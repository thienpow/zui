const std = @import("std");
const jetzig = @import("jetzig");

const security = @import("../security/security.zig");
const SecurityError = security.SecurityError;
const req_ultil = @import("../utils/request.zig");

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
    // Only handle authentication logic
    const path_str = req_ultil.getPathString(request);
    const is_auth_path = isAuthPath(path_str);
    if (is_auth_path) return;

    const auth_success = try authenticateRequest(self, request, path_str);
    if (!auth_success) return;

    // Handle redirects for authenticated users trying to access auth pages
    if (is_auth_path) try handleAuthPageRedirects(request);
}

pub fn afterResponse(self: *auth, request: *jetzig.http.Request, response: *jetzig.http.Response) !void {
    _ = self;
    _ = request;
    _ = response;
}

// Helper function to determine if we're on an auth page
fn isAuthPath(path: []const u8) bool {
    return std.mem.startsWith(u8, path, "/auth/login") or
        std.mem.startsWith(u8, path, "/auth/register");
}

// Main authentication function
pub fn authenticateRequest(self: *auth, request: *jetzig.http.Request, path_str: []const u8) !bool {
    _ = self;

    // Check if the route requires authentication using the auth middleware config
    const auth_middleware = request.global.security.auth_middleware;
    const protected_route = auth_middleware.getRequiredAuthStrategy(path_str);

    if (protected_route == null) {
        try request.server.logger.DEBUG("[auth:auth] Route is not protected, skipping authentication", .{});
        return true; // Continue processing without authentication
    }

    // Route is protected, perform authentication
    try request.server.logger.DEBUG("[auth:auth] Authenticating protected route: {s}", .{path_str});
    const auth_result = try auth_middleware.authenticate(request);
    try request.server.logger.DEBUG("[auth:auth] Auth result: authenticated={}", .{auth_result.authenticated});

    // Handle authentication failure
    if (!auth_result.authenticated or auth_result.errors != null) {
        try request.server.logger.DEBUG("[auth:auth] Authentication failed, handling failure", .{});
        try auth_middleware.handleAuthFailure(request, auth_result);
        try request.server.logger.DEBUG("[auth:auth] Auth failure handled", .{});
        return false; // Signal that response has been handled
    }

    // Authentication succeeded, store user ID in request for later use
    if (auth_result.user_id) |user_id| {
        try request.server.logger.DEBUG("[auth:auth] Authentication succeeded, storing user_id={}", .{user_id});
        var data = try request.data(.object);
        try data.put("user_id", user_id);
    }

    try request.server.logger.DEBUG("[auth:auth] Authentication successful", .{});
    return true; // Continue processing
}

// Handle redirects for authenticated users trying to access auth pages
fn handleAuthPageRedirects(request: *jetzig.http.Request) !void {
    var data = try request.data(.object);
    if (data.get("user_id")) |user_id_value| {
        try request.server.logger.DEBUG("[auth:redirect] Found user_id in request data: {}", .{user_id_value});
        try request.server.logger.DEBUG("[auth:redirect] Authenticated user attempting to access auth page", .{});

        const is_htmx = request.headers.get("HX-Request") != null;
        if (is_htmx) {
            // For HTMX requests, use HX-Redirect header
            try request.server.logger.DEBUG("[auth:redirect] Using HX-Redirect for HTMX request", .{});
            try request.response.headers.append("HX-Redirect", "/dashboard");
        } else {
            // For normal requests, do a standard redirect
            try request.server.logger.DEBUG("[auth:redirect] Using standard redirect for browser request", .{});
            request.response.status_code = .found;
            try request.response.headers.append("Location", "/dashboard");
        }
        // Set a flag to indicate response has been handled
        try data.put("response_handled", true);
    }
}
