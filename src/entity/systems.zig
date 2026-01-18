//! Entity Systems
//!
//! Implements game systems that operate on entities with specific components.
//! Systems are the "S" in ECS - they contain the logic that operates on data.

const std = @import("std");
const math = @import("../math/math.zig");
const collision_mod = @import("../physics/collision.zig");
const ecs = @import("ecs.zig");
const ai_mod = @import("ai.zig");
const components = @import("components.zig");

const EntityWorld = ecs.EntityWorld;
const Entity = ecs.Entity;
const Transform = ecs.Transform;
const Velocity = ecs.Velocity;
const Health = ecs.Health;
const AI = ecs.AI;
const Render = ecs.Render;
const Collider = ecs.Collider;
const Mob = ecs.Mob;
const PhysicsBody = ecs.PhysicsBody;

const AABB = collision_mod.AABB;
const mobs = @import("mobs.zig");

/// Gravity constant (blocks per second squared)
pub const GRAVITY: f32 = 28.0;

/// Maximum number of death events per frame
pub const MAX_DEATH_EVENTS: usize = 16;

/// Death event for mob drops
pub const DeathEvent = struct {
    position: math.Vec3,
    mob_type: components.MobType,
    experience: u16,
};

/// Global death events buffer (cleared each frame after processing)
var g_death_events: [MAX_DEATH_EVENTS]DeathEvent = undefined;
var g_death_event_count: usize = 0;

/// Get pending death events (call from game loop to process drops)
pub fn getDeathEvents() []const DeathEvent {
    return g_death_events[0..g_death_event_count];
}

/// Clear death events (call after processing drops)
pub fn clearDeathEvents() void {
    g_death_event_count = 0;
}

/// Record a death event
fn recordDeathEvent(position: math.Vec3, mob_type: components.MobType, experience: u16) void {
    if (g_death_event_count >= MAX_DEATH_EVENTS) return;
    g_death_events[g_death_event_count] = .{
        .position = position,
        .mob_type = mob_type,
        .experience = experience,
    };
    g_death_event_count += 1;
}

/// Player damage event (mob attacks player)
pub const PlayerDamageEvent = struct {
    damage: f32,
    source_position: math.Vec3,
    source_type: components.MobType,
};

/// Global player damage events buffer
var g_player_damage_events: [8]PlayerDamageEvent = undefined;
var g_player_damage_event_count: usize = 0;

/// Get pending player damage events
pub fn getPlayerDamageEvents() []const PlayerDamageEvent {
    return g_player_damage_events[0..g_player_damage_event_count];
}

/// Clear player damage events
pub fn clearPlayerDamageEvents() void {
    g_player_damage_event_count = 0;
}

/// Record a player damage event
fn recordPlayerDamageEvent(damage: f32, source_position: math.Vec3, source_type: components.MobType) void {
    if (g_player_damage_event_count >= 8) return;
    g_player_damage_events[g_player_damage_event_count] = .{
        .damage = damage,
        .source_position = source_position,
        .source_type = source_type,
    };
    g_player_damage_event_count += 1;
}

/// Maximum fall speed
pub const TERMINAL_VELOCITY: f32 = 78.0;

// ============================================================================
// Movement System
// ============================================================================

/// Update entity positions based on velocity
pub fn movementSystem(world: *EntityWorld, delta_time: f32) void {
    const dt = delta_time;

    // Iterate over all entities with Transform and Velocity
    var iter = world.query(&[_]type{ Transform, Velocity });

    while (iter.next()) |result| {
        const transform = result.get(Transform) orelse continue;
        const velocity = result.get(Velocity) orelse continue;

        // Apply velocity to position
        transform.position = math.Vec3.add(
            transform.position,
            math.Vec3.scale(velocity.linear, dt),
        );

        // Apply angular velocity to rotation (simplified)
        if (math.Vec3.lengthSquared(velocity.angular) > 0.0001) {
            const angular_delta = math.Vec3.scale(velocity.angular, dt);
            transform.rotation = math.Quat.mul(
                transform.rotation,
                math.Quat.fromEuler(angular_delta.x(), angular_delta.y(), angular_delta.z()),
            );
        }
    }
}

