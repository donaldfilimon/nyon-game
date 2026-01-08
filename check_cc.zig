const std = @import("std");

pub fn main() void {
    const CC = std.builtin.CallingConvention;
    inline for (@typeInfo(CC).Union.fields) |field| {
        std.debug.print("{s}\n", .{field.name});
    }
}
