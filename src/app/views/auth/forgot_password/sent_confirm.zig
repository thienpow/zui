const std = @import("std");
const jetzig = @import("jetzig");

pub const layout = "auth"; // Use the same layout as login

pub fn index(request: *jetzig.Request) !jetzig.View {
    const Params = struct {
        email: []const u8,
    };

    const params = try request.expectParams(Params) orelse {
        return request.fail(.unprocessable_entity);
    };
    var data = try request.data(.object);
    try data.put("email", params.email);

    return request.render(.ok);
}
