//! Chunk Streaming and Management System
//!
//! Manages chunk loading, unloading, and prioritization for large worlds.
//! Supports background loading and memory management for efficient streaming.

const std = @import("std");
const math = @import("../math/math.zig");
const chunk_lod = @import("chunk_lod.zig");
const culling = @import("../render/culling.zig");

/// Chunk coordinate key for hash map storage
pub const ChunkCoord = struct {
    x: i32,
    y: i32,
    z: i32,

    const Self = @This();

    pub fn init(x: i32, y: i32, z: i32) Self {
        return .{ .x = x, .y = y, .z = z };
    }

    /// Hash function for use with HashMap
    pub fn hash(self: Self) u64 {
        var h: u64 = 0;
        h ^= @as(u64, @bitCast(@as(i64, self.x))) *% 0x517cc1b727220a95;
        h ^= @as(u64, @bitCast(@as(i64, self.y))) *% 0x5851f42d4c957f2d;
        h ^= @as(u64, @bitCast(@as(i64, self.z))) *% 0x9e3779b97f4a7c15;
        return h;
    }

    /// Equality check for HashMap
    pub fn eql(a: Self, b: Self) bool {
        return a.x == b.x and a.y == b.y and a.z == b.z;
    }

    /// Get distance squared from another coordinate
    pub fn distanceSquared(self: Self, other: Self) i64 {
        const dx: i64 = @as(i64, self.x) - @as(i64, other.x);
        const dy: i64 = @as(i64, self.y) - @as(i64, other.y);
        const dz: i64 = @as(i64, self.z) - @as(i64, other.z);
        return dx * dx + dy * dy + dz * dz;
    }

    /// Convert to world position (chunk origin)
    pub fn toWorldPos(self: Self, chunk_size: f32) math.Vec3 {
        return math.Vec3.init(
            @as(f32, @floatFromInt(self.x)) * chunk_size,
            @as(f32, @floatFromInt(self.y)) * chunk_size,
            @as(f32, @floatFromInt(self.z)) * chunk_size,
        );
    }

    /// Create from world position
    pub fn fromWorldPos(pos: math.Vec3, chunk_size: f32) Self {
        return .{
            .x = @intFromFloat(@floor(pos.x() / chunk_size)),
            .y = @intFromFloat(@floor(pos.y() / chunk_size)),
            .z = @intFromFloat(@floor(pos.z() / chunk_size)),
        };
    }
};

/// Chunk load request with priority
pub const ChunkLoadRequest = struct {
    coord: ChunkCoord,
    priority: f32,
    lod_level: chunk_lod.LODLevel,

    pub fn lessThan(_: void, a: ChunkLoadRequest, b: ChunkLoadRequest) std.math.Order {
        // Lower priority value = higher priority (load first)
        return std.math.order(a.priority, b.priority);
    }
};

/// Chunk state tracking
pub const ChunkState = enum {
    unloaded, // Not in memory
    loading, // Currently being generated/loaded
    loaded, // Ready to use
    dirty, // Needs mesh regeneration
    unloading, // Being removed from memory
};

/// Cached chunk mesh data for efficient rendering
pub const ChunkMeshData = struct {
    /// Vertex count
    vertex_count: u32 = 0,
    /// Index count
    index_count: u32 = 0,
    /// Is mesh valid and up-to-date
    is_valid: bool = false,
    /// LOD level this mesh was generated for
    lod_level: chunk_lod.LODLevel = .full,
    /// Generation timestamp for cache invalidation
    generation: u64 = 0,

    const Self = @This();

    pub fn invalidate(self: *Self) void {
        self.is_valid = false;
    }

    pub fn markValid(self: *Self, lod: chunk_lod.LODLevel, gen: u64) void {
        self.is_valid = true;
        self.lod_level = lod;
        self.generation = gen;
    }
};

