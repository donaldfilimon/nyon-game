//! Physics World - Main physics simulation coordinator
//!
//! This module provides the main physics world that manages rigid bodies,
//! collision detection, and constraint solving for realistic physics simulation.

const std = @import("std");
const types = @import("types.zig");
const rigidbody = @import("rigidbody.zig");
const colliders = @import("colliders.zig");

/// Physics simulation configuration
pub const PhysicsConfig = struct {
    gravity: types.Vector3 = types.Vector3.init(0, -9.81, 0),
    max_substeps: u32 = 10,
    fixed_timestep: f32 = 1.0 / 60.0,
    position_iterations: u32 = 8,
    velocity_iterations: u32 = 4,
    broad_phase_enabled: bool = true,
    sleep_threshold: f32 = 0.1,
    baumgarte_factor: f32 = 0.2, // Constraint stabilization
};

/// Collision pair for broad phase results
pub const CollisionPair = struct {
    a: BodyHandle,
    b: BodyHandle,
};

/// Physics body handle for external references
pub const BodyHandle = usize;

/// Physics constraint types
pub const ConstraintType = enum {
    distance,
    hinge,
    fixed,
};

/// Physics constraint for joints and connections
pub const Constraint = struct {
    type: ConstraintType,
    body_a: BodyHandle,
    body_b: BodyHandle,
    local_anchor_a: types.Vector3,
    local_anchor_b: types.Vector3,
    data: union {
        distance: struct {
            rest_length: f32,
            stiffness: f32,
            damping: f32,
        },
        hinge: struct {
            axis: types.Vector3,
            min_angle: f32,
            max_angle: f32,
        },
        fixed: void,
    },

    pub fn distance(body_a: BodyHandle, body_b: BodyHandle, anchor_a: types.Vector3, anchor_b: types.Vector3, rest_length: f32) Constraint {
        return .{
            .type = .distance,
            .body_a = body_a,
            .body_b = body_b,
            .local_anchor_a = anchor_a,
            .local_anchor_b = anchor_b,
            .data = .{ .distance = .{
                .rest_length = rest_length,
                .stiffness = 1000.0,
                .damping = 10.0,
            } },
        };
    }
};

