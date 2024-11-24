const std = @import("std");
const jetzig = @import("jetzig");

pub const layout = "admin";
pub fn index(request: *jetzig.Request, data: *jetzig.Data) !jetzig.View {
    var root = try data.object();
    var page = try root.put("page", .object);
    try page.put("total_page", 10);
    try page.put("current_page", 1);

    return request.render(.ok);
}
