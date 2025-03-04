const std = @import("std");
const jetzig = @import("jetzig");

const htmx = @This();

/// Initialize middleware.
pub fn init(request: *jetzig.http.Request) !*htmx {
    const middleware = try request.allocator.create(htmx);
    return middleware;
}
pub fn deinit(self: *htmx, request: *jetzig.http.Request) void {
    request.allocator.destroy(self);
}

pub fn afterRequest(_: *htmx, request: *jetzig.http.Request) !void {
    // Only handle HTMX-specific behaviors
    const is_htmx = request.headers.get("HX-Request") != null;
    if (is_htmx) {
        request.setLayout(null);
    }
}
pub fn afterResponse(self: *htmx, request: *jetzig.http.Request, response: *jetzig.http.Response) !void {
    _ = self;
    _ = request;
    _ = response;
}
