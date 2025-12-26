//! Entity Component System (ECS) - Query System
//!
//! This module provides query system for efficient iteration over entities
//! with specific component combinations. Queries are compiled to work with
//! archetype-based storage for cache-friendly access patterns.

const std = @import("std");
const entity = @import("entity.zig");
const component = @import("component.zig");
const archetype = @import("archetype.zig");

/// Query builder for constructing entity queries
pub fn queryBuilder(allocator: std.mem.Allocator) QueryBuilder {
    return QueryBuilder.init(allocator);
}

/// Query builder for constructing entity queries
pub const QueryBuilder = struct {
    allocator: std.mem.Allocator,
    include_types: std.ArrayList(archetype.ComponentType),
    exclude_types: std.ArrayList(archetype.ComponentType),

    pub fn init(allocator: std.mem.Allocator) QueryBuilder {
        return .{
            .allocator = allocator,
            .include_types = std.ArrayList(archetype.ComponentType).initCapacity(allocator, 0) catch unreachable,
            .exclude_types = std.ArrayList(archetype.ComponentType).initCapacity(allocator, 0) catch unreachable,
        };
    }

    pub fn deinit(self: *QueryBuilder) void {
        self.include_types.deinit(self.allocator);
        self.exclude_types.deinit(self.allocator);
    }

    /// Include entities that have this component type
    pub fn with(self: *QueryBuilder, comptime T: type) *QueryBuilder {
        self.include_types.append(self.allocator, archetype.ComponentType.init(T)) catch unreachable;
        return self;
    }

    /// Exclude entities that have this component type
    pub fn without(self: *QueryBuilder, comptime T: type) *QueryBuilder {
        self.exclude_types.append(self.allocator, archetype.ComponentType.init(T)) catch unreachable;
        return self;
    }

    /// Build a query
    pub fn build(self: *QueryBuilder) !Query {
        return Query.init(self.allocator, self.include_types.items, self.exclude_types.items);
    }
};

/// Entity data structure for query results
pub const EntityData = struct {
    entity: entity.EntityId,
    archetype: *archetype.Archetype,
    entity_index: usize,

    /// Get a component from this entity
    pub fn get(self: EntityData, comptime T: type) ?*T {
        return self.archetype.getComponentAtIndex(T, self.entity_index);
    }

    /// Set a component on this entity
    pub fn set(self: EntityData, value: anytype) bool {
        return self.archetype.setComponentAtIndex(self.entity_index, value);
    }
};