/// Chunk entry with state and metadata
pub const ChunkEntry = struct {
    coord: ChunkCoord,
    state: ChunkState,
    mesh_data: ChunkMeshData,
    last_accessed: u64, // Frame number when last accessed
    distance_sq: i64, // Distance squared from player (for unloading)

    const Self = @This();

    pub fn init(coord: ChunkCoord) Self {
        return .{
            .coord = coord,
            .state = .unloaded,
            .mesh_data = .{},
            .last_accessed = 0,
            .distance_sq = 0,
        };
    }
};

/// Context for HashMap operations
pub const ChunkCoordContext = struct {
    pub fn hash(_: ChunkCoordContext, coord: ChunkCoord) u64 {
        return coord.hash();
    }

    pub fn eql(_: ChunkCoordContext, a: ChunkCoord, b: ChunkCoord) bool {
        return ChunkCoord.eql(a, b);
    }
};

/// Chunk streaming manager
pub const ChunkManager = struct {
    allocator: std.mem.Allocator,
    /// Currently loaded chunks
    loaded_chunks: std.HashMap(ChunkCoord, ChunkEntry, ChunkCoordContext, 80),
    /// Queue of chunks waiting to be loaded (priority queue)
    loading_queue: std.PriorityQueue(ChunkLoadRequest, void, ChunkLoadRequest.lessThan),
    /// Queue of chunks to unload
    unload_queue: std.ArrayList(ChunkCoord),
    /// Current render distance setting
    render_distance: chunk_lod.RenderDistance,
    /// LOD manager
    lod: chunk_lod.ChunkLOD,
    /// Chunk size in world units
    chunk_size: f32,
    /// Maximum number of loaded chunks
    max_loaded_chunks: u32,
    /// Chunks to load per frame
    chunks_per_frame: u32,
    /// Current frame number
    frame_number: u64,
    /// Statistics
    stats: ChunkManagerStats,
    /// Last known player position (chunk coordinates)
    last_player_chunk: ChunkCoord,
    /// Vertical chunk range to load (below and above player)
    vertical_range: struct { below: i32, above: i32 },

    const Self = @This();

    /// Initialize chunk manager with default settings
    pub fn init(allocator: std.mem.Allocator) Self {
        return initWithConfig(allocator, .{});
    }

    /// Configuration options
    pub const Config = struct {
        render_distance: chunk_lod.RenderDistance = .normal,
        chunk_size: f32 = 16.0,
        max_loaded_chunks: u32 = 4096,
        chunks_per_frame: u32 = 4,
        vertical_below: i32 = 2,
        vertical_above: i32 = 3,
    };

    /// Initialize with custom configuration
    pub fn initWithConfig(allocator: std.mem.Allocator, config: Config) Self {
        return .{
            .allocator = allocator,
            .loaded_chunks = std.HashMap(ChunkCoord, ChunkEntry, ChunkCoordContext, 80).init(allocator),
            .loading_queue = std.PriorityQueue(ChunkLoadRequest, void, ChunkLoadRequest.lessThan).init(allocator, {}),
            .unload_queue = std.ArrayList(ChunkCoord).init(allocator),
            .render_distance = config.render_distance,
            .lod = chunk_lod.ChunkLOD.initWithDistance(config.render_distance),
            .chunk_size = config.chunk_size,
            .max_loaded_chunks = config.max_loaded_chunks,
            .chunks_per_frame = config.chunks_per_frame,
            .frame_number = 0,
            .stats = .{},
            .last_player_chunk = ChunkCoord.init(0, 0, 0),
            .vertical_range = .{ .below = config.vertical_below, .above = config.vertical_above },
        };
    }

    /// Clean up all resources
    pub fn deinit(self: *Self) void {
        self.loaded_chunks.deinit();
        self.loading_queue.deinit();
        self.unload_queue.deinit();
    }

    /// Update the chunk manager based on player position
    pub fn update(self: *Self, player_pos: math.Vec3) void {
        self.frame_number += 1;
        self.stats.reset();

        const player_chunk = ChunkCoord.fromWorldPos(player_pos, self.chunk_size);

        // Check if player moved to a new chunk
        if (!ChunkCoord.eql(player_chunk, self.last_player_chunk)) {
            self.last_player_chunk = player_chunk;
            self.queueChunksAroundPlayer(player_chunk);
        }

        // Process loading queue
        self.processLoadingQueue();

        // Update loaded chunk distances and mark for unload if too far
        self.updateChunkDistances(player_chunk);

        // Process unload queue
        self.processUnloadQueue(player_chunk);
    }

    /// Queue chunks around the player for loading
    fn queueChunksAroundPlayer(self: *Self, center: ChunkCoord) void {
        const radius: i32 = @intCast(self.render_distance.getChunkRadius());

        var z = center.z - radius;
        while (z <= center.z + radius) : (z += 1) {
            var x = center.x - radius;
            while (x <= center.x + radius) : (x += 1) {
                var y = center.y - self.vertical_range.below;
                while (y <= center.y + self.vertical_range.above) : (y += 1) {
                    const coord = ChunkCoord.init(x, y, z);

                    // Skip if already loaded
                    if (self.loaded_chunks.get(coord)) |_| {
                        continue;
                    }

                    // Calculate priority based on distance and direction
                    const priority = self.calculateChunkPriority(coord, center);
                    const lod = self.getChunkLOD(coord, center);

                    // Add to loading queue
                    self.loading_queue.add(.{
                        .coord = coord,
                        .priority = priority,
                        .lod_level = lod,
                    }) catch {};
                }
            }
        }
    }

    /// Load chunks around a center position
    pub fn loadChunksAround(self: *Self, center: ChunkCoord, radius: u32) void {
        const r: i32 = @intCast(radius);

        var z = center.z - r;
        while (z <= center.z + r) : (z += 1) {
            var x = center.x - r;
            while (x <= center.x + r) : (x += 1) {
                var y = center.y - self.vertical_range.below;
                while (y <= center.y + self.vertical_range.above) : (y += 1) {
                    const coord = ChunkCoord.init(x, y, z);

                    if (self.loaded_chunks.get(coord) == null) {
                        const priority = self.calculateChunkPriority(coord, center);
                        const lod = self.getChunkLOD(coord, center);

                        self.loading_queue.add(.{
                            .coord = coord,
                            .priority = priority,
                            .lod_level = lod,
                        }) catch {};
                    }
                }
            }
        }
    }

    /// Unload chunks beyond a certain distance from center
    pub fn unloadDistantChunks(self: *Self, center: ChunkCoord, distance: u32) void {
        const max_dist_sq: i64 = @as(i64, distance) * @as(i64, distance);

        var iter = self.loaded_chunks.iterator();
        while (iter.next()) |entry| {
            const dist_sq = entry.key_ptr.distanceSquared(center);
            if (dist_sq > max_dist_sq) {
                self.unload_queue.append(entry.key_ptr.*) catch {};
            }
        }
    }

    /// Prioritize chunks in the player's view direction
    pub fn prioritizeChunks(self: *Self, player_forward: math.Vec3) void {
        // Re-sort loading queue based on view direction
        var items = std.ArrayList(ChunkLoadRequest).init(self.allocator);
        defer items.deinit();

        // Extract all items
        while (self.loading_queue.removeOrNull()) |request| {
            items.append(request) catch {};
        }

        // Recalculate priorities with view direction
        const center_pos = self.last_player_chunk.toWorldPos(self.chunk_size);

        for (items.items) |*request| {
            const chunk_pos = request.coord.toWorldPos(self.chunk_size);
            const to_chunk = math.Vec3.normalize(math.Vec3.sub(chunk_pos, center_pos));
            const dot = math.Vec3.dot(player_forward, to_chunk);

            // Adjust priority: chunks in front get lower priority (loaded first)
            request.priority *= (1.0 - dot * 0.5);
        }

        // Re-add to queue
        for (items.items) |request| {
            self.loading_queue.add(request) catch {};
        }
    }

    /// Process the loading queue (call each frame)
    fn processLoadingQueue(self: *Self) void {
        var loaded_this_frame: u32 = 0;

        while (loaded_this_frame < self.chunks_per_frame) {
            const request = self.loading_queue.removeOrNull() orelse break;

            // Skip if already loaded
            if (self.loaded_chunks.get(request.coord)) |_| {
                continue;
            }

            // Check memory limit
            if (self.loaded_chunks.count() >= self.max_loaded_chunks) {
                // Re-queue and try to unload some chunks first
                self.loading_queue.add(request) catch {};
                break;
            }

            // Mark chunk as loading
            var entry = ChunkEntry.init(request.coord);
            entry.state = .loading;
            entry.last_accessed = self.frame_number;
            entry.mesh_data.lod_level = request.lod_level;

            self.loaded_chunks.put(request.coord, entry) catch |err| {
                std.log.warn("Failed to register loaded chunk ({},{},{}): {}", .{
                    request.coord.x, request.coord.y, request.coord.z, err,
                });
                continue;
            };
            loaded_this_frame += 1;
            self.stats.chunks_loaded += 1;
        }
    }

    /// Update distance calculations for loaded chunks
    fn updateChunkDistances(self: *Self, center: ChunkCoord) void {
        const max_dist_sq: i64 = blk: {
            const r: i64 = @intCast(self.render_distance.getChunkRadius() + 2);
            break :blk r * r;
        };

        var iter = self.loaded_chunks.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.distance_sq = entry.key_ptr.distanceSquared(center);

            // Mark for unloading if too far
            if (entry.value_ptr.distance_sq > max_dist_sq) {
                self.unload_queue.append(entry.key_ptr.*) catch {};
            }
        }
    }

    /// Process the unload queue
    fn processUnloadQueue(self: *Self, center: ChunkCoord) void {
        _ = center;

        for (self.unload_queue.items) |coord| {
            _ = self.loaded_chunks.remove(coord);
            self.stats.chunks_unloaded += 1;
        }

        self.unload_queue.clearRetainingCapacity();
    }

    /// Calculate loading priority for a chunk
    fn calculateChunkPriority(_: *Self, coord: ChunkCoord, center: ChunkCoord) f32 {
        const dx: f32 = @floatFromInt(coord.x - center.x);
        const dy: f32 = @floatFromInt(coord.y - center.y);
        const dz: f32 = @floatFromInt(coord.z - center.z);

        // Euclidean distance as base priority
        return @sqrt(dx * dx + dy * dy * 0.5 + dz * dz); // Y weighted less
    }

    /// Get LOD level for a chunk based on distance
    fn getChunkLOD(self: *Self, coord: ChunkCoord, center: ChunkCoord) chunk_lod.LODLevel {
        const chunk_pos = coord.toWorldPos(self.chunk_size);
        const center_pos = center.toWorldPos(self.chunk_size);
        const distance = math.Vec3.distance(chunk_pos, center_pos);

        return self.lod.getLODLevel(distance);
    }

    /// Check if a chunk is loaded
    pub fn isChunkLoaded(self: *const Self, coord: ChunkCoord) bool {
        if (self.loaded_chunks.get(coord)) |entry| {
            return entry.state == .loaded or entry.state == .dirty;
        }
        return false;
    }

    /// Get chunk entry if loaded
    pub fn getChunkEntry(self: *Self, coord: ChunkCoord) ?*ChunkEntry {
        return self.loaded_chunks.getPtr(coord);
    }

    /// Mark a chunk as dirty (needs mesh regeneration)
    pub fn markChunkDirty(self: *Self, coord: ChunkCoord) void {
        if (self.loaded_chunks.getPtr(coord)) |entry| {
            entry.state = .dirty;
            entry.mesh_data.invalidate();
        }
    }

    /// Mark a chunk as loaded (after terrain generation)
    pub fn markChunkLoaded(self: *Self, coord: ChunkCoord) void {
        if (self.loaded_chunks.getPtr(coord)) |entry| {
            entry.state = .loaded;
            entry.last_accessed = self.frame_number;
        }
    }

    /// Set render distance
    pub fn setRenderDistance(self: *Self, distance: chunk_lod.RenderDistance) void {
        self.render_distance = distance;
        self.lod.setRenderDistance(distance);
    }

    /// Get current statistics
    pub fn getStats(self: *const Self) ChunkManagerStats {
        var stats = self.stats;
        stats.loaded_count = @intCast(self.loaded_chunks.count());
        stats.queue_size = @intCast(self.loading_queue.count());
        return stats;
    }

    /// Get iterator over loaded chunk coordinates
    pub fn getLoadedChunks(self: *const Self) LoadedChunkIterator {
        return .{ .inner = self.loaded_chunks.keyIterator() };
    }

    pub const LoadedChunkIterator = struct {
        inner: std.HashMap(ChunkCoord, ChunkEntry, ChunkCoordContext, 80).KeyIterator,

        pub fn next(self: *LoadedChunkIterator) ?ChunkCoord {
            if (self.inner.next()) |key| {
                return key.*;
            }
            return null;
        }
    };
};

