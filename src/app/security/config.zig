const SessionStorage = @import("session_storage.zig");
const types = @import("types.zig");
const redis = @import("../database/redis/redis.zig");

const SecurityEvent = types.SecurityEvent;
const PooledRedisClient = redis.PooledRedisClient;
const StorageType = types.StorageType;
const ProtectedRoute = types.ProtectedRoute;

pub const SecurityConfig = struct {
    auth_middleware: AuthMiddlewareConfig,
    session: SessionConfig,
    storage: StorageConfig,
    tokens: TokenConfig,
    rate_limit: RateLimitConfig,
    audit: AuditLogConfig,

    pub fn validate(self: SecurityConfig) !void {
        if (self.session.session_ttl <= 0) return error.InvalidSessionTTL;
        if (self.session.max_sessions_per_user == 0) return error.InvalidSessionLimit;
        if (self.tokens.token_length < 32) return error.InsecureTokenLength;
        if (self.rate_limit.window_seconds == 0) return error.InvalidRateLimit;
        if (self.rate_limit.lockout_duration < self.rate_limit.window_seconds)
            return error.InvalidLockoutDuration;
    }
};

pub const SessionConfig = struct {
    max_sessions_per_user: u32 = 5,
    session_ttl: i64 = 24 * 60 * 60, // 24 hours in seconds
    refresh_threshold: i64 = 60 * 60, // 1 hour in seconds
    cleanup_interval: i64 = 60 * 60, // 1 hour in seconds
};

pub const StorageConfig = struct {
    storage_type: StorageType = StorageType.both,
    cleanup_batch_size: u32 = 1000,
};

pub const TokenConfig = struct {
    access_token_ttl: i64 = 15 * 60, // 15 minutes
    refresh_token_ttl: i64 = 7 * 24 * 60 * 60, // 7 days
    token_length: usize = 48,
};

pub const RateLimitConfig = struct {
    max_attempts: u32 = 5,
    window_seconds: u32 = 300, // 5 minutes
    lockout_duration: u32 = 900, // 15 minutes
};

pub const AuditLogConfig = struct {
    enabled: bool = true,
    high_risk_events: []const SecurityEvent = &.{
        .login_failed,
        .password_changed,
        .mfa_disabled,
    },
    notify_admins: bool = true,
    store_type: StorageType = StorageType.both,
    log_retention_days: u32 = 90,
};

/// Configuration for authentication middleware
pub const AuthMiddlewareConfig = struct {
    /// List of protected routes with their authentication strategies
    protected_routes: []const ProtectedRoute,

    /// Default redirect URL for unauthenticated browser requests
    login_redirect_url: []const u8 = "/auth/login",

    /// Whether to append return_to parameter to login redirects
    use_return_to: bool = true,

    /// Custom response for API authentication failures
    api_error_message: []const u8 = "Unauthorized access",
};
