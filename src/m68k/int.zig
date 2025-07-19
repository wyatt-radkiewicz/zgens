//! Integer helping functions
const std = @import("std");

/// Extract something from an integer
inline fn extract(Extract: type, from: anytype, at: std.math.Log2Int(@TypeOf(from))) Extract {
    const bits = @as(
        std.meta.Int(.unsigned, @bitSizeOf(Extract)),
        @truncate(@as(std.meta.Int(.unsigned, @bitSizeOf(@TypeOf(from))), @bitCast(from)) >> at),
    );
    return @bitCast(bits);
}

/// Overwrite a part of a integer
inline fn overwrite(int: anytype, with: anytype) @TypeOf(int) {
    const UnsignedInt = std.meta.Int(.unsigned, @bitSizeOf(@TypeOf(int)));
    const UnsignedWith = std.meta.Int(.unsigned, @bitSizeOf(@TypeOf(with)));
    const mask: UnsignedInt = (1 << @bitSizeOf(@TypeOf(with))) - 1;
    return @bitCast(@as(UnsignedInt, @bitCast(int)) & ~mask | @as(UnsignedWith, @bitCast(with)));
}

/// Extend an interger
inline fn extend(To: type, int: anytype) To {
    const SignedTo = std.meta.Int(.signed, @bitSizeOf(To));
    const SignedInt = std.meta.Int(.signed, @bitSizeOf(@TypeOf(int)));
    return @bitCast(@as(SignedTo, @as(SignedInt, @bitCast(int))));
}

/// Get integer as this integer (truncated)
inline fn as(As: type, int: anytype) As {
    return @truncate(int);
}
