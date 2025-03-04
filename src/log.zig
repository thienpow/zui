const std = @import("std");

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    // Skip specific debug logs
    if (level == .debug) {
        if (scope == .redis_client or
            //  below is not implemented.
            //  To implement, replace existing std.log.debug in each module
            //  to example: std.log.scoped(.config_manager).debug
            //scope == .redis_pool or
            //scope == .config_manager or
            //scope == .security or
            scope == .other)
        {
            return;
        }
    }

    // Forward to the standard implementation
    std.log.defaultLog(level, scope, format, args);
}
