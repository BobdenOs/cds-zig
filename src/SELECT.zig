const std = @import("std");
const mem = std.heap.page_allocator;

extern fn CDS_SELECT(ptr: *const u8, length: usize) void;

pub const SELECT = struct {
    _one: bool,
    _from: []u8,
    _columns: []u8,

    pub fn init() SELECT {
        return .{
            ._one = false,
            ._from = undefined,
            ._columns = undefined,
        };
    }

    pub fn one(self: *SELECT, val: bool) *SELECT {
        self._one = val;
        return self;
    }

    pub fn from(self: *SELECT, target: []const u8) *SELECT {
        const ptr = mem.alloc(u8, target.len) catch unreachable;
        @memcpy(ptr, target);
        self._from = ptr;
        return self;
    }

    pub fn columns(self: *SELECT, comptime cols: []const u8) *SELECT {
        const ptr = mem.alloc(u8, cols.len) catch unreachable;
        @memcpy(ptr, cols);
        self._columns = ptr;
        return self;
    }

    pub fn ignore(self: *SELECT) void {
        _ = self;
    }

    pub fn then(self: *SELECT, comptime cb: []const u8) void {
        var json = std.ArrayList(u8).init(mem);
        std.json.stringify(.{
            .cb = cb,
            .one = self._one,
            .from = self._from,
            .columns = self._columns,
        }, .{}, json.writer()) catch unreachable;
        const slice = json.allocatedSlice();
        CDS_SELECT(&slice[0], json.items.len);
    }
};
