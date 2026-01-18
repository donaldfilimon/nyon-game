//! Mob Spawning System
//!
//! Handles random mob spawning in loaded chunks based on biome,
//! light level, and spawn rules.

const std = @import("std");
const math = @import("../math/math.zig");
const biome_mod = @import("../world/biome.zig");
const ecs = @import("ecs.zig");
const mobs = @import("mobs.zig");
const components = @import("components.zig");

const MobType = components.MobType;
const BiomeType = biome_mod.BiomeType;
const EntityWorld = ecs.EntityWorld;
const Entity = ecs.Entity;

/// Spawn configuration constants
pub const SpawnConfig = struct {
    /// Maximum mobs per chunk
    pub const MAX_MOBS_PER_CHUNK: u32 = 8;
    /// Minimum distance from player to spawn
    pub const MIN_SPAWN_DISTANCE: f32 = 24.0;
    /// Maximum distance from player to spawn
    pub const MAX_SPAWN_DISTANCE: f32 = 128.0;
    /// Light level threshold for hostile spawns (0-15)
    pub const HOSTILE_LIGHT_THRESHOLD: u8 = 7;
    /// Spawn attempt interval (seconds)
    pub const SPAWN_INTERVAL: f32 = 1.0;
    /// Chance per spawn attempt (0-1)
    pub const SPAWN_CHANCE: f32 = 0.1;
    /// Chunk size for mob counting
    pub const CHUNK_SIZE: i32 = 16;
};

/// Spawn weight for a mob in a biome
pub const SpawnEntry = struct {
    mob_type: MobType,
    weight: u32,
    min_group: u8,
    max_group: u8,
    /// Minimum light level for spawn (0 = dark, 15 = bright)
    min_light: u8,
    /// Maximum light level for spawn
    max_light: u8,
};

