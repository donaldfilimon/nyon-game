const raylib = @import("raylib");
pub fn main() void {
    const flags = raylib.ConfigFlags{ .invalid_field = true };
    _ = flags;
}
