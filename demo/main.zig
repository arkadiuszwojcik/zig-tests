const std = @import("std");
const builtin = @import("builtin");
pub const littlefs = @import("zlittlefs");

var disc: [4096 * 128]u8 = undefined;

fn zig_test_read(block: u32, off: u32, buffer: []u8) i32 {
    std.log.info("read: block: {} off: {} size: {}", .{block, off, buffer.len});
    const start = 4096 * block + off;
    const end = start + buffer.len;
    @memcpy(buffer, disc[start .. end]);
    return 0;
}

fn zig_test_prog(block: u32, off: u32, buffer: []const u8) i32 {
    std.log.info("prog: block: {} off: {} size: {}", .{block, off, buffer.len});
    const start = 4096 * block + off;
    const end = start + buffer.len;
    @memcpy(disc[start .. end], buffer[0..buffer.len]);
    return 0;
}

fn zig_test_erase(block: u32) i32 {
    _ = block;
    return 0;
}

fn zig_test_sync() i32 {
    return 0;
}

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    const test_cfg = littlefs.lfs_config{
        .read = zig_test_read,
        .prog = zig_test_prog,
        .erase = zig_test_erase,
        .sync = zig_test_sync
    };
    _ = test_cfg.to_lfs_config();
    //var lfs_config = test_cfg.to_lfs_config();

    //var fs = littlefs.FileSystem{};
    //fs.format(&lfs_config);
    //fs.mount(&lfs_config);
    //fs.makeDir("ala_kot");

    


    //try bw.flush(); // don't forget to flush!
    //try littlefs.mapSomeError();

    if (littlefs.mapSomeError()) {
       try stdout.print("Ok: \n", .{});
    } else |err| {
        try stdout.print("Error: {}\n", .{err});
    }

    try bw.flush(); // don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

export fn foundation_libc_assert(
    assertion: ?[*:0]const u8,
    file: ?[*:0]const u8,
    line: c_uint,
) noreturn {
    switch (builtin.mode) {
        .Debug, .ReleaseSafe => {
            var buf: [256]u8 = undefined;
            const str = std.fmt.bufPrint(&buf, "assertion failed: '{?s}' in file {?s} line {}", .{ assertion, file, line }) catch {
                @panic("assertion failed");
            };
            @panic(str);
        },
        .ReleaseSmall => @panic("assertion failed"),
        .ReleaseFast => unreachable,
    }
}
