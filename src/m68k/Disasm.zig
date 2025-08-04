//! Disassembly engine for the m68k
const std = @import("std");

const bus_interface = @import("bus");

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
pub fn disasm(comptime this: @This(), reader: *Reader) ?View {
    @setEvalBranchQuota(1000000000);
    var source = Source.init(reader);
    const instr = switch (this.decoder.decode(source.opcode()) orelse return null) {
        inline else => |index| if (index < this.instrs.len)
            Instr.disasm(this.instrs[index], &source, reader)
        else
            error.InvalidEncoding,
    } catch return null;
    return .{
        .source = source,
        .decoded = instr,
    };
}

/// Represents state to read data from memory
pub const Reader = struct {
    /// The bus to read data from
    bus: *const bus_interface.Bus(.main),

    /// Where to read data from
    addr: u32,

    /// Fetch data from the bus at the address
    fn fetch(this: *@This(), comptime Type: type) Type {
        const bits = switch (@bitSizeOf(Type)) {
            8 => byte: {
                this.*.addr +%= 1;
                const shift = @as(u4, @truncate(this.addr & 1)) * 8;
                const mask = @as(u16, 0xff00) >> shift;
                const byte: u8 = @truncate(this.*.bus.*.read(
                    @truncate(this.*.addr >> 1),
                    mask,
                ) >> shift);
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

/// The result of disassembling at an address
pub const View = struct {
    /// The bytes that the instruction came from
    source: Source,

    /// Ast of the instruction
    decoded: Instr,
};

/// Represents data that pertains to the instruction
pub const Source = struct {
    /// Where the bytes start
    addr: u32,

    /// The bytes that make up the instruction
    words: std.BoundedArray(u16, 10),

    /// Get the opcode from the source data
    pub fn opcode(this: @This()) u16 {
        return this.words.buffer[0];
    }

    /// Create a new source recorder
    fn init(reader: *Reader) @This() {
        var this = @This(){
            .addr = reader.*.addr,
            .words = .{},
        };
        this.record(reader.*.fetch(u16)) catch unreachable;
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
        // Get the size of the data, and the size rounded up to the nearest word
        const size = @sizeOf(@TypeOf(data));
        const words = size + 1 >> 1;

        // Write the data in big endian to the buffer
        var bytes = [1]u8{0} ** (words * 2);
        std.mem.writeInt(std.meta.Int(.unsigned, size * 8), bytes[0..size], @bitCast(data), .big);

        // Write the data as native endian words
        inline for (0..words) |word| {
            try this.*.words.append(std.mem.readInt(u16, bytes[word * 2 .. word * 2 + 2], .big));
        }
    }

    /// Formatter for when printing to stdout
    /// In this case:
    ///     - `fill` is what to fill inbetween address and bytes section (probably space character)
    ///     - `alignment` is how to align the address ('^' (center) for no address shown)
    ///     - `width` is how much padding to put inbetween the address and the bytes section
    pub fn format(
        this: @This(),
        comptime _: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (options.alignment) {
            .center => {},
            .left => try writer.print("{x: <8}:", .{this.addr}),
            .right => try writer.print("{x: <8}:", .{this.addr}),
        }
        for (0..options.width orelse 1) |_| {
            try writer.print("{u}", .{options.fill});
        }
        for (0.., this.words.buffer) |idx, word| {
            if (idx >= this.words.len) {
                try writer.print("     ", .{});
            } else {
                try writer.print(" {x:0>4}", .{word});
            }
        }
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

    /// Disassemble into an instruction from a reader
    fn disasm(comptime instr: dec.Instr, source: *Source, reader: *Reader) !@This() {
        // Set up the size and opcode source
        var this = @This(){
            .name = instr.name,
            .size = if (instr.size) |size| size.size(source.opcode()) else null,
            .operands = .{},
        };

        // Disassemble the opcodes
        if (try Operand.disasm(this.size, instr.code.info.src, source, reader)) |operand| {
            try this.operands.append(operand);
        }
        if (try Operand.disasm(this.size, instr.code.info.dst, source, reader)) |operand| {
            try this.operands.append(operand);
        }
        return this;
    }

    /// Formatter for when printing to stdout
    /// In this case:
    ///     - `fill` what to put inbetween operands
    pub fn format(
        this: @This(),
        comptime _: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("{s}", .{this.name});
        if (this.size) |size| {
            switch (size) {
                .byte => try writer.print(".b", .{}),
                .word => try writer.print(".w", .{}),
                .long => try writer.print(".l", .{}),
            }
        }
        try writer.print("{u}", .{options.fill});
        for (0.., this.operands.slice()) |idx, operand| {
            if (idx != 0) {
                try writer.print(",", .{});
            }
            try writer.print("{}", .{operand});
        }
    }
};

/// Represents an instruction operand
pub const Operand = union(enum) {
    /// The operand is an effective address
    ea: EffAddr,

    /// Disassembles an operand
    fn disasm(
        size: ?enc.Size,
        comptime transfer: Code.Info.Transfer,
        source: *Source,
        reader: *Reader,
    ) !?@This() {
        return switch (transfer) {
            .none => null,
            .addr_mode => |encoding| .{ .ea = try EffAddr.disasm(size, encoding, source, reader) },
        };
    }

    /// Formatter for when printing to stdout
    pub fn format(
        this: @This(),
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (this) {
            .ea => |ea| try writer.print("{}", .{ea}),
        }
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
    imm: Imm,

    /// Disassemble an effective address
    fn disasm(
        size: ?enc.Size,
        comptime info: Code.AddrMode,
        source: *Source,
        reader: *Reader,
    ) !@This() {
        const word = source.opcode();
        return switch (info.decode(word) orelse return error.InvalidEncoding) {
            inline .data_reg, .addr_reg, .addr, .addr_inc, .addr_dec => |mode| @unionInit(
                @This(),
                @tagName(mode),
                info.n(word),
            ),
            .addr_disp => .{ .addr_disp = try Disp.disasm(info.n(word), source, reader) },
            .addr_idx => .{ .addr_idx = try Index.disasm(info.n(word), source, reader) },
            .pc_disp => .{ .pc_disp = try source.*.fetch(i16, reader) },
            .pc_idx => .{ .pc_idx = try Index.disasm(null, source, reader) },
            .abs_short => .{ .abs_short = try source.*.fetch(u16, reader) },
            .abs_long => .{ .abs_long = try source.*.fetch(u32, reader) },
            .imm => .{ .imm = try Imm.disasm(
                size orelse return error.InvalidEncoding,
                source,
                reader,
            ) },
        };
    }

    /// Formatter for when printing to stdout
    pub fn format(
        this: @This(),
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try switch (this) {
            .data_reg => |n| writer.print("d{}", .{n}),
            .addr_reg => |n| writer.print("a{}", .{n}),
            .addr => |n| writer.print("(a{})", .{n}),
            .addr_inc => |n| writer.print("(a{})+", .{n}),
            .addr_dec => |n| writer.print("-(a{})", .{n}),
            .addr_disp => |disp| writer.print("{}", .{disp}),
            .addr_idx => |index| writer.print("{}", .{index}),
            .pc_disp => |disp| writer.print("({}, pc)", .{disp}),
            .pc_idx => |index| writer.print("{}", .{index}),
            .abs_short => |short| writer.print("({x:0>4}).w", .{short}),
            .abs_long => |long| writer.print("({x:0>8}).l", .{long}),
            .imm => |imm| writer.print("{}", .{imm}),
        };
    }

    /// Address register displacement instructions
    pub const Disp = struct {
        /// The displacement
        disp: i16,

        /// What address register is the base
        base: u3,

        /// Disassembles a address displacement
        fn disasm(n: u3, source: *Source, reader: *Reader) error{Overflow}!@This() {
            return .{
                .base = n,
                .disp = try source.*.fetch(i16, reader),
            };
        }

        /// Formatter for when printing to stdout
        pub fn format(
            this: @This(),
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            try writer.print("({}, a{})", .{ this.disp, this.base });
        }
    };

    /// Address register and program counter indexed instructions
    pub const Index = struct {
        /// What address register is the base (null if pc)
        base: ?u3,

        /// The index register, and displacement
        ext: enc.ExtWord,

        /// Disassembles a address index
        fn disasm(n: ?u3, source: *Source, reader: *Reader) error{Overflow}!@This() {
            return .{
                .base = n,
                .ext = try source.*.fetch(enc.ExtWord, reader),
            };
        }

        /// Formatter for when printing to stdout
        pub fn format(
            this: @This(),
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            try writer.print("({}, ", .{this.ext.disp});
            if (this.base) |base| {
                try writer.print("a{}, ", .{base});
            } else {
                try writer.print("pc, ", .{});
            }
            switch (this.ext.m) {
                0 => try writer.print("d{}", .{this.ext.n}),
                1 => try writer.print("a{}", .{this.ext.n}),
            }
            try writer.print(".{c})", .{@as(u8, switch (this.ext.size) {
                0 => 'w',
                1 => 'l',
            })});
        }
    };

    /// Immediate data
    pub const Imm = union(enc.Size) {
        /// Byte immediate. Still encoded with 16 bits
        byte: u8,

        /// Word immediate
        word: u16,

        /// Long immediate, encoded in big endian
        long: u32,

        /// Disassembles immediate data
        fn disasm(size: enc.Size, source: *Source, reader: *Reader) error{Overflow}!@This() {
            return switch (size) {
                .byte => .{ .byte = try source.*.fetch(u8, reader) },
                .word => .{ .word = try source.*.fetch(u16, reader) },
                .long => .{ .long = try source.*.fetch(u32, reader) },
            };
        }

        /// Formatter for when printing to stdout
        pub fn format(
            this: @This(),
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            switch (this) {
                .byte => |byte| try writer.print("#{x:0>2}", .{byte}),
                .word => |word| try writer.print("#{x:0>4}", .{word}),
                .long => |long| try writer.print("#{x:0>8}", .{long}),
            }
        }
    };
};
