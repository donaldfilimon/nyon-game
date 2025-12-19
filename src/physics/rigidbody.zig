//! Rigid Body Physics - Core rigid body simulation
//!
//! This module implements rigid body dynamics including mass, velocity,
//! forces, torques, and integration methods for realistic physics simulation.

const std = @import("std");
const types = @import("types.zig");

/// Rigid body state and properties
pub const RigidBody = struct {
    // Static properties
    mass: f32,
    inverse_mass: f32,
    inertia_tensor: types.Mat3,
    inverse_inertia_tensor: types.Mat3,

    // Dynamic state
    position: types.Vector3,
    orientation: types.Quaternion,
    linear_velocity: types.Vector3,
    angular_velocity: types.Vector3,

    // Forces and torques
    force_accumulator: types.Vector3,
    torque_accumulator: types.Vector3,

    // Material properties
    material: types.PhysicsMaterial,

    // Simulation properties
    linear_damping: f32,
    angular_damping: f32,
    gravity_scale: f32,

    // Flags
    is_kinematic: bool,
    is_static: bool,
    sleep_timer: f32,

    /// Create a dynamic rigid body
    pub fn dynamic(mass: f32, position: types.Vector3) RigidBody {
        std.debug.assert(mass > 0);

        const inv_mass = 1.0 / mass;
        const inertia = types.Mat3.identity().mul(mass * 0.1); // Simplified sphere inertia

        return .{
            .mass = mass,
            .inverse_mass = inv_mass,
            .inertia_tensor = inertia,
            .inverse_inertia_tensor = inertia.inverse(),
            .position = position,
            .orientation = types.Quaternion.identity(),
            .linear_velocity = types.Vector3.zero(),
            .angular_velocity = types.Vector3.zero(),
            .force_accumulator = types.Vector3.zero(),
            .torque_accumulator = types.Vector3.zero(),
            .material = types.PhysicsMaterial.default(),
            .linear_damping = 0.99,
            .angular_damping = 0.99,
            .gravity_scale = 1.0,
            .is_kinematic = false,
            .is_static = false,
            .sleep_timer = 0.0,
        };
    }

    /// Create a kinematic rigid body (moved by code, not physics)
    pub fn kinematic(position: types.Vector3) RigidBody {
        return .{
            .mass = 1.0, // Dummy mass
            .inverse_mass = 0.0, // Infinite mass
            .inertia_tensor = types.Mat3.identity(),
            .inverse_inertia_tensor = types.Mat3.zero(),
            .position = position,
            .orientation = types.Quaternion.identity(),
            .linear_velocity = types.Vector3.zero(),
            .angular_velocity = types.Vector3.zero(),
            .force_accumulator = types.Vector3.zero(),
            .torque_accumulator = types.Vector3.zero(),
            .material = types.PhysicsMaterial.default(),
            .linear_damping = 1.0,
            .angular_damping = 1.0,
            .gravity_scale = 0.0,
            .is_kinematic = true,
            .is_static = false,
            .sleep_timer = 0.0,
        };
    }

    /// Create a static rigid body (immovable)
    pub fn static(position: types.Vector3) RigidBody {
        return .{
            .mass = 1.0, // Dummy mass
            .inverse_mass = 0.0, // Infinite mass
            .inertia_tensor = types.Mat3.identity(),
            .inverse_inertia_tensor = types.Mat3.zero(),
            .position = position,
            .orientation = types.Quaternion.identity(),
            .linear_velocity = types.Vector3.zero(),
            .angular_velocity = types.Vector3.zero(),
            .force_accumulator = types.Vector3.zero(),
            .torque_accumulator = types.Vector3.zero(),
            .material = types.PhysicsMaterial.default(),
            .linear_damping = 1.0,
            .angular_damping = 1.0,
            .gravity_scale = 0.0,
            .is_kinematic = false,
            .is_static = true,
            .sleep_timer = 0.0,
        };
    }

    /// Apply a force at the center of mass
    pub fn addForce(self: *RigidBody, force: types.Vector3) void {
        self.force_accumulator = self.force_accumulator.add(force);
        self.sleep_timer = 0.0; // Wake up if sleeping
    }

    /// Apply a force at a specific world point
    pub fn addForceAtPoint(self: *RigidBody, force: types.Vector3, point: types.Vector3) void {
        self.addForce(force);

        // Calculate torque: r × F
        const r = point.sub(self.position);
        const torque = r.cross(force);
        self.addTorque(torque);
    }

    /// Apply a torque (rotational force)
    pub fn addTorque(self: *RigidBody, torque: types.Vector3) void {
        self.torque_accumulator = self.torque_accumulator.add(torque);
        self.sleep_timer = 0.0; // Wake up if sleeping
    }

    /// Clear accumulated forces and torques
    pub fn clearAccumulators(self: *RigidBody) void {
        self.force_accumulator = types.Vector3.zero();
        self.torque_accumulator = types.Vector3.zero();
    }

    /// Integrate physics state using Verlet integration
    pub fn integrate(self: *RigidBody, dt: f32, gravity: types.Vector3) void {
        if (self.is_static or self.is_kinematic) return;

        // Apply gravity
        const gravity_force = gravity.mul(self.mass * self.gravity_scale);
        self.addForce(gravity_force);

        // Calculate acceleration
        const acceleration = self.force_accumulator.mul(self.inverse_mass);

        // Integrate linear velocity
        self.linear_velocity = self.linear_velocity.add(acceleration.mul(dt));
        self.linear_velocity = self.linear_velocity.mul(self.linear_damping);

        // Integrate position
        self.position = self.position.add(self.linear_velocity.mul(dt));

        // Calculate angular acceleration
        const inv_inertia_world = self.getInverseInertiaTensorWorld();
        const angular_acceleration = inv_inertia_world.transform(self.torque_accumulator);

        // Integrate angular velocity
        self.angular_velocity = self.angular_velocity.add(angular_acceleration.mul(dt));
        self.angular_velocity = self.angular_velocity.mul(self.angular_damping);

        // Integrate orientation
        const angular_delta = self.angular_velocity.mul(dt * 0.5);
        const delta_quat = types.Quaternion{
            .x = angular_delta.x,
            .y = angular_delta.y,
            .z = angular_delta.z,
            .w = 0,
        };
        self.orientation = self.orientation.mul(delta_quat).normalize();

        // Clear accumulators for next frame
        self.clearAccumulators();

        // Check if body should sleep
        const velocity_magnitude = self.linear_velocity.length() + self.angular_velocity.length();
        if (velocity_magnitude < 0.1) {
            self.sleep_timer += dt;
        } else {
            self.sleep_timer = 0.0;
        }
    }

    /// Get the inverse inertia tensor in world space
    pub fn getInverseInertiaTensorWorld(self: *const RigidBody) types.Mat3 {
        // For simplicity, assuming axis-aligned inertia tensor
        // In a full implementation, this would transform the tensor by orientation
        return self.inverse_inertia_tensor;
    }

    /// Check if the body is sleeping (not moving)
    pub fn isSleeping(self: *const RigidBody) bool {
        return self.sleep_timer > 1.0; // Sleep after 1 second of low movement
    }

    /// Wake up the body if sleeping
    pub fn wakeUp(self: *RigidBody) void {
        self.sleep_timer = 0.0;
    }

    /// Get the body's axis-aligned bounding box
    pub fn getAABB(self: *const RigidBody, half_extents: types.Vector3) types.AABB {
        return types.AABB.fromCenterExtent(self.position, half_extents);
    }

    /// Set the body's position directly (kinematic use)
    pub fn setPosition(self: *RigidBody, position: types.Vector3) void {
        self.position = position;
        self.wakeUp();
    }

    /// Set the body's orientation directly (kinematic use)
    pub fn setOrientation(self: *RigidBody, orientation: types.Quaternion) void {
        self.orientation = orientation;
        self.wakeUp();
    }

    /// Set linear velocity directly
    pub fn setLinearVelocity(self: *RigidBody, velocity: types.Vector3) void {
        self.linear_velocity = velocity;
        self.wakeUp();
    }

    /// Set angular velocity directly
    pub fn setAngularVelocity(self: *RigidBody, velocity: types.Vector3) void {
        self.angular_velocity = velocity;
        self.wakeUp();
    }
};

