const std = @import("std");
const jetzig = @import("jetzig");
const ip_utils = @import("../utils/ip.zig");
const types = @import("types.zig");
const AuditMetadata = @import("audit.zig").AuditMetadata;

const Session = types.Session;

pub const ValidationError = error{
    InvalidIPAddress,
    InvalidUserAgent,
    SessionBindingMismatch,
    MetadataValidationFailed,
    InvalidResourceId,
    InvalidResourceType,
    InvalidStatus,
    PayloadTooLarge,
    InvalidCharacters,
    CustomDataValidationFailed,
};

pub fn validateSessionBinding(session: Session, request: *jetzig.Request) !bool {
    if (std.time.timestamp() >= session.expires_at) {
        return error.SessionExpired;
    }

    // Get client IP from headers instead of client_address
    const client_ip = ip_utils.getClientIp(request);

    // Debug: Log the client IP and session metadata
    std.log.debug("[validateSessionBinding] Client IP: '{s}'", .{client_ip});
    std.log.debug("[validateSessionBinding] Session metadata: ip='{s}', ua='{s}'", .{ session.metadata.ip_address orelse "null", session.metadata.user_agent orelse "null" });

    // if (!isValidIPAddress(client_ip)) {
    //     std.log.warn("Invalid IP address format: {s}", .{client_ip});
    //     return error.InvalidIPAddress;
    // }

    // Validate IP address binding if present
    if (session.metadata.ip_address) |stored_ip| {
        // Skip empty or special IPs
        if (stored_ip.len == 0 or
            std.mem.eql(u8, stored_ip, "localhost") or
            std.mem.eql(u8, stored_ip, "127.0.0.1") or
            std.mem.eql(u8, stored_ip, "unknown"))
        {
            std.log.debug("[validateSessionBinding] Skipping validation for special IP: '{s}'", .{stored_ip});
            return true;
        }

        if (!std.mem.eql(u8, stored_ip, client_ip)) {
            std.log.warn("Session IP mismatch - Stored: '{s}', Current: '{s}'", .{ stored_ip, client_ip });
            return ValidationError.SessionBindingMismatch;
        }
    }

    // Validate User-Agent binding if present
    const current_ua = request.headers.get("User-Agent") orelse "";

    if (session.metadata.user_agent) |stored_ua| {
        // Optional: Could implement fuzzy matching or partial UA comparison
        if (!std.mem.eql(u8, stored_ua, current_ua)) {
            std.log.warn("Session User-Agent mismatch - Stored: {s}, Current: {s}", .{ stored_ua, current_ua });
            return ValidationError.SessionBindingMismatch;
        }
    }

    return true;
}

pub fn validateMetadata(metadata: AuditMetadata) !void {
    // Validate action details
    if (metadata.action_details) |details| {
        try validateString(details, 1024); // Max length 1024 chars
        try validateCharacters(details);
    }

    // Validate resource ID
    if (metadata.resource_id) |id| {
        if (id.len == 0 or id.len > 128) {
            return ValidationError.InvalidResourceId;
        }
        try validateCharacters(id);
    }

    // Validate resource type
    if (metadata.resource_type) |res_type| {
        if (res_type.len == 0 or res_type.len > 64) {
            return ValidationError.InvalidResourceType;
        }
        try validateCharacters(res_type);
    }

    // Validate status
    if (metadata.status) |status| {
        if (status.len == 0 or status.len > 32) {
            return ValidationError.InvalidStatus;
        }
        try validateCharacters(status);
    }

    // Validate error message
    if (metadata.error_message) |error_msg| {
        try validateString(error_msg, 2048); // Max length 2048 chars
        try validateCharacters(error_msg);
    }

    // Validate custom data
    if (metadata.custom_data) |custom| {
        try validateCustomData(custom);
    }
}

fn validateString(str: []const u8, max_length: usize) !void {
    if (str.len == 0 or str.len > max_length) {
        return ValidationError.PayloadTooLarge;
    }
}

fn isPrintableAscii(char: u8) bool {
    return char >= 32 and char <= 126; // ASCII printable range
}

fn validateCharacters(str: []const u8) !void {
    for (str) |char| {
        // Allow printable ASCII characters, but not newlines or carriage returns
        if (!isPrintableAscii(char) or char == '\n' or char == '\r') {
            return ValidationError.InvalidCharacters;
        }
    }
}

fn validateCustomData(data: std.json.Value) !void {
    switch (data) {
        .object => |obj| {
            // Validate object size
            if (obj.count() > 50) { // Max 50 key-value pairs
                return ValidationError.CustomDataValidationFailed;
            }

            // Validate each key-value pair
            var it = obj.iterator();
            while (it.next()) |entry| {
                try validateString(entry.key_ptr.*, 64); // Max key length 64
                try validateCustomData(entry.value_ptr.*);
            }
        },
        .array => |arr| {
            // Validate array size
            if (arr.items.len > 100) { // Max 100 items
                return ValidationError.CustomDataValidationFailed;
            }

            // Validate each array item
            for (arr.items) |item| {
                try validateCustomData(item);
            }
        },
        .string => |str| {
            try validateString(str, 1024); // Max string length 1024
            try validateCharacters(str);
        },
        .integer => |int| {
            // Optional: Add range validation if needed
            if (int < -9223372036854775808 or int > 9223372036854775807) {
                return ValidationError.CustomDataValidationFailed;
            }
        },
        .float => |float| {
            // Optional: Add range validation if needed
            if (std.math.isNan(float) or std.math.isInf(float)) {
                return ValidationError.CustomDataValidationFailed;
            }
        },
        .bool => {
            // Boolean values are always valid
        },
        .null => {
            // Null values are allowed
        },
        .number_string => |str| {
            try validateString(str, 64); // Max length for number strings
            // Optionally validate that it's actually a valid number string
            _ = std.fmt.parseFloat(f64, str) catch return ValidationError.CustomDataValidationFailed;
        },
    }
}

// Optional: Add IP address validation helper
pub fn isValidIPAddress(ip: []const u8) bool {

    // Basic IPv4 validation
    var splits = std.mem.splitScalar(u8, ip, '.');
    var count: u8 = 0;

    while (splits.next()) |octet| {
        count += 1;
        if (count > 4) return false;

        if (octet.len > 3) return false;
        if (octet.len > 1 and octet[0] == '0') return false;

        const num = std.fmt.parseInt(u8, octet, 10) catch return false;
        if (num > 255) return false;
    }

    return count == 4;
}

// Optional: Add User-Agent validation helper
pub fn isValidUserAgent(ua: []const u8) bool {
    if (ua.len == 0 or ua.len > 512) return false;

    // Basic validation - ensure printable ASCII
    for (ua) |char| {
        if (!isPrintableAscii(char)) return false;
    }

    return true;
}

fn getClientIp(request: *jetzig.Request) []const u8 {
    // Try various headers that might contain the client IP
    if (request.headers.get("X-Forwarded-For")) |ip| {
        // X-Forwarded-For might contain multiple IPs; get the first one
        const comma_pos = std.mem.indexOf(u8, ip, ",");
        if (comma_pos) |pos| {
            return std.mem.trim(u8, ip[0..pos], " ");
        }
        return ip;
    }

    if (request.headers.get("X-Real-IP")) |ip| {
        return ip;
    }

    if (request.headers.get("CF-Connecting-IP")) |ip| {
        return ip;
    }

    // If no IP is found in headers, return a fallback value
    return "127.0.0.1";
}
