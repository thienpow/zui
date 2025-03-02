const std = @import("std");
const jetzig = @import("jetzig");

const security = @import("../security/security.zig"); // Import Security module
const SecurityError = @import("../security/security.zig").SecurityError; // Import SecurityError

const router = @This();

/// Initialize middleware.
pub fn init(request: *jetzig.http.Request) !*router {
    const middleware = try request.allocator.create(router);
    return middleware;
}

pub fn afterRequest(_: *router, request: *jetzig.http.Request) !void {
    const is_htmx = request.headers.get("HX-Request") != null;
    if (is_htmx) {
        request.setLayout(null);
    } else {
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
        var root = try request.data(.object);
        try root.put("dark", dark);
    }
}

pub fn beforeRequest(self: *router, request: *jetzig.http.Request) !void {

    // Run authentication middleware first for protected routes
    try authenticateMiddleware(self, request); // Call the authentication middleware

    // ... (rest of your existing beforeRequest logic, e.g., layout setting, etc.)
}

pub fn afterResponse(
    self: *router,
    request: *jetzig.http.Request,
    response: *jetzig.http.Response,
) !void {
    _ = self;
    _ = response;
    try request.server.logger.DEBUG("[router:afterResponse] Response completed", .{});
}

pub fn deinit(self: *router, request: *jetzig.http.Request) void {
    request.allocator.destroy(self);
}

pub fn authenticateMiddleware(self: *router, request: *jetzig.http.Request) !void {
    _ = self;

    // Skip authentication check if middleware not configured
    if (request.global.security.auth_middleware == null) {
        return;
    }

    // Authenticate the request
    const auth_result = try request.global.security.auth_middleware.authenticate(request);

    // Handle authentication failure
    if (!auth_result.authenticated or auth_result.errors != null) {
        try request.global.security.auth_middleware.handleAuthFailure(request, auth_result);
        return error.Handled; // Signal that response has been handled
    }

    // Authentication succeeded, store user ID in request for later use
    if (auth_result.user_id) |user_id| {
        try request.data().put("user_id", user_id);
    }
}
