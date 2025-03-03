const std = @import("std");

pub const Status = enum(u16) {
    input = 10,
    sensitive_input = 11,
    success = 20,
    temp_redirect = 30,
    perm_redirect = 31,
    temp_fail = 40,
    server_unavailable = 41,
    cgi_error = 42,
    proxy_error = 43,
    slow_down = 44,
    perm_fail = 50,
    not_found = 51,
    gone = 52,
    proxy_request_refused = 53,
    bad_request = 54,
    auth = 60,

    pub fn from_array(array: *const [2]u8) !Status {
        return switch (int16(array)) {
            int16("10") => Status.input,
            int16("11") => Status.sensitive_input,
            int16("20") => Status.success,
            int16("30") => Status.temp_redirect,
            int16("31") => Status.perm_redirect,
            int16("40") => Status.temp_fail,
            int16("41") => Status.server_unavailable,
            int16("42") => Status.cgi_error,
            int16("43") => Status.proxy_error,
            int16("44") => Status.slow_down,
            int16("50") => Status.perm_fail,
            int16("51") => Status.not_found,
            int16("52") => Status.gone,
            int16("53") => Status.proxy_request_refused,
            int16("54") => Status.bad_request,
            int16("60") => Status.auth,
            else => error.bad_status,
        };
    }

    inline fn int16(array: *const [2]u8) u16 {
        return @bitCast(array.*);
    }
};

pub const FetchResult = struct {
    status: Status,

    /// The ArrayList will contain
    /// - input: prompt
    /// - success: mimetype CRLF body
    /// - redirect: URI-reference
    /// - tempfail: errormsg
    /// - permfail: errormsg
    /// - auth: errormsg 
    response_storage: std.ArrayList(u8),
};

pub fn fetch(allocator: std.mem.Allocator, url: []const u8) !FetchResult {
    const uri = try std.Uri.parse(url);
    const host = (uri.host orelse return error.invalid_url).percent_encoded;

    const stream = try std.net.tcpConnectToHost(allocator, host, uri.port orelse 1965);
    defer stream.close();

    // it seems most servers are self signed, so will not use OS certificates
    // var bundle = std.crypto.Certificate.Bundle{};
    // try bundle.rescan(allocator);

    var client = try std.crypto.tls.Client.init(stream, .{
        .host = .{ .explicit = host },
        .ca = .self_signed
    });

    try client.writeAll(stream, url);
    try client.writeAll(stream, "\r\n");

    var header_buf: [3]u8 = undefined;
    const header_read = try client.readAll(stream, &header_buf);

    if (header_read != 3) {
        return error.bad_response;
    }

    const status: Status = try Status.from_array(header_buf[0..2]);

    const response_buf = try allocator.alloc(u8, 4096);
    defer allocator.free(response_buf);

    var response_storage = std.ArrayList(u8).init(allocator);
    errdefer response_storage.deinit();

    while (client.readAll(stream, response_buf) catch null) |response_read| {
        try response_storage.writer().writeAll(response_buf[0..response_read]);

        if (response_read < 4096) {
            break;
        }
    }

    return FetchResult{ .status = status, .response_storage = response_storage };
}
