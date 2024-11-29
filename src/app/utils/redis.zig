const std = @import("std");
const builtin = @import("builtin");

pub const RedisError = error{
    ConnectionFailed,
    InvalidArgument,
    SetFailed,
    PoolExhausted,
    InvalidResponse,
};

pub const RedisClientConfig = struct {
    host: []const u8 = "localhost",
    port: u16 = 6379,
    max_connections: usize = 10,
    connection_timeout_ms: u64 = 5000,
    idle_timeout_ms: u64 = 30000,
};

pub const PooledRedisClient = struct {
    allocator: std.mem.Allocator,
    config: RedisClientConfig,
    connections: std.ArrayList(RedisClient),
    available_connections: std.ArrayList(usize),
    mutex: std.Thread.Mutex = .{},

    pub fn init(allocator: std.mem.Allocator, config: RedisClientConfig) !PooledRedisClient {
        var pool = PooledRedisClient{
            .allocator = allocator,
            .config = config,
            .connections = std.ArrayList(RedisClient).init(allocator),
            .available_connections = std.ArrayList(usize).init(allocator),
        };
        errdefer pool.deinit();

        // Pre-allocate connection slots
        try pool.connections.ensureTotalCapacity(config.max_connections);
        try pool.available_connections.ensureTotalCapacity(config.max_connections);

        return pool;
    }

    pub fn deinit(self: *PooledRedisClient) void {
        // Close and free all connections
        for (self.connections.items) |*client| {
            client.disconnect();
        }
        self.connections.deinit();
        self.available_connections.deinit();
    }

    pub fn acquire(self: *PooledRedisClient) !*RedisClient {
        self.mutex.lock();
        defer self.mutex.unlock();

        // First, check if we have an available connection
        if (self.available_connections.items.len > 0) {
            const index = self.available_connections.pop();
            return &self.connections.items[index];
        }

        // If we haven't reached max connections, create a new one
        if (self.connections.items.len < self.config.max_connections) {
            const client = try RedisClient.connect(self.allocator, self.config.host, self.config.port);
            try self.connections.append(client);
            return &self.connections.items[self.connections.items.len - 1];
        }

        // No available connections and max pool size reached
        return RedisError.PoolExhausted;
    }

    pub fn release(self: *PooledRedisClient, client: *RedisClient) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Find the index of the client in the connections array
        for (0..self.connections.items.len) |i| {
            if (&self.connections.items[i] == client) {
                try self.available_connections.append(i);
                return;
            }
        }

        // If client not found, it might have been removed or is invalid
        return error.InvalidArgument;
    }
};

pub const RedisClient = struct {
    allocator: std.mem.Allocator,
    socket: std.net.Stream,
    connected: bool = false,
    last_used_timestamp: i64 = 0,

    pub fn connect(allocator: std.mem.Allocator, host: []const u8, port: u16) !RedisClient {
        const socket = std.net.tcpConnectToHost(allocator, host, port) catch |err| {
            std.log.err("Connection failed: {}", .{err});
            return RedisError.ConnectionFailed;
        };

        return RedisClient{
            .allocator = allocator,
            .socket = socket,
            .connected = true,
            .last_used_timestamp = std.time.timestamp(),
        };
    }

    pub fn command(self: *RedisClient, cmd: []const u8) ![]const u8 {
        // Update last used timestamp
        self.last_used_timestamp = std.time.timestamp();

        // Write the command to the Redis server
        try self.socket.writer().writeAll(cmd);

        // Read the response from the Redis server
        var buffer: [4096]u8 = undefined;
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
            return RedisError.InvalidArgument;
        }

        const cmd = try std.fmt.allocPrint(self.allocator, "*3\r\n$3\r\nSET\r\n${d}\r\n{s}\r\n${d}\r\n{s}\r\n", .{ key.len, key, value.len, value });
        defer self.allocator.free(cmd);

        const response = try self.command(cmd);
        defer self.allocator.free(response);

        if (!std.mem.startsWith(u8, response, "+OK\r\n")) {
            return RedisError.SetFailed;
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
        const start = std.mem.indexOf(u8, response, "\r\n") orelse return RedisError.InvalidResponse;
        const end = std.mem.lastIndexOf(u8, response, "\r\n") orelse return RedisError.InvalidResponse;

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
        self.connected = false;
    }
};
