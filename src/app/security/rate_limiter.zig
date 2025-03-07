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
        std.log.scoped(.auth).debug("[rate_limiter.check] Acquiring Redis client for identifier: '{s}'", .{identifier});
        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        std.log.scoped(.auth).debug("[rate_limiter.check] Fetching value from Redis for identifier: '{s}'", .{identifier});
        const value = try client.get(identifier);
        std.log.scoped(.auth).debug("[rate_limiter.check] Redis value for identifier '{s}': {?s}", .{ identifier, value });

        // Parse attempts from Redis value
        var attempts: u32 = if (value) |v| blk: {
            const parsed = try std.fmt.parseInt(u32, v, 10);
            std.log.scoped(.auth).debug("[rate_limiter.check] Parsed attempts for '{s}': {}", .{ identifier, parsed });
            break :blk parsed;
        } else blk: {
            std.log.scoped(.auth).debug("[rate_limiter.check] No previous attempts for '{s}', starting at 0", .{identifier});
            break :blk 0;
        };

        // Initialize if no previous attempts
        if (attempts == 0) {
            std.log.scoped(.auth).debug("[rate_limiter.check] Initializing attempts to 1 for '{s}' with lockout duration: {}", .{ identifier, self.config.lockout_duration });
            try client.setEx(identifier, "1", self.config.lockout_duration);
            return RateLimitInfo{
                .attempts = 1,
                .remaining = self.config.max_attempts - 1,
                .reset_at = std.time.timestamp() + @as(i64, self.config.lockout_duration), // Proper reset time
                .is_locked = false,
            };
        }

        // Increment attempts
        attempts += 1;
        std.log.scoped(.auth).debug("[rate_limiter.check] Incremented attempts for '{s}' to: {}", .{ identifier, attempts });

        // Check if max attempts exceeded
        if (attempts >= self.config.max_attempts) {
            std.log.scoped(.auth).debug("[rate_limiter.check] Max attempts ({}) exceeded for '{s}', locking account", .{ self.config.max_attempts, identifier });
            const attempts_str = try std.fmt.allocPrint(client.allocator, "{}", .{self.config.max_attempts});
            defer client.allocator.free(attempts_str);
            try client.setEx(identifier, attempts_str, self.config.lockout_duration);
            return error.AccountLocked;
        }

        // Update attempts in Redis
        std.log.scoped(.auth).debug("[rate_limiter.check] Saving updated attempts ({}) for '{s}' with lockout duration: {}", .{ attempts, identifier, self.config.lockout_duration });
        const attempts_str = try std.fmt.allocPrint(client.allocator, "{}", .{attempts});
        defer client.allocator.free(attempts_str);
        try client.setEx(identifier, attempts_str, self.config.lockout_duration);

        const reset_at = std.time.timestamp() + @as(i64, self.config.lockout_duration);
        std.log.scoped(.auth).debug("[rate_limiter.check] Returning rate limit info for '{s}': attempts={}, remaining={}, reset_at={}", .{
            identifier,
            attempts,
            self.config.max_attempts - attempts,
            reset_at,
        });
        return RateLimitInfo{
            .attempts = attempts,
            .remaining = self.config.max_attempts - attempts,
            .reset_at = reset_at, // Proper reset time
            .is_locked = false,
        };
    }

    pub fn reset(self: *RateLimiter, identifier: []const u8) !void {
        std.log.scoped(.auth).debug("[rate_limiter.reset] Acquiring Redis client for identifier: '{s}'", .{identifier});
        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        std.log.scoped(.auth).debug("[rate_limiter.reset] Deleting rate limit entry for '{s}'", .{identifier});
        _ = client.del(identifier) catch |err| {
            //std.log.scoped(.auth).debug("[rate_limiter.reset] Failed to delete from Redis: {}", .{err});
            return switch (err) {
                redis.RedisError.ConnectionFailed => error.StorageError,
                redis.RedisError.CommandFailed => error.StorageError,
                else => err,
            };
        };
        std.log.scoped(.auth).debug("[rate_limiter.reset] Successfully reset rate limit for '{s}'", .{identifier});
    }

    pub fn increment(self: *RateLimiter, identifier: []const u8) !void {
        std.log.scoped(.auth).debug("[rate_limiter.increment] Acquiring Redis client for identifier: '{s}'", .{identifier});
        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        std.log.scoped(.auth).debug("[rate_limiter.increment] Incrementing attempts for '{s}'", .{identifier});
        const new_attempts = try client.incr(identifier);
        std.log.scoped(.auth).debug("[rate_limiter.increment] New attempts count for '{s}': {}", .{ identifier, new_attempts });

        std.log.scoped(.auth).debug("[rate_limiter.increment] Setting expiration for '{s}' to {} seconds", .{ identifier, self.config.window_seconds });
        try client.expire(identifier, self.config.window_seconds);
        std.log.scoped(.auth).debug("[rate_limiter.increment] Successfully set expiration for '{s}'", .{identifier});
    }

    fn isLocked(self: *const RateLimiter, attempts: u32) bool {
        const locked = attempts >= self.config.max_attempts;
        std.log.scoped(.auth).debug("[rate_limiter.isLocked] Checking if locked: attempts={} vs max_attempts={}, result={}", .{
            attempts,
            self.config.max_attempts,
            locked,
        });
        return locked;
    }

    fn exceededLimit(self: *const RateLimiter, attempts: u32) bool {
        const exceeded = attempts >= (self.config.max_attempts - 1);
        std.log.scoped(.auth).debug("[rate_limiter.exceededLimit] Checking if limit exceeded: attempts={} vs max_attempts-1={}, result={}", .{
            attempts,
            self.config.max_attempts - 1,
            exceeded,
        });
        return exceeded;
    }

    pub fn lockAccount(self: *RateLimiter, identifier: []const u8) !void {
        std.log.scoped(.auth).debug("[rate_limiter.lockAccount] Acquiring Redis client for identifier: '{s}'", .{identifier});
        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        std.log.scoped(.auth).debug("[rate_limiter.lockAccount] Locking account for '{s}' with max_attempts={} and duration={}", .{
            identifier,
            self.config.max_attempts,
            self.config.lockout_duration,
        });
        const attempts_str = try std.fmt.allocPrint(client.allocator, "{}", .{self.config.max_attempts});
        defer client.allocator.free(attempts_str);
        try client.setEx(identifier, attempts_str, self.config.lockout_duration);
        std.log.scoped(.auth).debug("[rate_limiter.lockAccount] Successfully locked account for '{s}'", .{identifier});
    }
};
