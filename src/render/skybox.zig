//! Skybox and Atmospheric Rendering
//!
//! Provides day/night sky rendering with celestial bodies, stars, and procedural clouds.

const std = @import("std");
const math = @import("../math/math.zig");
const Color = @import("color.zig").Color;

/// Sky color definition for a specific time of day
const SkyGradient = struct {
    horizon: Color,
    zenith: Color,
};

/// Time-based sky colors
const SKY_DAWN = SkyGradient{
    .horizon = Color.fromRgb(255, 140, 90), // Orange/pink
    .zenith = Color.fromRgb(135, 180, 225), // Light blue
};

const SKY_DAY = SkyGradient{
    .horizon = Color.fromRgb(150, 200, 255), // Light blue
    .zenith = Color.fromRgb(50, 100, 200), // Deep blue
};

const SKY_DUSK = SkyGradient{
    .horizon = Color.fromRgb(255, 100, 50), // Orange/red
    .zenith = Color.fromRgb(80, 50, 120), // Purple
};

const SKY_NIGHT = SkyGradient{
    .horizon = Color.fromRgb(15, 20, 40), // Dark blue
    .zenith = Color.fromRgb(5, 10, 25), // Near black
};

/// Maximum number of stars to render
const MAX_STARS: usize = 200;

/// Maximum number of clouds
const MAX_CLOUDS: usize = 20;

/// A single star in the sky
const Star = struct {
    /// Screen position as normalized coordinates (0-1)
    x: f32,
    y: f32,
    /// Brightness (0-1)
    brightness: f32,
    /// Size in pixels
    size: u8,
    /// Twinkle phase offset
    twinkle_phase: f32,
};

/// A procedural cloud
const Cloud = struct {
    /// Position (x: 0-1 horizontal, y: 0-0.5 vertical from horizon)
    x: f32,
    y: f32,
    /// Size scale
    scale: f32,
    /// Base opacity (0-1)
    opacity: f32,
    /// Drift speed
    speed: f32,
};

