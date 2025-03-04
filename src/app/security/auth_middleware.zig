const std = @import("std");
const jetzig = @import("jetzig");
const security = @import("security.zig");
const token_manager = @import("token_manager.zig");

const http_utils = @import("../utils/http.zig");
const errors = @import("errors.zig");

const types = @import("types.zig");
const ProtectedRoute = types.ProtectedRoute;
const AuthStrategy = types.AuthStrategy;

const config = @import("config.zig");
const AuthMiddlewareConfig = config.AuthMiddlewareConfig;

pub const AuthResult = struct {
    authenticated: bool,
    user_id: ?u64 = null,
    roles: ?[]const []const u8 = null,
    strategy_used: ?AuthStrategy = null,
    errors: ?errors.SecurityError = null,
};

pub const AuthMiddleware = struct {
    config: AuthMiddlewareConfig,

    /// Determine if a path requires authentication and which strategy to use
    pub fn getRequiredAuthStrategy(self: *const AuthMiddleware, path: []const u8) ?ProtectedRoute {
        for (self.config.protected_routes) |route| {
            if (std.mem.startsWith(u8, path, route.prefix)) {
                return route;
            }
        }
        return null;
    }

    /// Authenticate a request based on the route
    pub fn authenticate(self: *const AuthMiddleware, request: *jetzig.Request) !AuthResult {
        // Get a string representation of the path
        const path_str = blk: {
            // Try to access path as a string or path.raw
            if (@hasField(@TypeOf(request.path), "raw")) {
                break :blk request.path.raw;
            } else if (@hasField(@TypeOf(request.path), "path")) {
                break :blk request.path.path;
            } else {
                // Log path structure for debugging
                std.log.debug("Path type: {s}", .{@typeName(@TypeOf(request.path))});
                break :blk ""; // Default empty string
            }
        };

        // Check if the route requires authentication
        const protected_route = self.getRequiredAuthStrategy(path_str) orelse {
            // Public route, no authentication required
            return AuthResult{
                .authenticated = true,
                .strategy_used = .none,
            };
        };

        // Apply appropriate authentication strategy
        return switch (protected_route.strategy) {
            .session => try self.authenticateWithSession(request, protected_route),
            .jwt => try self.authenticateWithJWT(request, protected_route),
            .api_key => try self.authenticateWithApiKey(request, protected_route),
            .basic => try self.authenticateWithBasicAuth(request, protected_route),
            .none => AuthResult{
                .authenticated = true,
                .strategy_used = .none,
            },
        };
    }

    fn authenticateWithSession(_: *const AuthMiddleware, request: *jetzig.Request, route: ProtectedRoute) !AuthResult {
        const session = request.global.security.validateSession(request) catch |err| {
            // Convert the error to a string for debugging
            const err_name = @errorName(err);
            std.log.err("Session validation error: {s}", .{err_name});

            // Map common errors we expect
            const mapped_error: errors.SecurityError = if (std.mem.eql(u8, err_name, "SessionBindingMismatch"))
                errors.SecurityError.SessionBindingMismatch
            else if (std.mem.eql(u8, err_name, "UnauthorizedAccess"))
                errors.SecurityError.UnauthorizedAccess
            else if (std.mem.eql(u8, err_name, "SessionExpired"))
                errors.SecurityError.SessionExpired
            else if (std.mem.eql(u8, err_name, "ValidationError"))
                errors.SecurityError.ValidationError
            else
                errors.SecurityError.UnauthorizedAccess;

            return AuthResult{
                .authenticated = false,
                .errors = mapped_error,
                .strategy_used = .session,
            };
        };

        // Check required roles if specified
        if (route.required_roles) |required_roles| {
            const has_required_role = try request.global.security.hasRequiredRoles(session.user_id, required_roles);
            if (!has_required_role) {
                return AuthResult{
                    .authenticated = true,
                    .user_id = session.user_id,
                    .errors = errors.SecurityError.UnauthorizedAccess,
                    .strategy_used = .session,
                };
            }
        }

        return AuthResult{
            .authenticated = true,
            .user_id = session.user_id,
            .strategy_used = .session,
        };
    }

    fn authenticateWithJWT(_: *const AuthMiddleware, request: *jetzig.Request, route: ProtectedRoute) !AuthResult {

        // Get token from Authorization header
        const auth_header = request.headers.get("Authorization") orelse {
            return AuthResult{
                .authenticated = false,
                .errors = errors.SecurityError.UnauthorizedAccess,
                .strategy_used = .jwt,
            };
        };

        // Check Bearer token format
        if (!std.mem.startsWith(u8, auth_header, "Bearer ")) {
            return AuthResult{
                .authenticated = false,
                .errors = errors.SecurityError.InvalidToken,
                .strategy_used = .jwt,
            };
        }

        const token = auth_header[7..];

        // Validate token
        const session = request.global.security.tokens.validateAccessToken(token) catch |err| {
            // Map token errors to SecurityError
            const security_error = switch (err) {
                token_manager.TokenError.InvalidToken => errors.SecurityError.InvalidToken,
                token_manager.TokenError.ExpiredToken => errors.SecurityError.SessionExpired,
                token_manager.TokenError.TokenGenerationFailed => errors.SecurityError.InternalError,
                token_manager.TokenError.StorageError => errors.SecurityError.InternalError,
                else => errors.SecurityError.UnauthorizedAccess,
            };

            return AuthResult{
                .authenticated = false,
                .errors = security_error,
                .strategy_used = .jwt,
            };
        };

        // Check required roles if specified
        if (route.required_roles) |required_roles| {
            const has_required_role = try request.global.security.hasRequiredRoles(session.user_id, required_roles);
            if (!has_required_role) {
                return AuthResult{
                    .authenticated = true,
                    .user_id = session.user_id,
                    .errors = errors.SecurityError.UnauthorizedAccess,
                    .strategy_used = .jwt,
                };
            }
        }

        return AuthResult{
            .authenticated = true,
            .user_id = session.user_id,
            .strategy_used = .jwt,
        };
    }

    fn authenticateWithApiKey(_: *const AuthMiddleware, request: *jetzig.Request, route: ProtectedRoute) !AuthResult {

        // Get API key from header
        const api_key = request.headers.get("X-API-Key") orelse {
            return AuthResult{
                .authenticated = false,
                .errors = errors.SecurityError.UnauthorizedAccess,
                .strategy_used = .api_key,
            };
        };

        // Validate API key
        const api_key_info = request.global.security.validateApiKey(api_key) catch |err| {
            // Convert the error to a string for debugging
            const err_name = @errorName(err);
            std.log.err("API key validation error: {s}", .{err_name});

            // Map common errors based on error name
            const mapped_error: errors.SecurityError = if (std.mem.eql(u8, err_name, "InvalidInput"))
                errors.SecurityError.InvalidInput
            else if (std.mem.eql(u8, err_name, "InvalidToken"))
                errors.SecurityError.InvalidToken
            else if (std.mem.eql(u8, err_name, "UnauthorizedAccess"))
                errors.SecurityError.UnauthorizedAccess
            else if (std.mem.eql(u8, err_name, "UserNotFound"))
                errors.SecurityError.UserNotFound
            else
                errors.SecurityError.UnauthorizedAccess;

            return AuthResult{
                .authenticated = false,
                .errors = mapped_error,
                .strategy_used = .api_key,
            };
        };

        // Check required roles if specified
        if (route.required_roles) |required_roles| {
            const has_required_role = try request.global.security.hasRequiredRoles(api_key_info.user_id, required_roles);
            if (!has_required_role) {
                return AuthResult{
                    .authenticated = true,
                    .user_id = api_key_info.user_id,
                    .errors = errors.SecurityError.UnauthorizedAccess,
                    .strategy_used = .api_key,
                };
            }
        }

        return AuthResult{
            .authenticated = true,
            .user_id = api_key_info.user_id,
            .strategy_used = .api_key,
        };
    }

    fn authenticateWithBasicAuth(_: *const AuthMiddleware, request: *jetzig.Request, route: ProtectedRoute) !AuthResult {

        // Get Basic Auth header
        const auth_header = request.headers.get("Authorization") orelse {
            return AuthResult{
                .authenticated = false,
                .errors = errors.SecurityError.UnauthorizedAccess,
                .strategy_used = .basic,
            };
        };

        // Check Basic Auth format
        if (!std.mem.startsWith(u8, auth_header, "Basic ")) {
            return AuthResult{
                .authenticated = false,
                .errors = errors.SecurityError.InvalidCredentials,
                .strategy_used = .basic,
            };
        }

        // Decode credentials (base64)
        const encoded = auth_header[6..];
        const decoded_size = try std.base64.standard.Decoder.calcSizeForSlice(encoded);
        const decoded = try request.allocator.alloc(u8, decoded_size);
        defer request.allocator.free(decoded);

        _ = try std.base64.standard.Decoder.decode(decoded, encoded);

        // Split username:password
        const sep_idx = std.mem.indexOf(u8, decoded, ":") orelse {
            return AuthResult{
                .authenticated = false,
                .errors = errors.SecurityError.InvalidCredentials,
                .strategy_used = .basic,
            };
        };

        const username = decoded[0..sep_idx];
        const password = decoded[sep_idx + 1 ..];

        // Validate credentials
        const auth_result = try request.global.security.authenticate(request, .{
            .email = username,
            .password = password,
        });

        // Check required roles if specified
        if (route.required_roles) |required_roles| {
            const has_required_role = try request.global.security.hasRequiredRoles(auth_result.user.id, required_roles);
            if (!has_required_role) {
                return AuthResult{
                    .authenticated = true,
                    .user_id = auth_result.user.id,
                    .errors = errors.SecurityError.UnauthorizedAccess,
                    .strategy_used = .basic,
                };
            }
        }

        return AuthResult{
            .authenticated = true,
            .user_id = auth_result.user.id,
            .strategy_used = .basic,
        };
    }

    /// Handle authentication failure based on request type (API, HTMX, browser)
    pub fn handleAuthFailure(self: *const AuthMiddleware, request: *jetzig.Request, _: AuthResult) !void {
        const path_str = blk: {
            // Try to access path as a string or path.raw
            if (@hasField(@TypeOf(request.path), "raw")) {
                break :blk request.path.raw;
            } else if (@hasField(@TypeOf(request.path), "path")) {
                break :blk request.path.path;
            } else {
                // Default to empty string if we can't determine the path
                std.log.debug("Path type: {s}", .{@typeName(@TypeOf(request.path))});
                break :blk "";
            }
        };

        const is_api = std.mem.startsWith(u8, path_str, "/api/");
        const is_htmx = request.headers.get("HX-Request") != null;

        if (is_api) {
            // API requests should get a proper 401 response
            request.response.status_code = .unauthorized;
            request.response.content_type = "application/json";
            // Create JSON string
            const json_str = try std.json.stringifyAlloc(request.allocator, .{ .errors = self.config.api_error_message, .code = 401 }, .{});
            defer request.allocator.free(json_str);

            // Set the content
            request.response.content = json_str;
        } else if (is_htmx) {
            // HTMX requests get a redirect header
            try request.response.headers.append("HX-Redirect", self.config.login_redirect_url);
        } else {
            // Browser requests should redirect to login
            if (self.config.use_return_to) {
                // Store the original URL as a query parameter for post-login redirect
                const return_url = try http_utils.urlEncode(request.allocator, path_str);
                defer request.allocator.free(return_url);

                const redirect_url = try std.fmt.allocPrint(request.allocator, "{s}?return_to={s}", .{ self.config.login_redirect_url, return_url });
                _ = request.redirect(redirect_url, .found);
            } else {
                _ = request.redirect(self.config.login_redirect_url, .found);
            }
        }
    }
};
