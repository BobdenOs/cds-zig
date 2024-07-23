const std = @import("std");
const cds = @import("./lib.zig");

export fn main() void {
    var adminService = cds.Service("AdminService");
    adminService.before("CREATE", "Authors", "genid");
    adminService.before("CREATE", "Books", "genid");

    var userService = cds.Service("UserService");
    // REVISIT: Handler is registered behind default reject of persistence skip annotated entities
    userService.on("READ", "me", "onMe");
    userService.on("login", "", "onLogin"); // "" is considered undefined by handler registration (+1)
}

export fn genid(ptr: *u8, size: usize) void {
    const req = cds.mem.req(ptr, size, struct {});
    defer req.deinit();
    var cqn = cds.SELECT();
    cqn.from(req.value.target orelse "")
        .one(true)
        .columns("max(ID) as ID")
        .then("onMaxID");
}

export fn onMaxID(ptr: *u8, size: usize) void {
    const ID = struct {
        ID: u32,
    };

    const parsed = cds.mem.obj(ptr, size, ID);
    defer parsed.deinit();

    const id = parsed.value.ID - parsed.value.ID % 100 + 100 + 1;
    cds.context.setData("ID", id);
}

export fn onMe(ptr: *u8, size: usize) void {
    const req = cds.mem.req(ptr, size, struct {});
    defer req.deinit();

    const Me = struct {
        id: []u8,
        locale: ?[]u8,
        tenant: ?[]u8,
    };

    const me: Me = .{
        .id = req.value.user.id,
        .locale = req.value.locale,
        .tenant = req.value.tenant,
    };

    cds.mem.returnT(me);
}

export fn onLogin(ptr: *u8, size: usize) void {
    // Original example uses req._.http.res
    onMe(ptr, size);
}
