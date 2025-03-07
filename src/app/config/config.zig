const std = @import("std");
const builtin = @import("builtin");

const redis = @import("../../app/database/redis/redis.zig");
const security = @import("../../app/security/config.zig");
const types = @import("../../app/security/types.zig");

pub const ConfigManager = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    redis_config: redis.RedisClientConfig,
    security_config: security.SecurityConfig,
    config_file_path: []const u8,

    pub fn init(allocator: std.mem.Allocator) !Self {
        std.log.scoped(.config).debug("[config.init] Initializing config manager", .{});

        const redis_config = redis.RedisClientConfig{
            .host = "127.0.0.1",
            .port = 6379,
            .max_connections = 10,
        };

        const security_config = security.SecurityConfig{
            .middleware = .{
                .protected_routes = &[_]types.ProtectedRoute{
                    .{
                        .prefix = "/admin/",
                        .strategies = &[_]types.AuthStrategy{ .session, .oauth },
                        .required_roles = &[_][]const u8{"admin"},
                    },
                    .{
                        .prefix = "/api/private/",
                        .strategies = &[_]types.AuthStrategy{.jwt},
                        .required_roles = null,
                    },
                    .{
                        .prefix = "/api/webhook/",
                        .strategies = &[_]types.AuthStrategy{.api_key},
                        .required_roles = null,
                    },
                },
                .login_redirect_url = "/auth/login",
                .use_return_to = true,
                .api_error_message = "Authentication required",
            },
            .session = .{
                .max_sessions_per_user = 5,
                .cookie_name = "session_token",
                .session_ttl = 24 * 60 * 60, // 24 hours in seconds
                .refresh_threshold = 60 * 60, // 1 hour in seconds
                .cleanup_interval = 60 * 60, // 1 hour in seconds
            },
            .storage = .{
                .storage_type = .both,
                .cleanup_batch_size = 1000,
            },
            .token = .{
                .access_token_ttl = 15 * 60, // 15 minutes
                .refresh_token_ttl = 7 * 24 * 60 * 60, // 7 days
                .token_length = 48,
            },
            .rate_limit = .{
                .max_attempts = 5,
                .window_seconds = 300, // 5 minutes
                .lockout_duration = 900, // 15 minutes
            },
            .audit = .{
                .enabled = true,
                .high_risk_events = &.{
                    .login_failed,
                    .password_changed,
                    .mfa_disabled,
                },
                .notify_admins = true,
                .store_type = .both,
                .log_retention_days = 90,
            },
            .oauth = .{
                .enabled = false,
                .state_cookie_name = "session_token",
                .state_cookie_max_age = 600,
                .providers = &[_]security.OAuthProviderConfig{
                    .{
                        .provider = .google,
                        .name = "Google",
                        .client_id = "YOUR_GOOGLE_CLIENT_ID",
                        .client_secret = "YOUR_GOOGLE_CLIENT_SECRET",
                        .auth_url = "https://accounts.google.com/o/oauth2/v2/auth",
                        .token_url = "https://oauth2.googleapis.com/token",
                        .userinfo_url = "https://www.googleapis.com/oauth2/v3/userinfo",
                        .redirect_uri = "http://localhost:8000/auth/oauth/callback/google",
                        .scope = "email profile",
                        .enabled = false,
                    },
                },
                .default_redirect = "/dashboard",
                .user_auto_create = true,
                .user_auto_login = true,
            },
        };

        // 1. Try to get the executable directory
        std.log.scoped(.config).debug("[config.init] Determining executable directory", .{});
        var dir_buf: [std.fs.max_path_bytes]u8 = undefined;
        const exe_dir = try std.fs.selfExeDirPath(&dir_buf);
        std.log.scoped(.config).debug("[config.init] Executable directory: {s}", .{exe_dir});

        // 2. Log current working directory for debugging
        var cwd_buf: [std.fs.max_path_bytes]u8 = undefined;
        // Get the current working directory
        const cwd = try std.fs.cwd().realpath(".", &cwd_buf);
        std.log.scoped(.config).debug("[config.init] Current working directory: {s}", .{cwd});

        // 3. Define possible config locations
        std.log.scoped(.config).debug("[config.init] Determining config file path based on build mode: {s}", .{@tagName(builtin.mode)});
        const relative_config_path = switch (builtin.mode) {
            .Debug => "src/app/config/config.json", // Development path
            .ReleaseSafe, .ReleaseFast, .ReleaseSmall => "../config/config.json", // Production path
        };

        // Try these options in order:
        const config_paths = [_]struct { base: []const u8, rel: []const u8 }{
            // First try the path relative to executable directory
            .{ .base = exe_dir, .rel = relative_config_path },
            // Then try from current working directory
            .{ .base = cwd, .rel = relative_config_path },
            // Then try direct relative path from CWD
            .{ .base = "", .rel = relative_config_path },
            // Then try some common locations
            .{ .base = cwd, .rel = "config.json" },
            .{ .base = exe_dir, .rel = "config.json" },
            .{ .base = cwd, .rel = "config/config.json" },
        };

        // 4. Try each path
        var config_file_path: ?[]u8 = null;
        var found_config = false;

        std.log.scoped(.config).debug("[config.init] Searching for config file in {d} possible locations", .{config_paths.len});
        for (config_paths) |path_info| {
            if (path_info.base.len == 0) {
                std.log.scoped(.config).debug("[config.init] Skipping empty base path", .{});
                continue; // Skip empty base paths
            }

            // Join base and relative paths
            const full_path = try std.fs.path.join(allocator, &.{ path_info.base, path_info.rel });
            defer {
                if (!found_config) allocator.free(full_path);
            }

            std.log.scoped(.config).debug("[config.init] Trying config path: {s}", .{full_path});

            // Check if file exists
            const file = std.fs.openFileAbsolute(full_path, .{ .mode = .read_only }) catch |err| {
                std.log.scoped(.config).debug("[config.init] Could not open {s}: {s}", .{ full_path, @errorName(err) });
                continue;
            };
            file.close();

            // Found a valid config file
            config_file_path = full_path;
            found_config = true;
            std.log.scoped(.config).info("[config.init] Found config file at: {s}", .{full_path});
            break;
        }

        if (config_file_path == null) {
            std.log.scoped(.config).err("[config.init] Could not find config file in any location", .{});
            return error.ConfigFileNotFound;
        }

        // Create and initialize the manager
        var manager = Self{
            .allocator = allocator,
            .redis_config = redis_config,
            .security_config = security_config,
            .config_file_path = config_file_path.?,
        };

        // Try to load configuration
        std.log.scoped(.config).debug("[config.init] Loading configuration from file", .{});
        try manager.load();
        std.log.scoped(.config).debug("[config.init] Configuration manager initialized successfully", .{});

        return manager;
    }

    pub fn deinit(self: *Self) void {
        std.log.scoped(.config).debug("[config.deinit] Cleaning up configuration manager resources", .{});
        // Free the allocated config_file_path
        self.allocator.free(self.config_file_path);
        for (self.security_config.middleware.protected_routes) |protected_route| {
            self.allocator.free(protected_route.prefix);
            if (protected_route.required_roles) |roles| {
                for (roles) |role| {
                    self.allocator.free(role);
                }
                self.allocator.free(roles);
            }
            self.allocator.free(protected_route.strategies);
        }

        self.allocator.free(self.security_config.middleware.protected_routes);
        self.allocator.free(self.security_config.middleware.login_redirect_url);
        self.allocator.free(self.security_config.middleware.api_error_message);

        for (self.security_config.oauth.providers) |provider| {
            self.allocator.free(provider.name);
            self.allocator.free(provider.client_id);
            self.allocator.free(provider.client_secret);
            self.allocator.free(provider.auth_url);
            self.allocator.free(provider.token_url);
            self.allocator.free(provider.userinfo_url);
            self.allocator.free(provider.redirect_uri);
            self.allocator.free(provider.scope);

            if (provider.custom_provider_id) |id| {
                self.allocator.free(id);
            }
        }

        if (self.security_config.oauth.providers.len > 0) {
            self.allocator.free(self.security_config.oauth.providers);
        }

        self.allocator.free(self.security_config.session.cookie_name);
        self.allocator.free(self.security_config.oauth.state_cookie_name);
        self.allocator.free(self.security_config.oauth.default_redirect);

        std.log.scoped(.config).debug("[config.deinit] Configuration manager resources freed", .{});
    }

    pub fn createDefaultConfigFile(self: *Self, path: []const u8) !void {
        std.log.scoped(.config).info("[config.createDefaultConfigFile] Creating default config file at: {s}", .{path});

        const app_config = AppConfig{
            .redis = self.redis_config,
            .security = self.security_config,
        };

        const file = try std.fs.createFileAbsolute(path, .{});
        defer file.close();

        try std.json.stringify(app_config, .{ .whitespace = .indent_2 }, file.writer());
        std.log.scoped(.config).info("[config.createDefaultConfigFile] Default configuration saved to {s}", .{path});
    }

    // Combined config struct for serialization
    const AppConfig = struct {
        redis: redis.RedisClientConfig,
        security: security.SecurityConfig,
    };

    fn parseAuthStrategy(str: []const u8) !types.AuthStrategy {
        std.log.scoped(.config).debug("[config.parseAuthStrategy] Parsing auth strategy: '{s}'", .{str});
        if (std.mem.eql(u8, str, "session")) return .session;
        if (std.mem.eql(u8, str, "jwt")) return .jwt;
        if (std.mem.eql(u8, str, "api_key")) return .api_key;
        if (std.mem.eql(u8, str, "basic")) return .basic;
        if (std.mem.eql(u8, str, "oauth")) return .oauth;
        if (std.mem.eql(u8, str, "none")) return .none;
        std.log.scoped(.config).err("[config.parseAuthStrategy] Invalid auth strategy: '{s}'", .{str});
        return error.InvalidAuthStrategy;
    }

    // Similarly for SecurityEvent parsing
    fn parseSecurityEvent(str: []const u8) !types.SecurityEvent {
        std.log.scoped(.config).debug("[config.parseSecurityEvent] Parsing security event: '{s}'", .{str});
        if (std.mem.eql(u8, str, "login_failed")) return .login_failed;
        if (std.mem.eql(u8, str, "password_changed")) return .password_changed;
        if (std.mem.eql(u8, str, "mfa_disabled")) return .mfa_disabled;
        // Add all other values...
        std.log.scoped(.config).err("[config.parseSecurityEvent] Invalid security event: '{s}'", .{str});
        return error.InvalidSecurityEvent;
    }

    fn parseOAuthProvider(str: []const u8) !types.OAuthProvider {
        std.log.scoped(.config).debug("[config.parseOAuthProvider] Parsing OAuth provider: '{s}'", .{str});
        if (std.mem.eql(u8, str, "google")) return .google;
        if (std.mem.eql(u8, str, "github")) return .github;
        if (std.mem.eql(u8, str, "facebook")) return .facebook;
        if (std.mem.eql(u8, str, "microsoft")) return .microsoft;
        if (std.mem.eql(u8, str, "apple")) return .apple;
        if (std.mem.eql(u8, str, "custom")) return .custom;
        std.log.scoped(.config).err("[config.parseOAuthProvider] Invalid OAuth provider: '{s}'", .{str});
        return error.InvalidOAuthProvider;
    }

    pub fn load(self: *Self) !void {
        std.log.scoped(.config).debug("[config.load] Starting load from config file: {s}", .{self.config_file_path});

        const file = std.fs.openFileAbsolute(self.config_file_path, .{ .mode = .read_only }) catch |err| {
            std.log.scoped(.config).err("[config.load] Error opening config file: {s}", .{@errorName(err)});
            return err;
        };
        defer file.close();

        const file_size = try file.getEndPos();
        std.log.scoped(.config).debug("[config.load] Config file size: {d} bytes", .{file_size});

        const file_content = try self.allocator.alloc(u8, file_size);
        defer self.allocator.free(file_content);

        const bytes_read = try file.readAll(file_content);
        std.log.scoped(.config).debug("[config.load] Read {d} bytes from config file", .{bytes_read});
        std.log.scoped(.config).debug("[config.load] Config file content: '{s}'", .{file_content});

        // Parse the JSON
        std.log.scoped(.config).debug("[config.load] Parsing JSON content", .{});
        var parsed_json = try std.json.parseFromSlice(std.json.Value, self.allocator, file_content, .{});
        defer parsed_json.deinit();

        // Get the Redis config
        std.log.scoped(.config).debug("[config.load] Processing Redis configuration", .{});
        if (parsed_json.value.object.get("redis")) |redis_json| {
            self.redis_config.host = try self.allocator.dupe(u8, redis_json.object.get("host").?.string);
            self.redis_config.port = @intCast(redis_json.object.get("port").?.integer);
            self.redis_config.max_connections = @intCast(redis_json.object.get("max_connections").?.integer);
            std.log.scoped(.config).debug("[config.load] Redis config: host={s}, port={d}, max_connections={d}", .{
                self.redis_config.host,
                self.redis_config.port,
                self.redis_config.max_connections,
            });
        } else {
            std.log.scoped(.config).debug("[config.load] No Redis configuration found, using defaults", .{});
        }

        // Get the security config
        std.log.scoped(.config).debug("[config.load] Processing security configuration", .{});
        if (parsed_json.value.object.get("security")) |security_json| {
            // Parse middleware
            std.log.scoped(.config).debug("[config.load] Processing auth middleware configuration", .{});
            if (security_json.object.get("middleware")) |middleware_json| {
                var routes = std.ArrayList(types.ProtectedRoute).init(self.allocator);
                defer routes.deinit();

                if (middleware_json.object.get("protected_routes")) |routes_json| {
                    std.log.scoped(.config).debug("[config.load] Processing {d} protected routes", .{routes_json.array.items.len});
                    for (routes_json.array.items, 0..) |route_json, i| {
                        const prefix = try self.allocator.dupe(u8, route_json.object.get("prefix").?.string);

                        // ***** KEY CHANGE HERE *****
                        var strategies = std.ArrayList(types.AuthStrategy).init(self.allocator); // Create a list for strategies.
                        if (route_json.object.get("strategies")) |strategies_json| { // get the strategies.
                            if (strategies_json.array.items.len > 0) {
                                for (strategies_json.array.items) |strategy_json| {
                                    const strategy = try parseAuthStrategy(strategy_json.string);
                                    try strategies.append(strategy);
                                }
                            }
                        }

                        const strategies_slice = try strategies.toOwnedSlice(); // Convert to owned slice.

                        std.log.scoped(.config).debug("[config.load] Processing protected route {d}: prefix={s}", .{ i, prefix });

                        var required_roles: ?[]const []const u8 = null;
                        if (route_json.object.get("required_roles")) |roles_json| {
                            if (roles_json != .null) {
                                std.log.scoped(.config).debug("[config.load] Processing {d} required roles for route", .{roles_json.array.items.len});
                                var roles_list = std.ArrayList([]const u8).init(self.allocator);
                                for (roles_json.array.items) |role_json| {
                                    try roles_list.append(try self.allocator.dupe(u8, role_json.string));
                                }
                                required_roles = try roles_list.toOwnedSlice();
                            } else {
                                std.log.scoped(.config).debug("[config.load] No required roles for route", .{});
                            }
                        }

                        try routes.append(.{
                            .prefix = prefix,
                            .strategies = strategies_slice, // Assign the slice of strategies
                            .required_roles = required_roles,
                        });
                    }
                }

                self.security_config.middleware.protected_routes = try routes.toOwnedSlice();
                std.log.scoped(.config).debug("[config.load] Processed {d} protected routes total", .{self.security_config.middleware.protected_routes.len});

                if (middleware_json.object.get("login_redirect_url")) |url_json| {
                    self.security_config.middleware.login_redirect_url =
                        try self.allocator.dupe(u8, url_json.string);
                    std.log.scoped(.config).debug("[config.load] Set login redirect URL: {s}", .{self.security_config.middleware.login_redirect_url});
                }

                if (middleware_json.object.get("use_return_to")) |use_return_json| {
                    self.security_config.middleware.use_return_to = use_return_json.bool;
                    std.log.scoped(.config).debug("[config.load] Set use_return_to: {}", .{self.security_config.middleware.use_return_to});
                }

                if (middleware_json.object.get("api_error_message")) |msg_json| {
                    self.security_config.middleware.api_error_message =
                        try self.allocator.dupe(u8, msg_json.string);
                    std.log.scoped(.config).debug("[config.load] Set API error message: {s}", .{self.security_config.middleware.api_error_message});
                }
            }

            std.log.scoped(.config).debug("[config.load] Processing session configuration", .{});
            if (security_json.object.get("session")) |session_json| {

                // Parse state cookie info
                if (session_json.object.get("max_sessions_per_user")) |max_sessions_json| {
                    self.security_config.session.max_sessions_per_user = @intCast(max_sessions_json.integer);
                    std.log.scoped(.config).debug("[config.load] Set max sessions per user: {d}", .{self.security_config.session.max_sessions_per_user});
                }

                if (security_json.object.get("cookie_name")) |cookie_name_json| {
                    self.security_config.session.cookie_name =
                        try self.allocator.dupe(u8, cookie_name_json.string);
                    std.log.scoped(.config).debug("[config.load] Set session cookie name: {s}", .{self.security_config.session.cookie_name});
                }

                if (session_json.object.get("session_ttl")) |session_ttl_json| {
                    self.security_config.session.session_ttl = @intCast(session_ttl_json.integer);
                    std.log.scoped(.config).debug("[config.load] Set session TTL: {d} seconds", .{self.security_config.session.session_ttl});
                }

                if (session_json.object.get("refresh_threshold")) |refresh_threshold_json| {
                    self.security_config.session.refresh_threshold = @intCast(refresh_threshold_json.integer);
                    std.log.scoped(.config).debug("[config.load] Set refresh threshold: {d} seconds", .{self.security_config.session.refresh_threshold});
                }

                if (session_json.object.get("cleanup_interval")) |cleanup_interval_json| {
                    self.security_config.session.cleanup_interval = @intCast(cleanup_interval_json.integer);
                    std.log.scoped(.config).debug("[config.load] Set cleanup interval: {d} seconds", .{self.security_config.session.cleanup_interval});
                }
            }

            // Parse storage config
            std.log.scoped(.config).debug("[config.load] Processing storage configuration", .{});
            if (security_json.object.get("storage")) |storage_json| {
                if (storage_json.object.get("storage_type")) |storage_type_json| {
                    std.log.scoped(.config).debug("[config.load] Processing storage type: {s}", .{storage_type_json.string});
                    if (std.mem.eql(u8, storage_type_json.string, "redis")) {
                        self.security_config.storage.storage_type = .redis;
                    } else if (std.mem.eql(u8, storage_type_json.string, "database")) {
                        self.security_config.storage.storage_type = .database;
                    } else if (std.mem.eql(u8, storage_type_json.string, "both")) {
                        self.security_config.storage.storage_type = .both;
                    } else {
                        std.log.scoped(.config).warn("[config.load] Unknown storage type: {s}, defaulting to 'both'", .{storage_type_json.string});
                        self.security_config.storage.storage_type = .both;
                    }
                }

                if (storage_json.object.get("cleanup_batch_size")) |cleanup_batch_size_json| {
                    self.security_config.storage.cleanup_batch_size = @intCast(cleanup_batch_size_json.integer);
                    std.log.scoped(.config).debug("[config.load] Set cleanup batch size: {d}", .{self.security_config.storage.cleanup_batch_size});
                }
            }

            // Parse tokens config
            std.log.scoped(.config).debug("[config.load] Processing token configuration", .{});
            if (security_json.object.get("token")) |token_json| {
                if (token_json.object.get("access_token_ttl")) |access_token_ttl_json| {
                    self.security_config.token.access_token_ttl = @intCast(access_token_ttl_json.integer);
                    std.log.scoped(.config).debug("[config.load] Set access token TTL: {d} seconds", .{self.security_config.token.access_token_ttl});
                }

                if (token_json.object.get("refresh_token_ttl")) |refresh_token_ttl_json| {
                    self.security_config.token.refresh_token_ttl = @intCast(refresh_token_ttl_json.integer);
                    std.log.scoped(.config).debug("[config.load] Set refresh token TTL: {d} seconds", .{self.security_config.token.refresh_token_ttl});
                }

                if (token_json.object.get("token_length")) |token_length_json| {
                    self.security_config.token.token_length = @intCast(token_length_json.integer);
                    std.log.scoped(.config).debug("[config.load] Set token length: {d}", .{self.security_config.token.token_length});
                }
            }

            // Parse rate limit config
            std.log.scoped(.config).debug("[config.load] Processing rate limit configuration", .{});
            if (security_json.object.get("rate_limit")) |rate_limit_json| {
                if (rate_limit_json.object.get("max_attempts")) |max_attempts_json| {
                    self.security_config.rate_limit.max_attempts = @intCast(max_attempts_json.integer);
                    std.log.scoped(.config).debug("[config.load] Set max attempts: {d}", .{self.security_config.rate_limit.max_attempts});
                }

                if (rate_limit_json.object.get("window_seconds")) |window_seconds_json| {
                    self.security_config.rate_limit.window_seconds = @intCast(window_seconds_json.integer);
                    std.log.scoped(.config).debug("[config.load] Set window seconds: {d}", .{self.security_config.rate_limit.window_seconds});
                }

                if (rate_limit_json.object.get("lockout_duration")) |lockout_duration_json| {
                    self.security_config.rate_limit.lockout_duration = @intCast(lockout_duration_json.integer);
                    std.log.scoped(.config).debug("[config.load] Set lockout duration: {d} seconds", .{self.security_config.rate_limit.lockout_duration});
                }
            }

            // Parse audit config
            std.log.scoped(.config).debug("[config.load] Processing audit configuration", .{});
            if (security_json.object.get("audit")) |audit_json| {
                if (audit_json.object.get("enabled")) |enabled_json| {
                    self.security_config.audit.enabled = enabled_json.bool;
                    std.log.scoped(.config).debug("[config.load] Set audit enabled: {}", .{self.security_config.audit.enabled});
                }

                if (audit_json.object.get("notify_admins")) |notify_admins_json| {
                    self.security_config.audit.notify_admins = notify_admins_json.bool;
                    std.log.scoped(.config).debug("[config.load] Set notify admins: {}", .{self.security_config.audit.notify_admins});
                }

                if (audit_json.object.get("store_type")) |store_type_json| {
                    std.log.scoped(.config).debug("[config.load] Processing audit store type: {s}", .{store_type_json.string});
                    if (std.mem.eql(u8, store_type_json.string, "redis")) {
                        self.security_config.audit.store_type = .redis;
                    } else if (std.mem.eql(u8, store_type_json.string, "database")) {
                        self.security_config.audit.store_type = .database;
                    } else if (std.mem.eql(u8, store_type_json.string, "both")) {
                        self.security_config.audit.store_type = .both;
                    } else {
                        std.log.scoped(.config).warn("[config.load] Unknown audit store type: {s}, defaulting to 'both'", .{store_type_json.string});
                        self.security_config.audit.store_type = .both;
                    }
                }

                if (audit_json.object.get("log_retention_days")) |log_retention_days_json| {
                    self.security_config.audit.log_retention_days = @intCast(log_retention_days_json.integer);
                    std.log.scoped(.config).debug("[config.load] Set log retention days: {d}", .{self.security_config.audit.log_retention_days});
                }

                // Parse high_risk_events array
                if (audit_json.object.get("high_risk_events")) |high_risk_events_json| {
                    std.log.scoped(.config).debug("[config.load] Processing {d} high risk events", .{high_risk_events_json.array.items.len});
                    var events = std.ArrayList(types.SecurityEvent).init(self.allocator);
                    defer events.deinit();

                    for (high_risk_events_json.array.items, 0..) |event_json, i| {
                        const event_str = event_json.string;
                        std.log.scoped(.config).debug("[config.load] Processing high risk event {d}: {s}", .{ i, event_str });
                        const event = try parseSecurityEvent(event_str);
                        try events.append(event);
                    }

                    // Only free if it's not the default array pointer from initialization
                    const default_high_risk_events = &[_]types.SecurityEvent{
                        .login_failed,
                        .password_changed,
                        .mfa_disabled,
                    };
                    if (self.security_config.audit.high_risk_events.ptr != default_high_risk_events.ptr) {
                        self.allocator.free(self.security_config.audit.high_risk_events);
                    }

                    self.security_config.audit.high_risk_events = try events.toOwnedSlice();
                    std.log.scoped(.config).debug("[config.load] Set {d} high risk events", .{self.security_config.audit.high_risk_events.len});
                }
            }

            std.log.scoped(.config).debug("[config.load] Processing OAuth configuration", .{});
            if (security_json.object.get("oauth")) |oauth_json| {
                // Parse enabled flag
                if (oauth_json.object.get("enabled")) |enabled_json| {
                    self.security_config.oauth.enabled = enabled_json.bool;
                    std.log.scoped(.config).debug("[config.load] Set OAuth enabled: {}", .{self.security_config.oauth.enabled});
                }

                if (oauth_json.object.get("state_cookie_name")) |state_cookie_name_json| {
                    self.security_config.oauth.state_cookie_name =
                        try self.allocator.dupe(u8, state_cookie_name_json.string);
                    std.log.scoped(.config).debug("[config.load] Set OAuth state_cookie_name: {s}", .{self.security_config.oauth.state_cookie_name});
                }

                if (oauth_json.object.get("state_cookie_max_age")) |state_cookie_max_age_json| {
                    self.security_config.oauth.state_cookie_max_age = @intCast(state_cookie_max_age_json.integer);
                    std.log.scoped(.config).debug("[config.load] Set OAuth state_cookie_max_age: {d} seconds", .{self.security_config.oauth.state_cookie_max_age});
                }

                // Parse default redirect
                if (oauth_json.object.get("default_redirect")) |redirect_json| {
                    self.security_config.oauth.default_redirect =
                        try self.allocator.dupe(u8, redirect_json.string);
                    std.log.scoped(.config).debug("[config.load] Set OAuth default redirect: {s}", .{self.security_config.oauth.default_redirect});
                }

                // Parse user auto create/login flags
                if (oauth_json.object.get("user_auto_create")) |auto_create_json| {
                    self.security_config.oauth.user_auto_create = auto_create_json.bool;
                    std.log.scoped(.config).debug("[config.load] Set OAuth user auto create: {}", .{self.security_config.oauth.user_auto_create});
                }

                if (oauth_json.object.get("user_auto_login")) |auto_login_json| {
                    self.security_config.oauth.user_auto_login = auto_login_json.bool;
                    std.log.scoped(.config).debug("[config.load] Set OAuth user auto login: {}", .{self.security_config.oauth.user_auto_login});
                }

                // Parse OAuth providers
                if (oauth_json.object.get("providers")) |providers_json| {
                    std.log.scoped(.config).debug("[config.load] Processing {d} OAuth providers", .{providers_json.array.items.len});

                    var providers = std.ArrayList(security.OAuthProviderConfig).init(self.allocator);
                    defer providers.deinit();

                    for (providers_json.array.items, 0..) |provider_json, i| {
                        std.log.scoped(.config).debug("[config.load] Processing OAuth provider {d}", .{i});

                        // Required fields
                        const provider_type_str = provider_json.object.get("provider").?.string;
                        const provider_type = try parseOAuthProvider(provider_type_str);
                        const name = try self.allocator.dupe(u8, provider_json.object.get("name").?.string);
                        const client_id = try self.allocator.dupe(u8, provider_json.object.get("client_id").?.string);
                        const client_secret = try self.allocator.dupe(u8, provider_json.object.get("client_secret").?.string);
                        const auth_url = try self.allocator.dupe(u8, provider_json.object.get("auth_url").?.string);
                        const token_url = try self.allocator.dupe(u8, provider_json.object.get("token_url").?.string);
                        const userinfo_url = try self.allocator.dupe(u8, provider_json.object.get("userinfo_url").?.string);
                        const redirect_uri = try self.allocator.dupe(u8, provider_json.object.get("redirect_uri").?.string);
                        const scope = try self.allocator.dupe(u8, provider_json.object.get("scope").?.string);

                        // Optional fields
                        var enabled = true;
                        if (provider_json.object.get("enabled")) |enabled_json| {
                            enabled = enabled_json.bool;
                        }

                        var custom_provider_id: ?[]const u8 = null;
                        if (provider_json.object.get("custom_provider_id")) |id_json| {
                            if (id_json != .null) {
                                custom_provider_id = try self.allocator.dupe(u8, id_json.string);
                            }
                        }

                        try providers.append(.{
                            .provider = provider_type,
                            .name = name,
                            .client_id = client_id,
                            .client_secret = client_secret,
                            .auth_url = auth_url,
                            .token_url = token_url,
                            .userinfo_url = userinfo_url,
                            .redirect_uri = redirect_uri,
                            .scope = scope,
                            .enabled = enabled,
                            .custom_provider_id = custom_provider_id,
                        });

                        std.log.scoped(.config).debug("[config.load] Added OAuth provider: {s}", .{name});
                    }

                    self.security_config.oauth.providers = try providers.toOwnedSlice();
                    std.log.scoped(.config).debug("[config.load] Processed {d} OAuth providers total", .{self.security_config.oauth.providers.len});
                }
            }
        } else {
            std.log.scoped(.config).debug("[config.load] No security configuration found, using defaults", .{});
        }

        std.log.scoped(.config).info("[config.load] Configuration loaded successfully from {s}", .{self.config_file_path});
    }

    pub fn save(self: *Self) !void {
        std.log.scoped(.config).debug("[config.save] Starting save to config file: {s}", .{self.config_file_path});

        const file = try std.fs.cwd().createFile(self.config_file_path, .{});
        defer file.close();

        const app_config = AppConfig{
            .redis = self.redis_config,
            .security = self.security_config,
        };

        var buffer: [16384]u8 = undefined; // Use a fixed-size buffer
        var fba = std.heap.FixedBufferAllocator.init(&buffer);
        var json_writer = std.json.Writer.init(fba.allocator(), false);

        std.log.scoped(.config).debug("[config.save] Serializing configuration to JSON", .{});
        try json_writer.writeStruct(app_config);

        const json_content = json_writer.getWritten();
        std.log.scoped(.config).debug("[config.save] Writing {d} bytes to config file", .{json_content.len});
        _ = try file.writeAll(json_content);

        std.log.scoped(.config).info("[config.save] Configuration saved successfully to {s}", .{self.config_file_path});
    }
};
