//! Biome System
//!
//! Defines biome types and their properties for terrain generation.
//! Biomes control surface blocks, vegetation, and terrain features.

const std = @import("std");
const noise = @import("noise.zig");
const Block = @import("../game/world.zig").Block;

/// Biome types available in the world
pub const BiomeType = enum(u8) {
    plains, // Flat grass, occasional trees
    forest, // Dense trees, undergrowth
    desert, // Sand, cacti, dead bushes
    mountains, // Stone peaks, snow caps
    ocean, // Deep water
    beach, // Sand near water
    snow, // Snow-covered, ice
    swamp, // Water, mud, dead trees
    taiga, // Cold conifer forest
    savanna, // Warm grassland, acacia-like trees

    /// Get the display name of the biome
    pub fn getName(self: BiomeType) []const u8 {
        return switch (self) {
            .plains => "Plains",
            .forest => "Forest",
            .desert => "Desert",
            .mountains => "Mountains",
            .ocean => "Ocean",
            .beach => "Beach",
            .snow => "Snow",
            .swamp => "Swamp",
            .taiga => "Taiga",
            .savanna => "Savanna",
        };
    }
};

/// Tree types that can spawn in biomes
pub const TreeType = enum(u8) {
    oak, // Standard tree (plains, forest)
    birch, // White bark tree
    pine, // Tall conifer (taiga, mountains)
    palm, // Beach tree
    dead, // No leaves (swamp)
    acacia, // Flat-topped (savanna)
    none, // No trees

    /// Get trunk height range for tree type
    pub fn getHeightRange(self: TreeType) struct { min: u8, max: u8 } {
        return switch (self) {
            .oak => .{ .min = 4, .max = 6 },
            .birch => .{ .min = 5, .max = 7 },
            .pine => .{ .min = 6, .max = 10 },
            .palm => .{ .min = 5, .max = 7 },
            .dead => .{ .min = 3, .max = 5 },
            .acacia => .{ .min = 4, .max = 6 },
            .none => .{ .min = 0, .max = 0 },
        };
    }
};

