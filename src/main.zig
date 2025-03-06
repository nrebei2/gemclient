const std = @import("std");
const gemini = @import("gemini.zig");

const rl = @import("raylib");
const cl = @import("zclay");
const renderer = @import("raylib_render_clay.zig");
const parser = @import("gemtext_parser.zig");

const light_grey: cl.Color = .{ 175, 185, 180, 255 };
const nice_grey: cl.Color = .{ 54, 57, 62, 255 };
const dark_grey: cl.Color = .{ 35, 35, 36, 255 };
const red: cl.Color = .{ 168, 66, 28, 255 };
const orange: cl.Color = .{ 225, 138, 50, 255 };
const white: cl.Color = .{ 250, 250, 255, 255 };
const green: cl.Color = .{ 80, 200, 120, 255 };
const purple: cl.Color = .{ 114, 137, 218, 255 };

const blue: cl.Color = .{ 100, 149, 237, 255 };
const light_blue: cl.Color = .{ 96, 130, 182, 255 };


const charset =
    " !\"#$%&'()*+,-—./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~■¦█";

var hover_str: ?[]const u8 = null;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const min_memory_size: u32 = cl.minMemorySize();
    const memory = try allocator.alloc(u8, min_memory_size);
    defer allocator.free(memory);

    const url = "gemini://carcosa.net";
    const result = gemini.fetch(allocator, url);

    var response: std.ArrayList(u8) = undefined;
    defer response.deinit();
    if (result catch null) |r| {
        response = r.response_storage;
    } else {
        response = std.ArrayList(u8).init(allocator);
        try std.fmt.format(response.writer(), "Could not fetch {s}!", .{url});
    }

    std.log.debug("{s}", .{response.items});

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

    const codepoints = try rl.loadCodepoints(charset);
    defer rl.unloadCodepoints(codepoints);
    loadFont(@embedFile("resources/Arial Unicode MS/arial unicode ms bold.otf"), 0, 24, codepoints);
    loadFont(@embedFile("resources/SFNSMono.ttf"), 1, 24, codepoints);

    var mouse_down_on_scrollbar = false;
    var scroll_bar_data: struct { click_origin: cl.Vector2, position_origin: cl.Vector2 } = undefined;
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

                if (new_scroll_bar_offset < 0 or new_scroll_bar_offset + cl.getElementData(cl.getElementId("ScrollBar")).bounding_box.height > scrollData.scroll_container_dimensions.h) {} else {
                    scrollData.scroll_position.y = new_scroll_y;
                }
            }
        }

        var gp = parser.GemtextParser.new(response.items);
        var render_commands = createLayout(&gp, mouse_down_on_scrollbar);
        rl.beginDrawing();
        renderer.clayRaylibRender(&render_commands, allocator);
        rl.endDrawing();
    }
}