// ============================================================================
// Physics System
// ============================================================================

/// Apply physics (gravity, drag) to entities
pub fn physicsSystem(world: *EntityWorld, delta_time: f32) void {
    const dt = delta_time;

    var iter = world.query(&[_]type{ Velocity, PhysicsBody });

    while (iter.next()) |result| {
        const velocity = result.get(Velocity) orelse continue;
        const physics = result.get(PhysicsBody) orelse continue;

        // Apply gravity if not grounded
        if (physics.use_gravity and !physics.grounded) {
            velocity.linear = math.Vec3.init(
                velocity.linear.x(),
                velocity.linear.y() - GRAVITY * physics.gravity_scale * dt,
                velocity.linear.z(),
            );

            // Clamp to terminal velocity
            if (velocity.linear.y() < -TERMINAL_VELOCITY) {
                velocity.linear = math.Vec3.init(
                    velocity.linear.x(),
                    -TERMINAL_VELOCITY,
                    velocity.linear.z(),
                );
            }
        }

        // Apply drag
        if (physics.drag > 0) {
            const drag_factor = 1.0 - physics.drag * dt;
            velocity.linear = math.Vec3.init(
                velocity.linear.x() * drag_factor,
                velocity.linear.y(), // Don't apply drag to vertical velocity
                velocity.linear.z() * drag_factor,
            );
        }
    }
}

// ============================================================================
// AI System
// ============================================================================

/// Update AI behavior for all AI-controlled entities
pub fn aiSystem(world: *EntityWorld, player_pos: math.Vec3, delta_time: f32, rng: *std.Random.DefaultPrng) void {
    var iter = world.query(&[_]type{ AI, Transform, Velocity, Health });

    while (iter.next()) |result| {
        const ai = result.get(AI) orelse continue;
        const transform = result.get(Transform) orelse continue;
        const velocity = result.get(Velocity) orelse continue;
        const health = result.get(Health) orelse continue;

        // Get mob type if available
        var mob_type = components.MobType.custom;
        if (world.getComponent(result.entity, Mob)) |mob| {
            mob_type = mob.mob_type;
        }

        ai_mod.updateAI(ai, transform, velocity, health, mob_type, player_pos, delta_time, rng);
    }
}

// ============================================================================
// Health System
// ============================================================================

/// Update health regeneration and invulnerability timers
pub fn healthSystem(world: *EntityWorld, delta_time: f32) void {
    var entities_to_remove = std.ArrayListUnmanaged(Entity){};
    defer entities_to_remove.deinit(world.allocator);

    var iter = world.query(&[_]type{Health});

    while (iter.next()) |result| {
        const health = result.get(Health) orelse continue;

        // Update invulnerability timer
        if (health.invuln_timer > 0) {
            health.invuln_timer = @max(0, health.invuln_timer - delta_time);
        }

        // Apply regeneration
        if (health.regen_rate > 0 and health.current < health.max and !health.isDead()) {
            health.heal(health.regen_rate * delta_time);
        }

        // Mark dead entities for removal and record death events
        if (health.isDead()) {
            // Check if this is a mob that should despawn
            if (world.getComponent(result.entity, Mob)) |mob| {
                if (mob.despawn_timer >= 0) {
                    // Record death event for drops before removing
                    if (world.getComponent(result.entity, Transform)) |transform| {
                        recordDeathEvent(transform.position, mob.mob_type, mob.experience);
                    }
                    entities_to_remove.append(world.allocator, result.entity) catch {};
                }
            }
        }
    }

    // Remove dead entities
    for (entities_to_remove.items) |entity| {
        world.despawn(entity);
    }
}

// ============================================================================
// Collision System
// ============================================================================

/// Collision pair for tracking collisions
pub const CollisionPair = struct {
    entity_a: Entity,
    entity_b: Entity,
    info: collision_mod.CollisionInfo,
};

