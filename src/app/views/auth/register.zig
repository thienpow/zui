const std = @import("std");
const jetzig = @import("jetzig");

pub const layout = "auth";
pub fn index(request: *jetzig.Request, _: *jetzig.Data) !jetzig.View {
    return request.render(.ok);
}

pub fn post(request: *jetzig.Request) !jetzig.View {
    const Params = struct {
        username: []const u8,
        email: []const u8,
        password: []const u8,
    };

    const params = try request.expectParams(Params) orelse {
        return request.fail(.unprocessable_entity);
    };

    const allocator = request.allocator;
    // Hash the password
    const hashedPassword = try jetzig.auth.hashPassword(allocator, params.password);

    try request.repo.insert(.User, .{
        .username = params.username,
        .email = params.email,
        .password_hash = hashedPassword,
    });

    return request.render(.created);
}