fn createLayout(content: *parser.GemtextParser, mouse_down_on_scrollbar: bool) cl.ClayArray(cl.RenderCommand) {
    cl.beginLayout();
    cl.UI()(.{ .id = .ID("MainContent"), .layout = .{ .direction = .top_to_bottom, .sizing = .grow, .padding = .all(32), .child_gap = 10 }, .background_color = nice_grey, .scroll = .{ .vertical = true } })({
        while (content.next()) |line| {
            switch (line) {
                .text => |t| cl.text(t, .{ .font_size = 25, .color = white }),
                .list => |l| {
                    cl.UI()(.{ .id = .ID(l), .layout = .{ .padding = .{ .left = 20 } } })({
                        cl.text("■", .{
                            .color = orange,
                            .letter_spacing = 6,
                            .font_size = 30,
                        });
                        cl.text(l, .{ .color = green, .font_size = 25 });
                    });
                },
                .quote => |q| {
                    cl.UI()(.{ .id = .ID(q), .background_color = dark_grey, .corner_radius = cl.CornerRadius.all(4), .layout = .{ .sizing = cl.Sizing{ .h = .fit, .w = .grow } } })({
                        cl.text("█", .{ .color = light_grey, .letter_spacing = 6, .font_size = 30 });
                        cl.text(q, .{ .color = white, .font_size = 25 });
                    });
                },
                .heading => |h| {
                    cl.text(h.content, .{ .color = switch (h.level) {
                        .normal => purple,
                        .sub => green,
                        .sub_sub => orange,
                    }, .font_size = switch (h.level) {
                        .normal => 40,
                        .sub => 35,
                        .sub_sub => 32,
                    } });
                },
                .link => |l| {
                    cl.UI()(.{ .id = .ID(l.url), .border = if (cl.hovered()) .{} else .{ .color = blue, .width = .{ .bottom = 2 } } })({
                        cl.onHover({}, onLinkHover);
                        cl.text(l.desc orelse l.url, .{ .color = if (cl.hovered()) light_blue else blue, .font_size = 25 });
                    });
                },
                .preformat => |pf| {
                    cl.UI()(.{ .background_color = .{ 40, 43, 48, 255 }, .corner_radius = cl.CornerRadius.all(2), .border = .{ .color = dark_grey, .width = cl.BorderWidth.outside(2) } })({
                        cl.UI()(.{ .layout = .{ .padding = .{ .left = 15, .right = 40 } } })({
                            cl.text(pf, .{ .color = white, .font_size = 20, .font_id = 1 });
                        });
                    });
                },
            }
        }
    });

    const scrollData = cl.getScrollContainerData(cl.getElementId("MainContent"));
    if (scrollData.found) {
        cl.UI()(.{
            .id = .ID("ScrollBar"),
            .floating = cl.FloatingElementConfig{ .attach_to = .to_element_with_id, .parentId = cl.getElementId("MainContent").id, .zIndex = 1, .offset = .{ .x = 0, .y = -(scrollData.scroll_position.y / scrollData.content_dimensions.h) * scrollData.scroll_container_dimensions.h }, .attach_points = .{ .element = .right_top, .parent = .right_top } },
        })({
            cl.UI()(.{ .id = .ID("ScrollBarButton"), .layout = cl.LayoutConfig{ .sizing = .{ .w = .fixed(12), .h = .fixed((scrollData.scroll_container_dimensions.h / scrollData.content_dimensions.h) * scrollData.scroll_container_dimensions.h) } }, .background_color = if (mouse_down_on_scrollbar) .{ 220, 220, 220, 255 } else (if (cl.hovered()) .{ 130, 130, 130, 255 } else .{ 90, 90, 90, 255 }), .corner_radius = cl.CornerRadius.all(6) })({});
        });
    }

    if (hover_str) |s| {
        cl.UI()(.{
            .id = .ID("AddressTo"),
            .floating = cl.FloatingElementConfig{ .attach_to = .to_element_with_id, .parentId = cl.getElementId("MainContent").id, .zIndex = 1, .attach_points = .{ .element = .left_bottom, .parent = .left_bottom }}, .background_color = .{ 100, 100, 100, 255 }, .corner_radius = .{.top_left = 1, .top_right = 1, .bottom_right = 1, .bottom_left = 10}, .border = .{ .color = light_grey, .width = cl.BorderWidth.outside(1) } 
        })({
            cl.UI()(.{.layout = .{ .padding = .xy(2, 8) }})({
                cl.text(s, .{.color = white});
            });
        });
    }
    

    return cl.endLayout();
}

fn loadFont(file_data: ?[]const u8, font_id: u16, font_size: i32, codepoints: ?[]i32) void {
    renderer.raylib_fonts[font_id] = rl.loadFontFromMemory(".otf", file_data, font_size * 2, codepoints);
    rl.setTextureFilter(renderer.raylib_fonts[font_id].?.texture, .bilinear);
}

fn loadImage(comptime path: [:0]const u8) rl.Texture2D {
    const texture = rl.loadTextureFromImage(rl.loadImageFromMemory(@ptrCast(std.fs.path.extension(path)), @embedFile(path)));
    rl.setTextureFilter(texture, .bilinear);
    return texture;
}

fn onLinkHover(element_id: cl.ElementId, pointer_data: cl.PointerData, _: void) void {
    hover_str = element_id.string_id.chars[0..@intCast(element_id.string_id.length)];

    if (pointer_data.state == .released_this_frame) {
        // std.log.debug("Clicked {s}", .{});
    }
}
