const std = @import("std");
const jetzig = @import("jetzig");

const redis = @import("../database/redis/redis.zig");
const PooledRedisClient = redis.PooledRedisClient;

// Internal module imports
const types = @import("types.zig");
const Severity = types.Severity;
const SecurityEvent = types.SecurityEvent;
const Session = types.Session;
const User = types.User;
const AuthResult = types.AuthResult;
const Credentials = types.Credentials;
const ErrorDetails = types.ErrorDetails;

const config = @import("config.zig");
const SecurityConfig = config.SecurityConfig;

const errors = @import("errors.zig");
const SecurityError = errors.SecurityError;

const audit_log = @import("audit_log.zig");
const AuditContext = audit_log.AuditContext;
const AuditLog = audit_log.AuditLog;
const AuditLogConfig = audit_log.AuditLogConfig;

const SessionManager = @import("session_manager.zig").SessionManager;
const SessionStorage = @import("session_storage.zig").SessionStorage;
const TokenManager = @import("token_manager.zig").TokenManager;
const RateLimiter = @import("rate_limiter.zig").RateLimiter;
const validation = @import("validation.zig");

// Re-export common types and configurations
pub usingnamespace types;
pub usingnamespace config;
pub usingnamespace errors;

pub const Security = struct {
    allocator: std.mem.Allocator,
    session: SessionManager,
    storage: SessionStorage,
    tokens: TokenManager,
    rate_limiter: RateLimiter,
    audit: AuditLog,
    config: config.SecurityConfig,
    redis_pool: *PooledRedisClient,

    pub fn init(allocator: std.mem.Allocator, security_config: SecurityConfig) !Security {
        var storage = try SessionStorage.init(
            allocator,
            security_config.session,
            security_config.redis_pool,
        );

        const audit_context = AuditContext{
            .ip_address = null,
            .user_agent = null,
        };

        const audit_config = AuditLogConfig{
            .enabled = security_config.audit.enabled,
            .high_risk_events = security_config.audit.high_risk_events,
            .notify_admins = true,
            .store_type = .both,
        };

        return Security{
            .allocator = allocator,
            .config = security_config,
            .session = SessionManager.init(allocator, &storage, security_config.session),
            .storage = storage,
            .tokens = try TokenManager.init(allocator, security_config.tokens, security_config.redis_pool),
            .rate_limiter = RateLimiter{
                .config = security_config.rate_limit,
                .redis_pool = security_config.redis_pool,
            },
            .audit = try AuditLog.init(allocator, audit_config, audit_context, security_config.redis_pool),
            .redis_pool = security_config.redis_pool,
        };
    }

    pub fn deinit(self: *Security) void {
        self.storage.deinit();
        self.audit.deinit();
        self.tokens.deinit();
        self.session.deinit();
    }

    // fn handleValidationError(
    //     self: *Security,
    //     err: anyerror,
    //     event: SecurityEvent,
    //     user_id: ?u64,
    //     request: *jetzig.Request,
    //     context: ?[]const u8,
    // ) !void {
    //     const identifier = try self.getIdentifier(request);

    //     const error_details: ErrorDetails = switch (err) {
    //         // Session-related validation errors
    //         validation.ValidationError.SessionBindingMismatch => .{
    //             .details = "Session binding validation failed",
    //             .severity = .high,
    //             .category = "session_security",
    //         },
    //         validation.ValidationError.InvalidIPAddress => .{
    //             .details = "Invalid IP address detected",
    //             .severity = .medium,
    //             .category = "input_validation",
    //         },
    //         validation.ValidationError.InvalidUserAgent => .{
    //             .details = "Invalid User-Agent detected",
    //             .severity = .medium,
    //             .category = "input_validation",
    //         },

    //         // Metadata validation errors
    //         validation.ValidationError.MetadataValidationFailed => .{
    //             .details = "Metadata validation failed",
    //             .severity = .medium,
    //             .category = "data_validation",
    //         },
    //         validation.ValidationError.PayloadTooLarge => .{
    //             .details = "Validation failed - payload too large",
    //             .severity = .medium,
    //             .category = "data_validation",
    //         },
    //         validation.ValidationError.InvalidCharacters => .{
    //             .details = "Invalid characters detected",
    //             .severity = .medium,
    //             .category = "input_validation",
    //         },

    //         // Resource validation errors
    //         validation.ValidationError.InvalidResourceId => .{
    //             .details = "Invalid resource identifier",
    //             .severity = .medium,
    //             .category = "resource_validation",
    //         },
    //         validation.ValidationError.InvalidResourceType => .{
    //             .details = "Invalid resource type",
    //             .severity = .medium,
    //             .category = "resource_validation",
    //         },
    //         validation.ValidationError.InvalidStatus => .{
    //             .details = "Invalid status value",
    //             .severity = .low,
    //             .category = "data_validation",
    //         },

    //         // Custom data validation errors
    //         validation.ValidationError.CustomDataValidationFailed => .{
    //             .details = "Custom data validation failed",
    //             .severity = .medium,
    //             .category = "data_validation",
    //         },

    //         // Default case
    //         else => .{
    //             .details = "Unexpected validation error",
    //             .severity = .medium,
    //             .category = "unknown",
    //         },
    //     };

    //     // Create audit metadata with detailed information
    //     const metadata = audit_log.AuditMetadata{
    //         .action_details = error_details.details,
    //         .resource_id = context,
    //         .status = "failed",
    //         .error_message = @errorName(err),
    //         .custom_data = (try std.json.parseFromSlice(
    //             std.json.Value,
    //             self.allocator,
    //             try std.fmt.allocPrint(
    //                 self.allocator,
    //                 \\{
    //                 \\"severity": "{s}",
    //                 \\"category": "{s}",
    //                 \\"validation_context": {s},
    //                 \\"request_path": "{s}",
    //                 \\"method": "{s}"
    //                 \\}
    //             ,
    //                 .{
    //                     error_details.severity.toString(),
    //                     error_details.category,
    //                     if (context) |c| try std.fmt.allocPrint(self.allocator, "\"{s}\"", .{c}) else "null",
    //                     request.path,
    //                     request.method,
    //                 },
    //             ),
    //             .{},
    //         )).value,
    //     };

    //     // Log the validation error
    //     try self.audit.log(event, user_id, metadata);

    //     // Optional: Update rate limiting for repeated validation failures
    //     if (error_details.severity == .high) {
    //         try self.rate_limiter.increment(identifier);
    //     }
    // }

    pub fn authenticate(self: *Security, request: *jetzig.Request, credentials: Credentials) !AuthResult {
        const identifier = try self.getIdentifier(request);

        // Validate request metadata
        if (request.headers.get("User-Agent")) |ua| {
            if (!validation.isValidUserAgent(ua)) {
                // try self.handleValidationError(
                //     validation.ValidationError.InvalidUserAgent,
                //     .login_failed,
                //     null,
                //     request,
                //     "authentication",
                // );
                return SecurityError.ValidationError;
            }
        }

        // 1. Rate limit check
        const rate_limit_info = try self.rate_limiter.check(identifier);
        // Check if account is locked
        if (rate_limit_info.is_locked) {
            // try self.handleValidationError(
            //     error.AccountLocked,
            //     .account_locked,
            //     null,
            //     request,
            //     "account_locked",
            // );
            return SecurityError.AccountLocked;
        }

        // Check if rate limit is exceeded
        if (rate_limit_info.remaining == 0) {
            // try self.handleValidationError(
            //     error.RateLimitExceeded,
            //     .rate_limit_exceeded,
            //     null,
            //     request,
            //     "rate_limit",
            // );
            return SecurityError.RateLimitExceeded;
        }

        // 2. Basic auth validation
        const auth_result = self.validateCredentials(request, credentials) catch {
            try self.rate_limiter.increment(identifier);
            try self.audit.log(.login_failed, null, .{
                .action_details = "Invalid credentials",
                .ip_address = identifier,
            });
            return SecurityError.InvalidCredentials;
        };

        // 3. Create session
        const session = try self.session.create(auth_result.user);

        // 4. Generate tokens
        const tokens = try self.tokens.generate(session);

        // 5. Log successful authentication
        try self.audit.log(.login_success, auth_result.user.id, .{
            .action_details = "Successful login",
            .ip_address = identifier,
        });

        // 6. Reset rate limit counter on success
        try self.rate_limiter.reset(identifier);

        return AuthResult{
            .session = session,
            .user = auth_result.user,
            .tokens = tokens,
        };
    }

    fn validateCredentials(self: *Security, request: *jetzig.Request, credentials: Credentials) !struct { user: User } {
        _ = self;
        _ = request;
        _ = credentials; // TODO: Implement actual credential validation
        // Implement actual credential validation using the provided email and password
        return .{ .user = User{
            .id = 1,
            .last_ip = null,
            .last_user_agent = null,
            .device_id = null,
        } };
    }

    pub fn validateSession(self: *Security, request: *jetzig.Request) !Session {
        const token = self.getAuthToken(request) orelse return SecurityError.UnauthorizedAccess;

        const session = try self.session.validate(token) catch |err| {
            // try self.handleValidationError(
            //     err,
            //     .session_invalidated,
            //     null,
            //     request,
            //     "session_validation",
            // );
            return err;
        };

        // Validate IP and User-Agent binding
        try validation.validateSessionBinding(session, request) catch |err| {
            _ = err;
            // try self.handleValidationError(
            //     err,
            //     .session_invalidated,
            //     session.user_id,
            //     request,
            //     "session_binding",
            // );
            return SecurityError.SessionBindingMismatch;
        };

        return session;
    }

    pub fn logout(self: *Security, request: *jetzig.Request) !void {
        if (self.getAuthToken(request)) |token| {
            try self.session.invalidate(token);
            try self.tokens.invalidateToken(token);
            try self.audit.log(.logout, null, .{
                .action_details = "User logout",
                .ip_address = try self.getIdentifier(request),
            });
        }
    }

    fn getIdentifier(self: *Security, request: *jetzig.Request) ![]const u8 {
        _ = self;
        return request.headers.get("X-Forwarded-For") orelse "unkown";
    }

    fn getAuthToken(self: *Security, request: *jetzig.Request) ?[]const u8 {
        _ = self;
        const auth_header = request.headers.get("Authorization") orelse return null;
        if (std.mem.startsWith(u8, auth_header, "Bearer ")) {
            return auth_header[7..];
        }
        return null;
    }

    pub fn cleanup(self: *Security) !void {
        try self.storage.cleanupExpiredSessions();
        // Add other cleanup tasks as needed
    }
};
