//! Entity Component System (ECS) - Component Definitions
//!
//! This module defines the core component types used throughout the Nyon Game Engine.
//! Components are pure data structures that can be attached to entities to give them
//! specific behaviors and properties.

const std = @import("std");
const entity = @import("entity.zig");
const Vec3 = @Vector(3, f32);
const Quat = @Vector(4, f32);

// ============================================================================
// Core Transform Components
// ============================================================================

/// Position component for 3D spatial positioning
pub const Position = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,

    pub fn init(x: f32, y: f32, z: f32) Position {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn fromVec3(v: Vec3) Position {
        return .{ .x = v[0], .y = v[1], .z = v[2] };
    }

    pub fn toVec3(self: Position) Vec3 {
        return .{ self.x, self.y, self.z };
    }
};

/// Rotation component using quaternions for smooth interpolation
pub const Rotation = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    w: f32 = 1,

    pub fn identity() Rotation {
        return .{ .x = 0, .y = 0, .z = 0, .w = 1 };
    }

    pub fn fromEuler(pitch: f32, yaw: f32, roll: f32) Rotation {
        // Convert Euler angles to quaternion
        const cr = @cos(roll * 0.5);
        const sr = @sin(roll * 0.5);
        const cp = @cos(pitch * 0.5);
        const sp = @sin(pitch * 0.5);
        const cy = @cos(yaw * 0.5);
        const sy = @sin(yaw * 0.5);

        return .{
            .w = cr * cp * cy + sr * sp * sy,
            .x = sr * cp * cy - cr * sp * sy,
            .y = cr * sp * cy + sr * cp * sy,
            .z = cr * cp * sy - sr * sp * cy,
        };
    }

    pub fn fromQuat(q: Quat) Rotation {
        return .{ .x = q[0], .y = q[1], .z = q[2], .w = q[3] };
    }

    pub fn toQuat(self: Rotation) Quat {
        return .{ self.x, self.y, self.z, self.w };
    }
};

/// Scale component for non-uniform scaling
pub const Scale = struct {
    x: f32 = 1,
    y: f32 = 1,
    z: f32 = 1,

    pub fn uniform(s: f32) Scale {
        return .{ .x = s, .y = s, .z = s };
    }

    pub fn fromVec3(v: Vec3) Scale {
        return .{ .x = v[0], .y = v[1], .z = v[2] };
    }

    pub fn toVec3(self: Scale) Vec3 {
        return .{ self.x, self.y, self.z };
    }
};

/// Combined transform component for efficiency
pub const Transform = struct {
    position: Position,
    rotation: Rotation,
    scale: Scale,

    pub fn identity() Transform {
        return .{
            .position = .{},
            .rotation = Rotation.identity(),
            .scale = Scale.uniform(1),
        };
    }

    pub fn init(pos: Position, rot: Rotation, scl: Scale) Transform {
        return .{
            .position = pos,
            .rotation = rot,
            .scale = scl,
        };
    }
};

// ============================================================================
// Rendering Components
// ============================================================================

/// Renderable component for basic mesh rendering
pub const Renderable = struct {
    mesh_handle: u64, // Handle to mesh asset
    material_handle: u64, // Handle to material asset
    visible: bool = true,
    cast_shadows: bool = true,
    receive_shadows: bool = true,

    pub fn init(mesh: u64, material: u64) Renderable {
        return .{
            .mesh_handle = mesh,
            .material_handle = material,
        };
    }
};

/// Camera component for view/projection matrices
pub const Camera = struct {
    projection_type: enum { perspective, orthographic } = .perspective,
    fov: f32 = 60.0, // Field of view in degrees (perspective only)
    near: f32 = 0.1, // Near clipping plane
    far: f32 = 1000.0, // Far clipping plane
    aspect_ratio: f32 = 16.0 / 9.0,
    orthographic_size: f32 = 10.0, // Orthographic view size

    pub fn perspective(fov: f32, aspect: f32, near: f32, far: f32) Camera {
        return .{
            .projection_type = .perspective,
            .fov = fov,
            .aspect_ratio = aspect,
            .near = near,
            .far = far,
        };
    }

    pub fn orthographic(size: f32, near: f32, far: f32) Camera {
        return .{
            .projection_type = .orthographic,
            .orthographic_size = size,
            .near = near,
            .far = far,
        };
    }
};

/// Light component for dynamic lighting
pub const Light = struct {
    light_type: enum { directional, point, spot } = .point,
    color: Vec3 = .{ 1, 1, 1 }, // RGB color
    intensity: f32 = 1.0,
    range: f32 = 10.0, // Point/spot light range
    spot_angle: f32 = 30.0, // Spot light cone angle in degrees
    shadows: bool = true,

    pub fn directional(color: Vec3, intensity: f32) Light {
        return .{
            .light_type = .directional,
            .color = color,
            .intensity = intensity,
        };
    }

    pub fn point(color: Vec3, intensity: f32, range: f32) Light {
        return .{
            .light_type = .point,
            .color = color,
            .intensity = intensity,
            .range = range,
        };
    }

    pub fn spot(color: Vec3, intensity: f32, range: f32, angle: f32) Light {
        return .{
            .light_type = .spot,
            .color = color,
            .intensity = intensity,
            .range = range,
            .spot_angle = angle,
        };
    }
};

