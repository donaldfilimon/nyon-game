//! ECS World - manages entities and components

const std = @import("std");
const Entity = @import("entity.zig").Entity;
const EntityPool = @import("entity.zig").EntityPool;
const component = @import("component.zig");

/// The World manages all entities and their components
pub const World = struct {
    allocator: std.mem.Allocator,
    entity_pool: EntityPool,

    // Component storage (SoA layout for cache efficiency)
    transforms: ComponentStorage(component.Transform),
    velocities: ComponentStorage(component.Velocity),
    renderables: ComponentStorage(component.Renderable),
    cameras: ComponentStorage(component.Camera),
    lights: ComponentStorage(component.Light),
    names: ComponentStorage(component.Name),

    // Systems
    systems: std.ArrayListUnmanaged(System),

    pub const System = struct {
        name: []const u8,
        update_fn: *const fn (*World, f64) void,
        priority: i32,
    };

    pub fn init(allocator: std.mem.Allocator) !World {
        return World{
            .allocator = allocator,
            .entity_pool = EntityPool.init(allocator),
            .transforms = ComponentStorage(component.Transform).init(allocator),
            .velocities = ComponentStorage(component.Velocity).init(allocator),
            .renderables = ComponentStorage(component.Renderable).init(allocator),
            .cameras = ComponentStorage(component.Camera).init(allocator),
            .lights = ComponentStorage(component.Light).init(allocator),
            .names = ComponentStorage(component.Name).init(allocator),
            .systems = .{},
        };
    }

    pub fn deinit(self: *World) void {
        self.transforms.deinit();
        self.velocities.deinit();
        self.renderables.deinit();
        self.cameras.deinit();
        self.lights.deinit();
        self.names.deinit();
        self.entity_pool.deinit();
        self.systems.deinit(self.allocator);
    }

    /// Create a new entity
    pub fn spawn(self: *World) !Entity {
        return self.entity_pool.create();
    }

    /// Destroy an entity and all its components
    pub fn despawn(self: *World, entity: Entity) void {
        self.transforms.remove(entity);
        self.velocities.remove(entity);
        self.renderables.remove(entity);
        self.cameras.remove(entity);
        self.lights.remove(entity);
        self.names.remove(entity);
        _ = self.entity_pool.destroy(entity);
    }

    /// Check if entity is alive
    pub fn isAlive(self: *const World, entity: Entity) bool {
        return self.entity_pool.isAlive(entity);
    }

    /// Add a component to an entity
    pub fn addComponent(self: *World, entity: Entity, comptime T: type, comp: T) !void {
        const storage = self.getStorage(T);
        try storage.set(entity, comp);
    }

    /// Get a component from an entity
    pub fn getComponent(self: *World, entity: Entity, comptime T: type) ?*T {
        const storage = self.getStorage(T);
        return storage.get(entity);
    }

    /// Remove a component from an entity
    pub fn removeComponent(self: *World, entity: Entity, comptime T: type) void {
        const storage = self.getStorage(T);
        storage.remove(entity);
    }

    /// Get component storage for type
    pub fn getStorage(self: *World, comptime T: type) *ComponentStorage(T) {
        return switch (T) {
            component.Transform => &self.transforms,
            component.Velocity => &self.velocities,
            component.Renderable => &self.renderables,
            component.Camera => &self.cameras,
            component.Light => &self.lights,
            component.Name => &self.names,
            else => @compileError("Unknown component type"),
        };
    }

    /// Register a system
    pub fn addSystem(self: *World, system: System) !void {
        try self.systems.append(self.allocator, system);
        // Sort by priority
        std.mem.sort(System, self.systems.items, {}, struct {
            fn cmp(_: void, a: System, b: System) bool {
                return a.priority < b.priority;
            }
        }.cmp);
    }

    /// Update all systems
    pub fn update(self: *World, delta_time: f64) void {
        for (self.systems.items) |system| {
            system.update_fn(self, delta_time);
        }
    }

    /// Get entity count
    pub fn entityCount(self: *const World) u32 {
        return self.entity_pool.alive_count;
    }
};

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

        pub fn remove(self: *Self, entity: Entity) void {
            const key = entity.hash();
            if (self.sparse.fetchRemove(key)) |kv| {
                const idx = kv.value;
                if (idx < self.dense.items.len - 1) {
                    // Swap with last
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
    };
}

test "world spawn and despawn" {
    const allocator = std.testing.allocator;
    var world = try World.init(allocator);
    defer world.deinit();

    const e = try world.spawn();
    try std.testing.expect(world.isAlive(e));

    try world.addComponent(e, component.Transform, .{});
    try std.testing.expect(world.getComponent(e, component.Transform) != null);

    world.despawn(e);
    try std.testing.expect(!world.isAlive(e));
}
