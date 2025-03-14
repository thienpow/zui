const std = @import("std");
const jetzig = @import("jetzig");

const ip_utils = @import("../../utils/ip.zig");
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
        remember: ?bool,
    };

    // Define a struct for error details to unify the type

    // Validate and extract parameters
    const params = try request.expectParams(Params) orelse {
        try request.global.security.audit.log(
            .login_failed,
            null,
            .{
                .action_details = "Missing required parameters",
                .ip_address = ip_utils.getClientIp(request),
                .user_agent = request.headers.get("User-Agent"),
            },
        );
        return request.fail(.unprocessable_entity);
    };

    const remember = params.remember orelse false;

    // Attempt authentication with credentials
    _ = request.global.security.authenticate(request, .{
        .email = params.email,
        .password = params.password,
    }, remember) catch |err| {
        std.log.scoped(.auth).debug("[route.login] Authentication failed with error: {s}", .{@errorName(err)});
        switch (err) {
            SecurityError.AccountLocked => {
                std.log.scoped(.auth).debug("[route.login] Account locked, returning 403", .{});
                return request.fail(.forbidden); // 403
            },
            SecurityError.RateLimitExceeded => {
                std.log.scoped(.auth).debug("[route.login] Rate limit exceeded, returning 429", .{});
                return request.fail(.too_many_requests); // 429
            },
            SecurityError.UserNotFound => {
                std.log.scoped(.auth).debug("[route.login] User not found, returning 404", .{});
                return request.fail(.not_found); // 404
            },
            SecurityError.InvalidCredentials => {
                std.log.scoped(.auth).debug("[route.login] Invalid credentials, returning 401", .{});
                return request.fail(.unauthorized); // 401
            },
            SecurityError.ValidationError => {
                std.log.scoped(.auth).debug("[route.login] Validation error, returning 400", .{});
                return request.fail(.bad_request); // 400
            },
            else => {
                std.log.err("[route.login] Unexpected error: {s}", .{@errorName(err)});
                return request.fail(.internal_server_error); // 500
            },
        }
    };
    std.log.scoped(.auth).debug("[route.login] Authentication succeeded", .{});
    // ... proceed with successful response ...

    return request.render(.created);
}
