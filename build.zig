const std = @import("std");

pub fn build(b: *std.Build) void {
    const opt = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    const wasm_target = b.resolveTargetQuery(std.zig.CrossTarget.parse(
        .{ .arch_os_abi = "wasm32-freestanding" },
    ) catch unreachable);

    const wasm = b.addExecutable(.{
        .name = "index",
        .root_source_file = b.path("src/index.zig"),
        .target = wasm_target,
        .optimize = opt,
    });
    wasm.entry = .disabled;
    wasm.rdynamic = true;

    b.installArtifact(wasm);

    const preprocess = b.addExecutable(.{
        .name = "preprocess",
        .root_source_file = b.path("src/preprocessor.zig"),
        .target = target,
        .optimize = opt,
    });
    preprocess.linkSystemLibrary("expat");
    preprocess.linkLibC();
    b.installArtifact(preprocess);
}