/// Compiled query for efficient entity iteration
pub const Query = struct {
    allocator: std.mem.Allocator,
    include_types: []archetype.ComponentType,
    exclude_types: []archetype.ComponentType,
    matching_archetypes: std.ArrayList(*archetype.Archetype),
    is_cached: bool = false,
    last_update_frame: u64 = 0,
    cached_entity_count: usize = 0,

    /// Initialize a query with include/exclude component types
    pub fn init(allocator: std.mem.Allocator, include_types: []const archetype.ComponentType, exclude_types: []const archetype.ComponentType) !Query {
        const query = Query{
            .allocator = allocator,
            .include_types = try allocator.dupe(archetype.ComponentType, include_types),
            .exclude_types = try allocator.dupe(archetype.ComponentType, exclude_types),
            .matching_archetypes = std.ArrayList(*archetype.Archetype).initCapacity(allocator, 0) catch unreachable,
        };

        return query;
    }

    /// Enable query caching for performance
    pub fn enableCaching(self: *Query) void {
        self.is_cached = true;
    }

    /// Disable query caching (always update matches)
    pub fn disableCaching(self: *Query) void {
        self.is_cached = false;
    }

    /// Get total entity count from cached query results
    pub fn getEntityCount(self: *Query) usize {
        if (!self.is_cached) return 0;
        return self.cached_entity_count;
    }

    /// Deinitialize the query with proper cleanup
    pub fn deinit(self: *Query) void {
        // Free allocated arrays
        if (self.include_types.len > 0) {
            self.allocator.free(self.include_types);
        }
        if (self.exclude_types.len > 0) {
            self.allocator.free(self.exclude_types);
        }

        // Deinitialize the dynamic array
        self.matching_archetypes.deinit(self.allocator);
    }

    /// Update query with current archetypes from the world
    pub fn updateMatches(self: *Query, archetypes: []*archetype.Archetype) void {
        self.matching_archetypes.clearRetainingCapacity();

        for (archetypes) |arch_ptr| {
            if (self.matchesArchetype(arch_ptr)) {
                self.matching_archetypes.append(self.allocator, arch_ptr) catch unreachable;
            }
        }
    }

    /// Check if an archetype matches this query
    pub fn matchesArchetype(self: *const Query, arch: *const archetype.Archetype) bool {
        // Check include types (all must be present)
        for (self.include_types) |include_type| {
            var found = false;
            for (arch.component_types.items) |arch_type| {
                if (arch_type.type_id == include_type.type_id) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                return false;
            }
        }

        // Check exclude types (none must be present)
        for (self.exclude_types) |exclude_type| {
            for (arch.component_types.items) |arch_type| {
                if (arch_type.type_id == exclude_type.type_id) {
                    return false;
                }
            }
        }

        return true;
    }

    /// Get an iterator over matching entities
    pub fn iter(self: *const Query) Iterator {
        return Iterator.init(self.matching_archetypes.items);
    }

    /// Iterator for traversing query results
    pub const Iterator = struct {
        archetypes: []*archetype.Archetype,
        current_archetype: usize,
        current_entity: usize,

        pub fn init(archetypes: []*archetype.Archetype) Iterator {
            return .{
                .archetypes = archetypes,
                .current_archetype = 0,
                .current_entity = 0,
            };
        }

        /// Get the next entity and its components
        pub fn next(self: *Iterator) ?EntityData {
            while (self.current_archetype < self.archetypes.len) {
                const arch = self.archetypes[self.current_archetype];

                if (self.current_entity < arch.entityCount()) {
                    const entity_id = arch.entities.items[self.current_entity];
                    self.current_entity += 1;
                    return EntityData{
                        .entity = entity_id,
                        .archetype = arch,
                        .entity_index = self.current_entity - 1,
                    };
                } else {
                    // Move to next archetype
                    self.current_archetype += 1;
                    self.current_entity = 0;
                }
            }

            return null;
        }
    };
};

// ============================================================================
// Query Batching System
// ============================================================================

/// Batch query manager for running multiple queries efficiently
pub const QueryBatch = struct {
    allocator: std.mem.Allocator,
    queries: std.ArrayList(*Query),
    entity_data_buffer: std.ArrayList(EntityData),
    frame_count: u64 = 0,

    pub fn init(allocator: std.mem.Allocator) QueryBatch {
        return .{
            .allocator = allocator,
            .queries = std.ArrayList(*Query).initCapacity(allocator, 0) catch unreachable,
            .entity_data_buffer = std.ArrayList(EntityData).initCapacity(allocator, 0) catch unreachable,
        };
    }

    pub fn deinit(self: *QueryBatch) void {
        self.queries.deinit(self.allocator);
        self.entity_data_buffer.deinit(self.allocator);
    }

    /// Add a query to the batch
    pub fn addQuery(self: *QueryBatch, query: *Query) !void {
        try self.queries.append(self.allocator, query);
    }

    /// Update all queries in the batch (cached queries skip update)
    pub fn updateAll(self: *QueryBatch, archetypes: []*archetype.Archetype) void {
        self.frame_count += 1;
        self.entity_data_buffer.clearRetainingCapacity();

        for (self.queries.items) |query| {
            if (query.is_cached and query.last_update_frame == self.frame_count) {
                continue;
            }

            query.updateMatches(archetypes);
            query.last_update_frame = self.frame_count;

            var entity_count: usize = 0;
            var iter = query.iter();
            while (iter.next()) |_| {
                entity_count += 1;
            }
            query.cached_entity_count = entity_count;
        }
    }

    /// Run a function on all entities from all queries in batch
    pub fn forEachEntity(self: *QueryBatch, callback: *const fn (EntityData) void) void {
        for (self.queries.items) |query| {
            var iter = query.iter();
            while (iter.next()) |entity_data| {
                callback(entity_data);
            }
        }
    }

    /// Run a function on all entities from all queries (with error handling)
    pub fn forEachEntityErr(self: *QueryBatch, callback: *const fn (EntityData) anyerror!void) !void {
        for (self.queries.items) |query| {
            var iter = query.iter();
            while (iter.next()) |entity_data| {
                try callback(entity_data);
            }
        }
    }

    /// Get total entity count across all queries
    pub fn getTotalEntityCount(self: *const QueryBatch) usize {
        var total: usize = 0;
        for (self.queries.items) |query| {
            total += query.getEntityCount();
        }
        return total;
    }
};

