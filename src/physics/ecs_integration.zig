//! ECS Physics Integration - Connecting physics to the ECS world
//!
//! This module provides the integration layer between the physics simulation
//! and the ECS, allowing physics components to be managed through the ECS.

const std = @import("std");
const ecs = @import("../ecs/ecs.zig");
const physics = @import("physics.zig");

/// Physics system that integrates with the ECS
pub const PhysicsSystem = struct {
    allocator: std.mem.Allocator,
    world: physics.world.PhysicsWorld,
    entity_to_body: std.AutoHashMap(ecs.EntityId, physics.world.BodyHandle),
    body_to_entity: std.AutoHashMap(physics.world.BodyHandle, ecs.EntityId),

    /// Initialize the physics system
    pub fn init(allocator: std.mem.Allocator, config: physics.world.PhysicsConfig) PhysicsSystem {
        return .{
            .allocator = allocator,
            .world = physics.world.PhysicsWorld.init(allocator, config),
            .entity_to_body = std.AutoHashMap(ecs.EntityId, physics.world.BodyHandle).init(allocator),
            .body_to_entity = std.AutoHashMap(physics.world.BodyHandle, ecs.EntityId).init(allocator),
        };
    }

    /// Deinitialize the physics system
    pub fn deinit(self: *PhysicsSystem) void {
        self.world.deinit();
        self.entity_to_body.deinit();
        self.body_to_entity.deinit();
    }

    /// Update the physics system (call once per frame)
    pub fn update(self: *PhysicsSystem, ecs_world: *ecs.World, dt: f32) !void {
        // Sync ECS transforms to physics bodies
        try self.syncECSToPhysics(ecs_world);

        // Step physics simulation
        try self.world.step(dt);

        // Sync physics results back to ECS
        try self.syncPhysicsToECS(ecs_world);
    }

    /// Add a rigid body component to an entity
    pub fn addRigidBody(
        self: *PhysicsSystem,
        ecs_world: *ecs.World,
        entity: ecs.EntityId,
        body: physics.rigidbody.RigidBody,
        collider: ?physics.colliders.Collider,
    ) !void {
        _ = ecs_world; // Mark as used (actually used in sync functions)
        // Create physics body
        const body_handle = try self.world.createBody(body);

        // Attach collider if provided
        if (collider) |col| {
            try self.world.attachCollider(body_handle, col);
        }

        // Map entity to body
        try self.entity_to_body.put(entity, body_handle);
        try self.body_to_entity.put(body_handle, entity);
    }

    /// Remove a rigid body from an entity
    pub fn removeRigidBody(self: *PhysicsSystem, entity: ecs.EntityId) void {
        if (self.entity_to_body.get(entity)) |body_handle| {
            self.world.destroyBody(body_handle);
            _ = self.entity_to_body.remove(entity);
            _ = self.body_to_entity.remove(body_handle);
        }
    }

    /// Apply a force to an entity's rigid body
    pub fn applyForce(self: *PhysicsSystem, entity: ecs.EntityId, force: physics.types.Vector3) void {
        if (self.entity_to_body.get(entity)) |body_handle| {
            if (self.world.getBody(body_handle)) |body| {
                body.addForce(force);
            }
        }
    }

    /// Apply a force at a specific point on an entity's rigid body
    pub fn applyForceAtPoint(
        self: *PhysicsSystem,
        entity: ecs.EntityId,
        force: physics.types.Vector3,
        point: physics.types.Vector3,
    ) void {
        if (self.entity_to_body.get(entity)) |body_handle| {
            if (self.world.getBody(body_handle)) |body| {
                body.addForceAtPoint(force, point);
            }
        }
    }

    /// Apply torque to an entity's rigid body
    pub fn applyTorque(self: *PhysicsSystem, entity: ecs.EntityId, torque: physics.types.Vector3) void {
        if (self.entity_to_body.get(entity)) |body_handle| {
            if (self.world.getBody(body_handle)) |body| {
                body.addTorque(torque);
            }
        }
    }

    /// Set the position of an entity's rigid body
    pub fn setPosition(self: *PhysicsSystem, entity: ecs.EntityId, position: physics.types.Vector3) void {
        if (self.entity_to_body.get(entity)) |body_handle| {
            if (self.world.getBody(body_handle)) |body| {
                body.setPosition(position);
            }
        }
    }

    /// Set the velocity of an entity's rigid body
    pub fn setVelocity(self: *PhysicsSystem, entity: ecs.EntityId, velocity: physics.types.Vector3) void {
        if (self.entity_to_body.get(entity)) |body_handle| {
            if (self.world.getBody(body_handle)) |body| {
                body.setLinearVelocity(velocity);
            }
        }
    }

    /// Perform ray casting in the physics world
    pub fn raycast(
        self: *const PhysicsSystem,
        ray: physics.types.Ray,
    ) ?struct { hit: physics.types.RaycastHit, entity: ecs.EntityId } {
        if (self.world.raycast(ray)) |result| {
            if (self.body_to_entity.get(result.body)) |entity| {
                return .{ .hit = result.hit, .entity = entity };
            }
        }
        return null;
    }

    /// Add a physics constraint between two entities
    pub fn addConstraint(self: *PhysicsSystem, constraint: physics.world.Constraint) !void {
        // Validate that both entities exist
        if (!self.body_to_entity.contains(constraint.body_a)) return error.InvalidBodyA;
        if (!self.body_to_entity.contains(constraint.body_b)) return error.InvalidBodyB;

        try self.world.addConstraint(constraint);
    }

    /// Get physics statistics
    pub fn getStats(self: *const PhysicsSystem) physics.world.PhysicsWorld.Stats {
        return self.world.getStats();
    }

    /// Sync ECS transform components to physics bodies
    fn syncECSToPhysics(self: *PhysicsSystem, ecs_world: *ecs.World) !void {
        var query = ecs_world.createQuery();
        defer query.deinit();

        var builder = try query.with(ecs.component.Transform);
        var pos_query = try builder.build();
        defer pos_query.deinit();

        pos_query.updateMatches(ecs_world.archetypes.items);

        var iter = pos_query.iter();
        while (iter.next()) |entity_data| {
            const entity = entity_data.entity;
            const transform = entity_data.get(ecs.component.Transform) orelse continue;

            // Update physics body position if entity has one
            if (self.entity_to_body.get(entity)) |body_handle| {
                if (self.world.getBody(body_handle)) |body| {
                    // Only sync if entity is kinematic (physics doesn't control kinematic bodies)
                    if (body.is_kinematic) {
                        body.setPosition(.{
                            .x = transform.position.x,
                            .y = transform.position.y,
                            .z = transform.position.z,
                        });
                    }
                }
            }
        }
    }

    /// Sync physics body results back to ECS transforms
    fn syncPhysicsToECS(self: *PhysicsSystem, ecs_world: *ecs.World) !void {
        // Iterate through all physics bodies and update their ECS transforms
        for (self.world.bodies.items, 0..) |body, body_idx| {
            const handle = physics.types.BodyHandle{ .index = body_idx, .generation = self.world.generations.items[body_idx] };
            if (self.body_to_entity.get(handle)) |entity| {
                // Update ECS transform
                if (ecs_world.getComponent(entity, ecs.component.Transform)) |transform| {
                    transform.position.x = body.position.x;
                    transform.position.y = body.position.y;
                    transform.position.z = body.position.z;

                    // Convert quaternion back to rotation (simplified)
                    transform.rotation.x = body.orientation.x;
                    transform.rotation.y = body.orientation.y;
                    transform.rotation.z = body.orientation.z;
                    transform.rotation.w = body.orientation.w;
                }
            }
        }
    }
};

