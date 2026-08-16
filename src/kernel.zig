const std = @import("std");
const process_ref = @import("process.zig");
const logger = @import("helper/logger.zig");
const cpu_ref = @import("hardware/cpu.zig");

const CPU = cpu_ref.CPU;
const Process = process_ref.Process;

pub const Kernel = struct {
    allocator: std.mem.Allocator,
    processes: std.ArrayList(Process),
    next_pid: u32,
    current_pid: ?u32,
    // represent the next process which will get the cpu time
    next_process_index: usize,
    cpu: CPU,
    quantum: usize,

    pub fn init(allocator: std.mem.Allocator) Kernel {
        return Kernel{
            .allocator = allocator,
            .next_pid = 1,
            .processes = .empty,
            .current_pid = null,
            .next_process_index = 0,
            .cpu = CPU.init(),
            .quantum = 5,
        };
    }

    pub fn deinit(self: *Kernel) void {
        self.processes.deinit(self.allocator);
    }

    pub fn create_process(self: *Kernel, name: []const u8, cpu_burst: usize) !void {
        logger.info("Creating a process");

        const process = Process{
            .pid = self.next_pid,
            .state = .ready,
            .name = name,

            .quantum_used = 0,
            .remaining_time = cpu_burst,

            .context = .{
                .pc = self.next_pid * 100,
                .sp = 1000,
                .r0 = 0,
                .r1 = 0,
                .r2 = 0,
                .r3 = 0,
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
    pub fn scheduleProcess(self: *Kernel) void {
        logger.info("\nInstructed to schedule process");

        // already one process running
        if (self.current_pid) |_| {
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
                self.current_pid = process.pid;
                process.quantum_used = 0;
                self.cpu.restoreContext(process.context);

                logger.infof(
                    "PID: [{d}] scheduled. Restoring PC: {d}. Transitioned [ready] to [running]",
                    .{ process.pid, process.context.pc },
                );

                return;
            }
        }

        std.debug.print("No runnable process", .{});
    }

    pub fn runProcess(self: *Kernel) void {
        logger.info("Instructed to run the current process");

        if (self.current_pid) |pid| {
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
                self.cpu.executeInstruction();

                process.remaining_time -= 1;
                process.quantum_used += 1;

                logger.infof(
                    "PID: [{d}] executed instruction. Next PC: {d}, Remaining time: {d}",
                    .{
                        process.pid,
                        self.cpu.pc,
                        process.remaining_time,
                    },
                );
            }

            if (process.remaining_time == 0) {
                process.context = self.cpu.saveContext();
                process.state = .terminated;
                self.current_pid = null;

                logger.infof("PID: [{d}] has terminated", .{process.pid});
            }
        }
    }

    pub fn terminateProcess(self: *Kernel) void {
        if (self.current_pid) |pid| {
            if (self.find_process(pid)) |process| {
                process.context = self.cpu.saveContext();
                process.state = .terminated;
            }

            self.current_pid = null;
        }
    }

    // if the cpu time doesn't needed by a process.
    // it will yield and return to ready state.
    pub fn yield(self: *Kernel) void {
        if (self.current_pid == null) {
            return;
        }

        const pid = self.current_pid.?;
        if (self.find_process(pid)) |process| {
            process.context = self.cpu.saveContext();
            process.state = .ready;

            logger.infof(
                "PID: [{d}] yielded. Saved PC: {d}",
                .{
                    process.pid,
                    process.context.pc,
                },
            );
        }

        self.current_pid = null;
    }

    fn tryPreempt(self: *Kernel) void {
        if (self.current_pid == null) return;

        const current_process_id = self.current_pid.?;
        const current_process_result = self.find_process(current_process_id);
        if (current_process_result == null) return;

        const current_process = current_process_result.?;
        if (current_process.quantum_used >= self.quantum) {
            current_process.context = self.cpu.saveContext();
            current_process.state = .ready;
            self.current_pid = null;

            logger.infof(
                "PID: [{d}] preempted. Saved PC: {d}",
                .{
                    current_process.pid,
                    current_process.context.pc,
                },
            );
        }
    }

    // tick will schedule a process and give the process 1 tick process time
    pub fn tick(self: *Kernel) void {
        if (self.current_pid == null) {
            self.scheduleProcess();
        }

        self.runProcess();

        self.tryPreempt();

        // if (self.current_pid != null) {
        //     self.yield();
        // }
    }

    pub fn printProcess(self: *Kernel) void {
        std.debug.print("\nProcesses and their current status:\n", .{});

        for (self.processes.items) |process| {
            std.debug.print(
                "PID {d}: {s} [{s}] | PC: {d}\n",
                .{
                    process.pid,
                    process.name,
                    @tagName(process.state),
                    process.context.pc,
                },
            );
        }
    }
};
