const std = @import("std");
const jetzig = @import("jetzig");

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

pub fn beforeResponse(
    _: *router,
    _: *jetzig.http.Request,
    _: *jetzig.http.Response,
) !void {}

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
