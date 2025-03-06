const rl = @import("raylib");
const cl = @import("zclay");

pub const TexInfo = struct {
    texture: rl.Texture,
    rotation: f32 = 0,
    flip_vertically: bool = false,
    tint: rl.Color = rl.Color.white
};

back_button: TexInfo,
forward_button: TexInfo
