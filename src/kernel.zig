const std = @import("std");
const process_ref = @import("process.zig");
const logger = @import("helper/logger.zig");

const Process = process_ref.Process;

pub const Kernel = struct {
    allocator: std.mem.Allocator,
    next_pid: u32,
    processes: std.ArrayList(Process),
    current_process: ?u32,

    pub fn init(allocator: std.mem.Allocator) Kernel {
        return Kernel{
            .allocator = allocator,
            .next_pid = 1,
            .processes = .{},
            .current_process = null,
        };
    }

    pub fn deinit(self: *Kernel) void {
        self.processes.deinit(self.allocator);
    }

    pub fn create_process(self: *Kernel, name: []const u8) !void {
        logger.info("Creating a process");

        const process = Process{
            .pid = self.next_pid,
            .state = .ready,
            .name = name,
        };

        try self.processes.append(self.allocator, process);
        self.next_pid += 1;

        logger.infof("Process created with id: {}\n", .{process.pid});
    }

    pub fn find_process(self: *Kernel, pid: u32) ?*Process {
        for (self.processes.items) |*process| {
            if (process.pid == pid) {
                return process;
            }
        }

        return null;
    }

    pub fn run_process(self: *Kernel, pid: u32) bool {
        const process = self.find_process(pid) orelse return false;
        if (process.state != .ready) return false;

        process.state = .running;

        return true;
    }

    // we are implementing a very simple scheduling mechanism,
    // just schedule the next ready process
    pub fn schedule_process(self: *Kernel) ?*Process {

        // already one process running
        if (self.current_process) |pid| {
            return self.find_process(pid);
        }

        // find the next ready process
        var next_ready_process: ?*Process = null;
        for (self.processes.items) |*process| {
            if (process.state == .ready) {
                next_ready_process = process;
                break;
            }
        }

        // run the process and return
        if (next_ready_process) |process| {
            _ = self.run_process(process.pid);
            self.current_process = process.pid;
            return process;
        }

        return null;
    }

    pub fn terminate_process(self: *Kernel) void {
        if (self.current_process) |pid| {
            if (self.find_process(pid)) |p| {
                p.state = .terminated;
            }

            self.current_process = null;
        }
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
