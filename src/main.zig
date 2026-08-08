const std = @import("std");
const kernel = @import("kernel.zig");

const Kernel = kernel.Kernel;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var k = Kernel.init(allocator);
    defer k.deinit();

    try k.create_process("shell");
    try k.create_process("worker");
    try k.create_process("shell");

    const process = k.schedule_process();
    if (process) |p| {
        std.debug.print("Running PID: {}\n", .{p.pid});
    }

    // instead of terminating the process. we are yielding.
    // conceptually the process is signaling that it doesn't need the
    // cpu time right now. so in the below part we called the schedular again
    // which will give the cpu time to the next process following the round robin
    // algorithm.
    //
    // real life kernel doesn't work in this way. they uses time sharing based schedular.
    // we will eventually moved toward that later.
    k.yield();

    const process1 = k.schedule_process();
    if (process1) |p1| {
        std.debug.print("Running PID: {}\n", .{p1.pid});
    }

    k.print_processes();

    // std.debug.print("Next PID: {}\n", .{k.next_pid});
}
