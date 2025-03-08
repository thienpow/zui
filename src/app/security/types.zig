const std = @import("std");
const errors = @import("errors.zig");

pub const SecurityEvent = enum {
    // Authentication events
    credential_check,
    access_denied,
    login_success,
    login_failed,
    logout,
    password_changed,
    password_reset_requested,
    password_reset_completed,

    // Session events
    session_created,
    session_expired,
    session_invalidated,
    session_refreshed,

    // Access control events
    unauthorized_access,
    permission_denied,
    rate_limit_exceeded,

    // Account security events
    account_locked,
    account_unlocked,
    account_disabled,
    account_enabled,

    // MFA events
    mfa_enabled,
    mfa_disabled,
    mfa_challenge_success,
    mfa_challenge_failed,

    // Token events
    token_created,
    token_revoked,
    token_refreshed,
    token_expired,

    // Admin events
    admin_login,
    admin_action,
    settings_changed,

    // Security configuration events
    security_config_changed,
    policy_updated,

    // Suspicious activity
    suspicious_ip_detected,
    suspicious_activity_detected,
    brute_force_attempt,

    // Data access events
    sensitive_data_accessed,
    data_export_initiated,
    data_deleted,

    // API security events
    api_key_created,
    api_key_revoked,
    api_access_denied,

    // System events
    system_error,
    security_alert,
};

pub const ErrorDetails = struct {
    details: []const u8,
    severity: Severity,
    category: []const u8,
};

pub const StorageType = enum {
    redis,
    database,
    both,
};

pub const Severity = enum {
    low,
    medium,
    high,

    pub fn toString(self: Severity) []const u8 {
        return switch (self) {
            .low => "low",
            .medium => "medium",
            .high => "high",
        };
    }
};

pub const Session = struct {
    id: []const u8,
    user_id: u64,
    token: []const u8,
    created_at: i64,
    expires_at: i64,
    metadata: SessionMetadata,

    pub fn deepCopy(self: *const Session, allocator: std.mem.Allocator) !Session {
        return Session{
            .id = try allocator.dupe(u8, self.id),
            .user_id = self.user_id,
            .token = try allocator.dupe(u8, self.token),
            .created_at = self.created_at,
            .expires_at = self.expires_at,
            .metadata = SessionMetadata{
                .ip_address = if (self.metadata.ip_address) |ip|
                    try allocator.dupe(u8, ip)
                else
                    null,
                .user_agent = if (self.metadata.user_agent) |ua|
                    try allocator.dupe(u8, ua)
                else
                    null,
                .device_id = if (self.metadata.device_id) |ua|
                    try allocator.dupe(u8, ua)
                else
                    null,
            },
        };
    }
};

pub const SessionMetadata = struct {
    ip_address: ?[]const u8,
    user_agent: ?[]const u8,
    device_id: ?[]const u8,
};

pub const User = struct {
    id: u64,
    email: []const u8,
    last_ip: ?[]const u8,
    last_user_agent: ?[]const u8,
    device_id: ?[]const u8,
    last_login_at: i64, // Using i64 to accommodate negative timestamps if needed
    is_active: ?bool,
    is_banned: ?bool,
};

pub const Token = struct {
    access: []const u8,
    refresh: []const u8,
    csrf: []const u8,
};

pub const AuthenticationCredentials = struct {
    session: Session,
    user: User,
    token: Token,
};

pub const Credentials = struct {
    email: []const u8,
    password: []const u8,
};

pub const AuthStrategy = enum {
    session, // Cookie-based session
    jwt, // JWT bearer token
    api_key, // API key
    basic, // HTTP Basic Auth
    oauth, // oauth2.0 support like google,github,X
    none, // No authentication (public route)
};

pub const ProtectedRoute = struct {
    prefix: []const u8,
    strategies: []const AuthStrategy,
    required_roles: ?[]const []const u8 = null, // Optional: roles required for access
};

pub const OAuthProvider = enum {
    google,
    github,
    facebook,
    microsoft,
    apple,
    custom,
};

pub const AuthResult = struct {
    authenticated: bool,
    user_id: ?u64 = null,
    roles: ?[]const []const u8 = null,
    strategy_used: ?AuthStrategy = null,
    errors: ?errors.SecurityError = null,
};
