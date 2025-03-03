const std = @import("std");
const jetzig = @import("jetzig");
const builtin = @import("builtin");

/// Gets the client IP address from a request with proper header handling
/// and fallbacks. This centralizes IP extraction logic for the application.
pub fn getClientIp(request: *jetzig.Request) []const u8 {
    // Try X-Forwarded-For first (standard for proxies)
    if (request.headers.get("X-Forwarded-For")) |forwarded_for| {
        // X-Forwarded-For can contain multiple IPs - take the first one
        const comma_pos = std.mem.indexOf(u8, forwarded_for, ",");
        if (comma_pos) |pos| {
            return std.mem.trim(u8, forwarded_for[0..pos], " ");
        }
        return forwarded_for;
    }

    // Try other common headers
    if (request.headers.get("X-Real-IP")) |real_ip| {
        return real_ip;
    }

    if (request.headers.get("CF-Connecting-IP")) |cloudflare_ip| {
        return cloudflare_ip;
    }

    // Local development fallback
    if (builtin.mode == .Debug) {
        return "127.0.0.1"; // Local dev fallback
    }

    // Last resort
    return "unknown";
}

/// Validates if a string is a valid IPv4 or IPv6 address
pub fn isValidIpAddress(ip: []const u8) bool {
    // Basic validation - you could make this more robust
    if (std.mem.eql(u8, ip, "unknown") or std.mem.eql(u8, ip, "127.0.0.1") or
        std.mem.eql(u8, ip, "localhost"))
    {
        return true;
    }

    // IPv4 check (simple version)
    var parts: u8 = 0;
    var digits: u8 = 0;

    for (ip) |c| {
        if (c == '.') {
            parts += 1;
            digits = 0;
            continue;
        }

        if (c < '0' or c > '9') return false;
        digits += 1;
        if (digits > 3) return false;
    }

    return parts == 3;
}
