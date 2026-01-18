//! Mob Prefabs and Factory
//!
//! Defines mob types and provides factory functions to create
//! fully configured mob entities with all required components.

const std = @import("std");
const math = @import("../math/math.zig");
const components = @import("components.zig");
const ai_mod = @import("ai.zig");
const ecs = @import("ecs.zig");

const Transform = components.Transform;
const Velocity = components.Velocity;
const Health = components.Health;
const AI = components.AI;
const Render = components.Render;
const Collider = components.Collider;
const Mob = components.Mob;
const PhysicsBody = components.PhysicsBody;
const MobType = components.MobType;
const Color = components.Color;
const AIBehavior = components.AIBehavior;

/// Mob spawn configuration
pub const MobSpawnConfig = struct {
    mob_type: MobType,
    position: math.Vec3,
    /// Optional override for AI behavior
    behavior_override: ?AIBehavior = null,
    /// Whether this is a baby mob
    is_baby: bool = false,
};

/// Create a mob entity with all components
pub fn createMob(world: *ecs.EntityWorld, config: MobSpawnConfig) !ecs.Entity {
    const entity = try world.spawn();

    // Get mob stats
    const stats = getMobStats(config.mob_type);

    // Transform
    try world.addComponent(entity, Transform, .{
        .position = config.position,
        .scale = if (config.is_baby) math.Vec3.scale(stats.scale, 0.5) else stats.scale,
    });

    // Velocity
    try world.addComponent(entity, Velocity, .{});

    // Health
    var health = Health.init(stats.max_health);
    if (config.is_baby) {
        health.max = stats.max_health * 0.5;
        health.current = health.max;
    }
    try world.addComponent(entity, Health, health);

    // AI
    var ai_stats = ai_mod.getDefaultAIStats(config.mob_type);
    ai_stats.home_position = config.position;
    if (config.behavior_override) |behavior| {
        ai_stats.behavior = behavior;
    }
    try world.addComponent(entity, AI, ai_stats);

    // Render
    try world.addComponent(entity, Render, .{
        .mesh_type = .cube,
        .color = stats.color,
        .scale = if (config.is_baby) math.Vec3.scale(stats.render_scale, 0.5) else stats.render_scale,
    });

    // Collider
    var collider = stats.collider;
    if (config.is_baby) {
        collider.half_extents = math.Vec3.scale(collider.half_extents, 0.5);
    }
    try world.addComponent(entity, Collider, collider);

    // Mob tag
    try world.addComponent(entity, Mob, .{
        .mob_type = config.mob_type,
        .is_baby = config.is_baby,
        .experience = stats.experience,
    });

    // Physics body
    try world.addComponent(entity, PhysicsBody, .{
        .move_speed = stats.move_speed,
        .jump_velocity = stats.jump_velocity,
    });

    return entity;
}

/// Mob statistics and visual properties
pub const MobStats = struct {
    max_health: f32,
    move_speed: f32,
    jump_velocity: f32,
    color: Color,
    scale: math.Vec3,
    render_scale: math.Vec3,
    collider: Collider,
    experience: u16,
};

