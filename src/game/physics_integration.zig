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
    entity_to_body: std.AutoHashMap(usize, physics.world.BodyHandle),

    /// Map from physics body ID to entity ID
    body_to_entity: std.AutoHashMap(physics.world.BodyHandle, usize),

    pub fn init(allocator: std.mem.Allocator, physics_world: *physics.PhysicsWorld, entity_world: *ecs.ECSWorld) !PhysicsIntegration {
        return PhysicsIntegration{
            .allocator = allocator,
            .physics_world = physics_world,
            .entity_world = entity_world,
            .entity_to_body = std.AutoHashMap(usize, physics.world.BodyHandle).init(allocator),
            .body_to_entity = std.AutoHashMap(physics.world.BodyHandle, usize).init(allocator),
        };
    }

    pub fn deinit(self: *PhysicsIntegration) void {
        self.entity_to_body.deinit();
        self.body_to_entity.deinit();
    }

    /// Create a rigid body for a game entity
    pub fn createRigidBodyForEntity(self: *PhysicsIntegration, entity_id: usize, config: RigidBodyConfig) !void {
        var body = if (config.is_kinematic)
            physics.RigidBody.kinematic(config.position)
        else if (config.mass == 0.0)
            physics.RigidBody.static(config.position)
        else
            physics.RigidBody.dynamic(config.mass, config.position);

        body.material.restitution = config.restitution;
        body.material.friction = config.friction;

        const body_handle = try self.physics_world.createBody(body);

        // Attach collider
        const collider = switch (config.shape) {
            .sphere => physics.Collider.sphere(config.position, config.radius),
            .box => physics.Collider.box(config.position, physics.Vector3.init(config.width * 0.5, config.height * 0.5, config.depth * 0.5)),
            .capsule => physics.Collider.capsule(config.position, config.radius, config.height),
            .cylinder => physics.Collider.sphere(config.position, config.radius), // Cylinder fallback to sphere for now
        };

        try self.physics_world.attachCollider(body_handle, collider);

        try self.entity_to_body.put(entity_id, body_handle);
        try self.body_to_entity.put(body_handle, entity_id);
    }

    /// Update game entities from physics simulation
    pub fn updateEntitiesFromPhysics(self: *PhysicsIntegration) !void {
        var body_iter = self.body_to_entity.iterator();
        while (body_iter.next()) |entry| {
            const body_id = entry.key_ptr.*;
            const entity_id = entry.value_ptr.*;

            if (self.physics_world.getRigidBody(body_id)) |body| {
                // Update entity transform from physics body
                const pos = body.position;
                const rot = body.orientation;

                // Update Position component
                if (self.entity_world.getComponent(entity_id, ecs.Position)) |p| {
                    p.x = pos.x;
                    p.y = pos.y;
                    p.z = pos.z;
                }

                // Update Rotation component
                if (self.entity_world.getComponent(entity_id, ecs.Rotation)) |r| {
                    r.x = rot.x;
                    r.y = rot.y;
                    r.z = rot.z;
                    r.w = rot.w;
                }

                // Update combined Transform component if it exists
                if (self.entity_world.getComponent(entity_id, ecs.Transform)) |t| {
                    t.position.x = pos.x;
                    t.position.y = pos.y;
                    t.position.z = pos.z;
                    t.rotation.x = rot.x;
                    t.rotation.y = rot.y;
                    t.rotation.z = rot.z;
                    t.rotation.w = rot.w;
                }
            }
        }
    }

    /// Apply force to entity's rigid body
    pub fn applyForceToEntity(self: *PhysicsIntegration, entity_id: usize, force: physics.Vector3) !void {
        if (self.entity_to_body.get(entity_id)) |body_handle| {
            if (self.physics_world.getBody(body_handle)) |body| {
                body.addForce(force);
            }
        }
    }

    /// Set velocity for entity's rigid body
    pub fn setEntityVelocity(self: *PhysicsIntegration, entity_id: usize, velocity: physics.Vector3) !void {
        if (self.entity_to_body.get(entity_id)) |body_handle| {
            if (self.physics_world.getBody(body_handle)) |body| {
                body.setLinearVelocity(velocity);
            }
        }
    }

    /// Get entity velocity from physics body
    pub fn getEntityVelocity(self: *PhysicsIntegration, entity_id: usize) ?physics.Vector3 {
        if (self.entity_to_body.get(entity_id)) |body_handle| {
            if (self.physics_world.getBody(body_handle)) |body| {
                return body.linear_velocity;
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
        const manifolds = self.physics_world.manifolds.items;

        for (manifolds) |manifold| {
            if (self.body_to_entity.get(manifold.body_a)) |entity_a| {
                if (self.body_to_entity.get(manifold.body_b)) |entity_b| {
                    callback(entity_a, entity_b);
                }
            }
        }
    }

    /// Remove physics body for entity
    pub fn removeEntityRigidBody(self: *PhysicsIntegration, entity_id: usize) void {
        if (self.entity_to_body.fetchRemove(entity_id)) |entry| {
            const body_handle = entry.value;
            _ = self.body_to_entity.remove(body_handle);
            self.physics_world.destroyBody(body_handle);
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
