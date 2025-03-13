const std = @import("std");

pub fn isStrongPassword(password: []const u8) bool {
    // Check minimum length
    if (password.len < 8) {
        return false;
    }

    // Check for at least one uppercase letter
    var has_uppercase = false;
    // Check for at least one lowercase letter
    var has_lowercase = false;
    // Check for at least one digit
    var has_digit = false;
    // Check for at least one special character
    var has_special = false;

    for (password) |c| {
        switch (c) {
            'A'...'Z' => has_uppercase = true,
            'a'...'z' => has_lowercase = true,
            '0'...'9' => has_digit = true,
            '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '-', '_', '+', '=', '[', ']', '{', '}', '|', '\\', ';', ':', '"', '\'', '<', '>', ',', '.', '/', '?' => has_special = true,
            else => {},
        }
    }

    // For basic strength, require at least 3 of the 4 character types
    var criteria_met: u8 = 0;
    if (has_uppercase) criteria_met += 1;
    if (has_lowercase) criteria_met += 1;
    if (has_digit) criteria_met += 1;
    if (has_special) criteria_met += 1;

    return criteria_met >= 3;
}
pub fn hashPassword(allocator: std.mem.Allocator, password: []const u8) ![]const u8 {
    // Argon2id output format: $argon2id$v=19$m=32,t=3,p=4$salt$hash
    // Typical max length: ~108 bytes with default salt (16 bytes) and hash (32 bytes)
    // Using 128 as a safe upper bound
    const buf_size = 128;
    const buf = try allocator.alloc(u8, buf_size);

    const hashed = try std.crypto.pwhash.argon2.strHash(
        password,
        .{
            .allocator = allocator,
            .params = .{
                .t = 3, // Time cost
                .m = 32, // Memory cost (32 KiB)
                .p = 4, // Parallelism
            },
            .mode = .argon2id, // Explicitly specify for consistency
        },
        buf,
    );

    // Trim the buffer to actual size
    const actual_len = hashed.len;
    if (actual_len < buf_size) {
        return try allocator.realloc(buf, actual_len);
    }
    return hashed;
}
