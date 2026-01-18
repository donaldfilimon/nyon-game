//! Noise Generation
//!
//! Implements various noise functions for procedural terrain generation.
//! Includes Perlin/Simplex noise, fractal brownian motion (FBM),
//! ridged noise for mountains, and Voronoi noise for biome boundaries.

const std = @import("std");
const math = @import("../math/math.zig");

/// Permutation table for noise generation (256 values, doubled for overflow)
const PERM = generatePermutationTable();

/// Generate a deterministic permutation table based on seed
fn generatePermutationTable() [512]u8 {
    var perm: [512]u8 = undefined;
    // Standard Perlin permutation table
    const base = [256]u8{
        151, 160, 137, 91,  90,  15,  131, 13,  201, 95,  96,  53,  194, 233, 7,   225,
        140, 36,  103, 30,  69,  142, 8,   99,  37,  240, 21,  10,  23,  190, 6,   148,
        247, 120, 234, 75,  0,   26,  197, 62,  94,  252, 219, 203, 117, 35,  11,  32,
        57,  177, 33,  88,  237, 149, 56,  87,  174, 20,  125, 136, 171, 168, 68,  175,
        74,  165, 71,  134, 139, 48,  27,  166, 77,  146, 158, 231, 83,  111, 229, 122,
        60,  211, 133, 230, 220, 105, 92,  41,  55,  46,  245, 40,  244, 102, 143, 54,
        65,  25,  63,  161, 1,   216, 80,  73,  209, 76,  132, 187, 208, 89,  18,  169,
        200, 196, 135, 130, 116, 188, 159, 86,  164, 100, 109, 198, 173, 186, 3,   64,
        52,  217, 226, 250, 124, 123, 5,   202, 38,  147, 118, 126, 255, 82,  85,  212,
        207, 206, 59,  227, 47,  16,  58,  17,  182, 189, 28,  42,  223, 183, 170, 213,
        119, 248, 152, 2,   44,  154, 163, 70,  221, 153, 101, 155, 167, 43,  172, 9,
        129, 22,  39,  253, 19,  98,  108, 110, 79,  113, 224, 232, 178, 185, 112, 104,
        218, 246, 97,  228, 251, 34,  242, 193, 238, 210, 144, 12,  191, 179, 162, 241,
        81,  51,  145, 235, 249, 14,  239, 107, 49,  192, 214, 31,  181, 199, 106, 157,
        184, 84,  204, 176, 115, 121, 50,  45,  127, 4,   150, 254, 138, 236, 205, 93,
        222, 114, 67,  29,  24,  72,  243, 141, 128, 195, 78,  66,  215, 61,  156, 180,
    };
    for (0..256) |i| {
        perm[i] = base[i];
        perm[i + 256] = base[i];
    }
    return perm;
}

/// Gradient vectors for 3D Perlin noise
const GRAD3 = [12][3]f32{
    .{ 1, 1, 0 }, .{ -1, 1, 0 }, .{ 1, -1, 0 }, .{ -1, -1, 0 },
    .{ 1, 0, 1 }, .{ -1, 0, 1 }, .{ 1, 0, -1 }, .{ -1, 0, -1 },
    .{ 0, 1, 1 }, .{ 0, -1, 1 }, .{ 0, 1, -1 }, .{ 0, -1, -1 },
};

/// Fade function for smooth interpolation (improved Perlin)
fn fade(t: f32) f32 {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

/// Linear interpolation
fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + t * (b - a);
}

/// Gradient function for 3D Perlin noise
fn grad3(hash: u8, x: f32, y: f32, z: f32) f32 {
    const h = hash % 12;
    const g = GRAD3[h];
    return g[0] * x + g[1] * y + g[2] * z;
}

