const std = @import("std");
const jetzig = @import("jetzig");
const cookie_utils = @import("../../../utils/cookie.zig");

pub fn post(request: *jetzig.Request) !jetzig.View {
    const Params = struct {
        dark: []const u8,
    };

    const params = try request.expectParams(Params) orelse {
        try cookie_utils.set_cookie(request, "dark", "");

        var root = try request.data(.object);
        try root.put("dark", "");
        return request.render(.created);
    };

    try cookie_utils.set_cookie(request, "dark", params.dark);

    var root = try request.data(.object);
    try root.put("dark", "checked");

    return request.render(.created);
}
