const std = @import("std");

fn isAlpine() bool {
    const f = std.fs.openFileAbsolute(
        "/etc/alpine-release",
        std.fs.File.OpenFlags{},
    ) catch {
        return false;
    };
    defer f.close();
    return true;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const options = b.addOptions();
    const dynamic = b.option(bool, "dynamic", "link with dynamic library (default: false)") orelse false;
    options.addOption(bool, "dynamic", dynamic);

    const lib = b.addModule("aeron", .{
        .root_source_file = b.path("src/aeron.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib.addLibraryPath(b.path("lib"));
    if (isAlpine() and !dynamic) {
        lib.linkSystemLibrary("aeron_static_musl", .{});
    } else if (isAlpine() and dynamic) {
        lib.linkSystemLibrary("aeron_musl", .{});
    } else if (!isAlpine() and !dynamic) {
        lib.linkSystemLibrary("aeron_static_libc", .{});
    } else if (!isAlpine() and dynamic) {
        lib.linkSystemLibrary("aeron_libc", .{});
    }
}
