const std = @import("std");

pub fn build(b: *std.Build) !void {

    const demo_step = b.step("demo", "Builds the demo:");

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    const link_libc = !(b.option(bool, "no-libc", "Prevents linking of libc by default") orelse false);
    const no_malloc = b.option(bool, "no-malloc", "Use provided buffers instead of malloc") orelse true;

    const build_options = b.addOptions();
    build_options.addOption(bool, "no_malloc", no_malloc);
    
    const foundationlibc_dep = b.dependency("foundation_libc", .{
        .target = target,
        .optimize = optimize,
    });

    const littlefs_c_dep = b.dependency("littlefs_c", .{
        .target = target,
        .optimize = optimize,
    });

    const zlittlefs_mod = b.addModule("zlittlefs", .{
        .root_source_file = b.path("src/littlefs.zig"),
    });

    zlittlefs_mod.addIncludePath(foundationlibc_dep.path("include"));
    zlittlefs_mod.addIncludePath(littlefs_c_dep.path(""));
    zlittlefs_mod.addIncludePath(b.path("src/custom_include"));

    zlittlefs_mod.addCSourceFiles(.{
        .root = littlefs_c_dep.path(""),
        .files = &.{"lfs.c", "lfs_util.c"}
    });

    // Remove printf usage so stdio.h is not required (stdio right now is not supported in foundation libc)
    zlittlefs_mod.addCMacro("LFS_NO_DEBUG", "");
    zlittlefs_mod.addCMacro("LFS_NO_WARN", "");
    zlittlefs_mod.addCMacro("LFS_NO_ERROR", "");
    zlittlefs_mod.addCMacro("LFS_DEFINES", "custom_defines.h");
    if (no_malloc) {
        zlittlefs_mod.addCMacro("LFS_NO_MALLOC", "");
    }
    zlittlefs_mod.link_libc = link_libc;

    zlittlefs_mod.addOptions("lfs_build_options", build_options);

    // demo

    const exe = b.addExecutable(.{
        .name = "zlittlefs-demo",
        .root_source_file = b.path("demo/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibC();

    exe.root_module.addImport("zlittlefs", zlittlefs_mod);
    const demo_exe = b.addInstallArtifact(exe, .{});
    demo_step.dependOn(&demo_exe.step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}