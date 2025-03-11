const std = @import("std");
const builtin = @import("builtin");

const jetzig = @import("jetzig");

pub fn post(request: *jetzig.Request) !jetzig.View {
    const Params = struct {
        dark: []const u8,
    };

    const params = try request.expectParams(Params) orelse {
        var cookies = try request.cookies();
        try cookies.put(.{
            .name = "dark",
            .value = "",
            .path = "/",
            .http_only = if (builtin.mode == .Debug) false else true,
            .secure = if (builtin.mode == .Debug) false else true,
            .same_site = if (builtin.mode == .Debug) .lax else .strict,
            .max_age = 60 * 60 * 24 * 90, // 90 days in seconds
        });

        var root = try request.data(.object);
        try root.put("dark", "");
        return request.render(.created);
    };

    var cookies = try request.cookies();
    try cookies.put(.{
        .name = "dark",
        .value = params.dark,
        .path = "/",
        .http_only = if (builtin.mode == .Debug) false else true,
        .secure = if (builtin.mode == .Debug) false else true,
        .same_site = if (builtin.mode == .Debug) .lax else .strict,
        .max_age = 60 * 60 * 24 * 90, // 90 days in seconds
    });

    var root = try request.data(.object);
    try root.put("dark", "checked");

    return request.render(.created);
}
