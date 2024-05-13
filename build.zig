const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "aeron-zig",
        .root_source_file = b.path("src/aeron.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(lib);

    // build with Aeron library
    lib.addLibraryPath(.{ .path = "lib" });
    lib.linkSystemLibrary("aeron_static");
    lib.linkLibC();
    // exe.addIncludePath(.{ .path = "include/aeron" });
    // exe.defineCMacro("DISABLE_BOUNDS_CHECKS", null);
    // exe.linkSystemLibrary("aeron");
}
