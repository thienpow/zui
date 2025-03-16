const std = @import("std");
const zmpl = @import("zmpl");
const security_types = @import("../security/types.zig");

/// User registration data received from input forms
pub const UserRegistrationData = struct {
    username: []const u8,
    email: []const u8,
    password: []const u8,
    password_confirm: []const u8,
    first_name: ?[]const u8 = null,
    last_name: ?[]const u8 = null,
    phone: ?[]const u8 = null,
    profile_picture: ?[]const u8 = null,
    bio: ?[]const u8 = null,
    date_of_birth: ?[]const u8 = null, // Could use a proper timestamp type
    gender: ?[]const u8 = null, // Validate against 'male', 'female', 'other'
    address: ?[]const u8 = null,
    city: ?[]const u8 = null,
    country: ?[]const u8 = null,
    postal_code: ?[]const u8 = null,
    role_ids: ?[]u64 = null,
    metadata: ?std.json.Value = null, // Optional; requires JSONB column
};

/// User update data for profile updates
pub const UserUpdateData = struct {
    username: ?[]const u8 = null,
    email: ?[]const u8 = null,
    first_name: ?[]const u8 = null,
    last_name: ?[]const u8 = null,
    phone: ?[]const u8 = null,
    organization: ?[]const u8 = null,
    title: ?[]const u8 = null,
    bio: ?[]const u8 = null,
    is_active: ?bool = null,
    metadata: ?std.json.Value = null,
};

/// Data used for administrative password resets
pub const AdminPasswordResetData = struct {
    user_id: u64,
    new_password: []const u8,
    force_password_change: bool = false,
    notify_user: bool = true,
};

/// Suspension data structure
pub const UserSuspensionData = struct {
    user_id: u64,
    reason: []const u8,
    suspended_until: i64, // Unix timestamp when suspension ends
    suspended_by: u64, // Admin user ID who did the suspension
};

/// Ban data structure
pub const UserBanData = struct {
    user_id: u64,
    reason: ?[]const u8,
    permanent: bool = true,
    banned_until: ?i64 = null, // Used for temporary bans
    banned_by: u64, // Admin user ID who did the banning
};

/// Role assignment data
pub const RoleAssignmentData = struct {
    user_id: u64,
    role_id: u64,
    assigned_by: u64,
    expiration: ?i64 = null, // Optional role expiration timestamp
};

