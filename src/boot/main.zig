const std = @import("std");
const kernel = @import("kernel");
const vga = @import("vga");

// ── Multiboot 1 header ──────────────────────────────────────────────────
const MULTIBOOT_MAGIC: u32 = 0x1BADB002;
const MULTIBOOT_FLAGS: u32 = 0x00;
const MULTIBOOT_CHECKSUM: u32 = @as(u32, 0) -% MULTIBOOT_MAGIC -% MULTIBOOT_FLAGS;

const MultibootHeader = extern struct {
    magic: u32 = MULTIBOOT_MAGIC,
    flags: u32 = MULTIBOOT_FLAGS,
    checksum: u32 = MULTIBOOT_CHECKSUM,
};

export const multiboot_header: MultibootHeader linksection(".multiboot") = .{};

// ── Stack ────────────────────────────────────────────────────────────────
const STACK_SIZE = 16 * 1024;
export var stack_bytes: [STACK_SIZE]u8 align(16) linksection(".bss") = undefined;

// ── Entry point ──────────────────────────────────────────────────────────
export fn _start() callconv(.naked) noreturn {
    asm volatile (
        \\.extern stack_bytes
        \\lea stack_bytes + 16384, %%esp
        \\jmp kmain
    );
}

// ── Kernel main ──────────────────────────────────────────────────────────
export fn kmain() noreturn {
    vga.serial_init();

    var k = kernel.Kernel.init();

    k.create_process("shell", 3) catch {};
    k.create_process("worker", 2) catch {};
    k.create_process("shell", 4) catch {};

    for (0..10) |_| {
        k.tick();
    }

    k.print_processes();

    while (true) {
        asm volatile ("hlt");
    }
}

// ── Panic handler ────────────────────────────────────────────────────────
pub fn panic(_: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}
