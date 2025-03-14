const std = @import("std");
const jetzig = @import("jetzig");
const ip_utils = @import("../../utils/ip.zig");
const SecurityError = @import("../../security/errors.zig").SecurityError;
const SecurityEvent = @import("../../security/types.zig").SecurityEvent;

pub const layout = "auth";

pub fn index(request: *jetzig.Request) !jetzig.View {
    var root = try request.data(.object);

    const Params = struct {
        token: []const u8,
    };

    const params = try request.expectParams(Params) orelse {
        std.log.scoped(.password).debug("[route.password.reset] No token provided, redirecting to login", .{});
        return request.redirect("/auth/login", .found);
    };

    try root.put("token", params.token);
    return request.render(.ok);
}

pub fn post(request: *jetzig.Request) !jetzig.View {
    // Define expected parameters
    const Params = struct {
        token: []const u8,
        password: []const u8,
        password_confirm: []const u8,
    };

    // Validate and extract parameters
    const params = try request.expectParams(Params) orelse {
        try request.global.security.audit.log(
            .password_reset,
            null,
            .{
                .action_details = "Missing required parameters",
                .ip_address = ip_utils.getClientIp(request),
                .user_agent = request.headers.get("User-Agent"),
            },
        );
        return request.fail(.unprocessable_entity);
    };

    // Attempt to process the password reset
    request.global.security.resetPassword(request, .{
        .token = params.token,
        .password = params.password,
        .password_confirm = params.password_confirm,
    }) catch |err| {
        std.log.scoped(.password).debug("[route.password.reset] Password reset failed with error: {s}", .{@errorName(err)});

        switch (err) {
            SecurityError.InvalidToken => {
                std.log.scoped(.password).debug("[route.password.reset] Invalid or expired token, returning 401", .{});
                return request.fail(.unauthorized);
            },
            SecurityError.PasswordMismatch => {
                std.log.scoped(.password).debug("[route.password.reset] Password mismatch, returning 400", .{});
                return request.fail(.bad_request);
            },
            SecurityError.WeakPassword => {
                std.log.scoped(.password).debug("[route.password.reset] Password too weak, returning 400", .{});
                return request.fail(.bad_request);
            },
            SecurityError.RateLimitExceeded => {
                std.log.scoped(.password).debug("[route.password.reset] Rate limit exceeded, returning 429", .{});
                return request.fail(.too_many_requests);
            },
            else => {
                std.log.err("[route.password.reset] Unexpected error: {s}", .{@errorName(err)});
                return request.fail(.internal_server_error);
            },
        }
    };

    std.log.scoped(.password).debug("[route.password.reset] Password reset successful, redirecting to login", .{});
    return request.render(.created);
}
