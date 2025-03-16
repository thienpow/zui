const std = @import("std");
const jetzig = @import("jetzig");
const zmpl = @import("zmpl");

const UserManagerError = @import("../../user/types.zig").UserManagerError;

pub const layout = "auth";

pub fn index(request: *jetzig.Request) !jetzig.View {
    return request.render(.ok);
}
pub fn post(request: *jetzig.Request) !jetzig.View {
    const Params = struct {
        username: []const u8,
        email: []const u8,
        password: []const u8,
        password_confirm: []const u8,
        // first_name: ?[]const u8 = null,
        // last_name: ?[]const u8 = null,
        // phone: ?[]const u8 = null,
        // organization: ?[]const u8 = null,
        // role_ids: ?[]const u8 = null,
        // metadata: ?zmpl.Data.Value = null,
    };

    std.log.debug("Starting user registration POST request", .{});

    const params = try request.expectParams(Params) orelse {
        std.log.debug("Failed to parse request params, returning unprocessable_entity", .{});
        return request.render(.unprocessable_entity); //422
    };

    std.log.debug("Parsed params: username={s}, email={s}", .{ params.username, params.email });

    // Basic validation before passing to UserManager
    if (!std.mem.eql(u8, params.password, params.password_confirm)) {
        std.log.debug("Password and password_confirm do not match", .{});
        return request.render(.bad_request);
    }

    std.log.debug("Password validation passed", .{});

    // Parse role_ids from string to ?[]u64
    // var role_ids: ?[]u64 = null;
    // if (params.role_ids) |roles_str| {
    //     var list = std.ArrayList(u64).init(request.allocator);
    //     defer list.deinit();

    //     var it = std.mem.splitScalar(u8, roles_str, ',');
    //     while (it.next()) |role_str| {
    //         const role_id = std.fmt.parseInt(u64, std.mem.trim(u8, role_str, " "), 10) catch {
    //             return request.render(.bad_request);
    //         };
    //         try list.append(role_id);
    //     }
    //     role_ids = try list.toOwnedSlice();
    // }

    // Convert zmpl.Data.Value to std.json.Value
    // var metadata: ?std.json.Value = null;
    // if (params.metadata) |zmpl_value| {
    //     const json_string = try zmpl_value.toString();
    //     // Parse the JSON string into a Parsed struct
    //     const parsed = try std.json.parseFromSlice(std.json.Value, request.allocator, json_string, .{ .allocate = .alloc_always });
    //     // Extract the value; the arena will be deinitialized later
    //     metadata = parsed.value;
    // }

    std.log.debug("Calling registerUser with username={s}, email={s}", .{ params.username, params.email });

    _ = request.global.user_manager.registerUser(request, .{
        .username = params.username,
        .email = params.email,
        .password = params.password,
        .password_confirm = params.password_confirm,
        // .first_name = params.first_name,
        // .last_name = params.last_name,
        // .phone = params.phone,
        // .role_ids = role_ids,
        // .metadata = metadata,
    }) catch |err| {
        //if (role_ids) |r| request.allocator.free(r);
        //if (metadata) |m| std.json.parseFree(std.json.Value, m, request.allocator);
        switch (err) {
            UserManagerError.EmailAlreadyExists => {
                std.log.debug("Email already exists: {s}", .{params.email});
                return request.render(.conflict);
            },
            UserManagerError.UsernameAlreadyExists => {
                std.log.debug("Username already exists: {s}", .{params.username});
                return request.render(.conflict);
            },
            UserManagerError.InvalidUserData => {
                std.log.debug("Invalid user data provided", .{});
                return request.render(.bad_request);
            },
            else => {
                std.log.debug("Unexpected error during registration: {}", .{err});
                return request.render(.internal_server_error);
            },
        }
    };

    // Free allocated resources after success
    //if (role_ids) |r| request.allocator.free(r);
    //if (metadata) |m| std.json.parseFree(std.json.Value, m, request.allocator);

    std.log.debug("User registration successful for username={s}", .{params.username});

    return request.render(.created);
}
