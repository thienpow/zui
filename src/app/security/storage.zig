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
        std.log.scoped(.auth).debug("[SessionStorage.getSessionByToken] token={s}", .{token});
        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        const key = try std.fmt.allocPrint(self.allocator, "session_token:{s}", .{token});
        defer self.allocator.free(key);

        // Handle the optional result from get()
        const data = (try client.get(key)) orelse {
            std.log.scoped(.auth).debug("[SessionStorage.getSessionByToken] Key not found: {s}", .{key});
            return null;
        };

        std.log.scoped(.auth).debug("[SessionStorage.getSessionByToken] Raw data retrieved: {s}", .{data});

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

        std.log.scoped(.auth).debug("[SessionStorage.getSessionByToken] Parsed session ID: {s}", .{session.id});
        return session;
    }

    pub fn getSessionById(self: *SessionStorage, session_id: []const u8) !?Session {
        std.log.scoped(.auth).debug("[SessionStorage.getSessionById] session_id={s}", .{session_id});
        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);
        const key = try std.fmt.allocPrint(self.allocator, "session:{s}", .{session_id});
        defer self.allocator.free(key);

        // Handle the optional result from get()
        const data = (try client.get(key)) orelse {
            std.log.scoped(.auth).debug("[SessionStorage.getSessionById] Key not found: {s}", .{key});
            return null;
        };

        std.log.scoped(.auth).debug("[SessionStorage.getSessionById] Raw data retrieved: {s}", .{data});

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
        std.log.scoped(.auth).debug("[SessionStorage.getSessionById] Parsed session ID: {s}", .{session.id});
        return session;
    }

    pub fn invalidateSession(self: *SessionStorage, session_id: []const u8) !void {
        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        // First get the session to find its token
        const session = (try self.getSessionById(session_id)) orelse {
            std.log.scoped(.auth).debug("[SessionStorage.invalidateSession] Session not found: {s}", .{session_id});
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
        std.log.scoped(.auth).debug("[SessionStorage.saveSession] Saving session: id='{s}' (len: {})", .{ session.id, session.id.len });
        std.log.scoped(.auth).debug("[SessionStorage.saveSession] User ID: {d}, token='{s}' (len: {})", .{ session.user_id, session.token, session.token.len });

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

        std.log.scoped(.auth).debug("[SessionStorage.saveSession] Metadata: ip_address={s}, user_agent={s}", .{ ip_str, ua_str });

        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        // Create a buffer for JSON serialization
        var json_buffer = std.ArrayList(u8).init(self.allocator);
        defer json_buffer.deinit();

        // Stringify the session into the buffer
        try std.json.stringify(session, .{}, json_buffer.writer());

        // Get the resulting JSON string and log it
        const value = json_buffer.items;
        std.log.scoped(.auth).debug("[SessionStorage.saveSession] JSON serialized: {s}", .{value});

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

    pub fn cleanupExpiredSessions(_: *SessionStorage) !void {}

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
