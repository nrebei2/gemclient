const std = @import("std");
const gemini = @import("gemini.zig");

const clay = @cImport({
    // @cDefine("CLAY_IMPLEMENTATION", {});
    // @cInclude("clay.h");
    // @cInclude("clay_renderer_raylib.c");

    @cInclude("app.c");
});

pub fn main() !void {
    _ = clay.run();

    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer std.debug.assert(gpa.deinit() == .ok);
    // const allocator = gpa.allocator();

    // const url = "gemini://carcosa.net";
    // const result = gemini.fetch(allocator, url);

    // if (result catch null) |r| {
    //     defer r.response_storage.deinit();
    //     std.debug.print("{s}", .{r.response_storage.items});
    // } else {
    //     std.debug.print("Could not fetch {s}!", .{url});
    // }
}
