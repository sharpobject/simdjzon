const std = @import("std");

fn setup(step: *std.build.LibExeObjStep, mode: std.builtin.Mode, target: anytype, step_128: bool, ondemand: bool, ondemand_read_cap: u16) void {
    step.addCSourceFile("src/utils.c", &[_][]const u8{ "-Wall", "-Wextra", "-Werror", "-O3" });
    step.setTarget(target);
    // workaround for some kind of bug in debug builds which
    // manifests as bit_indexer.tail.items segfault
    if (mode == .Debug)
        step.setBuildMode(.ReleaseSafe)
    else
    step.setBuildMode(mode);
    step.addBuildOption(bool, "step_128", step_128);
    step.addBuildOption(bool, "ondemand", ondemand);
    step.addBuildOption(u16, "ondemand_read_cap", ondemand_read_cap);
}

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const step_128 = b.option(
        bool,
        "step-128",
        "process 128 bytes of input per StructuralIndexer step.  defaults to 64 if this flag is not present.  ",
    ) orelse false;

    const ondemand = b.option(
        bool,
        "ondemand",
        "use the ondemand parser for validation",
    ) orelse false;

    const ondemand_read_cap = b.option(
        u16,
        "ondemand-read-cap",
        "the capacity of the ondemand read buffer. defaults to 4096 (4 Kb)",
    ) orelse 4096;

    const lib = b.addStaticLibrary("simdjzon", "src/simdjzon.zig");
    setup(lib, mode, target, step_128, ondemand, ondemand_read_cap);
    lib.install();

    var main_tests = b.addTest("src/tests.zig");
    setup(main_tests, mode, target, step_128, ondemand, ondemand_read_cap);
    // main_tests.setFilter("ondemand array iteration");

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&main_tests.step);

    const exe = b.addExecutable("simdjzon", "src/main.zig");
    setup(exe, mode, target, step_128, ondemand, ondemand_read_cap);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args|
        run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