/// Spawner state
pub const MobSpawner = struct {
    allocator: std.mem.Allocator,
    spawn_timer: f32,
    rng: std.Random.DefaultPrng,
    /// Mob count per chunk (chunk_hash -> count)
    chunk_mob_counts: std.AutoHashMap(u64, u32),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, seed: u64) Self {
        return .{
            .allocator = allocator,
            .spawn_timer = 0,
            .rng = std.Random.DefaultPrng.init(seed),
            .chunk_mob_counts = std.AutoHashMap(u64, u32).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.chunk_mob_counts.deinit();
    }

    /// Update spawner and potentially spawn mobs
    pub fn update(
        self: *Self,
        world: *EntityWorld,
        player_pos: math.Vec3,
        biome_generator: anytype,
        get_light_level: ?*const fn (x: i32, y: i32, z: i32) u8,
        get_surface_height: ?*const fn (x: i32, z: i32) i32,
        delta_time: f32,
    ) !void {
        self.spawn_timer += delta_time;

        if (self.spawn_timer < SpawnConfig.SPAWN_INTERVAL) return;
        self.spawn_timer = 0;

        // Random chance to skip
        if (self.rng.random().float(f32) > SpawnConfig.SPAWN_CHANCE) return;

        // Pick random spawn position around player
        const spawn_pos = self.pickSpawnPosition(player_pos, get_surface_height);
        if (spawn_pos == null) return;
        const pos = spawn_pos.?;

        // Get biome at spawn position
        const biome = biome_generator.getBiome(@intFromFloat(pos.x()), @intFromFloat(pos.z()));

        // Get light level
        var light_level: u8 = 15; // Default to bright (surface)
        if (get_light_level) |get_light| {
            light_level = get_light(
                @intFromFloat(pos.x()),
                @intFromFloat(pos.y()),
                @intFromFloat(pos.z()),
            );
        }

        // Check mob cap for chunk
        const chunk_hash = chunkHash(
            @intFromFloat(pos.x()),
            @intFromFloat(pos.z()),
        );
        const current_count = self.chunk_mob_counts.get(chunk_hash) orelse 0;
        if (current_count >= SpawnConfig.MAX_MOBS_PER_CHUNK) return;

        // Pick mob type based on biome and light
        const mob_type = self.pickMobType(biome.biome_type, light_level);
        if (mob_type == null) return;

        // Spawn the mob
        const entity = try mobs.createMob(world, .{
            .mob_type = mob_type.?,
            .position = pos,
        });
        _ = entity;

        // Update chunk count
        try self.chunk_mob_counts.put(chunk_hash, current_count + 1);
    }

    /// Pick a random spawn position around the player
    fn pickSpawnPosition(
        self: *Self,
        player_pos: math.Vec3,
        get_surface_height: ?*const fn (x: i32, z: i32) i32,
    ) ?math.Vec3 {
        // Random angle and distance
        const angle = self.rng.random().float(f32) * std.math.tau;
        const dist = SpawnConfig.MIN_SPAWN_DISTANCE +
            self.rng.random().float(f32) *
                (SpawnConfig.MAX_SPAWN_DISTANCE - SpawnConfig.MIN_SPAWN_DISTANCE);

        const spawn_x = player_pos.x() + @cos(angle) * dist;
        const spawn_z = player_pos.z() + @sin(angle) * dist;

        // Get surface height
        var spawn_y: f32 = player_pos.y();
        if (get_surface_height) |get_height| {
            spawn_y = @floatFromInt(get_height(
                @intFromFloat(spawn_x),
                @intFromFloat(spawn_z),
            ) + 1);
        }

        return math.Vec3.init(spawn_x, spawn_y, spawn_z);
    }

    /// Pick a mob type based on biome and light level
    fn pickMobType(self: *Self, biome: BiomeType, light_level: u8) ?MobType {
        const entries = getSpawnEntries(biome);

        // Calculate total weight of valid entries
        var total_weight: u32 = 0;
        for (entries) |entry| {
            if (light_level >= entry.min_light and light_level <= entry.max_light) {
                total_weight += entry.weight;
            }
        }

        if (total_weight == 0) return null;

        // Random selection
        var roll = self.rng.random().uintLessThan(u32, total_weight);
        for (entries) |entry| {
            if (light_level >= entry.min_light and light_level <= entry.max_light) {
                if (roll < entry.weight) {
                    return entry.mob_type;
                }
                roll -= entry.weight;
            }
        }

        return null;
    }

    /// Notify spawner that a mob was despawned
    pub fn onMobDespawned(self: *Self, position: math.Vec3) void {
        const chunk_hash = chunkHash(
            @intFromFloat(position.x()),
            @intFromFloat(position.z()),
        );
        if (self.chunk_mob_counts.get(chunk_hash)) |count| {
            if (count > 1) {
                self.chunk_mob_counts.put(chunk_hash, count - 1) catch {};
            } else {
                // Remove entry when count reaches 0 to prevent memory leak
                _ = self.chunk_mob_counts.remove(chunk_hash);
            }
        }
    }

    /// Clear mob counts for unloaded chunks
    pub fn clearChunk(self: *Self, chunk_x: i32, chunk_z: i32) void {
        const hash = @as(u64, @bitCast(@as(i64, chunk_x))) ^ (@as(u64, @bitCast(@as(i64, chunk_z))) << 32);
        _ = self.chunk_mob_counts.remove(hash);
    }
};

/// Get spawn entries for a biome
pub fn getSpawnEntries(biome: BiomeType) []const SpawnEntry {
    return switch (biome) {
        .plains => &PLAINS_SPAWNS,
        .forest => &FOREST_SPAWNS,
        .desert => &DESERT_SPAWNS,
        .mountains => &MOUNTAIN_SPAWNS,
        .ocean => &OCEAN_SPAWNS,
        .beach => &BEACH_SPAWNS,
        .snow => &SNOW_SPAWNS,
        .swamp => &SWAMP_SPAWNS,
        .taiga => &TAIGA_SPAWNS,
        .savanna => &SAVANNA_SPAWNS,
    };
}

/// Hash function for chunk coordinates
fn chunkHash(x: i32, z: i32) u64 {
    const chunk_x = @divFloor(x, SpawnConfig.CHUNK_SIZE);
    const chunk_z = @divFloor(z, SpawnConfig.CHUNK_SIZE);
    return @as(u64, @bitCast(@as(i64, chunk_x))) ^ (@as(u64, @bitCast(@as(i64, chunk_z))) << 32);
}

