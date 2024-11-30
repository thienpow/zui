const std = @import("std");
const jetzig = @import("jetzig");
const jetquery = @import("jetzig").jetquery;

pub const layout = "auth";

pub fn index(request: *jetzig.Request, _: *jetzig.Data) !jetzig.View {
    return request.render(.ok);
}

pub fn post(request: *jetzig.Request) !jetzig.View {
    // Define expected parameters
    const Params = struct {
        email: []const u8,
        password: []const u8,
    };

    // Validate and extract parameters
    const params = try request.expectParams(Params) orelse {
        return request.fail(.unprocessable_entity);
    };

    // Attempt login with comprehensive error handling
    var auth = request.global.auth;
    auth.login(request, params.email, params.password) catch |err| {
        // Detailed error responses
        return switch (err) {
            error.NotFound => request.fail(.not_found), //User not found
            error.Unauthorized => request.fail(.unauthorized), //Invalid credentials"
            error.DatabaseError => request.fail(.internal_server_error), //Database error
            error.TokenGenerationError => request.fail(.internal_server_error), //Failed to generate session
            error.RedisError => request.fail(.internal_server_error), //Session storage error
            else => request.fail(.internal_server_error), //Authentication failed
        };
    };

    // If login succeeds, return created response
    return request.render(.created);
}