/// Complete user profile data
pub const UserProfile = struct {
    id: u64,
    username: []const u8,
    email: []const u8,
    first_name: ?[]const u8,
    last_name: ?[]const u8,
    phone: ?[]const u8,
    organization: ?[]const u8,
    title: ?[]const u8,
    bio: ?[]const u8,
    avatar_url: ?[]const u8,
    is_active: bool,
    is_banned: bool,
    is_suspended: bool,
    created_at: i64,
    updated_at: i64,
    last_login_at: ?i64,
    last_ip: ?[]const u8,
    last_user_agent: ?[]const u8,
    roles: []Role,
    ban_data: ?UserBanData,
    suspension_data: ?UserSuspensionData,
    metadata: ?std.json.Value,

    // Computed properties
    full_name: ?[]const u8 = null, // Combined first and last name if both exist

    // Data-sensitive handling
    pub fn init(allocator: std.mem.Allocator) !UserProfile {
        return UserProfile{
            .id = 0,
            .username = try allocator.dupe(u8, ""),
            .email = try allocator.dupe(u8, ""),
            .first_name = null,
            .last_name = null,
            .phone = null,
            .organization = null,
            .title = null,
            .bio = null,
            .avatar_url = null,
            .is_active = false,
            .is_banned = false,
            .is_suspended = false,
            .created_at = 0,
            .updated_at = 0,
            .last_login_at = null,
            .last_ip = null,
            .last_user_agent = null,
            .roles = &[_]Role{},
            .ban_data = null,
            .suspension_data = null,
            .metadata = null,
        };
    }

    pub fn deinit(self: *UserProfile, allocator: std.mem.Allocator) void {
        allocator.free(self.username);
        allocator.free(self.email);
        if (self.first_name) |fname| allocator.free(fname);
        if (self.last_name) |lname| allocator.free(lname);
        if (self.phone) |p| allocator.free(p);
        if (self.organization) |org| allocator.free(org);
        if (self.title) |t| allocator.free(t);
        if (self.bio) |b| allocator.free(b);
        if (self.avatar_url) |url| allocator.free(url);
        if (self.last_ip) |ip| allocator.free(ip);
        if (self.last_user_agent) |ua| allocator.free(ua);
        if (self.full_name) |name| allocator.free(name);
        // Note: Roles and other complex structures should be freed separately
    }

    pub fn hasRole(self: *const UserProfile, role_name: []const u8) bool {
        for (self.roles) |role| {
            if (std.mem.eql(u8, role.name, role_name)) {
                return true;
            }
        }
        return false;
    }

    pub fn hasPermission(self: *const UserProfile, permission: []const u8) bool {
        for (self.roles) |role| {
            for (role.permissions) |perm| {
                if (std.mem.eql(u8, perm.name, permission)) {
                    return true;
                }
            }
        }
        return false;
    }

    pub fn computeFullName(self: *UserProfile, allocator: std.mem.Allocator) !void {
        if (self.first_name != null and self.last_name != null) {
            self.full_name = try std.fmt.allocPrint(allocator, "{s} {s}", .{ self.first_name.?, self.last_name.? });
        } else if (self.first_name != null) {
            self.full_name = try allocator.dupe(u8, self.first_name.?);
        } else if (self.last_name != null) {
            self.full_name = try allocator.dupe(u8, self.last_name.?);
        } else {
            self.full_name = null;
        }
    }
};

/// Role definition structure
pub const Role = struct {
    id: u64,
    name: []const u8,
    description: ?[]const u8 = null,
    permissions: []Permission,
    is_system_role: bool = false,
    created_at: i64,
    updated_at: i64,
};

/// Permission definition structure
pub const Permission = struct {
    id: u64,
    name: []const u8,
    description: ?[]const u8 = null,
    resource: []const u8, // E.g., "users", "articles", etc.
    action: []const u8, // E.g., "create", "read", "update", "delete"
    conditions: ?std.json.Value = null, // Optional conditions in JSON
};

/// User manager operation results
pub const UserOperationResult = struct {
    success: bool,
    user_id: ?u64 = null,
    err: ?UserManagerError = null,
    details: ?[]const u8 = null,

    pub fn init(_: std.mem.Allocator, success: bool) !UserOperationResult {
        return UserOperationResult{
            .success = success,
            .user_id = null,
            .err = null,
            .details = null,
        };
    }

    pub fn withUserId(self: UserOperationResult, id: u64) UserOperationResult {
        var result = self;
        result.user_id = id;
        return result;
    }

    pub fn withError(self: UserOperationResult, err: UserManagerError) UserOperationResult {
        var result = self;
        result.err = err;
        return result;
    }

    pub fn withDetails(self: UserOperationResult, allocator: std.mem.Allocator, details: []const u8) !UserOperationResult {
        var result = self;
        result.details = try allocator.dupe(u8, details);
        return result;
    }

    pub fn deinit(self: *UserOperationResult, allocator: std.mem.Allocator) void {
        if (self.details) |details| {
            allocator.free(details);
        }
    }
};

/// User manager error types
pub const UserManagerError = error{
    UserNotFound,
    EmailAlreadyExists,
    UsernameAlreadyExists,
    InvalidUserData,
    PasswordMismatch,
    WeakPassword,
    InsufficientPermissions,
    DatabaseError,
    InvalidRoleAssignment,
    SystemRoleModificationError,
    SelfModificationError,
    CannotBanAdminUser,
    ValidationError,
    UserAlreadyBanned,
    UserAlreadySuspended,
    UserNotActive,
    UserIsBanned,
    UserIsSuspended,
    InvalidSuspensionPeriod,
    RoleNotFound,
    ApiError,
    InternalError,
    ActionNotPermitted,
};

