const std = @import("std");
const types = @import("types.zig");
const email_utils = @import("../utils/email.zig");
const password_utils = @import("../utils/password.zig");

/// Username validation parameters
pub const UsernameValidationParams = struct {
    min_length: usize = 3,
    max_length: usize = 30,
    allow_special_chars: bool = false,
    reserved_names: []const []const u8 = &[_][]const u8{
        "admin", "administrator", "system",    "root",     "support",
        "help",  "info",          "webmaster", "security", "anonymous",
    },
};

/// Results of validation with detailed error information
pub const ValidationResult = struct {
    is_valid: bool,
    error_field: ?[]const u8,
    error_message: ?[]const u8,

    pub fn valid() ValidationResult {
        return .{
            .is_valid = true,
            .error_field = null,
            .error_message = null,
        };
    }

    pub fn invalid(field: []const u8, message: []const u8) ValidationResult {
        return .{
            .is_valid = false,
            .error_field = field,
            .error_message = message,
        };
    }
};

/// Validate email format and domain
pub fn validateEmail(allocator: std.mem.Allocator, email: []const u8, check_dns: bool) !ValidationResult {
    // Check if email is empty
    if (email.len == 0) {
        return ValidationResult.invalid("email", "Email cannot be empty");
    }

    // Check basic email format
    if (!email_utils.isValidEmail(email)) {
        return ValidationResult.invalid("email", "Invalid email format");
    }

    // If DNS check is enabled, verify domain MX records
    if (check_dns) {
        const domain = blk: {
            const at_index = std.mem.indexOf(u8, email, "@") orelse return ValidationResult.invalid("email", "Invalid email format");
            break :blk email[at_index + 1 ..];
        };

        const is_valid_domain = try email_utils.validateEmailDomain(allocator, domain);
        if (!is_valid_domain) {
            return ValidationResult.invalid("email", "Invalid email domain");
        }
    }

    return ValidationResult.valid();
}

/// Validate password strength and requirements
pub fn validatePassword(password: []const u8, confirm_password: ?[]const u8, min_length: usize) ValidationResult {
    // Check if password is empty
    if (password.len == 0) {
        return ValidationResult.invalid("password", "Password cannot be empty");
    }

    // Check minimum length
    if (password.len < min_length) {
        return ValidationResult.invalid("password", std.fmt.comptimePrint("Password must be at least {d} characters long", .{min_length}));
    }

    // Check for basic strength (at least one uppercase, one lowercase, one digit)
    var has_uppercase = false;
    var has_lowercase = false;
    var has_digit = false;
    var has_special = false;

    for (password) |char| {
        if (std.ascii.isUpper(char)) has_uppercase = true;
        if (std.ascii.isLower(char)) has_lowercase = true;
        if (std.ascii.isDigit(char)) has_digit = true;
        if (!std.ascii.isAlphanumeric(char)) has_special = true;
    }

    if (!has_uppercase) {
        return ValidationResult.invalid("password", "Password must contain at least one uppercase letter");
    }

    if (!has_lowercase) {
        return ValidationResult.invalid("password", "Password must contain at least one lowercase letter");
    }

    if (!has_digit) {
        return ValidationResult.invalid("password", "Password must contain at least one digit");
    }

    if (!has_special) {
        return ValidationResult.invalid("password", "Password must contain at least one special character");
    }

    // If confirm password is provided, check that they match
    if (confirm_password) |confirm| {
        if (!std.mem.eql(u8, password, confirm)) {
            return ValidationResult.invalid("password_confirm", "Passwords do not match");
        }
    }

    return ValidationResult.valid();
}

