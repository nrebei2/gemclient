const std = @import("std");
const gemini = @import("gemini.zig");
const style = @import("style.zig");

const rl = @import("raylib");
const cl = @import("zclay");
const renderer = @import("raylib_render_clay.zig");
const app = @import("app.zig");

const charset =
    " !\"#$%&'()*+,-–—‒−./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~■→’ʼ″";

fn error_handler_function(error_data: cl.ErrorData) callconv(.c) void {
    std.debug.print("Clay Error: {s}\n", .{error_data.error_text.chars[0..@intCast(error_data.error_text.length)]});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    cl.setMaxMeasureTextCacheWordCount(65536);
    const min_memory_size: u32 = cl.minMemorySize();
    std.debug.print("mms: {d}\n", .{min_memory_size});
    const memory = try allocator.alloc(u8, min_memory_size);
    defer allocator.free(memory);

    const arena: cl.Arena = cl.createArenaWithCapacityAndMemory(memory);
    _ = cl.initialize(arena, .{ .h = 720, .w = 1280 }, .{.error_handler_function = &error_handler_function});
    cl.setMeasureTextFunction({}, renderer.measureText);

    rl.setConfigFlags(.{
        .msaa_4x_hint = true,
        .window_resizable = true,
    });
    rl.initWindow(1280, 720, "Gemini Client");
    rl.setWindowMinSize(300, 100);
    rl.setTargetFPS(120);

    const codepoints = try rl.loadCodepoints(charset);
    defer rl.unloadCodepoints(codepoints);
    loadFont(@embedFile("resources/Roboto-Regular.ttf"), 0, 24, codepoints);
    loadFont(@embedFile("resources/SFNSMono.ttf"), 1, 24, codepoints);
    loadFont(@embedFile("resources/RobotoMono-Medium.ttf"), 2, 24, codepoints);

    var style_options = style.init(allocator);
    defer style_options.deinit();

    const starting_url = style_options.config().general.start_url;
    var a = try app.init(allocator, starting_url, style_options);
    defer a.deinit();
    
    while (!rl.windowShouldClose()) {
        const mouse_pos = rl.getMousePosition();
        const cl_mouse_pos: cl.Vector2 = .{ .x = mouse_pos.x, .y = mouse_pos.y };

        cl.setPointerState(cl_mouse_pos, rl.isMouseButtonDown(.left));

        const scroll_delta = rl.getMouseWheelMoveV().multiply(.{ .x = 2, .y = 2 });
        cl.updateScrollContainers(
            false,
            .{ .x = scroll_delta.x, .y = scroll_delta.y },
            rl.getFrameTime(),
        );

        cl.setLayoutDimensions(.{
            .w = @floatFromInt(rl.getScreenWidth()),
            .h = @floatFromInt(rl.getScreenHeight()),
        });

        a.update(cl_mouse_pos);
    }
}

fn loadFont(file_data: ?[]const u8, font_id: u16, font_size: i32, codepoints: ?[]i32) void {
    renderer.raylib_fonts[font_id] = rl.loadFontFromMemory(".otf", file_data, font_size * 2, codepoints) catch return;
    rl.setTextureFilter(renderer.raylib_fonts[font_id].?.texture, .bilinear);
}

