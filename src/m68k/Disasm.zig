//! Disassembly engine for the m68k
const std = @import("std");

const MainBus = @import("../bus.zig").Main;
const Code = @import("Code.zig");
const dec = @import("decoder.zig");
const enc = @import("enc.zig");
const int = @import("int.zig");

/// The instruction set architecture this disassembler can decode
instrs: []const dec.Instr,

/// The runtime decoder for instruction type
decoder: dec.Decoder,

/// Creates a new disassembler
pub fn init(comptime instrs: []const dec.Instr) @This() {
    return .{
        .instrs = instrs,
        .decoder = dec.Decoder.init(dec.Matcher.extract(dec.Instr, instrs)),
    };
}

/// Dissasembles an instruction starting at the specified address
/// If what is at the address isn't a valid instruction, it will return null
pub fn disasm(comptime this: @This(), reader: *Reader) ?Instr {
    const start = reader.*.addr;
    const opcode = reader.*.fetch(u16);
    return switch (this.decoder.decode(opcode) orelse return null) {
        inline else => |index| Instr.disasm(this.instrs[index], opcode, start, reader) catch null,
    };
}

/// Represents state to read data from memory
pub const Reader = struct {
    /// The bus to read data from
    bus: *const MainBus,

    /// Where to read data from
    addr: u32,

    /// Fetch data from the bus at the address
    fn fetch(this: *@This(), comptime Type: type) Type {
        const bits = switch (@bitSizeOf(Type)) {
            8 => byte: {
                this.*.addr +%= 1;
                const shift = (this.addr & 1) * 8;
                const mask = @as(u16, 0xff00) >> shift;
                const byte: u8 = this.*.bus.*.read(@truncate(this.*.addr >> 1), mask) >> shift;
                this.*.addr +%= 1;
                break :byte byte;
            },
            16 => word: {
                const word: u16 = this.*.bus.*.read(@truncate(this.*.addr >> 1), 0x0000);
                this.*.addr +%= 2;
                break :word word;
            },
            32 => long: {
                const long: u32 =
                    @as(u32, this.*.bus.*.read(@truncate(this.*.addr >> 1), 0x0000)) << 16 |
                    @as(u32, this.*.bus.*.read(@truncate(this.*.addr +% 2 >> 1), 0x0000));
                this.*.addr +%= 4;
                break :long long;
            },
            else => |size| @compileError(std.fmt.comptimePrint(
                "Fetched size of {}, was expecting 8, 16, or 32",
                .{size},
            )),
        };
        return @bitCast(bits);
    }
};

/// The type that gets disassembled
pub const Instr = struct {
    /// The mnemonic of the instruction
    name: []const u8,

    /// The size of the instruction
    size: ?enc.Size,

    /// Operands to the instruction
    operands: std.BoundedArray(Operand, 2),

    /// The actual bytes that make up this instruction
    source: Source,

    /// Disassemble into an instruction from a reader
    fn disasm(comptime instr: dec.Instr, opcode: u16, start: u32, reader: *Reader) !@This() {
        // Set up the size and opcode source
        var this = @This(){
            .name = instr.name,
            .size = if (instr.size) |size| size.size(opcode) else null,
            .operands = .init(0) catch unreachable,
            .source = .init(opcode, start),
        };

        // Disassemble the opcodes
        if (try Operand.disasm(this.size, instr.code.info.src, &this.source, reader)) |operand| {
            try this.operands.append(operand);
        }
        if (try Operand.disasm(this.size, instr.code.info.dst, &this.source, reader)) |operand| {
            try this.operands.append(operand);
        }
        return this;
    }
};

/// Represents an instruction operand
pub const Operand = union(enum) {
    /// The operand is an effective address
    ea: EffAddr,

    /// Disassembles an operand
    fn disasm(comptime transfer: Code.Info.Transfer, source: *Source, reader: *Reader) !?@This() {
        return switch (transfer) {
            .none => null,
            .addr_mode => |encoding| EffAddr.disasm(encoding, source, reader),
        };
    }
};