/// Biome properties and generation parameters
pub const Biome = struct {
    biome_type: BiomeType,
    /// Block type for surface layer (top block)
    surface_block: Block,
    /// Block type for subsurface (3-4 blocks below surface)
    subsurface_block: Block,
    /// Block type for deep underground
    deep_block: Block,
    /// Probability of tree spawning (0.0 - 1.0)
    tree_density: f32,
    /// Primary tree type
    primary_tree: TreeType,
    /// Secondary tree type (less common)
    secondary_tree: TreeType,
    /// Multiplier for terrain height variation
    height_modifier: f32,
    /// Base height offset for biome
    base_height: f32,
    /// Whether water bodies are frozen
    frozen: bool,
    /// Chance for grass/flowers on surface
    foliage_density: f32,
    /// Temperature value (affects snow, ice)
    temperature: f32,
    /// Moisture value (affects vegetation)
    moisture: f32,

    const Self = @This();

    /// Get biome definition by type
    pub fn get(biome_type: BiomeType) Self {
        return switch (biome_type) {
            .plains => .{
                .biome_type = .plains,
                .surface_block = .grass,
                .subsurface_block = .dirt,
                .deep_block = .stone,
                .tree_density = 0.01,
                .primary_tree = .oak,
                .secondary_tree = .birch,
                .height_modifier = 0.3,
                .base_height = 0.0,
                .frozen = false,
                .foliage_density = 0.3,
                .temperature = 0.5,
                .moisture = 0.5,
            },
            .forest => .{
                .biome_type = .forest,
                .surface_block = .grass,
                .subsurface_block = .dirt,
                .deep_block = .stone,
                .tree_density = 0.15,
                .primary_tree = .oak,
                .secondary_tree = .birch,
                .height_modifier = 0.5,
                .base_height = 2.0,
                .frozen = false,
                .foliage_density = 0.5,
                .temperature = 0.5,
                .moisture = 0.7,
            },
            .desert => .{
                .biome_type = .desert,
                .surface_block = .sand,
                .subsurface_block = .sand,
                .deep_block = .stone,
                .tree_density = 0.002,
                .primary_tree = .dead,
                .secondary_tree = .none,
                .height_modifier = 0.2,
                .base_height = 0.0,
                .frozen = false,
                .foliage_density = 0.02,
                .temperature = 0.9,
                .moisture = 0.1,
            },
            .mountains => .{
                .biome_type = .mountains,
                .surface_block = .stone,
                .subsurface_block = .stone,
                .deep_block = .stone,
                .tree_density = 0.005,
                .primary_tree = .pine,
                .secondary_tree = .none,
                .height_modifier = 3.0,
                .base_height = 15.0,
                .frozen = false,
                .foliage_density = 0.05,
                .temperature = 0.3,
                .moisture = 0.4,
            },
            .ocean => .{
                .biome_type = .ocean,
                .surface_block = .sand,
                .subsurface_block = .sand,
                .deep_block = .stone,
                .tree_density = 0.0,
                .primary_tree = .none,
                .secondary_tree = .none,
                .height_modifier = 0.1,
                .base_height = -15.0,
                .frozen = false,
                .foliage_density = 0.0,
                .temperature = 0.5,
                .moisture = 1.0,
            },
            .beach => .{
                .biome_type = .beach,
                .surface_block = .sand,
                .subsurface_block = .sand,
                .deep_block = .stone,
                .tree_density = 0.01,
                .primary_tree = .palm,
                .secondary_tree = .none,
                .height_modifier = 0.1,
                .base_height = 1.0,
                .frozen = false,
                .foliage_density = 0.05,
                .temperature = 0.7,
                .moisture = 0.6,
            },
            .snow => .{
                .biome_type = .snow,
                .surface_block = .snow,
                .subsurface_block = .dirt,
                .deep_block = .stone,
                .tree_density = 0.02,
                .primary_tree = .pine,
                .secondary_tree = .none,
                .height_modifier = 0.4,
                .base_height = 3.0,
                .frozen = true,
                .foliage_density = 0.0,
                .temperature = 0.1,
                .moisture = 0.5,
            },
            .swamp => .{
                .biome_type = .swamp,
                .surface_block = .grass,
                .subsurface_block = .clay,
                .deep_block = .stone,
                .tree_density = 0.08,
                .primary_tree = .dead,
                .secondary_tree = .oak,
                .height_modifier = 0.1,
                .base_height = -2.0,
                .frozen = false,
                .foliage_density = 0.4,
                .temperature = 0.6,
                .moisture = 0.9,
            },
            .taiga => .{
                .biome_type = .taiga,
                .surface_block = .grass,
                .subsurface_block = .dirt,
                .deep_block = .stone,
                .tree_density = 0.12,
                .primary_tree = .pine,
                .secondary_tree = .pine,
                .height_modifier = 0.6,
                .base_height = 4.0,
                .frozen = false,
                .foliage_density = 0.2,
                .temperature = 0.25,
                .moisture = 0.6,
            },
            .savanna => .{
                .biome_type = .savanna,
                .surface_block = .grass,
                .subsurface_block = .dirt,
                .deep_block = .stone,
                .tree_density = 0.008,
                .primary_tree = .acacia,
                .secondary_tree = .none,
                .height_modifier = 0.2,
                .base_height = 1.0,
                .frozen = false,
                .foliage_density = 0.15,
                .temperature = 0.8,
                .moisture = 0.3,
            },
        };
    }

    /// Get surface block accounting for height (snow caps on mountains)
    pub fn getSurfaceBlock(self: *const Self, height: i32) Block {
        // Snow caps on tall mountains
        if (self.biome_type == .mountains and height > 25) {
            return .snow;
        }
        return self.surface_block;
    }
};

