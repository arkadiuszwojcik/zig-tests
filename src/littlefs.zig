const std = @import("std");
const c = @cImport({
    @cInclude("lfs_util.h");
    @cInclude("lfs.h");
});

const lfs_build_options = @import("lfs_build_options");

comptime {
    if (lfs_build_options.no_malloc == false) {
        @export(custom_lfs_malloc, .{ .name = "custom_lfs_malloc", .linkage = .strong });
        @export(custom_lfs_free, .{ .name = "custom_lfs_free", .linkage = .strong });
    }
}

pub const lfs_config = struct {
    const Self = @This();

    read: fn (block: u32, off: u32, buffer: []u8) i32,
    prog: fn (block: u32, off: u32, buffer: []const u8) i32,
    erase: fn (block: u32) i32,
    sync: fn () i32,

    //block_size: u32,
    //block_count: u32,
    //block_cycles: u32,

    pub fn to_lfs_config(self: *const Self) c.lfs_config {
        return c.lfs_config {
            .context = @ptrCast(@constCast(self)),
            .read = lfs_read,
            .prog = lfs_prog,
            .erase = lfs_erase,
            .sync = lfs_sync,

            .read_size = 16,
            .prog_size = 16,
            .block_size = 4096,
            .block_count = 128,
            .cache_size = 16,
            .lookahead_size = 16,
            .block_cycles = 500,
        };
    }
};

fn lfs_read(config: [*c]const c.lfs_config, block: u32, off: u32, buffer: ?*anyopaque, size: u32) callconv(.C) c_int {
    return @as(*lfs_config, @ptrCast(config.*.context)).read(block, off, @as([*]u8, @ptrCast(buffer))[0..size]);
}

fn lfs_prog(config: [*c]const c.lfs_config, block: u32, off: u32, buffer: ?*const anyopaque, size: u32) callconv(.C) c_int {
    return @as(*const lfs_config, @ptrCast(config.context)).prog(block, off, @as([*]const u8, @ptrCast(buffer))[0..size]);
}

fn lfs_erase(config: [*c]const c.lfs_config, block: u32) callconv(.C) c_int {
    return @as(*const lfs_config, @ptrCast(config.context)).erase(block);
}

fn lfs_sync(config: [*c]const c.lfs_config) callconv(.C) c_int {
    return @as(*const lfs_config, @ptrCast(config.context)).sync();
}

pub const api = struct {
    pub const format = c.lfs_format;
    pub const mount = c.lfs_mount;
    pub const unmount = c.lfs_unmount;
    pub const mkdir = c.lfs_mkdir;

    pub const lfs_config = c.struct_lfs_config;
};

pub const GlobalError = error{
    IoErr,
    CorruptErr,
    NoDirEntry,
    EntryAlreadyExists,
    EntryNotDir,
    EntryIsDir,
    NotEmpty,
    BadFileNumber,
    FileTooLarge,
    InvalidParam,
    NoSpace,
    NoMemory,
    NoAttribute,
    FileNameTooLong
};

inline fn mapGenericError(code: c.lfs_error) GlobalError!void {
    return switch (code) {
        c.LFS_ERR_OK => {},
        c.LFS_ERR_IO => error.IoErr,
        c.LFS_ERR_CORRUPT => error.CorruptErr,
        c.LFS_ERR_NOENT => error.NoDirEntry,
        c.LFS_ERR_EXIST => error.EntryAlreadyExists,
        c.LFS_ERR_NOTDIR => error.EntryNotDir,
        c.LFS_ERR_ISDIR => error.EntryIsDir,
        c.LFS_ERR_NOTEMPTY => error.NotEmpty,
        c.LFS_ERR_BADF => error.BadFileNumber,
        c.LFS_ERR_FBIG => error.FileTooLarge,
        c.LFS_ERR_INVAL => error.InvalidParam,
        c.LFS_ERR_NOSPC => error.NoSpace,
        c.LFS_ERR_NOMEM => error.NoMemory,
        c.LFS_ERR_NOATTR => error.NoAttribute,
        c.LFS_ERR_NAMETOOLONG => error.FileNameTooLong,
        else => unreachable,
    };
}

pub fn mapSomeError() GlobalError!void {
    return mapGenericError(c.LFS_ERR_NOTEMPTY);
}

pub fn myTest() void
{
    //const handle: c.lfs_t = undefined;
    //const err = c.lfs_mount(&lfs, &cfg);
}

const global = struct {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    pub var allocator: std.mem.Allocator = gpa.allocator();
    pub var endianness: std.builtin.Endian = std.builtin.Endian.little;
};

fn custom_lfs_malloc(size: usize) callconv(.C) ?*anyopaque {
    const raw_mem = global.allocator.alloc(u8, @sizeOf(usize) + size) catch return null;
    std.mem.writeInt(usize, raw_mem[0..@sizeOf(usize)], size, global.endianness);
    const user_mem = raw_mem[@sizeOf(usize)..];
    return @ptrCast(user_mem.ptr);
}

fn custom_lfs_free(ptr: *anyopaque) callconv(.C) void {
    const user_mem_ptr = @as([*]u8, @ptrCast(ptr));
    const raw_mem_ptr = user_mem_ptr - @sizeOf(usize);
    const raw_mem = @as([*]u8, @ptrCast(raw_mem_ptr));

    const size = std.mem.readInt(usize, raw_mem[0..@sizeOf(usize)], global.endianness);
    const raw_mem_slice = raw_mem[0..size];
    global.allocator.free(raw_mem_slice);
}

pub const FileSystem = struct {
    const Self = @This();

    raw: c.lfs_t = undefined,

    pub fn format(self: *Self, config: *api.lfs_config) void {
        const res = api.format(&self.raw, config);
        std.log.info("format: {}", .{res});
    }
    
    pub fn mount(self: *Self, config: *api.lfs_config) void {
        const res = api.mount(&self.raw, config);
        std.log.info("mount: {}", .{res});
    }

    pub fn makeDir(self: *Self, path: [:0]const u8) void {
        std.log.info("makeDir start", .{});
        const res = api.mkdir(&self.raw, path.ptr);
        std.log.info("makeDir: {}", .{res});
    }

    //pub fn cwd() Dir {
    //    return Dir{ .fs = &raw };
    //}
};

pub const Dir = struct {
    const Self = @This();
    fs: *c.lfs_t,
    dir_handle: c.lfs_dir_t = undefined,

    pub fn openDir(self: *Self, sub_path: [:0]const u8) void {
        _ = c.lfs_dir_open(self.fs, self.dir_handle, sub_path.ptr);
    }

    pub fn close(self: *Self) void {
        c.lfs_dir_close(self.fs, &self.dir_handle);
    }
};