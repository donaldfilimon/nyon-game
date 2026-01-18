//! Terrain Generation
//!
//! Procedural terrain generation using noise-based algorithms.
//! Generates terrain in layers: base height, caves, ores, features.

const std = @import("std");
const noise = @import("noise.zig");
const biome_mod = @import("biome.zig");
const Block = @import("../game/world.zig").Block;
const Chunk = @import("../game/world.zig").Chunk;
const CHUNK_SIZE = @import("../game/world.zig").CHUNK_SIZE;

pub const Biome = biome_mod.Biome;
pub const BiomeType = biome_mod.BiomeType;
pub const BiomeGenerator = biome_mod.BiomeGenerator;

/// Water level for oceans and lakes
pub const SEA_LEVEL: i32 = 0;

/// Terrain generator with procedural features
pub const TerrainGenerator = struct {
    allocator: std.mem.Allocator,
    seed: u64,
    noise_gen: noise.SeededNoise,
    biome_gen: BiomeGenerator,
    /// Random number generator for features
    rng: std.Random.DefaultPrng,

    const Self = @This();

    /// Initialize terrain generator with seed
    pub fn init(allocator: std.mem.Allocator, seed: u64) Self {
        return .{
            .allocator = allocator,
            .seed = seed,
            .noise_gen = noise.SeededNoise.init(seed),
            .biome_gen = BiomeGenerator.init(seed),
            .rng = std.Random.DefaultPrng.init(seed),
        };
    }

    /// Generate a complete chunk with all features
    pub fn generateChunk(self: *Self, chunk: *Chunk) void {
        const chunk_x = chunk.position[0];
        const chunk_y = chunk.position[1];
        const chunk_z = chunk.position[2];

        // First pass: base terrain height
        var height_map: [CHUNK_SIZE][CHUNK_SIZE]i32 = undefined;
        var biome_map: [CHUNK_SIZE][CHUNK_SIZE]Biome = undefined;

        for (0..CHUNK_SIZE) |lz| {
            for (0..CHUNK_SIZE) |lx| {
                const world_x = chunk_x * @as(i32, CHUNK_SIZE) + @as(i32, @intCast(lx));
                const world_z = chunk_z * @as(i32, CHUNK_SIZE) + @as(i32, @intCast(lz));

                biome_map[lz][lx] = self.biome_gen.getBlendedBiome(world_x, world_z, 8);
                height_map[lz][lx] = self.getTerrainHeight(world_x, world_z, &biome_map[lz][lx]);
            }
        }

        // Second pass: fill blocks based on height
        for (0..CHUNK_SIZE) |ly| {
            const world_y = chunk_y * @as(i32, CHUNK_SIZE) + @as(i32, @intCast(ly));

            for (0..CHUNK_SIZE) |lz| {
                for (0..CHUNK_SIZE) |lx| {
                    const world_x = chunk_x * @as(i32, CHUNK_SIZE) + @as(i32, @intCast(lx));
                    const world_z = chunk_z * @as(i32, CHUNK_SIZE) + @as(i32, @intCast(lz));

                    const height = height_map[lz][lx];
                    const biome = &biome_map[lz][lx];

                    const block = self.getBlockAt(world_x, world_y, world_z, height, biome);
                    chunk.setBlock(lx, ly, lz, block);
                }
            }
        }

        // Third pass: carve caves
        self.carveCaves(chunk, &height_map);

        // Fourth pass: place ores
        self.placeOres(chunk, &height_map);

        // Fifth pass: generate features (only for surface chunks)
        if (chunk_y >= -1 and chunk_y <= 2) {
            self.generateFeatures(chunk, &height_map, &biome_map);
        }

        chunk.is_dirty = true;
    }

    /// Get terrain height at world position
    pub fn getTerrainHeight(self: *const Self, x: i32, z: i32, biome: *const Biome) i32 {
        const fx: f32 = @floatFromInt(x);
        const fz: f32 = @floatFromInt(z);

        // Base continental height
        const base_height = self.noise_gen.fbm2(fx * 0.002, fz * 0.002, 5, 2.0, 0.5);

        // Detail noise
        const detail = self.noise_gen.fbm2(fx * 0.01, fz * 0.01, 4, 2.0, 0.5);

        // Mountain ridges (only in mountainous areas)
        var mountain_height: f32 = 0;
        if (biome.biome_type == .mountains) {
            mountain_height = self.noise_gen.ridged2(fx * 0.008, fz * 0.008, 4, 2.0, 2.0) * 30.0;
        }

        // Combine heights with biome modifiers
        const combined = base_height * 15.0 + detail * biome.height_modifier * 10.0 + mountain_height;
        const final_height = combined + biome.base_height;

        return @intFromFloat(final_height);
    }

    /// Get block type at world position based on height and biome
    fn getBlockAt(self: *const Self, x: i32, y: i32, z: i32, surface_height: i32, biome: *const Biome) Block {
        _ = self;
        _ = x;
        _ = z;

        // Above surface
        if (y > surface_height) {
            // Fill with water if below sea level
            if (y <= SEA_LEVEL) {
                if (biome.frozen and y == SEA_LEVEL) {
                    return .ice;
                }
                return .water;
            }
            return .air;
        }

        // At surface
        if (y == surface_height) {
            // Underwater surface
            if (y < SEA_LEVEL - 2) {
                return .gravel;
            }
            if (y < SEA_LEVEL) {
                return .sand;
            }
            return biome.getSurfaceBlock(y);
        }

        // Subsurface layers
        const depth = surface_height - y;

        if (depth <= 3) {
            // Subsurface layer (dirt, sand, etc.)
            if (y < SEA_LEVEL) {
                return .sand; // Beach sand under water
            }
            return biome.subsurface_block;
        }

        if (depth <= 5) {
            // Transition to stone
            return biome.subsurface_block;
        }

        // Deep underground - just stone
        return biome.deep_block;
    }

    /// Carve caves using 3D noise
    fn carveCaves(self: *Self, chunk: *Chunk, height_map: *const [CHUNK_SIZE][CHUNK_SIZE]i32) void {
        const chunk_x = chunk.position[0];
        const chunk_y = chunk.position[1];
        const chunk_z = chunk.position[2];

        for (0..CHUNK_SIZE) |ly| {
            const world_y = chunk_y * @as(i32, CHUNK_SIZE) + @as(i32, @intCast(ly));

            // Only carve caves underground
            if (world_y > 10) continue;

            for (0..CHUNK_SIZE) |lz| {
                for (0..CHUNK_SIZE) |lx| {
                    const world_x = chunk_x * @as(i32, CHUNK_SIZE) + @as(i32, @intCast(lx));
                    const world_z = chunk_z * @as(i32, CHUNK_SIZE) + @as(i32, @intCast(lz));

                    // Skip if we'd break through surface
                    const surface = height_map[lz][lx];
                    if (world_y >= surface - 5) continue;

                    // Worm caves
                    if (self.noise_gen.wormCave3(
                        @floatFromInt(world_x),
                        @floatFromInt(world_y),
                        @floatFromInt(world_z),
                        0.03,
                        0.12,
                    )) {
                        const current = chunk.getBlock(lx, ly, lz);
                        if (current != .water and current != .air) {
                            chunk.setBlock(lx, ly, lz, .air);
                        }
                    }

                    // Swiss cheese caves (deeper)
                    if (world_y < -10) {
                        if (self.noise_gen.swissCheese3(
                            @floatFromInt(world_x),
                            @floatFromInt(world_y),
                            @floatFromInt(world_z),
                            0.5,
                        )) {
                            const current = chunk.getBlock(lx, ly, lz);
                            if (current != .water) {
                                chunk.setBlock(lx, ly, lz, .air);
                            }
                        }
                    }
                }
            }
        }
    }

    /// Place ore veins
    fn placeOres(self: *Self, chunk: *Chunk, height_map: *const [CHUNK_SIZE][CHUNK_SIZE]i32) void {
        const chunk_x = chunk.position[0];
        const chunk_y = chunk.position[1];
        const chunk_z = chunk.position[2];

        for (biome_mod.ORES) |ore_config| {
            self.placeOreType(chunk, chunk_x, chunk_y, chunk_z, height_map, ore_config);
        }
    }

    /// Place a specific ore type in the chunk
    fn placeOreType(
        self: *Self,
        chunk: *Chunk,
        chunk_x: i32,
        chunk_y: i32,
        chunk_z: i32,
        height_map: *const [CHUNK_SIZE][CHUNK_SIZE]i32,
        config: biome_mod.OreConfig,
    ) void {
        // Use deterministic RNG based on chunk position and ore type
        const ore_seed = self.seed +%
            @as(u64, @bitCast(@as(i64, chunk_x))) *% 341873128712 +%
            @as(u64, @bitCast(@as(i64, chunk_y))) *% 132897987541 +%
            @as(u64, @bitCast(@as(i64, chunk_z))) *% 987234987234 +%
            @as(u64, @intFromEnum(config.block_type));

        var rng = std.Random.DefaultPrng.init(ore_seed);

        // Number of ore veins to attempt per chunk
        const attempts: u32 = 256 / config.rarity;

        for (0..attempts) |_| {
            const lx = rng.random().uintLessThan(usize, CHUNK_SIZE);
            const ly = rng.random().uintLessThan(usize, CHUNK_SIZE);
            const lz = rng.random().uintLessThan(usize, CHUNK_SIZE);

            const world_y = chunk_y * @as(i32, CHUNK_SIZE) + @as(i32, @intCast(ly));

            // Check height restrictions
            if (world_y < config.min_height or world_y > config.max_height) continue;

            // Don't place ore above surface
            const surface = height_map[lz][lx];
            if (world_y > surface - 3) continue;

            // Place vein
            self.placeOreVein(chunk, lx, ly, lz, config.block_type, config.vein_size, &rng);
        }
    }

    /// Place a single ore vein
    fn placeOreVein(
        self: *Self,
        chunk: *Chunk,
        start_x: usize,
        start_y: usize,
        start_z: usize,
        ore: Block,
        vein_size: u8,
        rng: *std.Random.DefaultPrng,
    ) void {
        _ = self;

        var x = start_x;
        var y = start_y;
        var z = start_z;

        for (0..vein_size) |_| {
            if (x < CHUNK_SIZE and y < CHUNK_SIZE and z < CHUNK_SIZE) {
                const current = chunk.getBlock(x, y, z);
                if (current == .stone) {
                    chunk.setBlock(x, y, z, ore);
                }
            }

            // Random walk to next position
            const dir = rng.random().uintLessThan(u8, 6);
            switch (dir) {
                0 => x = if (x > 0) x - 1 else x,
                1 => x = if (x < CHUNK_SIZE - 1) x + 1 else x,
                2 => y = if (y > 0) y - 1 else y,
                3 => y = if (y < CHUNK_SIZE - 1) y + 1 else y,
                4 => z = if (z > 0) z - 1 else z,
                5 => z = if (z < CHUNK_SIZE - 1) z + 1 else z,
                else => {},
            }
        }
    }

    /// Generate surface features (trees, plants, etc.)
    fn generateFeatures(
        self: *Self,
        chunk: *Chunk,
        height_map: *const [CHUNK_SIZE][CHUNK_SIZE]i32,
        biome_map: *const [CHUNK_SIZE][CHUNK_SIZE]Biome,
    ) void {
        const chunk_x = chunk.position[0];
        const chunk_y = chunk.position[1];
        const chunk_z = chunk.position[2];

        for (0..CHUNK_SIZE) |lz| {
            for (0..CHUNK_SIZE) |lx| {
                const world_x = chunk_x * @as(i32, CHUNK_SIZE) + @as(i32, @intCast(lx));
                const world_z = chunk_z * @as(i32, CHUNK_SIZE) + @as(i32, @intCast(lz));
                const surface = height_map[lz][lx];
                const biome = &biome_map[lz][lx];

                // Skip underwater areas
                if (surface < SEA_LEVEL) continue;

                // Check if surface is in this chunk
                const surface_ly = surface - chunk_y * @as(i32, CHUNK_SIZE);
                if (surface_ly < 0 or surface_ly >= CHUNK_SIZE) continue;

                // Tree generation
                if (biome.tree_density > 0) {
                    const tree_noise = self.noise_gen.perlin2(
                        @as(f32, @floatFromInt(world_x)) * 0.5,
                        @as(f32, @floatFromInt(world_z)) * 0.5,
                    );

                    // Use hash for consistent placement
                    const hash = hashPosition(world_x, world_z, self.seed);
                    const tree_chance = @as(f32, @floatFromInt(hash % 1000)) / 1000.0;

                    if (tree_noise > 0.3 and tree_chance < biome.tree_density * 3.0) {
                        // Only place trees away from chunk edges to avoid cross-chunk issues
                        if (lx >= 2 and lx < CHUNK_SIZE - 2 and lz >= 2 and lz < CHUNK_SIZE - 2) {
                            self.placeTree(chunk, lx, @intCast(surface_ly + 1), lz, biome.primary_tree);
                        }
                    }
                }
            }
        }
    }

    /// Place a tree at the given position
    fn placeTree(self: *Self, chunk: *Chunk, x: usize, y: usize, z: usize, tree_type: biome_mod.TreeType) void {
        if (tree_type == .none) return;
        if (y >= CHUNK_SIZE) return;

        const height_range = tree_type.getHeightRange();
        const seed_offset = @as(u64, x) *% 12345 +% @as(u64, z) *% 67890;
        var rng = std.Random.DefaultPrng.init(self.seed +% seed_offset);
        const trunk_height: usize = height_range.min + rng.random().uintLessThan(u8, height_range.max - height_range.min + 1);

        // Place trunk
        for (0..trunk_height) |dy| {
            const ty = y + dy;
            if (ty >= CHUNK_SIZE) break;
            chunk.setBlock(x, ty, z, .wood);
        }

        // Place leaves based on tree type
        if (tree_type == .dead) {
            return; // Dead trees have no leaves
        }

        const leaf_block: Block = if (tree_type == .pine) .leaves else .leaves;
        const top_y = y + trunk_height;

        switch (tree_type) {
            .oak, .birch => {
                // Spherical-ish canopy
                self.placeLeafSphere(chunk, x, top_y - 1, z, 2, leaf_block);
            },
            .pine => {
                // Conical canopy
                self.placeLeafCone(chunk, x, top_y, z, trunk_height, leaf_block);
            },
            .palm => {
                // Palm fronds
                self.placePalmFronds(chunk, x, top_y, z, leaf_block);
            },
            .acacia => {
                // Flat-topped canopy
                self.placeAcaciaCanopy(chunk, x, top_y, z, leaf_block);
            },
            else => {},
        }
    }

    /// Place a spherical leaf cluster
    fn placeLeafSphere(self: *Self, chunk: *Chunk, cx: usize, cy: usize, cz: usize, radius: i32, leaf: Block) void {
        _ = self;

        var dy: i32 = -radius;
        while (dy <= radius) : (dy += 1) {
            var dz: i32 = -radius;
            while (dz <= radius) : (dz += 1) {
                var dx: i32 = -radius;
                while (dx <= radius) : (dx += 1) {
                    const dist_sq = dx * dx + dy * dy + dz * dz;
                    if (dist_sq <= radius * radius + 1) {
                        const lx = @as(i32, @intCast(cx)) + dx;
                        const ly = @as(i32, @intCast(cy)) + dy;
                        const lz = @as(i32, @intCast(cz)) + dz;

                        if (lx >= 0 and lx < CHUNK_SIZE and
                            ly >= 0 and ly < CHUNK_SIZE and
                            lz >= 0 and lz < CHUNK_SIZE)
                        {
                            const ulx: usize = @intCast(lx);
                            const uly: usize = @intCast(ly);
                            const ulz: usize = @intCast(lz);

                            if (chunk.getBlock(ulx, uly, ulz) == .air) {
                                chunk.setBlock(ulx, uly, ulz, leaf);
                            }
                        }
                    }
                }
            }
        }
    }

    /// Place a conical leaf pattern for pine trees
    fn placeLeafCone(self: *Self, chunk: *Chunk, cx: usize, top_y: usize, cz: usize, height: usize, leaf: Block) void {
        _ = self;

        // Work from top down with increasing radius
        var layer: usize = 0;
        while (layer < height / 2) : (layer += 1) {
            const ly = top_y -| layer;
            if (ly >= CHUNK_SIZE) continue;

            const radius: i32 = @intCast(@min(layer + 1, 3));

            var dz: i32 = -radius;
            while (dz <= radius) : (dz += 1) {
                var dx: i32 = -radius;
                while (dx <= radius) : (dx += 1) {
                    if (@abs(dx) + @abs(dz) <= radius + 1) {
                        const lx = @as(i32, @intCast(cx)) + dx;
                        const lz = @as(i32, @intCast(cz)) + dz;

                        if (lx >= 0 and lx < CHUNK_SIZE and lz >= 0 and lz < CHUNK_SIZE) {
                            const ulx: usize = @intCast(lx);
                            const ulz: usize = @intCast(lz);

                            if (chunk.getBlock(ulx, ly, ulz) == .air) {
                                chunk.setBlock(ulx, ly, ulz, leaf);
                            }
                        }
                    }
                }
            }
        }
    }

    /// Place palm tree fronds
    fn placePalmFronds(self: *Self, chunk: *Chunk, cx: usize, cy: usize, cz: usize, leaf: Block) void {
        _ = self;

        if (cy >= CHUNK_SIZE) return;

        // Place leaves in cross pattern with drooping ends
        const dirs = [_][2]i32{ .{ 1, 0 }, .{ -1, 0 }, .{ 0, 1 }, .{ 0, -1 } };

        for (dirs) |dir| {
            for (1..4) |i| {
                const dx = dir[0] * @as(i32, @intCast(i));
                const dz = dir[1] * @as(i32, @intCast(i));
                const dy: i32 = if (i == 3) -1 else 0; // Droop at end

                const lx = @as(i32, @intCast(cx)) + dx;
                const ly = @as(i32, @intCast(cy)) + dy;
                const lz = @as(i32, @intCast(cz)) + dz;

                if (lx >= 0 and lx < CHUNK_SIZE and
                    ly >= 0 and ly < CHUNK_SIZE and
                    lz >= 0 and lz < CHUNK_SIZE)
                {
                    chunk.setBlock(@intCast(lx), @intCast(ly), @intCast(lz), leaf);
                }
            }
        }
    }

    /// Place acacia flat-topped canopy
    fn placeAcaciaCanopy(self: *Self, chunk: *Chunk, cx: usize, cy: usize, cz: usize, leaf: Block) void {
        _ = self;

        if (cy >= CHUNK_SIZE) return;

        // Flat disk of leaves
        var dz: i32 = -2;
        while (dz <= 2) : (dz += 1) {
            var dx: i32 = -2;
            while (dx <= 2) : (dx += 1) {
                if (@abs(dx) + @abs(dz) <= 3) {
                    const lx = @as(i32, @intCast(cx)) + dx;
                    const lz = @as(i32, @intCast(cz)) + dz;

                    if (lx >= 0 and lx < CHUNK_SIZE and lz >= 0 and lz < CHUNK_SIZE) {
                        if (chunk.getBlock(@intCast(lx), cy, @intCast(lz)) == .air) {
                            chunk.setBlock(@intCast(lx), cy, @intCast(lz), leaf);
                        }
                    }
                }
            }
        }
    }
};

