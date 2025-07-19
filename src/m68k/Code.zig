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

/// Empty code handler
pub const empty = @This(){ .steps = &.{} };

/// A function body that is the handler of the instruction. Takes in cpu state, bus interface
/// and executes the instruction and returns how long in cycles it took to complete.
pub fn code(comptime this: @This(), comptime width: ?u16) Fn {
    return struct {
        pub fn code(cpu: *Cpu, exec: *Exec) void {
            inline for (this.steps) |step| {
                const sig = switch (@typeInfo(@FieldType(step, "step"))) {
                    .@"fn" => |info| info,
                    else => @compileError("Expected code step type to have 'step' fn!"),
                };
                if (sig.params[0].type == u16 and sig.params[0].is_generic) {
                    // Paramatized instruction step
                    if (width) |count| {
                        step.step(count, cpu, &exec);
                    } else {
                        @compileError("Paramatized code step but there is no size!");
                    }
                } else {
                    // Non-paramatized instruction step
                    step.step(cpu, &exec);
                }
            }
        }
    }.code;
}

/// Calculate an effective address and put it in the execution context
/// If load is set to true, it will load the data from f
pub fn ea(
    comptime this: @This(),
    comptime calc: bool,
    comptime op: enum { load, store, none },
    comptime mpos: u4,
    comptime npos: u4,
) @This() {
    // Make sure there is a size, since we can't calculate effective addresses without them
    if (this.size_info == null) {
        @compileError("Instruction needs size encoding for effective address calculation");
    }

    // Add the step to calculate the effective address
    return this.append(struct {
        /// The actual effective address calculation
        pub inline fn step(comptime width: u16, cpu: *Cpu, exec: *Exec) void {
            const m = int.extract(u3, cpu.*.ir, mpos);
            const n = int.extract(u3, cpu.*.ir, npos);
            const mode = enc.AddrMode.decode(m, n);

            // Calculate the effective address (if needed)
            if (calc) {
                exec.*.ea_addr = switch (mode) {
                    .data_reg, .addr_reg, .imm => {},
                    .addr => cpu.*.a[n],
                    .addr_inc => addr_inc: {
                        const addr = cpu.*.a[n];
                        cpu.*.a[n] += width / 8;
                        break :addr_inc addr;
                    },
                    .addr_dec => addr_dec: {
                        cpu.*.a[n] -= width / 8;
                        break :addr_dec cpu.*.a[n];
                    },
                    .addr_disp => cpu.*.a[n] +% int.extend(u32, exec.*.fetch(16, cpu)),
                    .addr_idx => cpu.*.a[n] +% exec.*.extword(cpu),
                    .pc_disp => cpu.*.pc +% int.extend(u32, exec.*.fetch(16, cpu)),
                    .pc_idx => cpu.*.pc +% exec.*.extword(cpu),
                    .abs_short => int.extend(u32, exec.*.fetch(16, cpu)),
                    .abs_long => exec.*.fetch(32, cpu),
                };
            }

            // Complete the memory operation (if needed)
            switch (op) {
                .store => switch (mode) {
                    .data_reg => cpu.*.d[n] = int.overwrite(cpu.*.d[n], exec.*.ea_data),
                    .addr_reg => cpu.*.a[n] = int.extend(u32, exec.*.ea_data),
                    .imm => {},
                    else => exec.*.write(
                        width,
                        exec.*.ea_addr,
                        int.as(std.meta.Int(.unsigned, width), exec.*.ea_data),
                    ),
                },
                .load => exec.*.ea_data = @as(u32, switch (mode) {
                    .data_reg => cpu.*.d[n],
                    .addr_reg => cpu.*.a[n],
                    .imm => exec.*.fetch(width, cpu),
                    else => exec.*.read(width, exec.*.ea_addr),
                }),
                .none => {},
            }
        }
    });
}

/// Internal function to append a new step
/// The `Step` parameter should be a type with a function called `step`
fn append(comptime this: @This(), comptime Step: type) @This() {
    var new: [this.steps.len + 1]type = undefined;
    @memcpy(new[0..this.steps.len], this.steps);
    new[this.steps.len] = Step;
    return .{ .steps = &new };
}

/// The function signature for a complete instruction handler
pub const Fn = fn (*Cpu, *Exec) void;
