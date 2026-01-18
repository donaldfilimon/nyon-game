//! Water Rendering System
//!
//! Provides water visual effects including:
//! - Animated wave patterns on water surface
//! - Transparency and alpha blending
//! - Depth-based coloring (darker at depth)
//! - Underwater effects (blue tint, fog, distortion)
//! - Foam at water-solid boundaries

const std = @import("std");
const math = @import("../math/math.zig");
const Color = @import("color.zig").Color;

/// Water visual system for rendering water blocks with effects
pub const Water = struct {
    /// Current animation time for wave patterns
    animation_time: f32,
    /// Speed of wave animation
    wave_speed: f32,
    /// Height/amplitude of waves
    wave_height: f32,
    /// Base transparency (0.0 = invisible, 1.0 = opaque)
    transparency: f32,
    /// Color at surface
    surface_color: Color,
    /// Color at maximum depth
    deep_color: Color,
    /// Foam color where water meets solid blocks
    foam_color: Color,
    /// Wave frequency (higher = more waves)
    wave_frequency: f32,
    /// Secondary wave frequency for variation
    wave_frequency_2: f32,
    /// Sparkle intensity for sunlight reflections
    sparkle_intensity: f32,
    /// Maximum depth for color gradient (in blocks)
    max_depth: u32,

    /// Default water configuration
    pub const DEFAULT = Water{
        .animation_time = 0.0,
        .wave_speed = 1.2,
        .wave_height = 0.08,
        .transparency = 0.6,
        .surface_color = Color.fromRgba(64, 164, 223, 153), // Light blue, semi-transparent
        .deep_color = Color.fromRgba(20, 60, 100, 200), // Dark blue, more opaque
        .foam_color = Color.fromRgba(240, 250, 255, 200), // White foam
        .wave_frequency = 2.5,
        .wave_frequency_2 = 1.7,
        .sparkle_intensity = 0.3,
        .max_depth = 8,
    };

    /// Tropical water preset (clearer, more turquoise)
    pub const TROPICAL = Water{
        .animation_time = 0.0,
        .wave_speed = 0.8,
        .wave_height = 0.05,
        .transparency = 0.5,
        .surface_color = Color.fromRgba(64, 224, 208, 128), // Turquoise
        .deep_color = Color.fromRgba(0, 105, 148, 180),
        .foam_color = Color.fromRgba(255, 255, 255, 220),
        .wave_frequency = 3.0,
        .wave_frequency_2 = 2.0,
        .sparkle_intensity = 0.4,
        .max_depth = 12,
    };

    /// Swamp water preset (murky, greenish)
    pub const SWAMP = Water{
        .animation_time = 0.0,
        .wave_speed = 0.4,
        .wave_height = 0.03,
        .transparency = 0.75,
        .surface_color = Color.fromRgba(60, 90, 50, 180),
        .deep_color = Color.fromRgba(30, 50, 25, 230),
        .foam_color = Color.fromRgba(150, 170, 130, 180),
        .wave_frequency = 1.5,
        .wave_frequency_2 = 0.8,
        .sparkle_intensity = 0.1,
        .max_depth = 4,
    };

    /// Initialize water system with default settings
    pub fn init() Water {
        return DEFAULT;
    }

    /// Update water animation
    pub fn update(self: *Water, dt: f32) void {
        self.animation_time += dt * self.wave_speed;
        // Wrap around to prevent floating point issues over long play sessions
        if (self.animation_time > 1000.0) {
            self.animation_time -= 1000.0;
        }
    }

    /// Get wave height offset at a world position
    /// Returns a value typically in range [-wave_height, +wave_height]
    pub fn getWaveOffset(self: *const Water, x: f32, z: f32) f32 {
        // Combine two sine waves at different frequencies for more natural look
        const wave1 = @sin((x * self.wave_frequency + self.animation_time * 2.0) +
            (z * self.wave_frequency * 0.7));
        const wave2 = @sin((x * self.wave_frequency_2 * 0.8 - self.animation_time * 1.5) +
            (z * self.wave_frequency_2));
        const wave3 = @sin((x + z) * self.wave_frequency * 0.5 + self.animation_time * 0.8);

        // Combine waves with different weights
        const combined = wave1 * 0.5 + wave2 * 0.3 + wave3 * 0.2;
        return combined * self.wave_height;
    }

    /// Get surface color based on depth below surface
    /// depth: 0 = at surface, higher = deeper
    pub fn getSurfaceColor(self: *const Water, depth: u32) Color {
        if (depth == 0) {
            return self.surface_color;
        }

        // Lerp between surface and deep color based on depth
        const t = @min(@as(f32, @floatFromInt(depth)) / @as(f32, @floatFromInt(self.max_depth)), 1.0);
        return Color.lerp(self.surface_color, self.deep_color, t);
    }

    /// Get the effective alpha for water at a given depth
    pub fn getAlpha(self: *const Water, depth: u32) f32 {
        const surface_alpha = @as(f32, @floatFromInt(self.surface_color.a)) / 255.0;
        const deep_alpha = @as(f32, @floatFromInt(self.deep_color.a)) / 255.0;
        const t = @min(@as(f32, @floatFromInt(depth)) / @as(f32, @floatFromInt(self.max_depth)), 1.0);
        return surface_alpha + (deep_alpha - surface_alpha) * t;
    }

    /// Calculate sparkle/shimmer effect intensity at a position
    /// Returns 0.0-1.0 for additional brightness
    pub fn getSparkle(self: *const Water, x: f32, z: f32, sun_intensity: f32) f32 {
        if (sun_intensity <= 0) return 0;

        // High-frequency noise pattern that changes with time
        const sparkle_wave = @sin(x * 7.3 + self.animation_time * 5.0) *
            @sin(z * 6.7 - self.animation_time * 4.2) *
            @sin((x + z) * 4.1 + self.animation_time * 3.0);

        // Only positive values create sparkles, and threshold them
        const raw = @max(sparkle_wave * 2.0 - 1.0, 0.0);
        return raw * self.sparkle_intensity * sun_intensity;
    }

    /// Check if a position should have foam (near water-solid boundary)
    /// Returns foam intensity 0.0-1.0
    pub fn getFoamIntensity(self: *const Water, x: f32, z: f32, is_edge: bool) f32 {
        if (!is_edge) return 0;

        // Animated foam pattern
        const foam_wave = @sin(x * 3.0 + self.animation_time * 2.0) *
            @sin(z * 2.8 - self.animation_time * 1.8);
        const foam_base = 0.6;
        return foam_base + foam_wave * 0.4;
    }
};

