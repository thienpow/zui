const std = @import("std");
const jetzig = @import("jetzig");

pub fn index(request: *jetzig.Request, _: *jetzig.Data) !jetzig.View {
    const Params = struct {
        provider: []const u8,
    };

    const params = try request.expectParams(Params) orelse {
        return request.fail(.unprocessable_entity);
    };

    // Generate and redirect to the OAuth login URL
    const login_url = blk: {
        const url = request.global.security.oauth.getOAuthLoginUrl(params.provider, request) catch {
            return request.fail(.internal_server_error);
        };
        break :blk url;
    };

    std.log.scoped(.auth).debug("[route.oauth.login] login_url: {s}", .{login_url});
    return request.redirect(login_url, .found);
}
