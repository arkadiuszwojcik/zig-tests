const std = @import("std");
const c = @cImport({
    @cInclude("test.h");
});

pub const lfs_config = struct {
    const Self = @This();

    read: fn (block: u32, off: u32, buffer: []u8) i32,

    pub fn to_lfs_config(self: *const Self) c.lfs_config {
        return c.lfs_config {
            .context = @ptrCast(@constCast(self)),
            .read = lfs_read,
        };
    }
};

fn lfs_read(config: [*c]const c.lfs_config, block: u32, off: u32, buffer: ?*anyopaque, size: u32) callconv(.C) c_int {
    return @as(*lfs_config, @ptrCast(config.*.context)).read(block, off, @as([*]u8, @ptrCast(buffer))[0..size]);
}

pub fn main() !void {
    const test_cfg = lfs_config{
        .read = zig_test_read,
    };
    _ = test_cfg.to_lfs_config();
}

fn zig_test_read(block: u32, off: u32, buffer: []u8) i32 {
    std.log.info("read: block: {} off: {} size: {}", .{block, off, buffer.len});
    return 0;
}
