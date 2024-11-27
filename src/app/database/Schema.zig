const jetquery = @import("jetzig").jetquery;

pub const PasswordReset = jetquery.Model(
    @This(),
    "password_resets",
    struct {
        id: i32,
        user_id: i32,
        token: []const u8,
        expires_at: jetquery.DateTime,
        created_at: ?jetquery.DateTime,
    },
    .{},
);

pub const Permission = jetquery.Model(
    @This(),
    "permissions",
    struct {
        id: i32,
        name: []const u8,
        description: ?[]const u8,
        created_at: ?jetquery.DateTime,
        updated_at: ?jetquery.DateTime,
    },
    .{},
);

pub const RolePermission = jetquery.Model(
    @This(),
    "role_permissions",
    struct {
        role_id: i32,
        permission_id: i32,
        created_at: ?jetquery.DateTime,
    },
    .{},
);

pub const Role = jetquery.Model(
    @This(),
    "roles",
    struct {
        id: i32,
        name: []const u8,
        description: ?[]const u8,
        created_at: ?jetquery.DateTime,
        updated_at: ?jetquery.DateTime,
    },
    .{},
);

pub const SocialLogin = jetquery.Model(
    @This(),
    "social_logins",
    struct {
        id: i32,
        user_id: i32,
        provider: []const u8,
        provider_user_id: []const u8,
        provider_token: ?[]const u8,
        provider_refresh_token: ?[]const u8,
        token_expires_at: ?jetquery.DateTime,
        created_at: ?jetquery.DateTime,
        updated_at: ?jetquery.DateTime,
    },
    .{},
);

pub const UserActivityLog = jetquery.Model(
    @This(),
    "user_activity_logs",
    struct {
        id: i32,
        user_id: ?i32,
        activity_type: []const u8,
        description: ?[]const u8,
        ip_address: ?[]const u8,
        user_agent: ?[]const u8,
        created_at: ?jetquery.DateTime,
    },
    .{},
);

pub const UserRole = jetquery.Model(
    @This(),
    "user_roles",
    struct {
        user_id: i32,
        role_id: i32,
        created_at: ?jetquery.DateTime,
    },
    .{},
);

pub const UserSession = jetquery.Model(
    @This(),
    "user_sessions",
    struct {
        id: i32,
        user_id: i32,
        token: []const u8,
        ip_address: ?[]const u8,
        user_agent: ?[]const u8,
        last_activity: ?jetquery.DateTime,
        expires_at: ?jetquery.DateTime,
        created_at: ?jetquery.DateTime,
    },
    .{},
);

pub const User = jetquery.Model(
    @This(),
    "users",
    struct {
        id: i32,
        username: ?[]const u8,
        email: []const u8,
        password_hash: ?[]const u8,
        first_name: ?[]const u8,
        last_name: ?[]const u8,
        phone: ?[]const u8,
        profile_picture: ?[]const u8,
        bio: ?[]const u8,
        date_of_birth: ?jetquery.DateTime,
        gender: ?[]const u8,
        address: ?[]const u8,
        city: ?[]const u8,
        country: ?[]const u8,
        postal_code: ?[]const u8,
        last_login_at: ?jetquery.DateTime,
        email_verified_at: ?jetquery.DateTime,
        phone_verified_at: ?jetquery.DateTime,
        is_active: ?bool,
        is_banned: ?bool,
        ban_reason: ?[]const u8,
        account_type: ?[]const u8,
        created_at: ?jetquery.DateTime,
        updated_at: ?jetquery.DateTime,
        deleted_at: ?jetquery.DateTime,
    },
    .{},
);
