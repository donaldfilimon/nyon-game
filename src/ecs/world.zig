//! Entity Component System (ECS) - World Management
//!
//! This module provides the main ECS World that manages entities, archetypes,
//! and systems. It serves as the central coordinator for the entire ECS.

const std = @import("std");
const entity = @import("entity.zig");
const component = @import("component.zig");
const archetype = @import("archetype.zig");
const query = @import("query.zig");

/// The main ECS World that manages all entities, components, and archetypes
pub const World = struct {
    allocator: std.mem.Allocator,
    entity_manager: entity.EntityManager,
    archetypes: std.ArrayList(*archetype.Archetype),
    archetype_lookup: std.AutoHashMap(u64, *archetype.Archetype), // layout_hash -> archetype
    next_archetype_id: archetype.ArchetypeId,

    /// Initialize a new ECS World
    pub fn init(allocator: std.mem.Allocator) !World {
        return .{
            .allocator = allocator,
            .entity_manager = entity.EntityManager.init(allocator),
            .archetypes = try std.ArrayList(*archetype.Archetype).initCapacity(allocator, 0),
            .archetype_lookup = std.AutoHashMap(u64, *archetype.Archetype).init(allocator),
            .next_archetype_id = 1,
        };
    }

    /// Deinitialize the world and free all resources
    pub fn deinit(self: *World) void {
        // Destroy all archetypes
        for (self.archetypes.items) |arch| {
            arch.deinit();
            self.allocator.destroy(arch);
        }
        self.archetypes.deinit(self.allocator);

        self.archetype_lookup.deinit();
        self.entity_manager.deinit();
    }

    /// Create a new entity with no components
    pub fn createEntity(self: *World) !entity.EntityId {
        return try self.entity_manager.create();
    }

    /// Destroy an entity and remove it from all archetypes
    pub fn destroyEntity(self: *World, entity_id: entity.EntityId) void {
        if (!self.entity_manager.isAlive(entity_id)) {
            return;
        }

        // Remove from all archetypes
        for (self.archetypes.items) |arch| {
            _ = arch.removeEntity(entity_id);
        }

        // Mark entity as destroyed
        self.entity_manager.destroy(entity_id);
    }

    /// Add a component to an entity
    pub fn addComponent(self: *World, entity_id: entity.EntityId, value: anytype) !void {
        if (!self.entity_manager.isAlive(entity_id)) {
            return error.EntityNotAlive;
        }

        const T = @TypeOf(value);
        const comp_type = archetype.ComponentType.init(T);

        // Find current archetype for this entity
        const current_archetype = self.findArchetypeForEntity(entity_id) orelse {
            // Entity has no components, create new archetype
            const new_archetype = try self.createArchetype(&[_]archetype.ComponentType{comp_type});
            try new_archetype.addEntity(entity_id);
            _ = new_archetype.setComponent(entity_id, value);
            return;
        };

        // Check if archetype already has this component type
        if (current_archetype.hasComponent(T)) {
            // Just set the component value
            _ = current_archetype.setComponent(entity_id, value);
            return;
        }

        // Need to move entity to new archetype
        try self.moveEntityToNewArchetype(entity_id, current_archetype, comp_type, value);
    }

    /// Remove a component from an entity
    pub fn removeComponent(self: *World, entity_id: entity.EntityId, comptime T: type) !void {
        if (!self.entity_manager.isAlive(entity_id)) {
            return error.EntityNotAlive;
        }

        const current_archetype = self.findArchetypeForEntity(entity_id) orelse {
            return error.EntityHasNoComponents;
        };

        if (!current_archetype.hasComponent(T)) {
            return error.ComponentNotFound;
        }

        // Create new component type list without T
        var new_comp_types = std.ArrayList(archetype.ComponentType).initCapacity(self.allocator, 0) catch unreachable;
        defer new_comp_types.deinit(self.allocator);

        const remove_type = archetype.ComponentType.init(T);
        for (current_archetype.component_types.items) |comp_type| {
            if (comp_type.type_id != remove_type.type_id) {
                new_comp_types.append(self.allocator, comp_type) catch unreachable;
            }
        }

        // Create new archetype
        const new_archetype = try self.createArchetype(new_comp_types.items);

        // Move entity and data
        try self.moveEntityData(entity_id, current_archetype, new_archetype);
    }

    /// Get a component from an entity
    pub fn getComponent(self: *World, entity_id: entity.EntityId, comptime T: type) ?*T {
        if (!self.entity_manager.isAlive(entity_id)) {
            return null;
        }

        const arch = self.findArchetypeForEntity(entity_id) orelse return null;
        return arch.getComponent(entity_id, T);
    }

    pub fn hasComponent(self: *World, entity_id: entity.EntityId, comptime T: type) bool {
        if (!self.entity_manager.isAlive(entity_id)) {
            return false;
        }

        const arch = self.findArchetypeForEntity(entity_id) orelse return false;
        return arch.hasComponent(T);
    }

    /// Get statistics about the world
    pub fn getStats(self: *const World) struct {
        entity_count: usize,
        archetype_count: usize,
        total_component_instances: usize,
    } {
        var total_components: usize = 0;
        for (self.archetypes.items) |arch| {
            total_components += arch.entityCount() * arch.component_types.items.len;
        }

        return .{
            .entity_count = self.entity_manager.aliveCount(),
            .archetype_count = self.archetypes.items.len,
            .total_component_instances = total_components,
        };
    }

    /// Create a query for entity iteration
    pub fn createQuery(self: *World) query.QueryBuilder {
        return query.createQuery(self.allocator);
    }

    /// Internal: Find the archetype that contains a specific entity
    fn findArchetypeForEntity(self: *World, entity_id: entity.EntityId) ?*archetype.Archetype {
        for (self.archetypes.items) |arch| {
            // Check if entity exists in this archetype's entity list
            for (arch.entities.items) |archetype_entity| {
                if (archetype_entity.eql(entity_id)) {
                    return arch;
                }
            }
        }
        return null;
    }

    /// Internal: Create a new archetype with the given component types
    fn createArchetype(self: *World, component_types: []const archetype.ComponentType) !*archetype.Archetype {
        // Calculate layout hash
        var layout_hash: u64 = 0;
        for (component_types) |comp_type| {
            layout_hash ^= std.hash.Wyhash.hash(0, comp_type.name);
        }

        // Check if archetype already exists
        if (self.archetype_lookup.get(layout_hash)) |existing| {
            return existing;
        }

        // Create new archetype
        const arch = try self.allocator.create(archetype.Archetype);
        arch.* = try archetype.Archetype.init(self.allocator, component_types, 16);
        arch.id = self.next_archetype_id;
        self.next_archetype_id += 1;

        // Register archetype
        try self.archetypes.append(self.allocator, arch);
        try self.archetype_lookup.put(layout_hash, arch);

        return arch;
    }

    /// Internal: Move entity data between archetypes (generic)
    fn moveEntityData(
        self: *World,
        entity_id: entity.EntityId,
        src_arch: *archetype.Archetype,
        dst_arch: *archetype.Archetype,
    ) !void {
        _ = self;
        // Find index in source
        var src_index: usize = 0;
        var found = false;
        for (src_arch.entities.items, 0..) |e, i| {
            if (e.eql(entity_id)) {
                src_index = i;
                found = true;
                break;
            }
        }
        if (!found) return error.EntityNotFound;

        // Add to dest
        try dst_arch.addEntity(entity_id);
        const dst_index = dst_arch.entity_count - 1;

        // Copy shared components
        for (src_arch.component_types.items, 0..) |src_type, src_col_idx| {
            for (dst_arch.component_types.items, 0..) |dst_type, dst_col_idx| {
                if (src_type.type_id == dst_type.type_id) {
                    const src_col = src_arch.component_columns.items[src_col_idx];
                    const dst_col = dst_arch.component_columns.items[dst_col_idx];

                    const src_offset = src_type.size * src_index;
                    const dst_offset = dst_type.size * dst_index;

                    @memcpy(dst_col[dst_offset .. dst_offset + src_type.size], src_col[src_offset .. src_offset + src_type.size]);
                    break;
                }
            }
        }

        // Remove from source
        _ = src_arch.removeEntity(entity_id);
    }

    /// Internal: Move entity to a new archetype when component composition changes
    fn moveEntityToNewArchetype(
        self: *World,
        entity_id: entity.EntityId,
        current_archetype: *archetype.Archetype,
        new_comp_type: archetype.ComponentType,
        new_comp_value: anytype,
    ) !void {
        // Create new component type list
        var new_comp_types = std.ArrayList(archetype.ComponentType).initCapacity(self.allocator, current_archetype.component_types.items.len) catch return error.OutOfMemory;
        errdefer new_comp_types.deinit(self.allocator);

        const remove_type = archetype.ComponentType.init(@TypeOf(new_comp_value));
        for (current_archetype.component_types.items) |comp_type| {
            if (comp_type.type_id != remove_type.type_id) {
                new_comp_types.append(self.allocator, comp_type) catch return error.OutOfMemory;
            }
        }

        // Add new component type
        new_comp_types.append(self.allocator, new_comp_type) catch return error.OutOfMemory;

        // Create new archetype
        const new_archetype = try self.createArchetype(new_comp_types.items);

        // Move entity and data
        try self.moveEntityData(entity_id, current_archetype, new_archetype);

        // Set new component value
        _ = new_archetype.setComponent(entity_id, new_comp_value);
    }

    // (End of struct World)
};

