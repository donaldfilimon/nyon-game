//! Entity Component System (ECS) - Main module re-export
//!
//! This module provides a high-performance Entity Component System for the Nyon Game Engine.
//! It uses an archetype-based storage system for cache-friendly iteration and fast component access.

const std = @import("std");

// Core ECS modules
pub const entity = @import("entity.zig");
pub const component = @import("component.zig");
pub const archetype = @import("archetype.zig");
pub const query = @import("query.zig");
pub const world = @import("world.zig");

// Re-export commonly used types
pub const EntityId = entity.EntityId;
pub const World = world.World;
pub const Query = query.Query;
pub const QueryBuilder = query.QueryBuilder;

// Component storage system
pub const ComponentType = archetype.ComponentType;
pub const Archetype = archetype.Archetype;
pub const ArchetypeId = archetype.ArchetypeId;

// Error types
pub const ECSError = error{
    EntityNotAlive,
    ComponentNotFound,
    ArchetypeNotFound,
    InvalidConfiguration,
    OutOfMemory,
    EntityAlreadyHasComponent,
    InvalidComponentType,
};