/// Underwater visual effects for when camera is submerged
pub const UnderwaterEffects = struct {
    /// Blue tint color overlay
    tint_color: Color,
    /// Tint intensity (0.0-1.0)
    tint_intensity: f32,
    /// Fog start distance
    fog_start: f32,
    /// Fog end distance (full fog)
    fog_end: f32,
    /// Distortion amplitude
    distortion_amount: f32,
    /// Distortion frequency
    distortion_frequency: f32,
    /// Current time for animation
    time: f32,

    pub const DEFAULT = UnderwaterEffects{
        .tint_color = Color.fromRgba(30, 80, 140, 255),
        .tint_intensity = 0.3,
        .fog_start = 2.0,
        .fog_end = 16.0,
        .distortion_amount = 0.02,
        .distortion_frequency = 3.0,
        .time = 0.0,
    };

    /// Initialize underwater effects
    pub fn init() UnderwaterEffects {
        return DEFAULT;
    }

    /// Update animation time
    pub fn update(self: *UnderwaterEffects, dt: f32) void {
        self.time += dt;
        if (self.time > 1000.0) {
            self.time -= 1000.0;
        }
    }

    /// Apply underwater tint to a color
    pub fn applyTint(self: *const UnderwaterEffects, color: Color) Color {
        return Color.lerp(color, self.tint_color, self.tint_intensity);
    }

    /// Calculate fog factor for a given distance
    /// Returns 0.0 (no fog) to 1.0 (full fog)
    pub fn getFogFactor(self: *const UnderwaterEffects, distance: f32) f32 {
        if (distance <= self.fog_start) return 0.0;
        if (distance >= self.fog_end) return 1.0;
        return (distance - self.fog_start) / (self.fog_end - self.fog_start);
    }

    /// Apply fog to a color based on distance
    pub fn applyFog(self: *const UnderwaterEffects, color: Color, distance: f32) Color {
        const fog_factor = self.getFogFactor(distance);
        return Color.lerp(color, self.tint_color, fog_factor);
    }

    /// Get distortion offset for screen coordinates
    /// Returns (dx, dy) offset in normalized screen space
    pub fn getDistortion(self: *const UnderwaterEffects, screen_x: f32, screen_y: f32) struct { dx: f32, dy: f32 } {
        const wave_x = @sin(screen_y * self.distortion_frequency * 10.0 + self.time * 2.0);
        const wave_y = @sin(screen_x * self.distortion_frequency * 8.0 + self.time * 1.7);
        return .{
            .dx = wave_x * self.distortion_amount,
            .dy = wave_y * self.distortion_amount * 0.7,
        };
    }

    /// Apply full underwater effect to a pixel color
    pub fn applyEffect(self: *const UnderwaterEffects, color: Color, distance: f32) Color {
        // First apply tint
        const tinted = self.applyTint(color);
        // Then apply distance fog
        return self.applyFog(tinted, distance);
    }
};

