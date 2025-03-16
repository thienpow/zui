const std = @import("std");
const jetzig = @import("jetzig");
const security = @import("../security/security.zig");

/// Represents the available permissions in the system
pub const Permission = enum {
    // User management permissions
    view_users,
    create_user,
    update_user,
    delete_user,
    ban_user,
    unban_user,
    suspend_user,
    activate_user,
    deactivate_user,
    reset_user_password,

    // Role management permissions
    view_roles,
    create_role,
    update_role,
    delete_role,
    assign_role,
    remove_role,

    // Content permissions
    view_content,
    create_content,
    update_content,
    delete_content,
    moderate_content,

    // System permissions
    view_system_logs,
    view_audit_logs,
    manage_settings,
    manage_system,

    pub fn toString(self: Permission) []const u8 {
        return switch (self) {
            .view_users => "view_users",
            .create_user => "create_user",
            .update_user => "update_user",
            .delete_user => "delete_user",
            .ban_user => "ban_user",
            .unban_user => "unban_user",
            .suspend_user => "suspend_user",
            .activate_user => "activate_user",
            .deactivate_user => "deactivate_user",
            .reset_user_password => "reset_user_password",
            .view_roles => "view_roles",
            .create_role => "create_role",
            .update_role => "update_role",
            .delete_role => "delete_role",
            .assign_role => "assign_role",
            .remove_role => "remove_role",
            .view_content => "view_content",
            .create_content => "create_content",
            .update_content => "update_content",
            .delete_content => "delete_content",
            .moderate_content => "moderate_content",
            .view_system_logs => "view_system_logs",
            .view_audit_logs => "view_audit_logs",
            .manage_settings => "manage_settings",
            .manage_system => "manage_system",
        };
    }

    pub fn fromString(permission_str: []const u8) !Permission {
        inline for (std.meta.fields(Permission)) |field| {
            if (std.mem.eql(u8, field.name, permission_str)) {
                return @field(Permission, field.name);
            }
        }
        return error.InvalidPermission;
    }
};

/// Predefined user roles with associated permissions
pub const Role = struct {
    id: u64,
    name: []const u8,
    description: ?[]const u8,
    permissions: std.ArrayList(Permission),

    pub fn init(allocator: std.mem.Allocator, id: u64, name: []const u8, description: ?[]const u8) Role {
        return Role{
            .id = id,
            .name = name,
            .description = description,
            .permissions = std.ArrayList(Permission).init(allocator),
        };
    }

    pub fn deinit(self: *Role) void {
        self.permissions.deinit();
    }

    pub fn addPermission(self: *Role, permission: Permission) !void {
        // Check if permission already exists
        for (self.permissions.items) |existing| {
            if (existing == permission) {
                return; // Permission already exists, no need to add
            }
        }
        try self.permissions.append(permission);
    }

    pub fn removePermission(self: *Role, permission: Permission) void {
        for (self.permissions.items, 0..) |existing, i| {
            if (existing == permission) {
                _ = self.permissions.orderedRemove(i);
                return;
            }
        }
    }

    pub fn hasPermission(self: Role, permission: Permission) bool {
        for (self.permissions.items) |existing| {
            if (existing == permission) {
                return true;
            }
        }
        return false;
    }
};

pub const PermissionError = error{
    PermissionDenied,
    RoleNotFound,
    InvalidRole,
    InvalidPermission,
    DatabaseError,
};

