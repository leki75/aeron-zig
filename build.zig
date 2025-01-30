const std = @import("std");

const log = std.log.scoped(.aeron);

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    if (target.result.cpu.arch != .x86_64) log.err("The target CPU architecture needs to be 'x86_64': {s}", .{@tagName(target.result.cpu.arch)});

    const options = b.addOptions();
    const dynamic = b.option(bool, "dynamic", "link with dynamic library (default: false)") orelse false;
    options.addOption(bool, "dynamic", dynamic);

    const lib = b.addModule("aeron", .{
        .root_source_file = b.path("src/aeron.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib.addLibraryPath(b.path("lib"));
    if (target.result.cpu.arch == .x86_64) {
        switch (target.result.abi) {
            .gnu => lib.linkSystemLibrary(if (dynamic) "aeron_libc" else "aeron_static_libc", .{}),
            .musl => lib.linkSystemLibrary(if (dynamic) "aeron_musl" else "aeron_static_musl", .{}),
            else => |abi| log.err("The target ABI needs to be 'musl' or 'gnu': {s}", .{@tagName(abi)}),
        }
    }
}