/// Blend two colors using alpha blending (src over dst)
/// alpha: 0.0 = fully dst, 1.0 = fully src
pub fn blendColors(src: Color, dst: Color, alpha: f32) Color {
    const clamped_alpha = std.math.clamp(alpha, 0.0, 1.0);

    const src_f = src.toFloat();
    const dst_f = dst.toFloat();

    // Standard alpha blending: result = src * alpha + dst * (1 - alpha)
    const inv_alpha = 1.0 - clamped_alpha;

    return Color.fromFloat(
        src_f[0] * clamped_alpha + dst_f[0] * inv_alpha,
        src_f[1] * clamped_alpha + dst_f[1] * inv_alpha,
        src_f[2] * clamped_alpha + dst_f[2] * inv_alpha,
        src_f[3] * clamped_alpha + dst_f[3] * inv_alpha,
    );
}

/// Blend using source alpha (premultiplied alpha blend)
pub fn blendWithAlpha(src: Color, dst: Color) Color {
    return Color.blend(dst, src);
}

/// Additive blending (for sparkles, glow effects)
pub fn blendAdditive(src: Color, dst: Color, intensity: f32) Color {
    const src_f = src.toFloat();
    const dst_f = dst.toFloat();

    return Color.fromFloat(
        @min(dst_f[0] + src_f[0] * intensity, 1.0),
        @min(dst_f[1] + src_f[1] * intensity, 1.0),
        @min(dst_f[2] + src_f[2] * intensity, 1.0),
        dst_f[3],
    );
}

/// Water block rendering helper
pub const WaterRenderer = struct {
    water: Water,
    underwater: UnderwaterEffects,
    sun_intensity: f32,

    pub fn init() WaterRenderer {
        return .{
            .water = Water.init(),
            .underwater = UnderwaterEffects.init(),
            .sun_intensity = 1.0,
        };
    }

    /// Update all water animations
    pub fn update(self: *WaterRenderer, dt: f32) void {
        self.water.update(dt);
        self.underwater.update(dt);
    }

    /// Set sun intensity for sparkle effects
    pub fn setSunIntensity(self: *WaterRenderer, intensity: f32) void {
        self.sun_intensity = intensity;
    }

    /// Get the final color for a water surface pixel
    pub fn getWaterColor(
        self: *const WaterRenderer,
        world_x: f32,
        world_z: f32,
        depth: u32,
        is_edge: bool,
        base_lighting: f32,
    ) Color {
        // Get base water color for this depth
        var color = self.water.getSurfaceColor(depth);

        // Apply wave-based lighting variation
        const wave_offset = self.water.getWaveOffset(world_x, world_z);
        const wave_light = 1.0 + wave_offset * 2.0; // Waves affect perceived brightness

        // Apply sparkle effect
        const sparkle = self.water.getSparkle(world_x, world_z, self.sun_intensity);

        // Apply foam if at edge
        const foam_intensity = self.water.getFoamIntensity(world_x, world_z, is_edge);

        // Combine all effects
        var color_f = color.toFloat();
        const lighting = base_lighting * wave_light;

        color_f[0] = std.math.clamp(color_f[0] * lighting + sparkle, 0.0, 1.0);
        color_f[1] = std.math.clamp(color_f[1] * lighting + sparkle, 0.0, 1.0);
        color_f[2] = std.math.clamp(color_f[2] * lighting + sparkle * 0.8, 0.0, 1.0);

        var result = Color.fromFloat(color_f[0], color_f[1], color_f[2], color_f[3]);

        // Blend in foam if present
        if (foam_intensity > 0) {
            result = blendColors(self.water.foam_color, result, foam_intensity);
        }

        return result;
    }

    /// Check if camera is underwater and get appropriate effect
    pub fn isUnderwater(self: *const WaterRenderer, camera_y: f32, water_surface_y: f32) bool {
        _ = self;
        return camera_y < water_surface_y;
    }

    /// Apply underwater effect to final framebuffer color
    pub fn applyUnderwaterEffect(self: *const WaterRenderer, color: Color, distance: f32) Color {
        return self.underwater.applyEffect(color, distance);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "water init" {
    const water = Water.init();
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), water.animation_time, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), water.transparency, 0.001);
}

