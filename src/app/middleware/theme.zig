const std = @import("std");
const jetzig = @import("jetzig");
const cookie_utils = @import("../utils/cookie.zig");

const theme = @This();

/// Initialize middleware.
pub fn init(request: *jetzig.http.Request) !*theme {
    const middleware = try request.allocator.create(theme);
    return middleware;
}

pub fn deinit(self: *theme, request: *jetzig.http.Request) void {
    request.allocator.destroy(self);
}

pub fn afterRequest(_: *theme, request: *jetzig.http.Request) !void {
    // Only handle theme settings
    var data = try request.data(.object);

    // Apply theme logic
    const dark = getDarkModeSetting(request);
    try data.put("dark", dark);
}

pub fn afterResponse(self: *theme, request: *jetzig.http.Request, response: *jetzig.http.Response) !void {
    _ = self;
    _ = request;
    _ = response;
}

fn getDarkModeSetting(request: *jetzig.http.Request) ![]const u8 {
    const dark = blk: {
        const cookies = try request.cookies();
        if (cookies.get("dark")) |cookie| {
            break :blk cookie.value;
        } else {
            try cookie_utils.set_cookie(request, "dark", "", false);

            break :blk "";
        }
    };
    return if (std.mem.eql(u8, dark, "on")) "checked" else "";
}