/// Skybox renderer
pub const Skybox = struct {
    /// Random seed for procedural generation
    seed: u64,
    /// Pre-generated star positions
    stars: [MAX_STARS]Star,
    /// Pre-generated clouds
    clouds: [MAX_CLOUDS]Cloud,
    /// Animation time accumulator
    time_accumulator: f32,

    const Self = @This();

    /// Initialize the skybox with a random seed
    pub fn init(seed: u64) Self {
        var self = Self{
            .seed = seed,
            .stars = undefined,
            .clouds = undefined,
            .time_accumulator = 0,
        };

        // Generate stars
        var rng = std.Random.DefaultPrng.init(seed);
        const random = rng.random();

        for (&self.stars) |*star| {
            star.x = random.float(f32);
            star.y = random.float(f32) * 0.7; // Stars mostly in upper sky
            star.brightness = 0.3 + random.float(f32) * 0.7;
            star.size = if (random.float(f32) > 0.9) 2 else 1;
            star.twinkle_phase = random.float(f32) * std.math.tau;
        }

        // Generate clouds
        for (&self.clouds) |*cloud| {
            cloud.x = random.float(f32);
            cloud.y = random.float(f32) * 0.4 + 0.1; // Clouds in middle band
            cloud.scale = 0.5 + random.float(f32) * 1.0;
            cloud.opacity = 0.3 + random.float(f32) * 0.4;
            cloud.speed = 0.01 + random.float(f32) * 0.02;
        }

        return self;
    }

    /// Update skybox animation state
    pub fn update(self: *Self, dt: f32) void {
        self.time_accumulator += dt;

        // Update cloud positions (drift slowly)
        for (&self.clouds) |*cloud| {
            cloud.x += cloud.speed * dt;
            if (cloud.x > 1.2) cloud.x -= 1.4; // Wrap around
        }
    }

    /// Get interpolated sky gradient for current time
    fn getSkyGradient(time_of_day: f32) SkyGradient {
        // time_of_day: 0.0 = midnight, 0.25 = dawn, 0.5 = noon, 0.75 = dusk
        const t = time_of_day;

        if (t < 0.2) {
            // Night to pre-dawn
            const blend = t / 0.2;
            return SkyGradient{
                .horizon = Color.lerp(SKY_NIGHT.horizon, SKY_DAWN.horizon, blend * 0.3),
                .zenith = Color.lerp(SKY_NIGHT.zenith, SKY_DAWN.zenith, blend * 0.2),
            };
        } else if (t < 0.3) {
            // Dawn (sunrise)
            const blend = (t - 0.2) / 0.1;
            return SkyGradient{
                .horizon = Color.lerp(SKY_DAWN.horizon, SKY_DAY.horizon, blend),
                .zenith = Color.lerp(SKY_DAWN.zenith, SKY_DAY.zenith, blend),
            };
        } else if (t < 0.7) {
            // Daytime
            const mid = @abs(t - 0.5) / 0.2;
            const brightness = 1.0 - mid * 0.1;
            return SkyGradient{
                .horizon = Color.fromRgb(
                    @intFromFloat(@as(f32, @floatFromInt(SKY_DAY.horizon.r)) * brightness),
                    @intFromFloat(@as(f32, @floatFromInt(SKY_DAY.horizon.g)) * brightness),
                    @intFromFloat(@as(f32, @floatFromInt(SKY_DAY.horizon.b)) * brightness),
                ),
                .zenith = Color.fromRgb(
                    @intFromFloat(@as(f32, @floatFromInt(SKY_DAY.zenith.r)) * brightness),
                    @intFromFloat(@as(f32, @floatFromInt(SKY_DAY.zenith.g)) * brightness),
                    @intFromFloat(@as(f32, @floatFromInt(SKY_DAY.zenith.b)) * brightness),
                ),
            };
        } else if (t < 0.8) {
            // Dusk (sunset)
            const blend = (t - 0.7) / 0.1;
            return SkyGradient{
                .horizon = Color.lerp(SKY_DAY.horizon, SKY_DUSK.horizon, blend),
                .zenith = Color.lerp(SKY_DAY.zenith, SKY_DUSK.zenith, blend),
            };
        } else {
            // Night
            const blend = (t - 0.8) / 0.2;
            return SkyGradient{
                .horizon = Color.lerp(SKY_DUSK.horizon, SKY_NIGHT.horizon, blend),
                .zenith = Color.lerp(SKY_DUSK.zenith, SKY_NIGHT.zenith, blend),
            };
        }
    }

    /// Calculate sun position based on time of day
    /// Returns (x, y) in normalized screen coordinates, or null if below horizon
    fn getSunPosition(time_of_day: f32) ?struct { x: f32, y: f32 } {
        // Sun is visible from 0.25 (dawn) to 0.75 (dusk)
        if (time_of_day < 0.2 or time_of_day > 0.8) return null;

        // Map 0.25-0.75 to arc across sky
        const sun_progress = (time_of_day - 0.25) / 0.5;
        const angle = sun_progress * std.math.pi; // 0 to PI

        // Sun moves in an arc from left to right
        const x = 0.1 + 0.8 * sun_progress;
        const y = 0.6 - @sin(angle) * 0.5; // Peak at noon

        return .{ .x = x, .y = y };
    }

    /// Calculate moon position based on time of day
    /// Returns (x, y) in normalized screen coordinates, or null if below horizon
    fn getMoonPosition(time_of_day: f32) ?struct { x: f32, y: f32 } {
        // Moon is visible from 0.75 (dusk) through midnight to 0.25 (dawn)
        const is_night = time_of_day >= 0.75 or time_of_day <= 0.25;
        if (!is_night) return null;

        // Normalize moon time (0 at dusk, 1 at dawn)
        const moon_time = if (time_of_day >= 0.75)
            (time_of_day - 0.75) / 0.5
        else
            (time_of_day + 0.25) / 0.5;

        const angle = moon_time * std.math.pi;
        const x = 0.1 + 0.8 * moon_time;
        const y = 0.6 - @sin(angle) * 0.4;

        return .{ .x = x, .y = y };
    }

    /// Get star visibility factor (0 = invisible, 1 = fully visible)
    fn getStarVisibility(time_of_day: f32) f32 {
        // Stars fade in at dusk (0.75-0.85) and fade out at dawn (0.15-0.25)
        if (time_of_day >= 0.85 or time_of_day <= 0.15) {
            return 1.0;
        } else if (time_of_day >= 0.75) {
            return (time_of_day - 0.75) / 0.1;
        } else if (time_of_day <= 0.25) {
            return (0.25 - time_of_day) / 0.1;
        }
        return 0.0;
    }

    /// Render the skybox to a framebuffer
    /// time_of_day: 0.0 = midnight, 0.5 = noon, 1.0 = midnight
    pub fn render(
        self: *const Self,
        framebuffer: []Color,
        width: u32,
        height: u32,
        time_of_day: f32,
    ) void {
        const gradient = getSkyGradient(time_of_day);
        const star_visibility = getStarVisibility(time_of_day);
        const fheight = @as(f32, @floatFromInt(height));

        // Render sky gradient (top to bottom)
        var y: u32 = 0;
        while (y < height) : (y += 1) {
            const t = @as(f32, @floatFromInt(y)) / fheight;
            const sky_color = Color.lerp(gradient.zenith, gradient.horizon, t);

            var x: u32 = 0;
            while (x < width) : (x += 1) {
                const idx = y * width + x;
                framebuffer[idx] = sky_color;
            }
        }

        // Render stars (only at night)
        if (star_visibility > 0.01) {
            self.renderStars(framebuffer, width, height, star_visibility);
        }

        // Render celestial bodies
        if (getSunPosition(time_of_day)) |sun| {
            self.renderSun(framebuffer, width, height, sun.x, sun.y, time_of_day);
        }

        if (getMoonPosition(time_of_day)) |moon| {
            self.renderMoon(framebuffer, width, height, moon.x, moon.y);
        }

        // Render clouds (reduced at night)
        const cloud_opacity: f32 = if (time_of_day > 0.25 and time_of_day < 0.75) 1.0 else 0.3;
        if (cloud_opacity > 0.1) {
            self.renderClouds(framebuffer, width, height, cloud_opacity, gradient);
        }
    }

    /// Render stars with twinkling effect
    fn renderStars(
        self: *const Self,
        framebuffer: []Color,
        width: u32,
        height: u32,
        visibility: f32,
    ) void {
        for (self.stars) |star| {
            // Twinkle effect
            const twinkle = 0.7 + 0.3 * @sin(self.time_accumulator * 3.0 + star.twinkle_phase);
            const alpha = star.brightness * visibility * twinkle;

            if (alpha < 0.1) continue;

            const sx: i32 = @intFromFloat(star.x * @as(f32, @floatFromInt(width)));
            const sy: i32 = @intFromFloat(star.y * @as(f32, @floatFromInt(height)));

            if (sx < 0 or sy < 0) continue;
            const ux: u32 = @intCast(sx);
            const uy: u32 = @intCast(sy);
            if (ux >= width or uy >= height) continue;

            const star_color = Color.fromRgba(
                255,
                255,
                @intFromFloat(200 + 55 * star.brightness),
                @intFromFloat(alpha * 255),
            );

            const idx = uy * width + ux;
            framebuffer[idx] = Color.blend(framebuffer[idx], star_color);

            // Larger stars get extra pixels
            if (star.size > 1 and alpha > 0.5) {
                if (ux > 0) framebuffer[idx - 1] = Color.blend(framebuffer[idx - 1], star_color);
                if (ux + 1 < width) framebuffer[idx + 1] = Color.blend(framebuffer[idx + 1], star_color);
                if (uy > 0) framebuffer[idx - width] = Color.blend(framebuffer[idx - width], star_color);
                if (uy + 1 < height) framebuffer[idx + width] = Color.blend(framebuffer[idx + width], star_color);
            }
        }
    }

    /// Render the sun
    fn renderSun(
        _: *const Self,
        framebuffer: []Color,
        width: u32,
        height: u32,
        norm_x: f32,
        norm_y: f32,
        time_of_day: f32,
    ) void {
        const cx: i32 = @intFromFloat(norm_x * @as(f32, @floatFromInt(width)));
        const cy: i32 = @intFromFloat(norm_y * @as(f32, @floatFromInt(height)));

        // Sun color varies with time (more orange at sunrise/sunset)
        const is_near_horizon = time_of_day < 0.35 or time_of_day > 0.65;
        const sun_core = if (is_near_horizon)
            Color.fromRgb(255, 200, 100) // Orange
        else
            Color.fromRgb(255, 250, 200); // Yellow/white

        const sun_glow = if (is_near_horizon)
            Color.fromRgba(255, 150, 50, 100)
        else
            Color.fromRgba(255, 240, 150, 80);

        const radius: i32 = @intFromFloat(@as(f32, @floatFromInt(@min(width, height))) * 0.04);
        const glow_radius: i32 = radius * 2;

        // Draw glow (outer ring)
        var dy: i32 = -glow_radius;
        while (dy <= glow_radius) : (dy += 1) {
            var dx: i32 = -glow_radius;
            while (dx <= glow_radius) : (dx += 1) {
                const dist_sq = dx * dx + dy * dy;
                const glow_sq = glow_radius * glow_radius;

                if (dist_sq > glow_sq) continue;

                const px = cx + dx;
                const py = cy + dy;

                if (px < 0 or py < 0) continue;
                const upx: u32 = @intCast(px);
                const upy: u32 = @intCast(py);
                if (upx >= width or upy >= height) continue;

                const idx = upy * width + upx;
                const dist = @sqrt(@as(f32, @floatFromInt(dist_sq)));
                const fradius = @as(f32, @floatFromInt(radius));

                if (dist < fradius) {
                    // Core
                    framebuffer[idx] = sun_core;
                } else {
                    // Glow falloff
                    const glow_t = (dist - fradius) / @as(f32, @floatFromInt(glow_radius - radius));
                    const glow_alpha = (1.0 - glow_t) * (1.0 - glow_t);
                    if (glow_alpha > 0.05) {
                        const glow_color = Color.fromRgba(
                            sun_glow.r,
                            sun_glow.g,
                            sun_glow.b,
                            @intFromFloat(glow_alpha * @as(f32, @floatFromInt(sun_glow.a))),
                        );
                        framebuffer[idx] = Color.blend(framebuffer[idx], glow_color);
                    }
                }
            }
        }
    }

    /// Render the moon with simple crater texture
    fn renderMoon(
        self: *const Self,
        framebuffer: []Color,
        width: u32,
        height: u32,
        norm_x: f32,
        norm_y: f32,
    ) void {
        const cx: i32 = @intFromFloat(norm_x * @as(f32, @floatFromInt(width)));
        const cy: i32 = @intFromFloat(norm_y * @as(f32, @floatFromInt(height)));

        const radius: i32 = @intFromFloat(@as(f32, @floatFromInt(@min(width, height))) * 0.03);

        // Simple crater positions (relative to center, normalized)
        const craters = [_][3]f32{
            .{ -0.3, -0.2, 0.15 }, // x, y, size
            .{ 0.2, 0.3, 0.1 },
            .{ 0.1, -0.3, 0.12 },
            .{ -0.2, 0.2, 0.08 },
        };

        var dy: i32 = -radius;
        while (dy <= radius) : (dy += 1) {
            var dx: i32 = -radius;
            while (dx <= radius) : (dx += 1) {
                const dist_sq = dx * dx + dy * dy;
                const radius_sq = radius * radius;

                if (dist_sq > radius_sq) continue;

                const px = cx + dx;
                const py = cy + dy;

                if (px < 0 or py < 0) continue;
                const upx: u32 = @intCast(px);
                const upy: u32 = @intCast(py);
                if (upx >= width or upy >= height) continue;

                // Normalized position within moon
                const fradius = @as(f32, @floatFromInt(radius));
                const norm_dx = @as(f32, @floatFromInt(dx)) / fradius;
                const norm_dy = @as(f32, @floatFromInt(dy)) / fradius;

                // Base moon color (gray-white)
                var brightness: f32 = 0.85;

                // Add crater darkening
                for (craters) |crater| {
                    const cdx = norm_dx - crater[0];
                    const cdy = norm_dy - crater[1];
                    const cdist = @sqrt(cdx * cdx + cdy * cdy);
                    if (cdist < crater[2]) {
                        brightness -= 0.15 * (1.0 - cdist / crater[2]);
                    }
                }

                // Subtle noise using seed
                const noise_idx: usize = @intCast(@mod(self.seed +% @as(u64, @intCast(@abs(dx))) *% 31 +% @as(u64, @intCast(@abs(dy))) *% 37, 100));
                const noise = @as(f32, @floatFromInt(noise_idx % 10)) / 100.0;
                brightness += noise - 0.05;

                brightness = std.math.clamp(brightness, 0.5, 1.0);

                const moon_color = Color.fromRgb(
                    @intFromFloat(220 * brightness),
                    @intFromFloat(220 * brightness),
                    @intFromFloat(230 * brightness),
                );

                const idx = upy * width + upx;
                framebuffer[idx] = moon_color;
            }
        }
    }

    /// Render procedural clouds
    fn renderClouds(
        self: *const Self,
        framebuffer: []Color,
        width: u32,
        height: u32,
        opacity_mult: f32,
        gradient: SkyGradient,
    ) void {
        const fwidth = @as(f32, @floatFromInt(width));
        const fheight = @as(f32, @floatFromInt(height));

        for (self.clouds) |cloud| {
            // Cloud center position
            const cloud_cx = cloud.x * fwidth;
            const cloud_cy = cloud.y * fheight;

            // Cloud size based on scale
            const cloud_width = fwidth * 0.15 * cloud.scale;
            const cloud_height = fheight * 0.05 * cloud.scale;

            // Render cloud as soft elliptical blobs
            const min_x: i32 = @max(0, @as(i32, @intFromFloat(cloud_cx - cloud_width)));
            const max_x: i32 = @min(@as(i32, @intCast(width - 1)), @as(i32, @intFromFloat(cloud_cx + cloud_width)));
            const min_y: i32 = @max(0, @as(i32, @intFromFloat(cloud_cy - cloud_height)));
            const max_y: i32 = @min(@as(i32, @intCast(height - 1)), @as(i32, @intFromFloat(cloud_cy + cloud_height)));

            var py: i32 = min_y;
            while (py <= max_y) : (py += 1) {
                var px: i32 = min_x;
                while (px <= max_x) : (px += 1) {
                    const dx = (@as(f32, @floatFromInt(px)) - cloud_cx) / cloud_width;
                    const dy = (@as(f32, @floatFromInt(py)) - cloud_cy) / cloud_height;

                    // Elliptical falloff
                    const dist_sq = dx * dx + dy * dy;
                    if (dist_sq > 1.0) continue;

                    // Soft edge falloff
                    const falloff = 1.0 - dist_sq;
                    const alpha = falloff * falloff * cloud.opacity * opacity_mult;

                    if (alpha < 0.02) continue;

                    const upx: u32 = @intCast(px);
                    const upy: u32 = @intCast(py);
                    const idx = upy * width + upx;

                    // Cloud color is white/light gray, tinted by sky
                    const sky_t = @as(f32, @floatFromInt(upy)) / fheight;
                    const sky_color = Color.lerp(gradient.zenith, gradient.horizon, sky_t);

                    // Blend white cloud with sky tint
                    const cloud_color = Color.fromRgba(
                        @intFromFloat(std.math.clamp(@as(f32, @floatFromInt(sky_color.r)) * 0.3 + 180, 0, 255)),
                        @intFromFloat(std.math.clamp(@as(f32, @floatFromInt(sky_color.g)) * 0.3 + 180, 0, 255)),
                        @intFromFloat(std.math.clamp(@as(f32, @floatFromInt(sky_color.b)) * 0.3 + 180, 0, 255)),
                        @intFromFloat(alpha * 200),
                    );

                    framebuffer[idx] = Color.blend(framebuffer[idx], cloud_color);
                }
            }
        }
    }

    /// Render sky directly to pixels without depth testing (for background pass)
    pub fn renderBackground(
        self: *const Self,
        framebuffer: []Color,
        width: u32,
        height: u32,
        time_of_day: f32,
    ) void {
        self.render(framebuffer, width, height, time_of_day);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "skybox init" {
    const skybox = Skybox.init(12345);
    try std.testing.expect(skybox.stars[0].brightness > 0);
    try std.testing.expect(skybox.clouds[0].scale > 0);
}

test "sky gradient interpolation" {
    // Test dawn
    const dawn = Skybox.getSkyGradient(0.25);
    try std.testing.expect(dawn.horizon.r > 100); // Should be orange-ish

    // Test noon
    const noon = Skybox.getSkyGradient(0.5);
    try std.testing.expect(noon.zenith.b > noon.zenith.r); // Blue sky

    // Test night
    const night = Skybox.getSkyGradient(0.0);
    try std.testing.expect(night.zenith.r < 50); // Dark
}

test "star visibility" {
    // Night time - full visibility
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), Skybox.getStarVisibility(0.0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), Skybox.getStarVisibility(0.9), 0.01);

    // Day time - no visibility
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), Skybox.getStarVisibility(0.5), 0.01);
}

test "sun position" {
    // Sun should be visible at noon
    const noon_sun = Skybox.getSunPosition(0.5);
    try std.testing.expect(noon_sun != null);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), noon_sun.?.x, 0.1);

    // Sun should not be visible at midnight
    const midnight_sun = Skybox.getSunPosition(0.0);
    try std.testing.expect(midnight_sun == null);
}

test "moon position" {
    // Moon should be visible at midnight
    const midnight_moon = Skybox.getMoonPosition(0.0);
    try std.testing.expect(midnight_moon != null);

    // Moon should not be visible at noon
    const noon_moon = Skybox.getMoonPosition(0.5);
    try std.testing.expect(noon_moon == null);
}

test "skybox update" {
    var skybox = Skybox.init(12345);
    const initial_time = skybox.time_accumulator;
    skybox.update(0.016);
    try std.testing.expect(skybox.time_accumulator > initial_time);
}
