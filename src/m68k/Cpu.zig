//! Main state of the cpu

/// General purpose data registers
d: [8]u32 = [1]u32{0} ** 8,

/// Address registers a7 is stack pointer
a: [8]u32 = [1]u32{0} ** 8,

/// Program counter
pc: u32 = 0,

/// Status register
sr: Status = .{},

/// Instruction register
ir: u16 = 0,

/// Status register flags
pub const Status = packed struct {
    /// Carry flag, did the previous math instruction overflow?
    c: u1 = 0,

    /// Overflow flag, did the previous math instruction encounter signed overflow?
    v: u1 = 0,

    /// Zero flag, was the result zero?
    z: u1 = 0,

    /// Negative flag, was the result negative or was the msb set?
    n: u1 = 0,

    /// Like a copy of the carry flag, but updated by less instructions
    x: u1 = 0,

    /// Unused space
    reserved: u3 = 0,

    /// Interrupt priority level. Interrupts <= ipl are ignored
    ipl: u3 = 0,

    /// Unused space
    padding: u1 = 0,

    /// Master/interrupt flag, unused on original m68k
    m: u1 = 0,

    /// Supervisor flag, practically unused on the sega genesis, basically privalege bit
    s: u1 = 1,

    /// Trace flag, only defined values on m68k are 0 (off) and 2 (on)
    t: u2 = 0,
};
