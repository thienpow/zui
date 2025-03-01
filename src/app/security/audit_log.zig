const std = @import("std");
const redis = @import("../database/redis/redis.zig");
const types = @import("types.zig");
const validation = @import("validation.zig");

const SecurityEvent = types.SecurityEvent;
const PooledRedisClient = redis.PooledRedisClient;

pub const AuditMetadata = struct {
    // Common audit metadata fields
    action_details: ?[]const u8 = null,
    resource_id: ?[]const u8 = null,
    resource_type: ?[]const u8 = null,
    status: ?[]const u8 = null,
    error_message: ?[]const u8 = null,
    ip_address: ?[]const u8 = null,
    user_agent: ?[]const u8 = null,
    // Additional context-specific fields can be added
    custom_data: ?std.json.Value = null,
};

pub const AuditEntry = struct {
    timestamp: i64,
    event: SecurityEvent,
    user_id: ?u64,
    metadata: ?AuditMetadata,
    ip_address: ?[]const u8,
    user_agent: ?[]const u8,
};

pub const AuditContext = struct {
    ip_address: ?[]const u8,
    user_agent: ?[]const u8,
};

pub const AuditLogConfig = struct {
    enabled: bool = true,
    high_risk_events: []const SecurityEvent = &.{
        .login_failed,
        .password_changed,
        .mfa_disabled,
    },
    notify_admins: bool = true,
    store_type: enum {
        redis,
        database,
        both,
    } = .both,
};

pub const AuditLog = struct {
    allocator: std.mem.Allocator,
    config: AuditLogConfig,
    context: AuditContext,
    redis_pool: *PooledRedisClient,

    fn isHighRiskEvent(self: *const AuditLog, event: SecurityEvent) bool {
        for (self.config.high_risk_events) |high_risk| {
            if (high_risk == event) return true;
        }
        return false;
    }

    fn notifyAdmins(self: *AuditLog, entry: AuditEntry) !void {
        if (!self.config.notify_admins) return;

        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        // Log high-risk event notification
        const notification_key = try std.fmt.allocPrint(self.allocator, "admin:notifications:{}:{}", .{ entry.timestamp, if (entry.user_id) |id| id else 0 });
        defer self.allocator.free(notification_key);

        var json_string = std.ArrayList(u8).init(self.allocator);
        defer json_string.deinit();
        try std.json.stringify(.{
            .event = entry.event,
            .timestamp = entry.timestamp,
            .user_id = entry.user_id,
            .metadata = entry.metadata,
            .ip_address = entry.ip_address,
            .user_agent = entry.user_agent,
            .severity = "high_risk",
        }, .{}, json_string.writer());

        // Store notification in Redis list and get the new list length
        const list_length = client.lPush("admin:notifications", json_string.items) catch |err| switch (err) {
            redis.RedisError.ConnectionFailed => return error.StorageError,
            redis.RedisError.CommandFailed => return error.StorageError,
            else => return err,
        };

        // Optional: Log the new list length
        std.log.debug("Admin notifications list length: {}", .{list_length});

        // Optional: Set TTL for notification
        try client.expire("admin:notifications", 60 * 60 * 24);
    }

    pub fn log(self: *AuditLog, event: SecurityEvent, user_id: ?u64, metadata: ?AuditMetadata) !void {
        if (metadata) |m| {
            validation.validateMetadata(m) catch |err| {
                std.log.err("Metadata validation failed: {}", .{err});
                return error.MetadataValidationFailed;
            };
        }

        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        const entry = AuditEntry{
            .timestamp = std.time.timestamp(),
            .event = event,
            .user_id = user_id,
            .metadata = metadata,
            .ip_address = self.context.ip_address,
            .user_agent = self.context.user_agent,
        };

        const key = try std.fmt.allocPrint(self.allocator, "audit:{}:{}", .{ entry.timestamp, if (user_id) |id| id else 0 });
        defer self.allocator.free(key);

        var json_string = std.ArrayList(u8).init(self.allocator);
        defer json_string.deinit();
        try std.json.stringify(entry, .{}, json_string.writer());

        try client.set(key, json_string.items);

        if (self.isHighRiskEvent(event)) {
            try self.notifyAdmins(entry);
        }
    }
};

pub const AuditBatch = struct {
    entries: std.ArrayList(AuditEntry),

    pub fn init(allocator: std.mem.Allocator) AuditBatch {
        return .{ .entries = std.ArrayList(AuditEntry).init(allocator) };
    }

    pub fn deinit(self: *AuditBatch) void {
        self.entries.deinit();
    }

    pub fn append(self: *AuditBatch, entry: AuditEntry) !void {
        try self.entries.append(entry);
    }
};
