const std = @import("std");
const builtin = @import("builtin");

const redis = @import("../../app/database/redis/redis.zig");
const security = @import("../../app/security/config.zig");

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

        var parsed_config = try std.json.parseFromSlice(AppConfig, self.allocator, file_content, .{});
        defer parsed_config.deinit();

        // Log the parsed values before assignment
        std.log.debug("Parsed redis config: host='{s}', port={d}, max_connections={d}", .{ parsed_config.value.redis.host, parsed_config.value.redis.port, parsed_config.value.redis.max_connections });
        std.log.debug("Parsed security config: max_sessions_per_user={d}, access_token_ttl={d}", .{ parsed_config.value.security.session.max_sessions_per_user, parsed_config.value.security.tokens.access_token_ttl });

        // Assign and validate redis_config
        // TODO: self.redis_config = parsed_config.value.redis;
        std.log.debug("Assigned redis_config: host='{s}'", .{self.redis_config.host});
        if (self.redis_config.host.len == 0) {
            std.log.warn("Redis host is empty in config file, defaulting to '127.0.0.1'", .{});
            self.redis_config.host = "127.0.0.1";
        }
        std.log.debug("Final redis_config: host='{s}'", .{self.redis_config.host});

        self.security_config = parsed_config.value.security;

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
