const std = @import("std");
const jetzig = @import("jetzig");

pub const layout = "landing";
pub fn index(request: *jetzig.Request, _: *jetzig.Data) !jetzig.View {
    return request.render(.ok);
}
