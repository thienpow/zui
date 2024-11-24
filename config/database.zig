pub const database = .{
    // Null adapter fails when a database call is invoked.
    .development = .{
        .adapter = .postgresql,
        .hostname = "localhost",
        .port = 5432,
        .username = "postgres",
        .password = "postgres",
        .database = "zui",
    },
    .testing = .{
        .adapter = .postgresql,
        .hostname = "localhost",
        .port = 5432,
        .username = "postgres",
        .password = "postgres",
        .database = "zui",
    },
    .production = .{
        .adapter = .postgresql,
        .hostname = "localhost",
        .port = 5432,
        .username = "postgres",
        .password = "postgres",
        .database = "zui",
    },
};
