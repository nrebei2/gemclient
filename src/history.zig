const std = @import("std");
const Self = @This();

allocator: std.mem.Allocator,
past: std.ArrayList([]const u8), // elements are owned
current: []const u8,
future: std.ArrayList([]const u8), // elements are owned

pub fn init(allocator: std.mem.Allocator, starting_url: []const u8) Self {
    const current_url = allocator.dupe(u8, starting_url) catch unreachable;
    return Self {.allocator = allocator, .past = std.ArrayList([]const u8).init(allocator), .current = current_url, .future = std.ArrayList([]const u8).init(allocator)};
}

pub fn can_move_back(self: *Self) bool {
    return self.past.items.len != 0;
}

pub fn can_move_forward(self: *Self) bool {
    return self.future.items.len != 0;
}

pub fn move_back(self: *Self) void {
    const url = self.past.pop() orelse return;
    self.future.append(self.current) catch self.allocator.free(self.current);
    self.current = url;
}

pub fn peek_back(self: *Self) ?[]const u8 {
    return self.past.getLastOrNull();
}

pub fn move_forward(self: *Self) void {
    const url = self.future.pop() orelse return;
    self.past.append(self.current) catch self.allocator.free(self.current);
    self.current = url;
}

pub fn peek_forward(self: *Self) ?[]const u8 {
    return self.future.getLastOrNull();
}

pub fn append(self: *Self, url: []const u8) void {
    self.past.append(self.current) catch self.allocator.free(self.current);
    self.current = url;
    self.future.clearRetainingCapacity();
}

pub fn cur_url(self: *const Self) []const u8 {
    return self.current;
}

pub fn deinit(self: *Self) void {
    for (self.past.items) |item| {
        self.allocator.free(item);
    }

    for (self.future.items) |item| {
        self.allocator.free(item);
    }

    self.allocator.free(self.current);
    self.past.deinit();
    self.future.deinit();
}