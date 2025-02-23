const std = @import("std");
const types = @import("types.zig");
pub const pool = @import("pool.zig");

pub const RedisError = types.RedisError;
pub const ResponseType = types.ResponseType;
pub const RedisClientConfig = types.RedisClientConfig;
pub const BufferPool = pool.BufferPool;

pub const RedisClient = struct {
    allocator: std.mem.Allocator,
    socket: std.net.Stream,
    connected: bool,
    last_used_timestamp: i64,
    config: RedisClientConfig,
    reconnect_attempts: u8 = 0,
    max_reconnect_attempts: u8 = 3,
    buffer_pool: *BufferPool,
    command_buffer: std.ArrayList(u8),

    const Self = @This();

    pub fn isHealthy(self: *Self) bool {
        if (!self.connected) return false;

        // Check idle timeout
        const idle_time = std.time.milliTimestamp() - self.last_used_timestamp;
        if (idle_time > self.config.idle_timeout_ms) return false;

        // Try ping to verify connection
        const ping_response = self.ping() catch |err| {
            std.log.err("Health check failed: {}", .{err});
            return false;
        };
        defer self.allocator.free(ping_response);

        // Check if ping response is "PONG"
        return std.mem.eql(u8, ping_response, "PONG");
    }

    pub fn disconnect(self: *Self) void {
        self.socket.close();
        self.connected = false;
        self.last_used_timestamp = 0;
        self.command_buffer.deinit();
        self.buffer_pool.deinit();
        self.allocator.destroy(self.buffer_pool);
    }

    pub fn connect(allocator: std.mem.Allocator, config: RedisClientConfig) RedisError!Self {
        var socket = std.net.tcpConnectToHost(allocator, config.host, config.port) catch |err| {
            return switch (err) {
                error.ConnectionRefused => RedisError.ConnectionRefused,
                error.NetworkUnreachable, error.ConnectionTimedOut, error.ConnectionPending, error.ConnectionResetByPeer, error.SocketNotConnected, error.AddressInUse, error.AddressNotAvailable => RedisError.NetworkError,
                error.OutOfMemory => RedisError.OutOfMemory,
                else => RedisError.ConnectionFailed,
            };
        };
        errdefer socket.close();

        const buffer_pool = try allocator.create(BufferPool);
        buffer_pool.* = BufferPool.init(allocator);

        var client = Self{
            .allocator = allocator,
            .socket = socket,
            .connected = true,
            .last_used_timestamp = std.time.milliTimestamp(),
            .config = config,
            .reconnect_attempts = 0,
            .max_reconnect_attempts = 3,
            .buffer_pool = buffer_pool,
            .command_buffer = std.ArrayList(u8).init(allocator),
        };

        // Initial ping to verify connection
        const ping_response = client.ping() catch |err| {
            std.log.err("Initial ping failed: {}", .{err});
            client.disconnect();
            return RedisError.ConnectionFailed;
        };
        client.allocator.free(ping_response);

        return client;
    }

    pub fn reconnect(self: *Self) !void {
        if (self.connected) self.disconnect();

        while (self.reconnect_attempts < self.max_reconnect_attempts) : (self.reconnect_attempts += 1) {
            // Try to establish new connection
            const new_client = RedisClient.connect(self.allocator, self.config) catch |err| {
                std.log.err("Reconnection attempt {d} failed: {}", .{ self.reconnect_attempts + 1, err });
                if (self.reconnect_attempts + 1 == self.max_reconnect_attempts) {
                    return RedisError.ReconnectFailed;
                }
                std.time.sleep(std.time.ns_per_s); // 1 second delay between attempts
                continue;
            };

            // If connection successful, update current client
            self.socket = new_client.socket;
            self.connected = true;
            self.last_used_timestamp = std.time.milliTimestamp();
            self.reconnect_attempts = 0;
            return;
        }

        return RedisError.ReconnectFailed;
    }

    pub fn auth(self: *Self, password: []const u8) !void {
        const cmd = try self.formatCommand("*2\r\n$4\r\nAUTH\r\n${d}\r\n{s}\r\n", .{ password.len, password });
        defer self.allocator.free(cmd);
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);
        if (!std.mem.eql(u8, response, "+OK\r\n")) return RedisError.AuthenticationFailed;
    }

    pub fn select(self: *Self, db: u32) !void {
        const cmd = try self.formatCommand("*2\r\n$6\r\nSELECT\r\n${d}\r\n{d}\r\n", .{ std.fmt.count("{d}", .{db}), db });
        defer self.allocator.free(cmd);
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);
        if (!std.mem.eql(u8, response, "+OK\r\n")) return RedisError.CommandFailed;
    }

    fn formatCommand(self: *Self, comptime fmt: []const u8, args: anytype) ![]u8 {
        return std.fmt.allocPrint(self.allocator, fmt, args);
    }

    fn executeCommand(self: *Self, cmd: []const u8) ![]const u8 {
        if (!self.connected) {
            try self.reconnect();
        }

        const start_time = std.time.milliTimestamp();
        var retry_count: u8 = 0;
        const max_retries: u8 = 3;

        while (retry_count < max_retries) : (retry_count += 1) {
            if (std.time.milliTimestamp() - start_time > self.config.read_timeout_ms) {
                return RedisError.Timeout;
            }

            self.sendCommand(cmd) catch |err| {
                switch (err) {
                    error.ConnectionResetByPeer,
                    error.BrokenPipe,
                    error.ConnectionRefused,
                    error.InputOutput,
                    error.NotOpenForWriting,
                    error.SystemResources,
                    error.WouldBlock,
                    error.SocketNotConnected,
                    => {
                        try self.reconnect();
                        continue;
                    },
                    else => return err,
                }
            };

            return self.readResponse();
        }

        return RedisError.CommandFailed;
    }

    fn sendCommand(self: *Self, cmd: []const u8) !void {
        if (!self.connected) return RedisError.DisconnectedClient;
        self.last_used_timestamp = std.time.milliTimestamp();
        try self.socket.writer().writeAll(cmd);
    }

    fn readResponse(self: *Self) ![]const u8 {
        var buffer = std.ArrayList(u8).init(self.allocator);
        errdefer buffer.deinit();

        const reader = self.socket.reader();
        const response_type = try self.readResponseType(&buffer, reader);
        try self.parseResponse(&buffer, reader, response_type);

        return buffer.toOwnedSlice();
    }

    fn readResponseType(_: *Self, buffer: *std.ArrayList(u8), reader: anytype) !ResponseType {
        const first_byte = reader.readByte() catch |err| switch (err) {
            error.InputOutput => return RedisError.InputOutput,
            error.BrokenPipe => return RedisError.NetworkError,
            error.ConnectionResetByPeer => return RedisError.NetworkError,
            error.ConnectionTimedOut => return RedisError.Timeout,
            error.SystemResources => return RedisError.SystemResources,
            error.WouldBlock => return RedisError.NetworkError,
            error.SocketNotConnected => return RedisError.SocketNotConnected,
            error.EndOfStream => return RedisError.EndOfStream,
            else => return RedisError.NetworkError,
        };
        try buffer.append(first_byte);

        return switch (first_byte) {
            '+' => .SimpleString,
            '-' => .Error,
            ':' => .Integer,
            '$' => .BulkString,
            '*' => .Array,
            else => return RedisError.InvalidResponse,
        };
    }

    fn parseResponse(self: *Self, buffer: *std.ArrayList(u8), reader: anytype, response_type: ResponseType) RedisError!void {
        switch (response_type) {
            .SimpleString, .Error, .Integer => try self.readLine(buffer, reader),
            .BulkString => try self.readBulkString(buffer, reader),
            .Array => try self.readArray(buffer, reader),
        }
    }

    fn readLine(_: *Self, buffer: *std.ArrayList(u8), reader: anytype) RedisError!void {
        while (true) {
            const byte = reader.readByte() catch |err| switch (err) {
                error.InputOutput => return RedisError.InputOutput,
                error.BrokenPipe => return RedisError.NetworkError,
                error.ConnectionResetByPeer => return RedisError.NetworkError,
                error.ConnectionTimedOut => return RedisError.Timeout,
                error.SystemResources => return RedisError.SystemResources,
                error.WouldBlock => return RedisError.NetworkError,
                error.SocketNotConnected => return RedisError.SocketNotConnected,
                error.EndOfStream => return RedisError.EndOfStream,
                else => return RedisError.InvalidResponse,
            };
            try buffer.append(byte);
            if (byte == '\n' and buffer.items.len >= 2 and buffer.items[buffer.items.len - 2] == '\r') {
                break;
            }
        }
    }

    fn readBulkString(self: *Self, buffer: *std.ArrayList(u8), reader: anytype) RedisError!void {
        try self.readLine(buffer, reader);

        const line = buffer.items[1..];
        const len_end = std.mem.indexOf(u8, line, "\r") orelse return RedisError.InvalidResponse;
        const length = std.fmt.parseInt(i64, line[0..len_end], 10) catch |err| switch (err) {
            error.Overflow => return RedisError.Overflow,
            error.InvalidCharacter => return RedisError.InvalidFormat,
        };

        if (length == -1) return;

        const data = try self.allocator.alloc(u8, @intCast(length + 2));
        defer self.allocator.free(data);

        const bytes_read = reader.readAll(data) catch |err| switch (err) {
            error.InputOutput => return RedisError.InputOutput,
            error.BrokenPipe => return RedisError.NetworkError,
            error.ConnectionResetByPeer => return RedisError.NetworkError,
            error.ConnectionTimedOut => return RedisError.Timeout,
            error.SystemResources => return RedisError.SystemResources,
            error.WouldBlock => return RedisError.NetworkError,
            error.SocketNotConnected => return RedisError.SocketNotConnected,
            else => return RedisError.NetworkError,
        };
        if (bytes_read != length + 2) return RedisError.InvalidResponse;

        try buffer.appendSlice(data);
    }

    fn readArray(self: *Self, buffer: *std.ArrayList(u8), reader: anytype) RedisError!void {
        try self.readLine(buffer, reader);

        const line = buffer.items[1..];
        const len_end = std.mem.indexOf(u8, line, "\r") orelse return RedisError.InvalidResponse;
        const num_elements = std.fmt.parseInt(i64, line[0..len_end], 10) catch |err| switch (err) {
            error.Overflow => return RedisError.Overflow,
            error.InvalidCharacter => return RedisError.InvalidFormat,
        };

        if (num_elements == -1) return;

        var i: i64 = 0;
        while (i < num_elements) : (i += 1) {
            const element_type = try self.readResponseType(buffer, reader);
            try self.parseResponse(buffer, reader, element_type);
        }
    }

    pub fn ping(self: *Self) ![]const u8 {
        const cmd = "PING\r\n";
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);
        return try self.allocator.dupe(u8, "PONG");
    }

    pub fn set(self: *Self, key: []const u8, value: []const u8) !void {
        if (key.len == 0 or value.len == 0) return RedisError.InvalidArgument;
        const cmd = try self.formatCommand("*3\r\n$3\r\nSET\r\n${d}\r\n{s}\r\n${d}\r\n{s}\r\n", .{ key.len, key, value.len, value });
        defer self.allocator.free(cmd);
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);
        if (!std.mem.eql(u8, response, "+OK\r\n")) return RedisError.SetFailed;
    }

    pub fn get(self: *Self, key: []const u8) !?[]const u8 {
        if (key.len == 0) return RedisError.InvalidArgument;
        const cmd = try self.formatCommand("*2\r\n$3\r\nGET\r\n${d}\r\n{s}\r\n", .{ key.len, key });
        defer self.allocator.free(cmd);
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);

        if (response[0] == '$') {
            if (std.mem.eql(u8, response[0..4], "$-1\r")) return null;
            const len_end = std.mem.indexOf(u8, response, "\r\n") orelse return RedisError.InvalidResponse;
            const len = try std.fmt.parseInt(usize, response[1..len_end], 10);
            const value_start = len_end + 2;
            const value_end = value_start + len;
            if (value_end > response.len) return RedisError.InvalidResponse;
            return try self.allocator.dupe(u8, response[value_start..value_end]);
        }
        return RedisError.InvalidResponse;
    }

    pub fn del(self: *Self, key: []const u8) !u64 {
        if (key.len == 0) return RedisError.InvalidArgument;
        const cmd = try self.formatCommand("*2\r\n$3\r\nDEL\r\n${d}\r\n{s}\r\n", .{ key.len, key });
        defer self.allocator.free(cmd);
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);
        if (!std.mem.startsWith(u8, response, ":")) return RedisError.InvalidResponse;
        return try std.fmt.parseInt(u64, response[1 .. response.len - 2], 10);
    }

    pub fn setEx(self: *Self, key: []const u8, value: []const u8, ttl_seconds: i64) !void {
        const cmd = try self.formatCommand("*4\r\n$5\r\nSETEX\r\n${d}\r\n{s}\r\n${d}\r\n{d}\r\n${d}\r\n{s}\r\n", .{ key.len, key, std.fmt.count("{d}", .{ttl_seconds}), ttl_seconds, value.len, value });
        defer self.allocator.free(cmd);
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);
        if (!std.mem.eql(u8, response, "+OK\r\n")) return RedisError.SetFailed;
    }

    pub fn expire(self: *Self, key: []const u8, ttl_seconds: i64) !void {
        const cmd = try self.formatCommand("*3\r\n$6\r\nEXPIRE\r\n${d}\r\n{s}\r\n${d}\r\n{d}\r\n", .{ key.len, key, std.fmt.count("{d}", .{ttl_seconds}), ttl_seconds });
        defer self.allocator.free(cmd);
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);
    }

    pub fn ttl(self: *Self, key: []const u8) !?i64 {
        const cmd = try self.formatCommand("*2\r\n$3\r\nTTL\r\n${d}\r\n{s}\r\n", .{ key.len, key });
        defer self.allocator.free(cmd);
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);
        if (response[0] == ':') {
            return try std.fmt.parseInt(i64, response[1 .. response.len - 2], 10);
        }
        return null;
    }

    pub fn incr(self: *Self, key: []const u8) !u64 {
        const cmd = try self.formatCommand("*2\r\n$4\r\nINCR\r\n${d}\r\n{s}\r\n", .{ key.len, key });
        defer self.allocator.free(cmd);
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);
        if (!std.mem.startsWith(u8, response, ":")) return RedisError.InvalidResponse;
        return try std.fmt.parseInt(u64, response[1 .. response.len - 2], 10);
    }

    pub fn lPush(self: *Self, key: []const u8, value: []const u8) !u64 {
        if (key.len == 0 or value.len == 0) return RedisError.InvalidArgument;

        const cmd = try self.formatCommand("*3\r\n$5\r\nLPUSH\r\n${d}\r\n{s}\r\n${d}\r\n{s}\r\n", .{ key.len, key, value.len, value });
        defer self.allocator.free(cmd);

        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);

        // LPUSH returns the length of the list after the push operation
        if (!std.mem.startsWith(u8, response, ":")) return RedisError.InvalidResponse;
        return try std.fmt.parseInt(u64, response[1 .. response.len - 2], 10);
    }

    pub fn sMembers(self: *RedisClient, key: []const u8) !?[][]const u8 {
        if (key.len == 0) return RedisError.InvalidArgument;

        // Format SMEMBERS command
        const cmd = try self.formatCommand("*2\r\n$8\r\nSMEMBERS\r\n${d}\r\n{s}\r\n", .{ key.len, key });
        defer self.allocator.free(cmd);

        // Execute command
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);

        // Handle array response
        if (response[0] == '*') {
            var strings = std.ArrayList([]const u8).init(self.allocator);
            errdefer {
                for (strings.items) |item| {
                    self.allocator.free(item);
                }
                strings.deinit();
            }

            // Parse number of elements
            const len_end = std.mem.indexOf(u8, response[1..], "\r\n") orelse return RedisError.InvalidResponse;
            const num_elements = try std.fmt.parseInt(i64, response[1..len_end], 10);

            if (num_elements == 0) return null;
            if (num_elements == -1) return null;

            var current_pos: usize = len_end + 3; // Skip past initial *n\r\n
            var i: i64 = 0;
            while (i < num_elements) : (i += 1) {
                // Each element starts with $len\r\n
                if (response[current_pos] != '$') return RedisError.InvalidResponse;

                const str_len_end = std.mem.indexOf(u8, response[current_pos + 1 ..], "\r\n") orelse return RedisError.InvalidResponse;
                const str_len = try std.fmt.parseInt(usize, response[current_pos + 1 .. current_pos + 1 + str_len_end], 10);

                current_pos += str_len_end + 3; // Skip past $len\r\n
                const string = response[current_pos .. current_pos + str_len];
                try strings.append(try self.allocator.dupe(u8, string));

                current_pos += str_len + 2; // Skip past string and \r\n
            }

            const result = try strings.toOwnedSlice();
            return result;
        }

        return null;
    }

    pub fn sAdd(self: *Self, key: []const u8, member: []const u8) !void {
        if (key.len == 0 or member.len == 0) return RedisError.InvalidArgument;

        // Format SADD command using the existing formatCommand method
        const cmd = try self.formatCommand("*3\r\n$4\r\nSADD\r\n${d}\r\n{s}\r\n${d}\r\n{s}\r\n", .{ key.len, key, member.len, member });
        defer self.allocator.free(cmd);

        // Use the existing executeCommand method
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);

        // SADD returns an integer (number of elements added)
        if (!std.mem.startsWith(u8, response, ":")) return RedisError.InvalidResponse;
        const count = try std.fmt.parseInt(u64, response[1 .. response.len - 2], 10);
        if (count > 1) return RedisError.InvalidResponse; // SADD with one member should return 0 or 1
    }
};