/// Chunk manager statistics
pub const ChunkManagerStats = struct {
    loaded_count: u32 = 0,
    queue_size: u32 = 0,
    chunks_loaded: u32 = 0,
    chunks_unloaded: u32 = 0,
    meshes_generated: u32 = 0,
    meshes_cached: u32 = 0,

    const Self = @This();

    pub fn reset(self: *Self) void {
        self.chunks_loaded = 0;
        self.chunks_unloaded = 0;
        self.meshes_generated = 0;
        self.meshes_cached = 0;
    }
};

/// Greedy meshing utilities for chunk mesh optimization
pub const GreedyMesher = struct {
    /// Face data for greedy meshing
    pub const MeshFace = struct {
        /// Position of the face (in block coordinates)
        x: u8,
        y: u8,
        z: u8,
        /// Width and height of the merged face
        width: u8,
        height: u8,
        /// Face direction (0-5 for +-X, +-Y, +-Z)
        direction: u3,
        /// Block type for color/texture
        block_type: u8,
    };

    /// Check if two blocks can be merged into the same face
    pub fn canMerge(block_a: u8, block_b: u8) bool {
        // Same block type = can merge
        return block_a == block_b and block_a != 0; // 0 = air
    }

    /// Get the number of faces that would be generated for a chunk
    /// Returns an estimate based on block distribution
    pub fn estimateFaceCount(_: u32, exposed_faces: u32) u32 {
        // Greedy meshing typically reduces face count by 30-50%
        // depending on terrain uniformity
        return exposed_faces * 7 / 10;
    }
};

