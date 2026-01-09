//! Physics System
//!
//! Provides basic rigid body physics and gravity simulation.

const std = @import("std");
const math = @import("../math/math.zig");
const collision = @import("collision.zig");

pub const AABB = collision.AABB;
pub const Ray = collision.Ray;
pub const RaycastHit = collision.RaycastHit;
pub const Sphere = collision.Sphere;
pub const rayVsAABB = collision.rayVsAABB;

/// Physics configuration constants
pub const Config = struct {
    /// Gravity in units/second^2 (negative Y is down)
    pub const GRAVITY: f32 = -20.0;
    /// Terminal velocity
    pub const TERMINAL_VELOCITY: f32 = -50.0;
    /// Ground friction coefficient
    pub const GROUND_FRICTION: f32 = 8.0;
    /// Air friction coefficient
    pub const AIR_FRICTION: f32 = 0.5;
    /// Default player height
    pub const PLAYER_HEIGHT: f32 = 1.8;
    /// Default player width
    pub const PLAYER_WIDTH: f32 = 0.6;
};

/// Rigid body component for physics simulation
pub const RigidBody = struct {
    velocity: math.Vec3 = math.Vec3.ZERO,
    acceleration: math.Vec3 = math.Vec3.ZERO,
    mass: f32 = 1.0,
    drag: f32 = 0.0,
    gravity_scale: f32 = 1.0,
    is_kinematic: bool = false,
    is_grounded: bool = false,

    /// Apply force to rigid body
    pub fn applyForce(self: *RigidBody, force: math.Vec3) void {
        if (!self.is_kinematic and self.mass > 0) {
            self.acceleration = math.Vec3.add(
                self.acceleration,
                math.Vec3.scale(force, 1.0 / self.mass),
            );
        }
    }

    /// Apply impulse to rigid body (instant velocity change)
    pub fn applyImpulse(self: *RigidBody, impulse: math.Vec3) void {
        if (!self.is_kinematic) {
            self.velocity = math.Vec3.add(self.velocity, impulse);
        }
    }

    /// Update physics for this body
    pub fn integrate(self: *RigidBody, dt: f32) math.Vec3 {
        if (self.is_kinematic) {
            return self.velocity;
        }

        // Apply gravity
        var gravity = math.Vec3.init(0, Config.GRAVITY * self.gravity_scale, 0);
        self.velocity = math.Vec3.add(self.velocity, math.Vec3.scale(gravity, dt));

        // Apply drag
        const friction = if (self.is_grounded) Config.GROUND_FRICTION else Config.AIR_FRICTION;
        const horizontal_vel = math.Vec3.init(self.velocity.x(), 0, self.velocity.z());
        const friction_force = math.Vec3.scale(horizontal_vel, -friction * dt);
        self.velocity = math.Vec3.add(self.velocity, friction_force);

        // Apply custom acceleration
        self.velocity = math.Vec3.add(self.velocity, math.Vec3.scale(self.acceleration, dt));

        // Clamp to terminal velocity
        if (self.velocity.y() < Config.TERMINAL_VELOCITY) {
            self.velocity.data[1] = Config.TERMINAL_VELOCITY;
        }

        // Clear acceleration for next frame
        self.acceleration = math.Vec3.ZERO;

        return math.Vec3.scale(self.velocity, dt);
    }
};

/// Collider component
pub const Collider = struct {
    shape: Shape,
    offset: math.Vec3 = math.Vec3.ZERO,
    is_trigger: bool = false,

    pub const Shape = union(enum) {
        box: math.Vec3, // half-extents
        sphere: f32, // radius
    };

    /// Get AABB for this collider at given position
    pub fn getAABB(self: Collider, position: math.Vec3) AABB {
        const center = math.Vec3.add(position, self.offset);
        return switch (self.shape) {
            .box => |half_extents| AABB.fromCenterExtents(center, half_extents),
            .sphere => |radius| AABB.fromCenterExtents(center, math.Vec3.init(radius, radius, radius)),
        };
    }

    /// Create a box collider
    pub fn box(half_extents: math.Vec3) Collider {
        return .{ .shape = .{ .box = half_extents } };
    }

    /// Create a sphere collider
    pub fn sphere(radius: f32) Collider {
        return .{ .shape = .{ .sphere = radius } };
    }

    /// Default player collider
    pub fn player() Collider {
        return Collider.box(math.Vec3.init(
            Config.PLAYER_WIDTH * 0.5,
            Config.PLAYER_HEIGHT * 0.5,
            Config.PLAYER_WIDTH * 0.5,
        ));
    }
};

