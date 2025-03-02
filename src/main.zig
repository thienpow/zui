const std = @import("std");
const builtin = @import("builtin");
const jetzig = @import("jetzig");
const zmd = @import("zmd");
pub const routes = @import("routes");
pub const static = @import("static");
const redis = @import("app/database/redis/redis.zig");
const PooledRedisClient = redis.PooledRedisClient;
const RedisClientConfig = redis.RedisClientConfig;
const Security = @import("app/security/security.zig").Security;
const SecurityConfig = @import("app/security/config.zig").SecurityConfig;

const ConfigManager = @import("app/config/config.zig").ConfigManager;

pub const Global = struct {
    security: Security,
    config_manager: ConfigManager,
};

// Override default settings in `jetzig.config` here:
pub const jetzig_options = struct {
    pub const middleware: []const type = &.{
        // jetzig.middleware.HtmxMiddleware,
        // jetzig.middleware.CompressionMiddleware,
        @import("app/middleware/router.zig"),
    };

    pub const max_bytes_request_body: usize = std.math.pow(usize, 2, 16);
    pub const max_bytes_public_content: usize = std.math.pow(usize, 2, 20);
    pub const max_bytes_static_content: usize = std.math.pow(usize, 2, 18);
    pub const max_bytes_header_name: u16 = 40;
    pub const max_multipart_form_fields: usize = 20;
    pub const log_message_buffer_len: usize = 4096;
    pub const max_log_pool_len: usize = 256;
    pub const thread_count: ?u16 = null;
    pub const worker_count: u16 = 4;
    pub const max_connections: u16 = 512;
    pub const buffer_size: usize = 64 * 1024;
    pub const arena_size: usize = 1024 * 1024;
    pub const public_content_path = "public";
    pub const http_buffer_size: usize = std.math.pow(usize, 2, 16);
    pub const job_worker_threads: usize = 4;
    pub const job_worker_sleep_interval_ms: usize = 10;
    pub const Schema = @import("Schema");

    pub const cookies: jetzig.http.Cookies.CookieOptions = .{
        .domain = switch (jetzig.environment) {
            .development => "localhost",
            .testing => "localhost",
            .production => "zui.kavod.app",
        },
        .path = "/",
    };

    pub const store: jetzig.kv.Store.KVOptions = .{
        .backend = .memory,
    };

    pub const job_queue: jetzig.kv.Store.KVOptions = .{
        .backend = .memory,
    };

    pub const cache: jetzig.kv.Store.KVOptions = .{
        .backend = .memory,
    };

    pub const force_development_email_delivery = false;
};

pub fn init(app: *jetzig.App) !void {
    _ = app;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;
    defer if (builtin.mode == .Debug) std.debug.assert(gpa.deinit() == .ok);

    var app = try jetzig.init(allocator);
    defer app.deinit();

    // Initialize the configuration manager
    var config_manager = try ConfigManager.init(allocator);
    defer config_manager.deinit();
    // std.log.debug("config_file_path = '{s}'", .{config_manager.config_file_path});
    // std.log.debug("Redis config: host='{s}', port={d}, max_connections={d}", .{ config_manager.redis_config.host, config_manager.redis_config.port, config_manager.redis_config.max_connections });
    // std.log.debug("Security config: storage.storage_type={}, tokens.access_token_ttl={d}", .{ config_manager.security_config.storage.storage_type, config_manager.security_config.tokens.access_token_ttl });

    // --- Use the loaded configurations ---
    const redis_pool_ptr = try allocator.create(PooledRedisClient);
    errdefer allocator.destroy(redis_pool_ptr);

    redis_pool_ptr.* = try PooledRedisClient.init(allocator, config_manager.redis_config);

    var security = try Security.init(allocator, config_manager.security_config, redis_pool_ptr);
    defer security.deinit();
    // -------------------------------------

    const global = try allocator.create(Global);
    global.* = .{
        .security = security,
        .config_manager = config_manager,
    };

    try app.start(routes, .{ .global = global });
}
