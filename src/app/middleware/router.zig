const std = @import("std");
const jetzig = @import("jetzig");

const auth_middleware = @import("auth.zig");
const theme_middleware = @import("theme.zig");
const htmx_middleware = @import("htmx.zig");

const router = @This();

/// Initialize middleware.
pub fn init(request: *jetzig.http.Request) !*router {
    const middleware = try request.allocator.create(router);
    return middleware;
}

pub fn deinit(self: *router, request: *jetzig.http.Request) void {
    request.allocator.destroy(self);
}

pub fn afterRequest(_: *router, request: *jetzig.http.Request) !void {
    try request.server.logger.DEBUG("[router] Starting request processing", .{});

    // Execute authentication middleware
    var auth = try auth_middleware.init(request);
    defer auth.deinit(request);
    try auth.afterRequest(request);

    // Execute HTMX middleware
    var htmx = try htmx_middleware.init(request);
    defer htmx.deinit(request);
    try htmx.afterRequest(request);

    // Execute theme middleware
    var theme = try theme_middleware.init(request);
    defer theme.deinit(request);
    try theme.afterRequest(request);

    try request.server.logger.DEBUG("[router] Request processing completed", .{});
}

pub fn afterResponse(self: *router, request: *jetzig.http.Request, response: *jetzig.http.Response) !void {
    _ = self;
    _ = response;
    try request.server.logger.DEBUG("[router] Response completed", .{});
}
