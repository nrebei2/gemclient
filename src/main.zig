const std = @import("std");
const gemini = @import("gemini.zig");

const rl = @import("raylib");
const cl = @import("zclay");
const renderer = @import("raylib_render_clay.zig");
const parser = @import("gemtext_parser.zig");

const light_grey: cl.Color = .{ 224, 215, 210, 255 };
const red: cl.Color = .{ 168, 66, 28, 255 };
const orange: cl.Color = .{ 225, 138, 50, 255 };
const white: cl.Color = .{ 250, 250, 255, 255 };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const min_memory_size: u32 = cl.minMemorySize();
    const memory = try allocator.alloc(u8, min_memory_size);
    defer allocator.free(memory);

    const url = "gemini://geminiprotocol.net/";
    const result = gemini.fetch(allocator, url);

    var response: std.ArrayList(u8) = undefined;
    defer response.deinit();
    if (result catch null) |r| {
        response = r.response_storage;
    } else {
        response = std.ArrayList(u8).init(allocator);
        try std.fmt.format(response.writer(), "Could not fetch {s}!", .{url});
    }

    const arena: cl.Arena = cl.createArenaWithCapacityAndMemory(memory);
    _ = cl.initialize(arena, .{ .h = 1000, .w = 1000 }, .{});
    cl.setMeasureTextFunction({}, renderer.measureText);

    rl.setConfigFlags(.{
        .msaa_4x_hint = true,
        .window_resizable = true,
    });
    rl.initWindow(1000, 1000, "Gemini Client");
    rl.setWindowMinSize(300, 100);
    rl.setTargetFPS(120);

    loadFont(@embedFile("resources/Roboto-Regular.ttf"), 0, 24);

    var mouse_down_on_scrollbar = false;
    var scroll_bar_data: struct{click_origin: cl.Vector2, position_origin: cl.Vector2} = undefined;
    while (!rl.windowShouldClose()) {
        const mouse_pos = rl.getMousePosition();
        const cl_mouse_pos: cl.Vector2 = .{ .x = mouse_pos.x, .y = mouse_pos.y };

        cl.setPointerState(cl_mouse_pos, rl.isMouseButtonDown(.left));

        const scroll_delta = rl.getMouseWheelMoveV().multiply(.{ .x = 6, .y = 6 });
        cl.updateScrollContainers(
            false,
            .{ .x = scroll_delta.x, .y = scroll_delta.y },
            rl.getFrameTime(),
        );

        cl.setLayoutDimensions(.{
            .w = @floatFromInt(rl.getScreenWidth()),
            .h = @floatFromInt(rl.getScreenHeight()),
        });


        const scrollData = cl.getScrollContainerData(cl.getElementId("MainContent"));
        if (rl.isMouseButtonDown(.left) and cl.pointerOver(cl.ElementId.ID("ScrollBar")) and !mouse_down_on_scrollbar) {
            mouse_down_on_scrollbar = true;
            scroll_bar_data.click_origin = cl_mouse_pos;
            scroll_bar_data.position_origin = scrollData.scroll_position.*;
        }

        if (!rl.isMouseButtonDown(.left)) {
            mouse_down_on_scrollbar = false;
        }

        if (mouse_down_on_scrollbar) {
            if (scrollData.content_dimensions.h > 0 and scrollData.config.vertical) {
                const new_scroll_y = scroll_bar_data.position_origin.y + (scroll_bar_data.click_origin.y - mouse_pos.y) * 
                (scrollData.content_dimensions.h / scrollData.scroll_container_dimensions.h);

                const new_scroll_bar_offset = -(new_scroll_y / scrollData.content_dimensions.h) * scrollData.scroll_container_dimensions.h;

                if (new_scroll_bar_offset < 0 or new_scroll_bar_offset + cl.getElementData(cl.getElementId("ScrollBar")).bounding_box.height > scrollData.scroll_container_dimensions.h) {
                } else {
                    scrollData.scroll_position.y = new_scroll_y;
                }

            }
        }

        var p = parser.GemtextParser.new(response.items);
        var render_commands = createLayout(&p, mouse_down_on_scrollbar);
        rl.beginDrawing();
        renderer.clayRaylibRender(&render_commands, allocator);
        rl.endDrawing();
    }
}

fn createLayout(content: *parser.GemtextParser, mouse_down_on_scrollbar: bool) cl.ClayArray(cl.RenderCommand) {
    cl.beginLayout();
    cl.UI()(.{ .id = .ID("MainContent"), .layout = .{ .direction = .top_to_bottom, .sizing = .grow, .padding = .all(16), .child_gap = 16 }, .background_color = white, .scroll = .{ .vertical = true } })({

        while (content.next()) |line| {
            switch (line) {
                .text => |t| cl.text(t, .{}),  
                else => {}
            }
        }
    });

    const scrollData = cl.getScrollContainerData(cl.getElementId("MainContent"));
    if (scrollData.found) {
        cl.UI()(.{
            .id = .ID("ScrollBar"),
            .floating = cl.FloatingElementConfig{ .attach_to = .to_element_with_id, .parentId = cl.getElementId("MainContent").id, .zIndex = 1, .offset = .{ .x = 0, .y = -(scrollData.scroll_position.y / scrollData.content_dimensions.h) * scrollData.scroll_container_dimensions.h }, .attach_points = .{ .element = .right_top, .parent = .right_top } },
        })({
            cl.UI()(.{ .id = .ID("ScrollBarButton"), .layout = cl.LayoutConfig{ .sizing = .{ .w = .fixed(12), .h = .fixed((scrollData.scroll_container_dimensions.h / scrollData.content_dimensions.h) * scrollData.scroll_container_dimensions.h) } }, .background_color = if (mouse_down_on_scrollbar) red else (if (cl.pointerOver(cl.ElementId.ID("ScrollBar"))) light_grey else orange), .corner_radius = cl.CornerRadius.all(6) })({});
        });
    }

    return cl.endLayout();
}

fn loadFont(file_data: ?[]const u8, font_id: u16, font_size: i32) void {
    renderer.raylib_fonts[font_id] = rl.loadFontFromMemory(".ttf", file_data, font_size * 2, null);
    rl.setTextureFilter(renderer.raylib_fonts[font_id].?.texture, .bilinear);
}

fn loadImage(comptime path: [:0]const u8) rl.Texture2D {
    const texture = rl.loadTextureFromImage(rl.loadImageFromMemory(@ptrCast(std.fs.path.extension(path)), @embedFile(path)));
    rl.setTextureFilter(texture, .bilinear);
    return texture;
}
