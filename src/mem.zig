// Expose alloc and free for sending result from node to zig
const std = @import("std");
const mem = std.heap.page_allocator;

export fn alloc(size: usize) *const u8 {
    const ptr = mem.alloc(u8, size) catch {
        @panic("ALLOC FAILED.");
    };
    return &ptr[0];
}

export fn free(ptr: *u8, size: usize) void {
    const non_const_ptr = @as([*]u8, @ptrCast(@constCast(ptr)));
    mem.rawFree(non_const_ptr[0..size], std.math.log2_int(@TypeOf(size), size), @returnAddress());
}

pub fn read(ptr: *u8, size: usize) []u8 {
    const non_const_ptr = @as([*]u8, @ptrCast(@constCast(ptr)));
    const data = non_const_ptr[0..size];
    return data;
}

extern fn print(ptr: *const u8, length: usize) void;

pub fn write(msg: []u8, cb: @TypeOf(print)) void {
    cb(&msg[0], msg.len);
}

pub fn writeT(T: anytype, cb: @TypeOf(print)) void {
    var json = std.ArrayList(u8).init(std.heap.page_allocator);
    defer json.clearAndFree();

    std.json.stringify(T, .{}, json.writer()) catch unreachable;
    const slice = json.allocatedSlice();
    write(slice[0..json.items.len], cb);
}

extern fn CDS_RETURN(ptr: *const u8, length: usize) void;
extern fn CDS_RETURN_ASYNC() void;

pub fn returnT(T: anytype) void {
    writeT(T, CDS_RETURN);
}

pub fn returnP() void {
    CDS_RETURN_ASYNC();
}

extern fn CDS_CONTEXT(ptr: *const u8, length: usize) void;

pub fn Request(comptime T: type) type {
    return struct {
        data: ?T,
        locale: ?[]u8,
        tenant: ?[]u8,
        user: struct {
            id: []u8,
            // roles: std.json.ArrayHashMap(i32),
        },
        target: ?[]u8,

        pub fn setData(comptime key: []const u8, val: anytype) void {
            const key_ptr = mem.alloc(u8, key.len) catch unreachable;
            @memcpy(key_ptr, key);
            defer mem.free(key_ptr);

            const Data = struct {
                key: []u8,
                value: @TypeOf(val),
            };
            const data: Data = .{
                .key = key_ptr,
                .value = val,
            };
            writeT(data, CDS_CONTEXT);
        }
    };
}

pub fn req(ptr: *u8, size: usize, comptime T: type) std.json.Parsed(Request(T)) {
    return obj(ptr, size, Request(T));
}

pub fn obj(ptr: *u8, size: usize, comptime T: type) std.json.Parsed(T) {
    const data = read(ptr, size);
    defer free(ptr, size);

    const parsed = std.json.parseFromSlice(
        T,
        mem,
        data,
        .{
            // .duplicate_field_behavior = use_last,
            .ignore_unknown_fields = true,
        },
    ) catch unreachable;

    return parsed;
}
