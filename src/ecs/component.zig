//! Built-in ECS components

const std = @import("std");
const math = @import("../math/math.zig");

/// 3D Transform component
pub const Transform = struct {
    position: math.Vec3 = math.Vec3.ZERO,
    rotation: math.Quat = math.Quat.IDENTITY,
    scale: math.Vec3 = math.Vec3.ONE,

    pub fn matrix(self: Transform) math.Mat4 {
        const t = math.Mat4.translation(self.position);
        const r = self.rotation.toMat4();
        const s = math.Mat4.scaling(self.scale);
        return math.Mat4.mul(math.Mat4.mul(t, r), s);
    }

    pub fn forward(self: Transform) math.Vec3 {
        return self.rotation.rotateVec3(math.Vec3.FORWARD);
    }

    pub fn right(self: Transform) math.Vec3 {
        return self.rotation.rotateVec3(math.Vec3.RIGHT);
    }

    pub fn up(self: Transform) math.Vec3 {
        return self.rotation.rotateVec3(math.Vec3.UP);
    }
};

/// Velocity component for physics
pub const Velocity = struct {
    linear: math.Vec3 = math.Vec3.ZERO,
    angular: math.Vec3 = math.Vec3.ZERO,
};

/// Renderable component
pub const Renderable = struct {
    mesh_id: u32 = 0,
    material_id: u32 = 0,
    visible: bool = true,
    cast_shadows: bool = true,
    receive_shadows: bool = true,
};

/// Camera component
pub const Camera = struct {
    fov: f32 = 60.0,
    near: f32 = 0.1,
    far: f32 = 1000.0,
    is_active: bool = false,
    projection: Projection = .perspective,

    pub const Projection = enum { perspective, orthographic };

    pub fn projectionMatrix(self: Camera, aspect: f32) math.Mat4 {
        return switch (self.projection) {
            .perspective => math.Mat4.perspective(
                math.radians(self.fov),
                aspect,
                self.near,
                self.far,
            ),
            .orthographic => math.Mat4.orthographic(
                -10,
                10,
                -10,
                10,
                self.near,
                self.far,
            ),
        };
    }
};

/// Light component
pub const Light = struct {
    color: math.Vec3 = math.Vec3.ONE,
    intensity: f32 = 1.0,
    light_type: Type = .point,
    range: f32 = 10.0,
    inner_cone: f32 = 30.0,
    outer_cone: f32 = 45.0,

    pub const Type = enum { directional, point, spot };
};

/// Name component
pub const Name = struct {
    buffer: [64]u8 = undefined,
    len: usize = 0,

    pub fn init(name: []const u8) Name {
        var n = Name{};
        n.set(name);
        return n;
    }

    pub fn set(self: *Name, name: []const u8) void {
        const copy_len = @min(name.len, self.buffer.len);
        @memcpy(self.buffer[0..copy_len], name[0..copy_len]);
        self.len = copy_len;
    }

    pub fn get(self: *const Name) []const u8 {
        return self.buffer[0..self.len];
    }
};

/// Parent-child hierarchy
pub const Parent = struct {
    entity: @import("entity.zig").Entity,
};
