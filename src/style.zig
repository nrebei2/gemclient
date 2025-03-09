const Self = @This();
const std = @import("std");
const rl = @import("raylib");
const cl = @import("zclay");
const toml = @import("toml");

back_button: TexInfo,
forward_button: TexInfo,
toml_result: ConfigType,

pub const TexInfo = struct {
    texture: rl.Texture,
    rotation: f32 = 0,
    flip_vertically: bool = false,
    tint: rl.Color = rl.Color.white
};

const ConfigType = union (enum) {
    parsed: toml.Parsed(Config), 
    default: Config
};

const General = struct {
    start_url: []const u8 = "gemini://geminiprotocol.net/",
};

const Colors = struct {
    h1: cl.Color = cl.Color.purple,
    h2: cl.Color = cl.Color.green,
    h3: cl.Color = cl.Color.orange,
    text: cl.Color = cl.Color.white,
    top_panel: cl.Color = cl.Color.blue,
    background: cl.Color = cl.Color.gray,
    list: struct {text: cl.Color, bullet: cl.Color} = .{
        .text = cl.Color.green, 
        .bullet = cl.Color.orange
    }, 
    address_bar: struct {text: cl.Color, background: cl.Color} = .{
        .text = cl.Color.light_gray, 
        .background = cl.Color.dark_gray
    },
    quote: struct {text: cl.Color, background: cl.Color} = .{
        .text = cl.Color.white, 
        .background = cl.Color.dark_gray
    },
    link: struct {text: cl.Color, hovered: cl.Color} = .{
        .text = cl.Color.blue, 
        .hovered = cl.Color.light_blue
    },
    preformat: struct {text: cl.Color, background: cl.Color} = .{
        .text = cl.Color.white, 
        .background = cl.Color.dark_gray
    },
};

const Config = struct {
    general: General = .{},
    colors: Colors = .{}
};

pub fn init(allocator: std.mem.Allocator) Self {
    const back_button_texture = loadImage("resources/go-back.png");
    const result = retrieve_settings_toml(allocator) catch null;

    return Self {
        .back_button = .{.texture = back_button_texture},
        .forward_button = .{ .texture = back_button_texture, .flip_vertically = true }, 
        .toml_result = if (result) |p| .{.parsed = p} else .{.default = .{}}
    };
}

fn retrieve_settings_toml(allocator: std.mem.Allocator) !toml.Parsed(Config) {
    var parser = toml.Parser(Config).init(allocator); 
    defer parser.deinit();

    const home_dir = try std.process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home_dir);

    const settings_dir = try std.mem.concat(
        allocator, u8, 
        &[2][]const u8 {home_dir, "/.config/gemclient/settings.toml"}
    );
    defer allocator.free(settings_dir);
    
    return parser.parseFile(settings_dir);
}

pub fn config(self: *const Self) *const Config {
    return switch (self.toml_result) {
        .default => |d| &d,
        .parsed => |p| &p.value
    };
}

pub fn colors(self: *const Self) *const Colors {
    return &self.config().colors;
}

pub fn deinit(self: *Self) void {
    switch (self.toml_result) {
        .parsed => |p| p.deinit(),
        else => {}
    }
}

fn loadImage(comptime path: [:0]const u8) rl.Texture2D {
    const texture = rl.loadTextureFromImage(
        rl.loadImageFromMemory(@ptrCast(std.fs.path.extension(path)), @embedFile(path)) catch unreachable
    ) catch unreachable;
    rl.setTextureFilter(texture, .bilinear);
    return texture;
}
