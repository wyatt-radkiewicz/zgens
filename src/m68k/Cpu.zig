//! Main state of the cpu

/// General purpose data registers
d: [8]u32,

/// Address registers a7 is stack pointer
a: [8]u32,

/// Program counter
pc: u32,

/// Status register
sr: Status,

/// Instruction register
ir: u16,

/// Status register flags
pub const Status = packed struct {
    /// Carry flag, did the previous math instruction overflow?
    c: bool,

    /// Overflow flag, did the previous math instruction encounter signed overflow?
    v: bool,

    /// Zero flag, was the result zero?
    z: bool,

    /// Negative flag, was the result negative or was the msb set?
    n: bool,

    /// Like a copy of the carry flag, but updated by less instructions
    x: bool,

    /// Unused space
    reserved: u3,

    /// Interrupt priority level. Interrupts <= ipl are ignored
    ipl: u3,

    /// Unused space
    padding: u1,

    /// Master/interrupt flag, unused on original m68k
    m: bool,

    /// Supervisor flag, practically unused on the sega genesis, basically privalege bit
    s: bool,

    /// Trace flag, only defined values on m68k are 0 (off) and 2 (on)
    t: u2,
};
