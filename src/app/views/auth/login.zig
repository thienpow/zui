const std = @import("std");
const jetzig = @import("jetzig");
const SecurityError = @import("../../security/errors.zig").SecurityError;
const SecurityEvent = @import("../../security/types.zig").SecurityEvent;
const ErrorDetails = @import("../../security/types.zig").ErrorDetails;

pub const layout = "auth";

pub fn index(request: *jetzig.Request, _: *jetzig.Data) !jetzig.View {
    return request.render(.ok);
}

pub fn post(request: *jetzig.Request) !jetzig.View {
    // Define expected parameters
    const Params = struct {
        email: []const u8,
        password: []const u8,
    };

    // Define a struct for error details to unify the type

    // Validate and extract parameters
    const params = try request.expectParams(Params) orelse {
        try request.global.security.audit.log(
            .login_failed,
            null,
            .{
                .action_details = "Missing required parameters",
                .ip_address = try request.global.security.getIdentifier(request),
                .user_agent = request.headers.get("User-Agent"),
            },
        );
        return request.fail(.unprocessable_entity);
    };

    //std.log.info("params: {any}", .{params});
    // Attempt authentication with credentials
    _ = request.global.security.authenticate(request, .{
        .email = params.email,
        .password = params.password,
    }) catch |err| {
        std.log.info("err: {any}", .{err});
        return switch (err) {
            SecurityError.UserNotFound => request.fail(.not_found), //User not found
            SecurityError.InvalidCredentials => request.fail(.unauthorized), //Invalid credentials"to generate session
            else => request.fail(.internal_server_error), //Authentication failed
        };
    };

    // // Set session cookies
    // try request.setCookie("access_token", auth_result.tokens.access, .{
    //     .http_only = true,
    //     .secure = true,
    //     .same_site = .strict,
    // });

    // try request.setCookie("refresh_token", auth_result.tokens.refresh, .{
    //     .http_only = true,
    //     .secure = true,
    //     .same_site = .strict,
    // });

    // try request.setCookie("csrf_token", auth_result.tokens.csrf, .{
    //     .http_only = false, // Allow JavaScript access for CSRF protection
    //     .secure = true,
    //     .same_site = .strict,
    // });

    return request.render(.created);
}
