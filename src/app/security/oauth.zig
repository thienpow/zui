const std = @import("std");

const jetzig = @import("jetzig");
const http = std.http;
const Header = http.Header;
const http_utils = @import("../utils/http.zig");
const config = @import("config.zig");
const types = @import("types.zig");
const ip_utils = @import("../utils/ip.zig");
const cookie_utils = @import("../utils/cookie.zig");

const Security = @import("security.zig").Security;
const AuthResult = @import("types.zig").AuthResult;
const User = @import("types.zig").User;

pub const OAuthError = error{
    ProviderNotFound,
    InvalidState,
    TokenRequestFailed,
    UserInfoRequestFailed,
    InvalidResponse,
    HttpError,
    JsonParsingError,
};

pub const OAuthToken = struct {
    access_token: []const u8,
    refresh_token: ?[]const u8 = null,
    token_type: []const u8,
    expires_in: ?u32 = null,
};

pub const OAuthUserInfo = struct {
    id: []const u8,
    email: ?[]const u8 = null,
    name: ?[]const u8 = null,
    picture: ?[]const u8 = null,
    provider_data: std.json.Value,
};

pub const OAuthProvider = struct {
    allocator: std.mem.Allocator,
    config: config.OAuthProviderConfig,

    pub fn init(allocator: std.mem.Allocator, provider_config: config.OAuthProviderConfig) OAuthProvider {
        return .{
            .allocator = allocator,
            .config = provider_config,
        };
    }

    // Generate authorization URL with state parameter
    pub fn getAuthorizationUrl(self: *const OAuthProvider, state: []const u8) ![]const u8 {
        return try std.fmt.allocPrint(self.allocator, "{s}?client_id={s}&redirect_uri={s}&response_type=code&scope={s}&state={s}", .{
            self.config.auth_url,
            self.config.client_id,
            try http_utils.urlEncode(self.allocator, self.config.redirect_uri),
            try http_utils.urlEncode(self.allocator, self.config.scope),
            state,
        });
    }

    // Exchange code for token
    pub fn exchangeCodeForToken(self: *const OAuthProvider, code: []const u8) !OAuthToken {
        // Create form data for the token request
        const form_data = try std.fmt.allocPrint(self.allocator, "code={s}&client_id={s}&client_secret={s}&redirect_uri={s}&grant_type=authorization_code", .{
            try http_utils.urlEncode(self.allocator, code),
            try http_utils.urlEncode(self.allocator, self.config.client_id),
            try http_utils.urlEncode(self.allocator, self.config.client_secret),
            try http_utils.urlEncode(self.allocator, self.config.redirect_uri),
        });
        defer self.allocator.free(form_data);

        // Setup headers
        var headers = std.ArrayList(Header).init(self.allocator);
        defer headers.deinit();

        try headers.append(.{ .name = "Content-Type", .value = "application/x-www-form-urlencoded" });

        // For GitHub and some others that prefer Accept header for JSON
        if (self.config.provider == .github) {
            try headers.append(.{ .name = "Accept", .value = "application/json" });
        }

        // Send the request
        const response = try self.httpRequest("POST", self.config.token_url, headers.items, form_data);
        defer self.allocator.free(response);

        // Parse the JSON response
        var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response, .{ .allocate = .alloc_always });
        defer parsed.deinit();

        const json = parsed.value;

        // Check for error in response
        if (json.object.get("error")) |error_obj| {
            const error_msg = if (error_obj.object.get("message")) |msg|
                msg.string
            else if (error_obj.object.get("error_description")) |desc|
                desc.string
            else
                "Unknown OAuth error";

            std.log.scoped(.auth).debug("OAuth token error: {s}", .{error_msg});
            return OAuthError.TokenRequestFailed;
        }

        // Extract token values
        const access_token = json.object.get("access_token") orelse
            return OAuthError.InvalidResponse;

        const token_type = json.object.get("token_type") orelse
            return OAuthError.InvalidResponse;

        var refresh_token: ?[]const u8 = null;
        if (json.object.get("refresh_token")) |rt| {
            refresh_token = try self.allocator.dupe(u8, rt.string);
        }

        var expires_in: ?u32 = null;
        if (json.object.get("expires_in")) |exp| {
            expires_in = @intCast(exp.integer);
        }

        return OAuthToken{
            .access_token = try self.allocator.dupe(u8, access_token.string),
            .refresh_token = refresh_token,
            .token_type = try self.allocator.dupe(u8, token_type.string),
            .expires_in = expires_in,
        };
    }

    // Get user info with access token
    pub fn getUserInfo(self: *const OAuthProvider, token: OAuthToken) !OAuthUserInfo {
        var headers = std.ArrayList(Header).init(self.allocator);
        defer headers.deinit();

        // Set Authorization header
        const auth_header = try std.fmt.allocPrint(self.allocator, "{s} {s}", .{ token.token_type, token.access_token });
        defer self.allocator.free(auth_header);

        try headers.append(.{
            .name = "Authorization",
            .value = auth_header,
        });

        // For GitHub and some others that prefer Accept header for JSON
        if (self.config.provider == .github) {
            try headers.append(.{ .name = "Accept", .value = "application/json" });
        }

        // Send the request
        const response = try self.httpRequest("GET", self.config.userinfo_url, headers.items, null);
        defer self.allocator.free(response);

        // Parse the JSON response
        var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, response, .{ .allocate = .alloc_always });
        defer parsed.deinit();

        const json = parsed.value;

        // Provider-specific field mapping
        var id_field: []const u8 = "id";
        const email_field: []const u8 = "email";
        var name_field: []const u8 = "name";
        var picture_field: []const u8 = "picture";

        if (self.config.provider == .github) {
            // GitHub uses 'login' for username
            name_field = "login";
            // GitHub needs separate email API call in some cases
            // This is simplified - in practice you might need additional API calls
        } else if (self.config.provider == .facebook) {
            // Facebook profile picture is nested
            picture_field = "picture.data.url";
        } else if (self.config.provider == .google) {
            // Google uses sub for ID
            id_field = "sub";
        }

        // Extract ID (required)
        const id = if (self.getNestedValue(json, id_field)) |id_val|
            if (id_val == .string)
                id_val.string
            else if (id_val == .integer)
                try std.fmt.allocPrint(self.allocator, "{d}", .{id_val.integer})
            else
                return OAuthError.InvalidResponse
        else
            return OAuthError.InvalidResponse;

        // Extract optional fields
        var email: ?[]const u8 = null;
        if (self.getNestedValue(json, email_field)) |email_val| {
            if (email_val == .string) email = try self.allocator.dupe(u8, email_val.string);
        }

        var name: ?[]const u8 = null;
        if (self.getNestedValue(json, name_field)) |name_val| {
            if (name_val == .string) name = try self.allocator.dupe(u8, name_val.string);
        }

        var picture: ?[]const u8 = null;
        if (self.getNestedValue(json, picture_field)) |pic_val| {
            if (pic_val == .string) picture = try self.allocator.dupe(u8, pic_val.string);
        }

        return OAuthUserInfo{
            .id = try self.allocator.dupe(u8, id),
            .email = email,
            .name = name,
            .picture = picture,
            .provider_data = try cloneJsonValue(self.allocator, json),
        };
    }

    fn cloneJsonValue(allocator: std.mem.Allocator, value: std.json.Value) !std.json.Value {
        switch (value) {
            .null => return .null,
            .bool => |b| return .{ .bool = b },
            .integer => |i| return .{ .integer = i },
            .float => |f| return .{ .float = f },
            .number_string => |s| return .{ .number_string = try allocator.dupe(u8, s) },
            .string => |s| return .{ .string = try allocator.dupe(u8, s) },
            .array => |arr| {
                var new_array = std.json.Array.init(allocator);
                try new_array.ensureTotalCapacity(arr.items.len);

                for (arr.items) |item| {
                    try new_array.append(try cloneJsonValue(allocator, item));
                }

                return .{ .array = new_array };
            },
            .object => |obj| {
                var new_obj = std.json.ObjectMap.init(allocator);

                var it = obj.iterator();
                while (it.next()) |entry| {
                    try new_obj.put(try allocator.dupe(u8, entry.key_ptr.*), try cloneJsonValue(allocator, entry.value_ptr.*));
                }

                return .{ .object = new_obj };
            },
        }
    }

    // Helper to get potentially nested JSON values using dot notation
    fn getNestedValue(self: *const OAuthProvider, json: std.json.Value, path: []const u8) ?std.json.Value {
        _ = self;
        var current = json;
        var path_parts = std.mem.splitScalar(u8, path, '.');

        while (path_parts.next()) |part| {
            if (current != .object) return null;

            if (current.object.get(part)) |next| {
                current = next;
            } else {
                return null;
            }
        }

        return current;
    }

    fn httpRequest(self: *const OAuthProvider, method: []const u8, url: []const u8, headers: []const Header, body: ?[]const u8) ![]const u8 {
        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();

        // Parse the URL
        const uri = try std.Uri.parse(url);

        // Create a buffer for server response headers
        var server_header_buffer: [8192]u8 = undefined;

        // Buffer for response data
        var response_buffer = std.ArrayList(u8).init(self.allocator);
        defer response_buffer.deinit();

        // We need to handle different HTTP methods separately since the enum is comptime-only
        if (std.mem.eql(u8, method, "GET")) {
            var request = try client.open(.GET, uri, .{
                .server_header_buffer = &server_header_buffer,
                .extra_headers = headers,
            });
            defer request.deinit();
            try request.send();
            try request.finish();
            try request.wait();

            if (@intFromEnum(request.response.status) < 200 or @intFromEnum(request.response.status) >= 300) {
                std.log.scoped(.auth).debug("HTTP error: status {d}", .{@intFromEnum(request.response.status)});
                return OAuthError.HttpError;
            }

            try request.reader().readAllArrayList(&response_buffer, 10 * 1024 * 1024);
        } else if (std.mem.eql(u8, method, "POST")) {
            var request = try client.open(.POST, uri, .{
                .server_header_buffer = &server_header_buffer,
                .extra_headers = headers,
            });
            defer request.deinit();

            if (body) |b| {
                request.transfer_encoding = .{ .content_length = b.len };
            }

            try request.send();

            if (body) |b| {
                try request.writeAll(b);
            }

            try request.finish();
            try request.wait();

            if (@intFromEnum(request.response.status) < 200 or @intFromEnum(request.response.status) >= 300) {
                std.log.scoped(.auth).debug("HTTP error: status {d}", .{@intFromEnum(request.response.status)});
                return OAuthError.HttpError;
            }

            try request.reader().readAllArrayList(&response_buffer, 10 * 1024 * 1024);
        } else if (std.mem.eql(u8, method, "PUT")) {
            var request = try client.open(.PUT, uri, .{
                .server_header_buffer = &server_header_buffer,
                .extra_headers = headers,
            });
            defer request.deinit();

            if (body) |b| {
                request.transfer_encoding = .{ .content_length = b.len };
            }

            try request.send();

            if (body) |b| {
                try request.writeAll(b);
            }

            try request.finish();
            try request.wait();

            if (@intFromEnum(request.response.status) < 200 or @intFromEnum(request.response.status) >= 300) {
                std.log.scoped(.auth).debug("HTTP error: status {d}", .{@intFromEnum(request.response.status)});
                return OAuthError.HttpError;
            }

            try request.reader().readAllArrayList(&response_buffer, 10 * 1024 * 1024);
        } else if (std.mem.eql(u8, method, "DELETE")) {
            var request = try client.open(.DELETE, uri, .{
                .server_header_buffer = &server_header_buffer,
                .extra_headers = headers,
            });
            defer request.deinit();

            if (body) |b| {
                request.transfer_encoding = .{ .content_length = b.len };
            }

            try request.send();

            if (body) |b| {
                try request.writeAll(b);
            }

            try request.finish();
            try request.wait();

            if (@intFromEnum(request.response.status) < 200 or @intFromEnum(request.response.status) >= 300) {
                std.log.scoped(.auth).debug("HTTP error: status {d}", .{@intFromEnum(request.response.status)});
                return OAuthError.HttpError;
            }

            try request.reader().readAllArrayList(&response_buffer, 10 * 1024 * 1024);
        } else if (std.mem.eql(u8, method, "PATCH")) {
            var request = try client.open(.PATCH, uri, .{
                .server_header_buffer = &server_header_buffer,
                .extra_headers = headers,
            });
            defer request.deinit();

            if (body) |b| {
                request.transfer_encoding = .{ .content_length = b.len };
            }

            try request.send();

            if (body) |b| {
                try request.writeAll(b);
            }

            try request.finish();
            try request.wait();

            if (@intFromEnum(request.response.status) < 200 or @intFromEnum(request.response.status) >= 300) {
                std.log.scoped(.auth).debug("HTTP error: status {d}", .{@intFromEnum(request.response.status)});
                return OAuthError.HttpError;
            }

            try request.reader().readAllArrayList(&response_buffer, 10 * 1024 * 1024);
        } else {
            // Default to GET for unknown methods
            var request = try client.open(.GET, uri, .{
                .server_header_buffer = &server_header_buffer,
                .extra_headers = headers,
            });
            defer request.deinit();
            try request.send();
            try request.finish();
            try request.wait();

            if (@intFromEnum(request.response.status) < 200 or @intFromEnum(request.response.status) >= 300) {
                std.log.scoped(.auth).debug("HTTP error: status {d}", .{@intFromEnum(request.response.status)});
                return OAuthError.HttpError;
            }

            try request.reader().readAllArrayList(&response_buffer, 10 * 1024 * 1024);
        }

        return response_buffer.toOwnedSlice();
    }
};

