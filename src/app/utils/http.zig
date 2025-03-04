const std = @import("std");

/// URL encodes a string according to RFC 3986
pub fn urlEncode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    // Estimate size (worst case: each char becomes %XX)
    const max_size = input.len * 3;
    const output = try allocator.alloc(u8, max_size);

    var i: usize = 0;
    var o: usize = 0;

    while (i < input.len) {
        const c = input[i];

        // These characters don't need encoding according to RFC 3986
        if ((c >= 'A' and c <= 'Z') or
            (c >= 'a' and c <= 'z') or
            (c >= '0' and c <= '9') or
            c == '-' or c == '_' or c == '.' or c == '~')
        {
            output[o] = c;
            o += 1;
        } else {
            // URL encode as %XX
            output[o] = '%';
            o += 1;
            const hex = "0123456789ABCDEF";
            output[o] = hex[c >> 4];
            o += 1;
            output[o] = hex[c & 0x0F];
            o += 1;
        }

        i += 1;
    }

    // Resize to actual length
    return allocator.realloc(output, o);
}
