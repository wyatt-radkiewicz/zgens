//! Integer helping functions
const std = @import("std");

/// Extract something from an integer
pub inline fn extract(Extract: type, from: anytype, at: std.math.Log2Int(@TypeOf(from))) Extract {
    const bits = @as(
        std.meta.Int(.unsigned, @bitSizeOf(Extract)),
        @truncate(@as(std.meta.Int(.unsigned, @bitSizeOf(@TypeOf(from))), @bitCast(from)) >> at),
    );
    return @bitCast(bits);
}

/// Overwrite a part of a integer
pub inline fn overwrite(int: anytype, with: anytype) @TypeOf(int) {
    const UnsignedInt = std.meta.Int(.unsigned, @bitSizeOf(@TypeOf(int)));
    const UnsignedWith = std.meta.Int(.unsigned, @bitSizeOf(@TypeOf(with)));
    const mask: UnsignedInt = (1 << @bitSizeOf(@TypeOf(with))) - 1;
    return @bitCast(@as(UnsignedInt, @bitCast(int)) & ~mask | @as(UnsignedWith, @bitCast(with)));
}

/// Extend an interger
pub inline fn extend(To: type, int: anytype) To {
    const SignedTo = std.meta.Int(.signed, @bitSizeOf(To));
    const SignedInt = std.meta.Int(.signed, @bitSizeOf(@TypeOf(int)));
    return @bitCast(@as(SignedTo, @as(SignedInt, @bitCast(int))));
}

/// Get integer as this integer (truncated)
pub inline fn as(As: type, int: anytype) As {
    return @truncate(int);
}

/// Convert an integer to a signedness
pub inline fn tosign(
    to_signedness: std.builtin.Signedness,
    int: anytype,
) std.meta.Int(to_signedness, @bitSizeOf(@TypeOf(int))) {
    return @bitCast(int);
}

/// Converts a 8 bit int to binary coded decimal
pub fn tobcd(value: u8) struct { u8, u1 } {
    const lut = comptime lut: {
        var lut = [1]u8{0} ** 256;
        for (0..256) |byte| {
            const trunc = byte % 100;
            lut[byte] = (trunc / 10 << 4) | (trunc % 10);
        }
        break :lut lut;
    };
    return .{ lut[value], @intFromBool(value > 99) };
}

/// Converts binary coded decimal to 8 bit int
pub fn frombcd(value: u8) u8 {
    const lut = comptime lut: {
        var lut = [1]u8{0} ** 256;
        for (0..256) |byte| {
            const ones = byte & 0xf;
            const tens = byte >> 4;
            lut[byte] = tens * 10 + ones;
        }
        break :lut lut;
    };
    return lut[value];
}

/// Add 'n' integers together
/// Accepts a tuple of integers
pub fn add(values: anytype) Op(@TypeOf(values)) {
    var op = Op(@TypeOf(values)){};
    return inline for (0..values.len) |idx| {
        if (idx == 0) {
            op.result = values[idx];
            continue;
        }

        const value = values[idx];
        op.signed |= @addWithOverflow(tosign(.signed, op.result), tosign(.signed, value))[1];
        op.unsigned |= @addWithOverflow(tosign(.unsigned, op.result), tosign(.unsigned, value))[1];
        op.result +%= value;
    } else op;
}

/// Substract 'n' integers together
/// Accepts a tuple of integers
pub fn sub(values: anytype) Op(@TypeOf(values)) {
    var op = Op(@TypeOf(values)){};
    return inline for (0..values.len) |idx| {
        if (idx == 0) {
            op.result = values[idx];
            continue;
        }

        const value = values[idx];
        op.signed |= @subWithOverflow(tosign(.signed, op.result), tosign(.signed, value))[1];
        op.unsigned |= @subWithOverflow(tosign(.unsigned, op.result), tosign(.unsigned, value))[1];
        op.result -%= value;
    } else op;
}

/// The result of a mathmatical operation between 'n' integers
fn Op(Value: type) type {
    const values = @typeInfo(Value).@"struct".fields;
    return struct {
        /// The value (with overflows)
        result: if (values.len >= 2)
            @TypeOf(@as(values[0].type, 0) +% @as(values[1].type, 0))
        else
            values[0].type = 0,

        /// Whether or not signed overflow occurred
        signed: u1 = 0,

        /// Whether or not unsigned overflow occurred
        unsigned: u1 = 0,
    };
}
