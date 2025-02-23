const std = @import("std");
const types = @import("types.zig");

pub const RedisError = types.RedisError;
pub const RedisClientConfig = types.RedisClientConfig;
pub const RedisClient = @import("client.zig").RedisClient;

pub const BufferPool = struct {
    pool: std.ArrayList(std.ArrayList(u8)),
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) BufferPool {
        return .{
            .pool = std.ArrayList(std.ArrayList(u8)).init(allocator),
            .allocator = allocator,
            .mutex = .{},
        };
    }

    pub fn acquire(self: *BufferPool, initial_size: usize) !*std.ArrayList(u8) {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.pool.items.len == 0) {
            var buffer = try std.ArrayList(u8).initCapacity(self.allocator, initial_size);
            return &buffer;
        }

        return &self.pool.pop();
    }

    pub fn release(self: *BufferPool, buffer: *std.ArrayList(u8)) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        buffer.clearRetainingCapacity();
        try self.pool.append(buffer.*);
    }

    pub fn deinit(self: *BufferPool) void {
        for (self.pool.items) |*buffer| {
            buffer.deinit();
        }
        self.pool.deinit();
    }
};

pub const PooledRedisClient = struct {
    allocator: std.mem.Allocator,
    config: RedisClientConfig,
    connections: std.ArrayList(RedisClient),
    available_connections: std.ArrayList(usize),
    mutex: std.Thread.Mutex,
    buffer_pool: BufferPool,
    last_cleanup: i64,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: RedisClientConfig) !Self {
        var pool = Self{
            .allocator = allocator,
            .config = config,
            .connections = std.ArrayList(RedisClient).init(allocator),
            .available_connections = std.ArrayList(usize).init(allocator),
            .mutex = .{},
            .buffer_pool = BufferPool.init(allocator),
            .last_cleanup = std.time.milliTimestamp(),
        };
        errdefer pool.deinit();

        try pool.connections.ensureTotalCapacity(config.max_connections);
        try pool.available_connections.ensureTotalCapacity(config.max_connections);

        // Initialize with minimum connections
        const min_connections = @min(3, config.max_connections);
        var i: usize = 0;
        while (i < min_connections) : (i += 1) {
            try pool.createNewConnection();
        }

        return pool;
    }

    fn createNewConnection(self: *Self) !void {
        var client = try RedisClient.connect(self.allocator, self.config);
        errdefer client.disconnect();

        if (self.config.password) |pass| {
            try client.auth(pass);
        }
        if (self.config.database) |db| {
            try client.select(db);
        }

        try self.connections.append(client);
        try self.available_connections.append(self.connections.items.len - 1);
    }

    pub fn deinit(self: *Self) void {
        for (self.connections.items) |*client| {
            client.disconnect();
        }
        self.connections.deinit();
        self.available_connections.deinit();
        self.buffer_pool.deinit();
    }

    fn cleanupConnections(self: *Self) !void {
        const now = std.time.milliTimestamp();
        if (now - self.last_cleanup < self.config.cleanup_interval_ms) {
            return;
        }

        self.mutex.lock();
        defer self.mutex.unlock();

        var i: usize = 0;
        while (i < self.connections.items.len) {
            var client = &self.connections.items[i];
            if (!client.isHealthy()) {
                client.disconnect();
                _ = self.connections.swapRemove(i);
                // Update available_connections indices
                for (self.available_connections.items) |*idx| {
                    if (idx.* == i) {
                        _ = self.available_connections.swapRemove(i);
                    } else if (idx.* > i) {
                        idx.* -= 1;
                    }
                }
                continue;
            }
            i += 1;
        }

        self.last_cleanup = now;
    }

    pub fn acquire(self: *Self) !*RedisClient {
        try self.cleanupConnections();

        self.mutex.lock();
        defer self.mutex.unlock();

        // Check available connections
        while (self.available_connections.items.len > 0) {
            const index_opt = self.available_connections.pop();
            const index = index_opt orelse break; // Handle the optional value
            var client = &self.connections.items[index];

            if (client.isHealthy()) {
                return client;
            }

            client.disconnect();
            _ = self.connections.swapRemove(index);
        }

        // Create new connection if pool not full
        if (self.connections.items.len < self.config.max_connections) {
            try self.createNewConnection();
            return &self.connections.items[self.connections.items.len - 1];
        }

        return RedisError.PoolExhausted;
    }

    pub fn release(self: *Self, client: *RedisClient) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (0..self.connections.items.len) |i| {
            if (&self.connections.items[i] == client) {
                try self.available_connections.append(i);
                client.last_used_timestamp = std.time.milliTimestamp();
                return;
            }
        }

        return error.InvalidArgument;
    }
};