/// Get default stats for a mob type
pub fn getMobStats(mob_type: MobType) MobStats {
    return switch (mob_type) {
        .pig => .{
            .max_health = 10,
            .move_speed = 3.0,
            .jump_velocity = 6.0,
            .color = Color.PINK,
            .scale = math.Vec3.ONE,
            .render_scale = math.Vec3.init(0.9, 0.9, 1.2),
            .collider = Collider.box(0.45, 0.45, 0.6),
            .experience = 3,
        },
        .cow => .{
            .max_health = 10,
            .move_speed = 2.5,
            .jump_velocity = 5.0,
            .color = Color.BROWN,
            .scale = math.Vec3.ONE,
            .render_scale = math.Vec3.init(0.9, 1.4, 1.5),
            .collider = Collider.box(0.45, 0.7, 0.75),
            .experience = 3,
        },
        .chicken => .{
            .max_health = 4,
            .move_speed = 4.0,
            .jump_velocity = 7.0,
            .color = Color.WHITE,
            .scale = math.Vec3.ONE,
            .render_scale = math.Vec3.init(0.4, 0.7, 0.5),
            .collider = Collider.box(0.2, 0.35, 0.25),
            .experience = 3,
        },
        .sheep => .{
            .max_health = 8,
            .move_speed = 2.8,
            .jump_velocity = 5.5,
            .color = Color.LIGHT_GRAY,
            .scale = math.Vec3.ONE,
            .render_scale = math.Vec3.init(0.9, 1.0, 1.3),
            .collider = Collider.box(0.45, 0.5, 0.65),
            .experience = 3,
        },
        .zombie => .{
            .max_health = 20,
            .move_speed = 2.5,
            .jump_velocity = 6.0,
            .color = Color.DARK_GREEN,
            .scale = math.Vec3.ONE,
            .render_scale = math.Vec3.init(0.6, 1.8, 0.4),
            .collider = Collider.box(0.3, 0.9, 0.2),
            .experience = 5,
        },
        .skeleton => .{
            .max_health = 20,
            .move_speed = 3.0,
            .jump_velocity = 6.0,
            .color = Color.LIGHT_GRAY,
            .scale = math.Vec3.ONE,
            .render_scale = math.Vec3.init(0.5, 1.8, 0.3),
            .collider = Collider.box(0.25, 0.9, 0.15),
            .experience = 5,
        },
        .creeper => .{
            .max_health = 20,
            .move_speed = 3.5,
            .jump_velocity = 6.0,
            .color = Color.GREEN,
            .scale = math.Vec3.ONE,
            .render_scale = math.Vec3.init(0.6, 1.7, 0.6),
            .collider = Collider.box(0.3, 0.85, 0.3),
            .experience = 5,
        },
        .spider => .{
            .max_health = 16,
            .move_speed = 4.5,
            .jump_velocity = 8.0,
            .color = Color.fromRgb(50, 50, 50),
            .scale = math.Vec3.ONE,
            .render_scale = math.Vec3.init(1.4, 0.6, 0.9),
            .collider = Collider.box(0.7, 0.3, 0.45),
            .experience = 5,
        },
        .villager => .{
            .max_health = 20,
            .move_speed = 2.0,
            .jump_velocity = 5.0,
            .color = Color.BROWN,
            .scale = math.Vec3.ONE,
            .render_scale = math.Vec3.init(0.6, 1.9, 0.4),
            .collider = Collider.box(0.3, 0.95, 0.2),
            .experience = 0,
        },
        .player => .{
            .max_health = 20,
            .move_speed = 4.3,
            .jump_velocity = 8.0,
            .color = Color.WHITE,
            .scale = math.Vec3.ONE,
            .render_scale = math.Vec3.init(0.6, 1.8, 0.4),
            .collider = Collider.box(0.3, 0.9, 0.2),
            .experience = 0,
        },
        .custom => .{
            .max_health = 10,
            .move_speed = 3.0,
            .jump_velocity = 6.0,
            .color = Color.GRAY,
            .scale = math.Vec3.ONE,
            .render_scale = math.Vec3.ONE,
            .collider = Collider.cube(0.5),
            .experience = 0,
        },
    };
}

// ============================================================================
// Convenience spawners for specific mob types
// ============================================================================

/// Spawn a pig at position
pub fn spawnPig(world: *ecs.EntityWorld, position: math.Vec3) !ecs.Entity {
    return createMob(world, .{
        .mob_type = .pig,
        .position = position,
    });
}

/// Spawn a cow at position
pub fn spawnCow(world: *ecs.EntityWorld, position: math.Vec3) !ecs.Entity {
    return createMob(world, .{
        .mob_type = .cow,
        .position = position,
    });
}

/// Spawn a chicken at position
pub fn spawnChicken(world: *ecs.EntityWorld, position: math.Vec3) !ecs.Entity {
    return createMob(world, .{
        .mob_type = .chicken,
        .position = position,
    });
}

/// Spawn a sheep at position
pub fn spawnSheep(world: *ecs.EntityWorld, position: math.Vec3) !ecs.Entity {
    return createMob(world, .{
        .mob_type = .sheep,
        .position = position,
    });
}

/// Spawn a zombie at position
pub fn spawnZombie(world: *ecs.EntityWorld, position: math.Vec3) !ecs.Entity {
    return createMob(world, .{
        .mob_type = .zombie,
        .position = position,
    });
}

/// Spawn a skeleton at position
pub fn spawnSkeleton(world: *ecs.EntityWorld, position: math.Vec3) !ecs.Entity {
    return createMob(world, .{
        .mob_type = .skeleton,
        .position = position,
    });
}

/// Spawn a creeper at position
pub fn spawnCreeper(world: *ecs.EntityWorld, position: math.Vec3) !ecs.Entity {
    return createMob(world, .{
        .mob_type = .creeper,
        .position = position,
    });
}

