const std = @import("std");
const builtin = @import("builtin");

pub usingnamespace switch (builtin.target.os.tag) {
    .macos => mac_impl,
    else => default_impl
};

const mac_impl = struct {
    pub const c = @cImport({
        @cInclude("objc/runtime.h");
        @cInclude("objc/message.h");
    });

    extern const NSPasteboardTypeString: c.id;

    pub fn paste_clipboard(buffer: []u8) usize { 
        const NSPasteboard: c.Class = c.objc_getClass("NSPasteboard");

        const msgSendGeneralPasteboard: *const fn (c.Class, c.SEL) callconv(.c) c.id  = @ptrCast(&c.objc_msgSend);
        const generalPasteboard = msgSendGeneralPasteboard(NSPasteboard, c.sel_registerName("generalPasteboard"));

        const msgSendStringForType: *const fn (c.id, c.SEL, c.id) callconv(.c) c.id = @ptrCast(&c.objc_msgSend); 
        const NSStringInstance = msgSendStringForType(generalPasteboard, c.sel_registerName("stringForType:"), NSPasteboardTypeString);

        const msgSendgetCString: *const fn (c.id, c.SEL, *u8, isize, usize) callconv(.c) bool = @ptrCast(&c.objc_msgSend); 
        if (msgSendgetCString(NSStringInstance, c.sel_registerName("getCString:maxLength:encoding:"), @ptrCast(buffer.ptr), @intCast(buffer.len), 4)) {
            return std.mem.indexOfSentinel(u8, 0, @ptrCast(buffer.ptr));
        } else {
            return 0;
        }
    }
};

const default_impl = struct {
    pub fn paste_clipboard(_: []u8) usize { 
        return 0;
    }
};