/// Seeded noise generator
pub const SeededNoise = struct {
    seed: u64,
    perm: [512]u8,

    const Self = @This();

    /// Create a seeded noise generator
    pub fn init(seed: u64) Self {
        var self = Self{
            .seed = seed,
            .perm = undefined,
        };
        self.generateSeededPerm();
        return self;
    }

    /// Generate permutation table from seed
    fn generateSeededPerm(self: *Self) void {
        var rng = std.Random.DefaultPrng.init(self.seed);
        var base: [256]u8 = undefined;
        for (0..256) |i| {
            base[i] = @intCast(i);
        }
        // Fisher-Yates shuffle
        var i: usize = 255;
        while (i > 0) : (i -= 1) {
            const j = rng.random().uintLessThan(usize, i + 1);
            const tmp = base[i];
            base[i] = base[j];
            base[j] = tmp;
        }
        for (0..256) |k| {
            self.perm[k] = base[k];
            self.perm[k + 256] = base[k];
        }
    }

    /// 2D Perlin noise (returns -1 to 1)
    pub fn perlin2(self: *const Self, x: f32, y: f32) f32 {
        // Integer coordinates
        const xi: i32 = @intFromFloat(@floor(x));
        const yi: i32 = @intFromFloat(@floor(y));

        // Fractional coordinates
        const xf = x - @floor(x);
        const yf = y - @floor(y);

        // Fade curves
        const u = fade(xf);
        const v = fade(yf);

        // Hash coordinates
        const px: usize = @intCast(@mod(xi, 256));
        const py: usize = @intCast(@mod(yi, 256));

        const aa = self.perm[self.perm[px] +% py];
        const ab = self.perm[self.perm[px] +% py +% 1];
        const ba = self.perm[self.perm[px +% 1] +% py];
        const bb = self.perm[self.perm[px +% 1] +% py +% 1];

        // Gradient and interpolation
        const x1 = lerp(grad2(aa, xf, yf), grad2(ba, xf - 1, yf), u);
        const x2 = lerp(grad2(ab, xf, yf - 1), grad2(bb, xf - 1, yf - 1), u);

        return lerp(x1, x2, v);
    }

    /// 3D Perlin noise (returns -1 to 1)
    pub fn perlin3(self: *const Self, x: f32, y: f32, z: f32) f32 {
        // Integer coordinates
        const xi: i32 = @intFromFloat(@floor(x));
        const yi: i32 = @intFromFloat(@floor(y));
        const zi: i32 = @intFromFloat(@floor(z));

        // Fractional coordinates
        const xf = x - @floor(x);
        const yf = y - @floor(y);
        const zf = z - @floor(z);

        // Fade curves
        const u = fade(xf);
        const v = fade(yf);
        const w = fade(zf);

        // Hash coordinates
        const px: usize = @intCast(@mod(xi, 256));
        const py: usize = @intCast(@mod(yi, 256));
        const pz: usize = @intCast(@mod(zi, 256));

        const a = self.perm[px] +% py;
        const aa = self.perm[a] +% pz;
        const ab = self.perm[a +% 1] +% pz;
        const b = self.perm[px +% 1] +% py;
        const ba = self.perm[b] +% pz;
        const bb = self.perm[b +% 1] +% pz;

        // Gradient and interpolation
        const x1 = lerp(
            grad3(self.perm[aa], xf, yf, zf),
            grad3(self.perm[ba], xf - 1, yf, zf),
            u,
        );
        const x2 = lerp(
            grad3(self.perm[ab], xf, yf - 1, zf),
            grad3(self.perm[bb], xf - 1, yf - 1, zf),
            u,
        );
        const y1 = lerp(x1, x2, v);

        const x3 = lerp(
            grad3(self.perm[aa +% 1], xf, yf, zf - 1),
            grad3(self.perm[ba +% 1], xf - 1, yf, zf - 1),
            u,
        );
        const x4 = lerp(
            grad3(self.perm[ab +% 1], xf, yf - 1, zf - 1),
            grad3(self.perm[bb +% 1], xf - 1, yf - 1, zf - 1),
            u,
        );
        const y2 = lerp(x3, x4, v);

        return lerp(y1, y2, w);
    }

    /// Fractal Brownian Motion (octave noise)
    /// Returns value in range [-1, 1]
    pub fn fbm2(self: *const Self, x: f32, y: f32, octaves: u32, lacunarity: f32, persistence: f32) f32 {
        var total: f32 = 0;
        var frequency: f32 = 1.0;
        var amplitude: f32 = 1.0;
        var max_amplitude: f32 = 0;

        for (0..octaves) |_| {
            total += self.perlin2(x * frequency, y * frequency) * amplitude;
            max_amplitude += amplitude;
            amplitude *= persistence;
            frequency *= lacunarity;
        }

        return total / max_amplitude;
    }

    /// 3D Fractal Brownian Motion
    pub fn fbm3(self: *const Self, x: f32, y: f32, z: f32, octaves: u32, lacunarity: f32, persistence: f32) f32 {
        var total: f32 = 0;
        var frequency: f32 = 1.0;
        var amplitude: f32 = 1.0;
        var max_amplitude: f32 = 0;

        for (0..octaves) |_| {
            total += self.perlin3(x * frequency, y * frequency, z * frequency) * amplitude;
            max_amplitude += amplitude;
            amplitude *= persistence;
            frequency *= lacunarity;
        }

        return total / max_amplitude;
    }

    /// Ridged multifractal noise (good for mountains)
    /// Returns value in range [0, 1]
    pub fn ridged2(self: *const Self, x: f32, y: f32, octaves: u32, lacunarity: f32, gain: f32) f32 {
        var total: f32 = 0;
        var frequency: f32 = 1.0;
        var amplitude: f32 = 1.0;
        var weight: f32 = 1.0;

        for (0..octaves) |_| {
            // Get absolute value and invert for ridges
            var signal = self.perlin2(x * frequency, y * frequency);
            signal = 1.0 - @abs(signal);
            signal *= signal; // Square for sharper ridges

            // Weight successive octaves by previous signal
            signal *= weight;
            weight = std.math.clamp(signal * gain, 0.0, 1.0);

            total += signal * amplitude;
            frequency *= lacunarity;
            amplitude *= 0.5;
        }

        return total;
    }

    /// Ridged 3D noise
    pub fn ridged3(self: *const Self, x: f32, y: f32, z: f32, octaves: u32, lacunarity: f32, gain: f32) f32 {
        var total: f32 = 0;
        var frequency: f32 = 1.0;
        var amplitude: f32 = 1.0;
        var weight: f32 = 1.0;

        for (0..octaves) |_| {
            var signal = self.perlin3(x * frequency, y * frequency, z * frequency);
            signal = 1.0 - @abs(signal);
            signal *= signal;

            signal *= weight;
            weight = std.math.clamp(signal * gain, 0.0, 1.0);

            total += signal * amplitude;
            frequency *= lacunarity;
            amplitude *= 0.5;
        }

        return total;
    }

    /// Voronoi (cellular) noise for biome boundaries
    /// Returns struct with distance to nearest point and cell ID
    pub fn voronoi2(self: *const Self, x: f32, y: f32) VoronoiResult {
        const xi: i32 = @intFromFloat(@floor(x));
        const yi: i32 = @intFromFloat(@floor(y));
        const xf = x - @floor(x);
        const yf = y - @floor(y);

        var min_dist: f32 = std.math.floatMax(f32);
        var second_dist: f32 = std.math.floatMax(f32);
        var cell_x: i32 = 0;
        var cell_y: i32 = 0;

        // Check 3x3 neighborhood
        var dy: i32 = -1;
        while (dy <= 1) : (dy += 1) {
            var dx: i32 = -1;
            while (dx <= 1) : (dx += 1) {
                const cell_xi = xi + dx;
                const cell_yi = yi + dy;

                // Get random point within this cell
                const px: usize = @intCast(@mod(cell_xi, 256));
                const py: usize = @intCast(@mod(cell_yi, 256));
                const hash = self.perm[self.perm[px] +% py];

                const point_x = @as(f32, @floatFromInt(dx)) + hashToFloat(hash) - xf;
                const point_y = @as(f32, @floatFromInt(dy)) + hashToFloat(self.perm[hash]) - yf;

                const dist = point_x * point_x + point_y * point_y;

                if (dist < min_dist) {
                    second_dist = min_dist;
                    min_dist = dist;
                    cell_x = cell_xi;
                    cell_y = cell_yi;
                } else if (dist < second_dist) {
                    second_dist = dist;
                }
            }
        }

        return .{
            .distance = @sqrt(min_dist),
            .edge_distance = @sqrt(second_dist) - @sqrt(min_dist),
            .cell_id = @as(u32, @intCast(@mod(cell_x * 374761393 + cell_y * 668265263, 1000000))),
            .cell_x = cell_x,
            .cell_y = cell_y,
        };
    }

    /// Domain-warped noise for more organic shapes
    pub fn warpedFbm2(self: *const Self, x: f32, y: f32, octaves: u32, warp_strength: f32) f32 {
        // First pass - get warp offsets
        const warp_x = self.fbm2(x, y, 2, 2.0, 0.5) * warp_strength;
        const warp_y = self.fbm2(x + 5.2, y + 1.3, 2, 2.0, 0.5) * warp_strength;

        // Second pass - sample with warped coordinates
        return self.fbm2(x + warp_x, y + warp_y, octaves, 2.0, 0.5);
    }

    /// Billow noise (absolute value of perlin, gives puffy clouds/hills)
    pub fn billow2(self: *const Self, x: f32, y: f32, octaves: u32, lacunarity: f32, persistence: f32) f32 {
        var total: f32 = 0;
        var frequency: f32 = 1.0;
        var amplitude: f32 = 1.0;
        var max_amplitude: f32 = 0;

        for (0..octaves) |_| {
            total += @abs(self.perlin2(x * frequency, y * frequency)) * amplitude;
            max_amplitude += amplitude;
            amplitude *= persistence;
            frequency *= lacunarity;
        }

        return (total / max_amplitude) * 2.0 - 1.0;
    }

    /// Swiss cheese noise (good for caves)
    pub fn swissCheese3(self: *const Self, x: f32, y: f32, z: f32, threshold: f32) bool {
        const n1 = self.perlin3(x * 0.05, y * 0.05, z * 0.05);
        const n2 = self.perlin3(x * 0.1, y * 0.1, z * 0.1) * 0.5;
        return (n1 + n2) > threshold;
    }

    /// Worm cave noise (creates connected tunnel systems)
    pub fn wormCave3(self: *const Self, x: f32, y: f32, z: f32, scale: f32, threshold: f32) bool {
        const n1 = self.perlin3(x * scale, y * scale * 0.5, z * scale);
        const n2 = self.perlin3(x * scale + 100.0, y * scale * 0.5, z * scale + 100.0);
        // Cave exists where both noise values are close to 0
        return @abs(n1) < threshold and @abs(n2) < threshold;
    }
};

