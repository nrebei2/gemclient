const std = @import("std");
const gemini = @import("gemini.zig");
const style = @import("style.zig");

const rl = @import("raylib");
const cl = @import("zclay");
const renderer = @import("raylib_render_clay.zig");
const app = @import("app.zig");

const charset =
    " !\"#$%&'()*+,-—./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~■¦█";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const min_memory_size: u32 = cl.minMemorySize();
    const memory = try allocator.alloc(u8, min_memory_size);
    defer allocator.free(memory);

    const arena: cl.Arena = cl.createArenaWithCapacityAndMemory(memory);
    _ = cl.initialize(arena, .{ .h = 720, .w = 1280 }, .{});
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
    loadFont(@embedFile("resources/Arial Unicode MS/arial unicode ms bold.otf"), 0, 24, codepoints);
    loadFont(@embedFile("resources/SFNSMono.ttf"), 1, 24, codepoints);

    const back_button_texture = loadImage("resources/go-back.png");
    const style_options: style = .{.back_button = .{.texture = back_button_texture}, .forward_button = .{ .texture = back_button_texture, .flip_vertically = true }};

    const url = "gemini://geminiprotocol.net/";
    var a = try app.init(allocator, url, style_options);
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

fn loadImage(comptime path: [:0]const u8) rl.Texture2D {
    const texture = rl.loadTextureFromImage(rl.loadImageFromMemory(@ptrCast(std.fs.path.extension(path)), @embedFile(path)) catch unreachable) catch unreachable;
    rl.setTextureFilter(texture, .bilinear);
    return texture;
}