/// Occlusion culling helper for block visibility
pub const OcclusionCuller = struct {
    /// Check if a block is completely surrounded by solid blocks
    pub fn isBlockOccluded(
        get_block_fn: *const fn (x: i32, y: i32, z: i32) callconv(.C) bool,
        x: i32,
        y: i32,
        z: i32,
    ) bool {
        // Check all 6 neighbors
        return get_block_fn(x + 1, y, z) and
            get_block_fn(x - 1, y, z) and
            get_block_fn(x, y + 1, z) and
            get_block_fn(x, y - 1, z) and
            get_block_fn(x, y, z + 1) and
            get_block_fn(x, y, z - 1);
    }

    /// Face visibility flags for a chunk
    pub const ChunkFaceVisibility = packed struct {
        positive_x: bool = true,
        negative_x: bool = true,
        positive_y: bool = true,
        negative_y: bool = true,
        positive_z: bool = true,
        negative_z: bool = true,
        _padding: u2 = 0,

        pub fn allVisible() ChunkFaceVisibility {
            return .{};
        }

        pub fn setFace(self: *ChunkFaceVisibility, face: u3, visible: bool) void {
            switch (face) {
                0 => self.positive_x = visible,
                1 => self.negative_x = visible,
                2 => self.positive_y = visible,
                3 => self.negative_y = visible,
                4 => self.positive_z = visible,
                5 => self.negative_z = visible,
                else => {},
            }
        }

        pub fn isFaceVisible(self: *const ChunkFaceVisibility, face: u3) bool {
            return switch (face) {
                0 => self.positive_x,
                1 => self.negative_x,
                2 => self.positive_y,
                3 => self.negative_y,
                4 => self.positive_z,
                5 => self.negative_z,
                else => true,
            };
        }
    };
};

