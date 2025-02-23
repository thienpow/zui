const SessionStorage = @import("session_storage.zig");
const types = @import("types.zig");
const redis = @import("../database/redis/redis.zig");

const SecurityEvent = types.SecurityEvent;
const PooledRedisClient = redis.PooledRedisClient;
const StorageType = SessionStorage.StorageType;

pub const SecurityConfig = struct {
    session: SessionConfig,
    storage: StorageConfig,
    tokens: TokenConfig,
    rate_limit: RateLimitConfig,
    audit: AuditConfig,
    redis_pool: *PooledRedisClient,

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
    storage_type: SessionStorage.StorageType = .both,
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

pub const AuditConfig = struct {
    enabled: bool = true,
    high_risk_events: []const SecurityEvent = &.{
        .login_failed,
        .password_changed,
        .mfa_disabled,
    },
    log_retention_days: u32 = 90,
};
