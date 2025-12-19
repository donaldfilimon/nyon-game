//! Collision Detection System - Broad and Narrow Phase
//!
//! This module implements collision detection with a two-phase approach:
//! 1. Broad phase: AABB overlap tests for potential collisions
//! 2. Narrow phase: Precise collision detection for overlapping pairs

const std = @import("std");
const types = @import("types.zig");

/// Collision shape types
pub const ShapeType = enum {
    sphere_collider,
    box_collider,
    capsule_collider,
    mesh_collider,
};

/// Generic collision shape
pub const Collider = union(ShapeType) {
    sphere_collider: Sphere,
    box_collider: Box,
    capsule_collider: Capsule,
    mesh_collider: Mesh,

    /// Create a sphere collider
    pub fn sphere(center: types.Vector3, radius: f32) Collider {
        return .{ .sphere_collider = Sphere.init(center, radius) };
    }

    /// Create a box collider
    pub fn box(center: types.Vector3, half_extents: types.Vector3) Collider {
        return .{ .box_collider = Box.init(center, half_extents) };
    }

    /// Create a capsule collider
    pub fn capsule(center: types.Vector3, radius: f32, height: f32) Collider {
        return .{ .capsule_collider = Capsule.init(center, radius, height) };
    }

    /// Get the axis-aligned bounding box of this collider
    pub fn getAABB(self: Collider) types.AABB {
        return switch (self) {
            .sphere_collider => |s| s.getAABB(),
            .box_collider => |b| b.getAABB(),
            .capsule_collider => |c| c.getAABB(),
            .mesh_collider => |m| m.getAABB(),
        };
    }

    /// Test collision with another collider
    pub fn collidesWith(self: Collider, other: Collider) ?types.ContactManifold {
        return switch (self) {
            .sphere_collider => |a| switch (other) {
                .sphere_collider => |b| a.collidesWithSphere(b),
                .box_collider => |b| a.collidesWithBox(b),
                .capsule_collider => |b| a.collidesWithCapsule(b),
                .mesh_collider => null, // Not implemented yet
            },
            .box_collider => |a| switch (other) {
                .sphere_collider => |b| b.collidesWithBox(a), // Reuse sphere-box
                .box_collider => |b| a.collidesWithBox(b),
                .capsule_collider => |b| a.collidesWithCapsule(b),
                .mesh_collider => null, // Not implemented yet
            },
            .capsule_collider => |a| switch (other) {
                .sphere_collider => |b| b.collidesWithCapsule(a), // Reuse sphere-capsule
                .box_collider => |b| b.collidesWithCapsule(a), // Reuse box-capsule
                .capsule_collider => |b| a.collidesWithCapsule(b),
                .mesh_collider => null, // Not implemented yet
            },
            .mesh_collider => null, // Not implemented yet
        };
    }

    /// Perform ray casting against this collider
    pub fn raycast(self: Collider, ray: types.Ray) ?types.RaycastHit {
        return switch (self) {
            .sphere_collider => |s| s.raycast(ray),
            .box_collider => |b| b.raycast(ray),
            .capsule_collider => |c| c.raycast(ray),
            .mesh_collider => |m| m.raycast(ray),
        };
    }
};

/// Sphere collision shape
pub const Sphere = struct {
    center: types.Vector3,
    radius: f32,

    pub fn init(center: types.Vector3, radius: f32) Sphere {
        return .{ .center = center, .radius = radius };
    }

    pub fn getAABB(self: Sphere) types.AABB {
        const half_extents = types.Vector3.init(self.radius, self.radius, self.radius);
        return types.AABB.fromCenterExtent(self.center, half_extents);
    }

    pub fn collidesWithSphere(self: Sphere, other: Sphere) ?types.ContactManifold {
        const distance = self.center.distance(other.center);
        const sum_radii = self.radius + other.radius;

        if (distance >= sum_radii) return null;

        const normal = if (distance > 0) other.center.sub(self.center).normalize() else types.Vector3.up();
        const penetration = sum_radii - distance;

        return types.ContactManifold{
            .point_a = self.center.add(normal.mul(self.radius)),
            .point_b = other.center.sub(normal.mul(other.radius)),
            .normal = normal,
            .penetration = penetration,
            .body_a = 0, // Set by caller
            .body_b = 0, // Set by caller
        };
    }

    pub fn collidesWithBox(self: Sphere, box: Box) ?types.ContactManifold {
        // Find closest point on box to sphere center
        const closest = box.clampPoint(self.center);
        const distance = self.center.distance(closest);

        if (distance >= self.radius) return null;

        const normal = if (distance > 0) self.center.sub(closest).normalize() else types.Vector3.up();
        const penetration = self.radius - distance;

        return types.ContactManifold{
            .point_a = closest,
            .point_b = self.center.sub(normal.mul(self.radius)),
            .normal = normal,
            .penetration = penetration,
            .body_a = 0,
            .body_b = 0,
        };
    }

    pub fn collidesWithCapsule(self: Sphere, capsule: Capsule) ?types.ContactManifold {
        // Simplified: treat capsule as sphere for now
        const capsule_sphere = Sphere.init(capsule.center, capsule.radius);
        return self.collidesWithSphere(capsule_sphere);
    }

    pub fn raycast(self: Sphere, ray: types.Ray) ?types.RaycastHit {
        // Ray-sphere intersection
        const oc = ray.origin.sub(self.center);
        const a = ray.direction.dot(ray.direction);
        const b = 2.0 * oc.dot(ray.direction);
        const c = oc.dot(oc) - self.radius * self.radius;

        const discriminant = b * b - 4 * a * c;
        if (discriminant < 0) return null;

        const sqrt_d = @sqrt(discriminant);
        const t1 = (-b - sqrt_d) / (2 * a);
        const t2 = (-b + sqrt_d) / (2 * a);

        var t = t1;
        if (t < 0) t = t2;
        if (t < 0) return null;

        const point = ray.at(t);
        const normal = point.sub(self.center).normalize();

        return types.RaycastHit{
            .point = point,
            .normal = normal,
            .distance = t,
            .collider_id = 0, // Set by caller
        };
    }
};

