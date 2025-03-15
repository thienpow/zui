@zig {
    if (zmpl.getT(.string, "dark")) |dark|{
        if (std.mem.eql(u8, dark, "checked")) {
            @partial libs/styles/themes/default_dark
        } else {
            @partial libs/styles/themes/default
        }
    }
}
