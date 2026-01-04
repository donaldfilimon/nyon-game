//! Math Utilities for Game Engine Development
//!

const std = @import("std");

/// 2D Vector
pub const Vec2 = struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) Vec2 {
        return Vec2{ .x = x, .y = y };
    }

    pub fn zero() Vec2 {
        return Vec2{ .x = 0, .y = 0 };
    }

    pub fn one() Vec2 {
        return Vec2{ .x = 1, .y = 1 };
    }

    pub fn add(a: Vec2, b: Vec2) Vec2 {
        return Vec2{ .x = a.x + b.x, .y = a.y + b.y };
    }

    pub fn sub(a: Vec2, b: Vec2) Vec2 {
        return Vec2{ .x = a.x - b.x, .y = a.y - b.y };
    }

    pub fn scale(v: Vec2, s: f32) Vec2 {
        return Vec2{ .x = v.x * s, .y = v.y * s };
    }

    pub fn dot(a: Vec2, b: Vec2) f32 {
        return a.x * b.x + a.y * b.y;
    }

    pub fn length(v: Vec2) f32 {
        return std.math.sqrt(v.x * v.x + v.y * v.y);
    }

    pub fn lengthSquared(v: Vec2) f32 {
        return v.x * v.x + v.y * v.y;
    }

    pub fn normalize(v: Vec2) Vec2 {
        const len = v.length();
        if (len == 0) return Vec2.zero();
        return Vec2{ .x = v.x / len, .y = v.y / len };
    }

    pub fn distance(a: Vec2, b: Vec2) f32 {
        return a.sub(b).length();
    }

    pub fn lerp(a: Vec2, b: Vec2, t: f32) Vec2 {
        return Vec2{
            .x = a.x + (b.x - a.x) * t,
            .y = a.y + (b.y - a.y) * t,
        };
    }
};

/// 3D Vector
pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return Vec3{ .x = x, .y = y, .z = z };
    }

    pub fn zero() Vec3 {
        return Vec3{ .x = 0, .y = 0, .z = 0 };
    }

    pub fn one() Vec3 {
        return Vec3{ .x = 1, .y = 1, .z = 1 };
    }

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return Vec3{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return Vec3{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }

    pub fn scale(v: Vec3, s: f32) Vec3 {
        return Vec3{ .x = v.x * s, .y = v.y * s, .z = v.z * s };
    }

    pub fn dot(a: Vec3, b: Vec3) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return Vec3{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }

    pub fn length(v: Vec3) f32 {
        return std.math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
    }

    pub fn lengthSquared(v: Vec3) f32 {
        return v.x * v.x + v.y * v.y + v.z * v.z;
    }

    pub fn normalize(v: Vec3) Vec3 {
        const len = v.length();
        if (len == 0) return Vec3.zero();
        return Vec3{ .x = v.x / len, .y = v.y / len, .z = v.z / len };
    }

    pub fn distance(a: Vec3, b: Vec3) f32 {
        return a.sub(b).length();
    }

    pub fn lerp(a: Vec3, b: Vec3, t: f32) Vec3 {
        return Vec3{
            .x = a.x + (b.x - a.x) * t,
            .y = a.y + (b.y - a.y) * t,
            .z = a.z + (b.z - a.z) * t,
        };
    }
};

