const std = @import("std");
const types = @import("types.zig");

pub const RedisClient = @import("client.zig").RedisClient;

pub const RedisPipeline = struct {
    commands: std.ArrayList([]const u8),
    client: *RedisClient,
    command_count: usize,

    pub fn init(client: *RedisClient) !RedisPipeline {
        return RedisPipeline{
            .commands = std.ArrayList([]const u8).init(client.allocator),
            .client = client,
            .command_count = 0,
        };
    }

    pub fn add(self: *RedisPipeline, cmd: []const u8) !void {
        if (self.command_count >= self.client.config.max_pipeline_commands) {
            try self.execute();
        }
        try self.commands.append(cmd);
        self.command_count += 1;
    }

    pub fn execute(self: *RedisPipeline) !void {
        if (self.commands.items.len == 0) return;

        // Combine all commands into a single write
        var combined_cmd = std.ArrayList(u8).init(self.client.allocator);
        defer combined_cmd.deinit();

        for (self.commands.items) |cmd| {
            try combined_cmd.appendSlice(cmd);
        }

        try self.client.sendCommand(combined_cmd.items);

        // Read all responses
        var i: usize = 0;
        while (i < self.commands.items.len) : (i += 1) {
            const response = try self.client.readResponse();
            self.client.allocator.free(response);
        }

        self.commands.clearRetainingCapacity();
        self.command_count = 0;
    }

    pub fn deinit(self: *RedisPipeline) void {
        self.commands.deinit();
    }
};
