//! Entity-Component-System (ECS)
//!
//! A cache-friendly archetype-based ECS implementation.

const std = @import("std");

pub const Entity = @import("entity.zig").Entity;
pub const World = @import("world.zig").World;
pub const Query = @import("query.zig").Query;
pub const component = @import("component.zig");

/// Built-in components
pub const Transform = component.Transform;
pub const Velocity = component.Velocity;
pub const Renderable = component.Renderable;
pub const Camera = component.Camera;
pub const Light = component.Light;
pub const Name = component.Name;

test {
    std.testing.refAllDecls(@This());
}
