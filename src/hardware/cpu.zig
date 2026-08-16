const CpuContext = @import("../cpu_context.zig").CpuContext;

pub const CPU = struct {
    pc: usize, // program counter
    sp: usize, // stack pointer

    // registers
    r0: usize,
    r1: usize,
    r2: usize,
    r3: usize,

    pub fn init() CPU {
        return .{
            .pc = 0,
            .sp = 0,
            .r0 = 0,
            .r1 = 0,
            .r2 = 0,
            .r3 = 0,
        };
    }

    pub fn executeInstruction(self: *CPU) void {
        self.pc += 1;
    }

    pub fn saveContext(self: *const CPU) CpuContext {
        return .{
            .pc = self.pc,
            .sp = self.sp,
            .r0 = self.r0,
            .r1 = self.r1,
            .r2 = self.r2,
            .r3 = self.r3,
        };
    }

    pub fn restoreContext(self: *CPU, ctx: CpuContext) void {
        self.pc = ctx.pc;
        self.sp = ctx.sp;
        self.r0 = ctx.r0;
        self.r1 = ctx.r1;
        self.r2 = ctx.r2;
        self.r3 = ctx.r3;
    }
};
