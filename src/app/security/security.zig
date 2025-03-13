const std = @import("std");
const jetzig = @import("jetzig");

const ip_utils = @import("../utils/ip.zig");
const token_utils = @import("../utils/token.zig");
const email_utils = @import("../utils/email.zig");
const password_utils = @import("../utils/password.zig");

const redis = @import("../database/redis/redis.zig");
const PooledRedisClient = redis.PooledRedisClient;
const RedisClientConfig = redis.RedisClientConfig;

// Internal module imports

const types = @import("types.zig");
const AuthResult = types.AuthResult;
const Severity = types.Severity;
const SecurityEvent = types.SecurityEvent;
const Session = types.Session;
const User = types.User;
const AuthenticationCredentials = types.AuthenticationCredentials;
const Credentials = types.Credentials;
const ErrorDetails = types.ErrorDetails;

const config = @import("config.zig");
const AuthMiddlewareConfig = config.AuthMiddlewareConfig;
const OAuthConfig = config.OAuthConfig;
const SecurityConfig = config.SecurityConfig;

const errors = @import("errors.zig");
const SecurityError = errors.SecurityError;

const audit = @import("audit.zig");
const AuditContext = audit.AuditContext;
const AuditLog = audit.AuditLog;
const AuditLogConfig = config.AuditLogConfig;
const AuthMiddleware = @import("middleware.zig").AuthMiddleware;
const SessionManager = @import("session.zig").SessionManager;
const SessionStorage = @import("storage.zig").SessionStorage;
const TokenManager = @import("token.zig").TokenManager;
const RateLimiter = @import("rate_limiter.zig").RateLimiter;
const validation = @import("validation.zig");

const oauth = @import("oauth.zig");
const OAuthManager = oauth.OAuthManager;

// Re-export common types and configurations
pub usingnamespace types;
pub usingnamespace config;
pub usingnamespace errors;

