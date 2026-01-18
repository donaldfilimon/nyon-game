//! AI Behavior System
//!
//! Implements AI behaviors for mobs and NPCs including pathfinding,
//! target selection, and state machine logic.

const std = @import("std");
const math = @import("../math/math.zig");
const components = @import("components.zig");

const AIBehavior = components.AIBehavior;
const AIState = components.AIState;
const AI = components.AI;
const Transform = components.Transform;
const Velocity = components.Velocity;
const Health = components.Health;
const MobType = components.MobType;

/// Constants for AI behavior tuning
pub const AI_CONSTANTS = struct {
    /// Minimum distance to consider "arrived" at destination
    pub const ARRIVAL_THRESHOLD: f32 = 0.5;
    /// How often to pick new wander target (seconds)
    pub const WANDER_INTERVAL: f32 = 3.0;
    /// Maximum time to stay in idle state
    pub const MAX_IDLE_TIME: f32 = 5.0;
    /// Distance to keep from fleeing target
    pub const FLEE_DISTANCE: f32 = 16.0;
    /// How close skeleton tries to stay (ranged attacker)
    pub const RANGED_ATTACK_DISTANCE: f32 = 8.0;
    /// Creeper explosion range
    pub const CREEPER_EXPLOSION_RANGE: f32 = 3.0;
    /// Creeper fuse time
    pub const CREEPER_FUSE_TIME: f32 = 1.5;
};

/// Update AI state and behavior for an entity
pub fn updateAI(
    ai: *AI,
    transform: *Transform,
    velocity: *Velocity,
    health: *const Health,
    mob_type: MobType,
    player_pos: math.Vec3,
    delta_time: f32,
    rng: *std.Random.DefaultPrng,
) void {
    // Update timers
    ai.attack_timer = @max(0, ai.attack_timer - delta_time);
    ai.state_timer += delta_time;

    // Check if dead
    if (health.isDead()) {
        ai.state = .dead;
        velocity.linear = math.Vec3.ZERO;
        return;
    }

    // Calculate distance to player
    const to_player = math.Vec3.sub(player_pos, transform.position);
    const dist_to_player = math.Vec3.length(to_player);

    // Behavior-specific updates
    switch (ai.behavior) {
        .idle => updateIdleBehavior(ai, velocity),
        .wander => updateWanderBehavior(ai, transform, velocity, rng, delta_time),
        .follow => updateFollowBehavior(ai, transform, velocity, player_pos, dist_to_player),
        .flee => updateFleeBehavior(ai, transform, velocity, player_pos, dist_to_player),
        .hostile => updateHostileBehavior(ai, transform, velocity, player_pos, dist_to_player, mob_type),
        .passive => updatePassiveBehavior(ai, transform, velocity, player_pos, dist_to_player, rng, delta_time),
        .patrol => updatePatrolBehavior(ai, transform, velocity),
    }
}

/// Idle behavior - just stand still
fn updateIdleBehavior(ai: *AI, velocity: *Velocity) void {
    ai.state = .idle;
    velocity.linear = math.Vec3.ZERO;
}

/// Wander behavior - random movement within radius
fn updateWanderBehavior(
    ai: *AI,
    transform: *Transform,
    velocity: *Velocity,
    rng: *std.Random.DefaultPrng,
    delta_time: f32,
) void {
    // Check if we need a new target
    if (!ai.has_move_target or ai.state_timer > AI_CONSTANTS.WANDER_INTERVAL) {
        pickWanderTarget(ai, transform.position, rng);
        ai.state_timer = 0;
    }

    // Move toward target
    if (ai.has_move_target) {
        const to_target = math.Vec3.sub(ai.move_target, transform.position);
        const dist = math.Vec3.length(to_target);

        if (dist < AI_CONSTANTS.ARRIVAL_THRESHOLD) {
            // Arrived, go idle briefly
            ai.state = .idle;
            ai.has_move_target = false;
            velocity.linear = math.Vec3.ZERO;
        } else {
            // Move toward target
            ai.state = .moving;
            const dir = math.Vec3.normalize(to_target);
            const speed = ai.speed * 2.0; // Base wander speed
            velocity.linear = math.Vec3.init(
                dir.x() * speed,
                velocity.linear.y(), // Preserve vertical velocity
                dir.z() * speed,
            );
        }
    }
    _ = delta_time;
}

/// Follow behavior - move toward target
fn updateFollowBehavior(
    ai: *AI,
    transform: *Transform,
    velocity: *Velocity,
    target_pos: math.Vec3,
    dist_to_target: f32,
) void {
    if (dist_to_target > 2.0) {
        ai.state = .moving;
        const to_target = math.Vec3.sub(target_pos, transform.position);
        const dir = math.Vec3.normalize(to_target);
        const speed = ai.speed * 3.0;
        velocity.linear = math.Vec3.init(
            dir.x() * speed,
            velocity.linear.y(),
            dir.z() * speed,
        );
    } else {
        ai.state = .idle;
        velocity.linear = math.Vec3.init(0, velocity.linear.y(), 0);
    }
}

