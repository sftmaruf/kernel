const std = @import("std");
const process_ref = @import("process.zig");
const logger = @import("helper/logger.zig");

const Process = process_ref.Process;

pub const Kernel = struct {
    allocator: std.mem.Allocator,
    next_pid: u32,
    processes: std.ArrayList(Process),

    pub fn init(allocator: std.mem.Allocator) Kernel {
        return Kernel{
            .allocator = allocator,
            .next_pid = 1,
            .processes = .{},
        };
    }

    pub fn deinit(self: *Kernel) void {
        self.processes.deinit(self.allocator);
    }

    pub fn create_process(self: *Kernel, name: []const u8) !*Process {
        logger.info("Creating a process");

        const process = Process{
            .pid = self.next_pid,
            .state = .ready,
            .name = name,
        };

        try self.processes.append(self.allocator, process);
        self.next_pid += 1;

        logger.infof("Process created with id: {}\n", .{process.pid});

        return &self.processes.items[self.processes.items.len - 1];
    }

    pub fn print_processes(self: *Kernel) void {
        for (self.processes.items) |process| {
            std.debug.print(
                "PID {d}: {s} [{s}]\n",
                .{ process.pid, process.name, @tagName(process.state) },
            );
        }
    }
};