// ============================================================================
// Example Usage in ECS Systems
// ============================================================================

/// Example physics update system
pub fn physicsUpdateSystem(ecs_world: *ecs.World, physics_system: *PhysicsSystem, dt: f32) !void {
    // Update physics
    try physics_system.update(ecs_world, dt);

    // Example: Apply gravity to all entities with rigid bodies
    var query = ecs_world.createQuery();
    defer query.deinit();

    var rigidbody_query = try query
        .with(ecs.component.Transform)
        .with(ecs.component.RigidBody)
        .build();
    defer rigidbody_query.deinit();

    rigidbody_query.updateMatches(ecs_world.archetypes.items);

    var iter = rigidbody_query.iter();
    while (iter.next()) |entity_data| {
        const entity = entity_data.entity;
        const transform = entity_data.get(ecs.component.Transform) orelse continue;

        // Apply custom forces based on entity properties
        // For example, wind force for entities above certain height
        if (transform.position.y > 10.0) {
            physics_system.applyForce(entity, physics.types.Vector3.init(0, -5, 0));
        }
    }
}

/// Example collision response system
pub fn collisionResponseSystem(ecs_world: *ecs.World, physics_system: *const PhysicsSystem) void {
    // Handle collisions detected by physics system
    // This would access the physics world's manifolds and respond to collisions

    var query = ecs_world.createQuery();
    defer query.deinit();

    // Find entities that collided and apply custom logic
    // (This is a simplified example)

    var collision_query = try query
        .with(ecs.component.Transform)
        .with(ecs.component.RigidBody)
        .build();
    defer collision_query.deinit();

    collision_query.updateMatches(ecs_world.archetypes.items);

    var iter = collision_query.iter();
    while (iter.next()) |entity_data| {
        const entity = entity_data.entity;
        const transform = entity_data.get(ecs.component.Transform) orelse continue;

        // Example: Destroy entities that fall below a certain point
        if (transform.position.y < -50.0) {
            // In a real system, you'd queue the entity for destruction
            // ecs_world.destroyEntity(entity);
        }

        // Example: Bounce entities off walls
        if (transform.position.x < -10.0 or transform.position.x > 10.0) {
            // Reverse X velocity
            var velocity = physics.types.Vector3.init(-1, 0, 0);
            if (transform.position.x < -10.0) {
                velocity.x = 1; // Bounce right
            }
            physics_system.setVelocity(entity, velocity);
        }
    }
}