// ============================================================================
// Spawn Tables per Biome
// ============================================================================

const PLAINS_SPAWNS = [_]SpawnEntry{
    // Passive mobs (daylight)
    .{ .mob_type = .pig, .weight = 10, .min_group = 2, .max_group = 4, .min_light = 9, .max_light = 15 },
    .{ .mob_type = .cow, .weight = 8, .min_group = 2, .max_group = 4, .min_light = 9, .max_light = 15 },
    .{ .mob_type = .sheep, .weight = 12, .min_group = 2, .max_group = 4, .min_light = 9, .max_light = 15 },
    .{ .mob_type = .chicken, .weight = 10, .min_group = 2, .max_group = 4, .min_light = 9, .max_light = 15 },
    // Hostile mobs (darkness)
    .{ .mob_type = .zombie, .weight = 10, .min_group = 1, .max_group = 4, .min_light = 0, .max_light = 7 },
    .{ .mob_type = .skeleton, .weight = 8, .min_group = 1, .max_group = 2, .min_light = 0, .max_light = 7 },
    .{ .mob_type = .creeper, .weight = 5, .min_group = 1, .max_group = 1, .min_light = 0, .max_light = 7 },
    .{ .mob_type = .spider, .weight = 8, .min_group = 1, .max_group = 2, .min_light = 0, .max_light = 7 },
};

const FOREST_SPAWNS = [_]SpawnEntry{
    .{ .mob_type = .pig, .weight = 8, .min_group = 2, .max_group = 3, .min_light = 9, .max_light = 15 },
    .{ .mob_type = .chicken, .weight = 6, .min_group = 1, .max_group = 3, .min_light = 9, .max_light = 15 },
    .{ .mob_type = .zombie, .weight = 12, .min_group = 2, .max_group = 4, .min_light = 0, .max_light = 7 },
    .{ .mob_type = .skeleton, .weight = 10, .min_group = 1, .max_group = 3, .min_light = 0, .max_light = 7 },
    .{ .mob_type = .spider, .weight = 12, .min_group = 1, .max_group = 3, .min_light = 0, .max_light = 7 },
    .{ .mob_type = .creeper, .weight = 6, .min_group = 1, .max_group = 1, .min_light = 0, .max_light = 7 },
};

const DESERT_SPAWNS = [_]SpawnEntry{
    // Fewer passive mobs in desert
    .{ .mob_type = .zombie, .weight = 15, .min_group = 2, .max_group = 4, .min_light = 0, .max_light = 7 },
    .{ .mob_type = .skeleton, .weight = 15, .min_group = 2, .max_group = 4, .min_light = 0, .max_light = 7 },
    .{ .mob_type = .spider, .weight = 10, .min_group = 1, .max_group = 2, .min_light = 0, .max_light = 7 },
};

const MOUNTAIN_SPAWNS = [_]SpawnEntry{
    .{ .mob_type = .sheep, .weight = 15, .min_group = 2, .max_group = 4, .min_light = 9, .max_light = 15 },
    .{ .mob_type = .skeleton, .weight = 12, .min_group = 1, .max_group = 3, .min_light = 0, .max_light = 7 },
    .{ .mob_type = .zombie, .weight = 8, .min_group = 1, .max_group = 2, .min_light = 0, .max_light = 7 },
    .{ .mob_type = .spider, .weight = 6, .min_group = 1, .max_group = 2, .min_light = 0, .max_light = 7 },
};

const OCEAN_SPAWNS = [_]SpawnEntry{
    // Very few spawns in ocean (most would be aquatic)
    .{ .mob_type = .zombie, .weight = 5, .min_group = 1, .max_group = 1, .min_light = 0, .max_light = 7 },
};

const BEACH_SPAWNS = [_]SpawnEntry{
    .{ .mob_type = .chicken, .weight = 8, .min_group = 1, .max_group = 3, .min_light = 9, .max_light = 15 },
    .{ .mob_type = .zombie, .weight = 8, .min_group = 1, .max_group = 2, .min_light = 0, .max_light = 7 },
};

