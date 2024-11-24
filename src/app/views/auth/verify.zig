const std = @import("std");
const jetzig = @import("jetzig");

pub fn post(request: *jetzig.Request, _: *jetzig.Data) !jetzig.View {
    const Params = struct {
        email: []const u8,
        password: []const u8,
    };

    const params = try request.expectParams(Params) orelse {
        return request.fail(.unprocessable_entity);
    };

    //check if username and password is demo/demo
    if (!std.mem.eql(u8, params.email, "demo@demo.com") or !std.mem.eql(u8, params.password, "demo")) {
        return request.fail(.unauthorized);
    }

    var cookies = try request.cookies();
    try cookies.put(.{
        .name = "email",
        .value = params.email,
        .path = "/",
        .http_only = true,
        .same_site = .none, // Values: .strict, .lax, or .none
        .secure = true,
        .max_age = 60 * 60 * 24 * 90, // 90 days in seconds
    });

    try request.server.logger.DEBUG("[auth/login:post] ** Email: {s}", .{params.email});
    return request.render(.created);
    //request.setLayout("admin");
    //return request.redirect("/admin/dashboard", .found);
}
