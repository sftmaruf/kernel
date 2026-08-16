const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "kernel",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            // Emit valgrind client requests so the runtime integrates cleanly
            // with valgrind's leak checker (used by `zig build run-valgrind`).
            .valgrind = true,
            .target = target,
            .optimize = optimize,
            .imports = &.{},
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);

    const run_valgrind = b.step("run-valgrind", "Run the executable under valgrind's memory leak checker");

    if (b.findProgram(&.{"valgrind"}, &.{})) |valgrind| {
        const valgrind_cmd = b.addSystemCommand(&.{
            valgrind,
            "--error-exitcode=1",
            "--leak-check=full",
            "--show-leak-kinds=definite,indirect",
            "--errors-for-leak-kinds=definite,indirect",
        });
        valgrind_cmd.addArtifactArg(exe);

        run_valgrind.dependOn(&valgrind_cmd.step);
    } else |_| {
        // Fail loudly instead of silently passing when valgrind is missing.
        std.debug.print(
            "warning: valgrind not found on PATH; install it (e.g. `sudo apt install valgrind`) to use the check-valgrind step.\n",
            .{},
        );
        run_valgrind.dependOn(&b.addSystemCommand(&.{"false"}).step);
    }
}
