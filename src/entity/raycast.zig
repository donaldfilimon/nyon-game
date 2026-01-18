//! Entity Raycasting
//!
//! Provides raycasting functionality for detecting entity hits.
//! Used for player attacks, line-of-sight checks, and targeting.

const std = @import("std");
const math = @import("../math/math.zig");
const collision = @import("../physics/collision.zig");
const ecs = @import("ecs.zig");
const components = @import("components.zig");

const Vec3 = math.Vec3;
const Ray = collision.Ray;
const AABB = collision.AABB;
const EntityWorld = ecs.EntityWorld;
const Entity = ecs.Entity;
const Transform = components.Transform;
const Collider = components.Collider;
const Health = components.Health;

/// Result of an entity raycast
pub const EntityRaycastHit = struct {
    /// The entity that was hit
    entity: Entity,
    /// Distance from ray origin to hit point
    distance: f32,
    /// World-space hit point
    hit_point: Vec3,
    /// Surface normal at hit point
    normal: Vec3,
};

/// Raycast against all entities in the world with colliders
/// Returns the closest hit within max_distance, or null if nothing was hit
pub fn raycastEntities(
    world: *EntityWorld,
    origin: Vec3,
    direction: Vec3,
    max_distance: f32,
) ?EntityRaycastHit {
    const ray = Ray{
        .origin = origin,
        .direction = Vec3.normalize(direction),
    };

    var closest_hit: ?EntityRaycastHit = null;
    var closest_distance: f32 = max_distance;

    // Get entities that have colliders
    const entities_with_colliders = world.getEntitiesWith(Collider);

    // Check each entity with a collider
    for (entities_with_colliders) |entity| {
        // Get transform for this entity
        const transform = world.getComponent(entity, Transform) orelse continue;
        const collider = world.getComponent(entity, Collider) orelse continue;

        // Build world-space AABB
        const world_aabb = collider.getWorldAABB(transform.position);

        // Test ray against AABB
        if (collision.rayVsAABB(ray, world_aabb)) |hit| {
            if (hit.distance >= 0 and hit.distance < closest_distance) {
                closest_distance = hit.distance;
                closest_hit = .{
                    .entity = entity,
                    .distance = hit.distance,
                    .hit_point = hit.point,
                    .normal = hit.normal,
                };
            }
        }
    }

    return closest_hit;
}

/// Raycast against entities, filtering to only those with Health component (damageable)
pub fn raycastDamageableEntities(
    world: *EntityWorld,
    origin: Vec3,
    direction: Vec3,
    max_distance: f32,
) ?EntityRaycastHit {
    const ray = Ray{
        .origin = origin,
        .direction = Vec3.normalize(direction),
    };

    var closest_hit: ?EntityRaycastHit = null;
    var closest_distance: f32 = max_distance;

    // Get entities that have colliders
    const entities_with_colliders = world.getEntitiesWith(Collider);

    // Check each entity with a collider
    for (entities_with_colliders) |entity| {
        // Must have health to be damageable
        if (world.getComponent(entity, Health) == null) continue;

        // Get transform for this entity
        const transform = world.getComponent(entity, Transform) orelse continue;
        const collider = world.getComponent(entity, Collider) orelse continue;

        // Build world-space AABB
        const world_aabb = collider.getWorldAABB(transform.position);

        // Test ray against AABB
        if (collision.rayVsAABB(ray, world_aabb)) |hit| {
            if (hit.distance >= 0 and hit.distance < closest_distance) {
                closest_distance = hit.distance;
                closest_hit = .{
                    .entity = entity,
                    .distance = hit.distance,
                    .hit_point = hit.point,
                    .normal = hit.normal,
                };
            }
        }
    }

    return closest_hit;
}

/// Check if there's a clear line of sight between two points (no entity in the way)
pub fn hasLineOfSight(
    world: *EntityWorld,
    from: Vec3,
    to: Vec3,
    ignore_entity: ?Entity,
) bool {
    const direction = Vec3.sub(to, from);
    const distance = Vec3.length(direction);

    if (distance < 0.001) return true;

    const ray = Ray{
        .origin = from,
        .direction = Vec3.normalize(direction),
    };

    // Get entities that have colliders
    const entities_with_colliders = world.getEntitiesWith(Collider);

    for (entities_with_colliders) |entity| {
        // Skip ignored entity
        if (ignore_entity) |ignored| {
            if (entity.index == ignored.index and entity.generation == ignored.generation) continue;
        }

        const transform = world.getComponent(entity, Transform) orelse continue;
        const collider = world.getComponent(entity, Collider) orelse continue;

        const world_aabb = collider.getWorldAABB(transform.position);

        if (collision.rayVsAABB(ray, world_aabb)) |hit| {
            if (hit.distance >= 0 and hit.distance < distance) {
                return false; // Something is blocking the line of sight
            }
        }
    }

    return true;
}

/// Get all entities within a sphere (for area effects)
pub fn getEntitiesInSphere(
    world: *EntityWorld,
    center: Vec3,
    radius: f32,
    allocator: std.mem.Allocator,
) !std.ArrayList(Entity) {
    var result = std.ArrayList(Entity).init(allocator);
    errdefer result.deinit();

    const radius_sq = radius * radius;

    // Get entities with colliders for more accurate detection
    const entities_with_colliders = world.getEntitiesWith(Collider);

    if (entities_with_colliders.len > 0) {
        for (entities_with_colliders) |entity| {
            const transform = world.getComponent(entity, Transform) orelse continue;
            const collider = world.getComponent(entity, Collider) orelse continue;

            // Check if sphere overlaps AABB
            const aabb = collider.getWorldAABB(transform.position);
            if (sphereVsAABB(center, radius, aabb)) {
                try result.append(entity);
            }
        }
    } else {
        // Fallback: just check transform positions for entities with transforms
        const entities_with_transforms = world.getEntitiesWith(Transform);
        for (entities_with_transforms) |entity| {
            const transform = world.getComponent(entity, Transform) orelse continue;
            const dist_sq = Vec3.lengthSquared(Vec3.sub(transform.position, center));
            if (dist_sq <= radius_sq) {
                try result.append(entity);
            }
        }
    }

    return result;
}

/// Check if a sphere overlaps an AABB
fn sphereVsAABB(sphere_center: Vec3, sphere_radius: f32, aabb: AABB) bool {
    // Find closest point on AABB to sphere center
    const closest = Vec3.init(
        std.math.clamp(sphere_center.x(), aabb.min.x(), aabb.max.x()),
        std.math.clamp(sphere_center.y(), aabb.min.y(), aabb.max.y()),
        std.math.clamp(sphere_center.z(), aabb.min.z(), aabb.max.z()),
    );

    // Check if that point is within sphere radius
    const dist_sq = Vec3.lengthSquared(Vec3.sub(sphere_center, closest));
    return dist_sq <= sphere_radius * sphere_radius;
}

// ============================================================================
// Tests
// ============================================================================

test "sphere vs AABB" {
    const aabb = AABB{
        .min = Vec3.init(0, 0, 0),
        .max = Vec3.init(1, 1, 1),
    };

    // Sphere overlapping AABB
    try std.testing.expect(sphereVsAABB(Vec3.init(0.5, 0.5, 0.5), 0.1, aabb));

    // Sphere outside AABB
    try std.testing.expect(!sphereVsAABB(Vec3.init(5, 5, 5), 0.1, aabb));

    // Sphere touching edge
    try std.testing.expect(sphereVsAABB(Vec3.init(1.5, 0.5, 0.5), 0.6, aabb));
}
