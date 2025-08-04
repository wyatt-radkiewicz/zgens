//! Microcode builder
const std = @import("std");

const Cpu = @import("Cpu.zig");
const enc = @import("enc.zig");
const Exec = @import("Exec.zig");
const int = @import("int.zig");

/// Each step for the code block. Each type must have a single function called `step` with the
/// signature: `fn (comptime width: u16, cpu: *Cpu, exec: *Exec) void` or the signature
/// `fn (cpu: *Cpu, exec: *Exec) void`. If size is null, then all steps have to have the second way.
steps: []const type,

/// Miscellaneous info about the code. Aribitrary, and used by the disassembler
info: Info,

/// Default code builder
pub const builder = @This(){ .steps = &.{}, .info = .empty };

/// Code handler that adds cycles to the state
pub fn cycles(comptime this: @This(), comptime clk: usize) @This() {
    var new = this;
    new.append(struct {
        pub fn step(_: *Cpu, exec: *Exec) void {
            exec.*.clk += clk;
        }
    });
    return new;
}

/// A function body that is the handler of the instruction. Takes in cpu state, bus interface
/// and executes the instruction and returns how long in cycles it took to complete.
pub fn code(comptime this: @This(), comptime width: ?u16) Fn {
    return struct {
        pub fn code(cpu: *Cpu, exec: *Exec) void {
            inline for (this.steps) |step| {
                if (!@hasDecl(step, "step")) {
                    @compileError("Expected code step type to have 'step' fn!");
                }
                const sig = switch (@typeInfo(@TypeOf(step.step))) {
                    .@"fn" => |info| info,
                    else => @compileError("Expected code step type to have 'step' fn!"),
                };
                if (sig.params[0].type == u16) {
                    // Paramatized instruction step
                    if (width) |count| {
                        step.step(count, cpu, exec);
                    } else {
                        @compileError("Paramatized code step but there is no size!");
                    }
                } else {
                    // Non-paramatized instruction step
                    step.step(cpu, exec);
                }
            }
        }
    }.code;
}

/// Calculate an effective address and put it in the execution context
/// If load is set to true, it will load the data from f
/// If `clk` is true, it will add clock cycles
pub fn ea(
    comptime this: @This(),
    comptime transfer: std.meta.FieldEnum(Exec.Ea.Type),
    comptime calc: bool,
    comptime clk: bool,
    comptime op: enum { load, store, none },
    comptime addr_mode: AddrMode,
) @This() {
    // Add the step to calculate the effective address
    var new = this;
    new.append(struct {
        /// The actual effective address calculation
        pub inline fn step(comptime width: u16, cpu: *Cpu, exec: *Exec) void {
            const Int = std.meta.Int(.unsigned, width);
            const n = addr_mode.n(cpu.*.ir);
            const mode = addr_mode.decode(cpu.*.ir) orelse @panic("invalid addressing mode");
            const ty = @tagName(transfer);

            // Calculate the effective address (if needed)
            if (calc) {
                @field(exec.*.ea, ty).addr = switch (mode) {
                    .data_reg, .addr_reg, .imm => 0,
                    .addr => cpu.*.a[n],
                    .addr_inc => addr_inc: {
                        const addr = cpu.*.a[n];
                        cpu.*.a[n] +%= width / 8;
                        break :addr_inc addr;
                    },
                    .addr_dec => addr_dec: {
                        cpu.*.a[n] -%= width / 8;
                        break :addr_dec cpu.*.a[n];
                    },
                    .addr_disp => cpu.*.a[n] +% int.extend(u32, exec.*.fetch(16, cpu)),
                    .addr_idx => cpu.*.a[n] +% exec.*.extword(cpu),
                    .pc_disp => cpu.*.pc +% int.extend(u32, exec.*.fetch(16, cpu)),
                    .pc_idx => cpu.*.pc +% exec.*.extword(cpu),
                    .abs_short => int.extend(u32, exec.*.fetch(16, cpu)),
                    .abs_long => exec.*.fetch(32, cpu),
                };
                exec.*.clk += switch (mode) {
                    .addr_dec, .addr_idx, .pc_idx => 2 * @as(usize, @intFromBool(clk)),
                    else => 0,
                };
            }

            // Complete the memory operation (if needed)
            switch (op) {
                .store => switch (mode) {
                    .data_reg => cpu.*.d[n] = int.overwrite(
                        cpu.*.d[n],
                        int.as(Int, @field(exec.*.ea, ty).data),
                    ),
                    .addr_reg => cpu.*.a[n] = int.overwrite(
                        cpu.*.a[n],
                        int.as(Int, @field(exec.*.ea, ty).data),
                    ),
                    .imm => {},
                    else => exec.*.write(
                        width,
                        @field(exec.*.ea, ty).addr,
                        int.as(Int, @field(exec.*.ea, ty).data),
                    ),
                },
                .load => @field(exec.*.ea, ty).data = @as(u32, switch (mode) {
                    .data_reg => int.as(Int, cpu.*.d[n]),
                    .addr_reg => int.extend(u32, int.as(Int, cpu.*.a[n])),
                    .imm => exec.*.fetch(width, cpu),
                    else => exec.*.read(width, @field(exec.*.ea, ty).addr),
                }),
                .none => {},
            }
        }
    });

    // Record any info about the operation and return the new code sequence
    switch (transfer) {
        .src => new.info.src = .{ .addr_mode = addr_mode },
        .dst => new.info.dst = .{ .addr_mode = addr_mode },
    }
    return new;
}