pub const Security = struct {
    allocator: std.mem.Allocator,
    audit: AuditLog,
    session: SessionManager,
    token: TokenManager,
    rate_limiter: RateLimiter,
    middleware: AuthMiddleware,
    oauth: OAuthManager,
    redis_pool: *PooledRedisClient,

    pub fn init(allocator: std.mem.Allocator, security_config: SecurityConfig, redis_pool: *PooledRedisClient) !Security {
        return Security{
            .allocator = allocator,
            .middleware = AuthMiddleware{ .config = security_config.middleware },
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
            .token = TokenManager{
                .allocator = allocator,
                .config = security_config.token,
                .redis_pool = redis_pool,
            },
            .rate_limiter = RateLimiter{
                .config = security_config.rate_limit,
                .redis_pool = redis_pool,
            },
            .oauth = OAuthManager{
                .allocator = allocator,
                .config = security_config.oauth,
            },
            .redis_pool = redis_pool,
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
    //     const metadata = audit.AuditMetadata{
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

    pub fn authenticate(self: *Security, request: *jetzig.Request, credentials: Credentials) !AuthenticationCredentials {
        std.log.scoped(.auth).debug("[Security.authenticate] Starting authentication", .{});

        const client_ip = ip_utils.getClientIp(request);
        std.log.scoped(.auth).debug("[Security.authenticate] client_ip: '{s}'", .{client_ip});

        // Validate request metadata
        if (request.headers.get("User-Agent")) |ua| {
            std.log.scoped(.auth).debug("[Security.authenticate] Validating User-Agent: '{s}'", .{ua});
            if (!validation.isValidUserAgent(ua)) {
                std.log.scoped(.auth).debug("[Security.authenticate] Invalid User-Agent, returning ValidationError", .{});
                return SecurityError.ValidationError;
            }
        } else {
            std.log.scoped(.auth).debug("[Security.authenticate] No User-Agent header present", .{});
        }

        // 1. Rate limit check
        std.log.scoped(.auth).debug("[Security.authenticate] Checking rate limit for '{s}'", .{client_ip});
        const rate_limit_info = try self.rate_limiter.check(client_ip);
        std.log.scoped(.auth).debug("[Security.authenticate] Rate limit info - remaining: {d}, is_locked: {}", .{ rate_limit_info.remaining, rate_limit_info.is_locked });

        // Check if account is locked
        if (rate_limit_info.is_locked) {
            std.log.scoped(.auth).debug("[Security.authenticate] Account locked, returning AccountLocked", .{});
            return SecurityError.AccountLocked;
        }

        // Check if rate limit is exceeded
        if (rate_limit_info.remaining == 0) {
            std.log.scoped(.auth).debug("[Security.authenticate] Rate limit exceeded, returning RateLimitExceeded", .{});
            return SecurityError.RateLimitExceeded;
        }

        // 2. Basic auth validation
        std.log.scoped(.auth).debug("[Security.authenticate] Validating credentials", .{});
        const auth_result = self.validateCredentials(request, credentials, client_ip) catch {
            std.log.scoped(.auth).debug("[Security.authenticate] Invalid credentials, incrementing rate limit", .{});
            try self.rate_limiter.increment(client_ip);
            try self.audit.log(.login_failed, null, .{
                .action_details = "Invalid credentials",
                .ip_address = client_ip,
            });
            std.log.scoped(.auth).debug("[Security.authenticate] Returning InvalidCredentials", .{});
            return SecurityError.InvalidCredentials;
        };
        std.log.scoped(.auth).debug("[Security.authenticate] Credentials validated, user ID: {d}", .{auth_result.user.id});

        // 3. Create session
        std.log.scoped(.auth).debug("[Security.authenticate] Creating session for user ID: {d}", .{auth_result.user.id});
        const session = try self.session.create(auth_result.user, request);
        std.log.scoped(.auth).debug("[Security.authenticate] Session created", .{});

        // 4. Generate token
        std.log.scoped(.auth).debug("[Security.authenticate] Generating token", .{});
        const token = try self.token.generate(session);
        std.log.scoped(.auth).debug("[Security.authenticate] token generated", .{});

        // 5. Log successful authentication
        std.log.scoped(.auth).debug("[Security.authenticate] Logging successful login", .{});
        try self.audit.log(.login_success, auth_result.user.id, .{
            .action_details = "Successful login",
            .ip_address = client_ip,
        });

        // 6. Reset rate limit counter on success
        std.log.scoped(.auth).debug("[Security.authenticate] Resetting rate limit for '{s}'", .{client_ip});
        try self.rate_limiter.reset(client_ip);

        std.log.scoped(.auth).debug("[Security.authenticate] Authentication successful", .{});
        return AuthenticationCredentials{
            .session = session,
            .user = auth_result.user,
            .token = token,
        };
    }

    fn validateCredentials(self: *Security, request: *jetzig.Request, credentials: Credentials, client_ip: []const u8) !struct { user: User } {
        std.log.scoped(.auth).debug("[Security.validateCredentials] Starting credential validation", .{});

        // Validate input parameters first
        if (credentials.email.len == 0) {
            std.log.scoped(.auth).debug("[Security.validateCredentials] Empty email provided, returning InvalidInput", .{});
            return SecurityError.InvalidInput;
        }

        if (credentials.password.len == 0) {
            std.log.scoped(.auth).debug("[Security.validateCredentials] Empty password provided, returning InvalidInput", .{});
            return SecurityError.InvalidInput;
        }

        std.log.scoped(.auth).debug("[Security.validateCredentials] Input validation passed", .{});

        // 1. Database Query using jetzig.database.Query and findBy
        std.log.scoped(.auth).debug("[Security.validateCredentials] Building database query for email: '{s}'", .{credentials.email});
        const query = jetzig.database.Query(.User)
            .include(.user_roles, .{
                .include = .{.role},
            })
            .findBy(.{ .email = credentials.email });

        // Create JSON for the custom data properly
        std.log.scoped(.auth).debug("[Security.validateCredentials] Creating audit log JSON data", .{});
        const email_json = try std.fmt.allocPrint(
            self.allocator,
            \\{{ "email": "{s}" }}
        ,
            .{credentials.email},
        );
        defer self.allocator.free(email_json);

        // Parse the JSON string into a json.Value
        std.log.scoped(.auth).debug("[Security.validateCredentials] Parsing JSON for audit log", .{});
        const custom_data = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            email_json,
            .{},
        );
        defer custom_data.deinit();

        std.log.scoped(.auth).debug("[Security.validateCredentials] Logging credential check audit event", .{});
        try self.audit.log(.credential_check, null, .{
            .action_details = "Credentials verification attempt",
            .ip_address = client_ip,
            .custom_data = custom_data.value,
        });

        // Execute query with proper error handling
        std.log.scoped(.auth).debug("[Security.validateCredentials] Executing database query", .{});
        const user = request.repo.execute(query) catch |err| {
            std.log.scoped(.auth).debug("[Security.validateCredentials] Database error during credential verification: {}", .{err});
            return SecurityError.DatabaseError;
        } orelse {
            // Don't reveal if user exists or not to prevent enumeration attacks
            std.log.scoped(.auth).debug("[Security.validateCredentials] User not found: {s}", .{credentials.email});
            return SecurityError.InvalidCredentials;
        };

        std.log.scoped(.auth).debug("[Security.validateCredentials] User found: id={d}, username={s}, email={s}", .{
            user.id,
            user.username,
            user.email,
        });

        // 2. Account status verification
        std.log.scoped(.auth).debug("[Security.validateCredentials] Checking account status", .{});
        if (user.is_banned != null and user.is_banned.?) {
            std.log.scoped(.auth).debug("[Security.validateCredentials] Account is banned, returning AccountLocked", .{});
            try self.audit.log(.access_denied, @intCast(user.id), .{
                .action_details = "Login attempt on banned account",
                .ip_address = client_ip,
                .custom_data = if (user.ban_reason != null) blk: {
                    std.log.scoped(.auth).debug("[Security.validateCredentials] Including ban reason in audit log", .{});
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
            std.log.scoped(.auth).debug("[Security.validateCredentials] Account is inactive, returning AccountInactive", .{});
            try self.audit.log(.access_denied, @intCast(user.id), .{
                .action_details = "Login attempt on inactive account",
                .ip_address = client_ip,
            });
            return SecurityError.AccountInactive;
        }

        // 3. Password Hash Verification
        std.log.scoped(.auth).debug("[Security.validateCredentials] Verifying password hash", .{});
        const is_password_valid = jetzig.auth.verifyPassword(self.allocator, user.password_hash, credentials.password) catch |err| {
            std.log.scoped(.auth).debug("[Security.validateCredentials] Password verification error: {}", .{err});
            return SecurityError.InternalError;
        };

        if (!is_password_valid) {
            std.log.scoped(.auth).debug("[Security.validateCredentials] Password verification failed, returning InvalidCredentials", .{});
            try self.audit.log(.login_failed, @intCast(user.id), .{
                .action_details = "Invalid password",
                .ip_address = client_ip,
            });
            return SecurityError.InvalidCredentials;
        }
        std.log.scoped(.auth).debug("[Security.validateCredentials] Password verification successful", .{});

        // 4. User last login info
        std.log.scoped(.auth).debug("[Security.validateCredentials] Getting user agent information", .{});
        const user_agent = request.headers.get("User-Agent") orelse "";
        std.log.scoped(.auth).debug("[Security.validateCredentials] User agent: '{s}'", .{user_agent});

        // 5. Create and Return User struct with updated information
        std.log.scoped(.auth).debug("[Security.validateCredentials] Creating user record with updated login information", .{});

        const device_id = request.headers.get("X-Device-ID");
        if (device_id) |id| {
            std.log.scoped(.auth).debug("[Security.validateCredentials] Device ID provided: '{s}'", .{id});
        } else {
            std.log.scoped(.auth).debug("[Security.validateCredentials] No device ID provided", .{});
        }

        std.log.scoped(.auth).debug("[Security.validateCredentials] Validation successful for user ID: {d}", .{user.id});
        return .{
            .user = User{
                .id = @intCast(user.id),
                .email = user.email,
                //.roles = user.user_roles,
                .is_active = user.is_active,
                .is_banned = user.is_banned,
                .last_ip = client_ip,
                .last_user_agent = user_agent,
                .device_id = device_id,
                .last_login_at = std.time.timestamp(),
            },
        };
    }

    pub fn validateSession(self: *Security, request: *jetzig.Request) !Session {
        // Get the session token from the cookie
        std.log.scoped(.auth).debug("[Security.validateSession] calling getSessionTokenFromCookie: ", .{});
        const token = (try self.session.getSessionTokenFromCookie(request)) orelse
            return SecurityError.UnauthorizedAccess;

        //const token = self.getAuthToken(request) orelse return SecurityError.UnauthorizedAccess;

        std.log.scoped(.auth).debug("[Security.validateSession] calling session.validate: ", .{});
        const session = try self.session.validate(token, request);

        // Validate IP and User-Agent binding
        if (!try validation.validateSessionBinding(session, request)) {
            return SecurityError.SessionBindingMismatch;
        }

        // Validation successful, return the session
        return session;
    }

    pub fn logout(self: *Security, request: *jetzig.Request) !void {
        std.log.scoped(.auth).debug("[Security.logout] Starting logout process", .{});

        if (try self.session.getSessionTokenFromCookie(request)) |token| {
            std.log.scoped(.auth).debug("[Security.logout] Found session token: {s}", .{token});

            std.log.scoped(.auth).debug("[Security.logout] Cleaning up session", .{});
            try self.session.cleanup(request);

            std.log.scoped(.auth).debug("[Security.logout] Invalidating token", .{});
            try self.token.invalidateToken(token);

            const ip = ip_utils.getClientIp(request);
            std.log.scoped(.auth).debug("[Security.logout] Logging audit event from IP: {s}", .{ip});

            try self.audit.log(.logout, null, .{
                .action_details = "User logout",
                .ip_address = ip,
            });

            std.log.scoped(.auth).debug("[Security.logout] Logout process completed successfully", .{});
        } else {
            std.log.scoped(.auth).debug("[Security.logout] No session token found in cookie", .{});
        }
    }

    pub fn requestPasswordReset(self: *Security, request: *jetzig.Request, options: struct { email: []const u8 }) !void {
        // Check rate limits first to prevent abuse
        // Create a unique identifier for password reset rate limiting
        // This prefixes the identifier to distinguish it from login attempts
        const reset_identifier = try std.fmt.allocPrint(self.allocator, "pwd_reset:{s}", .{ip_utils.getClientIp(request)});
        defer self.allocator.free(reset_identifier);

        // Use the existing rate limiter
        const rate_limit_info = try self.rate_limiter.check(reset_identifier);

        // Check if account is locked
        if (rate_limit_info.is_locked) {
            std.log.scoped(.auth).debug("[Security.requestPasswordReset] Account locked, returning AccountLocked", .{});
            return SecurityError.AccountLocked;
        }

        // Check if rate limit is exceeded
        if (rate_limit_info.remaining == 0) {
            std.log.scoped(.auth).debug("[Security.requestPasswordReset] Rate limit exceeded, returning RateLimitExceeded", .{});
            try self.audit.log(
                .password_reset_request_blocked,
                null,
                .{
                    .action_details = "Rate limit exceeded for password reset",
                    .ip_address = ip_utils.getClientIp(request),
                    .user_agent = request.headers.get("User-Agent"),
                },
            );
            return SecurityError.RateLimitExceeded;
        }

        // Validate email format
        if (!email_utils.isValidEmail(options.email)) {
            try self.audit.log(
                .password_reset_request,
                null,
                .{
                    .action_details = "Invalid email format",
                    .ip_address = ip_utils.getClientIp(request),
                    .user_agent = request.headers.get("User-Agent"),
                },
            );
            return SecurityError.ValidationError;
        }

        // Find the user by email
        const query = jetzig.database.Query(.User).findBy(.{ .email = options.email });
        const user = request.repo.execute(query) catch |err| {
            std.log.scoped(.auth).debug("[Security.requestPasswordReset] Database error during forgot password: {}", .{err});
            try self.audit.log(
                .password_reset_request,
                null,
                .{
                    .action_details = "Database error",
                    .ip_address = ip_utils.getClientIp(request),
                },
            );
            return SecurityError.DatabaseError;
        } orelse {
            // IMPORTANT: Don't reveal whether the email exists in response.
            // But we still log it internally for auditing
            std.log.scoped(.auth).debug("[Security.requestPasswordReset] User with email {s} not found", .{options.email});
            try self.audit.log(
                .password_reset_request,
                null,
                .{
                    .action_details = "Email not found, but faking success",
                    .ip_address = ip_utils.getClientIp(request),
                },
            );
            // Return without error to prevent user enumeration
            return;
        };

        // Generate a secure token
        const token = try token_utils.generateSecureToken(self.allocator);
        defer self.allocator.free(token);

        // Store the token in Redis with user ID association
        var redis_client = try self.redis_pool.acquire();
        defer self.redis_pool.release(redis_client);

        const user_id_str = try std.fmt.allocPrint(self.allocator, "{d}", .{user.id});
        defer self.allocator.free(user_id_str);

        const token_key = try std.fmt.allocPrint(self.allocator, "pwd_reset:{s}", .{token});
        defer self.allocator.free(token_key);

        try redis_client.setEx(token_key, user_id_str, 3600); // Expire in 1 hour (3600 seconds)
        std.log.scoped(.auth).debug("[Security.requestPasswordReset] Setting token in Redis: key={s}, value={s}\n", .{ token_key, user_id_str });

        const ttl = try redis_client.ttl(token_key);
        std.log.scoped(.auth).debug("[Security.requestPasswordReset] Token TTL set to {any} seconds\n", .{ttl});

        // Log the successful token creation
        try self.audit.log(
            .password_reset_request,
            @intCast(user.id),
            .{
                .action_details = "Password reset token generated and stored",
                .ip_address = ip_utils.getClientIp(request),
            },
        );

        // Generate reset URL
        const reset_url = try std.fmt.allocPrint(self.allocator, "{s}/auth/reset_password?token={s}", .{ request.global.config_manager.server_config.base_url, token });
        defer self.allocator.free(reset_url);

        // Send the reset email
        // try self.communications.sendPasswordResetEmail(options.email, reset_url);

        std.log.scoped(.auth).debug("[Security.requestPasswordReset] Password reset email sent to {s}, reset_url: {s}", .{ options.email, reset_url });
    }

    pub fn resetPassword(self: *Security, request: *jetzig.Request, options: struct {
        token: []const u8,
        password: []const u8,
        password_confirm: []const u8,
    }) !void {
        // Check rate limits first to prevent brute-force attacks
        const client_ip = ip_utils.getClientIp(request);
        const reset_identifier = try std.fmt.allocPrint(self.allocator, "pwd_reset_attempt:{s}", .{client_ip});
        defer self.allocator.free(reset_identifier);

        const rate_limit_info = try self.rate_limiter.check(reset_identifier);

        // Check if account is locked
        if (rate_limit_info.is_locked) {
            std.log.scoped(.auth).debug("[Security.resetPassword] Account locked, returning AccountLocked", .{});
            return SecurityError.AccountLocked;
        }

        // Check if rate limit is exceeded
        if (rate_limit_info.remaining == 0) {
            std.log.scoped(.auth).debug("[Security.resetPassword] Rate limit exceeded, returning RateLimitExceeded", .{});
            try self.audit.log(
                .password_reset_blocked,
                null,
                .{
                    .action_details = "Rate limit exceeded for password reset attempts",
                    .ip_address = client_ip,
                    .user_agent = request.headers.get("User-Agent"),
                },
            );
            return SecurityError.RateLimitExceeded;
        }

        // Validate that passwords match
        if (!std.mem.eql(u8, options.password, options.password_confirm)) {
            try self.audit.log(
                .password_reset,
                null,
                .{
                    .action_details = "Password mismatch",
                    .ip_address = client_ip,
                    .user_agent = request.headers.get("User-Agent"),
                },
            );
            return SecurityError.PasswordMismatch;
        }

        // Validate password strength
        if (!password_utils.isStrongPassword(options.password)) {
            try self.audit.log(
                .password_reset,
                null,
                .{
                    .action_details = "Password too weak",
                    .ip_address = client_ip,
                    .user_agent = request.headers.get("User-Agent"),
                },
            );
            return SecurityError.WeakPassword;
        }

        // Get Redis client from pool
        var redis_client = try self.redis_pool.acquire();
        defer self.redis_pool.release(redis_client);

        // Format token key
        const token_key = try std.fmt.allocPrint(self.allocator, "pwd_reset:{s}", .{options.token});
        defer self.allocator.free(token_key);

        // Validate the token
        const user_id_str = blk: {
            const maybe_token = try redis_client.get(token_key);
            std.log.scoped(.auth).debug("[Security.resetPassword] redis_client.get({s}) returned {?s}\n", .{ token_key, maybe_token });

            const result = maybe_token orelse {
                std.log.scoped(.auth).debug("[Security.resetPassword] Token is null or expired for key: {s}\n", .{token_key});
                try self.audit.log(
                    .password_reset,
                    null,
                    .{
                        .action_details = "Invalid or expired token",
                        .ip_address = client_ip,
                        .user_agent = request.headers.get("User-Agent"),
                    },
                );
                std.log.scoped(.auth).debug("[Security.resetPassword] Audit log recorded for invalid token from IP: {s}\n", .{client_ip});
                return SecurityError.InvalidToken;
            };

            std.log.scoped(.auth).debug("[Security.resetPassword] Successfully retrieved user_id_str: {s}\n", .{result});
            break :blk result;
        };
        defer self.allocator.free(user_id_str);

        // Parse user id
        const user_id = std.fmt.parseInt(u64, user_id_str, 10) catch {
            try self.audit.log(
                .password_reset,
                null,
                .{
                    .action_details = "Invalid user_id format in token",
                    .ip_address = client_ip,
                    .user_agent = request.headers.get("User-Agent"),
                },
            );
            return SecurityError.InvalidToken;
        };

        // Hash the new password
        const password_hash = try password_utils.hashPassword(self.allocator, options.password);
        defer self.allocator.free(password_hash);

        // Update the user's password in the database
        const query = jetzig.database.Query(.User).update(.{
            .password_hash = password_hash,
        }).where(.{ .id = user_id });

        _ = request.repo.execute(query) catch |err| {
            std.log.scoped(.auth).debug("[Security.resetPassword] Failed to update password: {}", .{err});
            try self.audit.log(
                .password_reset,
                user_id,
                .{
                    .action_details = "Database error while updating password",
                    .ip_address = client_ip,
                    .user_agent = request.headers.get("User-Agent"),
                },
            );
            return SecurityError.DatabaseError;
        };

        // Invalidate the token (delete from Redis)
        _ = try redis_client.del(token_key);

        // Log successful password reset
        try self.audit.log(
            .password_reset,
            user_id,
            .{
                .action_details = "Password successfully reset",
                .ip_address = client_ip,
                .user_agent = request.headers.get("User-Agent"),
            },
        );

        // If we made it here, the password reset was successful
        std.log.scoped(.auth).debug("[Security.resetPassword] Password successfully reset for user {d}", .{user_id});
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
