const std = @import("std");

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const color_reset = "\x1b[0m";
    const color_level = switch (level) {
        .err => "\x1b[31m", // Red
        .warn => "\x1b[33m", // Yellow
        .info => "\x1b[32m", // Green
        .debug => "\x1b[34m", // Blue
    };

    const color_scope = switch (scope) {
        .config => "\x1b[36m", // Cyan
        .auth => "\x1b[35m", // Magenta
        .redis_client => "\x1b[92m", // Light Green
        .other => "\x1b[95m", // Light Magenta
        else => "\x1b[90m", // Gray for other scopes
    };

    // Skip specific debug logs
    if (level == .debug) {
        if ( //scope == .redis or
        scope == .config or
            //scope == .auth or
            //scope == .utils or
            scope == .other)
        {
            return;
        }
    }

    // Format level name in uppercase
    const level_str = switch (level) {
        .err => "ERROR",
        .warn => "WARN",
        .info => "INFO",
        .debug => "DEBUG",
    };

    // Print the colored log manually
    std.debug.print("{s}[{s}]{s} ({s}{s}{s}): ", .{ color_level, level_str, color_reset, color_scope, @tagName(scope), color_reset });
    std.debug.print(format ++ "\n", args);
}