/// Biome generator using noise-based selection
pub const BiomeGenerator = struct {
    seed: u64,
    noise_gen: noise.SeededNoise,
    /// Scale factor for biome size (larger = bigger biomes)
    biome_scale: f32,
    /// Voronoi-based biome selection blend distance
    blend_distance: f32,

    const Self = @This();

    /// Initialize biome generator with seed
    pub fn init(seed: u64) Self {
        return .{
            .seed = seed,
            .noise_gen = noise.SeededNoise.init(seed),
            .biome_scale = 0.005, // Biomes are ~200 blocks across
            .blend_distance = 8.0,
        };
    }

    /// Get temperature at world position
    pub fn getTemperature(self: *const Self, x: f32, z: f32) f32 {
        const temp_noise = self.noise_gen.fbm2(
            x * self.biome_scale * 0.5,
            z * self.biome_scale * 0.5,
            3,
            2.0,
            0.5,
        );
        // Map from [-1, 1] to [0, 1]
        return (temp_noise + 1.0) * 0.5;
    }

    /// Get moisture at world position
    pub fn getMoisture(self: *const Self, x: f32, z: f32) f32 {
        const moisture_noise = self.noise_gen.fbm2(
            x * self.biome_scale * 0.5 + 1000.0,
            z * self.biome_scale * 0.5 + 1000.0,
            3,
            2.0,
            0.5,
        );
        return (moisture_noise + 1.0) * 0.5;
    }

    /// Get continentalness (land vs ocean) at world position
    pub fn getContinentalness(self: *const Self, x: f32, z: f32) f32 {
        const cont_noise = self.noise_gen.fbm2(
            x * self.biome_scale * 0.3 + 5000.0,
            z * self.biome_scale * 0.3 + 5000.0,
            4,
            2.0,
            0.5,
        );
        return (cont_noise + 1.0) * 0.5;
    }

    /// Get erosion (affects mountain height) at world position
    pub fn getErosion(self: *const Self, x: f32, z: f32) f32 {
        const erosion_noise = self.noise_gen.fbm2(
            x * self.biome_scale + 3000.0,
            z * self.biome_scale + 3000.0,
            3,
            2.0,
            0.5,
        );
        return (erosion_noise + 1.0) * 0.5;
    }

    /// Determine biome type from climate parameters
    pub fn selectBiome(temperature: f32, moisture: f32, continentalness: f32, erosion: f32) BiomeType {
        // Ocean if continentalness is low
        if (continentalness < 0.35) {
            return .ocean;
        }

        // Beach near ocean threshold
        if (continentalness < 0.42) {
            return .beach;
        }

        // Mountain if erosion is high and inland
        if (erosion > 0.7 and continentalness > 0.5) {
            return .mountains;
        }

        // Temperature-moisture based selection for land biomes
        if (temperature < 0.25) {
            // Cold biomes
            if (moisture > 0.5) {
                return .taiga;
            } else {
                return .snow;
            }
        } else if (temperature < 0.5) {
            // Temperate biomes
            if (moisture > 0.65) {
                return .swamp;
            } else if (moisture > 0.4) {
                return .forest;
            } else {
                return .plains;
            }
        } else if (temperature < 0.75) {
            // Warm biomes
            if (moisture > 0.5) {
                return .forest;
            } else if (moisture > 0.25) {
                return .savanna;
            } else {
                return .plains;
            }
        } else {
            // Hot biomes
            if (moisture > 0.6) {
                return .swamp;
            } else if (moisture < 0.3) {
                return .desert;
            } else {
                return .savanna;
            }
        }
    }

    /// Get biome at world position
    pub fn getBiome(self: *const Self, x: i32, z: i32) Biome {
        const fx: f32 = @floatFromInt(x);
        const fz: f32 = @floatFromInt(z);

        const temperature = self.getTemperature(fx, fz);
        const moisture = self.getMoisture(fx, fz);
        const continentalness = self.getContinentalness(fx, fz);
        const erosion = self.getErosion(fx, fz);

        const biome_type = selectBiome(temperature, moisture, continentalness, erosion);
        return Biome.get(biome_type);
    }

    /// Get biome at world position (float version)
    pub fn getBiomeF(self: *const Self, x: f32, z: f32) Biome {
        const temperature = self.getTemperature(x, z);
        const moisture = self.getMoisture(x, z);
        const continentalness = self.getContinentalness(x, z);
        const erosion = self.getErosion(x, z);

        const biome_type = selectBiome(temperature, moisture, continentalness, erosion);
        return Biome.get(biome_type);
    }

    /// Get blended biome parameters for smooth transitions
    /// Returns weighted average of nearby biomes
    pub fn getBlendedBiome(self: *const Self, x: i32, z: i32, blend_radius: i32) Biome {
        const fx: f32 = @floatFromInt(x);
        const fz: f32 = @floatFromInt(z);

        // Sample multiple points for biome blending
        var total_height_mod: f32 = 0;
        var total_base_height: f32 = 0;
        var total_weight: f32 = 0;
        var dominant_biome: ?BiomeType = null;
        var max_weight: f32 = 0;

        const step: i32 = @max(1, @divFloor(blend_radius, 2));
        var dz: i32 = -blend_radius;
        while (dz <= blend_radius) : (dz += step) {
            var dx: i32 = -blend_radius;
            while (dx <= blend_radius) : (dx += step) {
                const sample_x = fx + @as(f32, @floatFromInt(dx));
                const sample_z = fz + @as(f32, @floatFromInt(dz));

                const dist_sq = @as(f32, @floatFromInt(dx * dx + dz * dz));
                const max_dist_sq = @as(f32, @floatFromInt(blend_radius * blend_radius));
                const weight = 1.0 - @min(dist_sq / max_dist_sq, 1.0);

                if (weight > 0.01) {
                    const biome = self.getBiomeF(sample_x, sample_z);
                    total_height_mod += biome.height_modifier * weight;
                    total_base_height += biome.base_height * weight;
                    total_weight += weight;

                    if (weight > max_weight or (weight == max_weight and dominant_biome == null)) {
                        max_weight = weight;
                        dominant_biome = biome.biome_type;
                    }
                }
            }
        }

        if (total_weight > 0) {
            var result = Biome.get(dominant_biome orelse .plains);
            result.height_modifier = total_height_mod / total_weight;
            result.base_height = total_base_height / total_weight;
            return result;
        }

        return self.getBiome(x, z);
    }
};

