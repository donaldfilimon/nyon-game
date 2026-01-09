//! Collision Detection Utilities
//!
//! Provides collision primitives and intersection tests for the physics system.

const std = @import("std");
const math = @import("../math/math.zig");

/// Axis-Aligned Bounding Box
pub const AABB = struct {
    min: math.Vec3,
    max: math.Vec3,

    pub const ZERO = AABB{
        .min = math.Vec3.ZERO,
        .max = math.Vec3.ZERO,
    };

    /// Create AABB from center and half-extents
    pub fn fromCenterExtents(center: math.Vec3, half_extents: math.Vec3) AABB {
        return .{
            .min = math.Vec3.sub(center, half_extents),
            .max = math.Vec3.add(center, half_extents),
        };
    }

    /// Create AABB for a unit cube at position
    pub fn unitCube(position: math.Vec3) AABB {
        return .{
            .min = position,
            .max = math.Vec3.add(position, math.Vec3.ONE),
        };
    }

    /// Get center of AABB
    pub fn center(self: AABB) math.Vec3 {
        return math.Vec3.scale(math.Vec3.add(self.min, self.max), 0.5);
    }

    /// Get size of AABB
    pub fn size(self: AABB) math.Vec3 {
        return math.Vec3.sub(self.max, self.min);
    }

    /// Get half-extents of AABB
    pub fn halfExtents(self: AABB) math.Vec3 {
        return math.Vec3.scale(self.size(), 0.5);
    }

    /// Check if point is inside AABB
    pub fn containsPoint(self: AABB, point: math.Vec3) bool {
        return point.x() >= self.min.x() and point.x() <= self.max.x() and
            point.y() >= self.min.y() and point.y() <= self.max.y() and
            point.z() >= self.min.z() and point.z() <= self.max.z();
    }

    /// Check if two AABBs intersect
    pub fn intersects(self: AABB, other: AABB) bool {
        return self.min.x() <= other.max.x() and self.max.x() >= other.min.x() and
            self.min.y() <= other.max.y() and self.max.y() >= other.min.y() and
            self.min.z() <= other.max.z() and self.max.z() >= other.min.z();
    }

    /// Expand AABB by delta
    pub fn expand(self: AABB, delta: math.Vec3) AABB {
        return .{
            .min = math.Vec3.sub(self.min, delta),
            .max = math.Vec3.add(self.max, delta),
        };
    }

    /// Translate AABB by offset
    pub fn translate(self: AABB, offset: math.Vec3) AABB {
        return .{
            .min = math.Vec3.add(self.min, offset),
            .max = math.Vec3.add(self.max, offset),
        };
    }
};

/// Ray for raycasting
pub const Ray = struct {
    origin: math.Vec3,
    direction: math.Vec3,

    pub fn init(origin: math.Vec3, direction: math.Vec3) Ray {
        return .{
            .origin = origin,
            .direction = math.Vec3.normalize(direction),
        };
    }

    /// Get point along ray at distance t
    pub fn at(self: Ray, t: f32) math.Vec3 {
        return math.Vec3.add(self.origin, math.Vec3.scale(self.direction, t));
    }
};

/// Result of a raycast
pub const RaycastHit = struct {
    point: math.Vec3,
    normal: math.Vec3,
    distance: f32,
    /// Block position (for voxel raycasts)
    block_pos: ?[3]i32 = null,
};

/// Raycast against an AABB
/// Returns distance to hit, or null if no hit
pub fn rayVsAABB(ray: Ray, aabb: AABB) ?RaycastHit {
    var t_min: f32 = 0.0;
    var t_max: f32 = std.math.floatMax(f32);
    var hit_normal = math.Vec3.ZERO;

    // For each axis
    inline for (0..3) |axis| {
        const origin = ray.origin.data[axis];
        const dir = ray.direction.data[axis];
        const min_bound = aabb.min.data[axis];
        const max_bound = aabb.max.data[axis];

        if (@abs(dir) < 0.0001) {
            // Ray parallel to slab
            if (origin < min_bound or origin > max_bound) {
                return null;
            }
        } else {
            var t1 = (min_bound - origin) / dir;
            var t2 = (max_bound - origin) / dir;

            var normal: math.Vec3 = math.Vec3.ZERO;
            normal.data[axis] = -1.0;

            if (t1 > t2) {
                const tmp = t1;
                t1 = t2;
                t2 = tmp;
                normal.data[axis] = 1.0;
            }

            if (t1 > t_min) {
                t_min = t1;
                hit_normal = normal;
            }
            t_max = @min(t_max, t2);

            if (t_min > t_max) {
                return null;
            }
        }
    }

    if (t_min < 0) return null;

    return RaycastHit{
        .point = ray.at(t_min),
        .normal = hit_normal,
        .distance = t_min,
    };
}