/// Check collisions between all collidable entities
pub fn collisionSystem(world: *EntityWorld, allocator: std.mem.Allocator) !std.ArrayList(CollisionPair) {
    var collisions = std.ArrayList(CollisionPair).init(allocator);

    // Get all entities with colliders
    const collider_entities = world.getEntitiesWith(Collider);

    // O(n^2) broad phase - could be optimized with spatial partitioning
    for (collider_entities, 0..) |entity_a, i| {
        if (!world.isAlive(entity_a)) continue;

        const transform_a = world.getComponent(entity_a, Transform) orelse continue;
        const collider_a = world.getComponent(entity_a, Collider) orelse continue;
        const aabb_a = collider_a.getWorldAABB(transform_a.position);

        for (collider_entities[i + 1 ..]) |entity_b| {
            if (!world.isAlive(entity_b)) continue;

            const transform_b = world.getComponent(entity_b, Transform) orelse continue;
            const collider_b = world.getComponent(entity_b, Collider) orelse continue;

            // Check layer masks
            if ((collider_a.mask & (@as(u8, 1) << @intCast(collider_b.layer))) == 0) continue;
            if ((collider_b.mask & (@as(u8, 1) << @intCast(collider_a.layer))) == 0) continue;

            const aabb_b = collider_b.getWorldAABB(transform_b.position);

            // Check intersection
            if (collision_mod.resolveAABBCollision(aabb_a, aabb_b)) |info| {
                try collisions.append(.{
                    .entity_a = entity_a,
                    .entity_b = entity_b,
                    .info = info,
                });
            }
        }
    }

    return collisions;
}

/// Resolve collisions by separating entities
pub fn resolveCollisions(world: *EntityWorld, collisions: []const CollisionPair) void {
    for (collisions) |pair| {
        // Skip if either entity has a trigger collider
        const collider_a = world.getComponent(pair.entity_a, Collider);
        const collider_b = world.getComponent(pair.entity_b, Collider);

        if (collider_a) |c| if (c.is_trigger) continue;
        if (collider_b) |c| if (c.is_trigger) continue;

        // Get physics bodies to determine mass ratio
        const physics_a = world.getComponent(pair.entity_a, PhysicsBody);
        const physics_b = world.getComponent(pair.entity_b, PhysicsBody);

        const mass_a = if (physics_a) |p| p.mass else 1.0;
        const mass_b = if (physics_b) |p| p.mass else 1.0;
        const total_mass = mass_a + mass_b;

        // Separate entities based on mass ratio
        if (world.getComponent(pair.entity_a, Transform)) |transform_a| {
            const ratio_a = mass_b / total_mass;
            const separation = math.Vec3.scale(pair.info.normal, pair.info.depth * ratio_a);
            transform_a.position = math.Vec3.sub(transform_a.position, separation);
        }

        if (world.getComponent(pair.entity_b, Transform)) |transform_b| {
            const ratio_b = mass_a / total_mass;
            const separation = math.Vec3.scale(pair.info.normal, pair.info.depth * ratio_b);
            transform_b.position = math.Vec3.add(transform_b.position, separation);
        }
    }
}

// ============================================================================
// Mob System
// ============================================================================

/// Update mob-specific logic (age, despawn timers)
pub fn mobSystem(world: *EntityWorld, delta_time: f32) void {
    var entities_to_despawn = std.ArrayListUnmanaged(Entity){};
    defer entities_to_despawn.deinit(world.allocator);

    var iter = world.query(&[_]type{Mob});

    while (iter.next()) |result| {
        const mob = result.get(Mob) orelse continue;

        // Update age
        mob.age += delta_time;

        // Check despawn timer
        if (mob.despawn_timer >= 0) {
            mob.despawn_timer -= delta_time;
            if (mob.despawn_timer <= 0) {
                entities_to_despawn.append(world.allocator, result.entity) catch {};
            }
        }
    }

    // Despawn timed-out entities
    for (entities_to_despawn.items) |entity| {
        world.despawn(entity);
    }
}

