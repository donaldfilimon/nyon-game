//! Physics System - Main module re-export
//!
//! This module provides a comprehensive physics simulation system for the Nyon Game Engine.
//! It includes collision detection, rigid body dynamics, and integration with the ECS.

const std = @import("std");

// Physics modules
pub const types = @import("types.zig");
pub const colliders = @import("colliders.zig");
pub const rigidbody = @import("rigidbody.zig");
pub const world = @import("world.zig");
pub const ecs_integration = @import("ecs_integration.zig");

// Re-export commonly used types
pub const PhysicsWorld = world.PhysicsWorld;
pub const RigidBody = rigidbody.RigidBody;
pub const Collider = colliders.Collider;
pub const CollisionShape = colliders.CollisionShape;
pub const Vector3 = types.Vector3;
pub const Quaternion = types.Quaternion;

// Physics constants
pub const GRAVITY: Vector3 = .{ .x = 0, .y = -9.81, .z = 0 };
pub const DEFAULT_FIXED_TIME_STEP: f32 = 1.0 / 60.0;

// Error types
pub const PhysicsError = error{
    InvalidParameters,
    OutOfMemory,
    WorldNotInitialized,
    RigidBodyNotFound,
    InvalidCollisionShape,
    SimulationError,
};
