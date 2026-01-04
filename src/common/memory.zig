//! Memory management utilities for Nyon Game Engine.

const std = @import("std");

pub const MemoryConfig = struct {
    arena_initial_size: usize = 64 * 1024,
    arena_max_size: usize = 4 * 1024 * 1024,
    temp_buffer_size: usize = 1024 * 1024,
};

pub fn createArena(allocator: std.mem.Allocator) !std.heap.ArenaAllocator {
    return std.heap.ArenaAllocator.init(allocator);
}

pub const ObjectPool = struct {
    allocator: std.mem.Allocator,
    objects: std.ArrayList(*anyopaque),
    create_fn: fn (std.mem.Allocator) anyerror!*anyopaque,
    destroy_fn: fn (*anyopaque, std.mem.Allocator) void,

    pub fn init(
        allocator: std.mem.Allocator,
        create_fn: fn (std.mem.Allocator) anyerror!*anyopaque,
        destroy_fn: fn (*anyopaque, std.mem.Allocator) void,
    ) ObjectPool {
        return ObjectPool{
            .allocator = allocator,
            .objects = std.ArrayList(*anyopaque).init(allocator),
            .create_fn = create_fn,
            .destroy_fn = destroy_fn,
        };
    }

    pub fn deinit(self: *ObjectPool) void {
        for (self.objects.items) |obj| {
            self.destroy_fn(obj, self.allocator);
        }
        self.objects.deinit();
    }

    pub fn acquire(self: *ObjectPool) !*anyopaque {
        if (self.objects.pop()) |obj| {
            return obj;
        }
        return try self.create_fn(self.allocator);
    }

    pub fn release(self: *ObjectPool, obj: *anyopaque) !void {
        try self.objects.append(obj);
    }
};

test "ObjectPool basic" {
    const TestContext = struct {
        fn create(_: std.mem.Allocator) anyerror!*anyopaque {
            const ptr = try std.testing.allocator.create(u8);
            ptr.* = 42;
            return @ptrCast(ptr);
        }
        fn destroy(obj: *anyopaque, a: std.mem.Allocator) void {
            const u = @as(*u8, @ptrCast(obj));
            a.destroy(u);
        }
    };
    var pool = ObjectPool.init(std.testing.allocator, TestContext.create, TestContext.destroy);
    defer pool.deinit();

    const obj = try pool.acquire();
    defer pool.release(obj) catch {};
    try std.testing.expectEqual(@as(u8, 42), @as(*u8, @ptrCast(obj)).*);
}
