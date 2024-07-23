const std = @import("std");

pub const mem = @import("./mem.zig");
pub const context = @import("./context.zig").context;
pub const Service = @import("./service.zig").Service.init;
pub const SELECT = @import("./SELECT.zig").SELECT.init;
extern fn print(ptr: *const u8, length: usize) void;

pub fn log(msg: []u8) void {
    print(&msg[0], msg.len);
}

pub fn logT(T: anytype) void {
    var json = std.ArrayList(u8).init(std.heap.page_allocator);
    defer json.clearAndFree();

    std.json.stringify(T, .{}, json.writer()) catch unreachable;
    const slice = json.allocatedSlice();
    log(slice[0..json.items.len]);
}
