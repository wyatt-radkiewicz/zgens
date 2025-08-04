//! Execution context (in an instruction, or other handlers)
const std = @import("std");

const bus_interface = @import("bus");
const Cpu = @import("Cpu.zig");
const enc = @import("enc.zig");
const int = @import("int.zig");

/// The bus interface
bus: *const bus_interface.Bus(.main),

/// Effective address information
ea: Ea.Type,

/// The number of cycles processed so far
clk: usize,

/// The initial state of the execution context
pub fn init(bus: *const bus_interface.Bus(.main)) @This() {
    return .{
        .bus = bus,
        .ea = .{},
        .clk = 0,
    };
}

/// Read an integer from the bus and add the processing time
pub fn read(this: *@This(), comptime width: u16, addr: u32) std.meta.Int(.unsigned, width) {
    switch (width) {
        8 => {
            this.*.clk += 4;
            const shift: u4 = @intCast((addr & 1) * 8);
            const mask = @as(u16, 0xff00) >> shift;
            return @truncate(this.*.bus.*.read(@truncate(addr >> 1), mask) >> shift);
        },
        16 => {
            this.*.clk += 4;
            return this.*.bus.*.read(@truncate(addr >> 1), 0x0000);
        },
        32 => {
            this.*.clk += 8;
            return @as(u32, this.*.bus.*.read(@truncate(addr >> 1), 0x0000)) << 16 |
                @as(u32, this.*.bus.*.read(@truncate(addr + 2 >> 1), 0x0000));
        },
        else => @compileError(std.fmt.comptimePrint("Tried to read int of size {}", .{width})),
    }
}

/// Write an integer to the bus and add the processing time
pub fn write(
    this: *@This(),
    comptime width: u16,
    addr: u32,
    value: std.meta.Int(.unsigned, width),
) void {
    switch (width) {
        8 => {
            this.*.clk += 4;
            const shift: u4 = @intCast((addr & 1) * 8);
            const mask = @as(u16, 0xff00) >> shift;
            this.*.bus.*.write(@truncate(addr >> 1), mask, @as(u16, value) << shift);
        },
        16 => {
            this.*.clk += 4;
            this.*.bus.*.write(@truncate(addr >> 1), 0x0000, value);
        },
        32 => {
            this.*.clk += 8;
            this.*.bus.*.write(@truncate(addr >> 1), 0x0000, @truncate(value >> 16));
            this.*.bus.*.write(@truncate(addr +% 2 >> 1), 0x0000, @truncate(value));
        },
        else => @compileError(std.fmt.comptimePrint("Tried to write int of size {}", .{width})),
    }
}

/// Fetch data from the program counter
pub fn fetch(this: *@This(), comptime width: u16, cpu: *Cpu) std.meta.Int(.unsigned, width) {
    const aligned_width = switch (width) {
        8 => 16,
        16, 32 => |value| value,
        else => @compileError(std.fmt.comptimePrint("Tried to fetch int of size {}", .{width})),
    };
    const data = this.*.read(aligned_width, cpu.*.pc);
    cpu.*.pc += aligned_width / 8;
    return @truncate(data);
}

/// Fetch an extension word and get the full-width displacement
pub fn extword(this: *@This(), cpu: *Cpu) u32 {
    const word: enc.ExtWord = @bitCast(this.*.fetch(16, cpu));
    const disp = int.extend(u32, word.disp);
    const idx = int.extend(u32, switch (word.m) {
        0 => cpu.*.d[word.n],
        1 => cpu.*.d[word.n],
    });
    return disp +% idx;
}

/// Effective address information
pub const Ea = struct {
    /// Effective address loaded value/store value
    data: u32 = 0,

    /// Effective address
    addr: u32 = 0,

    /// Effective address types
    pub const Type = struct {
        /// Destination
        dst: Ea = .{},

        /// Source
        src: Ea = .{},
    };
};