// ============================================================================
// Physics Components
// ============================================================================

/// Rigid body component for physics simulation
pub const RigidBody = struct {
    mass: f32 = 1.0,
    linear_velocity: Vec3 = .{ 0, 0, 0 },
    angular_velocity: Vec3 = .{ 0, 0, 0 },
    linear_damping: f32 = 0.0,
    angular_damping: f32 = 0.0,
    is_kinematic: bool = false,
    gravity_scale: f32 = 1.0,
    sleep_threshold: f32 = 0.1,

    pub fn static() RigidBody {
        return .{
            .mass = 0.0, // Infinite mass
            .is_kinematic = true,
        };
    }

    pub fn kinematic(mass: f32) RigidBody {
        return .{
            .mass = mass,
            .is_kinematic = true,
        };
    }

    pub fn dynamic(mass: f32) RigidBody {
        return .{
            .mass = mass,
            .is_kinematic = false,
        };
    }
};

/// Collider component for collision detection
pub const Collider = union(enum) {
    box_collider: struct {
        half_extents: Vec3,
    },
    sphere_collider: struct {
        radius: f32,
    },
    capsule_collider: struct {
        radius: f32,
        height: f32,
    },
    mesh_collider: struct {
        mesh_handle: u64,
    },

    pub fn box(half_width: f32, half_height: f32, half_depth: f32) Collider {
        return .{ .box_collider = .{ .half_extents = .{ half_width, half_height, half_depth } } };
    }

    pub fn sphere(radius: f32) Collider {
        return .{ .sphere_collider = .{ .radius = radius } };
    }

    pub fn capsule(radius: f32, height: f32) Collider {
        return .{ .capsule_collider = .{ .radius = radius, .height = height } };
    }

    pub fn mesh(handle: u64) Collider {
        return .{ .mesh_collider = .{ .mesh_handle = handle } };
    }
};

// ============================================================================
// Audio Components
// ============================================================================

/// Audio source component for 3D spatial audio
pub const AudioSource = struct {
    clip_handle: u64, // Handle to audio clip asset
    volume: f32 = 1.0,
    pitch: f32 = 1.0,
    looping: bool = false,
    spatial_blend: f32 = 1.0, // 0 = 2D, 1 = 3D
    min_distance: f32 = 1.0,
    max_distance: f32 = 100.0,
    playing: bool = false,

    pub fn init(clip: u64) AudioSource {
        return .{ .clip_handle = clip };
    }
};

/// Audio listener component (usually attached to camera)
pub const AudioListener = struct {
    // Usually just a marker component
    // The transform provides position/orientation
};

// ============================================================================
// Input Components
// ============================================================================

/// Input receiver component for handling user input
pub const InputReceiver = struct {
    input_enabled: bool = true,
    input_layer: u32 = 0, // For input priority/layering
};

// ============================================================================
// Utility Components
// ============================================================================

/// Name component for debugging and editor identification
pub const Name = struct {
    value: []const u8,

    pub fn init(name: []const u8) Name {
        return .{ .value = name };
    }
};

/// Tag component for grouping entities
pub const Tag = struct {
    value: []const u8,

    pub fn init(tag: []const u8) Tag {
        return .{ .value = tag };
    }
};

/// Hierarchy component for parent-child relationships
pub const Hierarchy = struct {
    parent: ?entity.EntityId = null,
    first_child: ?entity.EntityId = null,
    next_sibling: ?entity.EntityId = null,
    prev_sibling: ?entity.EntityId = null,
};

// ============================================================================
// Tests
// ============================================================================

test "transform components" {
    const pos = Position.init(1, 2, 3);
    const rot = Rotation.fromEuler(0, 0, 0);
    const scl = Scale.uniform(2);

    const transform = Transform.init(pos, rot, scl);

    try std.testing.expect(transform.position.x == 1);
    try std.testing.expect(transform.position.y == 2);
    try std.testing.expect(transform.position.z == 3);
    try std.testing.expect(transform.scale.x == 2);
    try std.testing.expect(transform.scale.y == 2);
    try std.testing.expect(transform.scale.z == 2);
}

test "camera component" {
    const cam = Camera.perspective(90, 16.0 / 9.0, 0.1, 100);
    try std.testing.expect(cam.projection_type == .perspective);
    try std.testing.expect(cam.fov == 90);
    try std.testing.expect(cam.near == 0.1);
    try std.testing.expect(cam.far == 100);
}

test "light component" {
    const light = Light.point(.{ 1, 1, 1 }, 2.0, 50.0);
    try std.testing.expect(light.light_type == .point);
    try std.testing.expect(light.intensity == 2.0);
    try std.testing.expect(light.range == 50.0);
}
