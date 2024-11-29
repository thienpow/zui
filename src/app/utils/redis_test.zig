const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualStrings = testing.expectEqualStrings;

const redis = @import("redis.zig");

test "connection pool basic functionality" {
    // Use testing allocator for proper memory tracking
    const allocator = testing.allocator;

    // Configure and create connection pool
    const config = redis.RedisClientConfig{
        .host = "localhost",
        .port = 6379,
        .max_connections = 5,
    };
    var pool = try redis.PooledRedisClient.init(allocator, config);
    defer pool.deinit();

    // Test basic connection and operations
    {
        const client1 = try pool.acquire();
        defer pool.release(client1) catch {};

        // Ping to verify connection
        const ping_response = try client1.ping();
        defer allocator.free(ping_response);
        try expectEqualStrings("PONG", ping_response);

        // Set and get a key
        try client1.set("test_key_1", "test_value_1");
        const value1 = try client1.get("test_key_1");
        try testing.expect(value1 != null);
        if (value1) |v| {
            try expectEqualStrings("test_value_1", v);
            allocator.free(v);
        }
    }

    // Test multiple connection acquisitions
    {
        const client2 = try pool.acquire();
        defer pool.release(client2) catch {};

        const client3 = try pool.acquire();
        defer pool.release(client3) catch {};

        // Verify different connections
        try expect(client2 != client3);

        // Set and get on different connections
        try client2.set("test_key_2", "test_value_2");
        try client3.set("test_key_3", "test_value_3");

        const value2 = try client2.get("test_key_2");
        const value3 = try client3.get("test_key_3");

        try testing.expect(value2 != null);
        try testing.expect(value3 != null);

        if (value2) |v2| {
            defer allocator.free(v2);
            try expectEqualStrings("test_value_2", v2);
        }

        if (value3) |v3| {
            defer allocator.free(v3);
            try expectEqualStrings("test_value_3", v3);
        }
    }

    // Test key deletion
    {
        const client4 = try pool.acquire();
        defer pool.release(client4) catch {};

        try client4.set("delete_key", "delete_value");
        const deleted_count = try client4.del("delete_key");
        try expectEqual(@as(u64, 1), deleted_count);

        const deleted_value = try client4.get("delete_key");
        try expect(deleted_value == null);
    }

    // Test null key handling
    {
        const client5 = try pool.acquire();
        defer pool.release(client5) catch {};

        const non_existent_value = try client5.get("non_existent_key");
        try expect(non_existent_value == null);
    }

    // Test pool exhaustion (if possible, depends on your Redis server)
    // Note: This test might need to be adapted based on your specific connection handling
    {
        var connections = std.ArrayList(*redis.RedisClient).init(allocator);
        defer connections.deinit();

        // Try to acquire max connections
        for (0..config.max_connections) |_| {
            const conn = try pool.acquire();
            try connections.append(conn);
        }

        // Attempt to acquire one more connection should fail or block
        const acquire_result = pool.acquire();
        try testing.expectError(redis.RedisError.PoolExhausted, acquire_result);

        // Release all connections
        for (connections.items) |conn| {
            try pool.release(conn);
        }
    }
}

test "basic set and get without pool" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = try redis.RedisClient.connect(allocator, "127.0.0.1", 6379); // Ensure Redis is running!
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

    var client = try redis.RedisClient.connect(allocator, "127.0.0.1", 6379);
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