// ============================================================================
// Damage System
// ============================================================================

/// Apply damage to an entity
pub fn damageEntity(world: *EntityWorld, entity: Entity, amount: f32, attacker_pos: ?math.Vec3) bool {
    const health = world.getComponent(entity, Health) orelse return false;

    const killed = health.damage(amount);

    // Trigger flee for passive mobs
    if (world.getComponent(entity, AI)) |ai| {
        if (attacker_pos) |pos| {
            ai_mod.triggerFlee(ai, pos);
        }
    }

    // Apply knockback
    if (attacker_pos) |pos| {
        if (world.getComponent(entity, Transform)) |transform| {
            if (world.getComponent(entity, Velocity)) |velocity| {
                const knockback_dir = math.Vec3.normalize(
                    math.Vec3.sub(transform.position, pos),
                );
                const knockback_strength: f32 = 8.0;
                velocity.linear = math.Vec3.add(
                    velocity.linear,
                    math.Vec3.init(
                        knockback_dir.x() * knockback_strength,
                        4.0, // Upward knockback
                        knockback_dir.z() * knockback_strength,
                    ),
                );
            }
        }
    }

    // Set invulnerability frames
    health.invuln_timer = 0.5;

    return killed;
}

// ============================================================================
// Attack System
// ============================================================================

/// Process attacks from AI entities
pub fn attackSystem(world: *EntityWorld, player_entity: ?Entity, player_pos: math.Vec3) void {
    var iter = world.query(&[_]type{ AI, Transform, Mob });

    while (iter.next()) |result| {
        const ai = result.get(AI) orelse continue;
        const transform = result.get(Transform) orelse continue;
        const mob = result.get(Mob) orelse continue;

        // Only process if in attacking state and can attack
        if (ai.state != .attacking or !ai.canAttack()) continue;

        // Calculate distance to player
        const dist = math.Vec3.distance(transform.position, player_pos);

        if (dist <= ai.attack_range) {
            // Deal damage to player
            if (player_entity) |player| {
                _ = damageEntity(world, player, ai.attack_damage, transform.position);
            } else {
                // Player not an entity - record damage event for game to process
                recordPlayerDamageEvent(ai.attack_damage, transform.position, mob.mob_type);
            }
            ai.resetAttackCooldown();
        }
    }
}

// ============================================================================
// Render System (Data preparation)
// ============================================================================

/// Render data for a single entity
pub const RenderData = struct {
    entity: Entity,
    position: math.Vec3,
    rotation: math.Quat,
    scale: math.Vec3,
    color: [4]f32,
    mesh_type: components.MeshType,
};

/// Collect render data for all visible entities
pub fn collectRenderData(world: *EntityWorld, allocator: std.mem.Allocator) !std.ArrayListUnmanaged(RenderData) {
    var render_list = std.ArrayListUnmanaged(RenderData){};

    var iter = world.query(&[_]type{ Transform, Render });

    while (iter.next()) |result| {
        const transform = result.get(Transform) orelse continue;
        const render = result.get(Render) orelse continue;

        if (!render.visible) continue;

        try render_list.append(allocator, .{
            .entity = result.entity,
            .position = transform.position,
            .rotation = transform.rotation,
            .scale = math.Vec3.mul(transform.scale, render.scale),
            .color = render.color.toFloat(),
            .mesh_type = render.mesh_type,
        });
    }

    return render_list;
}

// ============================================================================
// Update All Systems
// ============================================================================

/// Run all entity systems in order
pub fn updateAllSystems(
    world: *EntityWorld,
    player_pos: math.Vec3,
    player_entity: ?Entity,
    delta_time: f32,
    rng: *std.Random.DefaultPrng,
) void {
    // Update order matters!
    aiSystem(world, player_pos, delta_time, rng);
    physicsSystem(world, delta_time);
    movementSystem(world, delta_time);
    healthSystem(world, delta_time);
    mobSystem(world, delta_time);
    attackSystem(world, player_entity, player_pos);

    // Collision system returns allocations, handle separately if needed
}