/// Main physics world
pub const PhysicsWorld = struct {
    allocator: std.mem.Allocator,
    config: PhysicsConfig,
    bodies: std.ArrayList(rigidbody.RigidBody),
    colliders: std.ArrayList(?colliders.Collider),
    constraints: std.ArrayList(Constraint),

    // Broad phase acceleration structures
    dynamic_aabbs: std.ArrayList(types.AABB),
    static_aabbs: std.ArrayList(types.AABB),

    // Collision detection results
    potential_pairs: std.ArrayList(CollisionPair),
    manifolds: std.ArrayList(types.ContactManifold),

    // Performance tracking
    stats: struct {
        bodies: usize = 0,
        constraints: usize = 0,
        potential_collisions: usize = 0,
        actual_collisions: usize = 0,
        solve_time: u64 = 0,
    },

    /// Initialize a new physics world
    pub fn init(allocator: std.mem.Allocator, config: PhysicsConfig) PhysicsWorld {
        return .{
            .allocator = allocator,
            .config = config,
            .bodies = std.ArrayList(rigidbody.RigidBody).initCapacity(allocator, 0) catch unreachable,
            .colliders = std.ArrayList(?colliders.Collider).initCapacity(allocator, 0) catch unreachable,
            .constraints = std.ArrayList(Constraint).initCapacity(allocator, 0) catch unreachable,
            .dynamic_aabbs = std.ArrayList(types.AABB).initCapacity(allocator, 0) catch unreachable,
            .static_aabbs = std.ArrayList(types.AABB).initCapacity(allocator, 0) catch unreachable,
            .potential_pairs = std.ArrayList(CollisionPair).initCapacity(allocator, 0) catch unreachable,
            .manifolds = std.ArrayList(types.ContactManifold).initCapacity(allocator, 0) catch unreachable,
            .stats = .{},
        };
    }

    /// Deinitialize the physics world
    pub fn deinit(self: *PhysicsWorld) void {
        self.bodies.deinit(self.allocator);
        self.colliders.deinit(self.allocator);
        self.constraints.deinit(self.allocator);
        self.dynamic_aabbs.deinit(self.allocator);
        self.static_aabbs.deinit(self.allocator);
        self.potential_pairs.deinit(self.allocator);
        self.manifolds.deinit(self.allocator);
    }

    /// Create a new rigid body
    pub fn createBody(self: *PhysicsWorld, body: rigidbody.RigidBody) !BodyHandle {
        const handle = self.bodies.items.len;
        try self.bodies.append(self.allocator, body);
        try self.colliders.append(self.allocator, null); // No collider by default

        // Initialize AABB arrays
        try self.dynamic_aabbs.append(self.allocator, types.AABB.init(types.Vector3.zero(), types.Vector3.zero()));
        try self.static_aabbs.append(self.allocator, types.AABB.init(types.Vector3.zero(), types.Vector3.zero()));

        return handle;
    }

    /// Destroy a rigid body
    pub fn destroyBody(self: *PhysicsWorld, handle: BodyHandle) void {
        if (handle >= self.bodies.items.len) return;

        // Remove body
        _ = self.bodies.swapRemove(handle);

        // Remove collider
        _ = self.colliders.swapRemove(handle);

        // Remove AABBs
        _ = self.dynamic_aabbs.swapRemove(handle);
        _ = self.static_aabbs.swapRemove(handle);

        // Note: This invalidates handles for bodies after the removed one
        // In a production system, you'd use a free list or handle remapping
    }

    /// Attach a collider to a body
    pub fn attachCollider(self: *PhysicsWorld, handle: BodyHandle, collider: colliders.Collider) !void {
        if (handle >= self.colliders.items.len) return error.InvalidBodyHandle;
        self.colliders.items[handle] = collider;
    }

    /// Add a constraint between two bodies
    pub fn addConstraint(self: *PhysicsWorld, constraint: Constraint) !void {
        try self.constraints.append(self.allocator, constraint);
    }

    /// Step the physics simulation
    pub fn step(self: *PhysicsWorld, dt: f32) !void {
        const start_time = std.time.nanoTimestamp();

        // Handle variable timestep with substepping
        const substep_dt = self.config.fixed_timestep;
        const num_substeps = @min(self.config.max_substeps, @as(u32, @intFromFloat(@ceil(dt / substep_dt))));

        for (0..num_substeps) |_| {
            try self.substep(substep_dt);
        }

        self.stats.solve_time = std.time.nanoTimestamp() - start_time;
    }

    /// Single physics substep
    fn substep(self: *PhysicsWorld, dt: f32) !void {
        // 1. Update AABBs for broad phase
        try self.updateAABBs();

        // 2. Broad phase collision detection
        if (self.config.broad_phase_enabled) {
            try self.broadPhase();
        } else {
            // Fallback: check all pairs
            try self.bruteForceBroadPhase();
        }

        // 3. Narrow phase collision detection
        try self.narrowPhase();

        // 4. Integrate velocities (first half of symplectic Euler)
        self.integrateVelocities(dt);

        // 5. Solve constraints
        try self.solveConstraints(dt);

        // 6. Integrate positions
        self.integratePositions(dt);

        // 7. Solve position constraints (for stability)
        try self.solvePositionConstraints();

        // 8. Update sleeping bodies
        self.updateSleepingBodies();
    }

    /// Update axis-aligned bounding boxes for all bodies
    fn updateAABBs(self: *PhysicsWorld) !void {
        for (self.bodies.items, self.colliders.items, 0..) |*body, collider_opt, i| {
            if (collider_opt) |collider| {
                // Transform collider by body position
                var transformed_collider = collider;
                // Note: In a full implementation, this would transform the collider
                // by the body's position and orientation

                const aabb = transformed_collider.getAABB();

                if (body.is_static) {
                    self.static_aabbs.items[i] = aabb;
                } else {
                    self.dynamic_aabbs.items[i] = aabb;
                }
            }
        }
    }

    /// Broad phase collision detection using AABB overlap
    fn broadPhase(self: *PhysicsWorld) !void {
        self.potential_pairs.clearRetainingCapacity();

        // Dynamic vs dynamic
        for (0..self.bodies.items.len) |i| {
            for (i + 1..self.bodies.items.len) |j| {
                if (self.dynamic_aabbs.items[i].intersects(self.dynamic_aabbs.items[j])) {
                    try self.potential_pairs.append(self.allocator, CollisionPair{ .a = i, .b = j });
                }
            }
        }

        // Dynamic vs static
        for (0..self.bodies.items.len) |i| {
            for (0..self.static_aabbs.items.len) |j| {
                if (self.dynamic_aabbs.items[i].intersects(self.static_aabbs.items[j])) {
                    try self.potential_pairs.append(self.allocator, CollisionPair{ .a = i, .b = j });
                }
            }
        }
    }

    /// Brute force broad phase (for testing/small scenes)
    fn bruteForceBroadPhase(self: *PhysicsWorld) !void {
        self.potential_pairs.clearRetainingCapacity();

        for (0..self.bodies.items.len) |i| {
            for (i + 1..self.bodies.items.len) |j| {
                try self.potential_pairs.append(self.allocator, CollisionPair{ .a = i, .b = j });
            }
        }
    }

    /// Narrow phase collision detection
    fn narrowPhase(self: *PhysicsWorld) !void {
        self.manifolds.clearRetainingCapacity();

        for (self.potential_pairs.items) |pair| {
            const collider_a = self.colliders.items[pair.a];
            const collider_b = self.colliders.items[pair.b];

            if (collider_a == null or collider_b == null) continue;

            if (collider_a.?.collidesWith(collider_b.?)) |manifold| {
                var contact = manifold;
                contact.body_a = pair.a;
                contact.body_b = pair.b;
                try self.manifolds.append(self.allocator, contact);
            }
        }

        self.stats.potential_collisions = self.potential_pairs.items.len;
        self.stats.actual_collisions = self.manifolds.items.len;
    }

    /// Integrate velocities for all bodies
    fn integrateVelocities(self: *PhysicsWorld, dt: f32) void {
        for (self.bodies.items) |*body| {
            body.integrate(dt, self.config.gravity);
        }
    }

    /// Integrate positions for all bodies
    fn integratePositions(self: *PhysicsWorld, dt: f32) void {
        for (self.bodies.items) |*body| {
            if (!body.is_kinematic and !body.is_static) {
                body.position = body.position.add(body.linear_velocity.mul(dt));
            }
        }
    }

    /// Solve velocity constraints
    fn solveConstraints(self: *PhysicsWorld, dt: f32) !void {
        // Solve contact constraints
        for (0..self.config.velocity_iterations) |_| {
            for (self.manifolds.items) |*manifold| {
                try self.solveContactConstraint(manifold, dt);
            }

            // Solve joint constraints
            for (self.constraints.items) |*constraint| {
                try self.solveJointConstraint(constraint, dt);
            }
        }
    }

    /// Solve position constraints for stability
    fn solvePositionConstraints(self: *PhysicsWorld) !void {
        for (0..self.config.position_iterations) |_| {
            for (self.manifolds.items) |*manifold| {
                try self.solveContactPositionConstraint(manifold);
            }
        }
    }

    /// Solve a contact constraint
    fn solveContactConstraint(self: *PhysicsWorld, manifold: *types.ContactManifold, dt: f32) !void {
        _ = dt; // Not used in simplified implementation
        const body_a = &self.bodies.items[manifold.body_a];
        const body_b = &self.bodies.items[manifold.body_b];

        if (body_a.is_static and body_b.is_static) return;

        // Simplified impulse-based collision response
        const relative_velocity = body_b.linear_velocity.sub(body_a.linear_velocity);
        const velocity_along_normal = relative_velocity.dot(manifold.normal);

        if (velocity_along_normal > 0) return; // Separating

        const restitution = @min(body_a.material.restitution, body_b.material.restitution);
        const friction = @min(body_a.material.friction, body_b.material.friction);

        // Calculate impulse
        const inv_mass_sum = body_a.inverse_mass + body_b.inverse_mass;
        if (inv_mass_sum == 0) return; // Both static

        var impulse = -(1.0 + restitution) * velocity_along_normal / inv_mass_sum;

        // Apply friction
        const tangent_velocity = relative_velocity.sub(manifold.normal.mul(velocity_along_normal));
        const tangent_length = tangent_velocity.length();

        if (tangent_length > 0.001) {
            const tangent = tangent_velocity.mul(1.0 / tangent_length);
            const friction_impulse = -tangent_velocity.dot(tangent) * friction / inv_mass_sum;
            impulse = @min(impulse, friction_impulse);
        }

        const impulse_vector = manifold.normal.mul(impulse);

        // Apply impulse
        if (!body_a.is_static) {
            body_a.linear_velocity = body_a.linear_velocity.sub(impulse_vector.mul(body_a.inverse_mass));
        }
        if (!body_b.is_static) {
            body_b.linear_velocity = body_b.linear_velocity.add(impulse_vector.mul(body_b.inverse_mass));
        }
    }

    /// Solve a contact position constraint
    fn solveContactPositionConstraint(self: *PhysicsWorld, manifold: *types.ContactManifold) !void {
        const body_a = &self.bodies.items[manifold.body_a];
        const body_b = &self.bodies.items[manifold.body_b];

        if (body_a.is_static and body_b.is_static) return;

        const inv_mass_sum = body_a.inverse_mass + body_b.inverse_mass;
        if (inv_mass_sum == 0) return;

        // Position correction
        const correction = manifold.normal.mul(manifold.penetration * self.config.baumgarte_factor / inv_mass_sum);

        if (!body_a.is_static) {
            body_a.position = body_a.position.sub(correction.mul(body_a.inverse_mass));
        }
        if (!body_b.is_static) {
            body_b.position = body_b.position.add(correction.mul(body_b.inverse_mass));
        }
    }

    /// Solve a joint constraint
    fn solveJointConstraint(self: *PhysicsWorld, constraint: *Constraint, dt: f32) !void {
        _ = dt; // Not used in simplified implementation

        const body_a = &self.bodies.items[constraint.body_a];
        const body_b = &self.bodies.items[constraint.body_b];

        switch (constraint.type) {
            .distance => {
                const data = &constraint.data.distance;

                // Get world space anchor points
                const world_anchor_a = body_a.position.add(constraint.local_anchor_a);
                const world_anchor_b = body_b.position.add(constraint.local_anchor_b);

                const delta = world_anchor_b.sub(world_anchor_a);
                const distance = delta.length();

                if (distance == 0) return;

                const normal = delta.mul(1.0 / distance);
                const constraint_error = distance - data.rest_length;

                // Calculate constraint force
                const inv_mass_sum = body_a.inverse_mass + body_b.inverse_mass;
                if (inv_mass_sum == 0) return;

                const correction = normal.mul(-constraint_error * data.stiffness / inv_mass_sum);

                if (!body_a.is_static) {
                    body_a.position = body_a.position.sub(correction.mul(body_a.inverse_mass));
                }
                if (!body_b.is_static) {
                    body_b.position = body_b.position.add(correction.mul(body_b.inverse_mass));
                }
            },
            .hinge => {
                // Simplified hinge - would need full angular constraint solving
            },
            .fixed => {
                // Fixed joint - bodies should be at same position
                const pos_diff = body_b.position.sub(body_a.position);
                const correction = pos_diff.mul(0.5); // Split the difference

                if (!body_a.is_static) {
                    body_a.position = body_a.position.add(correction);
                }
                if (!body_b.is_static) {
                    body_b.position = body_b.position.sub(correction);
                }
            },
        }
    }

    /// Update sleeping bodies
    fn updateSleepingBodies(self: *PhysicsWorld) void {
        for (self.bodies.items) |*body| {
            if (body.isSleeping()) {
                body.linear_velocity = types.Vector3.zero();
                body.angular_velocity = types.Vector3.zero();
            }
        }
    }

    /// Perform ray casting against all bodies
    pub fn raycast(self: *const PhysicsWorld, ray: types.Ray) ?struct { hit: types.RaycastHit, body: BodyHandle } {
        var closest_hit: ?struct { hit: types.RaycastHit, body: BodyHandle } = null;

        for (self.bodies.items, self.colliders.items, 0..) |_, collider_opt, i| {
            if (collider_opt) |collider| {
                // Transform ray to local space (simplified)
                if (collider.raycast(ray)) |hit| {
                    const is_closer = closest_hit == null or hit.distance < closest_hit.?.hit.distance;
                    if (is_closer) {
                        closest_hit = .{ .hit = hit, .body = i };
                    }
                }
            }
        }

        return closest_hit;
    }

    /// Get body by handle
    pub fn getBody(self: *PhysicsWorld, handle: BodyHandle) ?*rigidbody.RigidBody {
        if (handle >= self.bodies.items.len) return null;
        return &self.bodies.items[handle];
    }

    /// Get current physics statistics
    pub fn getStats(self: *const PhysicsWorld) struct {
        bodies: usize,
        constraints: usize,
        potential_collisions: usize,
        actual_collisions: usize,
        solve_time_ns: u64,
    } {
        return .{
            .bodies = self.bodies.items.len,
            .constraints = self.constraints.items.len,
            .potential_collisions = self.stats.potential_collisions,
            .actual_collisions = self.stats.actual_collisions,
            .solve_time_ns = self.stats.solve_time,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "physics world creation" {
    var world = PhysicsWorld.init(std.testing.allocator, .{});
    defer world.deinit();

    try std.testing.expect(world.bodies.items.len == 0);
    try std.testing.expect(world.constraints.items.len == 0);
}

test "rigid body creation" {
    var world = PhysicsWorld.init(std.testing.allocator, .{});
    defer world.deinit();

    const body = rigidbody.RigidBody.dynamic(10.0, types.Vector3.zero());
    const handle = try world.createBody(body);

    try std.testing.expect(handle == 0);
    try std.testing.expect(world.bodies.items.len == 1);

    const retrieved = world.getBody(handle);
    try std.testing.expect(retrieved != null);
    try std.testing.expect(retrieved.?.mass == 10.0);
}

test "constraint creation" {
    var world = PhysicsWorld.init(std.testing.allocator, .{});
    defer world.deinit();

    const body_a = try world.createBody(rigidbody.RigidBody.dynamic(1.0, types.Vector3.init(0, 0, 0)));
    const body_b = try world.createBody(rigidbody.RigidBody.dynamic(1.0, types.Vector3.init(2, 0, 0)));

    const constraint = Constraint.distance(body_a, body_b, types.Vector3.zero(), types.Vector3.zero(), 2.0);
    try world.addConstraint(constraint);

    try std.testing.expect(world.constraints.items.len == 1);
    try std.testing.expect(world.constraints.items[0].type == .distance);
}
