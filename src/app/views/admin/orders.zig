const std = @import("std");
const jetzig = @import("jetzig");

pub const layout = "admin";
pub fn index(request: *jetzig.Request) !jetzig.View {
    return request.render(.ok);
}
