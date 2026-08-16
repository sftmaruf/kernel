const std = @import("std");
const kernel = @import("kernel.zig");

const Kernel = kernel.Kernel;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var k = Kernel.init(allocator);
    defer k.deinit();

    // think like the shell need 3 ticks to complete the process
    // here ticks are for simulation in real life we don't know
    // how much tick a process may need. Eventually we will get
    // rid of it later.
    try k.create_process("shell", 3);
    try k.create_process("worker", 100);
    try k.create_process("shell", 4);

    // here we are simulating total 10 CPU ticks
    for (0..107) |_| {
        k.tick();
    }

    k.printProcess();
}
