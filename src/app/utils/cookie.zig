const std = @import("std");
const jetzig = @import("jetzig");

pub fn set_cookie(request: *jetzig.Request, name: []const u8, value: []const u8) !void {
    const cookies = try request.cookies();
    try cookies.put(jetzig.http.Cookies.Cookie{
        .name = name,
        .value = value,
        .domain = request.global.config_manager.security_config.session.cookie_domain,
        .path = "/",
        .http_only = true,
        .secure = true,
        .same_site = .strict,
        .max_age = 60 * 60 * 24 * 90, // 90 days in seconds
    });
}

pub fn set_oauth_cookie(request: *jetzig.Request, value: []const u8) !void {
    const cookies = try request.cookies();
    try cookies.put(jetzig.http.Cookies.Cookie{
        .name = request.global.config_manager.security_config.oauth.state_cookie_name,
        .value = value,
        .domain = request.global.config_manager.security_config.session.cookie_domain,
        .path = "/",
        .http_only = true,
        .secure = true,
        .same_site = .lax,
        .max_age = 60 * 5, // 5 minutes in seconds

    });
}
