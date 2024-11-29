const std = @import("std");
const RedisClient = @import("redis.zig").RedisClient;

const expect = std.testing.expect;

test "basic set and get" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = try RedisClient.connect(allocator, "127.0.0.1", 6379); // Ensure Redis is running!
    defer client.disconnect();

    const p = User{ .id = 1, .token = "xyz123abc", .last_login = 1234567890 };
    const test_value = try std.fmt.allocPrint(allocator, "{}", .{p});
    defer allocator.free(test_value);

    try client.set("u:778899", test_value);
    const retrieved_value = try client.get("u:778899");
    defer if (retrieved_value) |val| allocator.free(val); // Free duplicated string

    std.debug.print("retrieved_value: {s}\n", .{retrieved_value.?});

    const parsed = try std.json.parseFromSlice(
        User,
        allocator,
        retrieved_value.?,
        .{},
    );
    defer parsed.deinit();

    const user = parsed.value;
    std.debug.print("user.token: {s}\n", .{user.token});

    try expect(std.mem.eql(u8, retrieved_value.?, test_value));

    // Test DEL
    const deleted_count = try client.del("u:778899");
    try expect(deleted_count == 1);
}

test "redis ping" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = try RedisClient.connect(allocator, "127.0.0.1", 6379);
    defer client.disconnect();

    const response = try client.ping();
    defer allocator.free(response); // Free the allocated response
    try expect(std.mem.startsWith(u8, response, "PONG"));
}

const User = struct {
    id: i32,
    token: []const u8,
    last_login: u64,
    //images: []const []const u8,

    pub fn format(
        user: User,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.writeAll("{");
        _ = try writer.print("\"id\":{},", .{user.id});
        _ = try writer.print("\"token\":\"{s}\",", .{user.token});
        _ = try writer.print("\"last_login\":{}", .{user.last_login});
        try writer.writeAll("}");
    }
};
