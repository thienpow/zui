const std = @import("std");
const jetzig = @import("jetzig");

const security = @import("../security/security.zig");
const SecurityError = security.SecurityError;

const router = @This();

/// Initialize middleware.
pub fn init(request: *jetzig.http.Request) !*router {
    const middleware = try request.allocator.create(router);
    return middleware;
}

pub fn afterRequest(self: *router, request: *jetzig.http.Request) !void {
    try request.server.logger.DEBUG("[router] Starting request processing", .{});

    // Skip authentication for auth pages
    const is_auth_page = isAuthPath(request);
    if (is_auth_page) {
        try request.server.logger.DEBUG("[router] On auth page, skipping authentication", .{});
    } else {
        // Handle authentication for non-auth pages
        try request.server.logger.DEBUG("[router] Running authentication middleware", .{});
        const auth_success = try authenticateRequest(self, request);
        if (!auth_success) {
            try request.server.logger.DEBUG("[router] Authentication failed, response has been handled", .{});
            return; // Exit early since the response has been handled
        }
    }

    // Detect if this is an HTMX request
    const is_htmx = request.headers.get("HX-Request") != null;
    try request.server.logger.DEBUG("[router] Request is HTMX: {}", .{is_htmx});

    // Handle authenticated users trying to access auth pages (redirect to dashboard)
    try handleAuthPageRedirects(request, is_htmx);

    // Apply HTMX and theme settings
    try applyRequestSettings(request, is_htmx);

    try request.server.logger.DEBUG("[router] Request processing completed", .{});
}

pub fn afterResponse(
    self: *router,
    request: *jetzig.http.Request,
    response: *jetzig.http.Response,
) !void {
    _ = self;
    _ = response;
    try request.server.logger.DEBUG("[router] Response completed", .{});
}

pub fn deinit(self: *router, request: *jetzig.http.Request) void {
    request.allocator.destroy(self);
}

// Helper function to determine if we're on an auth page
fn isAuthPath(request: *jetzig.http.Request) bool {
    // Log the path for debugging
    _ = request.server.logger.DEBUG("[router:isAuthPath] Checking path: {any}", .{request.path}) catch {};

    // If path is a string
    if (@TypeOf(request.path) == []const u8) {
        return std.mem.startsWith(u8, request.path, "/auth/login") or
            std.mem.startsWith(u8, request.path, "/auth/register");
    }
    // If path is a struct with a path field
    else if (@hasField(@TypeOf(request.path), "path")) {
        return std.mem.startsWith(u8, request.path.path, "/auth/login") or
            std.mem.startsWith(u8, request.path.path, "/auth/register");
    }
    // For other path types
    else {
        return false;
    }
}

// Main authentication function
pub fn authenticateRequest(self: *router, request: *jetzig.http.Request) !bool {
    _ = self;

    // Get a string representation of the path
    const path_str = blk: {
        // Try to access path as a string or path.raw
        if (@hasField(@TypeOf(request.path), "raw")) {
            break :blk request.path.raw;
        } else if (@hasField(@TypeOf(request.path), "path")) {
            break :blk request.path.path;
        } else {
            // Log path structure for debugging
            try request.server.logger.DEBUG("[router:auth] Path type: {s}", .{@typeName(@TypeOf(request.path))});
            break :blk ""; // Default empty string
        }
    };

    // Check if the route requires authentication using the auth middleware config
    const auth_middleware = &request.global.security.auth_middleware;
    const protected_route = auth_middleware.getRequiredAuthStrategy(path_str);

    if (protected_route == null) {
        try request.server.logger.DEBUG("[router:auth] Route is not protected, skipping authentication", .{});
        return true; // Continue processing without authentication
    }

    // Route is protected, perform authentication
    try request.server.logger.DEBUG("[router:auth] Authenticating protected route: {s}", .{path_str});
    const auth_result = try auth_middleware.authenticate(request);
    try request.server.logger.DEBUG("[router:auth] Auth result: authenticated={}", .{auth_result.authenticated});

    // Handle authentication failure
    if (!auth_result.authenticated or auth_result.errors != null) {
        try request.server.logger.DEBUG("[router:auth] Authentication failed, handling failure", .{});
        try auth_middleware.handleAuthFailure(request, auth_result);
        try request.server.logger.DEBUG("[router:auth] Auth failure handled", .{});
        return false; // Signal that response has been handled
    }

    // Authentication succeeded, store user ID in request for later use
    if (auth_result.user_id) |user_id| {
        try request.server.logger.DEBUG("[router:auth] Authentication succeeded, storing user_id={}", .{user_id});
        var data = try request.data(.object);
        try data.put("user_id", user_id);
    }

    try request.server.logger.DEBUG("[router:auth] Authentication successful", .{});
    return true; // Continue processing
}

// Handle redirects for authenticated users trying to access auth pages
fn handleAuthPageRedirects(request: *jetzig.http.Request, is_htmx: bool) !void {
    var data = try request.data(.object);
    if (data.get("user_id")) |user_id_value| {
        try request.server.logger.DEBUG("[router:redirect] Found user_id in request data: {}", .{user_id_value});

        const is_auth_page = isAuthPath(request);
        if (is_auth_page) {
            try request.server.logger.DEBUG("[router:redirect] Authenticated user attempting to access auth page", .{});

            if (is_htmx) {
                // For HTMX requests, use HX-Redirect header
                try request.server.logger.DEBUG("[router:redirect] Using HX-Redirect for HTMX request", .{});
                try request.response.headers.append("HX-Redirect", "/dashboard");
            } else {
                // For normal requests, do a standard redirect
                try request.server.logger.DEBUG("[router:redirect] Using standard redirect for browser request", .{});
                request.response.status_code = .found;
                try request.response.headers.append("Location", "/dashboard");
            }
            // Set a flag to indicate response has been handled
            try data.put("response_handled", true);
        }
    }
}

// Apply HTMX and theme settings
fn applyRequestSettings(request: *jetzig.http.Request, is_htmx: bool) !void {
    var data = try request.data(.object);

    // Check if response has already been handled
    if (data.get("response_handled")) |handled_value| {
        if (@TypeOf(handled_value) == []const u8 and std.mem.eql(u8, handled_value, "true")) {
            return; // Skip further processing
        }
    }

    // Handle HTMX-specific settings
    if (is_htmx) {
        request.setLayout(null);
    } else {
        // Handle theme preferences
        var cookies = try request.cookies();
        var dark = blk: {
            if (cookies.get("dark")) |cookie| {
                break :blk cookie.value;
            } else {
                try cookies.put(.{
                    .name = "dark",
                    .value = "",
                    .path = "/",
                    .http_only = true,
                    .same_site = .strict,
                    .secure = true,
                    .max_age = 60 * 60 * 24 * 90, // 90 days in seconds
                });
                break :blk "";
            }
        };
        dark = if (std.mem.eql(u8, dark, "on")) "checked" else "";
        try data.put("dark", dark);
    }
}