pub const PermissionsManager = struct {
    allocator: std.mem.Allocator,
    db_pool: *jetzig.db.Pool,
    predefined_roles: std.StringHashMap(Role),

    pub fn init(allocator: std.mem.Allocator, db_pool: *jetzig.db.Pool) !PermissionsManager {
        var manager = PermissionsManager{
            .allocator = allocator,
            .db_pool = db_pool,
            .predefined_roles = std.StringHashMap(Role).init(allocator),
        };

        try manager.initializePredefinedRoles();
        return manager;
    }

    pub fn deinit(self: *PermissionsManager) void {
        var role_iterator = self.predefined_roles.valueIterator();
        while (role_iterator.next()) |role_ptr| {
            role_ptr.deinit();
        }
        self.predefined_roles.deinit();
    }

    fn initializePredefinedRoles(self: *PermissionsManager) !void {
        // Admin role - has all permissions
        var admin_role = Role.init(self.allocator, 1, "admin", "System administrator with full access");
        inline for (std.meta.fields(Permission)) |field| {
            try admin_role.addPermission(@field(Permission, field.name));
        }
        try self.predefined_roles.put("admin", admin_role);

        // Moderator role
        var moderator_role = Role.init(self.allocator, 2, "moderator", "Content moderator");
        try moderator_role.addPermission(.view_users);
        try moderator_role.addPermission(.ban_user);
        try moderator_role.addPermission(.unban_user);
        try moderator_role.addPermission(.suspend_user);
        try moderator_role.addPermission(.view_content);
        try moderator_role.addPermission(.update_content);
        try moderator_role.addPermission(.delete_content);
        try moderator_role.addPermission(.moderate_content);
        try moderator_role.addPermission(.view_audit_logs);
        try self.predefined_roles.put("moderator", moderator_role);

        // User role (regular user)
        var user_role = Role.init(self.allocator, 3, "user", "Regular user");
        try user_role.addPermission(.view_content);
        try user_role.addPermission(.create_content);
        try user_role.addPermission(.update_content); // Only their own content (enforced in handlers)
        try user_role.addPermission(.delete_content); // Only their own content (enforced in handlers)
        try self.predefined_roles.put("user", user_role);

        // Guest role
        var guest_role = Role.init(self.allocator, 4, "guest", "Unauthenticated user");
        try guest_role.addPermission(.view_content);
        try self.predefined_roles.put("guest", guest_role);
    }

    /// Check if a user has a specific permission
    pub fn userHasPermission(self: *PermissionsManager, request: *jetzig.Request, user_id: u64, permission: Permission) !bool {

        // Get user's roles from database
        const db = try request.db();
        const query =
            \\SELECT r.name FROM roles r
            \\JOIN user_roles ur ON r.id = ur.role_id
            \\WHERE ur.user_id = $1
        ;

        var roles = std.ArrayList([]const u8).init(self.allocator);
        defer roles.deinit();

        // Execute query to get user roles
        var result = try db.query(query, .{user_id});
        defer result.deinit();

        // Extract role names from query result
        while (try result.next()) |row| {
            const role_name = try row.get([]const u8, 0);
            try roles.append(role_name);
        }

        // Check if any of the user's roles has the required permission
        for (roles.items) |role_name| {
            if (self.predefined_roles.get(role_name)) |role| {
                if (role.hasPermission(permission)) {
                    return true;
                }
            } else {
                // Role not found in predefined roles, might be a custom role
                // Try to load it from database
                const role_query =
                    \\SELECT p.name FROM permissions p
                    \\JOIN role_permissions rp ON p.id = rp.permission_id
                    \\JOIN roles r ON rp.role_id = r.id
                    \\WHERE r.name = $1
                ;

                var perm_result = try db.query(role_query, .{role_name});
                defer perm_result.deinit();

                while (try perm_result.next()) |perm_row| {
                    const perm_name = try perm_row.get([]const u8, 0);
                    if (std.mem.eql(u8, perm_name, permission.toString())) {
                        return true;
                    }
                }
            }
        }

        return false;
    }

    /// Check if user has permission and throw error if not
    pub fn enforcePermission(self: *PermissionsManager, request: *jetzig.Request, user_id: u64, permission: Permission) !void {
        const has_permission = try self.userHasPermission(request, user_id, permission);
        if (!has_permission) {
            return PermissionError.PermissionDenied;
        }
    }

    /// Create a new role with specified permissions
    pub fn createRole(self: *PermissionsManager, request: *jetzig.Request, name: []const u8, description: ?[]const u8, permissions: []const Permission) !u64 {
        _ = self;
        const db = try request.db();

        // Start a transaction
        try db.exec("BEGIN");
        errdefer db.exec("ROLLBACK") catch {};

        // Insert role
        const role_result = try db.query(
            \\INSERT INTO roles (name, description)
            \\VALUES ($1, $2)
            \\RETURNING id
        , .{ name, description });
        defer role_result.deinit();

        const role_id = blk: {
            if (try role_result.next()) |row| {
                break :blk try row.get(u64, 0);
            } else {
                return PermissionError.DatabaseError;
            }
        };

        // Insert permissions for role
        for (permissions) |permission| {
            // Get permission ID from permission name
            const perm_query = try db.query(
                \\SELECT id FROM permissions WHERE name = $1
            , .{permission.toString()});
            defer perm_query.deinit();

            const permission_id = blk: {
                if (try perm_query.next()) |row| {
                    break :blk try row.get(u64, 0);
                } else {
                    // Permission doesn't exist in DB, create it
                    const insert_result = try db.query(
                        \\INSERT INTO permissions (name) VALUES ($1) RETURNING id
                    , .{permission.toString()});
                    defer insert_result.deinit();

                    if (try insert_result.next()) |insert_row| {
                        break :blk try insert_row.get(u64, 0);
                    } else {
                        return PermissionError.DatabaseError;
                    }
                }
            };

            // Link permission to role
            _ = try db.exec(
                \\INSERT INTO role_permissions (role_id, permission_id)
                \\VALUES ($1, $2)
            , .{ role_id, permission_id });
        }

        // Commit transaction
        try db.exec("COMMIT");

        return role_id;
    }

    /// Get all permissions for a specific role
    pub fn getRolePermissions(self: *PermissionsManager, request: *jetzig.Request, role_id: u64) !std.ArrayList(Permission) {
        const db = try request.db();

        var permissions = std.ArrayList(Permission).init(self.allocator);
        errdefer permissions.deinit();

        const query =
            \\SELECT p.name FROM permissions p
            \\JOIN role_permissions rp ON p.id = rp.permission_id
            \\WHERE rp.role_id = $1
        ;

        var result = try db.query(query, .{role_id});
        defer result.deinit();

        while (try result.next()) |row| {
            const perm_name = try row.get([]const u8, 0);
            const permission = try Permission.fromString(perm_name);
            try permissions.append(permission);
        }

        return permissions;
    }

    /// Update the permissions for a role
    pub fn updateRolePermissions(self: *PermissionsManager, request: *jetzig.Request, role_id: u64, permissions: []const Permission) !void {
        _ = self;
        const db = try request.db();

        // Start a transaction
        try db.exec("BEGIN");
        errdefer db.exec("ROLLBACK") catch {};

        // Delete existing permissions for the role
        _ = try db.exec("DELETE FROM role_permissions WHERE role_id = $1", .{role_id});

        // Insert new permissions
        for (permissions) |permission| {
            // Get permission ID from permission name
            const perm_query = try db.query(
                \\SELECT id FROM permissions WHERE name = $1
            , .{permission.toString()});
            defer perm_query.deinit();

            const permission_id = blk: {
                if (try perm_query.next()) |row| {
                    break :blk try row.get(u64, 0);
                } else {
                    // Permission doesn't exist in DB, create it
                    const insert_result = try db.query(
                        \\INSERT INTO permissions (name) VALUES ($1) RETURNING id
                    , .{permission.toString()});
                    defer insert_result.deinit();

                    if (try insert_result.next()) |insert_row| {
                        break :blk try insert_row.get(u64, 0);
                    } else {
                        return PermissionError.DatabaseError;
                    }
                }
            };

            // Link permission to role
            _ = try db.exec(
                \\INSERT INTO role_permissions (role_id, permission_id)
                \\VALUES ($1, $2)
            , .{ role_id, permission_id });
        }

        // Commit transaction
        try db.exec("COMMIT");
    }

    /// Delete a role and its permission associations
    pub fn deleteRole(self: *PermissionsManager, request: *jetzig.Request, role_id: u64) !void {
        _ = self;
        const db = try request.db();

        // Start a transaction
        try db.exec("BEGIN");
        errdefer db.exec("ROLLBACK") catch {};

        // First delete from user_roles to maintain referential integrity
        _ = try db.exec("DELETE FROM user_roles WHERE role_id = $1", .{role_id});

        // Then delete from role_permissions
        _ = try db.exec("DELETE FROM role_permissions WHERE role_id = $1", .{role_id});

        // Finally delete the role itself
        const result = try db.exec("DELETE FROM roles WHERE id = $1", .{role_id});

        if (result.rowCount() == 0) {
            return PermissionError.RoleNotFound;
        }

        // Commit transaction
        try db.exec("COMMIT");
    }

    /// Get all roles in the system
    pub fn getAllRoles(self: *PermissionsManager, request: *jetzig.Request) !std.ArrayList(Role) {
        const db = try request.db();

        var roles = std.ArrayList(Role).init(self.allocator);
        errdefer {
            for (roles.items) |*role| {
                role.deinit();
            }
            roles.deinit();
        }

        const query = "SELECT id, name, description FROM roles";
        var result = try db.query(query, .{});
        defer result.deinit();

        while (try result.next()) |row| {
            const id = try row.get(u64, 0);
            const name = try row.get([]const u8, 1);
            const description = try row.get(?[]const u8, 2);

            // Create role
            var role = Role.init(self.allocator, id, name, description);

            // Get permissions for this role
            const perms = try self.getRolePermissions(request, id);
            defer perms.deinit();

            // Add permissions to role
            for (perms.items) |perm| {
                try role.addPermission(perm);
            }

            try roles.append(role);
        }

        return roles;
    }

    /// Get all roles assigned to a user
    pub fn getUserRoles(self: *PermissionsManager, request: *jetzig.Request, user_id: u64) !std.ArrayList(Role) {
        const db = try request.db();

        var roles = std.ArrayList(Role).init(self.allocator);
        errdefer {
            for (roles.items) |*role| {
                role.deinit();
            }
            roles.deinit();
        }

        const query =
            \\SELECT r.id, r.name, r.description FROM roles r
            \\JOIN user_roles ur ON r.id = ur.role_id
            \\WHERE ur.user_id = $1
        ;

        var result = try db.query(query, .{user_id});
        defer result.deinit();

        while (try result.next()) |row| {
            const id = try row.get(u64, 0);
            const name = try row.get([]const u8, 1);
            const description = try row.get(?[]const u8, 2);

            // Create role
            var role = Role.init(self.allocator, id, name, description);

            // Get permissions for this role
            const perms = try self.getRolePermissions(request, id);
            defer perms.deinit();

            // Add permissions to role
            for (perms.items) |perm| {
                try role.addPermission(perm);
            }

            try roles.append(role);
        }

        return roles;
    }

    /// Check if a user has a specific role
    pub fn userHasRole(self: *PermissionsManager, request: *jetzig.Request, user_id: u64, role_name: []const u8) !bool {
        _ = self;
        const db = try request.db();

        const query =
            \\SELECT COUNT(*) FROM user_roles ur
            \\JOIN roles r ON ur.role_id = r.id
            \\WHERE ur.user_id = $1 AND r.name = $2
        ;

        var result = try db.query(query, .{ user_id, role_name });
        defer result.deinit();

        if (try result.next()) |row| {
            const count = try row.get(u64, 0);
            return count > 0;
        }

        return false;
    }

    /// Get all permissions associated with a user (from all roles)
    pub fn getUserPermissions(self: *PermissionsManager, request: *jetzig.Request, user_id: u64) !std.ArrayList(Permission) {
        const db = try request.db();

        var permissions = std.ArrayList(Permission).init(self.allocator);
        errdefer permissions.deinit();

        // Maintain a set of already added permissions to avoid duplicates
        var added_perms = std.StringHashMap(void).init(self.allocator);
        defer added_perms.deinit();

        const query =
            \\SELECT DISTINCT p.name FROM permissions p
            \\JOIN role_permissions rp ON p.id = rp.permission_id
            \\JOIN roles r ON rp.role_id = r.id
            \\JOIN user_roles ur ON r.id = ur.role_id
            \\WHERE ur.user_id = $1
        ;

        var result = try db.query(query, .{user_id});
        defer result.deinit();

        while (try result.next()) |row| {
            const perm_name = try row.get([]const u8, 0);

            // Check if we've already added this permission
            if (added_perms.contains(perm_name)) {
                continue;
            }

            // Add to our set of added permissions
            try added_perms.put(perm_name, {});

            // Add to our list of permissions
            const permission = try Permission.fromString(perm_name);
            try permissions.append(permission);
        }

        return permissions;
    }

    /// Creates middleware for route permission checking
    pub fn createPermissionMiddleware(self: *PermissionsManager, permission: Permission) jetzig.middleware.MiddlewareFn {
        return struct {
            fn middleware(request: *jetzig.Request) !void {
                // Get the user ID from the authenticated session
                const user_id = try request.session.get("user_id") orelse {
                    // No user ID in session, redirect to login
                    try request.redirect("/login?redirect=" ++ request.url.path);
                    return;
                };

                // Check permission
                const has_permission = try self.userHasPermission(request, user_id, permission);
                if (!has_permission) {
                    try request.status(.forbidden);
                    try request.renderJson(.{ .err = "Permission denied" });
                    return;
                }
            }
        }.middleware;
    }

    /// Creates middleware for role checking
    pub fn createRoleMiddleware(self: *PermissionsManager, role_name: []const u8) jetzig.middleware.MiddlewareFn {
        return struct {
            fn middleware(request: *jetzig.Request) !void {
                // Get the user ID from the authenticated session
                const user_id = try request.session.get("user_id") orelse {
                    // No user ID in session, redirect to login
                    try request.redirect("/login?redirect=" ++ request.url.path);
                    return;
                };

                // Check role
                const has_role = try self.userHasRole(request, user_id, role_name);
                if (!has_role) {
                    try request.status(.forbidden);
                    try request.renderJson(.{ .err = "Access denied" });
                    return;
                }
            }
        }.middleware;
    }

    /// Get a predefined role by name
    pub fn getPredefinedRole(self: *PermissionsManager, name: []const u8) ?Role {
        return self.predefined_roles.get(name);
    }

    /// Audit log for permission changes
    pub fn logPermissionChange(self: *PermissionsManager, request: *jetzig.Request, action: []const u8, details: anytype) !void {
        _ = self;
        const db = try request.db();

        const actor_id = try request.session.get([]const u8, "user_id") orelse "system";

        _ = try db.exec(
            \\INSERT INTO audit_logs (actor_id, action, details, created_at)
            \\VALUES ($1, $2, $3, NOW())
        , .{ actor_id, action, details });
    }
};

