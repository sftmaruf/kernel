const ProcessState = enum {
    ready,
    running,
    blocked,
    terminated,
};

pub const Process = struct {
    pid: u32,
    state: ProcessState,
    name: []const u8,
};
