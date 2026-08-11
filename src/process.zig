const CpuContext = @import("cpu_context.zig").CpuContext;

const ProcessState = enum {
    new,
    ready,
    running,
    blocked,
    terminated,
};

pub const Process = struct {
    pid: u32,
    state: ProcessState,
    name: []const u8,
    // cpu time still required
    remaining_time: usize,
    // cpu time already consumed
    cpu_time: usize,

    // save cpu context
    context: CpuContext,
};