// ============================================================================
// World Collision System
// ============================================================================

/// Block type for collision checking (imported from game world)
const world_mod = @import("../game/world.zig");
const Block = world_mod.Block;
const BlockWorld = world_mod.BlockWorld;

/// Resolve entity collisions with the block world.
/// This should be called after movement system.
pub fn worldCollisionSystem(
    entity_world: *EntityWorld,
    block_world: *BlockWorld,
) void {
    var iter = entity_world.query(&[_]type{ Transform, Velocity, Collider });

    while (iter.next()) |result| {
        const transform = result.get(Transform) orelse continue;
        const velocity = result.get(Velocity) orelse continue;
        const collider = result.get(Collider) orelse continue;

        // Get physics body if available for grounded state
        const physics = entity_world.getComponent(result.entity, PhysicsBody);

        const half_size = collider.half_extents;
        const pos = transform.position;

        // Check Y axis (vertical) collision first
        if (velocity.linear.y() < 0) {
            // Moving down - check ground
            const feet_y = pos.y() - half_size.y();
            const block_y: i32 = @intFromFloat(@floor(feet_y));
            const center_x: i32 = @intFromFloat(@floor(pos.x()));
            const center_z: i32 = @intFromFloat(@floor(pos.z()));

            // Check blocks beneath feet
            var grounded = false;
            var check_x = center_x - 1;
            while (check_x <= center_x + 1) : (check_x += 1) {
                var check_z = center_z - 1;
                while (check_z <= center_z + 1) : (check_z += 1) {
                    const block = block_world.getBlock(check_x, block_y, check_z);
                    if (block.isSolid()) {
                        // Check if entity overlaps this block horizontally
                        const block_min_x: f32 = @floatFromInt(check_x);
                        const block_max_x: f32 = block_min_x + 1.0;
                        const block_min_z: f32 = @floatFromInt(check_z);
                        const block_max_z: f32 = block_min_z + 1.0;

                        if (pos.x() + half_size.x() > block_min_x and
                            pos.x() - half_size.x() < block_max_x and
                            pos.z() + half_size.z() > block_min_z and
                            pos.z() - half_size.z() < block_max_z)
                        {
                            grounded = true;
                            // Snap to top of block
                            const block_top: f32 = @floatFromInt(block_y + 1);
                            transform.position = math.Vec3.init(
                                pos.x(),
                                block_top + half_size.y(),
                                pos.z(),
                            );
                            velocity.linear = math.Vec3.init(velocity.linear.x(), 0, velocity.linear.z());
                            break;
                        }
                    }
                }
                if (grounded) break;
            }

            if (physics) |p| {
                p.grounded = grounded;
            }
        } else if (velocity.linear.y() > 0) {
            // Moving up - check ceiling
            const head_y = pos.y() + half_size.y();
            const block_y: i32 = @intFromFloat(@floor(head_y));
            const center_x: i32 = @intFromFloat(@floor(pos.x()));
            const center_z: i32 = @intFromFloat(@floor(pos.z()));

            const block = block_world.getBlock(center_x, block_y, center_z);
            if (block.isSolid()) {
                // Hit ceiling - stop upward movement
                const block_bottom: f32 = @floatFromInt(block_y);
                transform.position = math.Vec3.init(
                    pos.x(),
                    block_bottom - half_size.y() - 0.01,
                    pos.z(),
                );
                velocity.linear = math.Vec3.init(velocity.linear.x(), 0, velocity.linear.z());
            }
        }

        // Check X axis collision
        if (@abs(velocity.linear.x()) > 0.001) {
            const new_pos = transform.position;
            const check_x: i32 = if (velocity.linear.x() > 0)
                @intFromFloat(@floor(new_pos.x() + half_size.x()))
            else
                @intFromFloat(@floor(new_pos.x() - half_size.x()));

            const min_y_check: i32 = @intFromFloat(@floor(new_pos.y() - half_size.y() + 0.1));
            const max_y_check: i32 = @intFromFloat(@floor(new_pos.y() + half_size.y() - 0.1));
            const center_z_i: i32 = @intFromFloat(@floor(new_pos.z()));

            var y_check = min_y_check;
            while (y_check <= max_y_check) : (y_check += 1) {
                const block = block_world.getBlock(check_x, y_check, center_z_i);
                if (block.isSolid()) {
                    // Blocked - stop X movement
                    velocity.linear = math.Vec3.init(0, velocity.linear.y(), velocity.linear.z());
                    break;
                }
            }
        }

        // Check Z axis collision
        if (@abs(velocity.linear.z()) > 0.001) {
            const new_pos = transform.position;
            const check_z: i32 = if (velocity.linear.z() > 0)
                @intFromFloat(@floor(new_pos.z() + half_size.z()))
            else
                @intFromFloat(@floor(new_pos.z() - half_size.z()));

            const min_y_check: i32 = @intFromFloat(@floor(new_pos.y() - half_size.y() + 0.1));
            const max_y_check: i32 = @intFromFloat(@floor(new_pos.y() + half_size.y() - 0.1));
            const center_x_i: i32 = @intFromFloat(@floor(new_pos.x()));

            var y_check = min_y_check;
            while (y_check <= max_y_check) : (y_check += 1) {
                const block = block_world.getBlock(center_x_i, y_check, check_z);
                if (block.isSolid()) {
                    // Blocked - stop Z movement
                    velocity.linear = math.Vec3.init(velocity.linear.x(), velocity.linear.y(), 0);
                    break;
                }
            }
        }
    }
}