/// Validate username format and restrictions
pub fn validateUsername(username: []const u8, params: UsernameValidationParams) ValidationResult {
    // Check if username is empty
    if (username.len == 0) {
        return ValidationResult.invalid("username", "Username cannot be empty");
    }

    // Check length constraints
    if (username.len < params.min_length) {
        return ValidationResult.invalid("username", std.fmt.comptimePrint("Username must be at least {d} characters long", .{params.min_length}));
    }

    if (username.len > params.max_length) {
        return ValidationResult.invalid("username", std.fmt.comptimePrint("Username cannot exceed {d} characters", .{params.max_length}));
    }

    // Check for reserved names
    for (params.reserved_names) |reserved| {
        if (std.ascii.eqlIgnoreCase(username, reserved)) {
            return ValidationResult.invalid("username", "This username is reserved and cannot be used");
        }
    }

    // Validate characters
    for (username) |char| {
        const is_valid = std.ascii.isAlphanumeric(char) or
            (params.allow_special_chars and (char == '_' or char == '-' or char == '.'));

        if (!is_valid) {
            if (params.allow_special_chars) {
                return ValidationResult.invalid("username", "Username can only contain letters, numbers, and the special characters: _ - .");
            } else {
                return ValidationResult.invalid("username", "Username can only contain letters and numbers");
            }
        }
    }

    // Username should start with a letter
    if (!std.ascii.isAlpha(username[0])) {
        return ValidationResult.invalid("username", "Username must start with a letter");
    }

    return ValidationResult.valid();
}

/// Validate phone number format
pub fn validatePhone(phone: []const u8) ValidationResult {
    if (phone.len == 0) {
        return ValidationResult.valid(); // Phone is optional
    }

    // Strip any spaces, dashes, parentheses for normalization
    var normalized_count: usize = 0;
    for (phone) |char| {
        if (std.ascii.isDigit(char) or char == '+') {
            normalized_count += 1;
        }
    }

    // Too few or too many digits
    if (normalized_count < 7 or normalized_count > 15) {
        return ValidationResult.invalid("phone", "Phone number must contain between 7 and 15 digits");
    }

    // Check for proper formatting (simplified check)
    var has_non_acceptable = false;
    for (phone) |char| {
        const is_valid = std.ascii.isDigit(char) or char == '+' or char == ' ' or
            char == '(' or char == ')' or char == '-';

        if (!is_valid) {
            has_non_acceptable = true;
            break;
        }
    }

    if (has_non_acceptable) {
        return ValidationResult.invalid("phone", "Phone number contains invalid characters");
    }

    return ValidationResult.valid();
}

/// Validate name fields
pub fn validateName(name: []const u8, field: []const u8) ValidationResult {
    if (name.len == 0) {
        return ValidationResult.valid(); // Names are optional
    }

    // Check length
    if (name.len > 50) {
        return ValidationResult.invalid(field, "Name cannot exceed 50 characters");
    }

    // Check for valid name characters (allowing for international names)
    for (name) |char| {
        // Accept letters, spaces, hyphens, and apostrophes for names
        if (!std.ascii.isAlpha(char) and char != ' ' and char != '-' and char != '\'') {
            return ValidationResult.invalid(field, "Name contains invalid characters");
        }
    }

    return ValidationResult.valid();
}

/// Validate complete user registration data
pub fn validateRegistration(allocator: std.mem.Allocator, data: types.UserRegistrationData) !ValidationResult {
    // Validate username
    const username_result = validateUsername(data.username, .{});
    if (!username_result.is_valid) {
        return username_result;
    }

    // Validate email
    const email_result = try validateEmail(allocator, data.email, true);
    if (!email_result.is_valid) {
        return email_result;
    }

    // Validate password
    const password_result = validatePassword(data.password, data.password_confirm, 8);
    if (!password_result.is_valid) {
        return password_result;
    }

    // Validate first name if provided
    if (data.first_name) |first_name| {
        const first_name_result = validateName(first_name, "first_name");
        if (!first_name_result.is_valid) {
            return first_name_result;
        }
    }

    // Validate last name if provided
    if (data.last_name) |last_name| {
        const last_name_result = validateName(last_name, "last_name");
        if (!last_name_result.is_valid) {
            return last_name_result;
        }
    }

    // Validate phone if provided
    if (data.phone) |phone| {
        const phone_result = validatePhone(phone);
        if (!phone_result.is_valid) {
            return phone_result;
        }
    }

    return ValidationResult.valid();
}

