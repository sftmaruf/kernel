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
    _ = try k.create_process("shell");

    if (k.find_process(2)) |process| {
        std.debug.print(
            "Found process: PID={}, state={}\n",
            .{ process.pid, process.state },
        );
    }

    k.print_processes();

    // std.debug.print("Next PID: {}\n", .{k.next_pid});
}
