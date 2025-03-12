const std = @import("std");
const jetzig = @import("jetzig");

pub fn set_cookie(request: *jetzig.Request, name: []const u8, value: []const u8) !void {
    var cookies = try request.cookies();

    var cookie = jetzig.http.Cookies.Cookie{
        .name = name,
        .value = value,
    };

    // cookie.domain = request.global.config_manager.security_config.session.cookie_domain;
    // cookie.path = "/";
    // cookie.http_only = true;
    // cookie.secure = true;
    // cookie.same_site = .strict;
    cookie.max_age = 60 * 60 * 24 * 90; // 90 days in seconds

    try cookies.put(cookie);
}

pub fn set_oauth_cookie(request: *jetzig.Request, value: []const u8) !void {
    var cookies = try request.cookies();

    var cookie = jetzig.http.Cookies.Cookie{
        .name = request.global.config_manager.security_config.oauth.state_cookie_name,
        .value = value,
    };

    // cookie.domain = request.global.config_manager.security_config.session.cookie_domain;
    // cookie.path = "/";
    // cookie.http_only = true;
    // cookie.secure = true;
    cookie.same_site = .lax;
    cookie.max_age = 60 * 5; // 5 minutes in seconds

    try cookies.put(cookie);
}
