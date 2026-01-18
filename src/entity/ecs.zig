//! Entity Component System for Mobs and NPCs
//!
//! Provides a specialized ECS world for managing game entities like mobs,
//! NPCs, and other dynamic objects. Built on top of the core ECS module.

const std = @import("std");
const core_ecs = @import("../ecs/ecs.zig");
const components = @import("components.zig");
const math = @import("../math/math.zig");

// Re-export entity type
pub const Entity = core_ecs.Entity;

// Re-export components
pub const Transform = components.Transform;
pub const Velocity = components.Velocity;
pub const Health = components.Health;
pub const AI = components.AI;
pub const Render = components.Render;
pub const Collider = components.Collider;
pub const Mob = components.Mob;
pub const PhysicsBody = components.PhysicsBody;
pub const Inventory = components.Inventory;
pub const Name = components.Name;

pub const AIBehavior = components.AIBehavior;
pub const AIState = components.AIState;
pub const MobType = components.MobType;
pub const MeshType = components.MeshType;
pub const Color = components.Color;

/// Sparse-set based component storage
fn ComponentStorage(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        sparse: std.AutoHashMap(u64, usize),
        dense: std.ArrayListUnmanaged(T),
        entities: std.ArrayListUnmanaged(Entity),

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .sparse = std.AutoHashMap(u64, usize).init(allocator),
                .dense = .{},
                .entities = .{},
            };
        }

        pub fn deinit(self: *Self) void {
            self.sparse.deinit();
            self.dense.deinit(self.allocator);
            self.entities.deinit(self.allocator);
        }

        pub fn set(self: *Self, entity: Entity, comp: T) !void {
            const key = entity.hash();
            if (self.sparse.get(key)) |idx| {
                self.dense.items[idx] = comp;
            } else {
                const idx = self.dense.items.len;
                try self.dense.append(self.allocator, comp);
                try self.entities.append(self.allocator, entity);
                try self.sparse.put(key, idx);
            }
        }

        pub fn get(self: *Self, entity: Entity) ?*T {
            const key = entity.hash();
            if (self.sparse.get(key)) |idx| {
                return &self.dense.items[idx];
            }
            return null;
        }

        pub fn getConst(self: *const Self, entity: Entity) ?*const T {
            const key = entity.hash();
            if (self.sparse.get(key)) |idx| {
                return &self.dense.items[idx];
            }
            return null;
        }

        pub fn remove(self: *Self, entity: Entity) void {
            const key = entity.hash();
            if (self.sparse.fetchRemove(key)) |kv| {
                const idx = kv.value;
                if (idx < self.dense.items.len - 1) {
                    const last_entity = self.entities.items[self.entities.items.len - 1];
                    self.dense.items[idx] = self.dense.items[self.dense.items.len - 1];
                    self.entities.items[idx] = last_entity;
                    self.sparse.put(last_entity.hash(), idx) catch {};
                }
                _ = self.dense.pop();
                _ = self.entities.pop();
            }
        }

        pub fn len(self: *const Self) usize {
            return self.dense.items.len;
        }

        pub fn contains(self: *const Self, entity: Entity) bool {
            return self.sparse.contains(entity.hash());
        }
    };
}