/// Spawn a spider at position
pub fn spawnSpider(world: *ecs.EntityWorld, position: math.Vec3) !ecs.Entity {
    return createMob(world, .{
        .mob_type = .spider,
        .position = position,
    });
}

/// Spawn a villager at position
pub fn spawnVillager(world: *ecs.EntityWorld, position: math.Vec3) !ecs.Entity {
    return createMob(world, .{
        .mob_type = .villager,
        .position = position,
    });
}

// ============================================================================
// Drop Tables
// ============================================================================

/// A single drop entry
pub const DropEntry = struct {
    item_id: u16,
    min_count: u8,
    max_count: u8,
    chance: f32, // 0.0 to 1.0
};

/// Get drops for a mob type
/// Returns slice of possible drops. Use RNG to determine actual drops.
pub fn getMobDrops(mob_type: MobType) []const DropEntry {
    return switch (mob_type) {
        .pig => &[_]DropEntry{
            .{ .item_id = 403, .min_count = 1, .max_count = 3, .chance = 1.0 }, // Raw Pork
        },
        .cow => &[_]DropEntry{
            .{ .item_id = 405, .min_count = 1, .max_count = 3, .chance = 1.0 }, // Raw Beef
            .{ .item_id = 306, .min_count = 0, .max_count = 2, .chance = 1.0 }, // Leather
        },
        .chicken => &[_]DropEntry{
            .{ .item_id = 407, .min_count = 1, .max_count = 1, .chance = 1.0 }, // Raw Chicken
            .{ .item_id = 307, .min_count = 0, .max_count = 2, .chance = 1.0 }, // Feather
        },
        .sheep => &[_]DropEntry{
            .{ .item_id = 21, .min_count = 1, .max_count = 1, .chance = 1.0 }, // Wool block
        },
        .zombie => &[_]DropEntry{
            .{ .item_id = 405, .min_count = 0, .max_count = 2, .chance = 0.5 }, // Rotten Flesh (use beef for now)
        },
        .skeleton => &[_]DropEntry{
            .{ .item_id = 300, .min_count = 0, .max_count = 2, .chance = 0.8 }, // Bones (use sticks for now)
        },
        .creeper => &[_]DropEntry{
            .{ .item_id = 301, .min_count = 0, .max_count = 2, .chance = 0.6 }, // Gunpowder (use coal for now)
        },
        .spider => &[_]DropEntry{
            .{ .item_id = 305, .min_count = 0, .max_count = 2, .chance = 0.75 }, // String
        },
        .villager, .player, .custom => &[_]DropEntry{},
    };
}

/// Drop result from rolling
pub const DropResult = struct {
    item_id: u16,
    count: u8,
};

/// Calculate actual drops for a mob (call when mob dies)
/// Returns array of drops
pub fn rollDrops(mob_type: MobType, rng: *std.Random.DefaultPrng) [8]DropResult {
    var result: [8]DropResult = [_]DropResult{.{ .item_id = 0, .count = 0 }} ** 8;
    var result_idx: usize = 0;

    const drops = getMobDrops(mob_type);
    for (drops) |drop| {
        if (result_idx >= 8) break;

        // Roll for drop chance
        if (rng.random().float(f32) > drop.chance) continue;

        // Roll for count
        const range = drop.max_count - drop.min_count;
        const count = if (range > 0)
            drop.min_count + rng.random().uintLessThan(u8, range + 1)
        else
            drop.min_count;

        if (count > 0) {
            result[result_idx] = .{ .item_id = drop.item_id, .count = count };
            result_idx += 1;
        }
    }

    return result;
}

// ============================================================================
// Tests
// ============================================================================

test "mob drops" {
    const pig_drops = getMobDrops(.pig);
    try std.testing.expect(pig_drops.len > 0);
    try std.testing.expectEqual(@as(u16, 403), pig_drops[0].item_id); // Raw Pork
}

test "mob stats lookup" {
    const pig_stats = getMobStats(.pig);
    try std.testing.expectApproxEqAbs(@as(f32, 10), pig_stats.max_health, 0.001);
    try std.testing.expectEqual(Color.PINK.r, pig_stats.color.r);

    const zombie_stats = getMobStats(.zombie);
    try std.testing.expectApproxEqAbs(@as(f32, 20), zombie_stats.max_health, 0.001);
}
