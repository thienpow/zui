const std = @import("std");
const RevokedTokenSet = std.StringHashMap(void);
const crypto = std.crypto;
const redis = @import("../database/redis/redis.zig");
const types = @import("types.zig");
const config = @import("config.zig");

const Session = types.Session;
const Tokens = types.Tokens;
const TokenConfig = config.TokenConfig;
const PooledRedisClient = redis.PooledRedisClient;

pub const TokenError = error{
    InvalidToken,
    ExpiredToken,
    TokenGenerationFailed,
    StorageError,
};

pub const TokenManager = struct {
    allocator: std.mem.Allocator,
    config: TokenConfig,
    redis_pool: *PooledRedisClient,

    fn generateToken(self: *TokenManager) ![]const u8 {
        var random_bytes: [48]u8 = undefined;
        std.crypto.random.bytes(&random_bytes);

        const encoder = std.base64.standard.Encoder;
        const encoded_len = encoder.calcSize(random_bytes.len);
        const encoded = try self.allocator.alloc(u8, encoded_len);
        _ = encoder.encode(encoded, random_bytes[0..]); // Pass slice explicitly

        return encoded;
    }

    fn createAccessToken(self: *TokenManager, session: Session) ![]const u8 {
        const token = try self.generateToken();

        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        const key = try std.fmt.allocPrint(self.allocator, "access_token:{s}", .{token});
        defer self.allocator.free(key);

        const value = try std.json.stringifyAlloc(self.allocator, session, .{});
        defer self.allocator.free(value);

        client.setEx(key, value, self.config.access_token_ttl) catch |err| {
            return switch (err) {
                redis.RedisError.ConnectionFailed => TokenError.StorageError,
                redis.RedisError.CommandFailed => TokenError.StorageError,
                else => err,
            };
        };

        return token;
    }

    fn createRefreshToken(self: *TokenManager, session: Session) ![]const u8 {
        const token = try self.generateToken();

        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        const key = try std.fmt.allocPrint(self.allocator, "refresh_token:{s}", .{token});
        defer self.allocator.free(key);

        const value = try std.json.stringifyAlloc(self.allocator, session, .{});
        defer self.allocator.free(value);

        client.setEx(key, value, self.config.refresh_token_ttl) catch |err| {
            return switch (err) {
                redis.RedisError.ConnectionFailed => TokenError.StorageError,
                redis.RedisError.CommandFailed => TokenError.StorageError,
                else => err,
            };
        };

        return token;
    }

    pub fn invalidateToken(self: *TokenManager, token: []const u8) !void {
        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        const access_key = try std.fmt.allocPrint(self.allocator, "access_token:{s}", .{token});
        defer self.allocator.free(access_key);

        const refresh_key = try std.fmt.allocPrint(self.allocator, "refresh_token:{s}", .{token});
        defer self.allocator.free(refresh_key);

        try client.del(access_key) catch |err| switch (err) {
            redis.RedisError.ConnectionFailed => return TokenError.StorageError,
            redis.RedisError.CommandFailed => return TokenError.StorageError,
            else => return err,
        };

        try client.del(refresh_key) catch |err| switch (err) {
            redis.RedisError.ConnectionFailed => return TokenError.StorageError,
            redis.RedisError.CommandFailed => return TokenError.StorageError,
            else => return err,
        };
    }

    fn createCSRFToken(self: *TokenManager) ![]const u8 {
        var random_bytes: [32]u8 = undefined;
        std.crypto.random.bytes(&random_bytes);

        const encoder = std.base64.standard.Encoder;
        const encoded_len = encoder.calcSize(random_bytes.len);
        const encoded = try self.allocator.alloc(u8, encoded_len);
        _ = encoder.encode(encoded, random_bytes[0..]);

        return encoded;
    }

    pub fn generate(self: *TokenManager, session: Session) !Tokens {
        return Tokens{
            .access = try self.allocator.dupe(u8, try self.createAccessToken(session)),
            .refresh = try self.allocator.dupe(u8, try self.createRefreshToken(session)),
            .csrf = try self.allocator.dupe(u8, try self.createCSRFToken()),
        };
    }

    pub fn rotate(self: *TokenManager, refresh_token: []const u8) !Tokens {
        // Validate refresh token
        const session = try self.validateRefreshToken(refresh_token);

        // Generate new token pair
        const new_tokens = try self.generate(session);

        // Invalidate old refresh token
        try self.invalidateToken(refresh_token);

        return new_tokens;
    }

    fn validateRefreshToken(self: *TokenManager, token: []const u8) !Session {
        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        const key = try std.fmt.allocPrint(self.allocator, "refresh_token:{s}", .{token});
        defer self.allocator.free(key);

        const value = try client.get(key) catch |err| switch (err) {
            redis.RedisError.ConnectionFailed => return TokenError.StorageError,
            redis.RedisError.CommandFailed => return TokenError.StorageError,
            else => return err,
        } orelse return TokenError.InvalidToken;

        return try std.json.parse(Session, value, .{});
    }

    pub fn validateAccessToken(self: *TokenManager, token: []const u8) !Session {
        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        const key = try std.fmt.allocPrint(self.allocator, "access_token:{s}", .{token});
        defer self.allocator.free(key);

        const value = (client.get(key) catch |err| switch (err) {
            redis.RedisError.ConnectionFailed => return TokenError.StorageError,
            redis.RedisError.CommandFailed => return TokenError.StorageError,
            else => return err,
        }) orelse return TokenError.InvalidToken;

        var parsed = try std.json.parseFromSlice(Session, self.allocator, value, .{});
        defer parsed.deinit();
        return parsed.value;
    }

    pub fn isRevoked(self: *TokenManager, token: []const u8) !bool {
        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        const key = try std.fmt.allocPrint(self.allocator, "revoked_token:{s}", .{token});
        defer self.allocator.free(key);

        return (try client.exists(key)) > 0;
    }
};
