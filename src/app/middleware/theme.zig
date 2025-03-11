const std = @import("std");
const builtin = @import("builtin");
const jetzig = @import("jetzig");

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
    const cookies = try request.cookies();
    const dark = getDarkModeSetting(cookies);
    try data.put("dark", dark);
}

pub fn afterResponse(self: *theme, request: *jetzig.http.Request, response: *jetzig.http.Response) !void {
    _ = self;
    _ = request;
    _ = response;
}

fn getDarkModeSetting(cookies: *jetzig.http.Cookies) ![]const u8 {
    const dark = blk: {
        if (cookies.get("dark")) |cookie| {
            break :blk cookie.value;
        } else {
            try cookies.put(.{
                .name = "dark",
                .value = "",
                .path = "/",
                .http_only = if (builtin.mode == .Debug) false else true,
                .secure = if (builtin.mode == .Debug) false else true,
                .same_site = if (builtin.mode == .Debug) .lax else .strict,
                .max_age = 60 * 60 * 24 * 90, // 90 days in seconds
            });
            break :blk "";
        }
    };
    return if (std.mem.eql(u8, dark, "on")) "checked" else "";
}