/// Flee behavior - run away from target
fn updateFleeBehavior(
    ai: *AI,
    transform: *Transform,
    velocity: *Velocity,
    threat_pos: math.Vec3,
    dist_to_threat: f32,
) void {
    if (dist_to_threat < AI_CONSTANTS.FLEE_DISTANCE) {
        ai.state = .fleeing;
        const away_from_threat = math.Vec3.sub(transform.position, threat_pos);
        const dir = math.Vec3.normalize(away_from_threat);
        const speed = ai.speed * 4.0; // Flee faster
        velocity.linear = math.Vec3.init(
            dir.x() * speed,
            velocity.linear.y(),
            dir.z() * speed,
        );
    } else {
        ai.state = .idle;
        velocity.linear = math.Vec3.init(0, velocity.linear.y(), 0);
    }
}

/// Hostile behavior - attack player
fn updateHostileBehavior(
    ai: *AI,
    transform: *Transform,
    velocity: *Velocity,
    player_pos: math.Vec3,
    dist_to_player: f32,
    mob_type: MobType,
) void {
    // Check if player is in detection range
    if (dist_to_player > ai.detection_range) {
        ai.state = .idle;
        velocity.linear = math.Vec3.init(0, velocity.linear.y(), 0);
        return;
    }

    // Mob-specific behavior
    switch (mob_type) {
        .skeleton => {
            // Ranged: keep distance
            if (dist_to_player < AI_CONSTANTS.RANGED_ATTACK_DISTANCE) {
                // Back away
                ai.state = .moving;
                const away = math.Vec3.sub(transform.position, player_pos);
                const dir = math.Vec3.normalize(away);
                velocity.linear = math.Vec3.init(
                    dir.x() * ai.speed * 2.0,
                    velocity.linear.y(),
                    dir.z() * ai.speed * 2.0,
                );
            } else if (dist_to_player > AI_CONSTANTS.RANGED_ATTACK_DISTANCE + 2.0) {
                // Close the gap
                ai.state = .moving;
                const toward = math.Vec3.sub(player_pos, transform.position);
                const dir = math.Vec3.normalize(toward);
                velocity.linear = math.Vec3.init(
                    dir.x() * ai.speed * 2.0,
                    velocity.linear.y(),
                    dir.z() * ai.speed * 2.0,
                );
            } else {
                // Attack from range
                ai.state = .attacking;
                velocity.linear = math.Vec3.init(0, velocity.linear.y(), 0);
            }
        },
        .creeper => {
            // Run toward player and explode
            if (dist_to_player < AI_CONSTANTS.CREEPER_EXPLOSION_RANGE) {
                ai.state = .attacking;
                velocity.linear = math.Vec3.init(0, velocity.linear.y(), 0);
                // Explosion handled in systems.zig
            } else {
                ai.state = .moving;
                const toward = math.Vec3.sub(player_pos, transform.position);
                const dir = math.Vec3.normalize(toward);
                velocity.linear = math.Vec3.init(
                    dir.x() * ai.speed * 2.5,
                    velocity.linear.y(),
                    dir.z() * ai.speed * 2.5,
                );
            }
        },
        else => {
            // Default melee: run toward and attack
            if (dist_to_player <= ai.attack_range) {
                ai.state = .attacking;
                velocity.linear = math.Vec3.init(0, velocity.linear.y(), 0);
            } else {
                ai.state = .moving;
                const toward = math.Vec3.sub(player_pos, transform.position);
                const dir = math.Vec3.normalize(toward);
                velocity.linear = math.Vec3.init(
                    dir.x() * ai.speed * 3.0,
                    velocity.linear.y(),
                    dir.z() * ai.speed * 3.0,
                );
            }
        },
    }
}

/// Passive behavior - wander, flee when attacked
fn updatePassiveBehavior(
    ai: *AI,
    transform: *Transform,
    velocity: *Velocity,
    player_pos: math.Vec3,
    dist_to_player: f32,
    rng: *std.Random.DefaultPrng,
    delta_time: f32,
) void {
    // If player is very close and we're not already fleeing, consider fleeing
    if (dist_to_player < 2.0 and ai.state != .fleeing) {
        ai.state = .fleeing;
        ai.state_timer = 0;
    }

    if (ai.state == .fleeing) {
        updateFleeBehavior(ai, transform, velocity, player_pos, dist_to_player);
        // Stop fleeing after a bit
        if (ai.state_timer > 3.0 or dist_to_player > AI_CONSTANTS.FLEE_DISTANCE) {
            ai.state = .idle;
            ai.state_timer = 0;
        }
    } else {
        // Just wander around
        updateWanderBehavior(ai, transform, velocity, rng, delta_time);
    }
}