/// Example: Character controller system
pub fn characterControllerSystem(ecs_world: *ecs.World, physics_system: *PhysicsSystem, input: anytype) void {
    var query = ecs_world.createQuery();
    defer query.deinit();

    var character_query = try query
        .with(ecs.component.Transform)
        .with(ecs.component.RigidBody)
        .with(ecs.component.InputReceiver) // Custom component for player characters
        .build();
    defer character_query.deinit();

    character_query.updateMatches(ecs_world.archetypes.items);

    var iter = character_query.iter();
    while (iter.next()) |entity_data| {
        const entity = entity_data.entity;

        // Handle input for character movement
        var move_force = physics.types.Vector3.zero();

        // Example input handling (would integrate with actual input system)
        if (input.left) move_force.x -= 100.0;
        if (input.right) move_force.x += 100.0;
        if (input.up) move_force.z -= 100.0;
        if (input.down) move_force.z += 100.0;
        if (input.jump) move_force.y += 500.0;

        physics_system.applyForce(entity, move_force);
    }
}

// ============================================================================
// Tests
// ============================================================================

test "physics system integration" {
    var physics_system = PhysicsSystem.init(std.testing.allocator, .{});
    defer physics_system.deinit();

    var ecs_world = ecs.World.init(std.testing.allocator);
    defer ecs_world.deinit();

    // Create an entity with physics
    const entity = try ecs_world.createEntity();
    try ecs_world.addComponent(entity, ecs.Position.init(0, 0, 0));
    try ecs_world.addComponent(entity, ecs.Rotation.identity());

    // Add rigid body to physics system
    const rigid_body = physics.rigidbody.RigidBody.dynamic(1.0, physics.types.Vector3.init(0, 5, 0));
    const sphere_collider = physics.colliders.Collider.sphere(physics.types.Vector3.zero(), 1.0);

    try physics_system.addRigidBody(&ecs_world, entity, rigid_body, sphere_collider);

    // Verify the entity has a physics body
    try std.testing.expect(physics_system.entity_to_body.contains(entity));

    // Update physics
    try physics_system.update(&ecs_world, 1.0 / 60.0);

    // Verify position was updated (should have fallen due to gravity)
    if (ecs_world.getComponent(entity, ecs.Position)) |pos| {
        try std.testing.expect(pos.y < 5.0); // Should be lower than initial position
    }
}

test "physics forces and torques" {
    var physics_system = PhysicsSystem.init(std.testing.allocator, .{});
    defer physics_system.deinit();

    var ecs_world = ecs.World.init(std.testing.allocator);
    defer ecs_world.deinit();

    const entity = try ecs_world.createEntity();
    try ecs_world.addComponent(entity, ecs.Position.init(0, 0, 0));

    const rigid_body = physics.rigidbody.RigidBody.dynamic(1.0, physics.types.Vector3.zero());
    try physics_system.addRigidBody(&ecs_world, entity, rigid_body, null);

    // Apply a force
    physics_system.applyForce(entity, physics.types.Vector3.init(10, 0, 0));

    // Update physics
    try physics_system.update(&ecs_world, 1.0 / 60.0);

    // Check that velocity changed
    if (physics_system.entity_to_body.get(entity)) |body_handle| {
        if (physics_system.world.getBody(body_handle)) |body| {
            try std.testing.expect(body.linear_velocity.x > 0);
        }
    }
}
