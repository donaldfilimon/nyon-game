//! Nyon Math Library
//!
//! SIMD-optimized vector and matrix math operations for game development.
//! Uses Zig's @Vector type for automatic SIMD acceleration.

const std = @import("std");

/// 2D Vector
pub const Vec2 = struct {
    data: @Vector(2, f32),

    pub const ZERO = Vec2{ .data = .{ 0, 0 } };
    pub const ONE = Vec2{ .data = .{ 1, 1 } };
    pub const X = Vec2{ .data = .{ 1, 0 } };
    pub const Y = Vec2{ .data = .{ 0, 1 } };

    pub fn init(x: f32, y: f32) Vec2 {
        return .{ .data = .{ x, y } };
    }

    pub fn x(self: Vec2) f32 {
        return self.data[0];
    }

    pub fn y(self: Vec2) f32 {
        return self.data[1];
    }

    pub fn add(a: Vec2, b: Vec2) Vec2 {
        return .{ .data = a.data + b.data };
    }

    pub fn sub(a: Vec2, b: Vec2) Vec2 {
        return .{ .data = a.data - b.data };
    }

    pub fn scale(v: Vec2, s: f32) Vec2 {
        return .{ .data = v.data * @as(@Vector(2, f32), @splat(s)) };
    }

    pub fn dot(a: Vec2, b: Vec2) f32 {
        const prod = a.data * b.data;
        return prod[0] + prod[1];
    }

    pub fn length(v: Vec2) f32 {
        return @sqrt(dot(v, v));
    }

    pub fn normalize(v: Vec2) Vec2 {
        const len = length(v);
        if (len > 0.0001) {
            return scale(v, 1.0 / len);
        }
        return ZERO;
    }

    pub fn lerp(a: Vec2, b: Vec2, t: f32) Vec2 {
        const t_vec: @Vector(2, f32) = @splat(t);
        const one_minus_t: @Vector(2, f32) = @splat(1.0 - t);
        return .{ .data = a.data * one_minus_t + b.data * t_vec };
    }
};

/// 3D Vector
pub const Vec3 = struct {
    data: @Vector(4, f32), // Use 4 for alignment, w is ignored

    pub const ZERO = Vec3{ .data = .{ 0, 0, 0, 0 } };
    pub const ONE = Vec3{ .data = .{ 1, 1, 1, 0 } };
    pub const X = Vec3{ .data = .{ 1, 0, 0, 0 } };
    pub const Y = Vec3{ .data = .{ 0, 1, 0, 0 } };
    pub const Z = Vec3{ .data = .{ 0, 0, 1, 0 } };
    pub const UP = Y;
    pub const RIGHT = X;
    pub const FORWARD = Vec3{ .data = .{ 0, 0, -1, 0 } };

    pub fn init(vx: f32, vy: f32, vz: f32) Vec3 {
        return .{ .data = .{ vx, vy, vz, 0 } };
    }

    pub fn x(self: Vec3) f32 {
        return self.data[0];
    }

    pub fn y(self: Vec3) f32 {
        return self.data[1];
    }

    pub fn z(self: Vec3) f32 {
        return self.data[2];
    }

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{ .data = a.data + b.data };
    }

    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return .{ .data = a.data - b.data };
    }

    pub fn mul(a: Vec3, b: Vec3) Vec3 {
        return .{ .data = a.data * b.data };
    }

    pub fn scale(v: Vec3, s: f32) Vec3 {
        return .{ .data = v.data * @as(@Vector(4, f32), @splat(s)) };
    }

    pub fn dot(a: Vec3, b: Vec3) f32 {
        const prod = a.data * b.data;
        return prod[0] + prod[1] + prod[2];
    }

    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return Vec3.init(
            a.y() * b.z() - a.z() * b.y(),
            a.z() * b.x() - a.x() * b.z(),
            a.x() * b.y() - a.y() * b.x(),
        );
    }

    pub fn length(v: Vec3) f32 {
        return @sqrt(dot(v, v));
    }

    pub fn lengthSquared(v: Vec3) f32 {
        return dot(v, v);
    }

    pub fn normalize(v: Vec3) Vec3 {
        const len = length(v);
        if (len > 0.0001) {
            return scale(v, 1.0 / len);
        }
        return ZERO;
    }

    pub fn negate(v: Vec3) Vec3 {
        return .{ .data = -v.data };
    }

    pub fn lerp(a: Vec3, b: Vec3, t: f32) Vec3 {
        const t_vec: @Vector(4, f32) = @splat(t);
        const one_minus_t: @Vector(4, f32) = @splat(1.0 - t);
        return .{ .data = a.data * one_minus_t + b.data * t_vec };
    }

    pub fn distance(a: Vec3, b: Vec3) f32 {
        return length(sub(b, a));
    }

    pub fn reflect(v: Vec3, n: Vec3) Vec3 {
        return sub(v, scale(n, 2.0 * dot(v, n)));
    }
};

