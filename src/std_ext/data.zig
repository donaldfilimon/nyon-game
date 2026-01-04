//! Game-Specific Data Structures
//!

const std = @import("std");

/// Entity ID with generation counter for safe handle invalidation
pub const EntityId = packed struct(u64) {
    index: u32,
    generation: u32,

    pub fn none() EntityId {
        return @as(EntityId, @bitCast(@as(u64, 0)));
    }

    pub fn isValid(self: EntityId) bool {
        return self.index != std.math.maxInt(u32);
    }

    pub fn getIndex(self: EntityId) u32 {
        return self.index;
    }

    pub fn getGeneration(self: EntityId) u32 {
        return self.generation;
    }
};

/// Entity manager with generation tracking
pub const EntityManager = struct {
    entities: std.ArrayListUnmanaged(EntityData),
    generations: std.ArrayListUnmanaged(u32),
    free_list: std.ArrayListUnmanaged(u32),
    alive_count: u32,
    allocator: std.mem.Allocator,

    const EntityData = struct {
        alive: bool,
        generation: u32,
    };

    pub fn init(allocator: std.mem.Allocator) !EntityManager {
        return EntityManager{
            .entities = try std.ArrayListUnmanaged(EntityData).initCapacity(allocator, 1024),
            .generations = try std.ArrayListUnmanaged(u32).initCapacity(allocator, 1024),
            .free_list = try std.ArrayListUnmanaged(u32).initCapacity(allocator, 1024),
            .alive_count = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *EntityManager) void {
        self.entities.deinit(self.allocator);
        self.generations.deinit(self.allocator);
        self.free_list.deinit(self.allocator);
    }

    pub fn create(self: *EntityManager) !EntityId {
        const index = if (self.free_list.pop()) |idx| idx else @as(u32, @intCast(self.entities.items.len));

        const generation = if (index < self.generations.items.len)
            self.generations.items[index] + 1
        else
            0;

        if (index >= self.entities.items.len) {
            try self.entities.append(self.allocator, EntityData{ .alive = true, .generation = generation });
            try self.generations.append(self.allocator, generation);
        } else {
            self.entities.items[index].alive = true;
            self.entities.items[index].generation = generation;
        }

        self.alive_count += 1;

        return @as(EntityId, @bitCast(@as(u64, (@intFromPtr(&self) & 0xFFFFFFFF) << 32) | index));
    }

    pub fn destroy(self: *EntityManager, entity_id: EntityId) void {
        const index = entity_id.index;
        if (index >= self.entities.items.len) return;
        if (!self.entities.items[index].alive) return;

        self.entities.items[index].alive = false;
        self.free_list.append(self.allocator, index) catch {};
        self.alive_count -= 1;
    }

    pub fn isAlive(self: *const EntityManager, entity_id: EntityId) bool {
        const index = entity_id.index;
        if (index >= self.entities.items.len) return false;
        if (!self.entities.items[index].alive) return false;
        if (self.generations.items[index] != entity_id.generation) return false;
        return true;
    }

    pub fn getAliveCount(self: *const EntityManager) u32 {
        return self.alive_count;
    }
};

/// Ring buffer for audio/processing pipelines
pub const RingBuffer = struct {
    buffer: []u8,
    read_offset: usize,
    write_offset: usize,
    capacity: usize,

    pub fn init(allocator: std.mem.Allocator, capacity: usize) !RingBuffer {
        const buffer = try allocator.alloc(u8, capacity);
        return RingBuffer{
            .buffer = buffer,
            .read_offset = 0,
            .write_offset = 0,
            .capacity = capacity,
        };
    }

    pub fn deinit(self: *RingBuffer, allocator: std.mem.Allocator) void {
        allocator.free(self.buffer);
    }

    pub fn write(self: *RingBuffer, data: []const u8) usize {
        const available = self.getAvailableWrite();
        const to_write = @min(data.len, available);

        for (0..to_write) |i| {
            self.buffer[(self.write_offset + i) % self.capacity] = data[i];
        }

        self.write_offset = (self.write_offset + to_write) % self.capacity;
        return to_write;
    }

    pub fn read(self: *RingBuffer, data: []u8) usize {
        const available = self.getAvailableRead();
        const to_read = @min(data.len, available);

        for (0..to_read) |i| {
            data[i] = self.buffer[(self.read_offset + i) % self.capacity];
        }

        self.read_offset = (self.read_offset + to_read) % self.capacity;
        return to_read;
    }

    pub fn getAvailableRead(self: *const RingBuffer) usize {
        if (self.write_offset >= self.read_offset) {
            return self.write_offset - self.read_offset;
        }
        return self.capacity - self.read_offset + self.write_offset;
    }

    pub fn getAvailableWrite(self: *const RingBuffer) usize {
        return self.capacity - self.getAvailableRead();
    }

    pub fn clear(self: *RingBuffer) void {
        self.read_offset = 0;
        self.write_offset = 0;
    }
};
