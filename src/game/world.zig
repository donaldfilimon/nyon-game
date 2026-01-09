//! Block World System
//!
//! Chunk-based voxel world storage and management.

const std = @import("std");
const math = @import("../math/math.zig");
const physics = @import("../physics/physics.zig");

/// Block types
pub const Block = enum(u8) {
    air = 0,
    stone,
    dirt,
    grass,
    sand,
    water,
    wood,
    leaves,
    brick,
    glass,

    pub fn isSolid(self: Block) bool {
        return switch (self) {
            .air, .water => false,
            else => true,
        };
    }

    pub fn isTransparent(self: Block) bool {
        return switch (self) {
            .air, .water, .glass, .leaves => true,
            else => false,
        };
    }

    /// Get block color for rendering
    pub fn getColor(self: Block) [4]u8 {
        return switch (self) {
            .air => .{ 0, 0, 0, 0 },
            .stone => .{ 128, 128, 128, 255 },
            .dirt => .{ 139, 90, 43, 255 },
            .grass => .{ 86, 152, 42, 255 },
            .sand => .{ 237, 201, 175, 255 },
            .water => .{ 64, 164, 223, 180 },
            .wood => .{ 156, 102, 31, 255 },
            .leaves => .{ 30, 120, 30, 200 },
            .brick => .{ 178, 34, 34, 255 },
            .glass => .{ 200, 220, 255, 100 },
        };
    }
};

/// Chunk dimensions (16x16x16 blocks)
pub const CHUNK_SIZE: usize = 16;
pub const CHUNK_SIZE_I: i32 = 16;
pub const CHUNK_VOLUME: usize = CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE;

/// Single chunk of blocks
pub const Chunk = struct {
    blocks: [CHUNK_VOLUME]Block,
    position: [3]i32, // Chunk position in chunk coordinates
    is_dirty: bool,

    pub fn init(cx: i32, cy: i32, cz: i32) Chunk {
        return .{
            .blocks = [_]Block{.air} ** CHUNK_VOLUME,
            .position = .{ cx, cy, cz },
            .is_dirty = true,
        };
    }

    /// Get index from local block position
    fn getIndex(x: usize, y: usize, z: usize) usize {
        return x + y * CHUNK_SIZE + z * CHUNK_SIZE * CHUNK_SIZE;
    }

    /// Get block at local position
    pub fn getBlock(self: *const Chunk, x: usize, y: usize, z: usize) Block {
        if (x >= CHUNK_SIZE or y >= CHUNK_SIZE or z >= CHUNK_SIZE) {
            return .air;
        }
        return self.blocks[getIndex(x, y, z)];
    }

    /// Set block at local position
    pub fn setBlock(self: *Chunk, x: usize, y: usize, z: usize, block: Block) void {
        if (x >= CHUNK_SIZE or y >= CHUNK_SIZE or z >= CHUNK_SIZE) {
            return;
        }
        self.blocks[getIndex(x, y, z)] = block;
        self.is_dirty = true;
    }

    /// Get world position of chunk origin
    pub fn getWorldPosition(self: *const Chunk) math.Vec3 {
        return math.Vec3.init(
            @as(f32, @floatFromInt(self.position[0] * CHUNK_SIZE_I)),
            @as(f32, @floatFromInt(self.position[1] * CHUNK_SIZE_I)),
            @as(f32, @floatFromInt(self.position[2] * CHUNK_SIZE_I)),
        );
    }
};

