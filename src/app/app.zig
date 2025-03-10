const std = @import("std");
const Self = @This();
const gemini = @import("../gemini/gemini.zig");
const cl = @import("zclay");
const rl = @import("raylib");
const parser = @import("../gemini/gemtext_parser.zig");
const renderer = @import("raylib_render_clay.zig");
const style = @import("../style.zig");
const history = @import("history.zig");
const builtin = @import("builtin");
const clipboard = @import("clipboard.zig");

const MAX_SEARCH_CHARS = 128;

const MouseOver = enum {
    other,
    search_bar,
    link
};
mouse_over: MouseOver = .other,

url_history: history,
cur_response: std.ArrayList(u8),
cur_status: gemini.Status = .success,
hovered_str: ?[]const u8 = null,
allocator: std.mem.Allocator,
search_bar: std.BoundedArray(u8, MAX_SEARCH_CHARS),
frames_counter: usize = 0,

mouse_down_on_scrollbar: bool = false,
scroll_bar_data: struct { click_origin: cl.Vector2, position_origin: cl.Vector2 } = undefined,

style_options: style,

pub fn init(allocator: std.mem.Allocator, starting_url: []const u8, style_options: style) Self {
    var self = Self {
        .allocator = allocator, 
        .cur_response = std.ArrayList(u8).init(allocator), 
        .style_options = style_options, 
        .search_bar = std.BoundedArray(u8, MAX_SEARCH_CHARS){}, 
        .url_history = history.init(allocator, starting_url) 
    };
    self.search_bar.appendSlice(starting_url) catch {};

    self.update_response();
    return self;
}

fn reset_state(self: *Self) void {
    const scrollData = cl.getScrollContainerData(cl.getElementId("MainContent"));
    scrollData.scroll_position.y = 0;
    self.cur_response.clearRetainingCapacity();
    self.hovered_str = null;
}

fn update_response(self: *Self) void {
    self.search_bar.clear();
    self.search_bar.appendSlice(self.url_history.cur_url()) catch {};

    if (gemini.fetch(self.allocator, self.url_history.cur_url(), &self.cur_response) catch null) |status| {
        self.cur_status = status;
    } else {
        self.cur_status = .not_found;
        std.fmt.format(self.cur_response.writer(), "Could not fetch {s}", .{self.url_history.cur_url()}) catch {};
    }
}

fn set_url(self: *Self, url: []const u8) !void {
    if (url.len == 0) return;

    const url_type: enum{absolute, relative, other} = 
        if (std.mem.startsWith(u8, url, "gemini://")) .absolute
        else if (std.mem.indexOf(u8, url, "://")) |_| .other 
        else .relative;
    
    if (url_type == .other) {
        if (builtin.target.os.tag.isDarwin()) {
            var cp = std.process.Child.init(&[_][]const u8 {"/usr/bin/open", url}, self.allocator);
            cp.spawn() catch {};
        }
        return;
    }

    const trimmed_url = if (url[0] == '/') url[1..] else url;
    var new_url = 
        if (url_type == .absolute) 
            try self.allocator.dupe(u8, trimmed_url) 
        else 
            if (self.url_history.cur_url()[self.url_history.cur_url().len - 1] == '/') 
                try std.fmt.allocPrint(self.allocator, "{s}{s}", .{self.url_history.cur_url(), trimmed_url})
            else 
                try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{self.url_history.cur_url(), trimmed_url});

    if (!std.mem.endsWith(u8, new_url, "/")) {
        new_url = try self.allocator.realloc(new_url, new_url.len + 1);
        new_url[new_url.len - 1] = '/';
    }

    if (std.mem.eql(u8, self.url_history.current, new_url)) {
        self.allocator.free(new_url);
    } else {
        self.url_history.append(new_url);
    }

    self.reset_state();
    self.update_response();
}

