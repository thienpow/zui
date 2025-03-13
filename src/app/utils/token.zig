const std = @import("std");

pub fn generateSecureToken(allocator: std.mem.Allocator) ![]u8 {
    var random_bytes: [48]u8 = undefined;
    std.crypto.random.bytes(&random_bytes);
    const encoded_len = std.base64.url_safe_no_pad.Encoder.calcSize(random_bytes.len);
    const encoded = try allocator.alloc(u8, encoded_len);
    errdefer allocator.free(encoded);
    const result = std.base64.url_safe_no_pad.Encoder.encode(encoded, &random_bytes);
    return try allocator.dupe(u8, result);
}
