const std = @import("std");

const crypto = std.crypto;
const jetzig = @import("jetzig");
const types = @import("types.zig");
const config = @import("config.zig");
const redis = @import("../database/redis/redis.zig");
const cookie_utils = @import("../utils/cookie.zig");
const token_utils = @import("../utils/token.zig");

const SessionStorage = @import("storage.zig").SessionStorage;
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

    pub fn create(self: *SessionManager, request: *jetzig.Request, user: User, remember: bool) !Session {
        std.log.scoped(.auth).debug("[SessionManager.create] Checking active session count for user_id: {}", .{user.id});
        const active_sessions = try self.storage.getUserActiveSessions(user.id);

        if (active_sessions.len >= self.config.max_sessions_per_user) {
            if (active_sessions.len > 0) {
                std.log.scoped(.auth).debug("[SessionManager.create] Max sessions ({d}) reached", .{
                    self.config.max_sessions_per_user,
                });
                try self.storage.invalidateSession(active_sessions[0].id);
            } else {
                std.log.scoped(.auth).debug("[SessionManager.create] Max sessions ({d}) reached, but no existing sessions found to invalidate", .{
                    self.config.max_sessions_per_user,
                });
            }
        }

        var max_age: i64 = 0;
        if (remember) {
            max_age = self.config.extended_session_ttl; // remember will use extended_session_ttl
        } else {
            max_age = self.config.session_ttl; // not remember will use session_ttl
        }

        std.log.scoped(.auth).debug("[SessionManager.create] Creating new session for user_id: {}", .{user.id});
        const session = Session{
            .id = try self.generateSessionId(),
            .user_id = user.id,
            .token = try token_utils.generateSecureToken(self.allocator),
            .created_at = std.time.timestamp(),
            .expires_at = std.time.timestamp() + max_age,
            .metadata = .{
                .ip_address = user.last_ip,
                .user_agent = request.headers.get("User-Agent") orelse user.last_user_agent,
                .device_id = user.device_id,
            },
        };

        std.log.scoped(.auth).debug("[SessionManager.create] Saving session with id: '{s}', token: '{s}'", .{ session.id, session.token });
        try self.storage.saveSession(session);

        try cookie_utils.set_cookie_with_age(request, self.config.cookie_name, session.token, max_age);
        std.log.scoped(.auth).debug("[SessionManager.create] Setting session cookie with token: '{s}'", .{session.token});

        std.log.scoped(.auth).debug("[SessionManager.create] Session created successfully for user_id: {}", .{user.id});
        return session;
    }

    pub fn validate(self: *SessionManager, token: []const u8, request: *jetzig.Request) !Session {
        std.log.scoped(.auth).debug("[SessionManager.validate] Token received: '{s}' (length: {})", .{ token, token.len });

        const session = try self.storage.getSessionByToken(token) orelse {
            std.log.scoped(.auth).debug("[SessionManager.validate] No session found for token: '{s}'", .{token});
            try self.clearSessionCookie(request);
            return error.InvalidSession;
        };

        std.log.scoped(.auth).debug("[SessionManager.validate] Session found: id='{s}', user_id={d}, token='{s}'", .{ session.id, session.user_id, session.token });
        std.log.scoped(.auth).debug("[SessionManager.validate] Session metadata: ip_address='{s}', user_agent='{s}'", .{ session.metadata.ip_address orelse "null", session.metadata.user_agent orelse "null" });

        if (self.isExpired(session)) {
            std.log.scoped(.auth).debug("[SessionManager.validate] Session expired for token: '{s}', id: '{s}'", .{ token, session.id });
            try self.storage.invalidateSession(session.id);
            try self.clearSessionCookie(request);
            return error.SessionExpired;
        }

        if (self.needsRefresh(session)) {
            std.log.scoped(.auth).debug("[SessionManager.validate] Session needs refresh for token: '{s}', id: '{s}'", .{ token, session.id });
            return try self.refresh(session, request);
        }

        std.log.scoped(.auth).debug("[SessionManager.validate] Session valid for token: '{s}', id: '{s}'", .{ token, session.id });
        return session;
    }

    pub fn refresh(self: *SessionManager, session: Session, request: *jetzig.Request) !Session {
        var new_session = session;
        new_session.id = try self.generateSessionId();
        new_session.token = try token_utils.generateSecureToken(self.allocator);
        new_session.expires_at = std.time.timestamp() + self.config.session_ttl;

        try self.storage.saveSession(new_session);
        try self.storage.invalidateSession(session.id);

        try cookie_utils.set_cookie_with_age(request, self.config.cookie_name, new_session.token, self.config.session_ttl);

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

    pub fn clearSessionCookie(self: *SessionManager, request: *jetzig.Request) !void {
        try cookie_utils.set_cookie(request, self.config.cookie_name, "");
    }

    pub fn getSessionTokenFromCookie(self: *SessionManager, request: *jetzig.Request) !?[]const u8 {
        std.log.scoped(.auth).debug("[SessionManager.getSessionTokenFromCookie] Starting cookie retrieval", .{});

        // Attempt to get the cookies object from the request
        std.log.scoped(.auth).debug("[SessionManager.getSessionTokenFromCookie] Calling request.cookies()", .{});
        const cookies = try request.cookies();
        std.log.scoped(.auth).debug("[SessionManager.getSessionTokenFromCookie] Successfully retrieved cookies object", .{});

        // Check if the cookie exists
        std.log.scoped(.auth).debug("[SessionManager.getSessionTokenFromCookie] Looking for '{s}' cookie", .{self.config.cookie_name});
        if (cookies.get(self.config.cookie_name)) |cookie| {
            std.log.scoped(.auth).debug("[SessionManager.getSessionTokenFromCookie] Found '{s}' cookie with value: '{s}'", .{ self.config.cookie_name, cookie.value });
            std.log.scoped(.auth).debug("[SessionManager.getSessionTokenFromCookie] Returning token: '{s}' (length: {})", .{ cookie.value, cookie.value.len });
            return cookie.value;
        } else {
            std.log.scoped(.auth).debug("[SessionManager.getSessionTokenFromCookie] No '{s}' cookie found", .{self.config.cookie_name});
            std.log.scoped(.auth).debug("[SessionManager.getSessionTokenFromCookie] Returning null", .{});
            return null;
        }
    }

    pub fn cleanup(self: *SessionManager, request: *jetzig.Request) !void {
        try self.storage.cleanupExpiredSessions();
        try self.clearSessionCookie(request);
    }
};
