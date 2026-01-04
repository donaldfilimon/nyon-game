//! Error handling utilities for Nyon Game Engine.

const std = @import("std");

pub const ErrorContext = struct {
    file: []const u8,
    function: []const u8,
    line: u32,
    message: []const u8,
};

pub const SafeWrapper = struct {
    pub fn ignoreErr(comptime T: type, result: anyerror!T, default: T) T {
        return result catch default;
    }

    pub fn logErr(comptime T: type, result: anyerror!T, context: ErrorContext, default: T) T {
        return result catch |err| {
            std.log.err("Error in {}:{s}:{d}: {s}: {}", .{ context.file, context.function, context.line, context.message, err });
            return default;
        };
    }
};

pub const Cast = struct {
    pub fn toInt(comptime Dest: type, value: anytype) Dest {
        return @intCast(value);
    }

    pub fn toFloat(comptime Dest: type, value: anytype) Dest {
        return @floatCast(value);
    }

    pub fn toIntClamped(comptime Dest: type, value: anytype, min: Dest, max: Dest) Dest {
        const casted = toInt(Dest, value);
        return std.math.clamp(casted, min, max);
    }

    pub fn toFloatClamped(comptime Dest: type, value: anytype, min: Dest, max: Dest) Dest {
        const casted = toFloat(Dest, value);
        return std.math.clamp(casted, min, max);
    }
};

pub fn safeArrayAccess(comptime T: type, array: []const T, index: usize) ?T {
    if (index >= array.len) {
        std.log.err("Array index out of bounds: {} >= {}", .{ index, array.len });
        return null;
    }
    return array[index];
}

test "Cast conversions" {
    try std.testing.expectEqual(@as(u8, 123), Cast.toInt(u8, @as(u64, 123)));
    try std.testing.expectEqual(@as(f64, 42.0), Cast.toFloat(f64, @as(i32, 42)));
}

test "safeArrayAccess" {
    const array = [_]u8{ 1, 2, 3 };
    try std.testing.expectEqual(@as(u8, 2), safeArrayAccess(u8, &array, 1).?);
    try std.testing.expectEqual(null, safeArrayAccess(u8, &array, 5));
}