/// Patrol behavior - move between waypoints
fn updatePatrolBehavior(
    ai: *AI,
    transform: *Transform,
    velocity: *Velocity,
) void {
    // Simplified: patrol around home position
    if (!ai.has_move_target) {
        // Set move target to home
        ai.move_target = ai.home_position;
        ai.has_move_target = true;
    }

    const to_target = math.Vec3.sub(ai.move_target, transform.position);
    const dist = math.Vec3.length(to_target);

    if (dist < AI_CONSTANTS.ARRIVAL_THRESHOLD) {
        ai.state = .idle;
        velocity.linear = math.Vec3.init(0, velocity.linear.y(), 0);
    } else {
        ai.state = .moving;
        const dir = math.Vec3.normalize(to_target);
        velocity.linear = math.Vec3.init(
            dir.x() * ai.speed * 2.0,
            velocity.linear.y(),
            dir.z() * ai.speed * 2.0,
        );
    }
}

/// Pick a random wander target within radius
fn pickWanderTarget(ai: *AI, current_pos: math.Vec3, rng: *std.Random.DefaultPrng) void {
    const angle = rng.random().float(f32) * std.math.tau;
    const dist = rng.random().float(f32) * ai.wander_radius;

    ai.move_target = math.Vec3.init(
        ai.home_position.x() + @cos(angle) * dist,
        current_pos.y(), // Keep same height
        ai.home_position.z() + @sin(angle) * dist,
    );
    ai.has_move_target = true;
}

/// Trigger flee behavior (called when entity is attacked)
pub fn triggerFlee(ai: *AI, attacker_pos: math.Vec3) void {
    if (ai.behavior == .passive) {
        ai.state = .fleeing;
        ai.state_timer = 0;
        // Set move target away from attacker
        ai.has_move_target = false;
    }
    _ = attacker_pos;
}

/// Check if entity should aggro on target
pub fn shouldAggro(ai: *const AI, dist_to_target: f32) bool {
    return ai.behavior == .hostile and dist_to_target <= ai.detection_range;
}

/// Get AI behavior for a mob type
pub fn getDefaultBehavior(mob_type: MobType) AIBehavior {
    return switch (mob_type) {
        .pig, .cow, .chicken, .sheep => .passive,
        .zombie, .skeleton, .creeper, .spider => .hostile,
        .villager => .wander,
        .player => .idle,
        .custom => .idle,
    };
}

/// Get default AI stats for a mob type
pub fn getDefaultAIStats(mob_type: MobType) AI {
    var ai = AI{};
    ai.behavior = getDefaultBehavior(mob_type);

    switch (mob_type) {
        .pig, .cow, .sheep => {
            ai.wander_radius = 8.0;
            ai.speed = 0.8;
            ai.detection_range = 8.0;
        },
        .chicken => {
            ai.wander_radius = 6.0;
            ai.speed = 1.0;
            ai.detection_range = 6.0;
        },
        .zombie => {
            ai.detection_range = 24.0;
            ai.attack_range = 2.0;
            ai.attack_damage = 6.0;
            ai.attack_cooldown = 1.0;
            ai.speed = 1.0;
        },
        .skeleton => {
            ai.detection_range = 24.0;
            ai.attack_range = 12.0;
            ai.attack_damage = 4.0;
            ai.attack_cooldown = 1.5;
            ai.speed = 1.0;
        },
        .creeper => {
            ai.detection_range = 16.0;
            ai.attack_range = 3.0;
            ai.attack_damage = 30.0;
            ai.speed = 1.2;
        },
        .spider => {
            ai.detection_range = 16.0;
            ai.attack_range = 2.0;
            ai.attack_damage = 4.0;
            ai.attack_cooldown = 0.5;
            ai.speed = 1.5;
        },
        .villager => {
            ai.wander_radius = 12.0;
            ai.speed = 0.7;
            ai.detection_range = 10.0;
        },
        else => {},
    }

    return ai;
}

// ============================================================================
// Tests
// ============================================================================

test "wander target selection" {
    var ai = AI{};
    ai.wander_radius = 10.0;
    ai.home_position = math.Vec3.init(100, 50, 100);

    var rng = std.Random.DefaultPrng.init(12345);
    const current_pos = math.Vec3.init(100, 50, 100);

    pickWanderTarget(&ai, current_pos, &rng);

    try std.testing.expect(ai.has_move_target);

    // Target should be within wander radius of home
    const dist = math.Vec3.distance(ai.move_target, ai.home_position);
    try std.testing.expect(dist <= ai.wander_radius + 0.1);
}

test "default behavior assignment" {
    try std.testing.expectEqual(AIBehavior.passive, getDefaultBehavior(.pig));
    try std.testing.expectEqual(AIBehavior.hostile, getDefaultBehavior(.zombie));
    try std.testing.expectEqual(AIBehavior.wander, getDefaultBehavior(.villager));
}

test "default AI stats" {
    const zombie_ai = getDefaultAIStats(.zombie);
    try std.testing.expectEqual(AIBehavior.hostile, zombie_ai.behavior);
    try std.testing.expectApproxEqAbs(@as(f32, 24.0), zombie_ai.detection_range, 0.001);

    const pig_ai = getDefaultAIStats(.pig);
    try std.testing.expectEqual(AIBehavior.passive, pig_ai.behavior);
}
