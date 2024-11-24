const std = @import("std");
const builtin = @import("builtin");
const jetzig = @import("jetzig");

pub const layout = "landing";
pub fn index(request: *jetzig.Request, _: *jetzig.Data) !jetzig.View {
    // var root = try data.object();

    // if (builtin.mode == .Debug) {
    //     try root.put("runmode", "dev");
    // } else {
    //     try root.put("runmode", "prod");
    // }

    return request.render(.ok);
}