/// Entity World specialized for game entities (mobs, NPCs, etc.)
pub const EntityWorld = struct {
    allocator: std.mem.Allocator,
    entity_pool: core_ecs.component.Parent, // Use entity pool from parent module

    // Use our own entity pool
    generations: std.ArrayListUnmanaged(u32),
    free_list: std.ArrayListUnmanaged(u32),
    alive_count: u32,

    // Component storage
    transforms: ComponentStorage(Transform),
    velocities: ComponentStorage(Velocity),
    healths: ComponentStorage(Health),
    ais: ComponentStorage(AI),
    renders: ComponentStorage(Render),
    colliders: ComponentStorage(Collider),
    mobs: ComponentStorage(Mob),
    physics_bodies: ComponentStorage(PhysicsBody),
    inventories: ComponentStorage(Inventory),
    names: ComponentStorage(Name),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .entity_pool = undefined,
            .generations = .{},
            .free_list = .{},
            .alive_count = 0,
            .transforms = ComponentStorage(Transform).init(allocator),
            .velocities = ComponentStorage(Velocity).init(allocator),
            .healths = ComponentStorage(Health).init(allocator),
            .ais = ComponentStorage(AI).init(allocator),
            .renders = ComponentStorage(Render).init(allocator),
            .colliders = ComponentStorage(Collider).init(allocator),
            .mobs = ComponentStorage(Mob).init(allocator),
            .physics_bodies = ComponentStorage(PhysicsBody).init(allocator),
            .inventories = ComponentStorage(Inventory).init(allocator),
            .names = ComponentStorage(Name).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.transforms.deinit();
        self.velocities.deinit();
        self.healths.deinit();
        self.ais.deinit();
        self.renders.deinit();
        self.colliders.deinit();
        self.mobs.deinit();
        self.physics_bodies.deinit();
        self.inventories.deinit();
        self.names.deinit();
        self.generations.deinit(self.allocator);
        self.free_list.deinit(self.allocator);
    }

    /// Create a new entity
    pub fn spawn(self: *Self) !Entity {
        var index: u32 = undefined;
        var generation: u32 = undefined;

        if (self.free_list.pop()) |free_idx| {
            index = free_idx;
            generation = self.generations.items[index];
        } else {
            index = @intCast(self.generations.items.len);
            try self.generations.append(self.allocator, 0);
            generation = 0;
        }

        self.alive_count += 1;
        return Entity{ .index = index, .generation = generation };
    }

    /// Destroy an entity and all its components
    pub fn despawn(self: *Self, entity: Entity) void {
        if (!self.isAlive(entity)) return;

        // Remove all components
        self.transforms.remove(entity);
        self.velocities.remove(entity);
        self.healths.remove(entity);
        self.ais.remove(entity);
        self.renders.remove(entity);
        self.colliders.remove(entity);
        self.mobs.remove(entity);
        self.physics_bodies.remove(entity);
        self.inventories.remove(entity);
        self.names.remove(entity);

        // Increment generation and add to free list
        self.generations.items[entity.index] += 1;
        self.free_list.append(self.allocator, entity.index) catch {};
        self.alive_count -= 1;
    }

    /// Check if entity is alive
    pub fn isAlive(self: *const Self, entity: Entity) bool {
        if (entity.index >= self.generations.items.len) return false;
        return self.generations.items[entity.index] == entity.generation;
    }

    /// Add a component to an entity
    pub fn addComponent(self: *Self, entity: Entity, comptime T: type, comp: T) !void {
        if (!self.isAlive(entity)) return error.EntityNotAlive;
        const storage = self.getStorage(T);
        try storage.set(entity, comp);
    }

    /// Get a component from an entity
    pub fn getComponent(self: *Self, entity: Entity, comptime T: type) ?*T {
        if (!self.isAlive(entity)) return null;
        const storage = self.getStorage(T);
        return storage.get(entity);
    }

    /// Get component (const version)
    pub fn getComponentConst(self: *const Self, entity: Entity, comptime T: type) ?*const T {
        if (!self.isAlive(entity)) return null;
        const storage = self.getStorageConst(T);
        return storage.getConst(entity);
    }

    /// Remove a component from an entity
    pub fn removeComponent(self: *Self, entity: Entity, comptime T: type) void {
        const storage = self.getStorage(T);
        storage.remove(entity);
    }

    /// Check if entity has a component
    pub fn hasComponent(self: *const Self, entity: Entity, comptime T: type) bool {
        if (!self.isAlive(entity)) return false;
        const storage = self.getStorageConst(T);
        return storage.contains(entity);
    }

    /// Get component storage for type
    pub fn getStorage(self: *Self, comptime T: type) *ComponentStorage(T) {
        return switch (T) {
            Transform => &self.transforms,
            Velocity => &self.velocities,
            Health => &self.healths,
            AI => &self.ais,
            Render => &self.renders,
            Collider => &self.colliders,
            Mob => &self.mobs,
            PhysicsBody => &self.physics_bodies,
            Inventory => &self.inventories,
            Name => &self.names,
            else => @compileError("Unknown component type: " ++ @typeName(T)),
        };
    }

    /// Get component storage for type (const version)
    pub fn getStorageConst(self: *const Self, comptime T: type) *const ComponentStorage(T) {
        return switch (T) {
            Transform => &self.transforms,
            Velocity => &self.velocities,
            Health => &self.healths,
            AI => &self.ais,
            Render => &self.renders,
            Collider => &self.colliders,
            Mob => &self.mobs,
            PhysicsBody => &self.physics_bodies,
            Inventory => &self.inventories,
            Name => &self.names,
            else => @compileError("Unknown component type: " ++ @typeName(T)),
        };
    }

    /// Get entity count
    pub fn entityCount(self: *const Self) u32 {
        return self.alive_count;
    }

    /// Get all entities with a specific component
    pub fn getEntitiesWith(self: *Self, comptime T: type) []const Entity {
        const storage = self.getStorage(T);
        return storage.entities.items;
    }

    /// Iterate over all entities with specific components
    pub fn query(self: *Self, comptime Components: []const type) QueryIterator(Components) {
        return QueryIterator(Components).init(self);
    }
};

