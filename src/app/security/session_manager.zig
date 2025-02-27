const std = @import("std");
const crypto = std.crypto;
const types = @import("types.zig");
const config = @import("config.zig");
const SessionStorage = @import("session_storage.zig").SessionStorage;

const Session = types.Session;
const User = types.User;
const SessionConfig = config.SessionConfig;

pub const SessionManager = struct {
    allocator: std.mem.Allocator,
    storage: *SessionStorage,
    session_config: SessionConfig,

    pub fn init(allocator: std.mem.Allocator, storage: *SessionStorage, session_config: SessionConfig) SessionManager {
        return .{
            .allocator = allocator,
            .storage = storage,
            .session_config = session_config,
        };
    }

    pub fn deinit(self: *SessionManager) void {
        _ = self;
        // Need to implement cleanup of stored sessions

    }
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

    pub fn create(self: *SessionManager, user: User) !Session {
        // Check active session count
        std.log.info("[session_manager.create] -- Check active session count {any}", .{0});
        const active_sessions = try self.storage.getUserActiveSessions(user.id);

        if (active_sessions.len >= self.session_config.max_sessions_per_user) {
            // Either return error or invalidate oldest session
            try self.storage.invalidateSession(active_sessions[0].id);
        }

        // Create new session
        std.log.info("[session_manager.create] -- Create new session {any}", .{0});
        const session = Session{
            .id = try self.generateSessionId(),
            .user_id = user.id,
            .token = try self.generateSecureToken(),
            .created_at = std.time.timestamp(),
            .expires_at = std.time.timestamp() + self.session_config.session_ttl,
            .metadata = .{
                .ip_address = user.last_ip,
                .user_agent = user.last_user_agent,
                .device_id = user.device_id,
            },
        };

        // Save session
        std.log.info("[session_manager.create] -- Save session {any}", .{0});
        try self.storage.saveSession(session);

        return session;
    }

    pub fn validate(self: *SessionManager, token: []const u8) !Session {
        const session = try self.storage.getSession(token) orelse
            return error.InvalidSession;

        if (self.isExpired(session)) {
            try self.storage.invalidateSession(session.id);
            return error.SessionExpired;
        }

        if (self.needsRefresh(session)) {
            return try self.refresh(session);
        }

        return session;
    }

    pub fn refresh(self: *SessionManager, session: Session) !Session {
        // Create new session with extended expiry
        var new_session = session;
        new_session.id = try self.generateSessionId();
        new_session.token = try self.generateSecureToken();
        new_session.expires_at = std.time.timestamp() + self.session_config.session_ttl;

        // Save new session
        try self.storage.saveSession(new_session);

        // Invalidate old session
        try self.storage.invalidateSession(session.id);

        return new_session;
    }

    fn isExpired(_: *SessionManager, session: Session) bool {
        return std.time.timestamp() >= session.expires_at;
    }

    fn needsRefresh(self: *SessionManager, session: Session) bool {
        const time_left = session.expires_at - std.time.timestamp();
        return time_left < self.config.refresh_threshold;
    }
};
