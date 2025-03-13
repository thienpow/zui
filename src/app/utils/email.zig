const std = @import("std");

/// Validates an email address according to simple but practical rules:
/// - Must contain a single @ character
/// - Must have at least one character before the @
/// - Must have at least one character after the @
/// - Must have at least one dot after the @
/// - The top-level domain must be at least 2 characters
/// - Characters must be valid for email addresses
///
/// Return: true if the email is valid, false otherwise
pub fn isValidEmail(email: []const u8) bool {
    // Check if the email is too short to be valid
    if (email.len < 5) { // a@b.c is minimal valid format (5 chars)
        return false;
    }

    // Find the position of the @ symbol
    const at_pos = std.mem.indexOf(u8, email, "@") orelse return false;

    // Check that @ isn't the first character and there's content before it
    if (at_pos == 0) {
        return false;
    }

    // Get the part after the @ symbol
    const domain_part = email[at_pos + 1 ..];

    // Check that the domain part is not empty
    if (domain_part.len == 0) {
        return false;
    }

    // Find the last dot in the domain part
    const last_dot = std.mem.lastIndexOf(u8, domain_part, ".") orelse return false;

    // Check that the dot isn't the first or last character in the domain
    if (last_dot == 0 or last_dot == domain_part.len - 1) {
        return false;
    }

    // Check that the TLD (part after the last dot) is at least 2 characters
    if (domain_part.len - last_dot - 1 < 2) {
        return false;
    }

    // Check for invalid characters
    for (email) |c| {
        switch (c) {
            'a'...'z', 'A'...'Z', '0'...'9', '.', '_', '-', '+', '@' => continue,
            else => return false,
        }
    }

    // All checks passed
    return true;
}

// Test cases:
test "isValidEmail" {
    const testing = std.testing;

    // Valid emails
    try testing.expect(isValidEmail("user@example.com"));
    try testing.expect(isValidEmail("user.name@domain.co.uk"));
    try testing.expect(isValidEmail("user+tag@example.com"));
    try testing.expect(isValidEmail("user_name@example.com"));
    try testing.expect(isValidEmail("user-name@example.com"));
    try testing.expect(isValidEmail("user123@example123.com"));

    // Invalid emails
    try testing.expect(!isValidEmail(""));
    try testing.expect(!isValidEmail("user"));
    try testing.expect(!isValidEmail("user@"));
    try testing.expect(!isValidEmail("@domain.com"));
    try testing.expect(!isValidEmail("user@.com"));
    try testing.expect(!isValidEmail("user@domain"));
    try testing.expect(!isValidEmail("user@domain."));
    try testing.expect(!isValidEmail("user@domain.c"));
    try testing.expect(!isValidEmail("user name@domain.com"));
    try testing.expect(!isValidEmail("user!@domain.com"));
    try testing.expect(!isValidEmail("user@dom@in.com"));
}
