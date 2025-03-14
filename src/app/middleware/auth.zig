const std = @import("std");
const jetzig = @import("jetzig");

const security = @import("../security/security.zig");
const SecurityError = security.SecurityError;

const auth = @This();

/// Initialize middleware.
pub fn init(request: *jetzig.http.Request) !*auth {
    const middleware = try request.allocator.create(auth);
    return middleware;
}

pub fn deinit(self: *auth, request: *jetzig.http.Request) void {
    request.allocator.destroy(self);
}

pub fn afterRequest(self: *auth, request: *jetzig.http.Request) !void {
    const auth_success = try authenticateRequest(self, request);
    if (!auth_success) return;
}

pub fn afterResponse(self: *auth, request: *jetzig.http.Request, response: *jetzig.http.Response) !void {
    _ = self;
    _ = request;
    _ = response;
}

// Main authentication function
pub fn authenticateRequest(self: *auth, request: *jetzig.http.Request) !bool {
    _ = self;

    // Check if the route requires authentication using the auth middleware config
    const middleware = request.global.security.middleware;
    const protected_route = middleware.getRequiredAuthStrategy(request.path.path);

    if (protected_route == null) {
        std.log.scoped(.auth).debug("[auth.authenticateRequest] Route is not protected, skipping authentication", .{});
        return true; // Continue processing without authentication
    }

    // Route is protected, perform authentication
    std.log.scoped(.auth).debug("[auth.authenticateRequest] Authenticating protected route: {s}", .{request.path.path});
    const auth_result = try middleware.authenticate(request);
    std.log.scoped(.auth).debug("[auth.authenticateRequest] Auth result: authenticated={}", .{auth_result.authenticated});

    // Handle authentication failure
    if (!auth_result.authenticated or auth_result.errors != null) {
        std.log.scoped(.auth).debug("[auth.authenticateRequest] Authentication failed, handling failure", .{});
        try middleware.handleAuthFailure(request, auth_result);
        std.log.scoped(.auth).debug("[auth.authenticateRequest] Auth failure handled", .{});
        return false; // Signal that response has been handled
    }

    // Authentication succeeded, store user ID in request for later use
    if (auth_result.user_id) |user_id| {
        std.log.scoped(.auth).debug("[auth.authenticateRequest] Authentication succeeded, storing user_id={}", .{user_id});
        var data = try request.data(.object);
        try data.put("user_id", user_id);
    }

    std.log.scoped(.auth).debug("[auth.authenticateRequest] Authentication successful", .{});
    return true; // Continue processing
}
