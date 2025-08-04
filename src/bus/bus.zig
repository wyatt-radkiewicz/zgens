//! Bus interfaces for the sega genesis
const std = @import("std");
const builtin = @import("builtin");
pub const Config = @import("Config.zig");

/// Create a specialized bus interface
pub fn Bus(comptime config: Config) type {
    // Make sure that the page_size is a power of 2
    if (@popCount(config.page_size) != 1) {
        @compileError(std.fmt.comptimePrint(
            "Expected BusOptions.page_size to be a power of two but found {}!",
            .{config.page_size},
        ));
    }

    // The bus interface
    const page_size: std.meta.Int(.unsigned, config.addr_width) = @truncate(config.page_size);
    return struct {
        /// Device handlers
        devices: [config.max_devices]Device,

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
                .devices = [1]Device{.default} ** config.max_devices,
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
                        // Check max number of devices
                        if (id == config.max_devices - 1) {
                            return Error.MaxDeviceLimitReached;
                        }
                        
                        // Check for conflicting mappings
                        for (dev.start..@as(usize, @intCast(dev.end)) + 1) |page| {
                            if (occupied_pages.isSet(page)) {
                                return Error.ConflictingDeviceMappings;
                            } else {
                                bus.pages[page] = @intCast(id);
                                occupied_pages.set(page);
                            }
                        }
                    },
                    else => @memset(bus.pages[dev.start .. dev.end + 1], @intCast(id)),
                }
                bus.devices[id] = dev;
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
            const device = &this.devices[this.pages[addr / page_size]];
            return device.read(device.context, addr - device.start * page_size, mask);
        }

        /// Write something to this address.
        /// Put the `addr` as the address on the bus
        /// Put `mask` as the mask on the bus.
        /// Put `data` as the data on the bus. Bits set in mask correspond to undefined bits
        /// in this parameter.
        pub inline fn write(this: @This(), addr: Addr, mask: Mask, data: Data) void {
            const device = &this.devices[this.pages[addr / page_size]];
            device.write(device.context, addr - device.start * page_size, mask, data);
        }

        /// Number of pages found in the address space
        pub const num_pages = (1 << config.addr_width) / config.page_size;

        /// A type that represents a device id
        pub const Id = std.math.IntFittingRange(0, config.max_devices - 1);

        /// A type that represents a page
        pub const Page = std.math.IntFittingRange(0, num_pages - 1);

        /// The address type
        pub const Addr = std.meta.Int(.unsigned, config.addr_width);

        /// The data type
        pub const Data = std.meta.Int(.unsigned, config.data_width);

        /// The mask type (same as data type)
        /// When using types of data below the native bus data width a mask of bits that specify
        /// where the data is are given. Unset bits indicate parts of the data variable that are
        /// valid/should be returned. Set bits indicate bits to ignore in the data parameter.
        pub const Mask = std.meta.Int(.unsigned, config.data_width);

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
            context: *const anyopaque,

            /// Pointer to the read handler
            read: *const fn (*const anyopaque, Addr, Mask) Data,

            /// Pointer to the write handler
            write: *const fn (*const anyopaque, Addr, Mask, Data) void,

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
                    .context = @ptrCast(context),
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
                    pub fn read(_: *const anyopaque, _: Addr, _: Mask) Data {
                        return 0;
                    }
                }.read,
                .write = struct {
                    pub fn write(_: *const anyopaque, _: Addr, _: Mask, _: Data) void {
                        return;
                    }
                }.write,
            };
        };
    };
}
