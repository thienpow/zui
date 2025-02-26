const std = @import("std");
const jetzig = @import("jetzig");

const security = @import("../security/security.zig"); // Import Security module
const SecurityError = @import("../security/security.zig").SecurityError; // Import SecurityError

// Example: List of URL path prefixes that are protected
const protected_prefixes = &.{
    "/admin/",
    "/api/private/",
    // ... add more prefixes as needed
};

const layout_mappings = [_][2][]const u8{
    .{ "/", "landing" },
    .{ "/about", "landing" },

    .{ "/admin/dashboard", "admin" },
    .{ "/admin/profile", "admin" },
    .{ "/admin/products", "admin" },
    .{ "/admin/orders", "admin" },
    .{ "/admin/users", "admin" },
    .{ "/admin/settings", "admin" },

    .{ "/auth/login", "auth" },
};

fn findMapping(key: []const u8) ?[]const u8 {
    for (layout_mappings) |entry| {
        if (std.mem.eql(u8, entry[0], key)) {
            return entry[1];
        }
    }
    return null;
}

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

        // if (findMapping(request.path.base_path)) |layout| {
        //     try request.server.logger.DEBUG("[router:afterRequest] HTMX request: {s} -> {s}", .{ request.path.base_path, layout });
        //     request.setLayout(layout);
        // }

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

    // Check if the request path starts with any protected prefix
    for (protected_prefixes) |prefix| {
        if (std.mem.startsWith(u8, request.path.base_path, prefix)) {
            // This route is protected, validate session
            _ = request.global.security.validateSession(request) catch |err| {
                std.log.warn("Session validation failed for path {s}: {}", .{ request.path.base_path, err });
                return error.UnauthorizedAccess; // Indicate unauthorized access
                // Alternatively, you could redirect to login page if it's a browser request:
                // return request.redirect("/auth/login");
            };
            // Session is valid, request proceeds
            return;
        }
    }
    // Route is not protected, continue without validation
}
