//! Chunk Level of Detail (LOD) System
//!
//! Provides LOD management for chunk rendering, reducing detail for distant chunks
//! to improve performance while maintaining visual quality for nearby chunks.

const std = @import("std");
const math = @import("../math/math.zig");

/// LOD levels for chunk rendering
pub const LODLevel = enum(u3) {
    full = 0, // All blocks rendered (distance: 0-32)
    half = 1, // Every other block (distance: 32-64)
    quarter = 2, // Every 4th block (distance: 64-128)
    distant = 3, // Just colored box (distance: 128-256)
    unloaded = 4, // Not loaded/rendered (distance: 256+)

    /// Get the block skip value for this LOD level
    pub fn getBlockSkip(self: LODLevel) u32 {
        return switch (self) {
            .full => 1,
            .half => 2,
            .quarter => 4,
            .distant => 16, // Render as single colored box
            .unloaded => 0, // Don't render
        };
    }

    /// Get human-readable name for debugging
    pub fn getName(self: LODLevel) []const u8 {
        return switch (self) {
            .full => "Full",
            .half => "Half",
            .quarter => "Quarter",
            .distant => "Distant",
            .unloaded => "Unloaded",
        };
    }
};

/// Render distance presets
pub const RenderDistance = enum(u8) {
    near = 4, // 4 chunks (64 blocks)
    normal = 8, // 8 chunks (128 blocks)
    far = 16, // 16 chunks (256 blocks)
    extreme = 32, // 32 chunks (512 blocks)

    /// Get the chunk radius for this render distance
    pub fn getChunkRadius(self: RenderDistance) u32 {
        return @intFromEnum(self);
    }

    /// Get the maximum world distance in blocks
    pub fn getWorldDistance(self: RenderDistance) f32 {
        return @as(f32, @floatFromInt(@intFromEnum(self))) * 16.0;
    }

    /// Get LOD transition distances based on render distance
    pub fn getLODDistances(self: RenderDistance) LODDistances {
        const base = self.getWorldDistance();
        return .{
            .full_to_half = base * 0.25, // 25% of render distance
            .half_to_quarter = base * 0.5, // 50% of render distance
            .quarter_to_distant = base * 0.75, // 75% of render distance
            .distant_to_unload = base, // 100% of render distance
        };
    }
};

/// LOD transition distances
pub const LODDistances = struct {
    full_to_half: f32 = 32.0,
    half_to_quarter: f32 = 64.0,
    quarter_to_distant: f32 = 128.0,
    distant_to_unload: f32 = 256.0,

    /// Default distances for normal render distance
    pub const DEFAULT = LODDistances{
        .full_to_half = 32.0,
        .half_to_quarter = 64.0,
        .quarter_to_distant = 128.0,
        .distant_to_unload = 256.0,
    };
};

