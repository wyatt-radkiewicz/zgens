const std = @import("std");
const builtin = @import("builtin");

/// Options to pass in to create a bus interface
pub const BusOptions = struct {
    /// How wide the address bus will be
    addr_width: u16,

    /// How wide the data bus will be
    data_width: u16,

    /// How big every page is (note this is important for memory usages, lower page sizes in
    /// comparison to address width result in more memory being used)
    page_size: usize,

    /// Max number of devices allowed to listen/serve on the bus
    max_devices: usize = 16,
};

/// Create a specialized bus interface
pub fn Bus(comptime options: BusOptions) type {
    // Make sure that the page_size is a power of 2
    if (@popCount(options.page_size) != 1) {
        @compileError(std.fmt.comptimePrint(
            "Expected BusOptions.page_size to be a power of two but found {}!",
            .{options.page_size},
        ));
    }

    // The bus interface
    return struct {
        /// Device handlers
        devices: [options.max_devices]Device,

        /// LUT address page -> device handler indexes
        pages: [num_pages]Id,

        /// Create a new bus with the specified handlers.
        /// `open_bus` will be put everywhere where a device is not specified.
        /// In debugging modes, if any entries in the `devices` slice overlap it will throw an
        /// error, or if the devices in the list don't cover the entire address space and an
        /// `open_bus` handler isn't specified, it will also error out.
        pub fn init(open_bus: ?Device, devices: []const Device) Error!@This() {
            var occupied_pages = std.StaticBitSet(num_pages).initEmpty();
            var id: usize = 0;
            var bus = @This(){
                .devices = [1]Device{.default} ** options.max_devices,
                .pages = [1]Id{0} ** num_pages,
            };

            // Add in open bus
            if (open_bus) |dev| {
                bus.devices[id] = dev;
                id += 1;
            }

            // Add in the next devices
            for (devices) |dev| {
                switch (builtin.mode) {
                    .Debug => {
                        // Check for conflicting mappings
                        for (dev.start .. dev.end + 1) |page| {
                            if (occupied_pages.isSet(page)) {
                                return Error.ConflictingDeviceMappings;
                            } else {
                                bus.pages[page] = @intCast(id);
                                occupied_pages.set(page);
                            }
                        }

                        // Check max number of devices
                        if (id == options.max_devices - 1) {
                            return Error.MaxDeviceLimitReached;
                        }
                    },
                    else => @memset(bus.pages[dev.start .. dev.end + 1], @intCast(id)),
                }
                id += 1;
            }

            // Return the completed bus and check for unmapped pages in debug modes
            if (builtin.mode == .Debug and occupied_pages.count() != num_pages) {
                return Error.UnmappedPages;
            }
            return bus;
        }
        
        /// Read something from this address.
        /// Put the `addr` as the address on the bus
        /// Put `mask` as the mask on the bus.
        /// The data received will be undefined where the mask is set
        pub inline fn read(this: @This(), addr: Addr, mask: Mask) Data {
            const device = &this.devices[this.pages[addr / options.page_size]];
            return device.read(device.context, addr, mask);
        }
        
        /// Write something to this address.
        /// Put the `addr` as the address on the bus
        /// Put `mask` as the mask on the bus.
        /// Put `data` as the data on the bus. Bits set in mask correspond to undefined bits
        /// in this parameter.
        pub inline fn write(this: @This(), addr: Addr, mask: Mask, data: Data) void {
            const device = &this.devices[this.pages[addr / options.page_size]];
            device.write(device.context, addr, mask, data);
        }

        /// Number of pages found in the address space
        pub const num_pages = (1 << options.addr_width) / options.page_size;

        /// A type that represents a device id
        pub const Id = std.math.IntFittingRange(0, options.max_devices - 1);

        /// A type that represents a page
        pub const Page = std.math.IntFittingRange(0, num_pages - 1);

        /// The address type
        pub const Addr = std.meta.Int(.unsigned, options.addr_width);

        /// The data type
        pub const Data = std.meta.Int(.unsigned, options.data_width);

        /// The mask type (same as data type)
        /// When using types of data below the native bus data width a mask of bits that specify
        /// where the data is are given. Unset bits indicate parts of the data variable that are
        /// valid/should be returned. Set bits indicate bits to ignore in the data parameter.
        pub const Mask = std.meta.Int(.unsigned, options.data_width);

        /// Errors when using the bus
        pub const Error = error{
            /// Provided more devices than can be handled, change options
            MaxDeviceLimitReached,

            /// Multiple devices map to one page
            ConflictingDeviceMappings,

            /// Some pages were unmapped
            UnmappedPages,
        };

        /// Represents a device on the bus network. Each device must provide an interface to
        /// write and read data to and from.
        pub const Device = struct {
            /// The start page (inclusive)
            start: Page,

            /// The end page (inclusive)
            end: Page,

            /// The pointer to the handler object
            context: *anyopaque,

            /// Pointer to the read handler
            read: *const fn (*anyopaque, Addr, Mask) Data,

            /// Pointer to the write handler
            write: *const fn (*anyopaque, Addr, Mask, Data) void,

            /// Type safely create a device handler with a context.
            /// The context passed in must be a pointer to the mutable handler
            pub fn init(
                start: Page,
                end: Page,
                context: anytype,
                read_impl: *const fn (@TypeOf(context), Addr, Mask) Data,
                write_impl: *const fn (@TypeOf(context), Addr, Mask, Data) void,
            ) @This() {
                return .{
                    .start = start,
                    .end = end,
                    .context = context,
                    .read = @ptrCast(read_impl),
                    .write = @ptrCast(write_impl),
                };
            }

            /// Default bus handler. Returns 0 for data, write does nothing.
            pub const default = @This(){
                .start = 0,
                .end = num_pages - 1,
                .context = @ptrCast(@constCast(&.{0})),
                .read = struct {
                    pub fn func(_: *anyopaque, _: Addr, _: Mask) Data {
                        return 0;
                    }
                }.func,
                .write = struct {
                    pub fn write(_: *anyopaque, _: Addr, _: Mask, _: Data) void {
                        return;
                    }
                }.func,
            };
        };
    };
}

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
pub const Main = Bus(.{
    .addr_width = 23,
    .data_width = 16,
    .page_size = 0x100000,
    .max_devices = 7,
});

/// Interface for the sub sega genesis bus
/// This one is connected to the z80 and represents the backwards compatible half of the sega
/// genesis. Its bus is conntected to 5 devices. They are:
/// - z80 cpu
/// - bus arbiter (8 bit side)
/// - 8kb of work ram
/// - i/o controller
/// - sound controller
pub const Sub = Bus(.{
    .addr_width = 16,
    .data_width = 8,
    .page_size = 0x1000,
    .max_devices = 5,
});
