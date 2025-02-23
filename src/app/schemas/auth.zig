const std = @import("std");

pub const UserSession = struct {
    id: i64,
    token: []const u8,
    last_active: i64,
    expires_at: i64,

    pub fn format(
        user: UserSession,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.writeAll("{");
        _ = try writer.print("\"id\":{},", .{user.id});
        _ = try writer.print("\"token\":\"{s}\",", .{user.token});
        _ = try writer.print("\"last_active\":{}", .{user.last_active});
        _ = try writer.print("\"expires_at\":{}", .{user.expires_at});
        try writer.writeAll("}");
    }
};
