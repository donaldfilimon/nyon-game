//! Texture handling

const std = @import("std");
const Color = @import("color.zig").Color;

/// 2D Texture
pub const Texture = struct {
    width: u32,
    height: u32,
    data: []Color,
    allocator: std.mem.Allocator,
    filter: Filter,
    wrap: Wrap,

    pub const Filter = enum { nearest, linear };
    pub const Wrap = enum { repeat, clamp, mirror };

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Texture {
        const data = try allocator.alloc(Color, width * height);
        @memset(data, Color.WHITE);
        return .{
            .width = width,
            .height = height,
            .data = data,
            .allocator = allocator,
            .filter = .nearest,
            .wrap = .repeat,
        };
    }

    pub fn deinit(self: *Texture) void {
        self.allocator.free(self.data);
    }

    pub fn setPixel(self: *Texture, x: u32, y: u32, color: Color) void {
        if (x < self.width and y < self.height) {
            self.data[y * self.width + x] = color;
        }
    }

    pub fn getPixel(self: *const Texture, x: u32, y: u32) Color {
        if (x < self.width and y < self.height) {
            return self.data[y * self.width + x];
        }
        return Color.TRANSPARENT;
    }

    pub fn sample(self: *const Texture, u: f32, v: f32) Color {
        var uw = u;
        var vw = v;

        switch (self.wrap) {
            .repeat => {
                uw = @mod(u, 1.0);
                vw = @mod(v, 1.0);
                if (uw < 0) uw += 1;
                if (vw < 0) vw += 1;
            },
            .clamp => {
                uw = std.math.clamp(u, 0, 1);
                vw = std.math.clamp(v, 0, 1);
            },
            .mirror => {
                uw = @abs(@mod(u, 2.0) - 1.0);
                vw = @abs(@mod(v, 2.0) - 1.0);
            },
        }

        const x = @as(u32, @intFromFloat(uw * @as(f32, @floatFromInt(self.width - 1))));
        const y = @as(u32, @intFromFloat(vw * @as(f32, @floatFromInt(self.height - 1))));
        return self.getPixel(x, y);
    }

    /// Create a checkerboard pattern
    pub fn checkerboard(allocator: std.mem.Allocator, size: u32, tile_size: u32) !Texture {
        var tex = try init(allocator, size, size);
        for (0..size) |y| {
            for (0..size) |x| {
                const checker = (@divFloor(x, tile_size) + @divFloor(y, tile_size)) % 2 == 0;
                tex.setPixel(@intCast(x), @intCast(y), if (checker) Color.WHITE else Color.fromRgb(128, 128, 128));
            }
        }
        return tex;
    }
};

test "texture sampling" {
    const allocator = std.testing.allocator;
    var tex = try Texture.init(allocator, 4, 4);
    defer tex.deinit();

    tex.setPixel(0, 0, Color.RED);
    const sampled = tex.sample(0, 0);
    try std.testing.expectEqual(Color.RED.r, sampled.r);
}
