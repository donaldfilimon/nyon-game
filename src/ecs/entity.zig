//! Entity handle with generation for safe references

const std = @import("std");

/// Unique entity identifier with generation for dangling reference detection
pub const Entity = struct {
    index: u32,
    generation: u32,

    pub const INVALID = Entity{ .index = std.math.maxInt(u32), .generation = 0 };

    pub fn isValid(self: Entity) bool {
        return self.index != std.math.maxInt(u32);
    }

    pub fn eql(a: Entity, b: Entity) bool {
        return a.index == b.index and a.generation == b.generation;
    }

    pub fn hash(self: Entity) u64 {
        return @as(u64, self.index) | (@as(u64, self.generation) << 32);
    }
};

/// Entity pool for allocation/deallocation
pub const EntityPool = struct {
    generations: std.ArrayListUnmanaged(u32),
    free_list: std.ArrayListUnmanaged(u32),
    alive_count: u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) EntityPool {
        return .{
            .generations = .{},
            .free_list = .{},
            .alive_count = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *EntityPool) void {
        self.generations.deinit(self.allocator);
        self.free_list.deinit(self.allocator);
    }

    pub fn create(self: *EntityPool) !Entity {
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

    pub fn destroy(self: *EntityPool, entity: Entity) bool {
        if (!self.isAlive(entity)) return false;

        self.generations.items[entity.index] += 1;
        self.free_list.append(self.allocator, entity.index) catch {};
        self.alive_count -= 1;
        return true;
    }

    pub fn isAlive(self: *const EntityPool, entity: Entity) bool {
        if (entity.index >= self.generations.items.len) return false;
        return self.generations.items[entity.index] == entity.generation;
    }
};

test "entity pool" {
    const allocator = std.testing.allocator;
    var pool = EntityPool.init(allocator);
    defer pool.deinit();

    const e1 = try pool.create();
    const e2 = try pool.create();

    try std.testing.expect(pool.isAlive(e1));
    try std.testing.expect(pool.isAlive(e2));
    try std.testing.expect(!e1.eql(e2));

    try std.testing.expect(pool.destroy(e1));
    try std.testing.expect(!pool.isAlive(e1));

    const e3 = try pool.create();
    try std.testing.expectEqual(e1.index, e3.index);
    try std.testing.expect(e3.generation > e1.generation);
}
