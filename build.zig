const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const qemu_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .none,
        .cpu_features_sub = std.Target.x86.featureSet(&.{
            .sse,
            .sse2,
        }),
    });

    const vga_mod = b.createModule(.{
        .root_source_file = b.path("src/vga.zig"),
        .target = qemu_target,
        .optimize = optimize,
        .red_zone = false,
        .imports = &.{},
    });

    const kernel_mod = b.createModule(.{
        .root_source_file = b.path("src/kernel.zig"),
        .target = qemu_target,
        .optimize = optimize,
        .red_zone = false,
        .imports = &.{
            .{ .name = "vga", .module = vga_mod },
        },
    });

    const qemu_mod = b.createModule(.{
        .root_source_file = b.path("src/boot/main.zig"),
        .target = qemu_target,
        .optimize = optimize,
        .red_zone = false,
        .imports = &.{
            .{ .name = "kernel", .module = kernel_mod },
            .{ .name = "vga", .module = vga_mod },
        },
    });

    const qemu_kernel = b.addExecutable(.{
        .name = "firmware",
        .root_module = qemu_mod,
    });

    qemu_kernel.setLinkerScript(b.path("src/boot/linker.ld"));
    b.installArtifact(qemu_kernel);

    const run_qemu = b.step("run-qemu", "Boot the kernel in QEMU");
    if (b.findProgram(&.{"qemu-system-i386"}, &.{})) |qemu| {
        const run_qemu_cmd = b.addSystemCommand(&.{
            qemu,
            "-display",
            "none",
            "-serial",
            "stdio",
            "-kernel",
        });
        run_qemu_cmd.addArtifactArg(qemu_kernel);
        run_qemu_cmd.step.dependOn(b.getInstallStep());
        run_qemu.dependOn(&run_qemu_cmd.step);
    } else |_| {
        std.debug.print(
            "warning: qemu-system-i386 not found on PATH; install it to use the run-qemu step.\n",
            .{},
        );
        run_qemu.dependOn(&b.addSystemCommand(&.{"false"}).step);
    }
}
