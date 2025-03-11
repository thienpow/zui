const std = @import("std");
const jetzig = @import("jetzig");

pub fn set_cookie(request: *jetzig.Request, name: []const u8, value: []const u8) !void {
    var cookies = try request.cookies();
    std.log.scoped(.utils).debug("[Utils.Cookie.set_cookie], cookie_domain: {s}", .{request.global.config_manager.security_config.session.cookie_domain});
    try cookies.put(.{
        .name = name,
        .value = value,
        .domain = request.global.config_manager.security_config.session.cookie_domain,
        .path = "/",
        .http_only = if (jetzig.environment == .development) false else true,
        .secure = if (jetzig.environment == .development) false else true,
        .same_site = if (jetzig.environment == .development) .lax else .strict,
        .max_age = 60 * 60 * 24 * 90, // 90 days in seconds
    });
}
