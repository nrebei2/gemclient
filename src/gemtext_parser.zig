const std = @import("std");

pub const GemtextParser = struct {
    const Self = GemtextParser;
    lines: std.mem.SplitIterator(u8, .scalar),

    pub fn new(response: []const u8) Self {
        return Self { .lines = std.mem.splitScalar(u8, response, '\n')};
    }

    pub fn next(self: *Self) ?Line {
        var next_line = self.lines.next() orelse return null;
        if (std.mem.endsWith(u8, next_line, "\r")) {
            next_line = next_line[0..next_line.len - 1];
        }

        if (std.mem.startsWith(u8, next_line, "#")) {
            var begin: usize = 0;
            while (begin < @min(3, next_line.len) and next_line[begin] == '#') : (begin += 1) {}
            const level: Level = switch (begin) {
                1 => .normal,
                2 => .sub,
                3 => .sub_sub,
                else => unreachable
            };

            return Line {.heading = .{.level = level, .content = next_line[begin..]}};
        } else if (std.mem.startsWith(u8, next_line, "=>")) {
            var line = next_line[2..];
            line = std.mem.trimLeft(u8, line, " \t");

            const idx = std.mem.indexOfAny(u8, line, " \t") orelse return Line.create_link(line, null);
            const url = line[0..idx];

            line = line[idx..];
            return Line.create_link(url, std.mem.trimLeft(u8, line, " \t"));
        } else if (std.mem.startsWith(u8, next_line, "* ")) {
            return Line {.quote = next_line[2..]};
        } else if (std.mem.startsWith(u8, next_line, ">")) {
            return Line {.quote = next_line[1..]};
        } else if (std.mem.startsWith(u8, next_line, "```")) {
            _ = next_line[3..]; // alt text, unused

            const start_idx = self.lines.index orelse return null;
            var end_idx = start_idx;

            while (self.lines.next()) |line| {
                if (std.mem.startsWith(u8, line, "```")) {
                    return Line {.preformat = self.lines.buffer[start_idx..end_idx]};
                }
                end_idx = self.lines.index orelse 0;
            } else {
                // instead of failing assume response was cut off and do best effort
                return Line {.preformat = self.lines.buffer[start_idx..]};
            }
        } else {
            return Line {.text = next_line};
        }
    }
};

pub const Level = enum {
    normal, 
    sub,
    sub_sub
};

pub const Line = union(enum) {
    text: []const u8,
    link: struct {url_type: enum{relative, absolute}, url: []const u8, desc: ?[]const u8},
    heading: struct {level: Level, content: []const u8},
    list: []const u8,
    quote: []const u8,
    preformat: []const u8, // does not include alt text

    fn create_link(url: []const u8, desc: ?[]const u8) Line {
        return Line {
            .link = .{
                .url_type = if (std.mem.startsWith(u8, url, "gemini://")) .absolute else .relative,
                .url = url, 
                .desc = desc 
            }
        };
    }
};