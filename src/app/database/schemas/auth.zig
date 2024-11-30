const std = @import("std");

pub const UserSession = struct {
    id: i64,
    token: []const u8,
    last_activity: i64,

    pub fn format(
        user: UserSession,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.writeAll("{");
        _ = try writer.print("\"id\":{},", .{user.id});
        _ = try writer.print("\"token\":\"{s}\",", .{user.token});
        _ = try writer.print("\"last_activity\":{}", .{user.last_activity});
        try writer.writeAll("}");
    }
};
