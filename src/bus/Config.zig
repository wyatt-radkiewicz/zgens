//! Options to pass in to create a bus interface

/// How wide the address bus will be
addr_width: u16,

/// How wide the data bus will be
data_width: u16,

/// How big every page is (note this is important for memory usages, lower page sizes in
/// comparison to address width result in more memory being used)
page_size: usize,

/// Max number of devices allowed to listen/serve on the bus
max_devices: usize = 16,

/// Interface for the main sega genesis bus
/// The actual m68k has a 24 bit address space but since the data bus is 16 bit, there is no
/// need for the final bit.
/// There are 7 devices connected to the main bus of the sega genesis. They are:
/// - 68000 cpu
/// - cart i/o
/// - peripherial i/o
/// - 64kb of work ram
/// - bus arbiter (16 bit side)
/// - i/o controller
/// - vdp (visual display processor)
pub const main = @This(){
    .addr_width = 23,
    .data_width = 16,
    .page_size = 0x80000,
    .max_devices = 7,
};

/// Interface for the sub sega genesis bus
/// This one is connected to the z80 and represents the backwards compatible half of the sega
/// genesis. Its bus is conntected to 5 devices. They are:
/// - z80 cpu
/// - bus arbiter (8 bit side)
/// - 8kb of work ram
/// - i/o controller
/// - sound controller
pub const sub = @This(){
    .addr_width = 16,
    .data_width = 8,
    .page_size = 0x1000,
    .max_devices = 5,
};
