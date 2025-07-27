//! Decoding engine/instruction set architecture format
const std = @import("std");

const Code = @import("Code.zig");
const enc = @import("enc.zig");
const int = @import("int.zig");

/// Generates a lut
pub const Decoder = struct {
    /// Matches against opcodes
    matcher: Matcher,

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
            .matcher = Matcher.init(instrs),
            .illegal = illegal,
            .lut = .init(0) catch unreachable,
            .top = undefined,
        };
        this.top = this.visit(0, 0);
        return this;
    }

    /// Creates a compressed version of the LUT and returns it as a type
    pub fn decode(comptime this: @This(), word: u16) *const Code.Fn {
        const compressed = this.compress();
        var index = compressed.lut[this.top][word >> 12];
        inline for (0..3) |level| {
            index = compressed.lut[index][word >> 12 - level * 4];
        }
        return compressed.code[index];
    }

    /// Visits a prefix of an or full instruction, and returns the page index
    fn visit(comptime this: *@This(), prefix: u16, level: u3) usize {
        var found_perm: ?usize = null;
        for (0..1 << 16 - level * 4) |postfix| {
            const opcode = prefix << (16 - level * 4) | postfix;
            const matched = this.matcher.match(this.perms, opcode);
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
    fn add(comptime this: *@This(), page: [16]usize) usize {
        for (0.., this.lut.slice()) |index, lut| {
            if (std.mem.eql(usize, &lut, &page)) {
                return index;
            }
        }
        this.lut.appendAssumeCapacity(page);
        return this.lut.len - 1;
    }

    /// Get an compressed lut, it's not capitalized because its a dynamically generated namespace
    fn compress(comptime this: @This()) type {
        return struct {
            /// Compressed 4 level look up table to code/instr indicies
            pub const lut = lut: {
                var table: [this.lut.len][16]std.math.IntFittingRange(
                    0,
                    @max(this.lut.len - 1, this.perms.len - 1),
                ) = undefined;
                for (&table, this.lut) |*compressed_table, uncompressed_table| {
                    for (compressed_table, uncompressed_table) |*compressed, uncompressed| {
                        compressed.* = uncompressed;
                    }
                }
                break :lut table;
            };

            /// Code handlers
            pub const code = code: {
                const num_perms = this.matcher.perms.len;
                var handlers: [num_perms + 1]*const Code.Fn = undefined;
                for (handlers[0..num_perms], this.perms) |*pfn, perm| {
                    if (perm.size) |size| {
                        pfn.* = perm.instr.code.code(size.width());
                    } else {
                        pfn.* = perm.instr.code.code(null);
                    }
                }
                handlers[num_perms] = this.illegal;
                break :code handlers;
            };
        };
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

    /// Disassembly format for the instruction. Written like the formats for normal zig functions.
    /// Instead though, inside of each '{}' you put the name of the info of the instruction, like
    /// `sz`, `src`, `dst`, and these are read from the code info and size.
    format: []const u8,

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

/// A struct that can match a word against a variable amount of instructions
const Matcher = struct {
    /// All the permutations
    perms: []const Permutation,

    /// Generate all permutations of the instructions based on what can be paramatized in each
    pub fn init(comptime instrs: []const Instr) @This() {
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
        return .{ .perms = &perms };
    }

    /// Matches a specific concrete implementation of an instruction and returns its index
    pub fn match(comptime this: @This(), comptime word: u16) ?usize {
        return for (0.., this.perms) |i, perm| {
            if (perm.opcode.match(word)) {
                return i;
            }
        } else null;
    }
};
