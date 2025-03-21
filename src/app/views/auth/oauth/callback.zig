const std = @import("std");
const jetzig = @import("jetzig");

pub fn index(request: *jetzig.Request) !jetzig.View {
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
    //try request.server.logger.DEBUG("[view:auth:oauth:callback] code {s}, {s}", .{ code, state });

    // Error handling: check for error param from OAuth provider
    const error_msg = params.get("error");
    if (error_msg != null) {
        return request.fail(.unauthorized);
    }

    // Process OAuth callback with string parameters
    const auth_result = try request.global.security.oauth.handleOAuthCallback(provider_id, code, state, request);
    if (!auth_result.authenticated) {
        return request.fail(.unauthorized);
    }

    // Get the default redirect URL from config
    const default_redirect_url = request.global.security.oauth.config.default_redirect;
    const data = try request.data(.object);
    try data.put("default_redirect_url", default_redirect_url);

    // Redirect to dashboard or return_to URL
    return request.render(.created); // must use this render method and use js to redirect in order to have the state_cookie stored and available for checking.
    // return request.redirect(default_redirect_url, .found); setting redirect header won't work, it will redirect before the state_cookie is stored.
}
