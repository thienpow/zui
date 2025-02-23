pub const SecurityEvent = enum {
    // Authentication events
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
};

pub const SessionMetadata = struct {
    ip_address: ?[]const u8,
    user_agent: ?[]const u8,
    device_id: ?[]const u8,
};

pub const User = struct {
    id: u64,
    last_ip: ?[]const u8,
    last_user_agent: ?[]const u8,
    device_id: ?[]const u8,
    // Add other user fields as needed
};

pub const Tokens = struct {
    access: []const u8,
    refresh: []const u8,
    csrf: []const u8,
};

pub const AuthResult = struct {
    session: Session,
    user: User,
    tokens: Tokens,
};

pub const Credentials = struct {
    email: []const u8,
    password: []const u8,
};