/// Result from Voronoi noise calculation
pub const VoronoiResult = struct {
    /// Distance to nearest cell point
    distance: f32,
    /// Distance to edge (difference between first and second closest)
    edge_distance: f32,
    /// Unique ID for the cell
    cell_id: u32,
    /// Cell X coordinate
    cell_x: i32,
    /// Cell Y coordinate
    cell_y: i32,
};

/// 2D gradient function
fn grad2(hash: u8, x: f32, y: f32) f32 {
    const h = hash & 3;
    const u: f32 = if (h < 2) x else y;
    const v: f32 = if (h < 2) y else x;
    return (if ((h & 1) == 0) u else -u) + (if ((h & 2) == 0) v else -v);
}

/// Convert hash to float in range [0, 1]
fn hashToFloat(hash: u8) f32 {
    return @as(f32, @floatFromInt(hash)) / 255.0;
}

/// Default noise instance (seed 0)
pub const default = SeededNoise.init(0);

/// Simple 2D Perlin noise (convenience function)
pub fn perlin2(x: f32, y: f32) f32 {
    return default.perlin2(x, y);
}

/// Simple 3D Perlin noise (convenience function)
pub fn perlin3(x: f32, y: f32, z: f32) f32 {
    return default.perlin3(x, y, z);
}