pub const OAuthManager = struct {
    allocator: std.mem.Allocator,
    config: config.OAuthConfig,

    // Find provider by ID
    pub fn getProvider(self: *const OAuthManager, provider_id: []const u8) !OAuthProvider {
        for (self.config.providers) |provider_config| {
            const id_to_compare = if (provider_config.provider == .custom)
                provider_config.custom_provider_id orelse provider_config.name
            else
                @tagName(provider_config.provider);

            if (std.mem.eql(u8, id_to_compare, provider_id) and provider_config.enabled) {
                return OAuthProvider.init(self.allocator, provider_config);
            }
        }
        return OAuthError.ProviderNotFound;
    }

    // Generate a random state for CSRF protection
    pub fn generateState(self: *const OAuthManager) ![]const u8 {
        var random_bytes: [16]u8 = undefined;
        std.crypto.random.bytes(&random_bytes);
        return try std.fmt.allocPrint(self.allocator, "{x}", .{std.fmt.fmtSliceHexLower(&random_bytes)});
    }

    pub fn getOAuthLoginUrl(self: *OAuthManager, provider_id: []const u8, request: *jetzig.Request) ![]const u8 {
        var provider = try self.getProvider(provider_id);
        const state = try self.generateState();

        // Store state in a cookie
        try cookie_utils.set_oauth_cookie(request, state);

        return try provider.getAuthorizationUrl(state);
    }

    pub fn handleOAuthCallback(
        self: *OAuthManager,
        provider_id: []const u8,
        code: []const u8,
        state: []const u8,
        request: *jetzig.Request,
    ) !AuthResult {
        _ = state; // Validate state here if needed

        var provider = try self.getProvider(provider_id);
        const token = try provider.exchangeCodeForToken(code);
        const user_info = try provider.getUserInfo(token);

        const user_id = try self.findOrCreateOAuthUser(provider_id, user_info);

        const client_ip = ip_utils.getClientIp(request);
        const user_agent = request.headers.get("User-Agent") orelse "unknown";
        const device_id = null;

        const user = User{
            .id = @intCast(user_id),
            .email = user_info.email orelse "unknown@example.com",
            .is_active = true,
            .is_banned = false,
            .last_ip = client_ip,
            .last_user_agent = user_agent,
            .device_id = device_id,
            .last_login_at = std.time.timestamp(),
        };

        const session = try request.global.security.session.create(user, request);
        std.log.scoped(.auth).debug("[oauth.handleOAuthCallback] Created session with token: '{s}' for user_id: {}", .{ session.token, user_id });

        return AuthResult{
            .authenticated = true,
            .user_id = user_id,
            .strategy_used = .oauth,
        };
    }

    fn findOrCreateOAuthUser(self: *OAuthManager, provider_id: []const u8, user_info: OAuthUserInfo) !u64 {
        _ = self;
        _ = provider_id;
        _ = user_info;
        return 1; // Implement DB logic here
    }
};
