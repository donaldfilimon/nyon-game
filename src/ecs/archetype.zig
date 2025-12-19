//! Entity Component System (ECS) - Archetype Storage
//!
//! This module implements archetype-based storage for efficient component access.
//! Archetypes group entities that have the same set of components, enabling
//! cache-friendly iteration and fast component lookups.

const std = @import("std");
const entity = @import("entity.zig");
const component = @import("component.zig");

/// Unique identifier for archetypes
pub const ArchetypeId = u32;

/// Component type information for archetype matching
pub const ComponentType = struct {
    type_id: usize,
    size: usize,
    alignment: usize,
    name: []const u8,

    pub fn init(comptime T: type) ComponentType {
        return .{
            .type_id = std.hash.Wyhash.hash(0, @typeName(T)),
            .size = @sizeOf(T),
            .alignment = @alignOf(T),
            .name = @typeName(T),
        };
    }
};

/// Archetype storage for entities with the same component layout
pub const Archetype = struct {
    allocator: std.mem.Allocator,
    id: ArchetypeId,
    layout_hash: u64,
    component_types: std.ArrayList(ComponentType),
    entities: std.ArrayList(entity.EntityId),
    component_columns: std.ArrayList([]u8),
    entity_capacity: usize,
    entity_count: usize,

    /// Initialize a new archetype with the given component types
    pub fn init(allocator: std.mem.Allocator, component_types: []const ComponentType, initial_capacity: usize) !Archetype {
        var archetype = Archetype{
            .allocator = allocator,
            .id = 0, // Assigned by World
            .layout_hash = 0,
            .component_types = std.ArrayList(ComponentType).initCapacity(allocator, component_types.len) catch return error.OutOfMemory,
            .entities = std.ArrayList(entity.EntityId).initCapacity(allocator, initial_capacity) catch return error.OutOfMemory,
            .component_columns = std.ArrayList([]u8).initCapacity(allocator, component_types.len) catch return error.OutOfMemory,
            .entity_capacity = initial_capacity,
            .entity_count = 0,
        };

        // Copy component types and calculate layout hash
        for (component_types) |comp_type| {
            archetype.component_types.appendAssumeCapacity(comp_type);
            archetype.layout_hash ^= std.hash.Wyhash.hash(0, comp_type.name);
        }

        // Sort component types for consistent ordering
        std.sort.pdq(ComponentType, archetype.component_types.items, {}, struct {
            fn lessThan(_: void, a: ComponentType, b: ComponentType) bool {
                return a.type_id < b.type_id;
            }
        }.lessThan);

        // Allocate component columns
        for (component_types) |comp_type| {
            const column_size = comp_type.size * initial_capacity;
            // Use maximum alignment for simplicity (could be optimized per component)
            const column = try allocator.alignedAlloc(u8, null, column_size);
            archetype.component_columns.appendAssumeCapacity(column);
        }

        return archetype;
    }

    /// Deinitialize the archetype and free all memory
    pub fn deinit(self: *Archetype) void {
        // Free component columns
        for (self.component_columns.items) |column| {
            self.allocator.free(column);
        }
        self.component_columns.deinit(self.allocator);

        self.entities.deinit(self.allocator);
        self.component_types.deinit(self.allocator);
    }

    /// Add an entity to this archetype with default component values
    pub fn addEntity(self: *Archetype, entity_id: entity.EntityId) !void {
        // Ensure we have capacity
        if (self.entity_count >= self.entity_capacity) {
            try self.growCapacity();
        }

        // Add entity
        self.entities.appendAssumeCapacity(entity_id);
        self.entity_count += 1;

        // Initialize components with default values
        for (self.component_types.items, 0..) |comp_type, i| {
            const column = self.component_columns.items[i];
            const component_offset = comp_type.size * (self.entity_count - 1);

            // Zero initialize (most components have reasonable zero defaults)
            // Use a loop since @memset requires comptime size
            var j: usize = 0;
            while (j < comp_type.size) : (j += 1) {
                column[component_offset + j] = 0;
            }
        }
    }

    /// Remove an entity from this archetype
    pub fn removeEntity(self: *Archetype, entity_id: entity.EntityId) ?usize {
        // Find entity index
        for (self.entities.items, 0..) |entity_in_archetype, i| {
            if (entity_in_archetype.eql(entity_id)) {
                return self.removeEntityAtIndex(i);
            }
        }
        return null;
    }

    /// Remove entity at the given index (used internally for efficiency)
    pub fn removeEntityAtIndex(self: *Archetype, index: usize) usize {
        std.debug.assert(index < self.entity_count);

        const last_index = self.entity_count - 1;

        if (index != last_index) {
            // Move last entity to fill the gap
            self.entities.items[index] = self.entities.items[last_index];

            // Move component data
            for (self.component_columns.items, 0..) |column, comp_i| {
                const comp_size = self.component_types.items[comp_i].size;
                const src_offset = comp_size * last_index;
                const dst_offset = comp_size * index;

                @memcpy(column[dst_offset .. dst_offset + comp_size], column[src_offset .. src_offset + comp_size]);
            }
        }

        // Remove last entity
        _ = self.entities.pop();
        self.entity_count -= 1;

        return index;
    }

    /// Get a pointer to a component for the given entity
    pub fn getComponent(self: *Archetype, entity_id: entity.EntityId, comptime T: type) ?*T {
        // Find entity index
        for (self.entities.items, 0..) |entity_in_archetype, i| {
            if (entity_in_archetype.eql(entity_id)) {
                return self.getComponentAtIndex(T, i);
            }
        }
        return null;
    }

    /// Get a pointer to a component at the given entity index
    pub fn getComponentAtIndex(self: *Archetype, comptime T: type, entity_index: usize) ?*T {
        std.debug.assert(entity_index < self.entity_count);

        // Find component column
        const comp_type_info = ComponentType.init(T);
        for (self.component_types.items, 0..) |comp_type, i| {
            if (comp_type.type_id == comp_type_info.type_id) {
                const column = self.component_columns.items[i];
                const component_offset = comp_type.size * entity_index;
                return @as(*T, @ptrCast(@alignCast(&column[component_offset])));
            }
        }
        return null;
    }

    /// Set a component value for the given entity
    pub fn setComponent(self: *Archetype, entity_id: entity.EntityId, value: anytype) bool {
        // Find entity index
        for (self.entities.items, 0..) |entity_in_archetype, i| {
            if (entity_in_archetype.eql(entity_id)) {
                return self.setComponentAtIndex(i, value);
            }
        }
        return false;
    }

    /// Set a component value at the given entity index
    pub fn setComponentAtIndex(self: *Archetype, entity_index: usize, value: anytype) bool {
        std.debug.assert(entity_index < self.entity_count);

        const T = @TypeOf(value);
        const comp_type_info = ComponentType.init(T);

        // Find component column
        for (self.component_types.items, 0..) |comp_type, i| {
            if (comp_type.type_id == comp_type_info.type_id) {
                const column = self.component_columns.items[i];
                const component_offset = comp_type.size * entity_index;
                const component_ptr = @as(*T, @ptrCast(@alignCast(&column[component_offset])));
                component_ptr.* = value;
                return true;
            }
        }
        return false;
    }

    /// Check if this archetype contains the given component type
    pub fn hasComponent(self: *const Archetype, comptime T: type) bool {
        const comp_type_info = ComponentType.init(T);
        for (self.component_types.items) |comp_type| {
            if (comp_type.type_id == comp_type_info.type_id) {
                return true;
            }
        }
        return false;
    }

    /// Check if this archetype matches the given component layout
    pub fn matchesLayout(self: *const Archetype, component_types: []const ComponentType) bool {
        if (self.component_types.items.len != component_types.len) {
            return false;
        }

        // Check each component type
        for (component_types) |required_type| {
            var found = false;
            for (self.component_types.items) |archetype_type| {
                if (archetype_type.type_id == required_type.type_id) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                return false;
            }
        }

        return true;
    }

    /// Grow the capacity of this archetype
    fn growCapacity(self: *Archetype) !void {
        const new_capacity = self.entity_capacity * 2;

        // Grow entities array
        try self.entities.resize(self.allocator, new_capacity);

        // Grow component columns
        for (self.component_columns.items, 0..) |*column, i| {
            const comp_type = self.component_types.items[i];
            const new_column_size = comp_type.size * new_capacity;
            const new_column = try self.allocator.alignedAlloc(u8, null, new_column_size);

            // Copy existing data
            @memcpy(new_column[0..column.len], column.*);

            // Free old column and update
            self.allocator.free(column.*);
            column.* = new_column;
        }

        self.entity_capacity = new_capacity;
    }

    /// Get the number of entities in this archetype
    pub fn entityCount(self: *const Archetype) usize {
        return self.entity_count;
    }

    /// Get the capacity of this archetype
    pub fn capacity(self: *const Archetype) usize {
        return self.entity_capacity;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "archetype creation and entity management" {
    const allocator = std.testing.allocator;

    // Create component types
    const component_types = [_]ComponentType{
        ComponentType.init(component.Position),
        ComponentType.init(component.Rotation),
    };

    var archetype = try Archetype.init(allocator, &component_types, 4);
    defer archetype.deinit();

    try std.testing.expect(archetype.entityCount() == 0);
    try std.testing.expect(archetype.capacity() == 4);

    // Add entities
    const entity1 = entity.EntityId.init(1, 0);
    const entity2 = entity.EntityId.init(2, 0);

    try archetype.addEntity(entity1);
    try archetype.addEntity(entity2);

    try std.testing.expect(archetype.entityCount() == 2);
    try std.testing.expect(archetype.hasComponent(component.Position));
    try std.testing.expect(archetype.hasComponent(component.Rotation));
    try std.testing.expect(!archetype.hasComponent(component.Scale));

    // Test component access
    if (archetype.getComponent(entity1, component.Position)) |pos| {
        pos.* = component.Position.init(1, 2, 3);
        try std.testing.expect(pos.x == 1);
        try std.testing.expect(pos.y == 2);
        try std.testing.expect(pos.z == 3);
    } else {
        try std.testing.expect(false); // Should have found component
    }

    // Remove entity
    if (archetype.removeEntity(entity1)) |removed_index| {
        try std.testing.expect(removed_index < archetype.entityCount() + 1);
    }
    try std.testing.expect(archetype.entityCount() == 1);
}

test "archetype layout matching" {
    const allocator = std.testing.allocator;

    const component_types = [_]ComponentType{
        ComponentType.init(component.Position),
        ComponentType.init(component.Rotation),
    };

    var archetype = try Archetype.init(allocator, &component_types, 4);
    defer archetype.deinit();

    // Should match same layout
    try std.testing.expect(archetype.matchesLayout(&component_types));

    // Should not match different layout
    const different_types = [_]ComponentType{
        ComponentType.init(component.Position),
        ComponentType.init(component.Scale),
    };
    try std.testing.expect(!archetype.matchesLayout(&different_types));
}