/// Chunk LOD calculation and management
pub const ChunkLOD = struct {
    distances: LODDistances,
    render_distance: RenderDistance,

    const Self = @This();

    /// Initialize with default settings
    pub fn init() Self {
        return .{
            .distances = LODDistances.DEFAULT,
            .render_distance = .normal,
        };
    }

    /// Initialize with a specific render distance
    pub fn initWithDistance(render_dist: RenderDistance) Self {
        return .{
            .distances = render_dist.getLODDistances(),
            .render_distance = render_dist,
        };
    }

    /// Set render distance and recalculate LOD distances
    pub fn setRenderDistance(self: *Self, render_dist: RenderDistance) void {
        self.render_distance = render_dist;
        self.distances = render_dist.getLODDistances();
    }

    /// Get LOD level for a given distance from the camera
    pub fn getLODLevel(self: *const Self, distance: f32) LODLevel {
        if (distance >= self.distances.distant_to_unload) {
            return .unloaded;
        } else if (distance >= self.distances.quarter_to_distant) {
            return .distant;
        } else if (distance >= self.distances.half_to_quarter) {
            return .quarter;
        } else if (distance >= self.distances.full_to_half) {
            return .half;
        }
        return .full;
    }

    /// Get LOD level based on chunk position and camera position
    pub fn getLODLevelForChunk(
        self: *const Self,
        chunk_x: i32,
        chunk_y: i32,
        chunk_z: i32,
        camera_pos: math.Vec3,
        chunk_size: f32,
    ) LODLevel {
        const distance = self.getChunkDistance(chunk_x, chunk_y, chunk_z, camera_pos, chunk_size);
        return self.getLODLevel(distance);
    }

    /// Calculate distance from camera to chunk center
    pub fn getChunkDistance(
        _: *const Self,
        chunk_x: i32,
        chunk_y: i32,
        chunk_z: i32,
        camera_pos: math.Vec3,
        chunk_size: f32,
    ) f32 {
        const half_chunk = chunk_size * 0.5;
        const chunk_center = math.Vec3.init(
            @as(f32, @floatFromInt(chunk_x)) * chunk_size + half_chunk,
            @as(f32, @floatFromInt(chunk_y)) * chunk_size + half_chunk,
            @as(f32, @floatFromInt(chunk_z)) * chunk_size + half_chunk,
        );
        return math.Vec3.distance(camera_pos, chunk_center);
    }

    /// Get block skip value for a given LOD level
    pub fn getBlockSkip(_: *const Self, lod: LODLevel) u32 {
        return lod.getBlockSkip();
    }

    /// Determine if a block should be rendered at a given LOD level
    /// Uses a simple grid pattern based on LOD level
    pub fn shouldRenderBlock(_: *const Self, x: u32, y: u32, z: u32, lod: LODLevel) bool {
        const skip = lod.getBlockSkip();
        if (skip == 0) return false; // Unloaded
        if (skip == 1) return true; // Full LOD

        // For reduced LOD, only render blocks at regular intervals
        return (x % skip == 0) and (y % skip == 0) and (z % skip == 0);
    }

    /// Get a priority value for chunk loading (lower = higher priority)
    /// Takes into account distance and whether chunk is in front of camera
    pub fn getChunkPriority(
        self: *const Self,
        chunk_x: i32,
        chunk_y: i32,
        chunk_z: i32,
        camera_pos: math.Vec3,
        camera_forward: math.Vec3,
        chunk_size: f32,
    ) f32 {
        const distance = self.getChunkDistance(chunk_x, chunk_y, chunk_z, camera_pos, chunk_size);

        // Calculate direction to chunk
        const half_chunk = chunk_size * 0.5;
        const chunk_center = math.Vec3.init(
            @as(f32, @floatFromInt(chunk_x)) * chunk_size + half_chunk,
            @as(f32, @floatFromInt(chunk_y)) * chunk_size + half_chunk,
            @as(f32, @floatFromInt(chunk_z)) * chunk_size + half_chunk,
        );
        const to_chunk = math.Vec3.normalize(math.Vec3.sub(chunk_center, camera_pos));

        // Dot product: 1 = directly in front, -1 = directly behind
        const dot = math.Vec3.dot(camera_forward, to_chunk);

        // Priority formula: distance * (1 - dot * 0.5)
        // Chunks in front get priority (lower score), behind get penalty (higher score)
        const direction_factor = 1.0 - (dot * 0.5);
        return distance * direction_factor;
    }

    /// Get the maximum render distance in blocks
    pub fn getMaxRenderDistance(self: *const Self) f32 {
        return self.distances.distant_to_unload;
    }

    /// Get the chunk radius for the current render distance
    pub fn getChunkRadius(self: *const Self) u32 {
        return self.render_distance.getChunkRadius();
    }
};