/// User search parameters
pub const UserSearchParams = struct {
    username: ?[]const u8 = null,
    email: ?[]const u8 = null,
    first_name: ?[]const u8 = null,
    last_name: ?[]const u8 = null,
    organization: ?[]const u8 = null,
    role_id: ?u64 = null,
    is_active: ?bool = null,
    is_banned: ?bool = null,
    is_suspended: ?bool = null,
    created_after: ?i64 = null,
    created_before: ?i64 = null,
    last_login_after: ?i64 = null,
    last_login_before: ?i64 = null,

    // Pagination
    page: usize = 1,
    per_page: usize = 20,

    // Sorting
    sort_by: []const u8 = "username",
    sort_order: []const u8 = "asc",
};

/// User search result
pub const UserSearchResult = struct {
    users: []UserProfile,
    total_count: usize,
    page: usize,
    per_page: usize,
    total_pages: usize,

    pub fn deinit(self: *UserSearchResult, allocator: std.mem.Allocator) void {
        for (self.users) |*user| {
            user.deinit(allocator);
        }
        allocator.free(self.users);
    }
};

/// User account status enum
pub const UserAccountStatus = enum {
    active,
    inactive,
    banned,
    suspended,
    pending_email_verification,
    password_reset_required,

    pub fn toString(self: UserAccountStatus) []const u8 {
        return switch (self) {
            .active => "active",
            .inactive => "inactive",
            .banned => "banned",
            .suspended => "suspended",
            .pending_email_verification => "pending_email_verification",
            .password_reset_required => "password_reset_required",
        };
    }

    pub fn fromString(status_str: []const u8) ?UserAccountStatus {
        if (std.mem.eql(u8, status_str, "active")) {
            return .active;
        } else if (std.mem.eql(u8, status_str, "inactive")) {
            return .inactive;
        } else if (std.mem.eql(u8, status_str, "banned")) {
            return .banned;
        } else if (std.mem.eql(u8, status_str, "suspended")) {
            return .suspended;
        } else if (std.mem.eql(u8, status_str, "pending_email_verification")) {
            return .pending_email_verification;
        } else if (std.mem.eql(u8, status_str, "password_reset_required")) {
            return .password_reset_required;
        } else {
            return null;
        }
    }
};

/// User audit log events specific to user management
pub const UserManagementEvent = enum {
    user_created,
    user_updated,
    user_deleted,
    user_banned,
    user_unbanned,
    user_suspended,
    user_unsuspended,
    user_activated,
    user_deactivated,
    password_changed,
    role_assigned,
    role_removed,
    user_export_requested,
    user_data_deleted,

    pub fn toString(self: UserManagementEvent) []const u8 {
        return switch (self) {
            .user_created => "user_created",
            .user_updated => "user_updated",
            .user_deleted => "user_deleted",
            .user_banned => "user_banned",
            .user_unbanned => "user_unbanned",
            .user_suspended => "user_suspended",
            .user_unsuspended => "user_unsuspended",
            .user_activated => "user_activated",
            .user_deactivated => "user_deactivated",
            .password_changed => "password_changed",
            .role_assigned => "role_assigned",
            .role_removed => "role_removed",
            .user_export_requested => "user_export_requested",
            .user_data_deleted => "user_data_deleted",
        };
    }

    pub fn getSeverity(self: UserManagementEvent) security_types.Severity {
        return switch (self) {
            .user_created => .info,
            .user_updated => .info,
            .user_deleted => .critical,
            .user_banned => .warning,
            .user_unbanned => .info,
            .user_suspended => .warning,
            .user_unsuspended => .info,
            .user_activated => .info,
            .user_deactivated => .info,
            .password_changed => .info,
            .role_assigned => .info,
            .role_removed => .info,
            .user_export_requested => .warning,
            .user_data_deleted => .critical,
        };
    }
};
