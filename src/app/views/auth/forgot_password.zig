const std = @import("std");
const jetzig = @import("jetzig");

const ip_utils = @import("../../utils/ip.zig");
const SecurityError = @import("../../security/errors.zig").SecurityError;
const SecurityEvent = @import("../../security/types.zig").SecurityEvent;

pub const layout = "auth"; // Use the same layout as login

pub fn index(request: *jetzig.Request, _: *jetzig.Data) !jetzig.View {
    return request.render(.ok);
}

pub fn post(request: *jetzig.Request) !jetzig.View {

    // Define expected parameters
    const Params = struct {
        email: []const u8,
    };

    // Validate and extract parameters
    const params = try request.expectParams(Params) orelse {
        try request.global.security.audit.log(
            .password_reset_request,
            null,
            .{
                .action_details = "Missing email parameter",
                .ip_address = ip_utils.getClientIp(request),
                .user_agent = request.headers.get("User-Agent"),
            },
        );
        return request.fail(.unprocessable_entity);
    };

    // Request password reset through the security module
    request.global.security.requestPasswordReset(request, .{ .email = params.email }) catch |err| {
        std.log.scoped(.password).debug("[route.password.forgot] Password reset request failed with error: {s}", .{@errorName(err)});

        switch (err) {
            SecurityError.RateLimitExceeded => {
                std.log.scoped(.password).debug("[route.password.forgot] Rate limit exceeded, returning 429", .{});
                return request.fail(.too_many_requests); // 429
            },
            SecurityError.ValidationError => {
                std.log.scoped(.password).debug("[route.password.forgot] Validation error, returning 400", .{});
                return request.fail(.bad_request); // 400
            },
            else => {
                // For security reasons, we don't expose details about other errors
                // like UserNotFound to prevent email enumeration attacks
                std.log.scoped(.password).debug("[route.password.forgot] Other error occurred, but returning generic success for security", .{});
                // Still return success to prevent user enumeration
                return request.render(.created);
            },
        }
    };

    std.log.scoped(.password).debug("[route.password.forgot] Password reset request processed successfully", .{});
    return request.render(.created);
}
