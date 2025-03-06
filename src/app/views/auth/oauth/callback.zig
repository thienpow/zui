const std = @import("std");
const jetzig = @import("jetzig");

pub fn index(request: *jetzig.Request, _: *jetzig.Data) !jetzig.View {
    return request.render(.ok);
}

pub fn get(id: []const u8, request: *jetzig.Request) !jetzig.View {
    _ = id; // Ignore the ID parameter since we don't need it

    // Extract provider ID from path
    const provider_id = request.path.resource_id;

    // Get query parameters manually
    const params = try request.params();

    // Extract required parameters and convert to strings
    const code = (params.get("code").?.string).value;
    const state = (params.get("state").?.string).value;
    const return_to_value = params.get("return_to");
    const return_to = if (return_to_value) |value| value.string.value else null;

    // Error handling: check for error param from OAuth provider
    const error_msg = params.get("error");
    if (error_msg != null) {
        return request.fail(.unauthorized);
    }

    // Process OAuth callback with string parameters
    const auth_result = try request.global.security.handleOAuthCallback(provider_id, code, state, request);
    if (!auth_result.authenticated) {
        return request.fail(.unauthorized);
    }

    // Redirect to dashboard or return_to URL
    const redirect_url = return_to orelse "/admin/dashboard";
    return request.redirect(redirect_url, .found);
}
