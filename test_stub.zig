const std = @import("std");
const raylib = @import("src/raylib_stub.zig");

test "check vec3Distance" {
    const v1 = raylib.Vector3{ .x = 1, .y = 0, .z = 0 };
    const v2 = raylib.Vector3{ .x = 0, .y = 0, .z = 0 };
    const d = raylib.vec3Distance(v1, v2);
    try std.testing.expect(d == 1.0);
}
