//! Instruction definitions and code
const std = @import("std");

const bus_interface = @import("bus");

const Code = @import("Code.zig");
const Cpu = @import("Cpu.zig");
const decoder = @import("decoder.zig");
const Instr = decoder.Instr;
const Disasm = @import("Disasm.zig");
const Exec = @import("Exec.zig");

/// Instruction set for the m68k
pub const isa = &.{
    // Add decimal with extend
    Instr{
        .name = "abcd",
        .size = .{ .static = .byte },
        .opcode = .init("1100xxx10000xxxx"),
        .code = Code.builder
            .ea(.dst, true, false, .load, .bcd(.dst))
            .ea(.src, true, false, .load, .bcd(.src))
            .bcd(.add)
            .ea(.dst, false, false, .store, .bcd(.dst))
            .fetch(),
    },

    // Add (data register destination)
    Instr{
        .name = "add",
        .size = .default,
        .opcode = .init("1101xxx0xxxxxxxx"),
        .code = Code.builder
            .ea(.src, true, false, .load, .bcd(.src))
            .ldreg(.dst, .data, 9)
            .add()
            .streg(.dst, .data, 9)
            .fetch(),
    },
};

/// Run the test code in rom until the instruction pointer goes past the array.
/// Returns how much machine cycles it took to emulate
/// If ram is accessed outside of the []u16 ram array, it will do nothing.
/// It will assert that the rom disassembles to disasm
///  - with newlines inbetween each instruction
///  - no listing, just instructions
/// If an invalid instruction was encountered it will return error.InvalidInstruction
/// If the disassembly does not match it will return the testing error
/// Rom 0x00000000-0x000fffff
/// Ram 0x00100000-0x001fffff, mirrored until 0xffffffff
fn run(
    cpu: *Cpu,
    expected_cycles: usize,
    expected_disasm: []const u8,
    src_rom: []const u16,
    src_ram: ?[]u16,
) !void {
    // Create the bus interface
    const bus = try bus_interface.Bus(.main).init(null, &.{
        .init(0x0, 0x0, &src_rom, struct {
            pub fn read(rom: *const []const u16, addr: u23, _: u16) u16 {
                if (addr < rom.*.len) {
                    return rom.*[addr];
                } else {
                    return 0;
                }
            }
        }.read, struct {
            pub fn write(_: *const []const u16, _: u23, _: u16, _: u16) void {}
        }.write),
        .init(0x1, 0xf, &src_ram, struct {
            pub fn read(ram: *const ?[]u16, addr: u23, _: u16) u16 {
                const words = ram.* orelse return 0;
                const trunc = addr % 0x80000;
                if (trunc < words.len) {
                    return words[trunc];
                } else {
                    return 0;
                }
            }
        }.read, struct {
            pub fn write(ram: *const ?[]u16, addr: u23, mask: u16, data: u16) void {
                const words = ram.* orelse return;
                const trunc = addr % 0x100000;
                if (trunc < words.len) {
                    words[trunc] &= mask;
                    words[trunc] |= data;
                }
            }
        }.write),
    });

    // Verify the disassembly
    const allocator = std.testing.allocator;
    var actual_disasm = std.ArrayListUnmanaged(u8).initCapacity(allocator, 32) catch @panic("OOM");
    defer actual_disasm.deinit(allocator);
    var writer = actual_disasm.writer(allocator);
    const disasm = Disasm.init(isa);
    var reader = Disasm.Reader{
        .bus = &bus,
        .addr = 0,
    };
    while (true) {
        const view = disasm.disasm(&reader) orelse return error.InvalidInstruction;
        try writer.print("{}", .{view.decoded});
        if (reader.addr < src_rom.len * 2) {
            try writer.print("\n", .{});
        } else {
            break;
        }
    }
    try std.testing.expectEqualSlices(u8, expected_disasm, actual_disasm.items);

    // Run the code
    var cycles: usize = 0;
    cpu.ir = bus.read(0, 0x0000);
    cpu.pc = 2;
    while (true) {
        var exec = Exec.init(&bus);
        if (decoder.decode(isa, cpu.*.ir)) |code| {
            code(cpu, &exec);
        } else {
            return error.InvalidInstruction;
        }
        cycles += exec.clk;

        if (cpu.pc / 2 >= src_rom.len) {
            break;
        }
    }
    try std.testing.expectEqual(expected_cycles, cycles);
}

test "abcd" {
    // Test normal non-overflowing addition and clear zero flag if non-zero
    var cpu = Cpu{
        .d = .{ 0x09, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
        .sr = .{ .z = 1 },
    };
    try run(&cpu, 6, "abcd.b d0,d1", &.{0b1100_0011_0000_0000}, null);
    try std.testing.expectEqual(0x09, cpu.d[0]);
    try std.testing.expectEqual(0x11, cpu.d[1]);
    try std.testing.expectEqual(0, cpu.sr.x);
    try std.testing.expectEqual(0, cpu.sr.c);
    try std.testing.expectEqual(0, cpu.sr.z);

    // Test overflowing addition and zero flag is unchanged
    cpu = Cpu{
        .d = .{ 0x98, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
        .sr = .{ .z = 0 },
    };
    try run(&cpu, 6, "abcd.b d0,d1", &.{0b1100_0011_0000_0000}, null);
    try std.testing.expectEqual(0x98, cpu.d[0]);
    try std.testing.expectEqual(0x00, cpu.d[1]);
    try std.testing.expectEqual(1, cpu.sr.x);
    try std.testing.expectEqual(1, cpu.sr.c);
    try std.testing.expectEqual(0, cpu.sr.z);

    // Test addition with integers that have more data
    cpu = Cpu{
        .d = .{ 0xff15, 0xff13, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
    };
    try run(&cpu, 6, "abcd.b d0,d1", &.{0b1100_0011_0000_0000}, null);
    try std.testing.expectEqual(0xff15, cpu.d[0]);
    try std.testing.expectEqual(0xff28, cpu.d[1]);
    try std.testing.expectEqual(0, cpu.sr.x);
    try std.testing.expectEqual(0, cpu.sr.c);

    // Test memory addition and extra overflow case
    cpu = Cpu{
        .a = .{ 0x00100001, 0x00100002, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
    };
    var ram = [_]u16{0x9999};
    try run(&cpu, 18, "abcd.b -(a0),-(a1)", &.{0b1100_0011_0000_1000}, &ram);
    try std.testing.expectEqual(0x00100000, cpu.a[0]);
    try std.testing.expectEqual(0x00100001, cpu.a[1]);
    try std.testing.expectEqual(0x9899, ram[0]);
    try std.testing.expectEqual(1, cpu.sr.x);
    try std.testing.expectEqual(1, cpu.sr.c);
}
