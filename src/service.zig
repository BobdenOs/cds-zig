const std = @import("std");
const mem = @import("./mem.zig");
const alloc = std.heap.page_allocator;

extern fn CDS_SERVICE(ptr: *const u8, length: usize) void;

const Event = struct {
    service: []u8,
    hook: []u8,
    event: []u8,
    entity: []u8,
    cb: []u8,
};

pub const Service = struct {
    _name: []u8,

    pub fn init(comptime name: []const u8) Service {
        const ptr = std.heap.page_allocator.alloc(u8, name.len) catch unreachable;
        @memcpy(ptr, name);
        return .{
            ._name = ptr,
        };
    }

    fn call(self: *Service, comptime hook: []const u8, comptime event: []const u8, comptime entity: []const u8, comptime cb: []const u8) void {
        const hook_ptr = alloc.alloc(u8, hook.len) catch unreachable;
        @memcpy(hook_ptr, hook);
        defer alloc.free(hook_ptr);

        const event_ptr = alloc.alloc(u8, event.len) catch unreachable;
        @memcpy(event_ptr, event);
        defer alloc.free(event_ptr);

        const entity_ptr = alloc.alloc(u8, entity.len) catch unreachable;
        @memcpy(entity_ptr, entity);
        defer alloc.free(entity_ptr);

        const cb_ptr = alloc.alloc(u8, cb.len) catch unreachable;
        @memcpy(cb_ptr, cb);
        defer alloc.free(cb_ptr);

        const payload: Event = .{
            .service = self._name,
            .hook = hook_ptr,
            .event = event_ptr,
            .entity = entity_ptr,
            .cb = cb_ptr,
        };
        mem.writeT(payload, CDS_SERVICE);
    }

    pub fn before(self: *Service, comptime event: []const u8, comptime entity: []const u8, comptime cb: []const u8) void {
        self.call("before", event, entity, cb);
    }

    pub fn on(self: *Service, comptime event: []const u8, comptime entity: []const u8, comptime cb: []const u8) void {
        self.call("on", event, entity, cb);
    }

    pub fn after(self: *Service, comptime event: []const u8, comptime entity: []const u8, comptime cb: []const u8) void {
        self.call("after", event, entity, cb);
    }
};