// ============================================================================
// Tests
// ============================================================================

test "movement system" {
    const allocator = std.testing.allocator;
    var world = EntityWorld.init(allocator);
    defer world.deinit();

    const entity = try world.spawn();
    try world.addComponent(entity, Transform, .{
        .position = math.Vec3.init(0, 0, 0),
    });
    try world.addComponent(entity, Velocity, .{
        .linear = math.Vec3.init(10, 0, 0),
    });

    movementSystem(&world, 1.0);

    const transform = world.getComponent(entity, Transform);
    try std.testing.expect(transform != null);
    try std.testing.expectApproxEqAbs(@as(f32, 10), transform.?.position.x(), 0.001);
}

test "physics system gravity" {
    const allocator = std.testing.allocator;
    var world = EntityWorld.init(allocator);
    defer world.deinit();

    const entity = try world.spawn();
    try world.addComponent(entity, Velocity, .{
        .linear = math.Vec3.ZERO,
    });
    try world.addComponent(entity, PhysicsBody, .{
        .use_gravity = true,
        .grounded = false,
    });

    physicsSystem(&world, 1.0);

    const velocity = world.getComponent(entity, Velocity);
    try std.testing.expect(velocity != null);
    try std.testing.expect(velocity.?.linear.y() < 0); // Should fall
}

test "health system regeneration" {
    const allocator = std.testing.allocator;
    var world = EntityWorld.init(allocator);
    defer world.deinit();

    const entity = try world.spawn();
    var health = Health.init(100);
    health.current = 50;
    health.regen_rate = 10;
    try world.addComponent(entity, Health, health);

    healthSystem(&world, 1.0);

    const updated_health = world.getComponent(entity, Health);
    try std.testing.expect(updated_health != null);
    try std.testing.expectApproxEqAbs(@as(f32, 60), updated_health.?.current, 0.001);
}

test "damage entity" {
    const allocator = std.testing.allocator;
    var world = EntityWorld.init(allocator);
    defer world.deinit();

    const entity = try world.spawn();
    try world.addComponent(entity, Health, Health.init(100));
    try world.addComponent(entity, Transform, .{});
    try world.addComponent(entity, Velocity, .{});

    const killed = damageEntity(&world, entity, 30, null);
    try std.testing.expect(!killed);

    const health = world.getComponent(entity, Health);
    try std.testing.expectApproxEqAbs(@as(f32, 70), health.?.current, 0.001);
}
