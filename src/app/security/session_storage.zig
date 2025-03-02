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

    pub fn getSession(self: *SessionStorage, token: []const u8) !?Session {
        std.log.info("[session_storage.getSession] token={s}", .{token});
        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        const key = try std.fmt.allocPrint(self.allocator, "session:{s}", .{token});
        defer self.allocator.free(key);

        // Handle the optional result from get()
        const data = (try client.get(key)) orelse {
            std.log.info("[session_storage.getSession] Key not found: {s}", .{key});
            return null;
        };

        defer self.allocator.free(data);

        const parsed = std.json.parseFromSlice(
            Session,
            self.allocator,
            data,
            .{},
        ) catch |err| {
            std.log.err("Failed to parse session data: {}", .{err});
            return null;
        };
        defer parsed.deinit();

        return parsed.value;
    }

    // fn saveToDatabase(self: *SessionStorage, session: Session) !void {
    //     try self.db_pool.transaction(struct {
    //         pub fn run(tx: *sql.Transaction) !void {
    //             // Store session
    //             try tx.exec(
    //                 \\INSERT INTO sessions
    //                 \\(id, user_id, token, created_at, expires_at, metadata)
    //                 \\VALUES (?, ?, ?, ?, ?, ?)
    //             ,
    //                 .{
    //                     session.id,
    //                     session.user_id,
    //                     session.token,
    //                     session.created_at,
    //                     session.expires_at,
    //                     session.metadata,
    //                 },
    //             );

    //             // Update session count
    //             try tx.exec(
    //                 \\INSERT INTO user_session_stats
    //                 \\(user_id, session_count, last_session_at)
    //                 \\VALUES (?, 1, ?)
    //                 \\ON CONFLICT (user_id) DO UPDATE
    //                 \\SET session_count = session_count + 1,
    //                 \\    last_session_at = EXCLUDED.last_session_at
    //             ,
    //                 .{
    //                     session.user_id,
    //                     session.created_at,
    //                 },
    //             );
    //         }
    //     });
    // }

    pub fn invalidateSession(self: *SessionStorage, session_id: []const u8) !void {
        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        const key = try std.fmt.allocPrint(self.allocator, "session:{s}", .{session_id});
        defer self.allocator.free(key);

        _ = try client.del(key);
    }

    pub fn saveSession(self: *SessionStorage, session: Session) !void {
        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        const key = try std.fmt.allocPrint(self.allocator, "session:{s}", .{session.id});
        defer self.allocator.free(key);

        // Create a buffer for JSON serialization
        var json_buffer = std.ArrayList(u8).init(self.allocator);
        defer json_buffer.deinit();

        // Stringify the session into the buffer
        try std.json.stringify(session, .{}, json_buffer.writer());

        // Get the resulting JSON string
        const value = json_buffer.items;

        try client.setEx(key, value, self.session_config.session_ttl);

        const user_key = try std.fmt.allocPrint(self.allocator, "user:{d}:sessions", .{session.user_id});
        defer self.allocator.free(user_key);

        try client.sAdd(user_key, session.id);
        try client.expire(user_key, self.session_config.session_ttl);
    }

    pub fn cleanupExpiredSessions(self: *SessionStorage) !void {
        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        // Use Redis SCAN to iterate over session keys
        var cursor: u64 = 0;
        const pattern = "session:*";
        const batch_size: u64 = 100;

        while (true) {
            const scan_result = try client.scan(cursor, pattern, batch_size);
            cursor = scan_result.cursor;

            for (scan_result.keys) |key| {
                if (try client.ttl(key)) |ttl| {
                    if (ttl <= 0) {
                        _ = try client.del(key);
                    }
                }
            }

            if (cursor == 0) break;
        }
    }

    pub fn getUserActiveSessions(self: *SessionStorage, user_id: u64) ![]Session {
        var sessions = std.ArrayList(Session).init(self.allocator);
        errdefer sessions.deinit();

        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        const user_key = try std.fmt.allocPrint(self.allocator, "user:{}:sessions", .{user_id});
        defer self.allocator.free(user_key);

        if (try client.sMembers(user_key)) |session_ids| {
            for (session_ids) |session_id| {
                if (try self.getSession(session_id)) |session| {
                    try sessions.append(session);
                }
            }
        }
        return sessions.toOwnedSlice(); // Caller needs to free this
    }

    fn removeFromRedis(self: *SessionStorage, session_id: []const u8) !void {
        var client = try self.redis_pool.acquire();
        defer self.redis_pool.release(client);

        const key = try std.fmt.allocPrint(self.allocator, "session:{s}", .{session_id});
        defer self.allocator.free(key);

        _ = try client.del(key);
    }

    pub const SessionError = error{
        InvalidSession,
        StorageError,
        ParseError,
    };
};
