//! Main m68k file
const Main = @import("bus").Main;

pub const Cpu = @import("Cpu.zig");
const decoder = @import("decoder.zig");
const Exec = @import("Exec.zig");
const isa = @import("isa.zig");

/// Run the emulator for one instruction step
pub fn step(cpu: *Cpu, bus: *const Main) usize {
    var exec = Exec.init(bus);
    if (decoder.decode(isa.isa, cpu.*.ir)) |code| {
        code(cpu, &exec);
    }
    return exec.clk;
}

test "m68k" {
    _ = isa;
}
