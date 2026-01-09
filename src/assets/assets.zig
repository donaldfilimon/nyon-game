//! Asset Management

const std = @import("std");
const render = @import("../render/render.zig");

/// Asset handle with type tag
pub fn Handle(comptime T: type) type {
    _ = T;
    return struct {
        id: u32,
        generation: u32,

        pub const INVALID = @This(){ .id = std.math.maxInt(u32), .generation = 0 };

        pub fn isValid(self: @This()) bool {
            return self.id != std.math.maxInt(u32);
        }
    };
}

/// Asset manager
///
/// Ownership Model:
/// - The AssetManager owns all resources (textures, meshes) loaded through it.
/// - It is responsible for freeing them when `deinit()` is called.
/// - Handles returned are weak references; the underlying asset remains owned by the manager.
pub const AssetManager = struct {
    allocator: std.mem.Allocator,
    textures: AssetStorage(render.Texture),
    meshes: AssetStorage(render.Mesh),

    pub fn init(allocator: std.mem.Allocator) AssetManager {
        return .{
            .allocator = allocator,
            .textures = AssetStorage(render.Texture).init(allocator),
            .meshes = AssetStorage(render.Mesh).init(allocator),
        };
    }

    pub fn deinit(self: *AssetManager) void {
        self.textures.deinit();
        self.meshes.deinit();
    }

    pub fn loadTexture(self: *AssetManager, path: []const u8) !Handle(render.Texture) {
        _ = path;
        const tex = try render.Texture.init(self.allocator, 64, 64);
        return self.textures.add(tex);
    }

    pub fn getTexture(self: *AssetManager, handle: Handle(render.Texture)) ?*render.Texture {
        return self.textures.get(handle);
    }

    pub fn loadMesh(self: *AssetManager, path: []const u8) !Handle(render.Mesh) {
        _ = path;
        const mesh = try render.Mesh.cube(self.allocator);
        return self.meshes.add(mesh);
    }

    pub fn getMesh(self: *AssetManager, handle: Handle(render.Mesh)) ?*render.Mesh {
        return self.meshes.get(handle);
    }
};

fn AssetStorage(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        items: std.ArrayListUnmanaged(?T),
        generations: std.ArrayListUnmanaged(u32),
        free_list: std.ArrayListUnmanaged(u32),

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .items = .{},
                .generations = .{},
                .free_list = .{},
            };
        }

        pub fn deinit(self: *Self) void {
            for (self.items.items) |*maybe_item| {
                if (maybe_item.*) |*item| {
                    item.deinit();
                }
            }
            self.items.deinit(self.allocator);
            self.generations.deinit(self.allocator);
            self.free_list.deinit(self.allocator);
        }

        pub fn add(self: *Self, item: T) !Handle(T) {
            var index: u32 = undefined;
            var generation: u32 = undefined;

            if (self.free_list.pop()) |free_idx| {
                index = free_idx;
                self.items.items[index] = item;
                generation = self.generations.items[index];
            } else {
                index = @intCast(self.items.items.len);
                try self.items.append(self.allocator, item);
                try self.generations.append(self.allocator, 0);
                generation = 0;
            }

            return Handle(T){ .id = index, .generation = generation };
        }

        pub fn get(self: *Self, handle: Handle(T)) ?*T {
            if (handle.id >= self.items.items.len) return null;
            if (self.generations.items[handle.id] != handle.generation) return null;
            if (self.items.items[handle.id]) |*item| {
                return item;
            }
            return null;
        }

        pub fn remove(self: *Self, handle: Handle(T)) void {
            if (handle.id >= self.items.items.len) return;
            if (self.generations.items[handle.id] != handle.generation) return;

            if (self.items.items[handle.id]) |*item| {
                item.deinit();
                self.items.items[handle.id] = null;
                self.generations.items[handle.id] += 1;
                self.free_list.append(self.allocator, handle.id) catch {};
            }
        }
    };
}

test "asset manager" {
    const allocator = std.testing.allocator;
    var assets = AssetManager.init(allocator);
    defer assets.deinit();
}
