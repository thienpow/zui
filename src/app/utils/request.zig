const std = @import("std");
const jetzig = @import("jetzig");

pub fn getPathString(request: *jetzig.http.Request) []const u8 {
    if (@hasField(@TypeOf(request.path), "raw")) {
        return request.path.raw;
    } else if (@hasField(@TypeOf(request.path), "path")) {
        return request.path.path;
    } else {
        return "";
    }
}
