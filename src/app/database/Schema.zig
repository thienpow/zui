const jetquery = @import("jetzig").jetquery;

pub const PasswordReset = jetquery.Model(
    @This(),
    "password_resets",
    struct {
        id: i64,
        user_id: i64,
        token: []const u8,
        expires_at: jetquery.DateTime,
        created_at: ?jetquery.DateTime,
    },
    .{
        .relations = .{
            .user = jetquery.belongsTo(.User, .{}),
        },
    },
);

pub const Permission = jetquery.Model(
    @This(),
    "permissions",
    struct {
        id: i64,
        name: []const u8,
        description: ?[]const u8,
        created_at: ?jetquery.DateTime,
        updated_at: ?jetquery.DateTime,
    },
    .{
        .relations = .{
            .role_permissions = jetquery.hasMany(.RolePermission, .{}),
        },
    },
);

pub const RolePermission = jetquery.Model(
    @This(),
    "role_permissions",
    struct {
        role_id: i64,
        permission_id: i64,
        created_at: ?jetquery.DateTime,
    },
    .{
        .relations = .{
            .role = jetquery.belongsTo(.Role, .{}),
            .permission = jetquery.belongsTo(.Permission, .{}),
        },
    },
);

pub const Role = jetquery.Model(
    @This(),
    "roles",
    struct {
        id: i64,
        name: []const u8,
        description: ?[]const u8,
        created_at: ?jetquery.DateTime,
        updated_at: ?jetquery.DateTime,
    },
    .{
        .relations = .{
            .user_roles = jetquery.hasMany(.UserRole, .{}),
            .role_permissions = jetquery.hasMany(.RolePermission, .{}),
        },
    },
);

pub const SocialLogin = jetquery.Model(
    @This(),
    "social_logins",
    struct {
        id: i64,
        user_id: i64,
        provider: []const u8,
        provider_user_id: []const u8,
        provider_token: ?[]const u8,
        provider_refresh_token: ?[]const u8,
        token_expires_at: ?jetquery.DateTime,
        created_at: ?jetquery.DateTime,
        updated_at: ?jetquery.DateTime,
    },
    .{
        .relations = .{
            .user = jetquery.belongsTo(.User, .{}),
        },
    },
);

pub const UserActivityLog = jetquery.Model(
    @This(),
    "user_activity_logs",
    struct {
        id: i64,
        user_id: ?i64,
        activity_type: []const u8,
        description: ?[]const u8,
        ip_address: ?[]const u8,
        user_agent: ?[]const u8,
        created_at: ?jetquery.DateTime,
    },
    .{
        .relations = .{
            .user = jetquery.belongsTo(.User, .{}),
        },
    },
);

pub const UserRole = jetquery.Model(
    @This(),
    "user_roles",
    struct {
        user_id: i64,
        role_id: i64,
        created_at: ?jetquery.DateTime,
    },
    .{
        .relations = .{
            .user = jetquery.belongsTo(.User, .{}),
            .role = jetquery.belongsTo(.Role, .{}),
        },
    },
);

pub const UserSession = jetquery.Model(
    @This(),
    "user_sessions",
    struct {
        id: i64,
        user_id: i64,
        token: []const u8,
        ip_address: ?[]const u8,
        user_agent: ?[]const u8,
        last_activity: ?jetquery.DateTime,
        expires_at: ?jetquery.DateTime,
        created_at: ?jetquery.DateTime,
    },
    .{
        .relations = .{
            .user = jetquery.belongsTo(.User, .{}),
        },
    },
);

pub const User = jetquery.Model(
    @This(),
    "users",
    struct {
        id: i64,
        username: []const u8,
        email: []const u8,
        password_hash: []const u8,
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
    .{
        .relations = .{
            .social_logins = jetquery.hasMany(.SocialLogin, .{}),
            .user_roles = jetquery.hasMany(.UserRole, .{}),
            .user_sessions = jetquery.hasMany(.UserSession, .{}),
            .password_resets = jetquery.hasMany(.PasswordReset, .{}),
            .user_activity_logs = jetquery.hasMany(.UserActivityLog, .{}),
        },
    },
);