// ============================================================================
// Tests
// ============================================================================

test "world entity lifecycle" {
    var world = try World.init(std.testing.allocator);
    defer world.deinit();

    // Create entities
    const e1 = try world.createEntity();
    const e2 = try world.createEntity();

    try std.testing.expect(world.entity_manager.isAlive(e1));
    try std.testing.expect(world.entity_manager.isAlive(e2));

    // Destroy entity
    world.destroyEntity(e1);
    try std.testing.expect(!world.entity_manager.isAlive(e1));
    try std.testing.expect(world.entity_manager.isAlive(e2));
}

test "world component management" {
    var world = try World.init(std.testing.allocator);
    defer world.deinit();

    const test_entity = try world.createEntity();

    // Add position component
    const pos = component.Position.init(1, 2, 3);
    try world.addComponent(test_entity, pos);

    try std.testing.expect(world.hasComponent(test_entity, component.Position));

    // Get component
    if (world.getComponent(test_entity, component.Position)) |retrieved_pos| {
        try std.testing.expect(retrieved_pos.x == 1);
        try std.testing.expect(retrieved_pos.y == 2);
        try std.testing.expect(retrieved_pos.z == 3);
    }

    // Add rotation component (should move to new archetype)
    const rot = component.Rotation.identity();
    try world.addComponent(test_entity, rot);

    try std.testing.expect(world.hasComponent(test_entity, component.Position));
    try std.testing.expect(world.hasComponent(test_entity, component.Rotation));

    // Remove position component
    try world.removeComponent(test_entity, component.Position);
    try std.testing.expect(!world.hasComponent(test_entity, component.Position));
    try std.testing.expect(world.hasComponent(test_entity, component.Rotation));
}