/// Sphere collision primitive
pub const Sphere = struct {
    center: math.Vec3,
    radius: f32,

    pub fn containsPoint(self: Sphere, point: math.Vec3) bool {
        return math.Vec3.distance(self.center, point) <= self.radius;
    }

    pub fn intersectsSphere(self: Sphere, other: Sphere) bool {
        const dist = math.Vec3.distance(self.center, other.center);
        return dist <= (self.radius + other.radius);
    }

    pub fn intersectsAABB(self: Sphere, aabb: AABB) bool {
        // Find closest point on AABB to sphere center
        const closest = math.Vec3.init(
            std.math.clamp(self.center.x(), aabb.min.x(), aabb.max.x()),
            std.math.clamp(self.center.y(), aabb.min.y(), aabb.max.y()),
            std.math.clamp(self.center.z(), aabb.min.z(), aabb.max.z()),
        );

        return math.Vec3.distance(self.center, closest) <= self.radius;
    }
};

/// Collision response data
pub const CollisionInfo = struct {
    /// Normalized collision normal (points from A to B)
    normal: math.Vec3,
    /// Penetration depth
    depth: f32,
    /// Contact point
    point: math.Vec3,
};

/// Calculate collision response between two AABBs
pub fn resolveAABBCollision(a: AABB, b: AABB) ?CollisionInfo {
    if (!a.intersects(b)) return null;

    // Calculate overlap on each axis
    const overlap_x = @min(a.max.x() - b.min.x(), b.max.x() - a.min.x());
    const overlap_y = @min(a.max.y() - b.min.y(), b.max.y() - a.min.y());
    const overlap_z = @min(a.max.z() - b.min.z(), b.max.z() - a.min.z());

    // Find minimum overlap axis (MTV - Minimum Translation Vector)
    var normal = math.Vec3.ZERO;
    var depth: f32 = 0;

    if (overlap_x <= overlap_y and overlap_x <= overlap_z) {
        depth = overlap_x;
        if (a.center().x() < b.center().x()) {
            normal = math.Vec3.init(-1, 0, 0);
        } else {
            normal = math.Vec3.init(1, 0, 0);
        }
    } else if (overlap_y <= overlap_x and overlap_y <= overlap_z) {
        depth = overlap_y;
        if (a.center().y() < b.center().y()) {
            normal = math.Vec3.init(0, -1, 0);
        } else {
            normal = math.Vec3.init(0, 1, 0);
        }
    } else {
        depth = overlap_z;
        if (a.center().z() < b.center().z()) {
            normal = math.Vec3.init(0, 0, -1);
        } else {
            normal = math.Vec3.init(0, 0, 1);
        }
    }

    // Contact point is center of overlap region
    const contact = math.Vec3.init(
        ((@max(a.min.x(), b.min.x()) + @min(a.max.x(), b.max.x())) * 0.5),
        ((@max(a.min.y(), b.min.y()) + @min(a.max.y(), b.max.y())) * 0.5),
        ((@max(a.min.z(), b.min.z()) + @min(a.max.z(), b.max.z())) * 0.5),
    );

    return CollisionInfo{
        .normal = normal,
        .depth = depth,
        .point = contact,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "AABB intersection" {
    const a = AABB{
        .min = math.Vec3.init(0, 0, 0),
        .max = math.Vec3.init(2, 2, 2),
    };
    const b = AABB{
        .min = math.Vec3.init(1, 1, 1),
        .max = math.Vec3.init(3, 3, 3),
    };
    const c = AABB{
        .min = math.Vec3.init(5, 5, 5),
        .max = math.Vec3.init(6, 6, 6),
    };

    try std.testing.expect(a.intersects(b));
    try std.testing.expect(!a.intersects(c));
}

test "AABB contains point" {
    const aabb = AABB{
        .min = math.Vec3.init(0, 0, 0),
        .max = math.Vec3.init(1, 1, 1),
    };

    try std.testing.expect(aabb.containsPoint(math.Vec3.init(0.5, 0.5, 0.5)));
    try std.testing.expect(!aabb.containsPoint(math.Vec3.init(2, 0.5, 0.5)));
}

test "ray vs AABB" {
    const aabb = AABB{
        .min = math.Vec3.init(0, 0, 0),
        .max = math.Vec3.init(1, 1, 1),
    };

    // Ray pointing at box
    const ray = Ray.init(
        math.Vec3.init(-1, 0.5, 0.5),
        math.Vec3.init(1, 0, 0),
    );

    const hit = rayVsAABB(ray, aabb);
    try std.testing.expect(hit != null);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), hit.?.distance, 0.001);

    // Ray pointing away
    const miss_ray = Ray.init(
        math.Vec3.init(-1, 0.5, 0.5),
        math.Vec3.init(-1, 0, 0),
    );
    try std.testing.expect(rayVsAABB(miss_ray, aabb) == null);
}