/// Complete block world
pub const BlockWorld = struct {
    allocator: std.mem.Allocator,
    chunks: std.AutoHashMap(i64, *Chunk),
    physics_world: physics.PhysicsWorld,

    pub fn init(allocator: std.mem.Allocator) BlockWorld {
        return .{
            .allocator = allocator,
            .chunks = std.AutoHashMap(i64, *Chunk).init(allocator),
            .physics_world = physics.PhysicsWorld.init(allocator),
        };
    }

    pub fn deinit(self: *BlockWorld) void {
        var iter = self.chunks.valueIterator();
        while (iter.next()) |chunk_ptr| {
            self.allocator.destroy(chunk_ptr.*);
        }
        self.chunks.deinit();
        self.physics_world.deinit();
    }

    /// Hash chunk coordinates to single key
    fn chunkKey(cx: i32, cy: i32, cz: i32) i64 {
        const x: i64 = @intCast(cx);
        const y: i64 = @intCast(cy);
        const z: i64 = @intCast(cz);
        return x + y * 0x100000 + z * 0x10000000000;
    }

    /// Get or create chunk at chunk coordinates
    pub fn getOrCreateChunk(self: *BlockWorld, cx: i32, cy: i32, cz: i32) !*Chunk {
        const key = chunkKey(cx, cy, cz);
        if (self.chunks.get(key)) |chunk| {
            return chunk;
        }

        const chunk = try self.allocator.create(Chunk);
        chunk.* = Chunk.init(cx, cy, cz);
        try self.chunks.put(key, chunk);
        return chunk;
    }

    /// Get chunk if it exists
    pub fn getChunk(self: *BlockWorld, cx: i32, cy: i32, cz: i32) ?*Chunk {
        return self.chunks.get(chunkKey(cx, cy, cz));
    }

    /// Convert world position to chunk coords
    pub fn worldToChunk(x: i32, y: i32, z: i32) struct { cx: i32, cy: i32, cz: i32, lx: usize, ly: usize, lz: usize } {
        const cx = @divFloor(x, CHUNK_SIZE_I);
        const cy = @divFloor(y, CHUNK_SIZE_I);
        const cz = @divFloor(z, CHUNK_SIZE_I);

        const lx: usize = @intCast(@mod(x, CHUNK_SIZE_I));
        const ly: usize = @intCast(@mod(y, CHUNK_SIZE_I));
        const lz: usize = @intCast(@mod(z, CHUNK_SIZE_I));

        return .{ .cx = cx, .cy = cy, .cz = cz, .lx = lx, .ly = ly, .lz = lz };
    }

    /// Get block at world position
    pub fn getBlock(self: *BlockWorld, x: i32, y: i32, z: i32) Block {
        const coords = worldToChunk(x, y, z);
        if (self.getChunk(coords.cx, coords.cy, coords.cz)) |chunk| {
            return chunk.getBlock(coords.lx, coords.ly, coords.lz);
        }
        return .air;
    }

    /// Set block at world position
    pub fn setBlock(self: *BlockWorld, x: i32, y: i32, z: i32, block: Block) !void {
        const coords = worldToChunk(x, y, z);
        const chunk = try self.getOrCreateChunk(coords.cx, coords.cy, coords.cz);
        chunk.setBlock(coords.lx, coords.ly, coords.lz, block);
    }

    /// Generate flat terrain
    pub fn generateFlat(self: *BlockWorld, chunk_radius: i32, height: i32) !void {
        var cx: i32 = -chunk_radius;
        while (cx <= chunk_radius) : (cx += 1) {
            var cz: i32 = -chunk_radius;
            while (cz <= chunk_radius) : (cz += 1) {
                // Only ground level chunks
                var cy: i32 = -1;
                while (cy <= 0) : (cy += 1) {
                    const chunk = try self.getOrCreateChunk(cx, cy, cz);

                    var y: usize = 0;
                    while (y < CHUNK_SIZE) : (y += 1) {
                        const world_y = cy * CHUNK_SIZE_I + @as(i32, @intCast(y));
                        if (world_y >= height) continue;

                        var x: usize = 0;
                        while (x < CHUNK_SIZE) : (x += 1) {
                            var z: usize = 0;
                            while (z < CHUNK_SIZE) : (z += 1) {
                                const block: Block = if (world_y == height - 1)
                                    .grass
                                else if (world_y >= height - 4)
                                    .dirt
                                else
                                    .stone;

                                chunk.setBlock(x, y, z, block);
                            }
                        }
                    }
                }
            }
        }
    }

    /// Raycast to find block
    pub fn raycastBlock(self: *BlockWorld, origin: math.Vec3, direction: math.Vec3, max_distance: f32) ?struct {
        block_pos: [3]i32,
        face_normal: [3]i32,
        block: Block,
        distance: f32,
    } {
        // DDA-style voxel traversal
        var pos = origin;
        const step = math.Vec3.scale(math.Vec3.normalize(direction), 0.1);
        var dist: f32 = 0;

        while (dist < max_distance) {
            const bx: i32 = @intFromFloat(@floor(pos.x()));
            const by: i32 = @intFromFloat(@floor(pos.y()));
            const bz: i32 = @intFromFloat(@floor(pos.z()));

            const block = self.getBlock(bx, by, bz);
            if (block.isSolid()) {
                // Calculate face normal
                const center = math.Vec3.init(
                    @as(f32, @floatFromInt(bx)) + 0.5,
                    @as(f32, @floatFromInt(by)) + 0.5,
                    @as(f32, @floatFromInt(bz)) + 0.5,
                );
                const diff = math.Vec3.sub(origin, center);

                var normal: [3]i32 = .{ 0, 0, 0 };
                if (@abs(diff.x()) > @abs(diff.y()) and @abs(diff.x()) > @abs(diff.z())) {
                    normal[0] = if (diff.x() > 0) 1 else -1;
                } else if (@abs(diff.y()) > @abs(diff.z())) {
                    normal[1] = if (diff.y() > 0) 1 else -1;
                } else {
                    normal[2] = if (diff.z() > 0) 1 else -1;
                }

                return .{
                    .block_pos = .{ bx, by, bz },
                    .face_normal = normal,
                    .block = block,
                    .distance = dist,
                };
            }

            pos = math.Vec3.add(pos, step);
            dist += 0.1;
        }

        return null;
    }

    /// Update physics colliders for blocks near position
    pub fn updatePhysicsNear(self: *BlockWorld, position: math.Vec3, radius: i32) !void {
        self.physics_world.clearStaticColliders();

        const px: i32 = @intFromFloat(@floor(position.x()));
        const py: i32 = @intFromFloat(@floor(position.y()));
        const pz: i32 = @intFromFloat(@floor(position.z()));

        var y = py - radius;
        while (y <= py + radius) : (y += 1) {
            var x = px - radius;
            while (x <= px + radius) : (x += 1) {
                var z = pz - radius;
                while (z <= pz + radius) : (z += 1) {
                    const block = self.getBlock(x, y, z);
                    if (block.isSolid()) {
                        const aabb = physics.AABB.unitCube(math.Vec3.init(
                            @floatFromInt(x),
                            @floatFromInt(y),
                            @floatFromInt(z),
                        ));
                        try self.physics_world.addStaticCollider(aabb);
                    }
                }
            }
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "chunk get/set block" {
    var chunk = Chunk.init(0, 0, 0);
    chunk.setBlock(5, 5, 5, .stone);
    try std.testing.expectEqual(Block.stone, chunk.getBlock(5, 5, 5));
    try std.testing.expectEqual(Block.air, chunk.getBlock(0, 0, 0));
}

test "world block operations" {
    const allocator = std.testing.allocator;
    var world = BlockWorld.init(allocator);
    defer world.deinit();

    try world.setBlock(10, 5, 10, .grass);
    try std.testing.expectEqual(Block.grass, world.getBlock(10, 5, 10));
    try std.testing.expectEqual(Block.air, world.getBlock(0, 100, 0));
}

test "world to chunk coords" {
    const coords = BlockWorld.worldToChunk(-5, 20, 33);
    try std.testing.expectEqual(@as(i32, -1), coords.cx);
    try std.testing.expectEqual(@as(i32, 1), coords.cy);
    try std.testing.expectEqual(@as(i32, 2), coords.cz);
}
