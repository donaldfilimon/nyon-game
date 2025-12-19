//! Entity Component System (ECS) - Entity Management
//!
//! This module provides the foundation for the ECS architecture used throughout
//! the Nyon Game Engine. It implements efficient entity management with archetype-based
//! storage for cache-friendly component access.

const std = @import("std");

/// Unique identifier for entities in the ECS world
pub const Entity = u64;

/// Entity generation counter to prevent ABA problems
pub const EntityGeneration = u32;

/// Entity ID with generation for safety
pub const EntityId = struct {
    id: Entity,
    generation: EntityGeneration,

    pub fn init(id: Entity, generation: EntityGeneration) EntityId {
        return .{ .id = id, .generation = generation };
    }

    pub fn eql(self: EntityId, other: EntityId) bool {
        return self.id == other.id and self.generation == other.generation;
    }
};

/// Entity manager for creating, destroying, and validating entities
pub const EntityManager = struct {
    allocator: std.mem.Allocator,
    next_id: Entity = 0,
    generations: std.AutoHashMap(Entity, EntityGeneration),
    free_ids: std.ArrayList(Entity),

    /// Initialize a new entity manager
    pub fn init(allocator: std.mem.Allocator) EntityManager {
        return .{
            .allocator = allocator,
            .generations = std.AutoHashMap(Entity, EntityGeneration).init(allocator),
            .free_ids = std.ArrayList(Entity).initCapacity(allocator, 0) catch unreachable,
        };
    }

    /// Deinitialize the entity manager
    pub fn deinit(self: *EntityManager) void {
        self.generations.deinit();
        self.free_ids.deinit(self.allocator);
    }

    /// Create a new entity and return its ID
    pub fn create(self: *EntityManager) !EntityId {
        var id: Entity = undefined;
        var generation: EntityGeneration = 0;

        // Reuse a freed ID if available
        if (self.free_ids.items.len > 0) {
            id = self.free_ids.pop().?;
            generation = self.generations.get(id) orelse 0;
            generation += 1;
        } else {
            id = self.next_id;
            self.next_id += 1;
        }

        try self.generations.put(id, generation);
        return EntityId.init(id, generation);
    }

    /// Destroy an entity, making its ID available for reuse
    pub fn destroy(self: *EntityManager, entity: EntityId) void {
        if (self.generations.getPtr(entity.id)) |gen_ptr| {
            if (gen_ptr.* == entity.generation) {
                // Mark as destroyed by incrementing generation
                gen_ptr.* += 1;
                self.free_ids.append(self.allocator, entity.id) catch {};
            }
        }
    }

    /// Check if an entity ID is currently alive (not destroyed)
    pub fn isAlive(self: *const EntityManager, entity: EntityId) bool {
        if (self.generations.get(entity.id)) |current_gen| {
            return current_gen == entity.generation;
        }
        return false;
    }

    /// Get the current generation of an entity ID
    pub fn getGeneration(self: *const EntityManager, id: Entity) ?EntityGeneration {
        return self.generations.get(id);
    }

    /// Get total number of alive entities
    pub fn aliveCount(self: *const EntityManager) usize {
        return self.generations.count() - self.free_ids.items.len;
    }

    /// Get total number of entities ever created (including destroyed ones)
    pub fn totalCount(self: *const EntityManager) usize {
        return self.generations.count();
    }

    /// Clear all entities and reset the manager
    pub fn clear(self: *EntityManager) void {
        self.generations.clearRetainingCapacity();
        self.free_ids.clearRetainingCapacity();
        self.next_id = 0;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "entity creation and destruction" {
    var em = EntityManager.init(std.testing.allocator);
    defer em.deinit();

    // Create some entities
    const e1 = try em.create();
    const e2 = try em.create();
    const e3 = try em.create();

    try std.testing.expect(em.isAlive(e1));
    try std.testing.expect(em.isAlive(e2));
    try std.testing.expect(em.isAlive(e3));
    try std.testing.expect(em.aliveCount() == 3);

    // Destroy one entity
    em.destroy(e2);
    try std.testing.expect(!em.isAlive(e2));
    try std.testing.expect(em.isAlive(e1));
    try std.testing.expect(em.isAlive(e3));
    try std.testing.expect(em.aliveCount() == 2);

    // Create a new entity (should reuse e2's ID with new generation)
    const e4 = try em.create();
    try std.testing.expect(em.isAlive(e4));
    try std.testing.expect(e4.id == e2.id);
    try std.testing.expect(e4.generation == 2); // Destroyed (gen 0->1) + create (gen 1->2)
    try std.testing.expect(em.aliveCount() == 3);
}

test "entity ID validation" {
    var em = EntityManager.init(std.testing.allocator);
    defer em.deinit();

    const e1 = try em.create();
    try std.testing.expect(em.isAlive(e1));

    // Create fake entity ID
    const fake = EntityId.init(999, 0);
    try std.testing.expect(!em.isAlive(fake));

    // Destroy real entity
    em.destroy(e1);
    try std.testing.expect(!em.isAlive(e1));
}
