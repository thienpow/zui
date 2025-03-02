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
        const redis_config = redis.RedisClientConfig{
            .host = "127.0.0.1",
            .port = 6379,
            .max_connections = 10,
        };

        const security_config = security.SecurityConfig{
            .auth_middleware = .{
                .protected_routes = &[_]types.ProtectedRoute{
                    .{
                        .prefix = "/admin/",
                        .strategy = .session,
                        .required_roles = &[_][]const u8{"admin"},
                    },
                    .{
                        .prefix = "/api/private/",
                        .strategy = .jwt,
                        .required_roles = null,
                    },
                    .{
                        .prefix = "/api/webhook/",
                        .strategy = .api_key,
                        .required_roles = null,
                    },
                },
                .login_redirect_url = "/auth/login",
                .use_return_to = true,
                .api_error_message = "Authentication required",
            },
            .session = .{
                .max_sessions_per_user = 5,
                .session_ttl = 24 * 60 * 60, // 24 hours in seconds
                .refresh_threshold = 60 * 60, // 1 hour in seconds
                .cleanup_interval = 60 * 60, // 1 hour in seconds
            },
            .storage = .{
                .storage_type = .both,
                .cleanup_batch_size = 1000,
            },
            .tokens = .{
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
        };

        // 1. Try to get the executable directory
        var dir_buf: [std.fs.max_path_bytes]u8 = undefined;
        const exe_dir = try std.fs.selfExeDirPath(&dir_buf);
        std.log.debug("Executable directory: {s}", .{exe_dir});

        // 2. Log current working directory for debugging
        var cwd_buf: [std.fs.max_path_bytes]u8 = undefined;
        // Get the current working directory
        const cwd = try std.fs.cwd().realpath(".", &cwd_buf);
        std.log.debug("Current working directory: {s}", .{cwd});

        // 3. Define possible config locations
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

        for (config_paths) |path_info| {
            if (path_info.base.len == 0) continue; // Skip empty base paths

            // Join base and relative paths
            const full_path = try std.fs.path.join(allocator, &.{ path_info.base, path_info.rel });
            defer {
                if (!found_config) allocator.free(full_path);
            }

            std.log.debug("Trying config path: {s}", .{full_path});

            // Check if file exists
            const file = std.fs.openFileAbsolute(full_path, .{ .mode = .read_only }) catch |err| {
                std.log.debug("Could not open {s}: {s}", .{ full_path, @errorName(err) });
                continue;
            };
            file.close();

            // Found a valid config file
            config_file_path = full_path;
            found_config = true;
            std.log.info("Found config file at: {s}", .{full_path});
            break;
        }

        if (config_file_path == null) {
            std.log.err("Could not find config file in any location", .{});
            return error.ConfigFileNotFound;
        }

        // Rest of your init function...
        var manager = Self{
            .allocator = allocator,
            .redis_config = redis_config,
            .security_config = security_config,
            .config_file_path = config_file_path.?,
        };

        // Try to load configuration
        try manager.load();

        return manager;
    }

    pub fn deinit(self: *Self) void {
        // Free the allocated config_file_path
        self.allocator.free(self.config_file_path);
    }

    pub fn createDefaultConfigFile(self: *Self, path: []const u8) !void {
        std.log.info("Creating default config file at: {s}", .{path});

        const app_config = AppConfig{
            .redis = self.redis_config,
            .security = self.security_config,
        };

        const file = try std.fs.createFileAbsolute(path, .{});
        defer file.close();

        try std.json.stringify(app_config, .{ .whitespace = .indent_2 }, file.writer());
        std.log.info("Default configuration saved to {s}", .{path});
    }

    // Combined config struct for serialization
    const AppConfig = struct {
        redis: redis.RedisClientConfig,
        security: security.SecurityConfig,
    };

    fn parseAuthStrategy(str: []const u8) !types.AuthStrategy {
        if (std.mem.eql(u8, str, "session")) return .session;
        if (std.mem.eql(u8, str, "jwt")) return .jwt;
        if (std.mem.eql(u8, str, "api_key")) return .api_key;
        if (std.mem.eql(u8, str, "basic")) return .basic;
        if (std.mem.eql(u8, str, "none")) return .none;
        return error.InvalidAuthStrategy;
    }

    // Similarly for SecurityEvent parsing
    fn parseSecurityEvent(str: []const u8) !types.SecurityEvent {
        if (std.mem.eql(u8, str, "login_failed")) return .login_failed;
        if (std.mem.eql(u8, str, "password_changed")) return .password_changed;
        if (std.mem.eql(u8, str, "mfa_disabled")) return .mfa_disabled;
        // Add all other values...
        return error.InvalidSecurityEvent;
    }

    pub fn load(self: *Self) !void {
        std.log.debug("Starting load from config file: {s}", .{self.config_file_path});

        const file = std.fs.openFileAbsolute(self.config_file_path, .{ .mode = .read_only }) catch |err| {
            std.log.err("Error opening config file: {s}", .{@errorName(err)});
            return err;
        };
        defer file.close();

        const file_size = try file.getEndPos();
        std.log.debug("Config file size: {d} bytes", .{file_size});

        const file_content = try self.allocator.alloc(u8, file_size);
        defer self.allocator.free(file_content);

        const bytes_read = try file.readAll(file_content);
        std.log.debug("Read {d} bytes from config file", .{bytes_read});
        std.log.debug("Config file content: '{s}'", .{file_content});

        // Parse the JSON
        var parsed_json = try std.json.parseFromSlice(std.json.Value, self.allocator, file_content, .{});
        defer parsed_json.deinit();

        // Get the Redis config
        if (parsed_json.value.object.get("redis")) |redis_json| {
            self.redis_config.host = try self.allocator.dupe(u8, redis_json.object.get("host").?.string);
            self.redis_config.port = @intCast(redis_json.object.get("port").?.integer);
            self.redis_config.max_connections = @intCast(redis_json.object.get("max_connections").?.integer);
        }

        // Get the security config
        if (parsed_json.value.object.get("security")) |security_json| {
            // Parse auth_middleware
            if (security_json.object.get("auth_middleware")) |middleware_json| {
                var routes = std.ArrayList(types.ProtectedRoute).init(self.allocator);
                defer routes.deinit();

                if (middleware_json.object.get("protected_routes")) |routes_json| {
                    for (routes_json.array.items) |route_json| {
                        const prefix = route_json.object.get("prefix").?.string;
                        const strategy_str = route_json.object.get("strategy").?.string;
                        const strategy = try parseAuthStrategy(strategy_str);

                        var required_roles: ?[]const []const u8 = null;
                        if (route_json.object.get("required_roles")) |roles_json| {
                            if (roles_json != .null) {
                                var roles_list = std.ArrayList([]const u8).init(self.allocator);
                                for (roles_json.array.items) |role_json| {
                                    try roles_list.append(try self.allocator.dupe(u8, role_json.string));
                                }
                                required_roles = try roles_list.toOwnedSlice();
                            }
                        }

                        try routes.append(.{
                            .prefix = try self.allocator.dupe(u8, prefix),
                            .strategy = strategy,
                            .required_roles = required_roles,
                        });
                    }
                }

                self.security_config.auth_middleware.protected_routes = try routes.toOwnedSlice();

                if (middleware_json.object.get("login_redirect_url")) |url_json| {
                    self.security_config.auth_middleware.login_redirect_url =
                        try self.allocator.dupe(u8, url_json.string);
                }

                if (middleware_json.object.get("use_return_to")) |use_return_json| {
                    self.security_config.auth_middleware.use_return_to = use_return_json.bool;
                }

                if (middleware_json.object.get("api_error_message")) |msg_json| {
                    self.security_config.auth_middleware.api_error_message =
                        try self.allocator.dupe(u8, msg_json.string);
                }
            }

            if (security_json.object.get("session")) |session_json| {
                if (session_json.object.get("max_sessions_per_user")) |max_sessions_json| {
                    self.security_config.session.max_sessions_per_user = @intCast(max_sessions_json.integer);
                }

                if (session_json.object.get("session_ttl")) |session_ttl_json| {
                    self.security_config.session.session_ttl = @intCast(session_ttl_json.integer);
                }

                if (session_json.object.get("refresh_threshold")) |refresh_threshold_json| {
                    self.security_config.session.refresh_threshold = @intCast(refresh_threshold_json.integer);
                }

                if (session_json.object.get("cleanup_interval")) |cleanup_interval_json| {
                    self.security_config.session.cleanup_interval = @intCast(cleanup_interval_json.integer);
                }
            }

            // Parse storage config
            if (security_json.object.get("storage")) |storage_json| {
                if (storage_json.object.get("storage_type")) |storage_type_json| {
                    if (std.mem.eql(u8, storage_type_json.string, "redis")) {
                        self.security_config.storage.storage_type = .redis;
                    } else if (std.mem.eql(u8, storage_type_json.string, "database")) {
                        self.security_config.storage.storage_type = .database;
                    } else if (std.mem.eql(u8, storage_type_json.string, "both")) {
                        self.security_config.storage.storage_type = .both;
                    } else {
                        std.log.warn("Unknown storage type: {s}, defaulting to 'both'", .{storage_type_json.string});
                    }
                }

                if (storage_json.object.get("cleanup_batch_size")) |cleanup_batch_size_json| {
                    self.security_config.storage.cleanup_batch_size = @intCast(cleanup_batch_size_json.integer);
                }
            }

            // Parse tokens config
            if (security_json.object.get("tokens")) |tokens_json| {
                if (tokens_json.object.get("access_token_ttl")) |access_token_ttl_json| {
                    self.security_config.tokens.access_token_ttl = @intCast(access_token_ttl_json.integer);
                }

                if (tokens_json.object.get("refresh_token_ttl")) |refresh_token_ttl_json| {
                    self.security_config.tokens.refresh_token_ttl = @intCast(refresh_token_ttl_json.integer);
                }

                if (tokens_json.object.get("token_length")) |token_length_json| {
                    self.security_config.tokens.token_length = @intCast(token_length_json.integer);
                }
            }

            // Parse rate limit config
            if (security_json.object.get("rate_limit")) |rate_limit_json| {
                if (rate_limit_json.object.get("max_attempts")) |max_attempts_json| {
                    self.security_config.rate_limit.max_attempts = @intCast(max_attempts_json.integer);
                }

                if (rate_limit_json.object.get("window_seconds")) |window_seconds_json| {
                    self.security_config.rate_limit.window_seconds = @intCast(window_seconds_json.integer);
                }

                if (rate_limit_json.object.get("lockout_duration")) |lockout_duration_json| {
                    self.security_config.rate_limit.lockout_duration = @intCast(lockout_duration_json.integer);
                }
            }

            // Parse audit config
            if (security_json.object.get("audit")) |audit_json| {
                if (audit_json.object.get("enabled")) |enabled_json| {
                    self.security_config.audit.enabled = enabled_json.bool;
                }

                if (audit_json.object.get("notify_admins")) |notify_admins_json| {
                    self.security_config.audit.notify_admins = notify_admins_json.bool;
                }

                if (audit_json.object.get("store_type")) |store_type_json| {
                    if (std.mem.eql(u8, store_type_json.string, "redis")) {
                        self.security_config.audit.store_type = .redis;
                    } else if (std.mem.eql(u8, store_type_json.string, "database")) {
                        self.security_config.audit.store_type = .database;
                    } else if (std.mem.eql(u8, store_type_json.string, "both")) {
                        self.security_config.audit.store_type = .both;
                    } else {
                        std.log.warn("Unknown audit store type: {s}, defaulting to 'both'", .{store_type_json.string});
                    }
                }

                if (audit_json.object.get("log_retention_days")) |log_retention_days_json| {
                    self.security_config.audit.log_retention_days = @intCast(log_retention_days_json.integer);
                }

                // Parse high_risk_events array
                if (audit_json.object.get("high_risk_events")) |high_risk_events_json| {
                    var events = std.ArrayList(types.SecurityEvent).init(self.allocator);
                    defer events.deinit();

                    for (high_risk_events_json.array.items) |event_json| {
                        const event_str = event_json.string;
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
                }
            }
        }

        std.log.info("Configuration loaded from {s}", .{self.config_file_path});
    }

    pub fn save(self: *Self) !void {
        const file = try std.fs.cwd().createFile(self.config_file_path, .{});
        defer file.close();

        const app_config = AppConfig{
            .redis = self.redis_config,
            .security = self.security_config,
        };

        var buffer: [16384]u8 = undefined; // Use a fixed-size buffer
        var fba = std.heap.FixedBufferAllocator.init(&buffer);
        var json_writer = std.json.Writer.init(fba.allocator(), false);

        try json_writer.writeStruct(app_config);

        _ = try file.writeAll(json_writer.getWritten());

        std.log.info("Configuration saved to {s}", .{self.config_file_path});
    }
};