/// Box collision shape (axis-aligned)
pub const Box = struct {
    center: types.Vector3,
    half_extents: types.Vector3,

    pub fn init(center: types.Vector3, half_extents: types.Vector3) Box {
        return .{ .center = center, .half_extents = half_extents };
    }

    pub fn getAABB(self: Box) types.AABB {
        return types.AABB.fromCenterExtent(self.center, self.half_extents);
    }

    /// Clamp a point to the box boundaries
    pub fn clampPoint(self: Box, point: types.Vector3) types.Vector3 {
        const min = self.center.sub(self.half_extents);
        const max = self.center.add(self.half_extents);

        return types.Vector3.init(
            std.math.clamp(point.x, min.x, max.x),
            std.math.clamp(point.y, min.y, max.y),
            std.math.clamp(point.z, min.z, max.z),
        );
    }

    pub fn collidesWithBox(self: Box, other: Box) ?types.ContactManifold {
        const a_min = self.center.sub(self.half_extents);
        const a_max = self.center.add(self.half_extents);
        const b_min = other.center.sub(other.half_extents);
        const b_max = other.center.add(other.half_extents);

        // Check for overlap
        if (a_max.x < b_min.x or a_min.x > b_max.x or
            a_max.y < b_min.y or a_min.y > b_max.y or
            a_max.z < b_min.z or a_min.z > b_max.z)
        {
            return null;
        }

        // Find penetration and normal (simplified)
        const overlap_x = @min(a_max.x, b_max.x) - @max(a_min.x, b_min.x);
        const overlap_y = @min(a_max.y, b_max.y) - @max(a_min.y, b_min.y);
        const overlap_z = @min(a_max.z, b_max.z) - @max(a_min.z, b_min.z);

        var min_overlap = overlap_x;
        var normal = types.Vector3.init(1, 0, 0);

        if (overlap_y < min_overlap) {
            min_overlap = overlap_y;
            normal = types.Vector3.init(0, 1, 0);
        }
        if (overlap_z < min_overlap) {
            min_overlap = overlap_z;
            normal = types.Vector3.init(0, 0, 1);
        }

        // Determine normal direction
        const center_diff = other.center.sub(self.center);
        if (normal.dot(center_diff) < 0) {
            normal = normal.mul(-1);
        }

        return types.ContactManifold{
            .point_a = self.center,
            .point_b = other.center,
            .normal = normal,
            .penetration = min_overlap,
            .body_a = 0,
            .body_b = 0,
        };
    }

    pub fn collidesWithCapsule(self: Box, capsule: Capsule) ?types.ContactManifold {
        // Simplified: treat capsule as box for now
        const capsule_half_extents = types.Vector3.init(capsule.radius, capsule.height * 0.5, capsule.radius);
        const capsule_box = Box.init(capsule.center, capsule_half_extents);
        return self.collidesWithBox(capsule_box);
    }

    pub fn raycast(self: Box, ray: types.Ray) ?types.RaycastHit {
        // Slab method for AABB ray intersection
        const min = self.center.sub(self.half_extents);
        const max = self.center.add(self.half_extents);

        var t_min: f32 = 0;
        var t_max: f32 = std.math.inf(f32);

        // X slab
        if (@abs(ray.direction.x) > 0.0001) {
            const tx1 = (min.x - ray.origin.x) / ray.direction.x;
            const tx2 = (max.x - ray.origin.x) / ray.direction.x;
            t_min = @max(t_min, @min(tx1, tx2));
            t_max = @min(t_max, @max(tx1, tx2));
        } else if (ray.origin.x < min.x or ray.origin.x > max.x) {
            return null;
        }

        // Y slab
        if (@abs(ray.direction.y) > 0.0001) {
            const ty1 = (min.y - ray.origin.y) / ray.direction.y;
            const ty2 = (max.y - ray.origin.y) / ray.direction.y;
            t_min = @max(t_min, @min(ty1, ty2));
            t_max = @min(t_max, @max(ty1, ty2));
        } else if (ray.origin.y < min.y or ray.origin.y > max.y) {
            return null;
        }

        // Z slab
        if (@abs(ray.direction.z) > 0.0001) {
            const tz1 = (min.z - ray.origin.z) / ray.direction.z;
            const tz2 = (max.z - ray.origin.z) / ray.direction.z;
            t_min = @max(t_min, @min(tz1, tz2));
            t_max = @min(t_max, @max(tz1, tz2));
        } else if (ray.origin.z < min.z or ray.origin.z > max.z) {
            return null;
        }

        if (t_max < t_min or t_max < 0) return null;

        const t = if (t_min > 0) t_min else t_max;
        const point = ray.at(t);

        // Calculate normal (simplified - assumes we hit a face)
        var normal = types.Vector3.zero();
        const epsilon = 0.001;

        if (@abs(point.x - min.x) < epsilon) normal.x = -1 else if (@abs(point.x - max.x) < epsilon) normal.x = 1 else if (@abs(point.y - min.y) < epsilon) normal.y = -1 else if (@abs(point.y - max.y) < epsilon) normal.y = 1 else if (@abs(point.z - min.z) < epsilon) normal.z = -1 else if (@abs(point.z - max.z) < epsilon) normal.z = 1;

        return types.RaycastHit{
            .point = point,
            .normal = normal,
            .distance = t,
            .collider_id = 0,
        };
    }
};

