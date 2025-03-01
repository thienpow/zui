const std = @import("std");

pub const REDIS_PROTOCOL = struct {
    pub const CRLF = "\r\n";
    pub const SIMPLE_STRING = '+';
    pub const ERROR = '-';
    pub const INTEGER = ':';
    pub const BULK_STRING = '$';
    pub const ARRAY = '*';
};

pub const RedisError = error{
    ConnectionFailed,
    InvalidArgument,
    SetFailed,
    PoolExhausted,
    Timeout,
    DisconnectedClient,
    NetworkError,
    AuthenticationFailed,
    InvalidProtocol,
    CommandFailed,
    ParseError,
    ReconnectFailed,
    ConnectionRefused,
    SocketNotConnected,
    InvalidResponse,
    OutOfMemory,
    InvalidFormat,
    Overflow,
    EndOfStream,
    SystemResources,
    InputOutput,
    NoAvailableConnections,
};

pub const RedisClientConfig = struct {
    host: []const u8 = "localhost",
    port: u16 = 6379,
    min_connections: usize = 3,
    max_connections: usize = 50,
    timeout_ms: u64 = 5000,
    idle_timeout_ms: i64 = 30000,
    read_timeout_ms: i64 = 5000,
    password: ?[]const u8 = null,
    database: ?u32 = null,
    max_pipeline_commands: usize = 1000,
    cleanup_interval_ms: i64 = 60000,
};

pub const ResponseType = enum {
    SimpleString,
    Error,
    Integer,
    BulkString,
    Array,
};
