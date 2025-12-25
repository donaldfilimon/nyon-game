//! Physics Integration for Game Entities
//!
//! Connects physics system with game entities

const std = @import("std");
const physics = @import("physics/physics.zig");
const ecs = @import("ecs/ecs.zig");
const state_mod = @import("state.zig");

pub const PhysicsIntegration = struct {
    allocator: std.mem.Allocator,
    physics_world: *physics.PhysicsWorld,
    entity_world: *ecs.ECSWorld,

    /// Map from entity ID to physics body ID
    entity_to_body: std.HashMap(usize, physics.RigidBodyId),

    /// Map from physics body ID to entity ID
    body_to_entity: std.HashMap(physics.RigidBodyId, usize),

    pub fn init(allocator: std.mem.Allocator, physics_world: *physics.PhysicsWorld, entity_world: *ecs.ECSWorld) !PhysicsIntegration {
        return PhysicsIntegration{
            .allocator = allocator,
            .physics_world = physics_world,
            .entity_world = entity_world,
            .entity_to_body = std.HashMap(usize, physics.RigidBodyId).init(allocator),
            .body_to_entity = std.HashMap(physics.RigidBodyId, usize).init(allocator),
        };
    }

    pub fn deinit(self: *PhysicsIntegration) void {
        self.entity_to_body.deinit();
        self.body_to_entity.deinit();
    }

    /// Create a rigid body for a game entity
    pub fn createRigidBodyForEntity(self: *PhysicsIntegration, entity_id: usize, config: RigidBodyConfig) !void {
        const rigidbody = try physics.RigidBody.init(
            self.allocator,
            config.position,
            config.mass,
            config.shape,
        );
        defer rigidbody.deinit(self.allocator);

        const body_id = try self.physics_world.addRigidBody(rigidbody);

        try self.entity_to_body.put(entity_id, body_id);
        try self.body_to_entity.put(body_id, entity_id);
    }

    /// Update game entities from physics simulation
    pub fn updateEntitiesFromPhysics(self: *PhysicsIntegration) !void {
        var body_iter = self.body_to_entity.iterator();
        while (body_iter.next()) |entry| {
            const body_id = entry.key_ptr.*;
            const entity_id = entry.value_ptr.*;

            if (self.physics_world.getRigidBody(body_id)) |body| {
                // Update entity transform from physics body
                // This would require actual ECS component access
                _ = body;
                _ = entity_id;
            }
        }
    }

    /// Apply force to entity's rigid body
    pub fn applyForceToEntity(self: *PhysicsIntegration, entity_id: usize, force: physics.Vector3) !void {
        if (self.entity_to_body.get(entity_id)) |body_id| {
            try self.physics_world.applyForce(body_id, force);
        }
    }

    /// Set velocity for entity's rigid body
    pub fn setEntityVelocity(self: *PhysicsIntegration, entity_id: usize, velocity: physics.Vector3) !void {
        if (self.entity_to_body.get(entity_id)) |body_id| {
            try self.physics_world.setVelocity(body_id, velocity);
        }
    }

    /// Get entity velocity from physics body
    pub fn getEntityVelocity(self: *PhysicsIntegration, entity_id: usize) ?physics.Vector3 {
        if (self.entity_to_body.get(entity_id)) |body_id| {
            if (self.physics_world.getRigidBody(body_id)) |body| {
                return body.velocity;
            }
        }
        return null;
    }

    /// Create physics body for player
    pub fn createPlayerRigidBody(self: *PhysicsIntegration, player_x: f32, player_y: f32) !void {
        const config = RigidBodyConfig{
            .position = physics.Vector3{ .x = player_x, .y = player_y, .z = 0 },
            .mass = 70.0,
            .shape = .sphere,
            .radius = 20.0,
            .restitution = 0.0,
            .friction = 0.5,
            .is_kinematic = false,
        };

        // Use entity ID 0 for player
        try self.createRigidBodyForEntity(0, config);
    }

    /// Create physics body for enemy
    pub fn createEnemyRigidBody(self: *PhysicsIntegration, enemy_id: usize, x: f32, y: f32, enemy_type: anytype) !void {
        const config = switch (@tagName(enemy_type)) {
            .chaser => RigidBodyConfig{
                .position = physics.Vector3{ .x = x, .y = y, .z = 0 },
                .mass = 50.0,
                .shape = .sphere,
                .radius = 20.0,
                .restitution = 0.2,
                .friction = 0.5,
                .is_kinematic = false,
            },
            .patroller => RigidBodyConfig{
                .position = physics.Vector3{ .x = x, .y = y, .z = 0 },
                .mass = 75.0,
                .shape = .sphere,
                .radius = 25.0,
                .restitution = 0.1,
                .friction = 0.6,
                .is_kinematic = false,
            },
            .sniper => RigidBodyConfig{
                .position = physics.Vector3{ .x = x, .y = y, .z = 0 },
                .mass = 30.0,
                .shape = .sphere,
                .radius = 18.0,
                .restitution = 0.3,
                .friction = 0.4,
                .is_kinematic = true,
            },
            .drone => RigidBodyConfig{
                .position = physics.Vector3{ .x = x, .y = y, .z = 0 },
                .mass = 40.0,
                .shape = .sphere,
                .radius = 15.0,
                .restitution = 0.5,
                .friction = 0.3,
                .is_kinematic = false,
            },
            else => RigidBodyConfig{
                .position = physics.Vector3{ .x = x, .y = y, .z = 0 },
                .mass = 50.0,
                .shape = .sphere,
                .radius = 20.0,
                .restitution = 0.2,
                .friction = 0.5,
                .is_kinematic = false,
            },
        };

        try self.createRigidBodyForEntity(enemy_id, config);
    }

    /// Handle collisions between entities
    pub fn handleCollisions(self: *PhysicsIntegration, callback: *const fn (entity_id_a: usize, entity_id_b: usize) void) !void {
        const collisions = try self.physics_world.getCollisions(self.allocator);
        defer self.allocator.free(collisions);

        for (collisions) |collision| {
            if (self.body_to_entity.get(collision.body_a)) |entity_a| {
                if (self.body_to_entity.get(collision.body_b)) |entity_b| {
                    callback(entity_a, entity_b);
                }
            }
        }
    }

    /// Remove physics body for entity
    pub fn removeEntityRigidBody(self: *PhysicsIntegration, entity_id: usize) !void {
        if (self.entity_to_body.fetchRemove(entity_id)) |entry| {
            const body_id = entry.value;
            _ = self.body_to_entity.remove(body_id);
            try self.physics_world.removeRigidBody(body_id);
        }
    }
};

pub const RigidBodyConfig = struct {
    position: physics.Vector3,
    mass: f32,
    shape: CollisionShape,
    radius: f32 = 20.0,
    width: f32 = 20.0,
    height: f32 = 20.0,
    depth: f32 = 20.0,
    restitution: f32 = 0.2,
    friction: f32 = 0.5,
    is_kinematic: bool = false,
};

pub const CollisionShape = enum {
    sphere,
    box,
    capsule,
    cylinder,
};

pub const PhysicsCollisionData = struct {
    body_a: physics.RigidBodyId,
    body_b: physics.RigidBodyId,
    contact_point: physics.Vector3,
    contact_normal: physics.Vector3,
    penetration_depth: f32,
};
