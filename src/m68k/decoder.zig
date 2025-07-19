const std = @import("std");

const Code = @import("Code.zig");
const enc = @import("enc.zig");
const int = @import("int.zig");

/// Generates a lut
pub const Decoder = struct {
    /// Stored instruction permutations. The last permutation is the illegal instruction handler
    perms: []const Permutation,
    
    /// Illegal code handler. Should be paramaterless.
    illegal: Code,

    /// Uncompressed look up table. This still has no duplicates, but the actual index type is
    /// uncompressed.
    lut: std.BoundedArray([16]usize, 1 << 12),

    /// The top level page index
    top: usize,

    /// Generate a lut from an isa
    pub fn init(comptime instrs: []const Instr, comptime illegal: Code) @This() {
        var this = @This(){
            .perms = permutations(instrs),
            .illegal = illegal,
            .lut = .init(0) catch unreachable,
            .top = undefined,
        };
        this.top = this.visit(0, 0);
        return this;
    }

    /// Creates a compressed version of the LUT and returns it as a type
    pub fn decode(comptime this: @This(), word: u16) *const Code.Fn {
        // Compress the table at comptime
        const lut = comptime lut: {
            var lut: [this.lut.len][16]std.math.IntFittingRange(
                0,
                @max(this.lut.len - 1, this.perms.len - 1),
            ) = undefined;
            for (&lut, this.lut) |*compressed_table, uncompressed_table| {
                for (compressed_table, uncompressed_table) |*compressed, uncompressed| {
                    compressed.* = uncompressed;
                }
            }
            break :lut lut;
        };
        const code = comptime code: {
            var code: [this.perms.len + 1]*const Code.Fn = undefined;
            for (code[0..this.perms.len], this.perms) |*pfn, perm| {
                if (perm.size) |size| {
                    pfn.* = perm.instr.code.code(size.width());
                } else {
                    pfn.* = perm.instr.code.code(null);
                }
            }
            code[this.perms.len] = this.illegal;
            break :code code;
        };

        // The runtime part, just travel the 4 levels
        var index = lut[this.top][word >> 12];
        inline for (0..3) |level| {
            index = lut[index][word >> 12 - level * 4];
        }
        return code[index];
    }

    /// Visits a prefix of an or full instruction, and returns the page index
    fn visit(this: *@This(), prefix: u16, level: u3) usize {
        var found_perm: ?usize = null;
        for (0..1 << 16 - level * 4) |postfix| {
            const opcode = prefix << (16 - level * 4) | postfix;
            const matched = match(this.perms, opcode);
            if (found_perm != null) {
                if (found_perm != matched) {
                    // Okay so there is multiple different handlers here, so visit this and
                    // then add the visited lut as a new entry
                    var page: [16]usize = undefined;
                    for (0..16) |next_prefix| {
                        const full_prefix = prefix << 4 + next_prefix;
                        page[next_prefix] = this.visit(full_prefix, level + 1);
                    }
                    return this.add(page);
                }
            } else {
                found_perm = matched;
            }
        }

        // Since all of them are the same, lets just add a stub node
        var page = found_perm orelse this.perms.len;
        if (level == 4) {
            // This is the final level, so lets just link directly to the permutation
            return page;
        }

        // This isn't so we need to add some padding levels
        for (0..3 - level) |_| {
            page = this.add([1]usize{page} ** 16);
        }
        return page;
    }

    /// Adds the page to the lut and returns its index
    /// If there is already a page that looks like this, return that index instead
    fn add(this: *@This(), page: [16]usize) usize {
        for (0.., this.lut.slice()) |index, lut| {
            if (std.mem.eql(usize, &lut, &page)) {
                return index;
            }
        }
        this.lut.appendAssumeCapacity(page);
        return this.lut.len - 1;
    }
};

