const std = @import("std");
const jetzig = @import("jetzig");
const jetquery = @import("jetzig").jetquery;
const RedisClient = @import("../../utils/redis.zig").RedisClient;

pub const layout = "auth";
pub fn index(request: *jetzig.Request, _: *jetzig.Data) !jetzig.View {
    return request.render(.ok);
}

pub fn post(request: *jetzig.Request) !jetzig.View {
    const Params = struct {
        email: []const u8,
        password: []const u8,
    };

    const params = try request.expectParams(Params) orelse {
        return request.fail(.unprocessable_entity);
    };

    // Use `findBy` to fetch a single user by email
    const query = jetzig.database.Query(.User).findBy(.{ .email = params.email });
    const user = try request.repo.execute(query) orelse return request.fail(.not_found);

    // Verify the provided password matches the stored password hash
    if (!try jetzig.auth.verifyPassword(request.allocator, user.password_hash, params.password)) {
        return request.fail(.unauthorized);
    }

    // Generate a session token
    const token = try jetzig.util.generateSecret(request.allocator, 32);

    // Save the session token in the UserSession table
    try request.repo.insert(.UserSession, .{
        .user_id = user.id,
        .token = token,
    });

    // Store token in Redis for additional tracking
    var redis_client = try RedisClient.connect(request.allocator, "127.0.0.1", 6379);
    defer redis_client.disconnect();

    const redis_key = try std.fmt.allocPrint(request.allocator, "user:{d}", .{user.id});
    defer request.allocator.free(redis_key);

    try redis_client.set(redis_key, token);

    return request.render(.created, .{
        .token = token,
        .user_id = user.id,
    });
}
