const std = @import("std");
const jetzig = @import("jetzig");
const jetquery = @import("jetzig").jetquery;
const auth = @import("../../database/schemas/auth.zig");

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

    var redis = request.global.redis_pool;
    //defer redis.release(redis);

    // Acquire a connection from the pool
    const client1 = try redis.acquire();
    defer redis.release(client1) catch {};

    // Set the session token in Redis
    const redis_key = try std.fmt.allocPrint(request.allocator, "user:{d}", .{user.id});
    defer request.allocator.free(redis_key);

    const p = auth.UserSession{ .id = user.id, .token = token, .last_activity = 0 };
    const redis_value = try std.fmt.allocPrint(request.allocator, "{}", .{p});
    defer request.allocator.free(redis_value);

    try client1.set(redis_key, redis_value);

    return request.render(.created);
}
