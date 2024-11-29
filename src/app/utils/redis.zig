const std = @import("std");

pub const RedisClient = struct {
    allocator: std.mem.Allocator,
    socket: std.net.Stream,
    connected: bool = false,

    pub fn connect(allocator: std.mem.Allocator, host: []const u8, port: u16) !RedisClient {
        const socket = std.net.tcpConnectToHost(allocator, host, port) catch |err| {
            std.log.err("Connection failed: {}", .{err});
            return err;
        };
        return RedisClient{
            .allocator = allocator,
            .socket = socket,
            .connected = true,
        };
    }

    pub fn command(self: *RedisClient, cmd: []const u8) ![]const u8 {
        // Write the command to the Redis server
        //std.debug.print("Sending command: {s}\n", .{cmd});
        try self.socket.writer().writeAll(cmd);

        // Read the response from the Redis server
        var buffer: [1024]u8 = undefined;
        const len = try self.socket.reader().read(&buffer);

        // Allocate and copy the response
        return self.allocator.dupe(u8, buffer[0..len]);
    }

    pub fn ping(self: *RedisClient) ![]const u8 {
        const cmd = try std.fmt.allocPrint(self.allocator, "*1\r\n$4\r\nPING\r\n", .{});
        defer self.allocator.free(cmd);

        const response = try self.command(cmd);
        defer self.allocator.free(response);
        // response is +PONG, we duped the response
        //  skip the + and return PONG only
        const duped_response = try self.allocator.dupe(u8, response[1..5]);
        return duped_response; // Return the duplicated slice
    }

    pub fn set(self: *RedisClient, key: []const u8, value: []const u8) !void {
        if (key.len == 0 or value.len == 0) {
            return error.InvalidArgument;
        }

        const cmd = try std.fmt.allocPrint(self.allocator, "*3\r\n$3\r\nSET\r\n${d}\r\n{s}\r\n${d}\r\n{s}\r\n", .{ key.len, key, value.len, value });
        defer self.allocator.free(cmd);

        const response = try self.command(cmd);
        defer self.allocator.free(response);

        if (!std.mem.startsWith(u8, response, "+OK\r\n")) {
            return error.SetFailed;
        }
    }

    pub fn get(self: *RedisClient, key: []const u8) !?[]const u8 {
        const cmd = try std.fmt.allocPrint(self.allocator, "*2\r\n$3\r\nGET\r\n${d}\r\n{s}\r\n", .{ key.len, key });
        defer self.allocator.free(cmd);

        const response = try self.command(cmd);
        defer self.allocator.free(response);

        // Check for null bulk string
        if (std.mem.startsWith(u8, response, "$-1\r\n")) {
            return null; // Key not found
        }

        // Extract bulk string value
        const start = std.mem.indexOf(u8, response, "\r\n") orelse return error.InvalidResponse;
        const end = std.mem.lastIndexOf(u8, response, "\r\n") orelse return error.InvalidResponse;

        // Handle potential OutOfMemory error
        const duped_response = try self.allocator.dupe(u8, response[start + 2 .. end]);
        return duped_response; // Return the duplicated slice

    }

    pub fn del(self: *RedisClient, key: []const u8) !u64 {
        const cmd = try std.fmt.allocPrint(self.allocator, "*2\r\n$3\r\nDEL\r\n${d}\r\n{s}\r\n", .{ key.len, key });
        defer self.allocator.free(cmd);

        const response = try self.command(cmd);
        defer self.allocator.free(response);

        // Parse integer response
        return try std.fmt.parseInt(u64, response[1 .. response.len - 2], 0);
    }

    pub fn disconnect(self: *RedisClient) void {
        self.socket.close();
    }
};
