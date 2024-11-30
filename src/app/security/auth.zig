const std = @import("std");
const jetzig = @import("jetzig");
const redis = @import("../database/redis/redis.zig");
const auth_schema = @import("../database/redis/schemas/auth.zig");

pub const AuthError = error{
    NotFound,
    Unauthorized,
    DatabaseError,
    TokenGenerationError,
    RedisError,
};

pub const Auth = struct {
    allocator: std.mem.Allocator,
    redis_pool: redis.PooledRedisClient,

    pub fn init(allocator: std.mem.Allocator) !Auth {
        const redis_config = redis.RedisClientConfig{
            .host = "localhost",
            .port = 6379,
            .max_connections = 5,
        };
        const pool = try redis.PooledRedisClient.init(allocator, redis_config);

        return Auth{
            .allocator = allocator,
            .redis_pool = pool,
        };
    }

    pub fn deinit(self: *Auth) void {
        self.redis_pool.deinit();
    }

    pub fn login(self: *Auth, request: *jetzig.Request, email: []const u8, password: []const u8) !void {
        // Fetch user by email
        const query = jetzig.database.Query(.User).findBy(.{ .email = email });
        const user = try request.repo.execute(query) orelse return AuthError.NotFound;

        // Verify password
        if (!try jetzig.auth.verifyPassword(request.allocator, user.password_hash, password)) {
            return AuthError.Unauthorized;
        }

        // Create user session
        try self.createUserSession(request, user);
    }

    fn createUserSession(self: *Auth, request: *jetzig.Request, user: anytype) !void {
        // Generate session token
        const token = jetzig.util.generateSecret(request.allocator, 32) catch return AuthError.TokenGenerationError;

        // Insert session in database
        try request.repo.insert(.UserSession, .{
            .user_id = user.id,
            .token = token,
        });

        // Store in Redis
        try self.storeSessionInRedis(user.id, token);
    }

    fn storeSessionInRedis(self: *Auth, user_id: i64, token: []const u8) !void {
        // Acquire Redis client
        const client = self.redis_pool.acquire() catch |err| {
            std.log.err("Failed to acquire Redis client: {}", .{err});
            return AuthError.RedisError;
        };
        defer self.redis_pool.release(client) catch {};

        // Prepare Redis key and value
        const redis_key = try std.fmt.allocPrint(self.allocator, "user:{d}", .{user_id});
        defer self.allocator.free(redis_key);

        const session = auth_schema.UserSession{
            .id = user_id,
            .token = token,
            .last_active = std.time.timestamp(),
            .expires_at = std.time.timestamp() + 60 * 60 * 24 * 30, // 30 days
        };

        const redis_value = try std.json.stringifyAlloc(self.allocator, session, .{});
        defer self.allocator.free(redis_value);

        // Store in Redis
        client.set(redis_key, redis_value) catch |err| {
            std.log.err("Failed to store session in Redis: {}", .{err});
            return AuthError.RedisError;
        };
    }

    pub fn logout(self: *Auth, request: *jetzig.Request, user_id: i64) !void {
        // Remove session from database
        try request.repo.delete(.UserSession, .{ .user_id = user_id });

        // Remove from Redis
        const client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client) catch {};

        const redis_key = try std.fmt.allocPrint(self.allocator, "user:{d}", .{user_id});
        defer self.allocator.free(redis_key);

        try client.del(redis_key);
    }

    pub fn register(self: *Auth, request: *jetzig.Request, username: []const u8, email: []const u8, password: []const u8) !void {
        // Hash password
        const password_hash = try jetzig.auth.hashPassword(request.allocator, password);
        defer self.allocator.free(password_hash);

        // Insert new user
        try request.repo.insert(.User, .{
            .username = username,
            .email = email,
            .password_hash = password_hash,
        });
    }

    pub fn verifyToken(self: *Auth, request: *jetzig.Request, token: []const u8) !bool {
        // Find user session by token
        const query = jetzig.database.Query(.UserSession).findBy(.{ .token = token });
        const session = try request.repo.execute(query) orelse return false;

        // Check Redis for additional validation
        const client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client) catch {};

        const redis_key = try std.fmt.allocPrint(self.allocator, "user:{d}", .{session.user_id});
        defer self.allocator.free(redis_key);

        //const redis_value = client.get(redis_key) catch return false;

        // Validate token expiration
        const current_time = std.time.timestamp();
        return current_time < session.expires_at;
    }
};

// Basic test structure (you'll want to expand this)
test "Auth initialization and basic flow" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Initialize Auth
    var auth = try Auth.init(allocator);
    defer auth.deinit();

    // Additional tests would go here
}
