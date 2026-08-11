pub const CpuContext = struct {
    // represents next instruction cpu will execute
    instruction_pointer: usize,
    stack_pointer: usize,

    register_a: usize,
    register_b: usize,
};