// ============================================================================
// Convenience Functions
// ============================================================================

/// Create a query builder for fluent query construction
pub fn createQuery(allocator: std.mem.Allocator) QueryBuilder {
    return QueryBuilder.init(allocator);
}

/// Create a batch query manager
pub fn createQueryBatch(allocator: std.mem.Allocator) QueryBatch {
    return QueryBatch.init(allocator);
}

// ============================================================================
// Tests
// ============================================================================

test "query builder" {
    const allocator = std.testing.allocator;

    var builder = queryBuilder(allocator);
    defer builder.deinit();

    // Build a query for entities with Position and Rotation but without Scale
    var pos_rot_query = try builder
        .with(component.Position)
        .with(component.Rotation)
        .without(component.Scale)
        .build();
    defer pos_rot_query.deinit();

    try std.testing.expect(pos_rot_query.include_types.len == 2);
    try std.testing.expect(pos_rot_query.exclude_types.len == 1);
}

test "query matching" {
    const allocator = std.testing.allocator;

    // Create archetypes
    const transform_types = [_]archetype.ComponentType{
        archetype.ComponentType.init(component.Position),
        archetype.ComponentType.init(component.Rotation),
    };

    const renderable_types = [_]archetype.ComponentType{
        archetype.ComponentType.init(component.Position),
        archetype.ComponentType.init(component.Renderable),
    };

    var transform_arch = try archetype.Archetype.init(allocator, &transform_types, 4);
    defer transform_arch.deinit();

    var renderable_arch = try archetype.Archetype.init(allocator, &renderable_types, 4);
    defer renderable_arch.deinit();

    var archetypes = [_]*archetype.Archetype{ &transform_arch, &renderable_arch };

    // Create query for Position + Rotation
    var query_pos_rot = try Query.init(allocator, &[_]archetype.ComponentType{
        archetype.ComponentType.init(component.Position),
        archetype.ComponentType.init(component.Rotation),
    }, &[_]archetype.ComponentType{});
    defer query_pos_rot.deinit();

    query_pos_rot.updateMatches(&archetypes);

    try std.testing.expect(query_pos_rot.matching_archetypes.items.len == 1);
    try std.testing.expect(query_pos_rot.matching_archetypes.items[0] == &transform_arch);

    // Create query excluding Renderable
    var query_no_render = try Query.init(allocator, &[_]archetype.ComponentType{
        archetype.ComponentType.init(component.Position),
    }, &[_]archetype.ComponentType{
        archetype.ComponentType.init(component.Renderable),
    });
    defer query_no_render.deinit();

    query_no_render.updateMatches(&archetypes);

    try std.testing.expect(query_no_render.matching_archetypes.items.len == 1);
    try std.testing.expect(query_no_render.matching_archetypes.items[0] == &transform_arch);
}

test "query iteration" {
    const allocator = std.testing.allocator;

    // Create archetype with some entities
    const component_types = [_]archetype.ComponentType{
        archetype.ComponentType.init(component.Position),
        archetype.ComponentType.init(component.Rotation),
    };

    var arch = try archetype.Archetype.init(allocator, &component_types, 4);
    defer arch.deinit();

    // Add some entities
    const e1 = entity.EntityId.init(1, 0);
    const e2 = entity.EntityId.init(2, 0);

    try arch.addEntity(e1);
    try arch.addEntity(e2);

    // Set some component data
    if (arch.getComponent(e1, component.Position)) |pos| {
        pos.* = component.Position.init(1, 2, 3);
    }
    if (arch.getComponent(e2, component.Position)) |pos| {
        pos.* = component.Position.init(4, 5, 6);
    }

    // Create and run query
    var entity_query = try Query.init(allocator, &component_types, &[_]archetype.ComponentType{});
    defer entity_query.deinit();

    var arch_array = [_]*archetype.Archetype{&arch};
    entity_query.updateMatches(&arch_array);

    // Iterate over results
    var iter = entity_query.iter();
    var count: usize = 0;

    while (iter.next()) |entity_data| {
        count += 1;
        if (entity_data.get(component.Position)) |pos| {
            try std.testing.expect(pos.x > 0); // Should have valid position data
        }
    }

    try std.testing.expect(count == 2); // Should have found both entities
}