/// Represents an effective-address
pub const EffAddr = union(enc.AddrMode) {
    /// Data register direct
    data_reg: u3,

    /// Address register direct
    addr_reg: u3,

    /// Address register indirect
    addr: u3,

    /// Address register indirect with post-increment
    addr_inc: u3,

    /// Address register indirect with pre-decrement
    addr_dec: u3,

    /// Address register indirect with 16-bit signed displacement
    addr_disp: Disp,

    /// Address register indirect with 8-bit signed displacement and signed index
    addr_idx: Index,

    /// PC relative with 16-bit signed displacement
    pc_disp: i16,

    /// PC relative with 8-bit signed displacement and signed index register
    pc_idx: Index,

    /// Absolute memory location refrenced by sign extended 16-bit word
    abs_short: u16,

    /// Absolute memory location
    abs_long: u32,

    /// Immediate data (found after the instruction word, 8-bit still takes up word)
    imm: u32,

    /// Disassemble an effective address
    fn disasm(
        size: ?enc.Size,
        comptime info: Code.AddrMode,
        source: *Source,
        reader: *Reader,
    ) !@This() {
        const word = source.opcode();
        return switch (info.decode(word) catch return error.InvalidEncoding) {
            .data_reg, .addr_reg, .addr, .addr_inc, .addr_dec => |mode| @unionInit(
                @This(),
                @tagName(mode),
                info.m(word),
            ),
            .addr_disp => .{ .addr_disp = try Disp.disasm(info.m(word), source, reader) },
            .addr_idx => .{ .addr_idx = try Index.disasm(info.m(word), source, reader) },
            .pc_disp => .{ .pc_disp = try source.*.fetch(i16, reader) },
            .pc_idx => .{ .pc_idx = try Index.disasm(null, source, reader) },
            .abs_short => .{ .abs_short = try source.*.fetch(u16, reader) },
            .abs_long => .{ .abs_long = try source.*.fetch(u32, reader) },
            .imm => .{ .imm = switch (size orelse return error.InvalidEncoding) {
                .byte => try source.*.fetch(u8, reader),
                .word => try source.*.fetch(u16, reader),
                .long => try source.*.fetch(u32, reader),
            } },
        };
    }

    /// Address register displacement instructions
    pub const Disp = struct {
        /// The displacement
        disp: i16,

        /// What register is the base
        base: u3,

        /// Disassembles a address displacement
        fn disasm(m: u3, source: *Source, reader: *Reader) error{Overflow}!@This() {
            return .{
                .base = m,
                .disp = try source.*.fetch(i16, reader),
            };
        }
    };

    /// Address register and program counter indexed instructions
    pub const Index = struct {
        /// What register is the base (null if pc)
        base: ?u3,

        /// The index register, and displacement
        ext: enc.ExtWord,

        /// Disassembles a address index
        fn disasm(m: ?u3, source: *Source, reader: *Reader) error{Overflow}!@This() {
            return .{
                .base = m,
                .ext = try source.*.fetch(enc.ExtWord, reader),
            };
        }
    };
};

/// Represents data that pertains to the instruction
pub const Source = struct {
    /// Where the bytes start
    addr: u32,

    /// The bytes that make up the instruction
    bytes: std.BoundedArray(u8, 10),

    /// Get the opcode from the source data
    pub fn opcode(this: @This()) u16 {
        return std.mem.readInt(u16, this.bytes.buffer[0..2], .big);
    }

    /// Create a new source recorder
    fn init(start_opcode: u16, start_addr: u32) @This() {
        var this = @This(){
            .addr = start_addr,
            .bytes = .init(0) catch unreachable,
        };
        this.record(start_opcode);
        return this;
    }

    /// Fetches data with the reader and records it
    fn fetch(this: *@This(), comptime Data: type, reader: *Reader) error{Overflow}!Data {
        const data = reader.*.fetch(Data);
        try this.record(data);
        return data;
    }

    /// Writes source type to the source buffer
    /// If the data type is a byte long, it will make it a word and make the byte the lower 8 bits
    fn record(this: *@This(), data: anytype) error{Overflow}!void {
        const size = @min(2, @sizeOf(@TypeOf(data)));
        var bytes: [size]u8 = undefined;
        std.mem.writeInt(
            std.meta.Int(.unsigned, size * 8),
            &bytes,
            @as(std.meta.Int(.unsigned, @bitSizeOf(@TypeOf(data))), @bitCast(data)),
            .big,
        );
        try this.*.bytes.appendSlice(bytes);
    }
};
