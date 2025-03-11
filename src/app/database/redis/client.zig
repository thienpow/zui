const std = @import("std");

const types = @import("types.zig");
pub const pool = @import("pool.zig");
pub const buffer_pool = @import("buffer_pool.zig");

pub const RedisError = types.RedisError;
pub const ResponseType = types.ResponseType;
pub const RedisClientConfig = types.RedisClientConfig;
pub const ScanResult = types.ScanResult;
pub const BufferPool = buffer_pool.BufferPool;

pub const RedisClient = struct {
    allocator: std.mem.Allocator,
    socket: std.net.Stream,
    connected: bool,
    last_used_timestamp: i64,
    config: RedisClientConfig,
    reconnect_attempts: u8 = 0,
    max_reconnect_attempts: u8 = 3,

    const Self = @This();

    /// Checks if the client connection is healthy
    pub fn isHealthy(self: *Self) bool {
        if (!self.connected) return false;

        const idle_time = std.time.milliTimestamp() - self.last_used_timestamp;
        if (idle_time > self.config.idle_timeout_ms) return false;

        const ping_response = self.ping() catch |err| {
            std.log.scoped(.redis_client).debug("Health check failed: {}", .{err});
            return false;
        };
        defer self.allocator.free(ping_response);

        return std.mem.eql(u8, ping_response, "PONG");
    }

    /// Disconnects the client and cleans up resources
    pub fn disconnect(self: *Self) void {
        if (!self.connected) return;
        self.socket.close();
        self.connected = false;
        self.last_used_timestamp = 0;
    }

    /// Establishes a new connection to Redis
    pub fn connect(allocator: std.mem.Allocator, config: RedisClientConfig) RedisError!Self {
        buffer_pool.initGlobalPool(allocator, 16, 4096) catch |err| switch (err) {
            error.AlreadyInitialized => {}, // Ignore if already initialized
            error.OutOfMemory => return RedisError.OutOfMemory, // Map to RedisError
            //else => return RedisError.ConnectionFailed, // Fallback for unexpected errors
        };

        const socket = std.net.tcpConnectToHost(allocator, config.host, config.port) catch |err| {
            return switch (err) {
                error.ConnectionRefused => RedisError.ConnectionRefused,
                error.NetworkUnreachable, error.ConnectionTimedOut => RedisError.NetworkError,
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
        };

        const ping_response = client.ping() catch |err| {
            std.log.scoped(.redis_client).debug("Initial ping failed: {}", .{err});
            client.disconnect();
            return RedisError.ConnectionFailed;
        };
        defer client.allocator.free(ping_response);
        if (!std.mem.eql(u8, ping_response, "PONG")) {
            client.disconnect();
            return RedisError.ConnectionFailed;
        }

        return client;
    }

    /// Attempts to reconnect to Redis
    pub fn reconnect(self: *Self) RedisError!void {
        if (self.connected) self.disconnect();

        std.log.scoped(.redis_client).debug("Starting reconnect with max attempts: {d}", .{self.max_reconnect_attempts});

        while (self.reconnect_attempts < self.max_reconnect_attempts) : (self.reconnect_attempts += 1) {
            std.log.scoped(.redis_client).debug("Reconnection attempt {d}/{d}", .{ self.reconnect_attempts + 1, self.max_reconnect_attempts });
            self.socket = std.net.tcpConnectToHost(self.allocator, self.config.host, self.config.port) catch |err| {
                if (self.reconnect_attempts + 1 == self.max_reconnect_attempts) {
                    return switch (err) {
                        error.ConnectionRefused => RedisError.ConnectionRefused,
                        error.NetworkUnreachable => RedisError.NetworkError,
                        error.OutOfMemory => RedisError.OutOfMemory,
                        else => RedisError.ReconnectFailed,
                    };
                }
                std.time.sleep(std.time.ns_per_s);
                continue;
            };

            self.connected = true;
            self.last_used_timestamp = std.time.milliTimestamp();
            self.reconnect_attempts = 0;
            return;
        }

        self.connected = false;
        return RedisError.ReconnectFailed;
    }

    /// Authenticates with the Redis server
    pub fn auth(self: *Self, password: []const u8) RedisError!void {
        const cmd = self.formatCommand("*2\r\n$4\r\nAUTH\r\n${d}\r\n{s}\r\n", .{ password.len, password }) catch |err| switch (err) {
            error.OutOfMemory => return RedisError.OutOfMemory, // Explicitly handle OOM
            else => return RedisError.AuthenticationFailed, // Map all other errors to a sensible default
        };
        defer self.allocator.free(cmd);

        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);

        if (response.len == 0 or response[0] != '+') {
            return RedisError.AuthenticationFailed;
        }
    }

    /// Selects a Redis database
    pub fn select(self: *Self, db: u32) RedisError!void {
        const cmd = try self.formatCommand("*2\r\n$6\r\nSELECT\r\n${d}\r\n{d}\r\n", .{ std.fmt.count("{d}", .{db}), db });
        defer self.allocator.free(cmd);
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);
        if (!std.mem.eql(u8, response, "+OK\r\n")) return RedisError.CommandFailed;
    }

    fn formatCommand(self: *Self, comptime fmt: []const u8, args: anytype) ![]u8 {
        if (buffer_pool.getGlobalPool()) |bpool| {
            const buf = try bpool.acquire();
            errdefer bpool.release(buf);
            const result = std.fmt.bufPrint(buf, fmt, args) catch {
                bpool.release(buf);
                return RedisError.OutOfMemory;
            };
            const owned = try self.allocator.dupe(u8, result);
            bpool.release(buf);
            return owned;
        } else {
            return std.fmt.allocPrint(self.allocator, fmt, args) catch return RedisError.OutOfMemory;
        }
    }

    fn executeCommand(self: *Self, cmd: []const u8) RedisError![]const u8 {
        if (!self.connected) try self.reconnect();

        const start_time = std.time.milliTimestamp();
        var retry_count: u8 = 0;
        const max_retries: u8 = 3;

        while (retry_count < max_retries) : (retry_count += 1) {
            const elapsed = std.time.milliTimestamp() - start_time;
            if (elapsed > self.config.read_timeout_ms) return RedisError.Timeout;

            try self.sendCommand(cmd);
            var buffer = std.ArrayList(u8).initCapacity(self.allocator, 1024) catch return RedisError.OutOfMemory; // Pre-allocate 1KB
            errdefer buffer.deinit();

            const response_type = try self.readResponseType(&buffer, self.socket.reader());
            try self.parseResponse(&buffer, self.socket.reader(), response_type);

            const response = try buffer.toOwnedSlice();
            if (cmd.len >= 7 and std.mem.startsWith(u8, cmd, "*2\r\n$3\r\nTTL\r\n") and response.len > 0 and response[0] != ':') {
                self.allocator.free(response);
                try self.reconnect();
                continue;
            }
            return response;
        }
        return RedisError.CommandFailed;
    }

    fn sendCommand(self: *Self, cmd: []const u8) !void {
        if (!self.connected) return error.DisconnectedClient;
        self.last_used_timestamp = std.time.milliTimestamp();
        self.socket.writer().writeAll(cmd) catch |err| switch (err) {
            error.ConnectionResetByPeer, error.BrokenPipe => return RedisError.NetworkError,
            error.WouldBlock => return RedisError.WouldBlock,
            error.SystemResources, error.NoSpaceLeft, error.DiskQuota, error.FileTooBig, error.InputOutput, error.DeviceBusy => return RedisError.SystemResources,
            error.NotOpenForWriting, error.AccessDenied => return RedisError.DisconnectedClient,
            else => return RedisError.NetworkError, // Handle Unexpected and other errors
        };
    }

    fn readResponse(self: *Self) RedisError![]const u8 {
        var buffer = std.ArrayList(u8).init(self.allocator);
        errdefer buffer.deinit();

        const reader = self.socket.reader();
        const response_type = try self.readResponseType(&buffer, reader);
        try self.parseResponse(&buffer, reader, response_type);

        return buffer.toOwnedSlice() catch RedisError.OutOfMemory;
    }

    fn readResponseType(_: *Self, buffer: *std.ArrayList(u8), reader: anytype) RedisError!ResponseType {
        const first_byte = reader.readByte() catch |err| switch (err) {
            error.WouldBlock => return RedisError.WouldBlock,
            error.ConnectionTimedOut => return RedisError.Timeout,
            error.ConnectionResetByPeer, error.BrokenPipe => return RedisError.NetworkError,
            error.InputOutput, error.SystemResources => return RedisError.SystemResources,
            error.EndOfStream => return RedisError.EndOfStream,
            error.SocketNotConnected => return RedisError.SocketNotConnected,
            else => return RedisError.InvalidResponse,
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

    fn readLine(self: *Self, buffer: *std.ArrayList(u8), reader: anytype) RedisError!void {
        const start_time = std.time.milliTimestamp();
        while (true) {
            if (std.time.milliTimestamp() - start_time > self.config.read_timeout_ms) {
                return RedisError.Timeout;
            }
            const byte = reader.readByte() catch |err| switch (err) {
                error.WouldBlock => return RedisError.WouldBlock,
                error.ConnectionTimedOut => return RedisError.Timeout,
                error.ConnectionResetByPeer, error.BrokenPipe => return RedisError.NetworkError,
                error.InputOutput, error.SystemResources => return RedisError.SystemResources,
                error.EndOfStream => return RedisError.EndOfStream,
                error.SocketNotConnected => return RedisError.SocketNotConnected,
                else => return RedisError.InvalidResponse,
            };
            try buffer.append(byte);
            if (byte == '\n' and buffer.items.len >= 2 and buffer.items[buffer.items.len - 2] == '\r') {
                break;
            }
        }
    }

    fn readBulkString(self: *Self, buffer: *std.ArrayList(u8), reader: anytype) !void {
        try self.readLine(buffer, reader);

        const dollar_pos = std.mem.lastIndexOfScalar(u8, buffer.items, '$') orelse return RedisError.InvalidResponse;
        const line = buffer.items[dollar_pos + 1 ..];
        const len_end = std.mem.indexOf(u8, line, "\r") orelse return RedisError.InvalidResponse;

        const length = std.fmt.parseInt(i64, line[0..len_end], 10) catch |err| switch (err) {
            error.InvalidCharacter => return RedisError.InvalidFormat,
            error.Overflow => return RedisError.Overflow,
        };
        if (length == -1) return;
        if (length < 0) return RedisError.InvalidResponse;
        if (length > std.math.maxInt(usize)) return RedisError.Overflow;

        const length_usize: usize = @intCast(length);
        const total_len: usize = length_usize + 2;
        const data = try self.allocator.alloc(u8, total_len);
        defer self.allocator.free(data);

        const bytes_read = reader.readAll(data) catch |err| switch (err) {
            error.WouldBlock => return RedisError.WouldBlock,
            error.ConnectionTimedOut => return RedisError.Timeout,
            error.ConnectionResetByPeer, error.BrokenPipe => return RedisError.NetworkError,
            error.InputOutput, error.SystemResources, error.AccessDenied, error.LockViolation => return RedisError.SystemResources,
            error.SocketNotConnected => return RedisError.SocketNotConnected,
            error.NotOpenForReading => return RedisError.DisconnectedClient,
            else => return RedisError.NetworkError, // Handle Unexpected and other errors
        };
        if (bytes_read != total_len) return RedisError.InvalidResponse;
        if (data[length_usize] != '\r' or data[length_usize + 1] != '\n') return RedisError.InvalidResponse;

        try buffer.appendSlice(data);
    }

    fn readArray(self: *Self, buffer: *std.ArrayList(u8), reader: anytype) RedisError!void {
        try self.readLine(buffer, reader);

        const line = buffer.items[1..];
        const len_end = std.mem.indexOf(u8, line, "\r") orelse return RedisError.InvalidResponse;
        const num_elements = std.fmt.parseInt(i64, line[0..len_end], 10) catch |err| switch (err) {
            error.InvalidCharacter => return RedisError.InvalidFormat,
            error.Overflow => return RedisError.Overflow,
        };

        if (num_elements == -1) return;

        var i: i64 = 0;
        while (i < num_elements) : (i += 1) {
            const element_type = try self.readResponseType(buffer, reader);
            try self.parseResponse(buffer, reader, element_type);
        }
    }

    /// Sends a PING command and returns the response
    pub fn ping(self: *Self) ![]const u8 {
        const cmd = "PING\r\n";
        const response = try self.executeCommand(cmd);
        if (!std.mem.startsWith(u8, response, "+")) {
            self.allocator.free(response);
            return RedisError.InvalidResponse;
        }
        const result = try self.allocator.dupe(u8, response[1 .. response.len - 2]);
        self.allocator.free(response);
        return result;
    }

    /// Sets a key-value pair
    pub fn set(self: *Self, key: []const u8, value: []const u8) !void {
        if (key.len == 0 or value.len == 0) return RedisError.InvalidArgument;
        const cmd = try self.formatCommand("*3\r\n$3\r\nSET\r\n${d}\r\n{s}\r\n${d}\r\n{s}\r\n", .{ key.len, key, value.len, value });
        defer self.allocator.free(cmd);
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);
        if (!std.mem.eql(u8, response, "+OK\r\n")) return RedisError.SetFailed;
    }

    /// Gets a value by key
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
            if (value_end > response.len - 2) return RedisError.InvalidResponse;
            return try self.allocator.dupe(u8, response[value_start..value_end]);
        }
        return RedisError.InvalidResponse;
    }

    /// Deletes a key
    pub fn del(self: *Self, key: []const u8) !u64 {
        if (key.len == 0) return RedisError.InvalidArgument;
        const cmd = try self.formatCommand("*2\r\n$3\r\nDEL\r\n${d}\r\n{s}\r\n", .{ key.len, key });
        defer self.allocator.free(cmd);
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);
        if (!std.mem.startsWith(u8, response, ":")) return RedisError.InvalidResponse;
        return try std.fmt.parseInt(u64, response[1 .. response.len - 2], 10);
    }

    /// Checks if a key exists in Redis
    pub fn exists(self: *Self, key: []const u8) !u64 {
        if (key.len == 0) return RedisError.InvalidArgument;
        const cmd = try self.formatCommand("*2\r\n$6\r\nEXISTS\r\n${d}\r\n{s}\r\n", .{ key.len, key });
        defer self.allocator.free(cmd);
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);
        if (!std.mem.startsWith(u8, response, ":")) return RedisError.InvalidResponse;
        return try std.fmt.parseInt(u64, response[1 .. response.len - 2], 10);
    }

    /// Sets a key-value pair with expiration
    pub fn setEx(self: *Self, key: []const u8, value: []const u8, ttl_seconds: i64) !void {
        if (key.len == 0 or value.len == 0 or ttl_seconds <= 0) return RedisError.InvalidArgument;
        const cmd = try self.formatCommand("*4\r\n$5\r\nSETEX\r\n${d}\r\n{s}\r\n${d}\r\n{d}\r\n${d}\r\n{s}\r\n", .{ key.len, key, std.fmt.count("{d}", .{ttl_seconds}), ttl_seconds, value.len, value });
        defer self.allocator.free(cmd);
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);
        if (!std.mem.eql(u8, response, "+OK\r\n")) return RedisError.SetFailed;
    }

    /// Sets expiration for a key
    pub fn expire(self: *Self, key: []const u8, ttl_seconds: i64) !void {
        const cmd = try self.formatCommand("*3\r\n$6\r\nEXPIRE\r\n${d}\r\n{s}\r\n${d}\r\n{d}\r\n", .{ key.len, key, std.fmt.count("{d}", .{ttl_seconds}), ttl_seconds });
        defer self.allocator.free(cmd);
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);
    }

    /// Gets time to live for a key
    pub fn ttl(self: *Self, key: []const u8) RedisError!?i64 {
        const cmd = self.formatCommand("*2\r\n$3\r\nTTL\r\n${d}\r\n{s}\r\n", .{ key.len, key }) catch |err| switch (err) {
            error.OutOfMemory => return RedisError.OutOfMemory,
        };
        defer self.allocator.free(cmd);

        std.log.scoped(.redis_client).debug("[redis_client.ttl] Formatted command: '{s}'", .{cmd});
        std.log.scoped(.redis_client).debug("[redis_client.ttl] Sending TTL command for key: '{s}'", .{key});
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);

        std.log.scoped(.redis_client).debug("[redis_client.ttl] Received response: '{s}'", .{response});

        if (response.len < 3 or response[response.len - 2] != '\r' or response[response.len - 1] != '\n') {
            std.log.scoped(.redis_client).debug("[redis_client.ttl] Invalid response format", .{});
            return RedisError.InvalidResponse;
        }

        switch (response[0]) {
            ':' => {
                const value = std.fmt.parseInt(i64, response[1 .. response.len - 2], 10) catch |err| {
                    std.log.scoped(.redis_client).debug("[redis_client.ttl] Failed to parse integer: {}", .{err});
                    return RedisError.InvalidResponse;
                };
                std.log.scoped(.redis_client).debug("[redis_client.ttl] Parsed TTL: {d}", .{value});
                if (value == -2) return null; // Key doesn’t exist
                return value; // Includes -1 (no expiration) and positive TTLs
            },
            '-' => {
                std.log.scoped(.redis_client).debug("[redis_client.ttl] Redis error response: '{s}'", .{response});
                return RedisError.CommandFailed;
            },
            else => {
                std.log.scoped(.redis_client).debug("[redis_client.ttl] Unexpected response type: '{c}'", .{response[0]});
                return RedisError.InvalidResponse;
            },
        }
    }

    /// Increments a key
    pub fn incr(self: *Self, key: []const u8) !u64 {
        const cmd = try self.formatCommand("*2\r\n$4\r\nINCR\r\n${d}\r\n{s}\r\n", .{ key.len, key });
        defer self.allocator.free(cmd);
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);
        if (!std.mem.startsWith(u8, response, ":")) return RedisError.InvalidResponse;
        return try std.fmt.parseInt(u64, response[1 .. response.len - 2], 10);
    }

    /// Pushes value to the left of a list
    pub fn lPush(self: *Self, key: []const u8, value: []const u8) !u64 {
        if (key.len == 0 or value.len == 0) return RedisError.InvalidArgument;
        const cmd = try self.formatCommand("*3\r\n$5\r\nLPUSH\r\n${d}\r\n{s}\r\n${d}\r\n{s}\r\n", .{ key.len, key, value.len, value });
        defer self.allocator.free(cmd);
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);
        if (!std.mem.startsWith(u8, response, ":")) return RedisError.InvalidResponse;
        return try std.fmt.parseInt(u64, response[1 .. response.len - 2], 10);
    }

    /// Gets all members of a set
    pub fn sMembers(self: *Self, key: []const u8) !?[][]const u8 {
        if (key.len == 0) return RedisError.InvalidArgument;
        const cmd = try self.formatCommand("*2\r\n$8\r\nSMEMBERS\r\n${d}\r\n{s}\r\n", .{ key.len, key });
        defer self.allocator.free(cmd);
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);

        if (std.mem.eql(u8, response, "*0")) return null;

        if (response[0] == '*') {
            var strings = std.ArrayList([]const u8).init(self.allocator);
            errdefer {
                for (strings.items) |item| self.allocator.free(item);
                strings.deinit();
            }

            const len_end = std.mem.indexOf(u8, response[1..], "\r\n") orelse return RedisError.InvalidResponse;
            const num_elements = try std.fmt.parseInt(i64, response[1 .. 1 + len_end], 10);
            if (num_elements <= 0) return null;

            var current_pos: usize = len_end + 3;
            var i: i64 = 0;
            while (i < num_elements) : (i += 1) {
                if (response[current_pos] != '$') return RedisError.InvalidResponse;
                const str_len_end = std.mem.indexOf(u8, response[current_pos + 1 ..], "\r\n") orelse return RedisError.InvalidResponse;
                const str_len = try std.fmt.parseInt(usize, response[current_pos + 1 .. current_pos + 1 + str_len_end], 10);
                current_pos += str_len_end + 3;
                const string = response[current_pos .. current_pos + str_len];
                try strings.append(try self.allocator.dupe(u8, string));
                current_pos += str_len + 2;
            }
            return try strings.toOwnedSlice();
        }
        return null;
    }

    /// Adds a member to a set
    pub fn sAdd(self: *Self, key: []const u8, member: []const u8) !u64 {
        if (key.len == 0 or member.len == 0) return RedisError.InvalidArgument;
        const cmd = try self.formatCommand("*3\r\n$4\r\nSADD\r\n${d}\r\n{s}\r\n${d}\r\n{s}\r\n", .{ key.len, key, member.len, member });
        defer self.allocator.free(cmd);
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);
        if (!std.mem.startsWith(u8, response, ":")) return RedisError.InvalidResponse;
        return try std.fmt.parseInt(u64, response[1 .. response.len - 2], 10);
    }

    /// Removes a member from a set
    pub fn sRem(self: *Self, key: []const u8, member: []const u8) !u64 {
        if (key.len == 0 or member.len == 0) return RedisError.InvalidArgument;
        const cmd = try self.formatCommand("*3\r\n$4\r\nSREM\r\n${d}\r\n{s}\r\n${d}\r\n{s}\r\n", .{ key.len, key, member.len, member });
        defer self.allocator.free(cmd);
        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);
        if (!std.mem.startsWith(u8, response, ":")) return RedisError.InvalidResponse;
        return try std.fmt.parseInt(u64, response[1 .. response.len - 2], 10);
    }

    /// Scans keys matching a pattern
    pub fn scan(self: *Self, cursor: []const u8, match_pattern: ?[]const u8, count: ?u32) !ScanResult {
        var cmd_builder = std.ArrayList(u8).init(self.allocator);
        defer cmd_builder.deinit();

        // Build the SCAN command
        try std.fmt.format(cmd_builder.writer(), "*{d}\r\n$4\r\nSCAN\r\n${d}\r\n{s}\r\n", .{
            2 + @as(usize, if (match_pattern != null) 2 else 0) + @as(usize, if (count != null) 2 else 0),
            cursor.len,
            cursor,
        });

        if (match_pattern) |pattern| {
            try std.fmt.format(cmd_builder.writer(), "$5\r\nMATCH\r\n${d}\r\n{s}\r\n", .{
                pattern.len,
                pattern,
            });
        }

        if (count) |c| {
            const count_str = try std.fmt.allocPrint(self.allocator, "{d}", .{c});
            defer self.allocator.free(count_str);
            try std.fmt.format(cmd_builder.writer(), "$5\r\nCOUNT\r\n${d}\r\n{s}\r\n", .{
                count_str.len,
                count_str,
            });
        }

        const cmd = try cmd_builder.toOwnedSlice();
        defer self.allocator.free(cmd);

        const response = try self.executeCommand(cmd);
        defer self.allocator.free(response);

        // Parse the response
        if (response[0] != '*') return RedisError.InvalidResponse;

        const array_size_end = std.mem.indexOf(u8, response[1..], "\r\n") orelse return RedisError.InvalidResponse;
        const array_size = try std.fmt.parseInt(usize, response[1 .. 1 + array_size_end], 10);
        if (array_size != 2) return RedisError.InvalidResponse;

        var pos = 1 + array_size_end + 2;

        // Parse the cursor
        if (response[pos] != '$') return RedisError.InvalidResponse;
        const cursor_len_end = std.mem.indexOf(u8, response[pos + 1 ..], "\r\n") orelse return RedisError.InvalidResponse;
        const cursor_len = try std.fmt.parseInt(usize, response[pos + 1 .. pos + 1 + cursor_len_end], 10);
        pos += 1 + cursor_len_end + 2;

        const new_cursor = try self.allocator.dupe(u8, response[pos .. pos + cursor_len]);
        errdefer self.allocator.free(new_cursor);
        pos += cursor_len + 2;

        // Parse the keys
        if (response[pos] != '*') return RedisError.InvalidResponse;
        const keys_count_end = std.mem.indexOf(u8, response[pos + 1 ..], "\r\n") orelse return RedisError.InvalidResponse;
        const keys_count = try std.fmt.parseInt(usize, response[pos + 1 .. pos + 1 + keys_count_end], 10);
        pos += 1 + keys_count_end + 2;

        var keys = std.ArrayList([]const u8).init(self.allocator);
        errdefer {
            for (keys.items) |key| self.allocator.free(key);
            keys.deinit();
        }

        var i: usize = 0;
        while (i < keys_count and pos < response.len) : (i += 1) {
            if (response[pos] != '$') break;
            const key_len_end = std.mem.indexOf(u8, response[pos + 1 ..], "\r\n") orelse break;
            const key_len = try std.fmt.parseInt(usize, response[pos + 1 .. pos + 1 + key_len_end], 10);
            pos += 1 + key_len_end + 2;
            const key = try self.allocator.dupe(u8, response[pos .. pos + key_len]);
            try keys.append(key);
            pos += key_len + 2;
        }

        return ScanResult{
            .cursor = new_cursor,
            .keys = try keys.toOwnedSlice(),
        };
    }

    /// Scans all keys matching a pattern
    pub fn scanAll(self: *Self, match_pattern: ?[]const u8, count: ?u32) ![][]const u8 {
        var all_keys = std.ArrayList([]const u8).init(self.allocator);
        errdefer {
            for (all_keys.items) |key| self.allocator.free(key);
            all_keys.deinit();
        }

        var cursor = try self.allocator.dupe(u8, "0");
        defer self.allocator.free(cursor);

        while (true) {
            const scan_result = try self.scan(cursor, match_pattern, count);
            const new_cursor = scan_result.cursor;
            const batch_keys = scan_result.keys;
            defer {
                for (batch_keys) |key| self.allocator.free(key);
                self.allocator.free(batch_keys);
            }

            for (batch_keys) |key| {
                try all_keys.append(try self.allocator.dupe(u8, key));
            }

            self.allocator.free(cursor);
            cursor = new_cursor;

            if (std.mem.eql(u8, cursor, "0")) break;
        }

        return all_keys.toOwnedSlice();
    }
};