const SNOW_SPAWNS = [_]SpawnEntry{
    .{ .mob_type = .sheep, .weight = 10, .min_group = 2, .max_group = 4, .min_light = 9, .max_light = 15 },
    .{ .mob_type = .skeleton, .weight = 15, .min_group = 1, .max_group = 4, .min_light = 0, .max_light = 7 },
    .{ .mob_type = .zombie, .weight = 10, .min_group = 1, .max_group = 2, .min_light = 0, .max_light = 7 },
};

const SWAMP_SPAWNS = [_]SpawnEntry{
    .{ .mob_type = .pig, .weight = 5, .min_group = 1, .max_group = 2, .min_light = 9, .max_light = 15 },
    .{ .mob_type = .zombie, .weight = 15, .min_group = 2, .max_group = 5, .min_light = 0, .max_light = 9 },
    .{ .mob_type = .spider, .weight = 12, .min_group = 1, .max_group = 3, .min_light = 0, .max_light = 9 },
    .{ .mob_type = .creeper, .weight = 8, .min_group = 1, .max_group = 2, .min_light = 0, .max_light = 9 },
};

const TAIGA_SPAWNS = [_]SpawnEntry{
    .{ .mob_type = .sheep, .weight = 8, .min_group = 2, .max_group = 4, .min_light = 9, .max_light = 15 },
    .{ .mob_type = .cow, .weight = 6, .min_group = 1, .max_group = 3, .min_light = 9, .max_light = 15 },
    .{ .mob_type = .zombie, .weight = 10, .min_group = 1, .max_group = 3, .min_light = 0, .max_light = 7 },
    .{ .mob_type = .skeleton, .weight = 10, .min_group = 1, .max_group = 3, .min_light = 0, .max_light = 7 },
    .{ .mob_type = .spider, .weight = 8, .min_group = 1, .max_group = 2, .min_light = 0, .max_light = 7 },
};

const SAVANNA_SPAWNS = [_]SpawnEntry{
    .{ .mob_type = .cow, .weight = 8, .min_group = 2, .max_group = 4, .min_light = 9, .max_light = 15 },
    .{ .mob_type = .sheep, .weight = 6, .min_group = 2, .max_group = 4, .min_light = 9, .max_light = 15 },
    .{ .mob_type = .chicken, .weight = 4, .min_group = 1, .max_group = 2, .min_light = 9, .max_light = 15 },
    .{ .mob_type = .zombie, .weight = 8, .min_group = 1, .max_group = 3, .min_light = 0, .max_light = 7 },
    .{ .mob_type = .skeleton, .weight = 8, .min_group = 1, .max_group = 2, .min_light = 0, .max_light = 7 },
    .{ .mob_type = .spider, .weight = 6, .min_group = 1, .max_group = 2, .min_light = 0, .max_light = 7 },
};

// ============================================================================
// Tests
// ============================================================================

test "mob spawner initialization" {
    const allocator = std.testing.allocator;
    var spawner = MobSpawner.init(allocator, 12345);
    defer spawner.deinit();

    try std.testing.expectEqual(@as(f32, 0), spawner.spawn_timer);
}

test "spawn entries for biome" {
    const plains_entries = getSpawnEntries(.plains);
    try std.testing.expect(plains_entries.len > 0);

    // Check that pigs can spawn in plains during day
    var found_pig = false;
    for (plains_entries) |entry| {
        if (entry.mob_type == .pig) {
            found_pig = true;
            try std.testing.expect(entry.min_light >= 9);
        }
    }
    try std.testing.expect(found_pig);
}

test "chunk hash" {
    const hash1 = chunkHash(0, 0);
    const hash2 = chunkHash(16, 0);
    const hash3 = chunkHash(0, 16);

    // Different chunks should have different hashes
    try std.testing.expect(hash1 != hash2);
    try std.testing.expect(hash1 != hash3);
    try std.testing.expect(hash2 != hash3);

    // Same chunk should have same hash
    const hash1_again = chunkHash(15, 15); // Same chunk as 0,0
    try std.testing.expectEqual(hash1, hash1_again);
}