/// Query iterator for entities with specific components
pub fn QueryIterator(comptime Components: []const type) type {
    return struct {
        world: *EntityWorld,
        index: usize,
        entities: []const Entity,

        const Self = @This();

        pub fn init(world: *EntityWorld) Self {
            // Use the smallest component set as the base
            const first_storage = world.getStorage(Components[0]);
            return .{
                .world = world,
                .index = 0,
                .entities = first_storage.entities.items,
            };
        }

        pub fn next(self: *Self) ?QueryResult(Components) {
            while (self.index < self.entities.len) {
                const entity = self.entities[self.index];
                self.index += 1;

                if (!self.world.isAlive(entity)) continue;

                // Check if entity has all required components
                var has_all = true;
                inline for (Components) |T| {
                    if (!self.world.hasComponent(entity, T)) {
                        has_all = false;
                        break;
                    }
                }

                if (has_all) {
                    return QueryResult(Components){
                        .entity = entity,
                        .world = self.world,
                    };
                }
            }
            return null;
        }

        pub fn reset(self: *Self) void {
            self.index = 0;
        }
    };
}

/// Query result providing access to entity components
pub fn QueryResult(comptime Components: []const type) type {
    return struct {
        entity: Entity,
        world: *EntityWorld,

        const Self = @This();

        pub fn get(self: Self, comptime T: type) ?*T {
            // Verify T is in Components at compile time
            comptime {
                var found = false;
                for (Components) |C| {
                    if (C == T) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    @compileError("Component type not in query: " ++ @typeName(T));
                }
            }
            return self.world.getComponent(self.entity, T);
        }
    };
}

// ============================================================================
// Tests
// ============================================================================

test "EntityWorld spawn and despawn" {
    const allocator = std.testing.allocator;
    var world = EntityWorld.init(allocator);
    defer world.deinit();

    const e1 = try world.spawn();
    const e2 = try world.spawn();

    try std.testing.expect(world.isAlive(e1));
    try std.testing.expect(world.isAlive(e2));
    try std.testing.expectEqual(@as(u32, 2), world.entityCount());

    world.despawn(e1);
    try std.testing.expect(!world.isAlive(e1));
    try std.testing.expectEqual(@as(u32, 1), world.entityCount());
}

test "EntityWorld add and get components" {
    const allocator = std.testing.allocator;
    var world = EntityWorld.init(allocator);
    defer world.deinit();

    const entity = try world.spawn();

    try world.addComponent(entity, Transform, .{
        .position = math.Vec3.init(10, 20, 30),
    });
    try world.addComponent(entity, Health, Health.init(100));

    const transform = world.getComponent(entity, Transform);
    try std.testing.expect(transform != null);
    try std.testing.expectApproxEqAbs(@as(f32, 10), transform.?.position.x(), 0.001);

    const health = world.getComponent(entity, Health);
    try std.testing.expect(health != null);
    try std.testing.expectApproxEqAbs(@as(f32, 100), health.?.current, 0.001);
}

test "EntityWorld query" {
    const allocator = std.testing.allocator;
    var world = EntityWorld.init(allocator);
    defer world.deinit();

    // Create entities with different component combinations
    const e1 = try world.spawn();
    try world.addComponent(e1, Transform, .{});
    try world.addComponent(e1, Health, Health.init(100));

    const e2 = try world.spawn();
    try world.addComponent(e2, Transform, .{});
    // e2 has no Health

    const e3 = try world.spawn();
    try world.addComponent(e3, Transform, .{});
    try world.addComponent(e3, Health, Health.init(50));

    // Query for entities with both Transform and Health
    var iter = world.query(&[_]type{ Transform, Health });
    var count: u32 = 0;

    while (iter.next()) |_| {
        count += 1;
    }

    try std.testing.expectEqual(@as(u32, 2), count);
}

test "EntityWorld entity reuse" {
    const allocator = std.testing.allocator;
    var world = EntityWorld.init(allocator);
    defer world.deinit();

    const e1 = try world.spawn();
    const e1_idx = e1.index;
    const e1_gen = e1.generation;

    world.despawn(e1);

    const e2 = try world.spawn();

    // Should reuse same index but with incremented generation
    try std.testing.expectEqual(e1_idx, e2.index);
    try std.testing.expect(e2.generation > e1_gen);

    // Old entity handle should not be valid
    try std.testing.expect(!world.isAlive(e1));
    try std.testing.expect(world.isAlive(e2));
}