pub fn update(self: *Self, mouse_pos: cl.Vector2) void {
    self.frames_counter += 1;

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

            const bb_height = cl.getElementData(cl.getElementId("ScrollBar")).bounding_box.height;
            if (!(new_scroll_bar_offset < 0 or new_scroll_bar_offset + bb_height > scrollData.scroll_container_dimensions.h)) {
                scrollData.scroll_position.y = new_scroll_y;
            }
        }
    }

    switch (self.mouse_over) {
        .search_bar => {
            rl.setMouseCursor(.ibeam);

            var key = rl.getCharPressed();
            while (key > 0) {
                if ((key >= 32) and (key <= 125)) {
                    self.search_bar.append(@intCast(key)) catch break;
                }

                key = rl.getCharPressed();
            }

            if (rl.isKeyPressed(.backspace)) {
                if (rl.isKeyDown(.left_alt)) {
                    self.search_bar.clear();
                } else {
                    _ = self.search_bar.pop();
                }
            }

            if (rl.isKeyPressed(.enter)) {
                self.set_url(self.search_bar.slice()) catch {};
            }

            if (rl.isKeyPressed(.v)) {
                if (rl.isKeyDown(.left_control)) {
                    const count = clipboard.paste_clipboard(self.search_bar.buffer[self.search_bar.len..]);
                    self.search_bar.resize(self.search_bar.len + count) catch unreachable;
                }
            }
        },
        .link => {
            rl.setMouseCursor(.pointing_hand);
        },
        .other => {
            rl.setMouseCursor(.default);
        }
    }

    var render_commands = self.createLayout(self.mouse_down_on_scrollbar);
    rl.beginDrawing();
    renderer.clayRaylibRender(&render_commands, self.allocator);
    rl.endDrawing();
}