/// Chunk pool for memory reuse
pub const ChunkPool = struct {
    allocator: std.mem.Allocator,
    free_list: std.ArrayList(*ChunkData),
    max_pool_size: u32,

    pub const ChunkData = struct {
        blocks: [16 * 16 * 16]u8,
        light_data: [16 * 16 * 16]u8,
    };

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, max_size: u32) Self {
        return .{
            .allocator = allocator,
            .free_list = std.ArrayList(*ChunkData).init(allocator),
            .max_pool_size = max_size,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.free_list.items) |chunk| {
            self.allocator.destroy(chunk);
        }
        self.free_list.deinit();
    }

    /// Get a chunk from the pool or allocate a new one
    pub fn acquire(self: *Self) !*ChunkData {
        if (self.free_list.popOrNull()) |chunk| {
            return chunk;
        }
        return try self.allocator.create(ChunkData);
    }

    /// Return a chunk to the pool
    pub fn release(self: *Self, chunk: *ChunkData) void {
        if (self.free_list.items.len < self.max_pool_size) {
            self.free_list.append(chunk) catch {
                self.allocator.destroy(chunk);
            };
        } else {
            self.allocator.destroy(chunk);
        }
    }

    /// Clear all pooled chunks
    pub fn clear(self: *Self) void {
        for (self.free_list.items) |chunk| {
            self.allocator.destroy(chunk);
        }
        self.free_list.clearRetainingCapacity();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "chunk coord hash and equality" {
    const c1 = ChunkCoord.init(1, 2, 3);
    const c2 = ChunkCoord.init(1, 2, 3);
    const c3 = ChunkCoord.init(4, 5, 6);

    try std.testing.expect(ChunkCoord.eql(c1, c2));
    try std.testing.expect(!ChunkCoord.eql(c1, c3));
    try std.testing.expectEqual(c1.hash(), c2.hash());
}

test "chunk coord distance" {
    const c1 = ChunkCoord.init(0, 0, 0);
    const c2 = ChunkCoord.init(3, 4, 0);

    // 3^2 + 4^2 + 0^2 = 9 + 16 = 25
    try std.testing.expectEqual(@as(i64, 25), c1.distanceSquared(c2));
}

test "chunk coord from world pos" {
    const pos = math.Vec3.init(32.5, -8.0, 47.9);
    const coord = ChunkCoord.fromWorldPos(pos, 16.0);

    try std.testing.expectEqual(@as(i32, 2), coord.x);
    try std.testing.expectEqual(@as(i32, -1), coord.y);
    try std.testing.expectEqual(@as(i32, 2), coord.z);
}

test "chunk manager initialization" {
    const allocator = std.testing.allocator;
    var manager = ChunkManager.init(allocator);
    defer manager.deinit();

    try std.testing.expectEqual(chunk_lod.RenderDistance.normal, manager.render_distance);
    try std.testing.expectEqual(@as(u32, 0), manager.loaded_chunks.count());
}

test "chunk pool acquire and release" {
    const allocator = std.testing.allocator;
    var pool = ChunkPool.init(allocator, 10);
    defer pool.deinit();

    const chunk1 = try pool.acquire();
    const chunk2 = try pool.acquire();

    pool.release(chunk1);
    pool.release(chunk2);

    try std.testing.expectEqual(@as(usize, 2), pool.free_list.items.len);
}

test "chunk face visibility" {
    var vis = OcclusionCuller.ChunkFaceVisibility.allVisible();

    try std.testing.expect(vis.positive_x);
    try std.testing.expect(vis.isFaceVisible(0));

    vis.setFace(0, false);
    try std.testing.expect(!vis.positive_x);
    try std.testing.expect(!vis.isFaceVisible(0));
}
