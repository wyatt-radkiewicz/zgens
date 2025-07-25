//! Execution context (in an instruction, or other handlers)
const std = @import("std");

const Main = @import("../bus.zig").Main;
const Cpu = @import("Cpu.zig");
const int = @import("int.zig");

/// The bus interface
bus: *const Main,

/// Effective address loaded value/store value
ea_data: u32,

/// Effective address
ea_addr: u32,

/// The number of cycles processed so far
clk: usize,

/// The initial state of the execution context
pub fn init(bus: *const Main) @This() {
    return .{
        .bus = bus,
        .ea_addr = 0,
        .ea_data = 0,
        .clk = 0,
    };
}

/// Read an integer from the bus and add the processing time
pub fn read(this: *@This(), comptime width: u16, addr: u32) std.meta.Int(.unsigned, width) {
    switch (width) {
        8 => {
            this.*.clk += 4;
            const shift = (addr & 1) * 8;
            const mask = @as(u16, 0xff00) >> shift;
            return this.*.b.*.read(@truncate(addr >> 1), mask) >> shift;
        },
        16 => {
            this.*.clk += 4;
            return this.*.b.*.read(@truncate(addr >> 1), 0x0000);
        },
        32 => {
            this.*.clk += 8;
            return @as(u32, this.*.b.*.read(@truncate(addr >> 1), 0x0000)) << 16 |
                @as(u32, this.*.b.*.read(@truncate(addr + 2 >> 1), 0x0000));
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
            const shift = (addr & 1) * 8;
            const mask = @as(u16, 0xff00) >> shift;
            this.*.b.*.write(@truncate(addr >> 1), mask, value << shift);
        },
        16 => {
            this.*.clk += 4;
            this.*.b.*.write(@truncate(addr >> 1), 0x0000, value);
        },
        32 => {
            this.*.clk += 8;
            this.*.b.*.write(@truncate(addr >> 1), 0x0000, @truncate(value >> 16));
            this.*.b.*.write(@truncate(addr + 2 >> 1), 0x0000, @truncate(value));
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
    const Encoding = packed struct {
        /// 8 bit signed displacement
        disp: i8,

        /// 3 bit padding
        padding: u3,

        /// Size bit 0 => word, 1 => long
        size: u1,

        /// Register number (data register or address register)
        n: u3,

        /// Addressing mode 0 => data register, 1 => address register
        m: u1,
    };

    const enc: Encoding = @bitCast(this.*.fetch(16, cpu));
    const disp = int.extend(u32, enc.disp);
    const idx = int.extend(u32, switch (enc.m) {
        0 => cpu.*.d[enc.n],
        1 => cpu.*.d[enc.n],
    });
    return disp +% idx;
}
