const std = @import("std");
const types = @import("types.zig");
const RedisClient = @import("client.zig").RedisClient;

pub const RedisError = types.RedisError;
pub const RedisClientConfig = types.RedisClientConfig;

pub const PooledRedisClient = struct {
    allocator: std.mem.Allocator,
    config: RedisClientConfig,
    available: std.ArrayList(*RedisClient), // Available (idle) clients
    all_clients: std.ArrayList(*RedisClient), // All clients (active + available)
    mutex: std.Thread.Mutex,
    condition: std.Thread.Condition, // For waiting on available connections
    last_cleanup: i64,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: RedisClientConfig) !Self {
        var pool = Self{
            .allocator = allocator,
            .config = config,
            .available = std.ArrayList(*RedisClient).init(allocator),
            .all_clients = std.ArrayList(*RedisClient).init(allocator),
            .mutex = .{},
            .condition = .{},
            .last_cleanup = std.time.milliTimestamp(),
        };
        errdefer pool.deinit();

        try pool.available.ensureTotalCapacity(config.max_connections);
        try pool.all_clients.ensureTotalCapacity(config.max_connections);

        const min_connections = @min(config.min_connections, config.max_connections);
        for (0..min_connections) |_| {
            const client = try pool.createConnection();
            try pool.available.append(client);
            try pool.all_clients.append(client);
        }

        return pool;
    }

    pub fn deinit(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.all_clients.items) |client| {
            client.disconnect();
            self.allocator.destroy(client);
        }
        self.available.deinit();
        self.all_clients.deinit();
    }

    fn createConnection(self: *Self) RedisError!*RedisClient {
        var client_ptr = try self.allocator.create(RedisClient);
        errdefer self.allocator.destroy(client_ptr);

        client_ptr.* = try RedisClient.connect(self.allocator, self.config);

        if (self.config.password) |password| {
            try client_ptr.auth(password);
        }
        if (self.config.database) |db| {
            try client_ptr.select(db);
        }
        return client_ptr;
    }

    pub fn acquire(self: *Self) !*RedisClient {
        try self.maybeCleanupConnections();

        self.mutex.lock();
        defer self.mutex.unlock();

        while (true) {
            if (self.available.items.len > 0) {
                const client = self.available.pop() orelse unreachable;
                if (client.isHealthy()) {
                    return client;
                }
                client.disconnect();
                self.allocator.destroy(client);
                _ = self.removeFromAllClients(client);
                continue;
            }

            if (self.all_clients.items.len < self.config.max_connections) {
                const new_client = try self.createConnection();
                try self.all_clients.append(new_client);
                return new_client;
            }

            const timeout_ns = self.config.timeout_ms * std.time.ns_per_ms;
            self.condition.timedWait(&self.mutex, timeout_ns) catch |err| switch (err) {
                error.Timeout => return RedisError.PoolExhausted,
                else => |e| return e,
            };
        }
    }

    pub fn release(self: *Self, client: *RedisClient) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (!self.containsClient(client) or !client.connected) return;

        client.reconnect_attempts = 0;
        client.last_used_timestamp = std.time.milliTimestamp();

        if (!client.isHealthy()) {
            client.disconnect();
            self.allocator.destroy(client);
            _ = self.removeFromAllClients(client);
            return;
        }

        if (self.available.items.len < self.config.max_connections) {
            self.available.append(client) catch |err| {
                // Handle append failure (e.g., out of memory)
                std.log.err("Failed to append client to available pool: {}", .{err});
                client.disconnect();
                self.allocator.destroy(client);
                _ = self.removeFromAllClients(client);
            };
            self.condition.signal();
        } else {
            client.disconnect();
            self.allocator.destroy(client);
            _ = self.removeFromAllClients(client);
        }
    }

    fn containsClient(self: *Self, client: *RedisClient) bool {
        for (self.all_clients.items) |c| if (c == client) return true;
        return false;
    }

    fn maybeCleanupConnections(self: *Self) !void {
        const now = std.time.milliTimestamp();
        const cleanup_interval = @as(i64, 30000); // 30 seconds default

        const interval = if (@hasField(@TypeOf(self.config), "cleanup_interval_ms"))
            self.config.cleanup_interval_ms
        else
            cleanup_interval;

        if (interval > 0 and now - self.last_cleanup >= interval) {
            try self.cleanupConnections();
        }
    }

    fn cleanupConnections(self: *Self) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.last_cleanup = std.time.milliTimestamp();

        if (self.available.items.len == 0) return;

        var i: usize = self.available.items.len;
        while (i > 0) {
            i -= 1;
            if (i >= self.available.items.len) continue;

            const client = self.available.items[i];
            if (!client.isHealthy()) {
                const removed = self.available.orderedRemove(i);
                removed.disconnect();
                _ = self.removeFromAllClients(removed);
                self.allocator.destroy(removed);
            }
        }
    }

    fn removeFromAllClients(self: *Self, client: *RedisClient) bool {
        for (self.all_clients.items, 0..) |item, i| {
            if (item == client) {
                _ = self.all_clients.swapRemove(i);
                return true;
            }
        }
        return false;
    }
};