/// Capsule collision shape (cylinder with hemispherical caps)
pub const Capsule = struct {
    center: types.Vector3,
    radius: f32,
    height: f32,

    pub fn init(center: types.Vector3, radius: f32, height: f32) Capsule {
        return .{ .center = center, .radius = radius, .height = height };
    }

    pub fn getAABB(self: Capsule) types.AABB {
        const half_height = self.height * 0.5;
        const half_extents = types.Vector3.init(
            self.radius,
            half_height + self.radius,
            self.radius,
        );
        return types.AABB.fromCenterExtent(self.center, half_extents);
    }

    pub fn collidesWithCapsule(self: Capsule, other: Capsule) ?types.ContactManifold {
        // Simplified capsule-capsule collision
        // Treat as spheres for now
        const sphere_a = Sphere.init(self.center, self.radius);
        const sphere_b = Sphere.init(other.center, other.radius);
        return sphere_a.collidesWithSphere(sphere_b);
    }

    pub fn raycast(self: Capsule, ray: types.Ray) ?types.RaycastHit {
        // Simplified: treat as sphere for raycasting
        const sphere = Sphere.init(self.center, self.radius);
        return sphere.raycast(ray);
    }
};

/// Triangle mesh collision shape (placeholder)
pub const Mesh = struct {
    triangles: []types.Vector3, // Triangle vertices

    pub fn getAABB(self: Mesh) types.AABB {
        _ = self;
        // Would compute AABB from all triangles
        return types.AABB.init(types.Vector3.zero(), types.Vector3.one());
    }

    pub fn raycast(self: Mesh, ray: types.Ray) ?types.RaycastHit {
        _ = self;
        _ = ray;
        // Would implement triangle-ray intersection
        return null;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "sphere collision" {
    const sphere_a = Sphere.init(types.Vector3.init(0, 0, 0), 1.0);
    const sphere_b = Sphere.init(types.Vector3.init(1.5, 0, 0), 1.0);

    const manifold = sphere_a.collidesWithSphere(sphere_b);
    try std.testing.expect(manifold != null);
    try std.testing.expect(manifold.?.penetration > 0);
}

test "box AABB" {
    const box = Box.init(types.Vector3.init(0, 0, 0), types.Vector3.init(1, 2, 3));
    const aabb = box.getAABB();

    try std.testing.expect(aabb.min.x == -1);
    try std.testing.expect(aabb.max.x == 1);
    try std.testing.expect(aabb.min.y == -2);
    try std.testing.expect(aabb.max.y == 2);
    try std.testing.expect(aabb.min.z == -3);
    try std.testing.expect(aabb.max.z == 3);
}

test "AABB intersection" {
    const aabb1 = types.AABB.init(types.Vector3.init(0, 0, 0), types.Vector3.init(2, 2, 2));
    const aabb2 = types.AABB.init(types.Vector3.init(1, 1, 1), types.Vector3.init(3, 3, 3));

    try std.testing.expect(aabb1.intersects(aabb2));

    const aabb3 = types.AABB.init(types.Vector3.init(5, 5, 5), types.Vector3.init(6, 6, 6));
    try std.testing.expect(!aabb1.intersects(aabb3));
}
