const std = @import("std");

const types = @import("types.zig");
pub const pool = @import("pool.zig");

pub const RedisError = types.RedisError;
pub const ResponseType = types.ResponseType;
pub const RedisClientConfig = types.RedisClientConfig;
pub const ScanResult = types.ScanResult;
pub const BufferPool = pool.BufferPool;

pub const RedisClient = struct {
    allocator: std.mem.Allocator,
    socket: std.net.Stream,
    connected: bool,
    last_used_timestamp: i64,
    config: RedisClientConfig,
    reconnect_attempts: u8 = 0,
    max_reconnect_attempts: u8 = 3,

    const Self = @This();

    pub fn isHealthy(self: *Self) bool {
        if (!self.connected) return false;

        // Check idle timeout
        const idle_time = std.time.milliTimestamp() - self.last_used_timestamp;
        if (idle_time > self.config.idle_timeout_ms) return false;

        // Try ping to verify connection
        const ping_response = self.ping() catch |err| {
            std.log.scoped(.redis_client).debug("Health check failed: {}", .{err});
            return false;
        };
        defer self.allocator.free(ping_response);

        // Check if ping response is "PONG"
        return std.mem.eql(u8, ping_response, "PONG");
    }

    pub fn disconnect(self: *Self) void {
        if (!self.connected) return; // Already disconnected

        self.socket.close();
        self.connected = false;
        self.last_used_timestamp = 0;
    }

    pub fn connect(allocator: std.mem.Allocator, config: RedisClientConfig) RedisError!Self {
        const socket = std.net.tcpConnectToHost(allocator, config.host, config.port) catch |err| {
            return switch (err) {
                error.ConnectionRefused => RedisError.ConnectionRefused,
                error.NetworkUnreachable, error.ConnectionTimedOut, error.ConnectionPending, error.ConnectionResetByPeer, error.SocketNotConnected, error.AddressInUse, error.AddressNotAvailable => RedisError.NetworkError,
                error.OutOfMemory => RedisError.OutOfMemory,
                else => RedisError.ConnectionFailed,
            };
        };

        var client = Self{
            .allocator = allocator,
            .socket = socket,
            .connected = true,
            .last_used_timestamp = std.time.milliTimestamp(),
            .config = config,
            .reconnect_attempts = 0,
            .max_reconnect_attempts = 3,
        };

        // Initial ping to verify connection
        const ping_response = client.ping() catch |err| {
            std.log.scoped(.redis_client).debug("Initial ping failed: {}", .{err});
            client.disconnect();
            return RedisError.ConnectionFailed;
        };
        client.allocator.free(ping_response);

        return client;
    }

    pub fn reconnect(self: *Self) RedisError!void {
        if (self.connected) self.disconnect();

        std.log.scoped(.redis_client).debug("Starting reconnect with max attempts: {d}", .{self.max_reconnect_attempts});

        while (self.reconnect_attempts < self.max_reconnect_attempts) : (self.reconnect_attempts += 1) {
            std.log.scoped(.redis_client).debug("Reconnection attempt {d}/{d}", .{ self.reconnect_attempts + 1, self.max_reconnect_attempts });
            self.socket = std.net.tcpConnectToHost(self.allocator, self.config.host, self.config.port) catch |err| switch (err) {
                error.ConnectionRefused => {
                    std.log.scoped(.redis_client).debug("Reconnection attempt {d}/{d} failed: ConnectionRefused", .{ self.reconnect_attempts + 1, self.max_reconnect_attempts });
                    if (self.reconnect_attempts + 1 == self.max_reconnect_attempts) return RedisError.ConnectionRefused;
                    std.time.sleep(std.time.ns_per_s);
                    continue;
                },
                error.NetworkUnreachable => {
                    std.log.scoped(.redis_client).debug("Reconnection attempt {d}/{d} failed: {}", .{ self.reconnect_attempts + 1, self.max_reconnect_attempts, err });
                    if (self.reconnect_attempts + 1 == self.max_reconnect_attempts) return RedisError.NetworkError;
                    std.time.sleep(std.time.ns_per_s);
                    continue;
                },
                error.OutOfMemory => return RedisError.OutOfMemory,
                else => {
                    std.log.scoped(.redis_client).debug("Reconnection attempt {d}/{d} failed: {}", .{ self.reconnect_attempts + 1, self.max_reconnect_attempts, err });
                    if (self.reconnect_attempts + 1 == self.max_reconnect_attempts) return RedisError.ReconnectFailed;
                    std.time.sleep(std.time.ns_per_s);
                    continue;
                },
            };

            self.connected = true;
            self.last_used_timestamp = std.time.milliTimestamp();
            self.reconnect_attempts = 0;
            std.log.scoped(.redis_client).debug("Reconnection succeeded after {d} attempts", .{self.reconnect_attempts + 1});
            return;
        }

        std.log.scoped(.redis_client).debug("All reconnection attempts failed after {d} tries", .{self.max_reconnect_attempts});
        return RedisError.ReconnectFailed;
    }

    pub fn auth(self: *Self, password: []const u8) RedisError!void {
        const cmd = self.formatCommand("*2\r\n$4\r\nAUTH\r\n${d}\r\n{s}\r\n", .{ password.len, password }) catch return RedisError.OutOfMemory;
        defer self.allocator.free(cmd);
        const response = self.executeCommand(cmd) catch |err| return switch (err) {
            error.OutOfMemory => RedisError.OutOfMemory,
            error.ConnectionFailed => RedisError.ConnectionFailed,
            error.NetworkError => RedisError.NetworkError,
            else => RedisError.NetworkError, // Fallback
        };
        defer self.allocator.free(response);
        if (!std.mem.eql(u8, response, "+OK\r\n")) return RedisError.AuthenticationFailed;
    }

    pub fn select(self: *Self, db: u32) RedisError!void {
        const cmd = self.formatCommand("*2\r\n$6\r\nSELECT\r\n${d}\r\n{d}\r\n", .{ std.fmt.count("{d}", .{db}), db }) catch return RedisError.OutOfMemory;
        defer self.allocator.free(cmd);
        const response = self.executeCommand(cmd) catch |err| return switch (err) {
            error.OutOfMemory => RedisError.OutOfMemory,
            error.ConnectionFailed => RedisError.ConnectionFailed,
            error.NetworkError => RedisError.NetworkError,
            else => RedisError.NetworkError, // Fallback
        };
        defer self.allocator.free(response);
        if (!std.mem.eql(u8, response, "+OK\r\n")) return RedisError.CommandFailed;
    }

    fn formatCommand(self: *Self, comptime fmt: []const u8, args: anytype) ![]u8 {
        return std.fmt.allocPrint(self.allocator, fmt, args);
    }

    fn executeCommand(self: *Self, cmd: []const u8) ![]const u8 {
        std.log.scoped(.redis_client).debug("[redis_client.executeCommand] Starting with command: '{s}'", .{cmd});

        if (!self.connected) {
            std.log.scoped(.redis_client).debug("[redis_client.executeCommand] No active connection detected", .{});
            std.log.scoped(.redis_client).debug("[redis_client.executeCommand] Attempting to reconnect", .{});
            try self.reconnect();
            std.log.scoped(.redis_client).debug("[redis_client.executeCommand] Reconnect completed", .{});
        }

        const start_time = std.time.milliTimestamp();
        std.log.scoped(.redis_client).debug("[redis_client.executeCommand] Start timestamp: {d}ms", .{start_time});

        var retry_count: u8 = 0;
        const max_retries: u8 = 3;
        std.log.scoped(.redis_client).debug("[redis_client.executeCommand] Max retries configured: {d}", .{max_retries});

        while (retry_count < max_retries) : (retry_count += 1) {
            std.log.scoped(.redis_client).debug("[redis_client.executeCommand] Attempt {d}/{d}", .{ retry_count + 1, max_retries });

            const current_time = std.time.milliTimestamp();
            const elapsed = current_time - start_time;
            std.log.scoped(.redis_client).debug("[redis_client.executeCommand] Elapsed time: {d}ms, timeout limit: {d}ms", .{ elapsed, self.config.read_timeout_ms });

            if (elapsed > self.config.read_timeout_ms) {
                std.log.scoped(.redis_client).debug("[redis_client.executeCommand] Timeout exceeded after {d}ms", .{elapsed});
                return RedisError.Timeout;
            }

            std.log.scoped(.redis_client).debug("[redis_client.executeCommand] Sending command", .{});
            self.sendCommand(cmd) catch |err| {
                std.log.scoped(.redis_client).debug("[redis_client.executeCommand] Send failed with error: {}", .{err});
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
                        std.log.scoped(.redis_client).debug("[redis_client.executeCommand] Connection error detected, attempting reconnect", .{});
                        self.reconnect() catch |reconnect_err| {
                            std.log.scoped(.redis_client).debug("[redis_client.executeCommand] Reconnect failed: {}", .{reconnect_err});
                            return reconnect_err;
                        };
                        std.log.scoped(.redis_client).debug("[redis_client.executeCommand] Reconnect successful, retrying", .{});
                        continue;
                    },
                    else => {
                        std.log.scoped(.redis_client).debug("[redis_client.executeCommand] Unrecoverable error, propagating: {}", .{err});
                        return err;
                    },
                }
            };

            std.log.scoped(.redis_client).debug("[redis_client.executeCommand] Command sent, reading response", .{});
            const response = self.readResponse() catch |err| {
                std.log.scoped(.redis_client).debug("[redis_client.executeCommand] Response read failed: {}", .{err});
                return err;
            };

            std.log.scoped(.redis_client).debug("[redis_client.executeCommand] Response received successfully, length: {d}", .{response.len});
            return response;
        }

        std.log.scoped(.redis_client).debug("[redis_client.executeCommand] Max retries ({d}) exhausted", .{max_retries});
        return RedisError.CommandFailed;
    }

    fn sendCommand(self: *Self, cmd: []const u8) !void {
        if (!self.connected) return RedisError.DisconnectedClient;
        self.last_used_timestamp = std.time.milliTimestamp();
        try self.socket.writer().writeAll(cmd);
    }

    fn readResponse(self: *Self) ![]const u8 {
        std.log.scoped(.redis_client).debug("[redis_client.readResponse] Starting response read", .{});

        var buffer = std.ArrayList(u8).init(self.allocator);
        errdefer {
            std.log.scoped(.redis_client).debug("[redis_client.readResponse] Error occurred, cleaning up buffer", .{});
            buffer.deinit();
        }

        std.log.scoped(.redis_client).debug("[redis_client.readResponse] Getting socket reader", .{});
        const reader = self.socket.reader();

        std.log.scoped(.redis_client).debug("[redis_client.readResponse] Reading response type", .{});
        const response_type = self.readResponseType(&buffer, reader) catch |err| {
            std.log.scoped(.redis_client).debug("[redis_client.readResponse] Failed to read response type: {}", .{err});
            std.log.scoped(.redis_client).debug("[redis_client.readResponse] Current buffer content: '{s}'", .{buffer.items});
            return err;
        };
        std.log.scoped(.redis_client).debug("[redis_client.readResponse] Response type received: '{}'", .{response_type});

        std.log.scoped(.redis_client).debug("[redis_client.readResponse] Parsing response with type '{}'", .{response_type});
        self.parseResponse(&buffer, reader, response_type) catch |err| {
            std.log.scoped(.redis_client).debug("[redis_client.readResponse] Failed to parse response: {}", .{err});
            std.log.scoped(.redis_client).debug("[redis_client.readResponse] Buffer content at failure: '{s}'", .{buffer.items});
            return err;
        };
        std.log.scoped(.redis_client).debug("[redis_client.readResponse] Response parsing completed successfully", .{});

        const result = buffer.toOwnedSlice() catch |err| {
            std.log.scoped(.redis_client).debug("[redis_client.readResponse] Failed to convert buffer to slice: {}", .{err});
            return err;
        };
        std.log.scoped(.redis_client).debug("[redis_client.readResponse] Returning response, length: {d}", .{result.len});

        return result;
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
        std.log.scoped(.redis_client).debug("[redis_client.parseResponse] Starting with type: '{s}'", .{@tagName(response_type)});
        std.log.scoped(.redis_client).debug("[redis_client.parseResponse] Initial buffer: '{s}'", .{buffer.items});

        switch (response_type) {
            .SimpleString => {
                std.log.scoped(.redis_client).debug("[redis_client.parseResponse] Parsing SimpleString", .{});
                try self.readLine(buffer, reader);
                std.log.scoped(.redis_client).debug("[redis_client.parseResponse] SimpleString parsed, buffer now: '{s}'", .{buffer.items});
            },
            .Error => {
                std.log.scoped(.redis_client).debug("[redis_client.parseResponse] Parsing Error", .{});
                try self.readLine(buffer, reader);
                std.log.scoped(.redis_client).debug("[redis_client.parseResponse] Error parsed, buffer now: '{s}'", .{buffer.items});
            },
            .Integer => {
                std.log.scoped(.redis_client).debug("[redis_client.parseResponse] Parsing Integer", .{});
                try self.readLine(buffer, reader);
                std.log.scoped(.redis_client).debug("[redis_client.parseResponse] Integer parsed, buffer now: '{s}'", .{buffer.items});
            },
            .BulkString => {
                std.log.scoped(.redis_client).debug("[redis_client.parseResponse] Parsing BulkString", .{});
                try self.readBulkString(buffer, reader);
                std.log.scoped(.redis_client).debug("[redis_client.parseResponse] BulkString parsed, buffer now: '{s}'", .{buffer.items});
            },
            .Array => {
                std.log.scoped(.redis_client).debug("[redis_client.parseResponse] Parsing Array", .{});
                try self.readArray(buffer, reader);
                std.log.scoped(.redis_client).debug("[redis_client.parseResponse] Array parsed, buffer now: '{s}'", .{buffer.items});
            },
        }
        std.log.scoped(.redis_client).debug("[redis_client.parseResponse] Parsing completed successfully", .{});
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
        std.log.scoped(.redis_client).debug("[redis_client.readBulkString] Starting, initial buffer: '{s}'", .{buffer.items});

        try self.readLine(buffer, reader);
        std.log.scoped(.redis_client).debug("[redis_client.readBulkString] Length line read, buffer now: '{s}'", .{buffer.items});

        // Find the '$' to start parsing the length
        const dollar_pos = std.mem.lastIndexOfScalar(u8, buffer.items, '$') orelse {
            std.log.scoped(.redis_client).debug("[redis_client.readBulkString] No '$' found in buffer", .{});
            return RedisError.InvalidResponse;
        };
        const line = buffer.items[dollar_pos + 1 ..];
        const len_end = std.mem.indexOf(u8, line, "\r") orelse {
            std.log.scoped(.redis_client).debug("[redis_client.readBulkString] No \\r found in length line", .{});
            return RedisError.InvalidResponse;
        };
        std.log.scoped(.redis_client).debug("[redis_client.readBulkString] Length end at position {d}, line: '{s}'", .{ len_end, line });

        const length = std.fmt.parseInt(i64, line[0..len_end], 10) catch |err| switch (err) {
            error.Overflow => return RedisError.Overflow,
            error.InvalidCharacter => return RedisError.InvalidFormat,
        };
        std.log.scoped(.redis_client).debug("[redis_client.readBulkString] Parsed length: {d}", .{length});

        if (length == -1) {
            std.log.scoped(.redis_client).debug("[redis_client.readBulkString] Length is -1 (null), returning", .{});
            return;
        }

        if (length < 0) {
            std.log.scoped(.redis_client).debug("[redis_client.readBulkString] Invalid negative length: {d}", .{length});
            return RedisError.InvalidResponse;
        }

        const length_usize: usize = @intCast(length); // Convert i64 to usize safely
        const total_len: usize = length_usize + 2;
        std.log.scoped(.redis_client).debug("[redis_client.readBulkString] Allocating buffer for {d} bytes + \\r\\n", .{length});
        const data = try self.allocator.alloc(u8, total_len);
        defer self.allocator.free(data);

        std.log.scoped(.redis_client).debug("[redis_client.readBulkString] Reading {d} bytes", .{total_len});
        const bytes_read = reader.readAll(data) catch |err| switch (err) {
            error.InputOutput => return RedisError.InputOutput,
            error.SystemResources => return RedisError.SystemResources,
            error.SocketNotConnected => return RedisError.SocketNotConnected,
            error.ConnectionTimedOut => return RedisError.Timeout,
            error.BrokenPipe, error.ConnectionResetByPeer => return RedisError.NetworkError,
            else => {
                std.log.scoped(.redis_client).debug("[redis_client.readBulkString] Unexpected read error: {s}", .{@errorName(err)});
                return RedisError.NetworkError;
            },
        };
        std.log.scoped(.redis_client).debug("[redis_client.readBulkString] Read {d} bytes", .{bytes_read});

        if (bytes_read != total_len) {
            std.log.scoped(.redis_client).debug("[redis_client.readBulkString] Incomplete read: expected {d}, got {d}", .{ total_len, bytes_read });
            return RedisError.InvalidResponse;
        }

        if (data[length_usize] != '\r' or data[length_usize + 1] != '\n') {
            std.log.scoped(.redis_client).debug("[redis_client.readBulkString] Invalid terminator: '{c}', '{c}'", .{ data[length_usize], data[length_usize + 1] });
            return RedisError.InvalidResponse;
        }

        try buffer.appendSlice(data);
        std.log.scoped(.redis_client).debug("[redis_client.readBulkString] Bulk string completed, final buffer: '{s}'", .{buffer.items});
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

        // Parse response properly instead of assuming PONG
        if (!std.mem.startsWith(u8, response, "+")) return RedisError.InvalidResponse;
        return try self.allocator.dupe(u8, response[1 .. response.len - 2]); // Strip +OK\r\n
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

            // Safe parsing of length
            const len_end = std.mem.indexOf(u8, response, "\r\n") orelse return RedisError.InvalidResponse;
            if (len_end >= response.len - 2) return RedisError.InvalidResponse;

            const len = try std.fmt.parseInt(usize, response[1..len_end], 10);
            const value_start = len_end + 2;
            const value_end = value_start + len;

            // Bounds checking
            if (value_end > response.len - 2) return RedisError.InvalidResponse;
            if (response[value_end] != '\r' or response[value_end + 1] != '\n') return RedisError.InvalidResponse;

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
        // Add validation
        if (key.len == 0 or value.len == 0) return RedisError.InvalidArgument;
        if (ttl_seconds <= 0) return RedisError.InvalidArgument;

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
        std.log.scoped(.redis_client).debug("[redis_client.sMembers] Function started with key: '{s}'", .{key});
        if (key.len == 0) {
            std.log.scoped(.redis_client).debug("[redis_client.sMembers] Empty key detected, returning InvalidArgument", .{});
            return RedisError.InvalidArgument;
        }

        // Format SMEMBERS command
        std.log.scoped(.redis_client).debug("[redis_client.sMembers] Formatting SMEMBERS command", .{});
        const cmd = try self.formatCommand("*2\r\n$8\r\nSMEMBERS\r\n${d}\r\n{s}\r\n", .{ key.len, key });
        defer self.allocator.free(cmd);

        std.log.scoped(.redis_client).debug("[redis_client.sMembers] Formatted command: '{s}'", .{cmd});
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);

        std.log.scoped(.redis_client).debug("[redis_client.sMembers] Raw response received: '{s}', length: {d}", .{ response, response.len });

        // Basic handling for simple empty responses
        if (std.mem.eql(u8, response, "*0")) {
            std.log.scoped(.redis_client).debug("[redis_client.sMembers] Empty set response (*0) received, returning null", .{});
            return null;
        }

        // Handle array response
        if (response[0] == '*') {
            std.log.scoped(.redis_client).debug("[redis_client.sMembers] Processing array response", .{});
            var strings = std.ArrayList([]const u8).init(self.allocator);
            errdefer {
                std.log.scoped(.redis_client).debug("[redis_client.sMembers] Error cleanup: freeing {d} strings", .{strings.items.len});
                for (strings.items) |item| {
                    self.allocator.free(item);
                }
                strings.deinit();
            }

            // Parse number of elements
            const len_end = std.mem.indexOf(u8, response[1..], "\r\n") orelse {
                std.log.scoped(.redis_client).debug("[redis_client.sMembers] Invalid response: no \\r\\n found after '*'", .{});
                return RedisError.InvalidResponse;
            };

            const num_elements_str = response[1 .. 1 + len_end];
            std.log.scoped(.redis_client).debug("[redis_client.sMembers] Parsing element count from: '{s}'", .{num_elements_str});

            const num_elements = try std.fmt.parseInt(i64, num_elements_str, 10);
            std.log.scoped(.redis_client).debug("[redis_client.sMembers] Parsed number of elements: {d}", .{num_elements});

            if (num_elements == 0) {
                std.log.scoped(.redis_client).debug("[redis_client.sMembers] Zero elements in set, returning null", .{});
                return null;
            }
            if (num_elements == -1) {
                std.log.scoped(.redis_client).debug("[redis_client.sMembers] Negative element count (-1), returning null", .{});
                return null;
            }

            var current_pos: usize = len_end + 3;
            var i: i64 = 0;

            std.log.scoped(.redis_client).debug("[redis_client.sMembers] Starting to parse {d} elements at position {d}", .{ num_elements, current_pos });
            while (i < num_elements) : (i += 1) {
                std.log.scoped(.redis_client).debug("[redis_client.sMembers] Processing element {d}/{d} at position {d}", .{ i + 1, num_elements, current_pos });

                if (response[current_pos] != '$') {
                    std.log.scoped(.redis_client).debug("[redis_client.sMembers] Invalid element format: expected '$' at position {d}", .{current_pos});
                    return RedisError.InvalidResponse;
                }

                const str_len_end = std.mem.indexOf(u8, response[current_pos + 1 ..], "\r\n") orelse {
                    std.log.scoped(.redis_client).debug("[redis_client.sMembers] Invalid element: no length delimiter found", .{});
                    return RedisError.InvalidResponse;
                };

                const str_len = try std.fmt.parseInt(usize, response[current_pos + 1 .. current_pos + 1 + str_len_end], 10);
                std.log.scoped(.redis_client).debug("[redis_client.sMembers] Element length: {d}", .{str_len});

                current_pos += str_len_end + 3;
                const string = response[current_pos .. current_pos + str_len];
                std.log.scoped(.redis_client).debug("[redis_client.sMembers] Extracted element: '{s}'", .{string});

                try strings.append(try self.allocator.dupe(u8, string));
                current_pos += str_len + 2;
            }

            std.log.scoped(.redis_client).debug("[redis_client.sMembers] Successfully parsed all elements, converting to slice", .{});
            const result = try strings.toOwnedSlice();
            std.log.scoped(.redis_client).debug("[redis_client.sMembers] Returning {d} elements", .{result.len});
            return result;
        }

        std.log.scoped(.redis_client).debug("[redis_client.sMembers] Unrecognized response format, returning null", .{});
        return null;
    }

    pub fn sAdd(self: *Self, key: []const u8, member: []const u8) !u64 {
        if (key.len == 0 or member.len == 0) return RedisError.InvalidArgument;

        // Format SADD command using the existing formatCommand method
        const cmd = try self.formatCommand("*3\r\n$4\r\nSADD\r\n${d}\r\n{s}\r\n${d}\r\n{s}\r\n", .{ key.len, key, member.len, member });
        defer self.allocator.free(cmd);

        // Use the existing executeCommand method
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);

        // SADD returns an integer (number of elements added)
        if (!std.mem.startsWith(u8, response, ":")) return RedisError.InvalidResponse;
        return try std.fmt.parseInt(u64, response[1 .. response.len - 2], 10);
    }

    pub fn sRem(self: *Self, key: []const u8, member: []const u8) !u64 {
        if (key.len == 0 or member.len == 0) return RedisError.InvalidArgument;

        // Format SREM command
        const cmd = try self.formatCommand("*3\r\n$4\r\nSREM\r\n${d}\r\n{s}\r\n${d}\r\n{s}\r\n", .{ key.len, key, member.len, member });
        defer self.allocator.free(cmd);

        // Execute the command
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);

        // SREM returns an integer (number of elements removed)
        if (!std.mem.startsWith(u8, response, ":")) return RedisError.InvalidResponse;
        return try std.fmt.parseInt(u64, response[1 .. response.len - 2], 10);
    }

    pub fn scan(self: *RedisClient, cursor: []const u8, match_pattern: ?[]const u8, count: ?u32) !ScanResult {
        std.log.scoped(.redis_client).debug("[redis_client.scan] Starting with cursor: '{s}'", .{cursor});

        // Build the command
        var cmd_builder = std.ArrayList(u8).init(self.allocator);
        defer cmd_builder.deinit();

        // Start with the command array header
        var num_args: usize = 2; // SCAN + cursor
        if (match_pattern != null) num_args += 2; // MATCH + pattern
        if (count != null) num_args += 2; // COUNT + value

        try std.fmt.format(cmd_builder.writer(), "*{d}\r\n$4\r\nSCAN\r\n${d}\r\n{s}\r\n", .{ num_args, cursor.len, cursor });

        // Add MATCH if specified
        if (match_pattern) |pattern| {
            try std.fmt.format(cmd_builder.writer(), "$5\r\nMATCH\r\n${d}\r\n{s}\r\n", .{ pattern.len, pattern });
        }

        // Add COUNT if specified
        if (count) |c| {
            const count_str = try std.fmt.allocPrint(self.allocator, "{d}", .{c});
            defer self.allocator.free(count_str);
            try std.fmt.format(cmd_builder.writer(), "$5\r\nCOUNT\r\n${d}\r\n{s}\r\n", .{ count_str.len, count_str });
        }

        const cmd = try cmd_builder.toOwnedSlice();
        defer self.allocator.free(cmd);

        std.log.scoped(.redis_client).debug("[redis_client.scan] Executing command: '{s}'", .{cmd});
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);

        std.log.scoped(.redis_client).debug("[redis_client.scan] Response received: '{s}'", .{response});

        // SCAN returns an array with two elements:
        // 1. The new cursor
        // 2. An array of keys
        if (response.len == 0 or response[0] != '*') {
            std.log.scoped(.redis_client).debug("[redis_client.scan] Invalid response format: expected '*'", .{});
            return RedisError.InvalidResponse;
        }

        // Parse the array size (should be 2)
        const array_size_end = std.mem.indexOf(u8, response[1..], "\r\n") orelse {
            std.log.scoped(.redis_client).debug("[redis_client.scan] Invalid response: cannot find array size delimiter", .{});
            return RedisError.InvalidResponse;
        };

        const array_size = try std.fmt.parseInt(usize, response[1 .. 1 + array_size_end], 10);
        if (array_size != 2) {
            std.log.scoped(.redis_client).debug("[redis_client.scan] Invalid response: expected array size 2, got {d}", .{array_size});
            return RedisError.InvalidResponse;
        }

        var pos = 1 + array_size_end + 2; // Skip *2\r\n
        if (pos >= response.len) {
            return RedisError.InvalidResponse;
        }

        // Parse the first element (new cursor)
        if (response[pos] != '$') {
            std.log.scoped(.redis_client).debug("[redis_client.scan] Invalid response: expected '$' for cursor", .{});
            return RedisError.InvalidResponse;
        }

        const cursor_len_end = std.mem.indexOf(u8, response[pos + 1 ..], "\r\n") orelse return RedisError.InvalidResponse;
        const cursor_len = try std.fmt.parseInt(usize, response[pos + 1 .. pos + 1 + cursor_len_end], 10);
        pos += 1 + cursor_len_end + 2; // Skip $len\r\n

        if (pos + cursor_len > response.len) {
            return RedisError.InvalidResponse;
        }

        const new_cursor = try self.allocator.dupe(u8, response[pos .. pos + cursor_len]);
        errdefer self.allocator.free(new_cursor);
        pos += cursor_len + 2; // Skip cursor\r\n

        if (pos >= response.len) {
            return RedisError.InvalidResponse;
        }

        // Parse the second element (array of keys)
        if (response[pos] != '*') {
            std.log.scoped(.redis_client).debug("[redis_client.scan] Invalid response: expected '*' for keys array", .{});
            return RedisError.InvalidResponse;
        }

        const keys_count_end = std.mem.indexOf(u8, response[pos + 1 ..], "\r\n") orelse {
            std.log.scoped(.redis_client).debug("[redis_client.scan] Invalid response: cannot find keys count delimiter", .{});
            return RedisError.InvalidResponse;
        };

        const keys_count = try std.fmt.parseInt(usize, response[pos + 1 .. pos + 1 + keys_count_end], 10);
        pos += 1 + keys_count_end + 2; // Skip *count\r\n

        std.log.scoped(.redis_client).debug("[redis_client.scan] Found {d} keys", .{keys_count});

        var keys = std.ArrayList([]const u8).init(self.allocator);
        errdefer {
            for (keys.items) |key| {
                self.allocator.free(key);
            }
            keys.deinit();
        }

        // Count actual keys in the response (may be fewer than reported)
        var i: usize = 0;
        var current_pos = pos;

        while (i < keys_count and current_pos < response.len) {
            if (response[current_pos] != '$') {
                std.log.scoped(.redis_client).debug("[redis_client.scan] Invalid response format at key {d}", .{i});
                break;
            }

            const key_len_end = std.mem.indexOf(u8, response[current_pos + 1 ..], "\r\n") orelse break;
            const key_len = std.fmt.parseInt(usize, response[current_pos + 1 .. current_pos + 1 + key_len_end], 10) catch break;

            current_pos += 1 + key_len_end + 2; // Skip $len\r\n
            if (current_pos + key_len + 2 > response.len) break;

            current_pos += key_len + 2; // Skip key\r\n
            i += 1;
        }

        const actual_keys_count = i;
        std.log.scoped(.redis_client).debug("[redis_client.scan] Found {d} actual keys in response (expected {d})", .{ actual_keys_count, keys_count });

        // Now parse the keys we know are actually there
        i = 0;
        while (i < actual_keys_count) : (i += 1) {
            if (response[pos] != '$') {
                std.log.scoped(.redis_client).debug("[redis_client.scan] Invalid response: expected '$' for key {d}", .{i});
                break;
            }

            const key_len_end = std.mem.indexOf(u8, response[pos + 1 ..], "\r\n") orelse {
                std.log.scoped(.redis_client).debug("[redis_client.scan] Invalid response: cannot find key length delimiter for key {d}", .{i});
                break;
            };

            const key_len = try std.fmt.parseInt(usize, response[pos + 1 .. pos + 1 + key_len_end], 10);
            pos += 1 + key_len_end + 2; // Skip $len\r\n

            if (pos + key_len > response.len) {
                std.log.scoped(.redis_client).debug("[redis_client.scan] Key {d} extends beyond response", .{i});
                break;
            }

            const key = try self.allocator.dupe(u8, response[pos .. pos + key_len]);
            try keys.append(key);
            pos += key_len + 2; // Skip key\r\n
        }

        std.log.scoped(.redis_client).debug("[redis_client.scan] Successfully processed response, new cursor: '{s}', keys: {d}", .{ new_cursor, keys.items.len });
        return ScanResult{
            .cursor = new_cursor,
            .keys = try keys.toOwnedSlice(),
        };
    }

    /// Higher-level SCAN function that iterates through all matching keys
    pub fn scanAll(self: *RedisClient, match_pattern: ?[]const u8, count: ?u32) ![][]const u8 {
        std.log.scoped(.redis_client).debug("[redis_client.scanAll] Starting with pattern: '{s}', count: {?}", .{ match_pattern orelse "null", count });

        var all_keys = std.ArrayList([]const u8).init(self.allocator);
        errdefer {
            for (all_keys.items) |key| {
                self.allocator.free(key);
            }
            all_keys.deinit();
        }

        var cursor = try self.allocator.dupe(u8, "0");
        defer self.allocator.free(cursor);

        var done = false;
        while (!done) {
            std.log.scoped(.redis_client).debug("[redis_client.scanAll] Scanning with cursor: '{s}'", .{cursor});

            const scan_result = try self.scan(cursor, match_pattern, count);
            self.allocator.free(cursor);

            // Update cursor for next iteration
            cursor = scan_result[0];
            const batch_keys = scan_result[1];
            defer {
                // Free the batch keys from this iteration
                for (batch_keys) |key| {
                    self.allocator.free(key);
                }
                self.allocator.free(batch_keys);
            }

            // Add keys to the result array
            for (batch_keys) |key| {
                try all_keys.append(try self.allocator.dupe(u8, key));
            }

            // Check if we've completed the scan
            if (std.mem.eql(u8, cursor, "0")) {
                done = true;
            }
        }

        std.log.scoped(.redis_client).debug("[redis_client.scanAll] Completed scan with {d} keys found", .{all_keys.items.len});
        return all_keys.toOwnedSlice();
    }
};