/// Hash function for deterministic feature placement
fn hashPosition(x: i32, z: i32, seed: u64) u64 {
    var h = seed;
    h ^= @as(u64, @bitCast(@as(i64, x))) *% 0x517cc1b727220a95;
    h ^= @as(u64, @bitCast(@as(i64, z))) *% 0x5851f42d4c957f2d;
    h ^= h >> 32;
    h *%= 0xcf1bbcdcb7a56463;
    return h;
}

// ============================================================================
// Tests
// ============================================================================

test "terrain generator initialization" {
    const allocator = std.testing.allocator;
    var gen = TerrainGenerator.init(allocator, 12345);
    _ = &gen;
}

test "terrain height generation" {
    const allocator = std.testing.allocator;
    const gen = TerrainGenerator.init(allocator, 12345);

    const biome = Biome.get(.plains);
    const height = gen.getTerrainHeight(100, 100, &biome);

    // Height should be reasonable
    try std.testing.expect(height > -100);
    try std.testing.expect(height < 100);
}

test "terrain height determinism" {
    const allocator = std.testing.allocator;
    const gen1 = TerrainGenerator.init(allocator, 42);
    const gen2 = TerrainGenerator.init(allocator, 42);

    const biome = Biome.get(.forest);
    const h1 = gen1.getTerrainHeight(50, 50, &biome);
    const h2 = gen2.getTerrainHeight(50, 50, &biome);

    try std.testing.expectEqual(h1, h2);
}
