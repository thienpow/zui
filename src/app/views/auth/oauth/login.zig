const std = @import("std");
const jetzig = @import("jetzig");

pub fn index(request: *jetzig.Request, _: *jetzig.Data) !jetzig.View {
    const Params = struct {
        provider: []const u8,
    };

    std.debug.print("DEBUG: Attempting to parse provider parameter\n", .{});

    const params = try request.expectParams(Params) orelse {
        std.debug.print("DEBUG: Failed to get provider parameter\n", .{});
        return request.fail(.unprocessable_entity);
    };

    std.debug.print("DEBUG: Provider parameter found: {s}\n", .{params.provider});

    // Generate and redirect to the OAuth login URL
    std.debug.print("DEBUG: Attempting to get OAuth login URL for provider: {s}\n", .{params.provider});

    const login_url = blk: {
        const url = request.global.security.getOAuthLoginUrl(params.provider, request) catch |err| {
            std.debug.print("DEBUG: Error getting OAuth URL: {}\n", .{err});
            return request.fail(.internal_server_error);
        };
        std.debug.print("DEBUG: Generated OAuth URL: {s}\n", .{url});
        break :blk url;
    };

    std.debug.print("DEBUG: Redirecting to OAuth URL\n", .{});
    return request.redirect(login_url, .found);
}
