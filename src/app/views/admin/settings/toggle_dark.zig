const std = @import("std");
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
            .http_only = true,
            .same_site = .strict, // Values: .strict, .lax, or .none
            .secure = true,
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
        .http_only = true,
        .same_site = .strict, // Values: .strict, .lax, or .none
        .secure = true,
        .max_age = 60 * 60 * 24 * 90, // 90 days in seconds
    });

    var root = try request.data(.object);
    try root.put("dark", "checked");

    return request.render(.created);
}