// ============================================================================
// Tests
// ============================================================================

test "perlin noise range" {
    const noise = SeededNoise.init(12345);
    var min_val: f32 = 1000;
    var max_val: f32 = -1000;

    var y: f32 = 0;
    while (y < 10) : (y += 0.1) {
        var x: f32 = 0;
        while (x < 10) : (x += 0.1) {
            const val = noise.perlin2(x, y);
            min_val = @min(min_val, val);
            max_val = @max(max_val, val);
        }
    }

    // Perlin noise should be roughly in [-1, 1]
    try std.testing.expect(min_val >= -1.5);
    try std.testing.expect(max_val <= 1.5);
}

test "seeded noise determinism" {
    const noise1 = SeededNoise.init(42);
    const noise2 = SeededNoise.init(42);

    // Same seed should produce same values
    try std.testing.expectApproxEqAbs(noise1.perlin2(1.5, 2.5), noise2.perlin2(1.5, 2.5), 0.0001);
    try std.testing.expectApproxEqAbs(noise1.perlin3(1.5, 2.5, 3.5), noise2.perlin3(1.5, 2.5, 3.5), 0.0001);
}

test "different seeds produce different values" {
    const noise1 = SeededNoise.init(1);
    const noise2 = SeededNoise.init(2);

    // Different seeds should produce different values (with high probability)
    const v1 = noise1.perlin2(5.0, 5.0);
    const v2 = noise2.perlin2(5.0, 5.0);
    try std.testing.expect(@abs(v1 - v2) > 0.01);
}

test "fbm noise" {
    const noise = SeededNoise.init(999);
    const val = noise.fbm2(5.0, 5.0, 4, 2.0, 0.5);
    try std.testing.expect(val >= -1.0 and val <= 1.0);
}

test "voronoi noise" {
    const noise = SeededNoise.init(777);
    const result = noise.voronoi2(5.5, 5.5);
    try std.testing.expect(result.distance >= 0);
    try std.testing.expect(result.edge_distance >= 0);
}

test "ridged noise" {
    const noise = SeededNoise.init(888);
    const val = noise.ridged2(5.0, 5.0, 4, 2.0, 2.0);
    try std.testing.expect(val >= 0);
}
