const process_ref = @import("process.zig");
const vga = @import("vga");

const Process = process_ref.Process;

const MAX_PROCESSES = 16;

pub const Kernel = struct {
    next_pid: u32,
    processes: [MAX_PROCESSES]Process,
    process_count: usize,
    current_process: ?u32,
    next_process_index: usize,

    pub fn init() Kernel {
        return Kernel{
            .next_pid = 1,
            .processes = undefined,
            .process_count = 0,
            .current_process = null,
            .next_process_index = 0,
        };
    }

    pub fn create_process(self: *Kernel, name: []const u8, execution_time: usize) !void {
        if (self.process_count >= MAX_PROCESSES) return error.TooManyProcesses;

        vga.print_fmt("Creating a process\n", .{});

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

        self.processes[self.process_count] = process;
        self.process_count += 1;
        self.next_pid += 1;

        vga.print_fmt("Process created with id: {d}\n", .{process.pid});
    }

    pub fn find_process(self: *Kernel, pid: u32) ?*Process {
        for (self.processes[0..self.process_count]) |*process| {
            if (process.pid == pid) {
                return process;
            }
        }
        return null;
    }

    pub fn schedule_process(self: *Kernel) void {
        vga.print_fmt("\nInstructed to schedule process\n", .{});

        if (self.current_process) |_| return;
        if (self.process_count == 0) return;

        const count = self.process_count;

        for (0..count) |_| {
            const process = &self.processes[self.next_process_index];
            self.next_process_index = (self.next_process_index + 1) % count;

            if (process.state == .ready) {
                process.state = .running;
                self.current_process = process.pid;
                vga.print_fmt("PID: [{d}] scheduled. Transitioned [ready] to [running]\n", .{process.pid});
                return;
            }
        }

        vga.print_fmt("No runnable process\n", .{});
    }

    pub fn run_process(self: *Kernel) void {
        vga.print_fmt("Instructed to run the current process\n", .{});

        if (self.current_process) |pid| {
            const result = self.find_process(pid);

            if (result == null) {
                vga.print_fmt("PID: [{d}] not found\n", .{pid});
                return;
            }

            const process = result.?;

            if (process.state != .running) {
                vga.print_fmt("Process [{d}] is not running\n", .{process.pid});
                return;
            }

            if (process.remaining_time > 0) {
                process.remaining_time -= 1;
                process.cpu_time += 1;
                vga.print_fmt("PID: [{d}] is executed from 1 tick, Remaining time: {d}\n", .{ process.pid, process.remaining_time });
            }

            if (process.remaining_time == 0) {
                process.state = .terminated;
                self.current_process = null;
                vga.print_fmt("PID: [{d}] has terminated\n", .{process.pid});
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

    pub fn yield(self: *Kernel) void {
        if (self.current_process == null) return;

        const pid = self.current_process.?;
        if (self.find_process(pid)) |process| {
            process.state = .ready;
        }

        self.current_process = null;
    }

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
        vga.print_fmt("\nProcesses and their current status:\n", .{});

        for (self.processes[0..self.process_count]) |process| {
            vga.print_fmt("PID {d}: {s} [{s}]\n", .{ process.pid, process.name, @tagName(process.state) });
        }
    }
};
