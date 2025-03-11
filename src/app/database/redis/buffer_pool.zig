const std = @import("std");

pub const BufferPool = struct {
    allocator: std.mem.Allocator,
    buffers: std.ArrayList([]u8),
    mutex: std.Thread.Mutex,
    condition: std.Thread.Condition,
    max_size: usize,
    buffer_size: usize,
    total_allocated: usize,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, max_size: usize, buffer_size: usize) !Self {
        var pool = Self{
            .allocator = allocator,
            .buffers = std.ArrayList([]u8).init(allocator),
            .mutex = .{},
            .condition = .{},
            .max_size = max_size,
            .buffer_size = buffer_size,
            .total_allocated = 0,
        };
        errdefer pool.buffers.deinit();

        try pool.buffers.ensureTotalCapacity(max_size);
        const initial_buffers = @min(max_size / 2, 4);
        for (0..initial_buffers) |_| {
            const buf = try allocator.alloc(u8, buffer_size);
            try pool.buffers.append(buf);
            pool.total_allocated += 1;
        }

        return pool;
    }

    pub fn deinit(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.buffers.items) |buf| {
            self.allocator.free(buf);
        }
        self.buffers.deinit();
        self.total_allocated = 0;
    }

    pub fn acquire(self: *Self) ![]u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (true) {
            if (self.buffers.items.len > 0) {
                const buf: []u8 = self.buffers.pop().?;
                if (buf.len != self.buffer_size) {
                    self.allocator.free(buf);
                    return try self.allocator.alloc(u8, self.buffer_size);
                }
                return buf;
            }

            if (self.total_allocated < self.max_size) {
                const buf = try self.allocator.alloc(u8, self.buffer_size);
                self.total_allocated += 1;
                return buf;
            }

            const timeout_ns = std.time.ns_per_s;
            self.condition.timedWait(&self.mutex, timeout_ns) catch |err| switch (err) {
                error.Timeout => return try self.allocator.alloc(u8, self.buffer_size),
                else => return err,
            };
        }
    }

    pub fn release(self: *Self, buffer: []u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (buffer.len != self.buffer_size) {
            self.allocator.free(buffer);
            return;
        }

        if (self.buffers.items.len < self.max_size) {
            self.buffers.append(buffer) catch {
                self.allocator.free(buffer);
                return;
            };
            self.condition.signal();
        } else {
            self.allocator.free(buffer);
        }
    }

    pub fn availableCount(self: *Self) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.buffers.items.len;
    }

    pub fn totalAllocated(self: *Self) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.total_allocated;
    }
};

var global_pool: ?BufferPool = null;

pub fn initGlobalPool(allocator: std.mem.Allocator, max_size: usize, buffer_size: usize) !void {
    if (global_pool != null) return error.AlreadyInitialized;
    global_pool = try BufferPool.init(allocator, max_size, buffer_size);
}

pub fn deinitGlobalPool() void {
    if (global_pool) |*pool| {
        pool.deinit();
        global_pool = null;
    }
}

pub fn getGlobalPool() ?*BufferPool {
    return if (global_pool) |*pool| pool else null;
}

test "BufferPool basic functionality" {
    const allocator = std.testing.allocator;
    var pool = try BufferPool.init(allocator, 3, 1024);
    defer pool.deinit();

    const buf1 = try pool.acquire();
    try std.testing.expectEqual(1024, buf1.len);
    const buf2 = try pool.acquire();
    try std.testing.expectEqual(1024, buf2.len);

    pool.release(buf1);
    pool.release(buf2);

    try std.testing.expectEqual(@as(usize, 2), pool.availableCount());
    try std.testing.expectEqual(@as(usize, 2), pool.totalAllocated());
}
