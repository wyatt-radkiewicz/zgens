const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    // Create modules
    const bus_mod = b.createModule(.{
        .root_source_file = b.path("src/bus/bus.zig"),
        .target = target,
        .optimize = optimize,
    });
    const m68k_mod = b.createModule(.{
        .root_source_file = b.path("src/m68k/m68k.zig"),
        .target = target,
        .optimize = optimize,
    });
    m68k_mod.addImport("bus", bus_mod);
    
    // Generate tests
    const m68k_tests_step = b.step("m68k-tests", "Run the tests for the m68k module");
    const m68k_tests = b.addTest(.{
        .root_module = m68k_mod,
        .target = target,
        .optimize = optimize,
    });
    const m68k_tests_run = b.addRunArtifact(m68k_tests);
    m68k_tests_step.dependOn(&m68k_tests_run.step);
}