fn createLayout(self: *Self, mouse_down_on_scrollbar: bool) cl.ClayArray(cl.RenderCommand) {
    self.mouse_over = .other;
    cl.beginLayout();
    cl.UI()(.{ 
        .id = .ID("OuterContainer"), 
        .layout = .{ 
            .direction = .top_to_bottom, 
            .sizing = .grow 
        } 
    })({
        cl.UI()(.{ 
            .id = .ID("TopPanel"), 
            .layout = .{ 
                .child_alignment = .{.y = .center}, 
                .padding = .all(4), 
                .direction = .left_to_right, 
                .sizing = .{.w = .grow, .h = .fit}, 
                .child_gap = 4 
            }, 
            .background_color = self.style_options.colors().top_panel 
        })({
            cl.UI()(.{
                    .id = .ID("BackButton"),
                    .layout = .{ .sizing = .{ .h = .fixed(40), .w = .fixed(40) } },
                    .image = .{ 
                        .source_dimensions = .{ .h = 40, .w = 40 }, 
                        .image_data = @ptrCast(&self.style_options.back_button) 
                    },
                })({
                    if (self.url_history.can_move_back()) {
                        if (!cl.hovered()) self.style_options.back_button.tint = renderer.clayColorToRaylibColor(cl.Color.white);
                        cl.onHover(self, onBackButtonHover);
                    } else {
                        self.style_options.back_button.tint = .fromInt(0xFFFFFF80);
                    } 
                });
            cl.UI()(.{
                    .id = .ID("ForwardButton"),
                    .layout = .{ .sizing = .{ .h = .fixed(40), .w = .fixed(40) }},
                    .image = .{ 
                        .source_dimensions = .{ .h = 40, .w = 40 }, 
                        .image_data = @ptrCast(&self.style_options.forward_button) 
                    },
                })({
                    if (self.url_history.can_move_forward()) {
                        if (!cl.hovered()) self.style_options.forward_button.tint = renderer.clayColorToRaylibColor(cl.Color.white);
                        cl.onHover(self, onForwardButtonHover);
                    } else {
                        self.style_options.forward_button.tint = .fromInt(0xFFFFFF80);
                    }
                });

            cl.UI()(.{
                    .id = .ID("AddressBar"),
                    .layout = .{ 
                        .padding = .xy(0, 15), 
                        .sizing = .grow, 
                        .child_alignment = .{.y = .center} 
                    }, 
                    .background_color = self.style_options.colors().address_bar.background,
                    .corner_radius = cl.CornerRadius.all(3)
                })({
                    if (cl.hovered()) {
                        self.mouse_over = .search_bar;
                    }
                    cl.text(self.search_bar.slice(), .{ .font_size = 20, .color = self.style_options.colors().address_bar.text }); 

                    if (self.mouse_over == .search_bar and self.search_bar.len != self.search_bar.capacity()) {
                        // blinking underscore char
                        if (((self.frames_counter / 40) % 2) == 0) {
                            cl.text("_", .{ .font_size = 20, .color = self.style_options.colors().address_bar.text }); 
                        }
                    }
                });
        });
        cl.UI()(.{ 
            .id = .ID("MainContent"), 
            .layout = .{ 
                .direction = .top_to_bottom, 
                .sizing = .grow, 
                .padding = .all(32), 
                .child_gap = 10 
            }, 
            .background_color = self.style_options.colors().background, 
            .scroll = .{ .vertical = true } 
        })({
            if (self.cur_status == .success) {
                var content = parser.GemtextParser.new(self.cur_response.items);
                self.gemtextLayout(&content);
            } else {
                cl.text(@tagName(self.cur_status), .{ .font_size = 25, .color = cl.Color.red });
                cl.text(self.cur_response.items, .{ .font_size = 25, .color = self.style_options.colors().text });
            }
        });
    });

    const scrollData = cl.getScrollContainerData(cl.getElementId("MainContent"));
    if (scrollData.found) {
        cl.UI()(.{
            .id = .ID("ScrollBar"),
            .floating = cl.FloatingElementConfig { 
                .attach_to = .to_element_with_id, 
                .parentId = cl.getElementId("MainContent").id, 
                .zIndex = 1, 
                .offset = .{ 
                    .x = 0, 
                    .y = -(scrollData.scroll_position.y / scrollData.content_dimensions.h) * scrollData.scroll_container_dimensions.h 
                }, 
                .attach_points = .{ .element = .right_top, .parent = .right_top } 
            },
        })({
            cl.UI()(.{ 
                .id = .ID("ScrollBarButton"), 
                .layout = cl.LayoutConfig { 
                    .sizing = .{ 
                        .w = .fixed(12), 
                        .h = .fixed(
                            (scrollData.scroll_container_dimensions.h / scrollData.content_dimensions.h) *
                             scrollData.scroll_container_dimensions.h
                        ) 
                    } 
                }, 
                .background_color = 
                    if (mouse_down_on_scrollbar) cl.Color.all(220)
                    else 
                        if (cl.hovered()) cl.Color.all(130)
                        else cl.Color.all(90), 
                .corner_radius = cl.CornerRadius.all(6) 
            })({});
        });
    }

    if (self.hovered_str) |s| {
        cl.UI()(.{
            .id = .ID("AddressTo"),
            .floating = cl.FloatingElementConfig { 
                .attach_to = .to_element_with_id, 
                .parentId = cl.getElementId("MainContent").id, 
                .zIndex = 1, 
                .attach_points = .{ 
                    .element = .left_bottom, 
                    .parent = .left_bottom 
                }
            }, 
            .background_color = cl.Color.all(100), 
            .corner_radius = .{.top_left = 1, .top_right = 1, .bottom_right = 1, .bottom_left = 10}, 
            .border = .{ .color = cl.Color.light_gray, .width = cl.BorderWidth.outside(1) } 
        })({
            cl.UI()(.{.layout = .{ .padding = .xy(2, 8) }})({
                cl.text(s, .{.color = cl.Color.white});
            });
        });
    }

    return cl.endLayout();
}

