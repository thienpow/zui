const std = @import("std");
const jetzig = @import("jetzig");

pub fn set_cookie(request: *jetzig.Request, name: []const u8, value: []const u8, is_oauth: bool) !void {
    var cookies = try request.cookies();

    const on_https = request.global.config_manager.security_config.on_https;
    try cookies.put(.{
        .name = name,
        .value = value,
        .domain = request.global.config_manager.security_config.session.cookie_domain,
        .path = "/",
        .http_only = if (jetzig.environment == .development and !on_https) false else true,
        .secure = if (jetzig.environment == .development and !on_https) false else true,
        .same_site = if (is_oauth) .lax else .strict,
        .max_age = 60 * 60 * 24 * 90, // 90 days in seconds
    });
}
