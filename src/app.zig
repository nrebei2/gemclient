const std = @import("std");
const Self = @This();
const gemini = @import("gemini.zig");
const cl = @import("zclay");
const rl = @import("raylib");
const parser = @import("gemtext_parser.zig");
const renderer = @import("raylib_render_clay.zig");

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

cur_url: []const u8, // owned
cur_response: std.ArrayList(u8),
cur_status: gemini.Status = .success,
hovered_str: ?[]const u8 = null,
allocator: std.mem.Allocator,

mouse_down_on_scrollbar: bool = false,
scroll_bar_data: struct { click_origin: cl.Vector2, position_origin: cl.Vector2 } = undefined,

pub fn init(allocator: std.mem.Allocator, starting_url: []const u8) !Self {
    const cur_url = try allocator.dupe(u8, starting_url);
    errdefer allocator.free(cur_url);

    var self = Self {.allocator = allocator, .cur_response = std.ArrayList(u8).init(allocator), .cur_url = cur_url };
    try self.update_response();
    return self;
}

fn update_response(self: *Self) !void {
    self.cur_response.clearRetainingCapacity();
    if (gemini.fetch(self.allocator, self.cur_url, &self.cur_response) catch null) |status| {
        self.cur_status = status;
    } else {
        self.cur_status = .not_found;
        try std.fmt.format(self.cur_response.writer(), "Could not fetch {s}", .{self.cur_url});
    }

    // std.log.debug("{s}", .{self.cur_response.items});
}

fn set_url(self: *Self, url: []const u8, url_type: enum{relative, absolute}) !void {
    const new_url = 
        if (url_type == .absolute) try self.allocator.dupe(u8, url) 
        else 
            if (self.cur_url[self.cur_url.len - 1] == '/') try std.fmt.allocPrint(self.allocator, "{s}{s}", .{self.cur_url, url})
            else try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{self.cur_url, url});
    self.allocator.free(self.cur_url);
    self.cur_url = new_url;
    self.hovered_str = null;

    try self.update_response();

    const scrollData = cl.getScrollContainerData(cl.getElementId("MainContent"));
    scrollData.scroll_position.y = 0;
}

pub fn update(self: *Self, mouse_pos: cl.Vector2) void {
    const scrollData = cl.getScrollContainerData(cl.getElementId("MainContent"));
    if (rl.isMouseButtonDown(.left) and cl.pointerOver(cl.ElementId.ID("ScrollBar")) and !self.mouse_down_on_scrollbar) {
        self.mouse_down_on_scrollbar = true;
        self.scroll_bar_data.click_origin = mouse_pos;
        self.scroll_bar_data.position_origin = scrollData.scroll_position.*;
    }

    if (!rl.isMouseButtonDown(.left)) {
        self.mouse_down_on_scrollbar = false;
    }

    if (self.mouse_down_on_scrollbar) {
        if (scrollData.content_dimensions.h > 0 and scrollData.config.vertical) {
            const new_scroll_y = self.scroll_bar_data.position_origin.y + (self.scroll_bar_data.click_origin.y - mouse_pos.y) *
                (scrollData.content_dimensions.h / scrollData.scroll_container_dimensions.h);

            const new_scroll_bar_offset = -(new_scroll_y / scrollData.content_dimensions.h) * scrollData.scroll_container_dimensions.h;

            if (new_scroll_bar_offset < 0 or new_scroll_bar_offset + cl.getElementData(cl.getElementId("ScrollBar")).bounding_box.height > scrollData.scroll_container_dimensions.h) {} else {
                scrollData.scroll_position.y = new_scroll_y;
            }
        }
    }

    var render_commands = self.createLayout(self.mouse_down_on_scrollbar);
    rl.beginDrawing();
    renderer.clayRaylibRender(&render_commands, self.allocator);
    rl.endDrawing();
}

fn createLayout(self: *Self, mouse_down_on_scrollbar: bool) cl.ClayArray(cl.RenderCommand) {
    cl.beginLayout();
    cl.UI()(.{ .id = .ID("OuterContainer"), .layout = .{ .direction = .top_to_bottom, .sizing = .grow } })({
        cl.UI()(.{ .id = .ID("TopPanel"), .layout = .{ .direction = .left_to_right, .sizing = .grow }, .background_color = blue })({
            cl.text("⬅️ Testing...", .{ .font_size = 25, .color = light_grey }); 
        });
        cl.UI()(.{ .id = .ID("MainContent"), .layout = .{ .direction = .top_to_bottom, .sizing = .grow, .padding = .all(32), .child_gap = 10 }, .background_color = nice_grey, .scroll = .{ .vertical = true } })({
            if (self.cur_status == .success) {
                var content = parser.GemtextParser.new(self.cur_response.items);
                self.gemtextLayout(&content);
            } else {
                cl.text(@tagName(self.cur_status), .{ .font_size = 25, .color = red });
                cl.text(self.cur_response.items, .{ .font_size = 25, .color = white });
            }
        });
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

    if (self.hovered_str) |s| {
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

fn gemtextLayout(self: *Self, content: *parser.GemtextParser) void {
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
                    cl.onHover(self, onLinkHover);
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
}

pub fn deinit(self: *Self) void {
    self.cur_response.deinit();
    self.allocator.free(self.cur_url);
}


fn onLinkHover(element_id: cl.ElementId, pointer_data: cl.PointerData, context: *Self) void {
    context.hovered_str = element_id.string_id.chars[0..@intCast(element_id.string_id.length)];

    if (pointer_data.state == .released_this_frame) {
        if (std.mem.startsWith(u8, context.hovered_str.?, "gemini://")) {
            context.set_url(context.hovered_str.?, .absolute) catch {};
        } else {
            context.set_url(context.hovered_str.?, .relative) catch {};
        }
    }
}