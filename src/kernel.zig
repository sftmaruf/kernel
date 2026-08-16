const std = @import("std");
const process_ref = @import("process.zig");
const logger = @import("helper/logger.zig");

const Process = process_ref.Process;

pub const Kernel = struct {
    allocator: std.mem.Allocator,
    next_pid: u32,
    processes: std.ArrayList(Process),
    current_process: ?u32,
    // represent the next process which will get the cpu time
    next_process_index: usize,

    pub fn init(allocator: std.mem.Allocator) Kernel {
        return Kernel{
            .allocator = allocator,
            .next_pid = 1,
            .processes = .empty,
            .current_process = null,
            .next_process_index = 0,
        };
    }

    pub fn deinit(self: *Kernel) void {
        self.processes.deinit(self.allocator);
    }

    pub fn create_process(self: *Kernel, name: []const u8, execution_time: usize) !void {
        logger.info("Creating a process");

        const process = Process{
            .pid = self.next_pid,
            .state = .ready,
            .name = name,

            .cpu_time = 0,
            .remaining_time = execution_time,

            .context = .{
                .instruction_pointer = 0,
                .stack_pointer = 1000,
                .register_a = 0,
                .register_b = 0,
            },
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

    // we moved to a simple round robin based scheduler.
    pub fn schedule_process(self: *Kernel) void {
        logger.info("\nInstructed to schedule process");

        // already one process running
        if (self.current_process) |_| {
            return;
        }

        if (self.processes.items.len == 0) {
            return;
        }

        const count = self.processes.items.len;

        for (0..count) |_| {
            const process = &self.processes.items[self.next_process_index];
            self.next_process_index = (self.next_process_index + 1) % count;

            if (process.state == .ready) {
                process.state = .running;
                self.current_process = process.pid;

                logger.infof("PID: [{d}] scheduled. Transitioned [ready] to [running]", .{process.pid});

                return;
            }
        }

        std.debug.print("No runnable process", .{});
    }

    pub fn run_process(self: *Kernel) void {
        logger.info("Instructed to run the current process");

        if (self.current_process) |pid| {
            const result = self.find_process(pid);

            if (result == null) {
                logger.infof("PID: [{d}] not found", .{pid});
                return;
            }

            const process = result.?;

            if (process.state != .running) {
                logger.infof("Process [{d}] is not running", .{process.pid});
                return;
            }

            if (process.remaining_time > 0) {
                process.remaining_time -= 1;
                process.cpu_time += 1;

                logger.infof("PID: [{d}] is executed from 1 tick, Remaining time: {d}", .{ process.pid, process.remaining_time });
            }

            if (process.remaining_time == 0) {
                process.state = .terminated;
                self.current_process = null;

                logger.infof("PID: [{d}] has terminated", .{process.pid});
            }
        }
    }

    pub fn terminate_process(self: *Kernel) void {
        if (self.current_process) |pid| {
            if (self.find_process(pid)) |p| {
                p.state = .terminated;
            }

            self.current_process = null;
        }
    }

    // if the cpu time doesn't needed by a process.
    // it will yield and return to ready state.
    pub fn yield(self: *Kernel) void {
        if (self.current_process == null) {
            return;
        }

        const pid = self.current_process.?;
        if (self.find_process(pid)) |process| {
            process.state = .ready;
        }

        self.current_process = null;
    }

    // tick will schedule a process and give the process 1 tick process time
    pub fn tick(self: *Kernel) void {
        if (self.current_process == null) {
            self.schedule_process();
        }

        self.run_process();

        if (self.current_process != null) {
            self.yield();
        }
    }

    pub fn print_processes(self: *Kernel) void {
        std.debug.print("\nProcesses and their current status:\n", .{});

        for (self.processes.items) |process| {
            std.debug.print(
                "PID {d}: {s} [{s}]\n",
                .{ process.pid, process.name, @tagName(process.state) },
            );
        }
    }
};