/// Store effective address destination data into a register
pub fn streg(comptime this: @This(), comptime reg: enc.Reg, comptime npos: u4) @This() {
    var new = this;
    new.append(struct {
        pub inline fn step(comptime width: u16, cpu: *Cpu, exec: *Exec) void {
            const Int = std.meta.Int(.unsigned, width);
            const n = int.extract(u3, cpu.*.ir, npos);
            switch (reg) {
                .data => cpu.*.d[n] = int.overwrite(cpu.*.d[n], int.as(Int, exec.*.ea.dst.data)),
                .addr => cpu.*.a[n] = int.overwrite(cpu.*.a[n], int.as(Int, exec.*.ea.dst.data)),
            }
        }
    });
    new.info.dst = @unionInit(Info.Transfer, @tagName(reg), npos);
    return new;
}

/// Load register into effective address slot
pub fn ldreg(
    comptime this: @This(),
    comptime transfer: std.meta.FieldEnum(Exec.Ea.Type),
    comptime reg: enc.Reg,
    comptime npos: u4,
) @This() {
    var new = this;
    new.append(struct {
        pub inline fn step(comptime width: u16, cpu: *Cpu, exec: *Exec) void {
            const Int = std.meta.Int(.unsigned, width);
            const n = int.extract(u3, cpu.*.ir, npos);
            @field(exec.*.ea, @tagName(transfer)).data = switch (reg) {
                .data => int.as(Int, cpu.*.d[n]),
                .addr => int.extend(u32, int.as(Int, cpu.*.a[n])),
            };
        }
    });
    @field(new.info, @tagName(transfer)) = @unionInit(Info.Transfer, @tagName(reg), npos);
    return new;
}

/// Fetch the next instruction into the instruction register
pub fn fetch(comptime this: @This()) @This() {
    var new = this;
    new.append(struct {
        pub fn step(cpu: *Cpu, exec: *Exec) void {
            cpu.*.ir = exec.*.fetch(16, cpu);
        }
    });
    return new;
}

/// Do a binary decimal operation
pub fn bcd(comptime this: @This(), comptime op: enum { add, sub }) @This() {
    var new = this;
    new.append(struct {
        pub fn step(cpu: *Cpu, exec: *Exec) void {
            const src = int.frombcd(@truncate(exec.*.ea.src.data));
            const dst = int.frombcd(@truncate(exec.*.ea.dst.data));
            const result = int.tobcd(switch (op) {
                .add => dst +% src +% cpu.*.sr.x,
                .sub => dst -% src -% cpu.*.sr.x,
            });
            exec.*.ea.dst.data = result[0];
            exec.*.clk += 2;
            cpu.*.sr.c = result[1];
            cpu.*.sr.x = result[1];
            cpu.*.sr.z &= @intFromBool(result[0] == 0);
        }
    });
    return new;
}

/// Internal function to append a new step
/// The `Step` parameter should be a type with a function called `step`
fn append(comptime this: *@This(), comptime Step: type) void {
    var new: [this.*.steps.len + 1]type = undefined;
    @memcpy(new[0..this.*.steps.len], this.*.steps);
    new[this.*.steps.len] = Step;
    const final = new;
    this.*.steps = &final;
}

/// The function signature for a complete instruction handler
pub const Fn = fn (*Cpu, *Exec) void;

/// Miscellaneous info about the code sequence
pub const Info = struct {
    /// Info about a source of the code transformation
    src: Transfer,

    /// Info about the destination of the code transformation
    dst: Transfer,

    /// Empty info object
    pub const empty = @This(){
        .src = .none,
        .dst = .none,
    };

    /// Info about the source or destination of a transfer
    pub const Transfer = union(enum) {
        /// No transfer took place
        none: void,

        /// It was a transfer from an effective address
        addr_mode: AddrMode,

        /// It was a transfer from a data register
        data: u4,

        /// It was a transfer from an address register
        addr: u4,
    };
};

/// Info about an addressing mode
pub const AddrMode = struct {
    /// Where are the m bits
    mpos: u4,

    /// Where are the n bits
    npos: u4,

    /// How many m bits are there?
    msize: u16,

    /// How many n bits are there?
    nsize: u16,

    /// What encoding is used?
    encoding: enc.AddrMode.Enc,

    /// Decode the addressing mode
    pub fn decode(comptime this: @This(), word: u16) ?enc.AddrMode {
        return this.encoding.decode(this.m(word), this.n(word));
    }

    /// Get the m bits
    pub inline fn m(comptime this: @This(), word: u16) std.meta.Int(.unsigned, this.msize) {
        return int.extract(std.meta.Int(.unsigned, this.msize), word, this.mpos);
    }

    /// Get the n bits
    pub inline fn n(comptime this: @This(), word: u16) std.meta.Int(.unsigned, this.nsize) {
        return int.extract(std.meta.Int(.unsigned, this.nsize), word, this.npos);
    }

    /// The default addressing mode version used fgor type I and II instructions
    pub const default = @This(){
        .mpos = 3,
        .npos = 0,
        .msize = 3,
        .nsize = 3,
        .encoding = .default,
    };

    /// This is the addressing mode version used for abcd, and family
    pub fn bcd(npos: enum { src, dst }) @This() {
        return .{
            .mpos = 3,
            .npos = switch (npos) {
                .src => 0,
                .dst => 9,
            },
            .msize = 1,
            .nsize = 3,
            .encoding = .reg,
        };
    }
};
