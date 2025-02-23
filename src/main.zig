const std = @import("std");
const builtin = @import("builtin");

const jetzig = @import("jetzig");
const zmd = @import("zmd");

pub const routes = @import("routes");
pub const static = @import("static");

const redis = @import("app/database/redis/redis.zig");
const RedisClientConfig = redis.RedisClientConfig;
const PooledRedisClient = redis.PooledRedisClient;
const Security = @import("app/security/security.zig").Security;
const SecurityConfig = @import("app/security/config.zig").SecurityConfig;

pub const Global = struct {
    redis_pool: redis.PooledRedisClient,
    security: Security,
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
        // .backend = .file,
        // .file_options = .{
        //     .path = "/path/to/jetkv-store.db",
        //     .truncate = false, // Set to `true` to clear the store on each server launch.
        //     .address_space_size = jetzig.jetkv.JetKV.FileBackend.addressSpace(4096),
        // },
    };

    pub const job_queue: jetzig.kv.Store.KVOptions = .{
        .backend = .memory,
        // .backend = .file,
        // .file_options = .{
        //     .path = "/path/to/jetkv-queue.db",
        //     .truncate = false, // Set to `true` to clear the store on each server launch.
        //     .address_space_size = jetzig.jetkv.JetKV.FileBackend.addressSpace(4096),
        // },
    };

    pub const cache: jetzig.kv.Store.KVOptions = .{
        .backend = .memory,
        // .backend = .file,
        // .file_options = .{
        //     .path = "/path/to/jetkv-cache.db",
        //     .truncate = false, // Set to `true` to clear the store on each server launch.
        //     .address_space_size = jetzig.jetkv.JetKV.FileBackend.addressSpace(4096),
        // },
    };

    /// SMTP configuration for Jetzig Mail. It is recommended to use a local SMTP relay,
    /// e.g.: https://github.com/juanluisbaptiste/docker-postfix
    ///
    /// Each configuration option can be overridden with environment variables:
    /// `JETZIG_SMTP_PORT`
    /// `JETZIG_SMTP_ENCRYPTION`
    /// `JETZIG_SMTP_HOST`
    /// `JETZIG_SMTP_USERNAME`
    /// `JETZIG_SMTP_PASSWORD`
    // pub const smtp: jetzig.mail.SMTPConfig = .{
    //     .port = 25,
    //     .encryption = .none, // .insecure, .none, .tls, .start_tls
    //     .host = "localhost",
    //     .username = null,
    //     .password = null,
    // };

    pub const force_development_email_delivery = false;

    pub const markdown_fragments = struct {
        pub const root = .{
            "<main>",
            "</main>",
        };
        pub const h1 = .{
            "<h1>",
            "</h1>",
        };
        pub const h2 = .{
            "<h2>",
            "</h2>",
        };
        pub const h3 = .{
            "<h3>",
            "</h3>",
        };
        pub const paragraph = .{
            "<p>",
            "</p>",
        };

        pub fn block(allocator: std.mem.Allocator, node: zmd.Node) ![]const u8 {
            return try std.fmt.allocPrint(allocator,
                \\<pre><code class="language-{?s}">{s}</code></pre>
            , .{ node.meta, node.content });
        }

        pub fn link(allocator: std.mem.Allocator, node: zmd.Node) ![]const u8 {
            return try std.fmt.allocPrint(allocator,
                \\<a href="{0s}" title={1s}>{1s}</a>
            , .{ node.href.?, node.title.? });
        }
    };
};

pub fn init(app: *jetzig.App) !void {
    _ = app;
    // Example custom route:
    // app.route(.GET, "/custom/:id/foo/bar", @import("app/views/custom/foo.zig"), .bar);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;
    defer if (builtin.mode == .Debug) std.debug.assert(gpa.deinit() == .ok);

    var app = try jetzig.init(allocator);
    defer app.deinit();

    // Initialize Redis pool
    const redis_config = RedisClientConfig{
        .host = "localhost",
        .port = 6379,
        .max_connections = 5,
    };
    var redis_pool = try PooledRedisClient.init(allocator, redis_config);
    defer redis_pool.deinit();

    const security_config = SecurityConfig{
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
            .log_retention_days = 90,
        },
        .redis_pool = &redis_pool,
    };

    // Initialize security with the config
    var security = try Security.init(allocator, security_config);
    defer security.deinit();

    const global = try allocator.create(Global);
    global.* = .{
        .redis_pool = redis_pool,
        .security = security,
    };

    try app.start(routes, .{ .global = global });
}