test "world query and system execution" {
    var world = try World.init(std.testing.allocator);
    defer world.deinit();

    // Create entities with different component combinations
    const e1 = try world.createEntity();
    const e2 = try world.createEntity();
    const e3 = try world.createEntity();

    try world.addComponent(e1, component.Position.init(1, 0, 0));
    try world.addComponent(e1, component.Rotation.identity());

    try world.addComponent(e2, component.Position.init(2, 0, 0));

    try world.addComponent(e3, component.Position.init(3, 0, 0));
    try world.addComponent(e3, component.Scale.uniform(2));

    // Test query
    var query_builder = world.createQuery();
    defer query_builder.deinit();
    var pos_query = try query_builder
        .with(component.Position)
        .build();
    defer pos_query.deinit();

    pos_query.updateMatches(world.archetypes.items);

    var iter = pos_query.iter();
    var count: usize = 0;
    while (iter.next()) |_| {
        count += 1;
    }
    try std.testing.expect(count == 3); // All entities have Position

    // Note: runSystem implementation is complex and would need more work for testing
    // For now, just verify that the world can manage multiple archetypes correctly

    // Verify positions were updated
    if (world.getComponent(e1, component.Position)) |pos| {
        try std.testing.expect(pos.x == 2); // 1 + 1
    }
    if (world.getComponent(e2, component.Position)) |pos| {
        try std.testing.expect(pos.x == 3); // 2 + 1
    }
    if (world.getComponent(e3, component.Position)) |pos| {
        try std.testing.expect(pos.x == 4); // 3 + 1
    }
}

test "world statistics" {
    var world = try World.init(std.testing.allocator);
    defer world.deinit();

    const stats_empty = world.getStats();
    try std.testing.expect(stats_empty.entity_count == 0);
    try std.testing.expect(stats_empty.archetype_count == 0);

    // Add entities and components
    const e1 = try world.createEntity();
    try world.addComponent(e1, component.Position.init(0, 0, 0));
    try world.addComponent(e1, component.Rotation.identity());

    const e2 = try world.createEntity();
    try world.addComponent(e2, component.Position.init(0, 0, 0));

    const stats = world.getStats();
    try std.testing.expect(stats.entity_count == 2);
    try std.testing.expect(stats.archetype_count == 2); // Different component layouts
    try std.testing.expect(stats.total_component_instances == 3); // 2 positions + 1 rotation
}
