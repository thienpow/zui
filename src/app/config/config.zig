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

    const AppConfig = struct {
        redis: redis.RedisClientConfig,
        security: security.SecurityConfig,
    };

    pub fn init(allocator: std.mem.Allocator) !Self {
        std.log.scoped(.config).debug("[ConfigManager.init] Initializing config manager", .{});

        var dir_buf: [std.fs.max_path_bytes]u8 = undefined;
        const exe_dir = try std.fs.selfExeDirPath(&dir_buf);
        var cwd_buf: [std.fs.max_path_bytes]u8 = undefined;
        const cwd = try std.fs.cwd().realpath(".", &cwd_buf);
        const relative_config_path = switch (builtin.mode) {
            .Debug => "src/app/config/config.json",
            .ReleaseSafe, .ReleaseFast, .ReleaseSmall => "../config/config.json",
        };
        const config_paths = [_]struct { base: []const u8, rel: []const u8 }{
            .{ .base = exe_dir, .rel = relative_config_path },
            .{ .base = cwd, .rel = relative_config_path },
            .{ .base = "", .rel = relative_config_path },
            .{ .base = cwd, .rel = "config.json" },
            .{ .base = exe_dir, .rel = "config.json" },
            .{ .base = cwd, .rel = "config/config.json" },
        };

        var config_file_path: ?[]u8 = null;
        for (config_paths) |path_info| {
            if (path_info.base.len == 0) continue;

            const full_path = try std.fs.path.join(allocator, &.{ path_info.base, path_info.rel });
            // Free full_path unless it's the one assigned to config_file_path
            defer if (config_file_path == null or @intFromPtr(full_path.ptr) != @intFromPtr(config_file_path.?.ptr)) allocator.free(full_path);

            if (std.fs.openFileAbsolute(full_path, .{ .mode = .read_only })) |file| {
                file.close();
                config_file_path = full_path;
                std.log.scoped(.config).info("[ConfigManager.init] Found config file at: {s}", .{full_path});
                break;
            } else |_| continue;
        }

        if (config_file_path == null) {
            std.log.scoped(.config).err("[ConfigManager.init] Could not find config file", .{});
            return error.ConfigFileNotFound;
        }

        var manager = Self{
            .allocator = allocator,
            .redis_config = undefined,
            .security_config = undefined,
            .config_file_path = config_file_path.?,
        };

        try manager.load();
        std.log.scoped(.config).debug("[ConfigManager.init] Configuration manager initialized", .{});
        return manager;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.config_file_path);
        self.allocator.free(self.redis_config);
        self.allocator.free(self.security_config);
    }

    pub fn load(self: *Self) !void {
        std.log.scoped(.config).debug("[ConfigManager.load] Loading from: {s}", .{self.config_file_path});

        const file = try std.fs.openFileAbsolute(self.config_file_path, .{ .mode = .read_only });
        defer file.close();

        const file_size = try file.getEndPos();
        const file_content = try self.allocator.alloc(u8, file_size);
        defer self.allocator.free(file_content);
        _ = try file.readAll(file_content);

        const parsed = try std.json.parseFromSlice(AppConfig, self.allocator, file_content, .{
            .allocate = .alloc_always,
            .ignore_unknown_fields = true,
        });

        self.redis_config = parsed.value.redis;
        self.security_config = parsed.value.security;

        std.log.scoped(.config).info("[ConfigManager.load] Configuration loaded successfully", .{});
    }

    pub fn save(self: *Self) !void {
        std.log.scoped(.config).debug("[ConfigManager.save] Saving to: {s}", .{self.config_file_path});

        const file = try std.fs.createFileAbsolute(self.config_file_path, .{});
        defer file.close();

        const app_config = AppConfig{
            .redis = self.redis_config,
            .security = self.security_config,
        };

        try std.json.stringify(app_config, .{ .whitespace = .indent_2 }, file.writer());
        std.log.scoped(.config).info("[ConfigManager.save] Configuration saved", .{});
    }

    pub fn createDefaultConfigFile(self: *Self, path: []const u8) !void {
        std.log.scoped(.config).info("[ConfigManager.createDefaultConfigFile] Creating at: {s}", .{path});
        const default_config = try AppConfig.initDefault(self.allocator);
        const file = try std.fs.createFileAbsolute(path, .{});
        defer file.close();
        try std.json.stringify(default_config, .{ .whitespace = .indent_2 }, file.writer());
        std.log.scoped(.config).info("[ConfigManager.createDefaultConfigFile] Default config saved", .{});
    }
};
