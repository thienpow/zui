const std = @import("std");
const redis = @import("../database/redis/redis.zig");
const types = @import("types.zig");
const config = @import("config.zig");

const Session = types.Session;
const SessionConfig = config.SessionConfig;
const StorageConfig = config.StorageConfig;
const PooledRedisClient = redis.PooledRedisClient;

pub const SessionStorage = struct {
    allocator: std.mem.Allocator,
    session_config: SessionConfig,
    storage_config: StorageConfig,
    redis_pool: *PooledRedisClient,

    pub fn getSessionByToken(self: *SessionStorage, token: []const u8) !?Session {
        std.log.scoped(.auth).debug("[storage.getSessionByToken] token={s}", .{token});
        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        const key = try std.fmt.allocPrint(self.allocator, "session_token:{s}", .{token});
        defer self.allocator.free(key);

        // Handle the optional result from get()
        const data = (try client.get(key)) orelse {
            std.log.scoped(.auth).debug("[storage.getSessionByToken] Key not found: {s}", .{key});
            return null;
        };

        std.log.scoped(.auth).debug("[storage.getSessionByToken] Raw data retrieved: {s}", .{data});

        // Use allocate option to ensure strings are properly owned
        const options = std.json.ParseOptions{
            .allocate = .alloc_always, // This makes it allocate strings
            .ignore_unknown_fields = false,
        };

        const session = std.json.parseFromSliceLeaky(
            Session,
            self.allocator,
            data,
            options,
        ) catch |err| {
            self.allocator.free(data); // Free data before returning
            std.log.scoped(.auth).debug("Failed to parse session data: {}", .{err});
            return null;
        };

        // Now we can free the original data
        self.allocator.free(data);

        std.log.scoped(.auth).debug("[storage.getSessionByToken] Parsed session ID: {s}", .{session.id});
        return session;
    }

    pub fn getSessionById(self: *SessionStorage, session_id: []const u8) !?Session {
        std.log.scoped(.auth).debug("[storage.getSessionById] session_id={s}", .{session_id});
        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);
        const key = try std.fmt.allocPrint(self.allocator, "session:{s}", .{session_id});
        defer self.allocator.free(key);

        // Handle the optional result from get()
        const data = (try client.get(key)) orelse {
            std.log.scoped(.auth).debug("[storage.getSessionById] Key not found: {s}", .{key});
            return null;
        };

        std.log.scoped(.auth).debug("[storage.getSessionById] Raw data retrieved: {s}", .{data});

        // Use allocate option to ensure strings are properly owned
        const options = std.json.ParseOptions{
            .allocate = .alloc_always, // This makes it allocate strings
            .ignore_unknown_fields = false,
        };

        const session = std.json.parseFromSliceLeaky(
            Session,
            self.allocator,
            data,
            options,
        ) catch |err| {
            self.allocator.free(data); // Free data before returning
            std.log.scoped(.auth).debug("Failed to parse session data: {}", .{err});
            return null;
        };

        // Now we can free the original data
        self.allocator.free(data);
        std.log.scoped(.auth).debug("[storage.getSessionById] Parsed session ID: {s}", .{session.id});
        return session;
    }

    pub fn invalidateSession(self: *SessionStorage, session_id: []const u8) !void {
        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        // First get the session to find its token
        const session = (try self.getSessionById(session_id)) orelse {
            std.log.scoped(.auth).debug("[storage.invalidateSession] Session not found: {s}", .{session_id});
            return;
        };

        // Delete the session by ID
        const id_key = try std.fmt.allocPrint(self.allocator, "session:{s}", .{session_id});
        defer self.allocator.free(id_key);
        _ = try client.del(id_key);

        // Delete the token-based reference
        const token_key = try std.fmt.allocPrint(self.allocator, "session_token:{s}", .{session.token});
        defer self.allocator.free(token_key);
        _ = try client.del(token_key);

        // Remove from user's session set
        const user_key = try std.fmt.allocPrint(self.allocator, "user:{d}:sessions", .{session.user_id});
        defer self.allocator.free(user_key);
        _ = try client.sRem(user_key, session_id);
    }

    pub fn saveSession(self: *SessionStorage, session: Session) !void {
        // Log the complete session before saving
        std.log.scoped(.auth).debug("[storage.saveSession] Saving session: id='{s}' (len: {})", .{ session.id, session.id.len });
        std.log.scoped(.auth).debug("[storage.saveSession] User ID: {d}, token='{s}' (len: {})", .{ session.user_id, session.token, session.token.len });

        // Specifically log metadata with details on if it's null or not
        const ip_str = if (session.metadata.ip_address) |ip|
            std.fmt.allocPrint(self.allocator, "'{s}' (len: {})", .{ ip, ip.len }) catch "allocation error"
        else
            "null";
        defer if (!std.mem.eql(u8, ip_str, "null") and !std.mem.eql(u8, ip_str, "allocation error"))
            self.allocator.free(ip_str);

        const ua_str = if (session.metadata.user_agent) |ua|
            std.fmt.allocPrint(self.allocator, "'{s}' (len: {})", .{ ua, ua.len }) catch "allocation error"
        else
            "null";
        defer if (!std.mem.eql(u8, ua_str, "null") and !std.mem.eql(u8, ua_str, "allocation error"))
            self.allocator.free(ua_str);

        std.log.scoped(.auth).debug("[storage.saveSession] Metadata: ip_address={s}, user_agent={s}", .{ ip_str, ua_str });

        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        // Create a buffer for JSON serialization
        var json_buffer = std.ArrayList(u8).init(self.allocator);
        defer json_buffer.deinit();

        // Stringify the session into the buffer
        try std.json.stringify(session, .{}, json_buffer.writer());

        // Get the resulting JSON string and log it
        const value = json_buffer.items;
        std.log.scoped(.auth).debug("[storage.saveSession] JSON serialized: {s}", .{value});

        // Store session by ID
        const id_key = try std.fmt.allocPrint(self.allocator, "session:{s}", .{session.id});
        defer self.allocator.free(id_key);
        try client.setEx(id_key, value, self.session_config.session_ttl);

        // Store session by token (for lookup from cookies)
        const token_key = try std.fmt.allocPrint(self.allocator, "session_token:{s}", .{session.token});
        defer self.allocator.free(token_key);
        try client.setEx(token_key, value, self.session_config.session_ttl);

        // Add to user's session set
        const user_key = try std.fmt.allocPrint(self.allocator, "user:{d}:sessions", .{session.user_id});
        defer self.allocator.free(user_key);
        _ = try client.sAdd(user_key, session.id);
        try client.expire(user_key, self.session_config.session_ttl);
    }

    pub fn cleanupExpiredSessions(self: *SessionStorage) !void {
        std.log.scoped(.session_storage).debug("[session_storage.cleanupExpiredSessions] Starting cleanup of expired sessions", .{});

        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);
        std.log.scoped(.session_storage).debug("[session_storage.cleanupExpiredSessions] Acquired Redis client", .{});

        // Use Redis SCAN to iterate over session keys
        var cursor: []const u8 = "0";
        const pattern = "session:*";
        const batch_size: u64 = 100;
        var session_count: usize = 0;
        var expired_session_count: usize = 0;

        std.log.scoped(.session_storage).debug("[session_storage.cleanupExpiredSessions] Starting scan of '{s}' with batch size {d}", .{ pattern, batch_size });

        while (true) {
            std.log.scoped(.session_storage).debug("[session_storage.cleanupExpiredSessions] Running SCAN with cursor '{s}'", .{cursor});
            const scan_result = try client.scan(cursor, pattern, batch_size);
            cursor = scan_result.cursor;

            std.log.scoped(.session_storage).debug("[session_storage.cleanupExpiredSessions] Got {d} session keys, next cursor: '{s}'", .{ scan_result.keys.len, cursor });

            for (scan_result.keys) |key| {
                session_count += 1;
                std.log.scoped(.session_storage).debug("[session_storage.cleanupExpiredSessions] Checking TTL for key: '{s}'", .{key});

                if (try client.ttl(key)) |ttl| {
                    std.log.scoped(.session_storage).debug("[session_storage.cleanupExpiredSessions] Key '{s}' has TTL: {d}", .{ key, ttl });

                    if (ttl <= 0) {
                        std.log.scoped(.session_storage).debug("[session_storage.cleanupExpiredSessions] Deleting expired key: '{s}'", .{key});
                        _ = try client.del(key);
                        expired_session_count += 1;
                    }
                } else {
                    std.log.scoped(.session_storage).debug("[session_storage.cleanupExpiredSessions] Failed to get TTL for key: '{s}'", .{key});
                }
            }

            // Check if cursor is "0", not the integer 0
            if (std.mem.eql(u8, cursor, "0")) {
                std.log.scoped(.session_storage).debug("[session_storage.cleanupExpiredSessions] Completed scan of session keys", .{});
                break;
            }
        }

        std.log.scoped(.session_storage).debug("[session_storage.cleanupExpiredSessions] Processed {d} session keys, deleted {d} expired sessions", .{ session_count, expired_session_count });

        // Also clean up token-based keys
        cursor = "0";
        const token_pattern = "session_token:*";
        var token_count: usize = 0;
        var expired_token_count: usize = 0;

        std.log.scoped(.session_storage).debug("[session_storage.cleanupExpiredSessions] Starting scan of '{s}' with batch size {d}", .{ token_pattern, batch_size });

        while (true) {
            std.log.scoped(.session_storage).debug("[session_storage.cleanupExpiredSessions] Running SCAN with cursor '{s}'", .{cursor});
            const scan_result = try client.scan(cursor, token_pattern, batch_size);
            cursor = scan_result.cursor;

            std.log.scoped(.session_storage).debug("[session_storage.cleanupExpiredSessions] Got {d} token keys, next cursor: '{s}'", .{ scan_result.keys.len, cursor });

            for (scan_result.keys) |key| {
                token_count += 1;
                std.log.scoped(.session_storage).debug("[session_storage.cleanupExpiredSessions] Checking TTL for key: '{s}'", .{key});

                if (try client.ttl(key)) |ttl| {
                    std.log.scoped(.session_storage).debug("[session_storage.cleanupExpiredSessions] Key '{s}' has TTL: {d}", .{ key, ttl });

                    if (ttl <= 0) {
                        std.log.scoped(.session_storage).debug("[session_storage.cleanupExpiredSessions] Deleting expired key: '{s}'", .{key});
                        _ = try client.del(key);
                        expired_token_count += 1;
                    }
                } else {
                    std.log.scoped(.session_storage).debug("[session_storage.cleanupExpiredSessions] Failed to get TTL for key: '{s}'", .{key});
                }
            }

            // Check if cursor is "0", not the integer 0
            if (std.mem.eql(u8, cursor, "0")) {
                std.log.scoped(.session_storage).debug("[session_storage.cleanupExpiredSessions] Completed scan of token keys", .{});
                break;
            }
        }

        std.log.scoped(.session_storage).debug("[session_storage.cleanupExpiredSessions] Processed {d} token keys, deleted {d} expired tokens", .{ token_count, expired_token_count });
        std.log.scoped(.session_storage).debug("[session_storage.cleanupExpiredSessions] Cleanup completed successfully", .{});
    }

    pub fn getUserActiveSessions(self: *SessionStorage, user_id: u64) ![]Session {
        var sessions = std.ArrayList(Session).init(self.allocator);
        errdefer sessions.deinit();

        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        const user_key = try std.fmt.allocPrint(self.allocator, "user:{d}:sessions", .{user_id});
        defer self.allocator.free(user_key);

        if (try client.sMembers(user_key)) |session_ids| {
            for (session_ids) |session_id| {
                if (try self.getSessionById(session_id)) |session| {
                    try sessions.append(session);
                }
            }
        }
        return sessions.toOwnedSlice(); // Caller needs to free this
    }

    pub const SessionError = error{
        InvalidSession,
        StorageError,
        ParseError,
    };
};
