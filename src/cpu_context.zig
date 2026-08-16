pub const CpuContext = struct {
    pc: usize, // program counter
    sp: usize, // stack pointer

    // registers
    r0: usize,
    r1: usize,
    r2: usize,
    r3: usize,
};
