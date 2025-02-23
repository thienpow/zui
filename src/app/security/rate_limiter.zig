const std = @import("std");
const redis = @import("../database/redis/redis.zig");
const config = @import("config.zig");

const PooledRedisClient = redis.PooledRedisClient;
const RateLimitConfig = config.RateLimitConfig;

pub const RateLimitInfo = struct {
    attempts: u32,
    remaining: u32,
    reset_at: i64,
    is_locked: bool,
};

pub const RateLimiter = struct {
    config: RateLimitConfig,
    redis_pool: *PooledRedisClient,

    pub fn check(self: *RateLimiter, identifier: []const u8) !RateLimitInfo {
        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client) catch |err| {
            std.log.err("Failed to release Redis client: {}", .{err});
        };

        // Get the value from Redis
        const value = try client.get(identifier);

        // Parse the attempts from the optional value
        const attempts = if (value) |v|
            try std.fmt.parseInt(u32, v, 10)
        else
            0;

        if (attempts >= self.config.max_attempts) {
            return error.AccountLocked;
        }

        if (attempts >= (self.config.max_attempts - 1)) {
            try client.setEx(identifier, try std.fmt.allocPrint(client.allocator, "{d}", .{self.config.max_attempts}), self.config.lockout_duration);
            return error.RateLimitExceeded;
        }

        return RateLimitInfo{
            .attempts = 0,
            .remaining = 0,
            .reset_at = 0,
            .is_locked = false,
        };
    }

    pub fn reset(self: *RateLimiter, identifier: []const u8) !void {
        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client) catch |err| {
            std.log.err("Failed to release Redis client: {}", .{err});
        };

        _ = client.del(identifier) catch |err| {
            return switch (err) {
                redis.RedisError.ConnectionFailed => error.StorageError,
                redis.RedisError.CommandFailed => error.StorageError,
                else => err,
            };
        };
    }

    pub fn increment(self: *RateLimiter, identifier: []const u8) !void {
        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client) catch |err| {
            std.log.err("Failed to release Redis client: {}", .{err});
        };

        _ = try client.incr(identifier);

        // Set the expiration time
        try client.expire(identifier, self.config.window_seconds);
    }

    fn isLocked(self: *const RateLimiter, attempts: u32) bool {
        return attempts >= self.config.max_attempts;
    }

    fn exceededLimit(self: *const RateLimiter, attempts: u32) bool {
        return attempts >= (self.config.max_attempts - 1);
    }

    fn lockAccount(self: *RateLimiter, identifier: []const u8) !void {
        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        try client.setEx(
            identifier,
            try std.fmt.allocPrint(client.allocator, "{d}", .{self.config.max_attempts}),
            self.config.lockout_duration,
        );
    }
};
