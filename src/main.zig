const std = @import("std");
const kernel = @import("kernel.zig");

const Kernel = kernel.Kernel;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var k = Kernel.init(allocator);
    defer k.deinit();

    _ = try k.create_process("shell");
    _ = try k.create_process("worker");

    k.print_processes();

    // std.debug.print("Next PID: {}\n", .{k.next_pid});
}
