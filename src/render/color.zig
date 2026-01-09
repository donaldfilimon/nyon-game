//! Color type with various format conversions

const std = @import("std");

/// RGBA color (8 bits per channel)
pub const Color = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub const BLACK = Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
    pub const WHITE = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
    pub const RED = Color{ .r = 255, .g = 0, .b = 0, .a = 255 };
    pub const GREEN = Color{ .r = 0, .g = 255, .b = 0, .a = 255 };
    pub const BLUE = Color{ .r = 0, .g = 0, .b = 255, .a = 255 };
    pub const YELLOW = Color{ .r = 255, .g = 255, .b = 0, .a = 255 };
    pub const CYAN = Color{ .r = 0, .g = 255, .b = 255, .a = 255 };
    pub const MAGENTA = Color{ .r = 255, .g = 0, .b = 255, .a = 255 };
    pub const TRANSPARENT = Color{ .r = 0, .g = 0, .b = 0, .a = 0 };

    pub fn fromRgb(r: u8, g: u8, b: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = 255 };
    }

    pub fn fromRgba(r: u8, g: u8, b: u8, a: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn fromFloat(r: f32, g: f32, b: f32, a: f32) Color {
        return .{
            .r = @intFromFloat(std.math.clamp(r, 0, 1) * 255),
            .g = @intFromFloat(std.math.clamp(g, 0, 1) * 255),
            .b = @intFromFloat(std.math.clamp(b, 0, 1) * 255),
            .a = @intFromFloat(std.math.clamp(a, 0, 1) * 255),
        };
    }

    pub fn fromHex(hex: u32) Color {
        return .{
            .r = @truncate((hex >> 24) & 0xFF),
            .g = @truncate((hex >> 16) & 0xFF),
            .b = @truncate((hex >> 8) & 0xFF),
            .a = @truncate(hex & 0xFF),
        };
    }

    pub fn toFloat(self: Color) [4]f32 {
        return .{
            @as(f32, @floatFromInt(self.r)) / 255.0,
            @as(f32, @floatFromInt(self.g)) / 255.0,
            @as(f32, @floatFromInt(self.b)) / 255.0,
            @as(f32, @floatFromInt(self.a)) / 255.0,
        };
    }

    pub fn toHex(self: Color) u32 {
        return (@as(u32, self.r) << 24) | (@as(u32, self.g) << 16) |
            (@as(u32, self.b) << 8) | @as(u32, self.a);
    }

    pub fn lerp(a: Color, b: Color, t: f32) Color {
        const t_clamped = std.math.clamp(t, 0, 1);
        return .{
            .r = @intFromFloat(@as(f32, @floatFromInt(a.r)) + (@as(f32, @floatFromInt(b.r)) - @as(f32, @floatFromInt(a.r))) * t_clamped),
            .g = @intFromFloat(@as(f32, @floatFromInt(a.g)) + (@as(f32, @floatFromInt(b.g)) - @as(f32, @floatFromInt(a.g))) * t_clamped),
            .b = @intFromFloat(@as(f32, @floatFromInt(a.b)) + (@as(f32, @floatFromInt(b.b)) - @as(f32, @floatFromInt(a.b))) * t_clamped),
            .a = @intFromFloat(@as(f32, @floatFromInt(a.a)) + (@as(f32, @floatFromInt(b.a)) - @as(f32, @floatFromInt(a.a))) * t_clamped),
        };
    }

    pub fn blend(dst: Color, src: Color) Color {
        const src_a = @as(f32, @floatFromInt(src.a)) / 255.0;
        const dst_a = @as(f32, @floatFromInt(dst.a)) / 255.0;
        const out_a = src_a + dst_a * (1 - src_a);

        if (out_a == 0) return TRANSPARENT;

        return .{
            .r = @intFromFloat((@as(f32, @floatFromInt(src.r)) * src_a + @as(f32, @floatFromInt(dst.r)) * dst_a * (1 - src_a)) / out_a),
            .g = @intFromFloat((@as(f32, @floatFromInt(src.g)) * src_a + @as(f32, @floatFromInt(dst.g)) * dst_a * (1 - src_a)) / out_a),
            .b = @intFromFloat((@as(f32, @floatFromInt(src.b)) * src_a + @as(f32, @floatFromInt(dst.b)) * dst_a * (1 - src_a)) / out_a),
            .a = @intFromFloat(out_a * 255),
        };
    }
};

test "color conversions" {
    const c = Color.fromRgb(128, 64, 32);
    try std.testing.expectEqual(@as(u8, 128), c.r);
    try std.testing.expectEqual(@as(u8, 255), c.a);

    const floats = c.toFloat();
    try std.testing.expectApproxEqAbs(@as(f32, 0.502), floats[0], 0.01);
}
