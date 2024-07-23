const std = @import("std");
const mem = @import("./mem.zig");
const alloc = std.heap.page_allocator;

extern fn CDS_CONTEXT(ptr: *const u8, length: usize) void;

pub const context = mem.Request(struct {});