/// LOD statistics for debugging and monitoring
pub const LODStats = struct {
    full_count: u32 = 0,
    half_count: u32 = 0,
    quarter_count: u32 = 0,
    distant_count: u32 = 0,
    unloaded_count: u32 = 0,
    total_rendered: u32 = 0,

    const Self = @This();

    /// Reset all counters
    pub fn reset(self: *Self) void {
        self.full_count = 0;
        self.half_count = 0;
        self.quarter_count = 0;
        self.distant_count = 0;
        self.unloaded_count = 0;
        self.total_rendered = 0;
    }

    /// Record a chunk at a given LOD level
    pub fn record(self: *Self, lod: LODLevel) void {
        switch (lod) {
            .full => self.full_count += 1,
            .half => self.half_count += 1,
            .quarter => self.quarter_count += 1,
            .distant => self.distant_count += 1,
            .unloaded => self.unloaded_count += 1,
        }
        if (lod != .unloaded) {
            self.total_rendered += 1;
        }
    }

    /// Get the total number of visible chunks
    pub fn getVisibleCount(self: *const Self) u32 {
        return self.total_rendered;
    }

    /// Get the estimated vertex reduction ratio
    pub fn getReductionRatio(self: *const Self) f32 {
        if (self.total_rendered == 0) return 0.0;

        // Calculate effective vertex count vs full detail
        const full_verts: f32 = @floatFromInt(self.full_count);
        const half_verts: f32 = @as(f32, @floatFromInt(self.half_count)) * 0.125; // 1/8 vertices
        const quarter_verts: f32 = @as(f32, @floatFromInt(self.quarter_count)) * 0.015625; // 1/64 vertices
        const distant_verts: f32 = @as(f32, @floatFromInt(self.distant_count)) * 0.001; // ~0 vertices

        const total_effective = full_verts + half_verts + quarter_verts + distant_verts;
        const total_full: f32 = @floatFromInt(self.total_rendered);

        return total_effective / total_full;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "LOD level distances" {
    const lod = ChunkLOD.init();

    try std.testing.expectEqual(LODLevel.full, lod.getLODLevel(0.0));
    try std.testing.expectEqual(LODLevel.full, lod.getLODLevel(31.0));
    try std.testing.expectEqual(LODLevel.half, lod.getLODLevel(33.0));
    try std.testing.expectEqual(LODLevel.quarter, lod.getLODLevel(65.0));
    try std.testing.expectEqual(LODLevel.distant, lod.getLODLevel(130.0));
    try std.testing.expectEqual(LODLevel.unloaded, lod.getLODLevel(300.0));
}

test "block skip values" {
    try std.testing.expectEqual(@as(u32, 1), LODLevel.full.getBlockSkip());
    try std.testing.expectEqual(@as(u32, 2), LODLevel.half.getBlockSkip());
    try std.testing.expectEqual(@as(u32, 4), LODLevel.quarter.getBlockSkip());
    try std.testing.expectEqual(@as(u32, 16), LODLevel.distant.getBlockSkip());
    try std.testing.expectEqual(@as(u32, 0), LODLevel.unloaded.getBlockSkip());
}

test "should render block" {
    const lod = ChunkLOD.init();

    // Full LOD renders all blocks
    try std.testing.expect(lod.shouldRenderBlock(0, 0, 0, .full));
    try std.testing.expect(lod.shouldRenderBlock(1, 1, 1, .full));
    try std.testing.expect(lod.shouldRenderBlock(7, 3, 5, .full));

    // Half LOD renders every other block
    try std.testing.expect(lod.shouldRenderBlock(0, 0, 0, .half));
    try std.testing.expect(lod.shouldRenderBlock(2, 2, 2, .half));
    try std.testing.expect(!lod.shouldRenderBlock(1, 0, 0, .half));
    try std.testing.expect(!lod.shouldRenderBlock(0, 1, 0, .half));

    // Quarter LOD renders every 4th block
    try std.testing.expect(lod.shouldRenderBlock(0, 0, 0, .quarter));
    try std.testing.expect(lod.shouldRenderBlock(4, 4, 4, .quarter));
    try std.testing.expect(!lod.shouldRenderBlock(2, 2, 2, .quarter));

    // Unloaded never renders
    try std.testing.expect(!lod.shouldRenderBlock(0, 0, 0, .unloaded));
}

test "render distance presets" {
    try std.testing.expectEqual(@as(u32, 4), RenderDistance.near.getChunkRadius());
    try std.testing.expectEqual(@as(u32, 8), RenderDistance.normal.getChunkRadius());
    try std.testing.expectEqual(@as(u32, 16), RenderDistance.far.getChunkRadius());
    try std.testing.expectEqual(@as(u32, 32), RenderDistance.extreme.getChunkRadius());
}

test "LOD stats tracking" {
    var stats = LODStats{};

    stats.record(.full);
    stats.record(.full);
    stats.record(.half);
    stats.record(.distant);
    stats.record(.unloaded);

    try std.testing.expectEqual(@as(u32, 2), stats.full_count);
    try std.testing.expectEqual(@as(u32, 1), stats.half_count);
    try std.testing.expectEqual(@as(u32, 1), stats.distant_count);
    try std.testing.expectEqual(@as(u32, 1), stats.unloaded_count);
    try std.testing.expectEqual(@as(u32, 4), stats.getVisibleCount());
}

test "chunk priority calculation" {
    const lod = ChunkLOD.init();

    const camera_pos = math.Vec3.init(0, 0, 0);
    const camera_forward = math.Vec3.init(0, 0, 1);

    // Chunk in front should have lower priority (load first)
    const front_priority = lod.getChunkPriority(0, 0, 2, camera_pos, camera_forward, 16.0);
    // Chunk behind should have higher priority (load later)
    const back_priority = lod.getChunkPriority(0, 0, -2, camera_pos, camera_forward, 16.0);

    try std.testing.expect(front_priority < back_priority);
}