/// Physics world for managing simulations
pub const PhysicsWorld = struct {
    allocator: std.mem.Allocator,
    gravity: math.Vec3,
    static_colliders: std.ArrayListUnmanaged(StaticCollider),

    pub const StaticCollider = struct {
        aabb: AABB,
        data: ?*anyopaque = null,
    };

    pub fn init(allocator: std.mem.Allocator) PhysicsWorld {
        return .{
            .allocator = allocator,
            .gravity = math.Vec3.init(0, Config.GRAVITY, 0),
            .static_colliders = .{},
        };
    }

    pub fn deinit(self: *PhysicsWorld) void {
        self.static_colliders.deinit(self.allocator);
    }

    /// Add a static collider (e.g., block)
    pub fn addStaticCollider(self: *PhysicsWorld, aabb: AABB) !void {
        try self.static_colliders.append(self.allocator, .{ .aabb = aabb });
    }

    /// Clear all static colliders
    pub fn clearStaticColliders(self: *PhysicsWorld) void {
        self.static_colliders.clearRetainingCapacity();
    }

    /// Move an entity with collision resolution
    /// Returns the actual movement applied
    pub fn moveAndSlide(
        self: *PhysicsWorld,
        position: math.Vec3,
        collider: Collider,
        velocity: math.Vec3,
        dt: f32,
    ) struct { position: math.Vec3, grounded: bool, velocity: math.Vec3 } {
        var new_pos = position;
        var new_vel = velocity;
        var grounded = false;

        // Move on each axis separately for better collision response
        const movement = math.Vec3.scale(velocity, dt);

        // Y-axis first (gravity)
        new_pos.data[1] += movement.y();
        const y_aabb = collider.getAABB(new_pos);

        for (self.static_colliders.items) |static| {
            if (y_aabb.intersects(static.aabb)) {
                if (const info = collision.resolveAABBCollision(y_aabb, static.aabb)) |col| {
                    if (col.normal.y() > 0.5) {
                        // Hit ground
                        grounded = true;
                        new_vel.data[1] = 0;
                    } else if (col.normal.y() < -0.5) {
                        // Hit ceiling
                        new_vel.data[1] = 0;
                    }
                    new_pos.data[1] += col.normal.y() * col.depth;
                }
            }
        }

        // X-axis
        new_pos.data[0] += movement.x();
        const x_aabb = collider.getAABB(new_pos);

        for (self.static_colliders.items) |static| {
            if (x_aabb.intersects(static.aabb)) {
                if (const info = collision.resolveAABBCollision(x_aabb, static.aabb)) |col| {
                    if (@abs(col.normal.x()) > 0.5) {
                        new_vel.data[0] = 0;
                        new_pos.data[0] += col.normal.x() * col.depth;
                    }
                }
            }
        }

        // Z-axis
        new_pos.data[2] += movement.z();
        const z_aabb = collider.getAABB(new_pos);

        for (self.static_colliders.items) |static| {
            if (z_aabb.intersects(static.aabb)) {
                if (const info = collision.resolveAABBCollision(z_aabb, static.aabb)) |col| {
                    if (@abs(col.normal.z()) > 0.5) {
                        new_vel.data[2] = 0;
                        new_pos.data[2] += col.normal.z() * col.depth;
                    }
                }
            }
        }

        return .{
            .position = new_pos,
            .grounded = grounded,
            .velocity = new_vel,
        };
    }

    /// Raycast against all static colliders
    pub fn raycast(self: *PhysicsWorld, ray: Ray, max_distance: f32) ?RaycastHit {
        var closest_hit: ?RaycastHit = null;
        var closest_dist = max_distance;

        for (self.static_colliders.items) |static| {
            if (rayVsAABB(ray, static.aabb)) |hit| {
                if (hit.distance < closest_dist) {
                    closest_dist = hit.distance;
                    closest_hit = hit;
                }
            }
        }

        return closest_hit;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "rigid body integration" {
    var rb = RigidBody{};
    rb.velocity = math.Vec3.init(10, 0, 0);

    const delta = rb.integrate(1.0 / 60.0);
    try std.testing.expect(delta.x() > 0);
    try std.testing.expect(rb.velocity.y() < 0); // Gravity applied
}

test "collider AABB" {
    const col = Collider.box(math.Vec3.init(0.5, 1.0, 0.5));
    const aabb = col.getAABB(math.Vec3.init(0, 0, 0));

    try std.testing.expectApproxEqAbs(@as(f32, -0.5), aabb.min.x(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), aabb.max.x(), 0.001);
}
