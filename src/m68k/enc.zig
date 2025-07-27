//! Encoding structures for instructions
const std = @import("std");

const int = @import("int.zig");

/// How opcodes are represented
pub const Opcode = struct {
    /// What bits must be set in the opcode
    set: u16,

    /// What bits can be either 0 or 1 in the opcode
    any: u16,

    /// Create an encoding from a string
    pub fn init(enc: *const [16]u8) @This() {
        var this = @This(){
            .set = 0,
            .any = 0,
        };
        for (enc) |bit| {
            switch (bit) {
                '0' => {},
                '1' => this.set |= 1,
                'x' => this.any |= 1,
                else => @panic("expected only '0', '1', or 'x' in opcode encoding!"),
            }
            this.set <<= 1;
            this.any <<= 1;
        }
    }

    /// Match the opcode against a word
    pub fn match(this: @This(), word: u16) bool {
        return (word & ~this.any) ^ this.set == 0;
    }
};

/// Different types of size classes
pub const Size = enum {
    /// 8 bit operation
    byte,

    /// 16 bit operation
    word,

    /// 32 bit operation
    long,

    /// Get the number of bits associated with this size class
    pub inline fn width(this: @This()) u16 {
        return switch (this) {
            .byte => 8,
            .word => 16,
            .long => 32,
        };
    }

    /// An actual size encoding
    pub const Enc = struct {
        /// What integer does byte map to?
        byte: ?comptime_int = null,

        /// What integer does word map to?
        word: ?comptime_int = null,

        /// What integer does long map to?
        long: ?comptime_int = null,

        /// Gets the backing type for a mapping based on the mappings
        pub fn BackingType(comptime this: @This()) type {
            return std.math.IntFittingRange(0, @max(
                this.byte orelse 0,
                this.word orelse 0,
                this.long orelse 0,
            ));
        }

        /// Gets the size from an mapping an bits
        pub fn decode(comptime this: @This(), bits: this.BackingType()) ?Size {
            return inline for (std.meta.fieldNames(@This())) |mapping_name| {
                if (@field(this, mapping_name)) |mapping| {
                    if (bits == mapping) {
                        break @field(Size, mapping_name);
                    }
                }
            } else {
                return null;
            };
        }

        /// Gets the encoding for a size from the logical size
        pub fn encode(comptime this: @This(), size: Size) ?this.BackingType() {
            return @field(this, @tagName(size));
        }

        /// Gets the number of allowed size variants / mappings
        pub fn count(comptime this: @This()) comptime_int {
            var total = 0;
            inline for (std.meta.fieldNames(@This())) |mapping_name| {
                if (@field(this, mapping_name) != null) {
                    total += 1;
                }
            }
            return total;
        }

        /// Returns the default encoding for the specified width
        pub fn default(comptime bits: u16) @This() {
            return switch (bits) {
                1 => .{ .word = 0, .long = 1 },
                2 => .{ .byte = 0, .word = 1, .long = 2 },
                else => @compileError("Default size mappings only exist for 1 and 2 bits"),
            };
        }

        /// Encoding for the move instruction
        pub const move = @This(){ .byte = 1, .word = 3, .long = 2 };

        /// Encoding for the movea instruction
        pub const movea = @This(){ .word = 3, .long = 2 };
    };
};

/// Effective addressing mode
pub const AddrMode = enum {
    /// Data register direct
    data_reg,

    /// Address register direct
    addr_reg,

    /// Address register indirect
    addr,

    /// Address register indirect with post-increment
    addr_inc,

    /// Address register indirect with pre-decrement
    addr_dec,

    /// Address register indirect with 16-bit signed displacement
    addr_disp,

    /// Address register indirect with 8-bit signed displacement and signed index
    addr_idx,

    /// PC relative with 16-bit signed displacement
    pc_disp,

    /// PC relative with 8-bit signed displacement and signed index register
    pc_idx,

    /// Absolute memory location refrenced by sign extended 16-bit word
    abs_short,

    /// Absolute memory location
    abs_long,

    /// Immediate data (found after the instruction word, 8-bit still takes up word)
    imm,

    /// Encoding for an addressing mode
    pub const Enc = struct {
        data_reg: ?Mapping = null,
        addr_reg: ?Mapping = null,
        addr: ?Mapping = null,
        addr_inc: ?Mapping = null,
        addr_dec: ?Mapping = null,
        addr_disp: ?Mapping = null,
        addr_idx: ?Mapping = null,
        pc_disp: ?Mapping = null,
        pc_idx: ?Mapping = null,
        abs_short: ?Mapping = null,
        abs_long: ?Mapping = null,
        imm: ?Mapping = null,

        /// How a m/n pair is mapped to an addressing mode
        pub const Mapping = struct {
            /// What should the m bits be? `null` for anything.
            m: ?comptime_int = null,

            /// What should the n bits be? `null` for anything.
            n: ?comptime_int = null,
        };

        /// Decode using this encoding
        /// Will create a lookup table based on the type of m and n
        pub fn decode(comptime this: @This(), m: anytype, n: anytype) ?AddrMode {
            // See what the bit size of m and n will be in the lut.
            // It will either be the bitsize of m and n, or 0 if its not used in the encoding
            const m_size = inline for (std.meta.fieldNames(@This())) |field| {
                if ((@field(this, field) orelse continue).m != null) {
                    break @bitSizeOf(m);
                }
            } else 0;
            const n_size = inline for (std.meta.fieldNames(@This())) |field| {
                if ((@field(this, field) orelse continue).n != null) {
                    break @bitSizeOf(n);
                }
            } else 0;

            // Now we can construct a look up table
            var lut: [1 << m_size + n_size]?AddrMode = undefined;
            inline for (0..lut.len, &lut) |pattern, *entry| {
                entry.* = inline for (std.meta.fieldNames(@This())) |field| {
                    const mapping = @field(this, field) orelse continue;
                    if (mapping.m) |mapping_m| {
                        if (mapping_m != int.as(@TypeOf(m), pattern >> n_size)) {
                            continue;
                        }
                    }
                    if (mapping.n) |mapping_n| {
                        if (mapping_n != int.as(@TypeOf(n), pattern)) {
                            continue;
                        }
                    }
                    break @unionInit(AddrMode, field, .{});
                } else null;
            }

            // Simple index the lookup table
            return lut[@as(std.meta.Int(.unsigned, m_size + n_size), m) << n_size | n_size];
        }

        /// The default addressing mode (3 bits for m, 3 bits for n)
        pub const default = @This(){
            .data_reg = .{ .m = 0b000, .n = null },
            .addr_reg = .{ .m = 0b001, .n = null },
            .addr = .{ .m = 0b010, .n = null },
            .addr_inc = .{ .m = 0b011, .n = null },
            .addr_dec = .{ .m = 0b100, .n = null },
            .addr_disp = .{ .m = 0b101, .n = null },
            .addr_idx = .{ .m = 0b110, .n = null },
            .pc_disp = .{ .m = 0b111, .n = 0b010 },
            .pc_idx = .{ .m = 0b111, .n = 0b011 },
            .abs_short = .{ .m = 0b111, .n = 0b000 },
            .abs_long = .{ .m = 0b111, .n = 0b001 },
            .imm = .{ .m = 0b111, .n = 0b100 },
        };

        /// The single byte fast addressing mode (1 bit for m, 3 bits for n)
        pub const regreg = @This(){
            .data_reg = .{ .m = 0, .n = null },
            .addr_dec = .{ .m = 1, .n = null },
        };
    };
};

/// Extension words used in some addressing modes
pub const ExtWord = packed struct {
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