/// Validate user update data
pub fn validateUserUpdate(allocator: std.mem.Allocator, data: types.UserUpdateData) !ValidationResult {
    // Validate username if provided
    if (data.username) |username| {
        const username_result = validateUsername(username, .{});
        if (!username_result.is_valid) {
            return username_result;
        }
    }

    // Validate email if provided
    if (data.email) |email| {
        const email_result = try validateEmail(allocator, email, true);
        if (!email_result.is_valid) {
            return email_result;
        }
    }

    // Validate first name if provided
    if (data.first_name) |first_name| {
        const first_name_result = validateName(first_name, "first_name");
        if (!first_name_result.is_valid) {
            return first_name_result;
        }
    }

    // Validate last name if provided
    if (data.last_name) |last_name| {
        const last_name_result = validateName(last_name, "last_name");
        if (!last_name_result.is_valid) {
            return last_name_result;
        }
    }

    // Validate phone if provided
    if (data.phone) |phone| {
        const phone_result = validatePhone(phone);
        if (!phone_result.is_valid) {
            return phone_result;
        }
    }

    return ValidationResult.valid();
}

/// Validate suspension data
pub fn validateSuspension(data: types.UserSuspensionData) ValidationResult {
    const current_time = std.time.timestamp();

    if (data.suspended_until <= current_time) {
        return ValidationResult.invalid("suspended_until", "Suspension end time must be in the future");
    }

    // Ensure suspension has a reason
    if (data.reason.len == 0) {
        return ValidationResult.invalid("reason", "Suspension reason is required");
    }

    // Limit suspension duration (e.g., max 1 year)
    const max_suspension = current_time + (365 * 24 * 60 * 60); // 1 year in seconds
    if (data.suspended_until > max_suspension) {
        return ValidationResult.invalid("suspended_until", "Suspension cannot exceed 1 year");
    }

    return ValidationResult.valid();
}

/// Validate ban data
pub fn validateBan(data: types.UserBanData) ValidationResult {
    // If it's a temporary ban, validate the expiration time
    if (!data.permanent) {
        if (data.banned_until) |expiry| {
            const current_time = std.time.timestamp();

            if (expiry <= current_time) {
                return ValidationResult.invalid("banned_until", "Ban end time must be in the future");
            }
        } else {
            return ValidationResult.invalid("banned_until", "Temporary ban requires an expiration time");
        }
    }

    return ValidationResult.valid();
}

/// Validate role assignment data
pub fn validateRoleAssignment(data: types.RoleAssignmentData) ValidationResult {
    // Validate expiration if provided
    if (data.expiration) |expiry| {
        const current_time = std.time.timestamp();

        if (expiry <= current_time) {
            return ValidationResult.invalid("expiration", "Role expiration time must be in the future");
        }
    }

    return ValidationResult.valid();
}

/// Check if a string contains profanity or inappropriate content
pub fn containsProfanity(_: []const u8) bool {
    // In a real implementation, you would implement profanity checking
    // using a dictionary approach or an API call
    // This is a placeholder implementation
    return false;
}

/// Sanitize user input to prevent XSS and other injection attacks
pub fn sanitizeUserInput(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        const c = input[i];
        switch (c) {
            // Replace potentially dangerous characters with HTML entities
            '<' => try buffer.appendSlice("&lt;"),
            '>' => try buffer.appendSlice("&gt;"),
            '&' => try buffer.appendSlice("&amp;"),
            '"' => try buffer.appendSlice("&quot;"),
            '\'' => try buffer.appendSlice("&#39;"),
            // For other characters, just copy them
            else => try buffer.append(c),
        }
    }

    return buffer.toOwnedSlice();
}