test "water update" {
    var water = Water.init();
    water.update(0.1);
    try std.testing.expect(water.animation_time > 0);
}

test "wave offset" {
    const water = Water.init();
    const offset = water.getWaveOffset(5.0, 3.0);
    try std.testing.expect(@abs(offset) <= water.wave_height * 1.5);
}

test "surface color depth" {
    const water = Water.init();
    const surface = water.getSurfaceColor(0);
    const deep = water.getSurfaceColor(8);

    // Deep water should be darker
    try std.testing.expect(deep.r <= surface.r);
    try std.testing.expect(deep.g <= surface.g);
}

test "alpha blending" {
    const src = Color.fromRgba(255, 0, 0, 255);
    const dst = Color.fromRgba(0, 0, 255, 255);

    // 50% blend should give purple
    const blended = blendColors(src, dst, 0.5);
    try std.testing.expect(blended.r > 100);
    try std.testing.expect(blended.b > 100);

    // Full src
    const full_src = blendColors(src, dst, 1.0);
    try std.testing.expectEqual(@as(u8, 255), full_src.r);
    try std.testing.expectEqual(@as(u8, 0), full_src.b);

    // Full dst
    const full_dst = blendColors(src, dst, 0.0);
    try std.testing.expectEqual(@as(u8, 0), full_dst.r);
    try std.testing.expectEqual(@as(u8, 255), full_dst.b);
}

test "underwater fog" {
    const underwater = UnderwaterEffects.init();

    // No fog at start
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), underwater.getFogFactor(0.0), 0.001);

    // Full fog past end
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), underwater.getFogFactor(20.0), 0.001);

    // Partial fog in between
    const mid = underwater.getFogFactor(9.0);
    try std.testing.expect(mid > 0.0 and mid < 1.0);
}

test "water renderer" {
    var renderer = WaterRenderer.init();
    renderer.update(0.016);

    const color = renderer.getWaterColor(10.0, 10.0, 2, false, 1.0);
    try std.testing.expect(color.a > 0);
}

test "water presets" {
    // Test that presets have valid values
    const default = Water.DEFAULT;
    try std.testing.expect(default.wave_speed > 0);
    try std.testing.expect(default.transparency > 0 and default.transparency <= 1.0);

    const tropical = Water.TROPICAL;
    try std.testing.expect(tropical.wave_frequency > 0);

    const swamp = Water.SWAMP;
    try std.testing.expect(swamp.max_depth > 0);
}

test "sparkle effect" {
    const water = Water.init();

    // Sparkle should be 0 when sun intensity is 0
    const no_sparkle = water.getSparkle(5.0, 5.0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), no_sparkle, 0.001);

    // Sparkle should be in valid range with sun
    const sparkle = water.getSparkle(5.0, 5.0, 1.0);
    try std.testing.expect(sparkle >= 0.0 and sparkle <= 1.0);
}

test "foam intensity" {
    var water = Water.init();
    water.animation_time = 0;

    // No foam when not at edge
    const no_foam = water.getFoamIntensity(5.0, 5.0, false);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), no_foam, 0.001);

    // Foam should be positive at edge
    const foam = water.getFoamIntensity(5.0, 5.0, true);
    try std.testing.expect(foam > 0.0);
}

test "underwater distortion" {
    var underwater = UnderwaterEffects.init();
    underwater.time = 1.0;

    const distortion = underwater.getDistortion(0.5, 0.5);
    // Distortion should be bounded
    try std.testing.expect(@abs(distortion.dx) <= underwater.distortion_amount * 2);
    try std.testing.expect(@abs(distortion.dy) <= underwater.distortion_amount * 2);
}

test "additive blending" {
    const src = Color.fromRgba(100, 50, 50, 255);
    const dst = Color.fromRgba(50, 100, 50, 255);

    const result = blendAdditive(src, dst, 1.0);
    // Result should be brighter
    try std.testing.expect(result.r >= dst.r);
    try std.testing.expect(result.g >= dst.g);
}
