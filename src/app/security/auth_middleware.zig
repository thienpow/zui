const std = @import("std");
const jetzig = @import("jetzig");
const security = @import("security.zig");
const token_manager = @import("token_manager.zig");
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
        // Check if the route requires authentication
        const protected_route = self.getRequiredAuthStrategy(request.path) orelse {
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
        const sec = &request.app.security;

        const session = sec.validateSession(request) catch |err| {
            return AuthResult{
                .authenticated = false,
                .errors = err,
                .strategy_used = .session,
            };
        };

        // Check required roles if specified
        if (route.required_roles) |required_roles| {
            const has_required_role = try sec.hasRequiredRoles(session.user_id, required_roles);
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
        const sec = &request.app.security;

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
        const session = sec.tokens.validateAccessToken(token) catch |err| {
            return AuthResult{
                .authenticated = false,
                .errors = err,
                .strategy_used = .jwt,
            };
        };

        // Check required roles if specified
        if (route.required_roles) |required_roles| {
            const has_required_role = try sec.hasRequiredRoles(session.user_id, required_roles);
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
        const sec = &request.app.security;

        // Get API key from header
        const api_key = request.headers.get("X-API-Key") orelse {
            return AuthResult{
                .authenticated = false,
                .errors = errors.SecurityError.UnauthorizedAccess,
                .strategy_used = .api_key,
            };
        };

        // Validate API key (you'll need to implement this function)
        const api_key_info = sec.validateApiKey(api_key) catch |err| {
            return AuthResult{
                .authenticated = false,
                .errors = err,
                .strategy_used = .api_key,
            };
        };

        // Check required roles if specified
        if (route.required_roles) |required_roles| {
            const has_required_role = try sec.hasRequiredRoles(api_key_info.user_id, required_roles);
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
        const sec = &request.app.security;

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
        const decoded = try request.arena.alloc(u8, decoded_size);
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
        const auth_result = try sec.authenticate(request, .{
            .email = username,
            .password = password,
        });

        // Check required roles if specified
        if (route.required_roles) |required_roles| {
            const has_required_role = try sec.hasRequiredRoles(auth_result.user.id, required_roles);
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
        const is_api = std.mem.startsWith(u8, request.path, "/api/");
        const is_htmx = request.headers.get("HX-Request") != null;

        if (is_api) {
            // API requests should get a proper 401 response
            request.response.status = .unauthorized;
            try request.response.json(.{ .errors = self.config.api_error_message, .code = 401 });
        } else if (is_htmx) {
            // HTMX requests get a redirect header
            try request.response.headers.append("HX-Redirect", self.config.login_redirect_url);
        } else {
            // Browser requests should redirect to login
            if (self.config.use_return_to) {
                // Store the original URL as a query parameter for post-login redirect
                const return_url = try std.Uri.escapeString(request.allocator, request.path);
                const redirect_url = try std.fmt.allocPrint(request.allocator, "{s}?return_to={s}", .{ self.config.login_redirect_url, return_url });
                try request.redirect(redirect_url);
            } else {
                try request.redirect(self.config.login_redirect_url);
            }
        }
    }
};
