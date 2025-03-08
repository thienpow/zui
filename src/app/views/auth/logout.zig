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
    _ = request.global.security.logout(request) catch |err| {
        std.log.scoped(.auth).debug("[route.logout] logout failed with error: {s}", .{@errorName(err)});
    };

    return request.render(.created);
}
