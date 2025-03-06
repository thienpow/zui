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
        std.log.debug("[session_manager.create] Checking active session count for user_id: {}", .{user.id});
        const active_sessions = try self.storage.getUserActiveSessions(user.id);

        if (active_sessions.len >= self.config.max_sessions_per_user) {
            if (active_sessions.len > 0) {
                std.log.debug("[session_manager.create] Max sessions ({d}) reached", .{
                    self.config.max_sessions_per_user,
                });
                try self.storage.invalidateSession(active_sessions[0].id);
            } else {
                std.log.debug("[session_manager.create] Max sessions ({d}) reached, but no existing sessions found to invalidate", .{
                    self.config.max_sessions_per_user,
                });
            }
        }

        std.log.debug("[session_manager.create] Creating new session for user_id: {}", .{user.id});
        const session = Session{
            .id = try self.generateSessionId(),
            .user_id = user.id,
            .token = try self.generateSecureToken(),
            .created_at = std.time.timestamp(),
            .expires_at = std.time.timestamp() + self.config.session_ttl,
            .metadata = .{
                .ip_address = user.last_ip,
                .user_agent = request.headers.get("User-Agent") orelse user.last_user_agent,
                .device_id = user.device_id,
            },
        };

        std.log.debug("[session_manager.create] Saving session with id: '{s}', token: '{s}'", .{ session.id, session.token });
        try self.storage.saveSession(session);

        std.log.debug("[session_manager.create] Setting session cookie with token: '{s}'", .{session.token});
        try self.setSessionCookie(request, session.token);

        std.log.debug("[session_manager.create] Session created successfully for user_id: {}", .{user.id});
        return session;
    }

    pub fn validate(self: *SessionManager, token: []const u8, request: *jetzig.Request) !Session {
        std.log.debug("[session_manager.validate] Token received: '{s}' (length: {})", .{ token, token.len });

        const session = try self.storage.getSessionByToken(token) orelse {
            std.log.debug("[session_manager.validate] No session found for token: '{s}'", .{token});
            try self.clearSessionCookie(request);
            return error.InvalidSession;
        };

        std.log.debug("[session_manager.validate] Session found: id='{s}', user_id={d}, token='{s}'", .{ session.id, session.user_id, session.token });
        std.log.debug("[session_manager.validate] Session metadata: ip_address='{s}', user_agent='{s}'", .{ session.metadata.ip_address orelse "null", session.metadata.user_agent orelse "null" });

        if (self.isExpired(session)) {
            std.log.debug("[session_manager.validate] Session expired for token: '{s}', id: '{s}'", .{ token, session.id });
            try self.storage.invalidateSession(session.id);
            try self.clearSessionCookie(request);
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

    pub fn setSessionCookie(self: *SessionManager, request: *jetzig.Request, token: []const u8) !void {
        std.log.debug("[session_manager.setSessionCookie] Starting cookie set for token: '{s}'", .{token});
        const cookies = try request.cookies();
        std.log.debug("[session_manager.setSessionCookie] Cookies object retrieved", .{});

        try cookies.put(.{
            .name = "session_token",
            .value = token,
            .path = "/",
            .http_only = true,
            .secure = true,
            .same_site = .strict,
            .max_age = self.config.session_ttl,
        });
        std.log.debug("[session_manager.setSessionCookie] Cookie 'session_token' set with value: '{s}', max_age: {}", .{ token, self.config.session_ttl });
    }

    pub fn clearSessionCookie(_: *SessionManager, request: *jetzig.Request) !void {
        const cookies = try request.cookies();
        try cookies.put(.{
            .name = "session_token",
            .value = "",
            .path = "/",
            .http_only = true,
            .secure = true,
            .same_site = .strict,
            .max_age = 0,
        });
    }

    pub fn getSessionTokenFromCookie(_: *SessionManager, request: *jetzig.Request) !?[]const u8 {
        std.log.debug("[session_manager.getSessionTokenFromCookie] Starting cookie retrieval", .{});

        // Attempt to get the cookies object from the request
        std.log.debug("[session_manager.getSessionTokenFromCookie] Calling request.cookies()", .{});
        const cookies = try request.cookies();
        std.log.debug("[session_manager.getSessionTokenFromCookie] Successfully retrieved cookies object", .{});

        // Check if the session_token cookie exists
        std.log.debug("[session_manager.getSessionTokenFromCookie] Looking for 'session_token' cookie", .{});
        if (cookies.get("session_token")) |cookie| {
            std.log.debug("[session_manager.getSessionTokenFromCookie] Found 'session_token' cookie with value: '{s}'", .{cookie.value});
            std.log.debug("[session_manager.getSessionTokenFromCookie] Returning token: '{s}' (length: {})", .{ cookie.value, cookie.value.len });
            return cookie.value;
        } else {
            std.log.debug("[session_manager.getSessionTokenFromCookie] No 'session_token' cookie found", .{});
            std.log.debug("[session_manager.getSessionTokenFromCookie] Returning null", .{});
            return null;
        }
    }

    pub fn cleanup(self: *SessionManager) !void {
        try self.storage.cleanupExpiredSessions();
        try self.clearSessionCookie();
    }
};
