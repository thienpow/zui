const jetzig = @import("jetzig");

pub fn applySecurityHeaders(response: *jetzig.Response) void {
    response.headers.append("Strict-Transport-Security", "max-age=31536000; includeSubDomains") catch {};
    response.headers.append("X-Content-Type-Options", "nosniff") catch {};
    response.headers.append("X-Frame-Options", "DENY") catch {};
    response.headers.append("Content-Security-Policy", "default-src 'self'") catch {};
    response.headers.append("X-XSS-Protection", "1; mode=block") catch {};
    response.headers.append("Referrer-Policy", "strict-origin-when-cross-origin") catch {};
    response.headers.append("Permissions-Policy", "geolocation=(), microphone=()") catch {};
}