/// Instruction format/specification
pub const Instr = struct {
    /// How size is encoded in the instruction and what sizes are allowed?
    /// This is used since each instruction is paramartized against the size which makes everything
    /// much simpler to code, and faster too.
    /// For instructions that don't have an associated size, null can be provided
    size: ?Size,
    
    /// The bitwise encoding of the instruction.
    /// This does a general match against the instruction, like a pruning operation.
    /// If matching against multiple instructions, its nessesary to match in an order of
    /// increasing specificity of each opcode.
    opcode: enc.Opcode,
    
    /// Disassembly format for the instruction. How this is interpreted depends on the disassembler
    /// But usually this is written like the instruction itself
    disasm: []const u8,

    /// What code to run for this instruction
    code: Code,

    /// What a size is for an instruction
    pub const Size = union(enum) {
        /// Dyanmic runtime size
        dynamic: Dynamic,

        /// Static hardcoded size
        static: enc.Size,

        /// Dynamic size encoding
        pub const Dynamic = struct {
            /// Where the encoding is
            pos: u4,

            /// The actual size encoding
            encoding: enc.Size.Enc,
        };

        /// Get the size of the instruction given the word
        pub fn size(this: @This(), word: u16) enc.Size {
            return switch (this) {
                .dynamic => |dynamic| dynamic.encoding.decode(int.extract(
                    dynamic.encoding.BackingType(),
                    word,
                    dynamic.pos,
                )),
                .static => |static| static,
            };
        }

        /// Default size encoding used in most instructions
        pub const default = @This(){ .dynamic = .{
            .pos = 6,
            .encoding = .default(2),
        } };
    };
};

/// Represents a specific size encoding of an instruction
const Permutation = struct {
    /// Size it paramatized for each instruction, this is the concrete size of this implementation
    size: ?enc.Size,

    /// What different bit encodings can this handler impl work with?
    opcode: enc.Opcode,

    /// The actual instruction handling this permutation
    instr: Instr,

    /// Create a specialized handler for a specific size
    pub fn init(instr: Instr, specialization: ?enc.Size) @This() {
        if (instr.size) |instr_size| {
            return switch (instr_size) {
                .dynamic => |dyn| perm: {
                    const size = specialization orelse unreachable;
                    const bits = dyn.encoding.encode(size) orelse unreachable;
                    const mask = @as(u16, std.math.maxInt(dyn.encoding.BackingType())) << dyn.pos;
                    var opcode = instr.opcode;
                    opcode.any &= ~mask;
                    opcode.set &= ~mask;
                    opcode.set |= @as(u16, bits) << dyn.pos;
                    break :perm .{
                        .size = size,
                        .opcode = opcode,
                        .instr = instr,
                    };
                },
                .static => |size| perm: {
                    break :perm .{
                        .size = size,
                        .opcode = instr.opcode,
                        .instr = instr,
                    };
                },
            };
        } else {
            return .{
                .size = null,
                .opcode = instr.opcode,
                .instr = instr,
            };
        }
    }
};

/// Matches a specific concrete implementation of an instruction and returns its index
fn match(comptime perms: []const Permutation, comptime word: u16) ?usize {
    return for (0.., perms) |i, perm| {
        if (perm.opcode.match(word)) {
            return i;
        }
    } else null;
}

/// Generate all permutations of the instructions based on what can be paramatized in each
fn permutations(comptime instrs: []const Instr) []const Permutation {
    // Find out how many permutations there are
    var num_perms = 0;
    for (instrs) |instr| {
        if (instr.size) |size| {
            num_perms += switch (size) {
                .dynamic => |dynamic| dynamic.encoding.count(),
                .static => 1,
            };
        } else {
            num_perms += 1;
        }
    }

    // Convert each instruction into permutations
    var perms = std.BoundedArray(Permutation, num_perms).init(0) catch unreachable;
    for (instrs) |instr| {
        if (instr.size) |encoding| {
            switch (encoding) {
                .dynamic => |dyn| {
                    inline for (0..std.math.maxInt(dyn.encoding.BackingType()) + 1) |bits| {
                        if (dyn.encoding.decode(bits)) |size| {
                            perms.appendAssumeCapacity(.init(instr, size));
                        }
                    }
                },
                .static => |size| perms.appendAssumeCapacity(.init(instr, size)),
            }
        } else {
            perms.appendAssumeCapacity(.init(instr, null));
        }
    }

    // Then order the permutations by specificity
    std.sort.pdq(Permutation, &perms, {}, struct {
        pub fn lessThan(_: void, lhs: Permutation, rhs: Permutation) bool {
            return @popCount(lhs.opcode.any) < @popCount(rhs.opcode.any);
        }
    }.lessThan);
    return &perms;
}