fn gemtextLayout(self: *Self, content: *parser.GemtextParser) void {
    var idx: u32 = 0;
    while (content.next()) |line| : (idx += 1) {
        switch (line) {
            .text => |t| cl.text(t, .{ .font_size = 25, .color = self.style_options.colors().text }),
            .list => |l| {
                cl.UI()(.{ .layout = .{ .padding = .{ .left = 20 } } })({
                    cl.text("■", .{
                        .color = self.style_options.colors().list.bullet,
                        .letter_spacing = 6,
                        .font_size = 30,
                    });
                    cl.text(l, .{ .color = self.style_options.colors().list.text, .font_size = 25 });
                });
            },
            .quote => |q| {
                cl.UI()(.{ 
                    .background_color = self.style_options.colors().quote.background, 
                    .corner_radius = cl.CornerRadius.all(4), 
                    .layout = .{ 
                        .sizing = cl.Sizing{ .h = .grow, .w = .grow }, 
                        .child_alignment = .{.y = .center}, 
                        .child_gap = 10 
                    } 
                })({
                    cl.UI()(.{ 
                        .background_color = cl.Color.light_gray, 
                        .corner_radius = cl.CornerRadius.all(4), 
                        .layout = .{ 
                            .sizing = cl.Sizing{ .h = .grow, .w = .fixed(15) } 
                        } 
                    })({});
                    cl.UI()(.{ .layout = .{ .padding = .xy(5, 0) } })({
                        cl.text(q, .{ .color = self.style_options.colors().quote.text, .font_size = 25 });
                    });
                });
            },
            .heading => |h| {
                const color = switch (h.level) {
                    .normal => self.style_options.colors().h1,
                    .sub => self.style_options.colors().h2,
                    .sub_sub => self.style_options.colors().h3
                };
                const font_size: u16 = switch (h.level) {
                    .normal => 45,
                    .sub => 37,
                    .sub_sub => 32,
                };
                cl.text(h.content, .{ .color = color, .font_size = font_size, .font_id = 2 });
            },
            .link => |l| {
                cl.UI()(.{ 
                    .id = .IDI(l.url, idx), 
                    .border = 
                        if (cl.hovered()) .{} 
                        else .{ .color = self.style_options.colors().link.text, .width = .{ .bottom = 2 } } 
                })({
                    cl.onHover(self, onLinkHover);
                    if (cl.hovered()) {
                        self.mouse_over = .link;
                    }
                    cl.text(
                        l.desc orelse l.url, 
                        .{ 
                            .color = 
                                if (cl.hovered()) self.style_options.colors().link.hovered
                                else self.style_options.colors().link.text, .font_size = 25
                        }
                    );
                });
            },
            .preformat => |pf| {
                cl.UI()(.{ 
                    .background_color = self.style_options.colors().preformat.background, 
                    .corner_radius = cl.CornerRadius.all(2), 
                    .border = .{ 
                        .color = self.style_options.colors().preformat.background, 
                        .width = cl.BorderWidth.outside(2) 
                    } 
                })({
                    cl.UI()(.{ 
                        .layout = .{ 
                            .padding = .{ .left = 15, .right = 40, .top = 20, .bottom = 20 } 
                        }
                    })({
                        cl.text(
                            pf, 
                            .{ 
                                .color = self.style_options.colors().preformat.text, 
                                .font_size = 20, 
                                .font_id = 1 
                            }
                        );
                    });
                });
            },
        }
    }
}

pub fn deinit(self: *Self) void {
    self.cur_response.deinit();
    self.url_history.deinit();
}

fn onLinkHover(element_id: cl.ElementId, pointer_data: cl.PointerData, context: *Self) void {
    context.hovered_str = element_id.string_id.chars[0..@intCast(element_id.string_id.length)];

    if (pointer_data.state == .released_this_frame) {
        context.set_url(context.hovered_str.?) catch {};
    }
}

fn onBackButtonHover(_: cl.ElementId, pointer_data: cl.PointerData, context: *Self) void {
    context.hovered_str = context.url_history.peek_back();
    const tint = if (pointer_data.state == .pressed) cl.Color.gray else cl.Color.light_gray;
    context.style_options.back_button.tint = renderer.clayColorToRaylibColor(tint);

    if (pointer_data.state == .released_this_frame and context.url_history.can_move_back()) {
        context.url_history.move_back();
        context.reset_state();
        context.update_response();
    }
}

fn onForwardButtonHover(_: cl.ElementId, pointer_data: cl.PointerData, context: *Self) void {
    context.hovered_str = context.url_history.peek_forward();
    const tint = if (pointer_data.state == .pressed) cl.Color.gray else cl.Color.light_gray;
    context.style_options.forward_button.tint = renderer.clayColorToRaylibColor(tint);

    if (pointer_data.state == .released_this_frame and context.url_history.can_move_forward()) {
        context.url_history.move_forward();
        context.reset_state();
        context.update_response();
    }
}