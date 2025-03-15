const std = @import("std");
const jetzig = @import("jetzig");

pub const layout = "admin";
pub fn index(request: *jetzig.Request) !jetzig.View {
    var cookies = try request.cookies();
    var dark = blk: {
        if (cookies.get("dark")) |cookie| {
            break :blk cookie.value;
        } else {
            break :blk "";
        }
    };
    dark = if (std.mem.eql(u8, dark, "on")) "checked" else "";
    var root = try request.data(.object);
    try root.put("dark", dark);

    return request.render(.ok);
}