/// Schema for the permissions-related tables
pub fn createPermissionsTables(db: anytype) !void {
    // Permissions table
    try db.exec(
        \\CREATE TABLE IF NOT EXISTS permissions (
        \\    id SERIAL PRIMARY KEY,
        \\    name VARCHAR(100) UNIQUE NOT NULL,
        \\    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        \\)
    , .{});

    // Roles table
    try db.exec(
        \\CREATE TABLE IF NOT EXISTS roles (
        \\    id SERIAL PRIMARY KEY,
        \\    name VARCHAR(100) UNIQUE NOT NULL,
        \\    description TEXT,
        \\    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        \\    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        \\)
    , .{});

    // Role permissions junction table
    try db.exec(
        \\CREATE TABLE IF NOT EXISTS role_permissions (
        \\    role_id INTEGER REFERENCES roles(id),
        \\    permission_id INTEGER REFERENCES permissions(id),
        \\    PRIMARY KEY (role_id, permission_id)
        \\)
    , .{});

    // User roles junction table
    try db.exec(
        \\CREATE TABLE IF NOT EXISTS user_roles (
        \\    user_id INTEGER REFERENCES users(id),
        \\    role_id INTEGER REFERENCES roles(id),
        \\    PRIMARY KEY (user_id, role_id)
        \\)
    , .{});

    // Audit logs table for permissions
    try db.exec(
        \\CREATE TABLE IF NOT EXISTS audit_logs (
        \\    id SERIAL PRIMARY KEY,
        \\    actor_id VARCHAR(100) NOT NULL,
        \\    action VARCHAR(100) NOT NULL,
        \\    details JSONB,
        \\    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        \\)
    , .{});
}
