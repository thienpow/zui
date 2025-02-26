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
        // Validate input parameters first
        if (credentials.email.len == 0) {
            return SecurityError.InvalidInput;
        }

        if (credentials.password.len == 0) {
            return SecurityError.InvalidInput;
        }

        // 1. Database Query using jetzig.database.Query and findBy
        const query = jetzig.database.Query(.User)
            .findBy(.{ .email = credentials.email });

        // Add audit context for the lookup attempt
        const identifier = try self.getIdentifier(request);

        // Create JSON for the custom data properly
        const email_json = try std.fmt.allocPrint(
            self.allocator,
            \\{{ "email": "{s}" }}
        ,
            .{credentials.email},
        );
        defer self.allocator.free(email_json);

        // Parse the JSON string into a json.Value
        const custom_data = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            email_json,
            .{},
        );
        defer custom_data.deinit();

        try self.audit.log(.credential_check, null, .{
            .action_details = "Credentials verification attempt",
            .ip_address = identifier,
            .custom_data = custom_data.value,
        });

        // Execute query with proper error handling
        const user = request.repo.execute(query) catch |err| {
            std.log.err("Database error during credential verification: {s}", .{@errorName(err)});
            return SecurityError.DatabaseError;
        } orelse {
            // Don't reveal if user exists or not to prevent enumeration attacks
            std.log.info("User not found: {s}", .{credentials.email});
            return SecurityError.InvalidCredentials;
        };

        // 2. Account status verification
        if (user.is_banned != null and user.is_banned.?) {
            try self.audit.log(.access_denied, @intCast(user.id), .{
                .action_details = "Login attempt on banned account",
                .ip_address = identifier,
                .custom_data = if (user.ban_reason != null) blk: {
                    const reason_json = try std.fmt.allocPrint(
                        self.allocator,
                        \\{{ "ban_reason": "{s}" }}
                    ,
                        .{user.ban_reason.?},
                    );
                    defer self.allocator.free(reason_json);
                    const parsed = try std.json.parseFromSlice(
                        std.json.Value,
                        self.allocator,
                        reason_json,
                        .{},
                    );
                    break :blk parsed.value;
                } else custom_data.value,
            });
            return SecurityError.AccountLocked;
        }

        if (user.is_active != null and !user.is_active.?) {
            try self.audit.log(.access_denied, @intCast(user.id), .{
                .action_details = "Login attempt on inactive account",
                .ip_address = identifier,
            });
            return SecurityError.AccountInactive;
        }

        // 3. Password Hash Verification
        const is_password_valid = jetzig.auth.verifyPassword(self.allocator, credentials.password, user.password_hash) catch |err| {
            std.log.err("Password verification error: {}", .{err});
            return SecurityError.InternalError;
        };

        if (!is_password_valid) {
            try self.audit.log(.login_failed, @intCast(user.id), .{
                .action_details = "Invalid password",
                .ip_address = identifier,
            });
            return SecurityError.InvalidCredentials;
        }

        // 4. User last login info
        const user_agent = request.headers.get("User-Agent") orelse "";

        // 5. Create and Return User struct with updated information
        return .{
            .user = User{
                .id = @intCast(user.id),
                .email = user.email,
                //TODO: query user need to include withRelation so that we can include the user_roles, suggest jetQuery to add this feature.
                //.roles = user.user_roles,
                .is_active = user.is_active,
                .is_banned = user.is_banned,
                .last_ip = identifier,
                .last_user_agent = user_agent,
                .device_id = request.headers.get("X-Device-ID"),
                .last_login_at = std.time.timestamp(),
            },
        };
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

    pub fn getIdentifier(self: *Security, request: *jetzig.Request) ![]const u8 {
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