/// 4x4 Matrix for transformations
pub const Mat4 = struct {
    data: [16]f32,

    pub fn identity() Mat4 {
        return Mat4{
            .data = [16]f32{ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 },
        };
    }

    pub fn translation(x: f32, y: f32, z: f32) Mat4 {
        var m = Mat4.identity();
        m.data[12] = x;
        m.data[13] = y;
        m.data[14] = z;
        return m;
    }

    pub fn scale(x: f32, y: f32, z: f32) Mat4 {
        var m = Mat4.identity();
        m.data[0] = x;
        m.data[5] = y;
        m.data[10] = z;
        return m;
    }

    pub fn rotationX(angle: f32) Mat4 {
        const s = std.math.sin(angle);
        const c = std.math.cos(angle);
        return Mat4{
            .data = [16]f32{ 1, 0, 0, 0, 0, c, -s, 0, 0, s, c, 0, 0, 0, 0, 1 },
        };
    }

    pub fn rotationY(angle: f32) Mat4 {
        const s = std.math.sin(angle);
        const c = std.math.cos(angle);
        return Mat4{
            .data = [16]f32{ c, 0, s, 0, 0, 1, 0, 0, -s, 0, c, 0, 0, 0, 0, 1 },
        };
    }

    pub fn rotationZ(angle: f32) Mat4 {
        const s = std.math.sin(angle);
        const c = std.math.cos(angle);
        return Mat4{
            .data = [16]f32{ c, -s, 0, 0, s, c, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 },
        };
    }

    pub fn multiply(a: Mat4, b: Mat4) Mat4 {
        var result: Mat4 = undefined;
        for (0..4) |i| {
            for (0..4) |j| {
                var sum: f32 = 0;
                for (0..4) |k| {
                    sum += a.data[i * 4 + k] * b.data[k * 4 + j];
                }
                result.data[i * 4 + j] = sum;
            }
        }
        return result;
    }

    pub fn perspective(fov: f32, aspect: f32, near: f32, far: f32) Mat4 {
        const f = 1.0 / std.math.tan(fov / 2.0);
        const range_inv = 1.0 / (near - far);
        var m = Mat4.identity();
        m.data[0] = f / aspect;
        m.data[5] = f;
        m.data[10] = (near + far) * range_inv;
        m.data[11] = -1;
        m.data[14] = near * far * range_inv * 2;
        m.data[15] = 0;
        return m;
    }

    pub fn lookAt(eye: Vec3, center: Vec3, up: Vec3) Mat4 {
        const f = Vec3.normalize(center.sub(eye));
        const s = Vec3.normalize(f.cross(up));
        const u = s.cross(f);

        var m = Mat4.identity();
        m.data[0] = s.x;
        m.data[1] = u.x;
        m.data[2] = -f.x;
        m.data[4] = s.y;
        m.data[5] = u.y;
        m.data[6] = -f.y;
        m.data[8] = s.z;
        m.data[9] = u.z;
        m.data[10] = -f.z;
        m.data[12] = -Vec3.dot(s, eye);
        m.data[13] = -Vec3.dot(u, eye);
        m.data[14] = Vec3.dot(f, eye);
        return m;
    }
};

/// Color structure
pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub fn init(r: u8, g: u8, b: u8, a: u8) Color {
        return Color{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn white() Color {
        return Color.init(255, 255, 255, 255);
    }

    pub fn black() Color {
        return Color.init(0, 0, 0, 255);
    }

    pub fn red() Color {
        return Color.init(255, 0, 0, 255);
    }

    pub fn green() Color {
        return Color.init(0, 255, 0, 255);
    }

    pub fn blue() Color {
        return Color.init(0, 0, 255, 255);
    }

    pub fn toFloatRGBA(self: Color) [4]f32 {
        return [4]f32{
            @as(f32, @floatFromInt(self.r)) / 255.0,
            @as(f32, @floatFromInt(self.g)) / 255.0,
            @as(f32, @floatFromInt(self.b)) / 255.0,
            @as(f32, @floatFromInt(self.a)) / 255.0,
        };
    }
};

/// Bounding box
pub const AABB = struct {
    min: Vec3,
    max: Vec3,

    pub fn init(min: Vec3, max: Vec3) AABB {
        return AABB{ .min = min, .max = max };
    }

    pub fn empty() AABB {
        return AABB{
            .min = Vec3.init(std.math.inf(f32), std.math.inf(f32), std.math.inf(f32)),
            .max = Vec3.init(-std.math.inf(f32), -std.math.inf(f32), -std.math.inf(f32)),
        };
    }

    pub fn center(a: AABB) Vec3 {
        return a.min.add(a.max).scale(0.5);
    }

    pub fn size(a: AABB) Vec3 {
        return a.max.sub(a.min);
    }

    pub fn contains(a: AABB, point: Vec3) bool {
        return point.x >= a.min.x and point.x <= a.max.x and
            point.y >= a.min.y and point.y <= a.max.y and
            point.z >= a.min.z and point.z <= a.max.z;
    }

    pub fn intersects(a: AABB, b: AABB) bool {
        return a.max.x >= b.min.x and a.min.x <= b.max.x and
            a.max.y >= b.min.y and a.min.y <= b.max.y and
            a.max.z >= b.min.z and a.min.z <= b.max.z;
    }
};