// ============================================================================
// 3x3 Matrix for inertia tensors and transformations
// ============================================================================

pub const Mat3 = struct {
    m: [9]f32,

    pub fn identity() Mat3 {
        return .{
            .m = [_]f32{
                1, 0, 0,
                0, 1, 0,
                0, 0, 1,
            },
        };
    }

    pub fn zero() Mat3 {
        return .{
            .m = [_]f32{
                0, 0, 0,
                0, 0, 0,
                0, 0, 0,
            },
        };
    }

    pub fn mul(mat: Mat3, scalar: f32) Mat3 {
        var result = Mat3.zero();
        for (mat.m, 0..) |val, i| {
            result.m[i] = val * scalar;
        }
        return result;
    }

    pub fn transform(mat: Mat3, vec: types.Vector3) types.Vector3 {
        return .{
            .x = mat.m[0] * vec.x + mat.m[1] * vec.y + mat.m[2] * vec.z,
            .y = mat.m[3] * vec.x + mat.m[4] * vec.y + mat.m[5] * vec.z,
            .z = mat.m[6] * vec.x + mat.m[7] * vec.y + mat.m[8] * vec.z,
        };
    }

    pub fn inverse(mat: Mat3) Mat3 {
        // Simplified matrix inversion for diagonal matrices (common for inertia tensors)
        // In a full implementation, this would handle general 3x3 matrix inversion
        var result = Mat3.zero();
        for (0..3) |i| {
            const idx = i * 3 + i;
            if (mat.m[idx] != 0) {
                result.m[idx] = 1.0 / mat.m[idx];
            }
        }
        return result;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "rigid body creation" {
    const body = RigidBody.dynamic(10.0, types.Vector3.init(0, 0, 0));
    try std.testing.expect(body.mass == 10.0);
    try std.testing.expect(body.inverse_mass == 0.1);
    try std.testing.expect(!body.is_static);
    try std.testing.expect(!body.is_kinematic);
}

test "rigid body forces" {
    var body = RigidBody.dynamic(1.0, types.Vector3.zero());
    const initial_force = body.force_accumulator;

    body.addForce(types.Vector3.init(1, 2, 3));
    try std.testing.expect(body.force_accumulator.x == initial_force.x + 1);
    try std.testing.expect(body.force_accumulator.y == initial_force.y + 2);
    try std.testing.expect(body.force_accumulator.z == initial_force.z + 3);
}

test "static and kinematic bodies" {
    const static_body = RigidBody.static(types.Vector3.zero());
    const kinematic_body = RigidBody.kinematic(types.Vector3.zero());

    try std.testing.expect(static_body.is_static);
    try std.testing.expect(!static_body.is_kinematic);
    try std.testing.expect(static_body.inverse_mass == 0.0);

    try std.testing.expect(!kinematic_body.is_static);
    try std.testing.expect(kinematic_body.is_kinematic);
    try std.testing.expect(kinematic_body.inverse_mass == 0.0);
}