/// 4D Vector
pub const Vec4 = struct {
    data: @Vector(4, f32),

    pub const ZERO = Vec4{ .data = .{ 0, 0, 0, 0 } };
    pub const ONE = Vec4{ .data = .{ 1, 1, 1, 1 } };

    pub fn init(vx: f32, vy: f32, vz: f32, vw: f32) Vec4 {
        return .{ .data = .{ vx, vy, vz, vw } };
    }

    pub fn fromVec3(v: Vec3, w: f32) Vec4 {
        return .{ .data = .{ v.x(), v.y(), v.z(), w } };
    }

    pub fn x(self: Vec4) f32 {
        return self.data[0];
    }

    pub fn y(self: Vec4) f32 {
        return self.data[1];
    }

    pub fn z(self: Vec4) f32 {
        return self.data[2];
    }

    pub fn w(self: Vec4) f32 {
        return self.data[3];
    }

    pub fn xyz(self: Vec4) Vec3 {
        return Vec3.init(self.x(), self.y(), self.z());
    }

    pub fn add(a: Vec4, b: Vec4) Vec4 {
        return .{ .data = a.data + b.data };
    }

    pub fn sub(a: Vec4, b: Vec4) Vec4 {
        return .{ .data = a.data - b.data };
    }

    pub fn scale(v: Vec4, s: f32) Vec4 {
        return .{ .data = v.data * @as(@Vector(4, f32), @splat(s)) };
    }

    pub fn dot(a: Vec4, b: Vec4) f32 {
        const prod = a.data * b.data;
        return prod[0] + prod[1] + prod[2] + prod[3];
    }
};

