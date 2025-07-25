//! Main cpu of the sega genesis
const Code = @import("m68k/Code.zig");
/// Illegal instruction handler
const illegal_handler = Code.empty;
const Cpu = @import("m68k/Cpu.zig");
const decoder = @import("m68k/decoder.zig");
const Exec = @import("m68k/Exec.zig");
const Main = @import("bus.zig").Main;

/// Run 1 instruction step on the cpu
pub fn step(cpu: *Cpu, bus: *const Main) usize {
    const dec = decoder.Decoder.init(&isa, illegal_handler);
    const code = dec.decode(cpu.*.ir);
    var exec = Exec.init(bus);
    code(cpu, &exec);
    return exec.clk;
}

/// Instruction set for the m68k
const isa = &.{
    decoder.Instr{
        .size = null,
        .opcode = .init("0100101011111100"),
        .format = "illegal",
        .code = illegal_handler,
    },
};
