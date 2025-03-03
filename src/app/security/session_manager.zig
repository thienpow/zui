const std = @import("std");
const crypto = std.crypto;
const jetzig = @import("jetzig");
const types = @import("types.zig");
const config = @import("config.zig");
const redis = @import("../database/redis/redis.zig");
const SessionStorage = @import("session_storage.zig").SessionStorage;
const PooledRedisClient = redis.PooledRedisClient;

const Session = types.Session;
const User = types.User;
const SessionConfig = config.SessionConfig;

pub const SessionManager = struct {
    allocator: std.mem.Allocator,
    storage: SessionStorage,
    config: SessionConfig,
    redis_pool: *PooledRedisClient,

    fn generateSessionId(self: *SessionManager) ![]const u8 {
        var random_bytes: [32]u8 = undefined;
        crypto.random.bytes(&random_bytes);
        const encoded_len = std.base64.standard.Encoder.calcSize(random_bytes.len);
        const encoded = try self.allocator.alloc(u8, encoded_len);
        return std.base64.standard.Encoder.encode(encoded, &random_bytes);
    }

    fn generateSecureToken(self: *SessionManager) ![]const u8 {
        var random_bytes: [48]u8 = undefined;
        crypto.random.bytes(&random_bytes);
        const encoded_len = std.base64.standard.Encoder.calcSize(random_bytes.len);
        const encoded = try self.allocator.alloc(u8, encoded_len);
        return std.base64.standard.Encoder.encode(encoded, &random_bytes);
    }

    pub fn create(self: *SessionManager, user: User, request: *jetzig.Request) !Session {
        // Assuming user.id is u64
        std.log.debug("[session_manager.create] Checking active session count for user_id: {}", .{user.id});
        const active_sessions = try self.storage.getUserActiveSessions(user.id);

        if (active_sessions.len >= self.config.max_sessions_per_user) {
            // Assuming active_sessions[0].id is []const u8 from storage
            if (active_sessions.len > 0) {
                std.log.debug("[session_manager.create] Max sessions ({d}) reached, invalidating oldest session id: '{s}'", .{
                    self.config.max_sessions_per_user,
                    active_sessions[0].id,
                });
                try self.storage.invalidateSession(active_sessions[0].id);
            } else {
                std.log.debug("[session_manager.create] Max sessions ({d}) reached, but no existing sessions found to invalidate", .{
                    self.config.max_sessions_per_user,
                });
            }
        }

        // Assuming user.id is u64
        std.log.debug("[session_manager.create] Creating new session for user_id: {}", .{user.id});
        const session = Session{
            .id = try self.generateSessionId(), // []const u8 from generateSessionId
            .user_id = user.id, // u64
            .token = try self.generateSecureToken(), // []const u8 from generateSecureToken
            .created_at = std.time.timestamp(),
            .expires_at = std.time.timestamp() + self.config.session_ttl,
            .metadata = .{
                .ip_address = user.last_ip,
                .user_agent = user.last_user_agent,
                .device_id = user.device_id,
            },
        };

        // session.id and session.token are []const u8
        std.log.debug("[session_manager.create] Saving session with id: '{s}', token: '{s}'", .{ session.id, session.token });
        try self.storage.saveSession(session);

        // session.token is []const u8
        std.log.debug("[session_manager.create] Setting session cookie with token: '{s}'", .{session.token});
        try self.setSessionCookie(request, session.token);

        // Assuming user.id is u64
        std.log.debug("[session_manager.create] Session created successfully for user_id: {}", .{user.id});
        return session;
    }

    pub fn validate(self: *SessionManager, token: []const u8, request: *jetzig.Request) !Session {
        // Debug: Log the token value and length
        std.log.debug("[session_manager.validate] Token received: '{s}' (length: {})", .{ token, token.len });

        const session = try self.storage.getSession(token) orelse {
            std.log.debug("[session_manager.validate] No session found for token: '{s}'", .{token});
            return error.InvalidSession;
        };

        if (self.isExpired(session)) {
            std.log.debug("[session_manager.validate] Session expired for token: '{s}', id: '{s}'", .{ token, session.id });
            try self.storage.invalidateSession(session.id);
            return error.SessionExpired;
        }

        if (self.needsRefresh(session)) {
            std.log.debug("[session_manager.validate] Session needs refresh for token: '{s}', id: '{s}'", .{ token, session.id });
            return try self.refresh(session, request);
        }

        std.log.debug("[session_manager.validate] Session valid for token: '{s}', id: '{s}'", .{ token, session.id });
        return session;
    }

    pub fn refresh(self: *SessionManager, session: Session, request: *jetzig.Request) !Session {
        var new_session = session;
        new_session.id = try self.generateSessionId();
        new_session.token = try self.generateSecureToken();
        new_session.expires_at = std.time.timestamp() + self.config.session_ttl;

        try self.storage.saveSession(new_session);
        try self.storage.invalidateSession(session.id);
        try self.setSessionCookie(request, new_session.token);

        return new_session;
    }

    fn isExpired(_: *SessionManager, session: Session) bool {
        return std.time.timestamp() >= session.expires_at;
    }

    fn needsRefresh(self: *SessionManager, session: Session) bool {
        const time_left = session.expires_at - std.time.timestamp();
        return time_left < self.config.refresh_threshold;
    }

    // --- Cookie Management Functions ---

    fn setSessionCookie(self: *SessionManager, request: *jetzig.Request, token: []const u8) !void {
        // Format the Set-Cookie header value
        const cookie_value = try std.fmt.allocPrint(self.allocator, "session_id={s}; Max-Age={d}; Path=/; HttpOnly; Secure; SameSite=Strict", .{
            token,
            self.config.session_ttl,
        });
        defer self.allocator.free(cookie_value);

        // Append to response headers
        try request.response.headers.append("Set-Cookie", cookie_value);
    }

    pub fn clearSessionCookie(_: *SessionManager, request: *jetzig.Request) !void {
        // Set an expired cookie to clear it
        const cookie_value = "session_id=; Max-Age=0; Path=/; HttpOnly; Secure; SameSite=Strict";
        try request.response.headers.append("Set-Cookie", cookie_value);
    }

    pub fn getSessionTokenFromCookie(self: *SessionManager, request: *jetzig.Request) ?[]const u8 {
        _ = self;
        const cookie_header = request.headers.get("Cookie") orelse return null;

        var cookie_iter = std.mem.tokenize(u8, cookie_header, "; ");
        while (cookie_iter.next()) |cookie| {
            if (std.mem.startsWith(u8, cookie, "session_id=")) {
                return cookie["session_id=".len..];
            }
        }
        return null;
    }

    pub fn cleanup(self: *SessionManager) !void {
        try self.storage.cleanupExpiredSessions();
        // Add other cleanup tasks as needed
    }
};