/// Ore generation configuration
pub const OreConfig = struct {
    block_type: Block,
    /// Minimum Y level for ore
    min_height: i32,
    /// Maximum Y level for ore
    max_height: i32,
    /// Vein size (number of blocks)
    vein_size: u8,
    /// Rarity (lower = more common, higher = more rare)
    rarity: u32,
};

/// Standard ore configurations
pub const ORES = [_]OreConfig{
    // Coal - common, found everywhere underground
    .{
        .block_type = .coal,
        .min_height = -64,
        .max_height = 128,
        .vein_size = 17,
        .rarity = 20,
    },
    // Iron - common in lower half
    .{
        .block_type = .iron,
        .min_height = -64,
        .max_height = 64,
        .vein_size = 9,
        .rarity = 25,
    },
    // Gold - rare, deep underground
    .{
        .block_type = .gold,
        .min_height = -64,
        .max_height = 32,
        .vein_size = 9,
        .rarity = 50,
    },
    // Diamond - very rare, very deep
    .{
        .block_type = .diamond_ore,
        .min_height = -64,
        .max_height = 16,
        .vein_size = 8,
        .rarity = 100,
    },
};

// ============================================================================
// Tests
// ============================================================================

test "biome definition" {
    const plains = Biome.get(.plains);
    try std.testing.expectEqual(BiomeType.plains, plains.biome_type);
    try std.testing.expectEqual(Block.grass, plains.surface_block);
    try std.testing.expectEqual(Block.dirt, plains.subsurface_block);
}

test "biome generator determinism" {
    const gen1 = BiomeGenerator.init(12345);
    const gen2 = BiomeGenerator.init(12345);

    const b1 = gen1.getBiome(100, 100);
    const b2 = gen2.getBiome(100, 100);

    try std.testing.expectEqual(b1.biome_type, b2.biome_type);
}

test "biome selection from climate" {
    // Cold and dry -> snow
    try std.testing.expectEqual(BiomeType.snow, BiomeGenerator.selectBiome(0.1, 0.2, 0.6, 0.3));

    // Hot and dry -> desert
    try std.testing.expectEqual(BiomeType.desert, BiomeGenerator.selectBiome(0.9, 0.1, 0.6, 0.3));

    // Ocean
    try std.testing.expectEqual(BiomeType.ocean, BiomeGenerator.selectBiome(0.5, 0.5, 0.2, 0.3));

    // Beach
    try std.testing.expectEqual(BiomeType.beach, BiomeGenerator.selectBiome(0.5, 0.5, 0.4, 0.3));
}

test "mountain snow caps" {
    const mountain = Biome.get(.mountains);
    try std.testing.expectEqual(Block.snow, mountain.getSurfaceBlock(30));
    try std.testing.expectEqual(Block.stone, mountain.getSurfaceBlock(20));
}