/// 4x4 Matrix (column-major)
pub const Mat4 = struct {
    cols: [4]@Vector(4, f32),

    pub const IDENTITY = Mat4{
        .cols = .{
            .{ 1, 0, 0, 0 },
            .{ 0, 1, 0, 0 },
            .{ 0, 0, 1, 0 },
            .{ 0, 0, 0, 1 },
        },
    };

    pub const ZERO = Mat4{
        .cols = .{
            .{ 0, 0, 0, 0 },
            .{ 0, 0, 0, 0 },
            .{ 0, 0, 0, 0 },
            .{ 0, 0, 0, 0 },
        },
    };

    pub fn translation(t: Vec3) Mat4 {
        return .{
            .cols = .{
                .{ 1, 0, 0, 0 },
                .{ 0, 1, 0, 0 },
                .{ 0, 0, 1, 0 },
                .{ t.x(), t.y(), t.z(), 1 },
            },
        };
    }

    pub fn scaling(s: Vec3) Mat4 {
        return .{
            .cols = .{
                .{ s.x(), 0, 0, 0 },
                .{ 0, s.y(), 0, 0 },
                .{ 0, 0, s.z(), 0 },
                .{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn rotationX(angle: f32) Mat4 {
        const c = @cos(angle);
        const s = @sin(angle);
        return .{
            .cols = .{
                .{ 1, 0, 0, 0 },
                .{ 0, c, s, 0 },
                .{ 0, -s, c, 0 },
                .{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn rotationY(angle: f32) Mat4 {
        const c = @cos(angle);
        const s = @sin(angle);
        return .{
            .cols = .{
                .{ c, 0, -s, 0 },
                .{ 0, 1, 0, 0 },
                .{ s, 0, c, 0 },
                .{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn rotationZ(angle: f32) Mat4 {
        const c = @cos(angle);
        const s = @sin(angle);
        return .{
            .cols = .{
                .{ c, s, 0, 0 },
                .{ -s, c, 0, 0 },
                .{ 0, 0, 1, 0 },
                .{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn perspective(fov_y: f32, aspect: f32, near: f32, far: f32) Mat4 {
        const tan_half_fov = @tan(fov_y / 2.0);
        const f = 1.0 / tan_half_fov;
        const range = far - near;

        return .{
            .cols = .{
                .{ f / aspect, 0, 0, 0 },
                .{ 0, f, 0, 0 },
                .{ 0, 0, -(far + near) / range, -1 },
                .{ 0, 0, -(2.0 * far * near) / range, 0 },
            },
        };
    }

    pub fn orthographic(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) Mat4 {
        const width = right - left;
        const height = top - bottom;
        const depth = far - near;

        return .{
            .cols = .{
                .{ 2.0 / width, 0, 0, 0 },
                .{ 0, 2.0 / height, 0, 0 },
                .{ 0, 0, -2.0 / depth, 0 },
                .{ -(right + left) / width, -(top + bottom) / height, -(far + near) / depth, 1 },
            },
        };
    }

    pub fn lookAt(eye: Vec3, target: Vec3, up: Vec3) Mat4 {
        const f = Vec3.normalize(Vec3.sub(target, eye));
        const s = Vec3.normalize(Vec3.cross(f, up));
        const u = Vec3.cross(s, f);

        return .{
            .cols = .{
                .{ s.x(), u.x(), -f.x(), 0 },
                .{ s.y(), u.y(), -f.y(), 0 },
                .{ s.z(), u.z(), -f.z(), 0 },
                .{ -Vec3.dot(s, eye), -Vec3.dot(u, eye), Vec3.dot(f, eye), 1 },
            },
        };
    }

    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        var result: Mat4 = ZERO;
        inline for (0..4) |col| {
            inline for (0..4) |row| {
                var sum: f32 = 0;
                inline for (0..4) |k| {
                    sum += a.cols[k][row] * b.cols[col][k];
                }
                result.cols[col][row] = sum;
            }
        }
        return result;
    }

    pub fn mulVec4(m: Mat4, v: Vec4) Vec4 {
        var result: @Vector(4, f32) = @splat(0);
        inline for (0..4) |col| {
            result += m.cols[col] * @as(@Vector(4, f32), @splat(v.data[col]));
        }
        return .{ .data = result };
    }

    pub fn transpose(m: Mat4) Mat4 {
        return .{
            .cols = .{
                .{ m.cols[0][0], m.cols[1][0], m.cols[2][0], m.cols[3][0] },
                .{ m.cols[0][1], m.cols[1][1], m.cols[2][1], m.cols[3][1] },
                .{ m.cols[0][2], m.cols[1][2], m.cols[2][2], m.cols[3][2] },
                .{ m.cols[0][3], m.cols[1][3], m.cols[2][3], m.cols[3][3] },
            },
        };
    }
};

/// Quaternion for 3D rotations
pub const Quat = struct {
    data: @Vector(4, f32), // x, y, z, w

    pub const IDENTITY = Quat{ .data = .{ 0, 0, 0, 1 } };

    pub fn init(qx: f32, qy: f32, qz: f32, qw: f32) Quat {
        return .{ .data = .{ qx, qy, qz, qw } };
    }

    pub fn x(self: Quat) f32 {
        return self.data[0];
    }

    pub fn y(self: Quat) f32 {
        return self.data[1];
    }

    pub fn z(self: Quat) f32 {
        return self.data[2];
    }

    pub fn w(self: Quat) f32 {
        return self.data[3];
    }

    pub fn fromAxisAngle(axis: Vec3, angle: f32) Quat {
        const half_angle = angle * 0.5;
        const s = @sin(half_angle);
        const n = Vec3.normalize(axis);
        return .{
            .data = .{ n.x() * s, n.y() * s, n.z() * s, @cos(half_angle) },
        };
    }

    pub fn fromEuler(pitch: f32, yaw: f32, roll: f32) Quat {
        const cp = @cos(pitch * 0.5);
        const sp = @sin(pitch * 0.5);
        const cy = @cos(yaw * 0.5);
        const sy = @sin(yaw * 0.5);
        const cr = @cos(roll * 0.5);
        const sr = @sin(roll * 0.5);

        return Quat.init(
            sr * cp * cy - cr * sp * sy,
            cr * sp * cy + sr * cp * sy,
            cr * cp * sy - sr * sp * cy,
            cr * cp * cy + sr * sp * sy,
        );
    }

    pub fn mul(a: Quat, b: Quat) Quat {
        return Quat.init(
            a.w() * b.x() + a.x() * b.w() + a.y() * b.z() - a.z() * b.y(),
            a.w() * b.y() - a.x() * b.z() + a.y() * b.w() + a.z() * b.x(),
            a.w() * b.z() + a.x() * b.y() - a.y() * b.x() + a.z() * b.w(),
            a.w() * b.w() - a.x() * b.x() - a.y() * b.y() - a.z() * b.z(),
        );
    }

    pub fn normalize(q: Quat) Quat {
        const len = @sqrt(q.data[0] * q.data[0] + q.data[1] * q.data[1] + q.data[2] * q.data[2] + q.data[3] * q.data[3]);
        if (len > 0.0001) {
            return .{ .data = q.data / @as(@Vector(4, f32), @splat(len)) };
        }
        return IDENTITY;
    }

    pub fn conjugate(q: Quat) Quat {
        return .{ .data = .{ -q.x(), -q.y(), -q.z(), q.w() } };
    }

    pub fn rotateVec3(q: Quat, v: Vec3) Vec3 {
        const qv = Vec3.init(q.x(), q.y(), q.z());
        const uv = Vec3.cross(qv, v);
        const uuv = Vec3.cross(qv, uv);
        return Vec3.add(Vec3.add(v, Vec3.scale(uv, 2.0 * q.w())), Vec3.scale(uuv, 2.0));
    }

    pub fn toMat4(q: Quat) Mat4 {
        const xx = q.x() * q.x();
        const xy = q.x() * q.y();
        const xz = q.x() * q.z();
        const xw = q.x() * q.w();
        const yy = q.y() * q.y();
        const yz = q.y() * q.z();
        const yw = q.y() * q.w();
        const zz = q.z() * q.z();
        const zw = q.z() * q.w();

        return .{
            .cols = .{
                .{ 1 - 2 * (yy + zz), 2 * (xy + zw), 2 * (xz - yw), 0 },
                .{ 2 * (xy - zw), 1 - 2 * (xx + zz), 2 * (yz + xw), 0 },
                .{ 2 * (xz + yw), 2 * (yz - xw), 1 - 2 * (xx + yy), 0 },
                .{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn slerp(a: Quat, b: Quat, t: f32) Quat {
        var cos_theta = a.data[0] * b.data[0] + a.data[1] * b.data[1] + a.data[2] * b.data[2] + a.data[3] * b.data[3];

        var b_adj = b;
        if (cos_theta < 0) {
            b_adj.data = -b.data;
            cos_theta = -cos_theta;
        }

        if (cos_theta > 0.9995) {
            // Linear interpolation for nearly parallel quaternions
            const t_vec: @Vector(4, f32) = @splat(t);
            const one_minus_t: @Vector(4, f32) = @splat(1.0 - t);
            return Quat.normalize(.{ .data = a.data * one_minus_t + b_adj.data * t_vec });
        }

        const theta = std.math.acos(cos_theta);
        const sin_theta = @sin(theta);
        const s0 = @sin((1.0 - t) * theta) / sin_theta;
        const s1 = @sin(t * theta) / sin_theta;

        return .{
            .data = a.data * @as(@Vector(4, f32), @splat(s0)) + b_adj.data * @as(@Vector(4, f32), @splat(s1)),
        };
    }
};

/// Common math constants and utilities
pub const PI: f32 = std.math.pi;
pub const TAU: f32 = std.math.tau;
pub const DEG_TO_RAD: f32 = PI / 180.0;
pub const RAD_TO_DEG: f32 = 180.0 / PI;

pub fn radians(degrees: f32) f32 {
    return degrees * DEG_TO_RAD;
}

pub fn degrees(rads: f32) f32 {
    return rads * RAD_TO_DEG;
}

pub fn clamp(val: f32, min_val: f32, max_val: f32) f32 {
    return @min(@max(val, min_val), max_val);
}

pub fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

pub fn smoothstep(edge0: f32, edge1: f32, x: f32) f32 {
    const t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

test "Vec3 operations" {
    const a = Vec3.init(1, 2, 3);
    const b = Vec3.init(4, 5, 6);

    const sum = Vec3.add(a, b);
    try std.testing.expectApproxEqAbs(@as(f32, 5), sum.x(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 7), sum.y(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 9), sum.z(), 0.001);

    const d = Vec3.dot(a, b);
    try std.testing.expectApproxEqAbs(@as(f32, 32), d, 0.001);
}

test "Mat4 perspective" {
    const proj = Mat4.perspective(radians(60.0), 16.0 / 9.0, 0.1, 1000.0);
    try std.testing.expect(proj.cols[0][0] != 0);
}

test "Quaternion rotation" {
    const q = Quat.fromAxisAngle(Vec3.Y, radians(90.0));
    const v = Vec3.X;
    const rotated = Quat.rotateVec3(q, v);
    try std.testing.expectApproxEqAbs(@as(f32, 0), rotated.x(), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, -1), rotated.z(), 0.01);
}
