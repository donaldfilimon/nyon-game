//! Entity Module
//!
//! Entity Component System for mobs, NPCs, and other game entities.
//! This module provides a complete ECS implementation specialized for
//! game entities like mobs, NPCs, projectiles, and other dynamic objects.
//!
//! ## Architecture
//!
//! The entity system is built on a sparse-set based ECS pattern:
//! - **Entities**: Unique identifiers with generation for safe references
//! - **Components**: Data-only structs attached to entities
//! - **Systems**: Functions that operate on entities with specific components
//!
//! ## Usage
//!
//! ```zig
//! const entity_mod = @import("entity/entity.zig");
//!
//! // Create entity world
//! var world = entity_mod.EntityWorld.init(allocator);
//! defer world.deinit();
//!
//! // Spawn a mob
//! const pig = try entity_mod.mobs.spawnPig(&world, position);
//!
//! // Update systems
//! entity_mod.systems.updateAllSystems(&world, player_pos, null, dt, &rng);
//! ```

const std = @import("std");

// Core ECS
pub const ecs = @import("ecs.zig");
pub const EntityWorld = ecs.EntityWorld;
pub const Entity = ecs.Entity;

// Components
pub const components = @import("components.zig");
pub const Transform = components.Transform;
pub const Velocity = components.Velocity;
pub const Health = components.Health;
pub const AI = components.AI;
pub const Render = components.Render;
pub const Collider = components.Collider;
pub const Mob = components.Mob;
pub const PhysicsBody = components.PhysicsBody;
pub const Inventory = components.Inventory;
pub const Name = components.Name;

// Component enums
pub const AIBehavior = components.AIBehavior;
pub const AIState = components.AIState;
pub const MobType = components.MobType;
pub const MeshType = components.MeshType;
pub const Color = components.Color;

// AI module
pub const ai = @import("ai.zig");

// Mob prefabs
pub const mobs = @import("mobs.zig");
pub const MobSpawnConfig = mobs.MobSpawnConfig;
pub const MobStats = mobs.MobStats;

// Systems
pub const systems = @import("systems.zig");
pub const RenderData = systems.RenderData;
pub const CollisionPair = systems.CollisionPair;

// Spawning
pub const spawning = @import("spawning.zig");
pub const MobSpawner = spawning.MobSpawner;
pub const SpawnConfig = spawning.SpawnConfig;
pub const SpawnEntry = spawning.SpawnEntry;

// Raycasting
pub const raycast = @import("raycast.zig");
pub const EntityRaycastHit = raycast.EntityRaycastHit;
pub const raycastEntities = raycast.raycastEntities;
pub const raycastDamageableEntities = raycast.raycastDamageableEntities;
pub const hasLineOfSight = raycast.hasLineOfSight;
pub const getEntitiesInSphere = raycast.getEntitiesInSphere;

// ============================================================================
// Convenience functions
// ============================================================================

/// Create a new entity world
pub fn createWorld(allocator: std.mem.Allocator) EntityWorld {
    return EntityWorld.init(allocator);
}

/// Spawn a mob at position
pub fn spawnMob(world: *EntityWorld, mob_type: MobType, position: @import("../math/math.zig").Vec3) !Entity {
    return mobs.createMob(world, .{
        .mob_type = mob_type,
        .position = position,
    });
}

// ============================================================================
// Tests
// ============================================================================

test {
    // Run all sub-module tests
    std.testing.refAllDecls(@This());
    _ = ecs;
    _ = components;
    _ = ai;
    _ = mobs;
    _ = systems;
    _ = spawning;
    _ = raycast;
}
