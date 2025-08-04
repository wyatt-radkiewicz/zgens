//! Decoding engine/instruction set architecture format
const std = @import("std");

const Code = @import("Code.zig");
const enc = @import("enc.zig");
const int = @import("int.zig");

/// Generates a lut
pub const Decoder = struct {
    /// Matches against opcodes
    matcher: Matcher,

    /// Uncompressed look up table. This still has no duplicates, but the actual index type is
    /// uncompressed.
    lut: std.BoundedArray([16]usize, 1 << 12),

    /// The top level page index
    top: usize,

    /// Generate a lut from an isa
    pub fn init(comptime opcodes: []const enc.Opcode) @This() {
        var this = @This(){
            .matcher = Matcher.init(opcodes),
            .lut = .{},
            .top = undefined,
        };
        this.top = this.visit(0, 0);
        return this;
    }

    /// Creates a compressed version of the LUT and returns it as a type
    pub fn decode(comptime this: @This(), word: u16) ?this.Entry() {
        const lut = this.compress();
        var index = lut[this.top][word >> 12];
        inline for (0..3) |level| {
            index = lut[index][word >> 8 - level * 4 & 0xf];
        }
        return if (index == this.matcher.opcodes.len) null else index;
    }

    /// Visits a prefix of an or full instruction, and returns the page index
    fn visit(comptime this: *@This(), prefix: u16, level: u3) usize {
        var found_perm: ?usize = null;
        for (0..1 << 16 - @as(u5, level) * 4) |postfix| {
            const opcode = prefix << @truncate(16 - @as(u5, level) * 4) | postfix;
            const matched = this.matcher.match(opcode);
            if (found_perm != null) {
                if (found_perm != matched) {
                    // Okay so there is multiple different handlers here, so visit this and
                    // then add the visited lut as a new entry
                    var page: [16]usize = undefined;
                    for (0..16) |next_prefix| {
                        const full_prefix = (prefix << 4) + next_prefix;
                        page[next_prefix] = this.visit(full_prefix, level + 1);
                    }
                    return this.add(page);
                }
            } else {
                found_perm = matched;
            }
        }

        // Since all of them are the same, lets just add a stub node
        var page = found_perm orelse this.matcher.opcodes.len;
        if (level == 4) {
            // This is the final level, so lets just link directly to the permutation
            return page;
        }

        // This isn't so we need to add some padding levels
        for (0..4 - level) |_| {
            page = this.add([1]usize{page} ** 16);
        }
        return page;
    }

    /// Adds the page to the lut and returns its index
    /// If there is already a page that looks like this, return that index instead
    fn add(comptime this: *@This(), page: [16]usize) usize {
        for (0.., this.lut.slice()) |index, lut| {
            if (std.mem.eql(usize, &lut, &page)) {
                return index;
            }
        }
        this.lut.appendAssumeCapacity(page);
        return this.lut.len - 1;
    }

    /// Returns the type of the comrpessed table
    fn CompressedTable(comptime this: @This()) type {
        return [this.lut.len][16]this.Entry();
    }
    
    /// The entry type in the look up tables
    fn Entry(comptime this: @This()) type {
        return std.math.IntFittingRange(0, @max(this.lut.len - 1, this.matcher.opcodes.len));
    }

    /// Get an compressed lut, it's not capitalized because its a dynamically generated namespace
    fn compress(comptime this: @This()) this.CompressedTable() {
        var table: this.CompressedTable() = undefined;
        for (&table, this.lut.slice()) |*compressed_table, uncompressed_table| {
            for (compressed_table, uncompressed_table) |*compressed, uncompressed| {
                compressed.* = @intCast(uncompressed);
            }
        }
        return table;
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

    /// The mnemonic of the instruction
    name: []const u8,

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
pub const Permutation = struct {
    /// Size it paramatized for each instruction, this is the concrete size of this implementation
    size: ?enc.Size,

    /// What different bit encodings can this handler impl work with?
    opcode: enc.Opcode,

    /// The actual instruction handling this permutation
    instr: Instr,

    /// Gets the code for a number of permutations
    pub fn code(comptime perms: []const @This()) []const *const Code.Fn {
        var fns: [perms.len]*const Code.Fn = undefined;
        for (perms, &fns) |perm, *func| {
            func.* = perm.instr.code.code(if (perm.size) |size| size.width() else null);
        }
        const final = fns;
        return &final;
    }

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

    /// Generates a list of permutations from a list of instructions
    pub fn generate(comptime instrs: []const Instr) []const Permutation {
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
        var perms = std.BoundedArray(Permutation, num_perms){};
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
        const final = perms.buffer;
        return final[0..perms.len];
    }
};

/// A struct that can match a word against a variable amount of opcodes
pub const Matcher = struct {
    /// All the opcodes to match against
    opcodes: []const enc.Opcode,

    /// Maps opcodes to original indexes
    indexes: []const usize,

    /// Generate all permutations of the instructions based on what can be paramatized in each
    pub fn init(comptime opcodes: []const enc.Opcode) @This() {
        // Create the unordered index map
        var indexes: [opcodes.len]usize = undefined;
        for (0.., &indexes) |i, *entry| {
            entry.* = i;
        }

        // Sort the index map
        std.sort.pdq(usize, &indexes, opcodes, struct {
            pub fn lessThan(source: []const enc.Opcode, lhs: usize, rhs: usize) bool {
                return @popCount(source[lhs].any) < @popCount(source[rhs].any);
            }
        }.lessThan);
        const final_indexes = indexes;
        return .{ .opcodes = opcodes, .indexes = &final_indexes };
    }

    /// Matches a specific concrete implementation of an instruction and returns its index
    /// corresponding to the original array of opcodes (unordered)
    pub fn match(comptime this: @This(), comptime word: u16) ?usize {
        @setEvalBranchQuota(2000000);
        return for (this.indexes) |index| {
            if (this.opcodes[index].match(word)) {
                return index;
            }
        } else null;
    }

    /// Extracts a list of opcodes from a slice of a type
    pub fn extract(comptime Type: type, comptime source: []const Type) []const enc.Opcode {
        var opcodes: [source.len]enc.Opcode = undefined;
        for (&opcodes, source) |*opcode, instance| {
            opcode.* = instance.opcode;
        }
        const final = opcodes;
        return &final;
    }
};

/// Decode code for an isa
pub fn decode(comptime isa: []const Instr, ir: u16) ?*const Code.Fn {
    const perms = comptime Permutation.generate(isa);
    const code = comptime Permutation.code(perms);
    const decoder = comptime Decoder.init(Matcher.extract(Permutation, perms));
    return code[decoder.decode(ir) orelse return null];
}
