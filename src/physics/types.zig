//! Physics System - Rigid Body Dynamics and Collision Detection
//!
//! This module provides a complete physics simulation system integrated with the ECS.
//! It includes rigid body dynamics, collision detection, and constraint solving for
//! realistic game physics.

const std = @import("std");
const Vec3 = @Vector(3, f32);
const Mat4 = @Vector(16, f32);

// ============================================================================
// Core Physics Types
// ============================================================================

/// 3D vector for physics calculations
pub const Vector3 = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,

    pub fn init(x: f32, y: f32, z: f32) Vector3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn zero() Vector3 {
        return .{ .x = 0, .y = 0, .z = 0 };
    }

    pub fn one() Vector3 {
        return .{ .x = 1, .y = 1, .z = 1 };
    }

    pub fn up() Vector3 {
        return .{ .x = 0, .y = 1, .z = 0 };
    }

    pub fn add(a: Vector3, b: Vector3) Vector3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn sub(a: Vector3, b: Vector3) Vector3 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }

    pub fn mul(v: Vector3, s: f32) Vector3 {
        return .{ .x = v.x * s, .y = v.y * s, .z = v.z * s };
    }

    pub fn dot(a: Vector3, b: Vector3) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn cross(a: Vector3, b: Vector3) Vector3 {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }

    pub fn length(v: Vector3) f32 {
        return @sqrt(v.dot(v));
    }

    pub fn normalize(v: Vector3) Vector3 {
        const len = v.length();
        if (len > 0) {
            return v.mul(1.0 / len);
        }
        return Vector3.zero();
    }

    pub fn distance(a: Vector3, b: Vector3) f32 {
        return a.sub(b).length();
    }
};

/// Quaternion for 3D rotations
pub const Quaternion = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    w: f32 = 1,

    pub fn identity() Quaternion {
        return .{ .x = 0, .y = 0, .z = 0, .w = 1 };
    }

    pub fn fromEuler(pitch: f32, yaw: f32, roll: f32) Quaternion {
        const cr = @cos(roll * 0.5);
        const sr = @sin(roll * 0.5);
        const cp = @cos(pitch * 0.5);
        const sp = @sin(pitch * 0.5);
        const cy = @cos(yaw * 0.5);
        const sy = @sin(yaw * 0.5);

        return .{
            .w = cr * cp * cy + sr * sp * sy,
            .x = sr * cp * cy - cr * sp * sy,
            .y = cr * sp * cy + sr * cp * sy,
            .z = cr * cp * sy - sr * sp * cy,
        };
    }

    pub fn mul(a: Quaternion, b: Quaternion) Quaternion {
        return .{
            .w = a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
            .x = a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
            .y = a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
            .z = a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
        };
    }

    pub fn conjugate(q: Quaternion) Quaternion {
        return .{
            .w = q.w,
            .x = -q.x,
            .y = -q.y,
            .z = -q.z,
        };
    }

    pub fn rotateVector(q: Quaternion, v: Vector3) Vector3 {
        const qv = Quaternion{ .x = v.x, .y = v.y, .z = v.z, .w = 0 };
        const result = q.mul(qv).mul(q.conjugate());
        return .{ .x = result.x, .y = result.y, .z = result.z };
    }
};

/// Axis-aligned bounding box for broad-phase collision detection
pub const AABB = struct {
    min: Vector3,
    max: Vector3,

    pub fn init(min: Vector3, max: Vector3) AABB {
        return .{ .min = min, .max = max };
    }

    pub fn fromCenterExtent(center: Vector3, extent: Vector3) AABB {
        return .{
            .min = center.sub(extent),
            .max = center.add(extent),
        };
    }

    pub fn intersects(a: AABB, b: AABB) bool {
        return !(a.max.x < b.min.x or a.min.x > b.max.x or
            a.max.y < b.min.y or a.min.y > b.max.y or
            a.max.z < b.min.z or a.min.z > b.max.z);
    }

    pub fn contains(a: AABB, point: Vector3) bool {
        return point.x >= a.min.x and point.x <= a.max.x and
            point.y >= a.min.y and point.y <= a.max.y and
            point.z >= a.min.z and point.z <= a.max.z;
    }

    pub fn surfaceArea(a: AABB) f32 {
        const size = a.max.sub(a.min);
        return 2.0 * (size.x * size.y + size.y * size.z + size.z * size.x);
    }
};

/// Ray for ray casting operations
pub const Ray = struct {
    origin: Vector3,
    direction: Vector3,

    pub fn init(origin: Vector3, direction: Vector3) Ray {
        return .{ .origin = origin, .direction = direction.normalize() };
    }

    pub fn at(ray: Ray, t: f32) Vector3 {
        return ray.origin.add(ray.direction.mul(t));
    }
};

/// Ray cast hit result
pub const RaycastHit = struct {
    point: Vector3,
    normal: Vector3,
    distance: f32,
    collider_id: usize,
};

/// 3x3 Matrix for physics calculations
pub const Mat3 = struct {
    m: [9]f32,

    pub fn identity() Mat3 {
        return .{
            .m = [_]f32{
                1, 0, 0,
                0, 1, 0,
                0, 0, 1,
            },
        };
    }

    pub fn zero() Mat3 {
        return .{
            .m = [_]f32{
                0, 0, 0,
                0, 0, 0,
                0, 0, 0,
            },
        };
    }

    pub fn mul(mat: Mat3, scalar: f32) Mat3 {
        var result = Mat3.zero();
        for (mat.m, 0..) |val, i| {
            result.m[i] = val * scalar;
        }
        return result;
    }

    pub fn transform(mat: Mat3, vec: Vector3) Vector3 {
        return .{
            .x = mat.m[0] * vec.x + mat.m[1] * vec.y + mat.m[2] * vec.z,
            .y = mat.m[3] * vec.x + mat.m[4] * vec.y + mat.m[5] * vec.z,
            .z = mat.m[6] * vec.x + mat.m[7] * vec.y + mat.m[8] * vec.z,
        };
    }

    pub fn inverse(mat: Mat3) Mat3 {
        // Simplified matrix inversion for diagonal matrices (common for inertia tensors)
        // In a full implementation, this would handle general 3x3 matrix inversion
        var result = Mat3.zero();
        for (0..3) |i| {
            const idx = i * 3 + i;
            if (mat.m[idx] != 0) {
                result.m[idx] = 1.0 / mat.m[idx];
            }
        }
        return result;
    }
};

/// Collision manifold for contact resolution
pub const ContactManifold = struct {
    point_a: Vector3,
    point_b: Vector3,
    normal: Vector3,
    penetration: f32,
    body_a: usize,
    body_b: usize,
};

/// Physics material properties
pub const PhysicsMaterial = struct {
    friction: f32 = 0.4,
    restitution: f32 = 0.2,
    density: f32 = 1.0,

    pub fn default() PhysicsMaterial {
        return .{};
    }

    pub fn ice() PhysicsMaterial {
        return .{ .friction = 0.1, .restitution = 0.1 };
    }

    pub fn rubber() PhysicsMaterial {
        return .{ .friction = 0.8, .restitution = 0.8 };
    }

    pub fn metal() PhysicsMaterial {
        return .{ .friction = 0.3, .restitution = 0.1 };
    }
};
