const std = @import("std");
const jetzig = @import("jetzig");
const builtin = @import("builtin");

const redis = @import("../database/redis/redis.zig");
const PooledRedisClient = redis.PooledRedisClient;
const RedisClientConfig = redis.RedisClientConfig;

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
const AuthMiddlewareConfig = config.AuthMiddlewareConfig;
const SecurityConfig = config.SecurityConfig;

const errors = @import("errors.zig");
const SecurityError = errors.SecurityError;

const audit_log = @import("audit_log.zig");
const AuditContext = audit_log.AuditContext;
const AuditLog = audit_log.AuditLog;
const AuditLogConfig = config.AuditLogConfig;
const AuthMiddleware = @import("auth_middleware.zig").AuthMiddleware;
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
    audit: AuditLog,
    session: SessionManager,
    tokens: TokenManager,
    rate_limiter: RateLimiter,
    auth_middleware: AuthMiddleware,

    pub fn init(allocator: std.mem.Allocator, security_config: SecurityConfig, redis_pool: *PooledRedisClient) !Security {
        return Security{
            .allocator = allocator,
            .auth_middleware = AuthMiddleware{ .config = security_config.auth_middleware },
            .audit = AuditLog{
                .allocator = allocator,
                .config = security_config.audit,
                .context = AuditContext{
                    .ip_address = null,
                    .user_agent = null,
                },
                .redis_pool = redis_pool,
            },
            .session = SessionManager{
                .allocator = allocator,
                .config = security_config.session,
                .redis_pool = redis_pool,
                .storage = SessionStorage{
                    .allocator = allocator,
                    .storage_config = security_config.storage,
                    .session_config = security_config.session,
                    .redis_pool = redis_pool,
                },
            },
            .tokens = TokenManager{
                .allocator = allocator,
                .config = security_config.tokens,
                .redis_pool = redis_pool,
            },
            .rate_limiter = RateLimiter{
                .config = security_config.rate_limit,
                .redis_pool = redis_pool,
            },
        };
    }

    pub fn deinit(self: *Security) void {
        _ = self;
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
        std.log.debug("[security.authenticate] Starting authentication", .{});

        const identifier = try self.getIdentifier(request);
        std.log.debug("[security.authenticate] Identifier: '{s}'", .{identifier});

        // Validate request metadata
        if (request.headers.get("User-Agent")) |ua| {
            std.log.debug("[security.authenticate] Validating User-Agent: '{s}'", .{ua});
            if (!validation.isValidUserAgent(ua)) {
                std.log.debug("[security.authenticate] Invalid User-Agent, returning ValidationError", .{});
                return SecurityError.ValidationError;
            }
        } else {
            std.log.debug("[security.authenticate] No User-Agent header present", .{});
        }

        // 1. Rate limit check
        std.log.debug("[security.authenticate] Checking rate limit for '{s}'", .{identifier});
        const rate_limit_info = try self.rate_limiter.check(identifier);
        std.log.debug("[security.authenticate] Rate limit info - remaining: {d}, is_locked: {}", .{ rate_limit_info.remaining, rate_limit_info.is_locked });

        // Check if account is locked
        if (rate_limit_info.is_locked) {
            std.log.debug("[security.authenticate] Account locked, returning AccountLocked", .{});
            return SecurityError.AccountLocked;
        }

        // Check if rate limit is exceeded
        if (rate_limit_info.remaining == 0) {
            std.log.debug("[security.authenticate] Rate limit exceeded, returning RateLimitExceeded", .{});
            return SecurityError.RateLimitExceeded;
        }

        // 2. Basic auth validation
        std.log.debug("[security.authenticate] Validating credentials", .{});
        const auth_result = self.validateCredentials(request, credentials, identifier) catch {
            std.log.debug("[security.authenticate] Invalid credentials, incrementing rate limit", .{});
            try self.rate_limiter.increment(identifier);
            try self.audit.log(.login_failed, null, .{
                .action_details = "Invalid credentials",
                .ip_address = identifier,
            });
            std.log.debug("[security.authenticate] Returning InvalidCredentials", .{});
            return SecurityError.InvalidCredentials;
        };
        std.log.debug("[security.authenticate] Credentials validated, user ID: {d}", .{auth_result.user.id});

        // 3. Create session
        std.log.debug("[security.authenticate] Creating session for user ID: {d}", .{auth_result.user.id});
        const session = try self.session.create(auth_result.user, request);
        std.log.debug("[security.authenticate] Session created", .{});

        // 4. Generate tokens
        std.log.debug("[security.authenticate] Generating tokens", .{});
        const tokens = try self.tokens.generate(session);
        std.log.debug("[security.authenticate] Tokens generated", .{});

        // 5. Log successful authentication
        std.log.debug("[security.authenticate] Logging successful login", .{});
        try self.audit.log(.login_success, auth_result.user.id, .{
            .action_details = "Successful login",
            .ip_address = identifier,
        });

        // 6. Reset rate limit counter on success
        std.log.debug("[security.authenticate] Resetting rate limit for '{s}'", .{identifier});
        try self.rate_limiter.reset(identifier);

        std.log.debug("[security.authenticate] Authentication successful", .{});
        return AuthResult{
            .session = session,
            .user = auth_result.user,
            .tokens = tokens,
        };
    }

    fn validateCredentials(self: *Security, request: *jetzig.Request, credentials: Credentials, identifier: []const u8) !struct { user: User } {
        std.log.debug("[security.validateCredentials] Starting credential validation", .{});

        // Validate input parameters first
        if (credentials.email.len == 0) {
            std.log.debug("[security.validateCredentials] Empty email provided, returning InvalidInput", .{});
            return SecurityError.InvalidInput;
        }

        if (credentials.password.len == 0) {
            std.log.debug("[security.validateCredentials] Empty password provided, returning InvalidInput", .{});
            return SecurityError.InvalidInput;
        }

        std.log.debug("[security.validateCredentials] Input validation passed", .{});

        // 1. Database Query using jetzig.database.Query and findBy
        std.log.debug("[security.validateCredentials] Building database query for email: '{s}'", .{credentials.email});
        const query = jetzig.database.Query(.User)
            .include(.user_roles, .{
            .include = .{.role},
        })
            .findBy(.{ .email = credentials.email });

        // Create JSON for the custom data properly
        std.log.debug("[security.validateCredentials] Creating audit log JSON data", .{});
        const email_json = try std.fmt.allocPrint(
            self.allocator,
            \\{{ "email": "{s}" }}
        ,
            .{credentials.email},
        );
        defer self.allocator.free(email_json);

        // Parse the JSON string into a json.Value
        std.log.debug("[security.validateCredentials] Parsing JSON for audit log", .{});
        const custom_data = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            email_json,
            .{},
        );
        defer custom_data.deinit();

        std.log.debug("[security.validateCredentials] Logging credential check audit event", .{});
        try self.audit.log(.credential_check, null, .{
            .action_details = "Credentials verification attempt",
            .ip_address = identifier,
            .custom_data = custom_data.value,
        });

        // Execute query with proper error handling
        std.log.debug("[security.validateCredentials] Executing database query", .{});
        const user = request.repo.execute(query) catch |err| {
            std.log.err("[security.validateCredentials] Database error during credential verification: {}", .{err});
            return SecurityError.DatabaseError;
        } orelse {
            // Don't reveal if user exists or not to prevent enumeration attacks
            std.log.info("[security.validateCredentials] User not found: {s}", .{credentials.email});
            return SecurityError.InvalidCredentials;
        };

        std.log.info("[security.validateCredentials] User found: id={d}, username={s}, email={s}", .{
            user.id,
            user.username,
            user.email,
        });

        // 2. Account status verification
        std.log.debug("[security.validateCredentials] Checking account status", .{});
        if (user.is_banned != null and user.is_banned.?) {
            std.log.debug("[security.validateCredentials] Account is banned, returning AccountLocked", .{});
            try self.audit.log(.access_denied, @intCast(user.id), .{
                .action_details = "Login attempt on banned account",
                .ip_address = identifier,
                .custom_data = if (user.ban_reason != null) blk: {
                    std.log.debug("[security.validateCredentials] Including ban reason in audit log", .{});
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
            std.log.debug("[security.validateCredentials] Account is inactive, returning AccountInactive", .{});
            try self.audit.log(.access_denied, @intCast(user.id), .{
                .action_details = "Login attempt on inactive account",
                .ip_address = identifier,
            });
            return SecurityError.AccountInactive;
        }

        // 3. Password Hash Verification
        std.log.debug("[security.validateCredentials] Verifying password hash", .{});
        const is_password_valid = jetzig.auth.verifyPassword(self.allocator, user.password_hash, credentials.password) catch |err| {
            std.log.err("[security.validateCredentials] Password verification error: {}", .{err});
            return SecurityError.InternalError;
        };

        if (!is_password_valid) {
            std.log.debug("[security.validateCredentials] Password verification failed, returning InvalidCredentials", .{});
            try self.audit.log(.login_failed, @intCast(user.id), .{
                .action_details = "Invalid password",
                .ip_address = identifier,
            });
            return SecurityError.InvalidCredentials;
        }
        std.log.debug("[security.validateCredentials] Password verification successful", .{});

        // 4. User last login info
        std.log.debug("[security.validateCredentials] Getting user agent information", .{});
        const user_agent = request.headers.get("User-Agent") orelse "";
        std.log.debug("[security.validateCredentials] User agent: '{s}'", .{user_agent});

        // 5. Create and Return User struct with updated information
        std.log.debug("[security.validateCredentials] Creating user record with updated login information", .{});

        const device_id = request.headers.get("X-Device-ID");
        if (device_id) |id| {
            std.log.debug("[security.validateCredentials] Device ID provided: '{s}'", .{id});
        } else {
            std.log.debug("[security.validateCredentials] No device ID provided", .{});
        }

        std.log.debug("[security.validateCredentials] Validation successful for user ID: {d}", .{user.id});
        return .{
            .user = User{
                .id = @intCast(user.id),
                .email = user.email,
                //.roles = user.user_roles,
                .is_active = user.is_active,
                .is_banned = user.is_banned,
                .last_ip = identifier,
                .last_user_agent = user_agent,
                .device_id = device_id,
                .last_login_at = std.time.timestamp(),
            },
        };
    }

    pub fn validateSession(self: *Security, request: *jetzig.Request) !Session {
        // Get the session token from the cookie
        const token = self.session.getSessionTokenFromCookie(request) orelse
            return SecurityError.UnauthorizedAccess;

        //const token = self.getAuthToken(request) orelse return SecurityError.UnauthorizedAccess;

        const session = try self.session.validate(token) catch |err| {
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

    pub fn logout(self: *Security, request: *jetzig.Request, response: *jetzig.Response) !void {
        // if (self.getAuthToken(request)) |token| {
        //     try self.session.invalidate(token);
        //     try self.tokens.invalidateToken(token);
        //     try self.audit.log(.logout, null, .{
        //         .action_details = "User logout",
        //         .ip_address = try self.getIdentifier(request),
        //     });
        // }

        if (self.session.getSessionTokenFromCookie(request)) |token| {
            try self.session.invalidate(token);
            try self.tokens.invalidateToken(token);
            try self.audit.log(.logout, null, .{
                .action_details = "User logout",
                .ip_address = try self.getIdentifier(request),
            });
        }
        // Clear Cookie
        try self.session.clearSessionCookie(response);
    }

    pub fn getIdentifier(self: *Security, request: *jetzig.Request) ![]const u8 {
        _ = self;
        const ip = request.headers.get("X-Forwarded-For") orelse {
            if (builtin.mode == .Debug) {
                return "localhost"; // Local dev fallback
            } else {
                return "unknown";
            }
        };
        return ip;
    }

    fn getAuthToken(self: *Security, request: *jetzig.Request) ?[]const u8 {
        _ = self;
        const auth_header = request.headers.get("Authorization") orelse return null;
        if (std.mem.startsWith(u8, auth_header, "Bearer ")) {
            return auth_header[7..];
        }
        return null;
    }

    pub fn hasRequiredRoles(self: *Security, user_id: u64, required_roles: []const []const u8) !bool {
        // This is a stub - you would implement actual role checking
        // against your user database or roles system
        _ = self;
        _ = user_id;
        _ = required_roles;

        // For now returning true, but you should implement actual role checking
        return true;
    }

    // Add API key validation (stub - implement according to your API key system)
    pub fn validateApiKey(self: *Security, api_key: []const u8) !struct { user_id: u64 } {
        _ = self;
        _ = api_key;
        // This is a stub - implement according to your API key system
        return error.NotImplemented;
    }
};
