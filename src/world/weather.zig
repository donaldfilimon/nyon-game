//! Weather System
//!
//! Comprehensive weather simulation for the Nyon Game Engine.
//! Supports multiple weather types with smooth transitions, biome-specific
//! weather patterns, and integration with skybox, lighting, particles, and audio.

const std = @import("std");
const math = @import("../math/math.zig");
const biome = @import("biome.zig");
const Color = @import("../render/color.zig").Color;
const particles = @import("../render/particles.zig");

/// Available weather types
pub const WeatherType = enum(u8) {
    clear,
    cloudy,
    rain,
    storm, // Rain + lightning
    snow,
    fog,

    /// Get display name for weather type
    pub fn getName(self: WeatherType) []const u8 {
        return switch (self) {
            .clear => "Clear",
            .cloudy => "Cloudy",
            .rain => "Rain",
            .storm => "Storm",
            .snow => "Snow",
            .fog => "Fog",
        };
    }

    /// Check if this weather produces precipitation
    pub fn hasPrecipitation(self: WeatherType) bool {
        return switch (self) {
            .rain, .storm, .snow => true,
            else => false,
        };
    }

    /// Check if this weather reduces visibility
    pub fn reducesVisibility(self: WeatherType) bool {
        return switch (self) {
            .rain, .storm, .snow, .fog => true,
            else => false,
        };
    }

    /// Check if this weather darkens the sky
    pub fn darkensSky(self: WeatherType) bool {
        return switch (self) {
            .cloudy, .rain, .storm, .fog => true,
            else => false,
        };
    }
};

/// Lightning flash state
pub const LightningFlash = struct {
    active: bool,
    intensity: f32, // 0-1 brightness
    timer: f32, // Time remaining for flash
    position: math.Vec3, // World position of strike
    distance: f32, // Distance from player for thunder delay

    pub const FLASH_DURATION: f32 = 0.15;
    pub const RUMBLE_DURATION: f32 = 2.0;

    pub fn init() LightningFlash {
        return .{
            .active = false,
            .intensity = 0,
            .timer = 0,
            .position = math.Vec3.ZERO,
            .distance = 0,
        };
    }

    pub fn trigger(self: *LightningFlash, pos: math.Vec3, player_pos: math.Vec3) void {
        self.active = true;
        self.intensity = 1.0;
        self.timer = FLASH_DURATION;
        self.position = pos;
        self.distance = math.Vec3.distance(pos, player_pos);
    }

    pub fn update(self: *LightningFlash, dt: f32) void {
        if (!self.active) return;

        self.timer -= dt;
        if (self.timer <= 0) {
            self.active = false;
            self.intensity = 0;
        } else {
            // Flash intensity fades quickly
            self.intensity = self.timer / FLASH_DURATION;
        }
    }

    /// Get thunder delay in seconds (sound of thunder after flash)
    /// Based on speed of sound (~343 m/s), 1 block = 1 meter
    pub fn getThunderDelay(self: *const LightningFlash) f32 {
        return self.distance / 343.0;
    }
};

/// Precipitation particle configuration
pub const PrecipitationConfig = struct {
    /// Particle velocity (direction and speed)
    velocity: math.Vec3,
    /// Particle color
    color: Color,
    /// Particles per second at max intensity
    emit_rate: f32,
    /// Particle lifetime
    lifetime: f32,
    /// Particle size
    size: f32,
    /// Gravity multiplier
    gravity: f32,
    /// Whether particles should streak (rain) or drift (snow)
    streak: bool,

    pub const RAIN = PrecipitationConfig{
        .velocity = math.Vec3.init(0, -15, 0),
        .color = Color.fromRgba(150, 180, 255, 150),
        .emit_rate = 500,
        .lifetime = 1.0,
        .size = 1.5,
        .gravity = 0.5,
        .streak = true,
    };

    pub const SNOW = PrecipitationConfig{
        .velocity = math.Vec3.init(0, -1.0, 0),
        .color = Color.fromRgba(255, 255, 255, 220),
        .emit_rate = 150,
        .lifetime = 8.0,
        .size = 2.0,
        .gravity = 0.1,
        .streak = false,
    };

    pub const STORM_RAIN = PrecipitationConfig{
        .velocity = math.Vec3.init(-3, -20, -1),
        .color = Color.fromRgba(130, 160, 230, 180),
        .emit_rate = 800,
        .lifetime = 0.8,
        .size = 1.8,
        .gravity = 0.8,
        .streak = true,
    };
};

/// Weather state and simulation
pub const Weather = struct {
    /// Current active weather type
    current: WeatherType,
    /// Target weather type (for transitions)
    target: WeatherType,
    /// Transition progress (0 = current, 1 = target)
    transition: f32,
    /// Time remaining until weather changes (seconds)
    duration: f32,
    /// Weather intensity (0-1, affects precipitation amount and effects)
    intensity: f32,
    /// Target intensity for smooth ramping
    target_intensity: f32,
    /// Wind direction and strength (x, z components)
    wind: math.Vec2,
    /// Target wind for smooth transitions
    target_wind: math.Vec2,
    /// Timer until next thunder strike (storm only)
    thunder_timer: f32,
    /// Current lightning flash state
    lightning: LightningFlash,
    /// Fog density (0-1)
    fog_density: f32,
    /// Accumulated precipitation time (for puddles/snow accumulation)
    precipitation_accumulation: f32,
    /// Whether weather system is paused
    paused: bool,
    /// Time of day (0-1, for fog behavior)
    time_of_day: f32,
    /// Pending thunder sounds (delay, volume)
    pending_thunder: [MAX_PENDING_THUNDER]PendingThunder,
    pending_thunder_count: u8,

    const Self = @This();

    const MAX_PENDING_THUNDER: usize = 4;

    /// Pending thunder sound effect
    const PendingThunder = struct {
        delay: f32,
        volume: f32,
        active: bool,
    };

    /// Weather transition speed (per second)
    const TRANSITION_SPEED: f32 = 0.2;
    /// Intensity ramp speed (per second)
    const INTENSITY_RAMP_SPEED: f32 = 0.3;
    /// Wind change speed (per second)
    const WIND_CHANGE_SPEED: f32 = 0.5;
    /// Minimum time between lightning strikes (seconds)
    const MIN_THUNDER_INTERVAL: f32 = 5.0;
    /// Maximum time between lightning strikes (seconds)
    const MAX_THUNDER_INTERVAL: f32 = 30.0;
    /// Default weather duration range (seconds)
    const MIN_WEATHER_DURATION: f32 = 120.0;
    const MAX_WEATHER_DURATION: f32 = 600.0;

    /// Initialize weather system with clear weather
    pub fn init() Self {
        var self = Self{
            .current = .clear,
            .target = .clear,
            .transition = 0,
            .duration = 300,
            .intensity = 0,
            .target_intensity = 0,
            .wind = math.Vec2.ZERO,
            .target_wind = math.Vec2.ZERO,
            .thunder_timer = 15,
            .lightning = LightningFlash.init(),
            .fog_density = 0,
            .precipitation_accumulation = 0,
            .paused = false,
            .time_of_day = 0.5,
            .pending_thunder = undefined,
            .pending_thunder_count = 0,
        };

        for (&self.pending_thunder) |*pt| {
            pt.* = .{ .delay = 0, .volume = 0, .active = false };
        }

        return self;
    }

    /// Update weather simulation
    pub fn update(self: *Self, dt: f32, rng: *std.Random) void {
        if (self.paused) return;

        // Update weather duration
        self.duration -= dt;
        if (self.duration <= 0) {
            self.selectNextWeather(rng);
        }

        // Handle weather transitions
        if (self.current != self.target) {
            self.transition += TRANSITION_SPEED * dt;
            if (self.transition >= 1.0) {
                self.current = self.target;
                self.transition = 0;
            }
        }

        // Ramp intensity
        if (self.intensity < self.target_intensity) {
            self.intensity = @min(self.intensity + INTENSITY_RAMP_SPEED * dt, self.target_intensity);
        } else if (self.intensity > self.target_intensity) {
            self.intensity = @max(self.intensity - INTENSITY_RAMP_SPEED * dt, self.target_intensity);
        }

        // Update wind
        self.wind = math.Vec2.lerp(self.wind, self.target_wind, WIND_CHANGE_SPEED * dt);

        // Occasionally change wind direction
        if (rng.float(f32) < 0.01 * dt) {
            self.randomizeWind(rng);
        }

        // Update lightning
        self.lightning.update(dt);

        // Update pending thunder
        for (&self.pending_thunder) |*pt| {
            if (pt.active) {
                pt.delay -= dt;
                if (pt.delay <= 0) {
                    pt.active = false;
                    // Thunder sound would be triggered here
                }
            }
        }

        // Storm lightning logic
        if (self.getEffectiveWeather() == .storm and self.intensity > 0.3) {
            self.thunder_timer -= dt;
            if (self.thunder_timer <= 0) {
                self.triggerLightning(rng, math.Vec3.ZERO); // Player pos would be passed in
                self.thunder_timer = MIN_THUNDER_INTERVAL +
                    rng.float(f32) * (MAX_THUNDER_INTERVAL - MIN_THUNDER_INTERVAL);
            }
        }

        // Update fog density based on weather and time
        self.updateFogDensity(dt);

        // Accumulate precipitation
        if (self.getEffectiveWeather().hasPrecipitation()) {
            self.precipitation_accumulation += self.intensity * dt;
        } else {
            // Slowly reduce accumulation (evaporation/melting)
            self.precipitation_accumulation = @max(0, self.precipitation_accumulation - 0.01 * dt);
        }
    }

    /// Select next weather type
    fn selectNextWeather(self: *Self, rng: *std.Random) void {
        const weather_weights = [_]f32{
            0.35, // clear
            0.25, // cloudy
            0.20, // rain
            0.08, // storm
            0.07, // snow
            0.05, // fog
        };

        var total: f32 = 0;
        for (weather_weights) |w| total += w;

        var roll = rng.float(f32) * total;
        var selected: WeatherType = .clear;

        for (weather_weights, 0..) |weight, i| {
            roll -= weight;
            if (roll <= 0) {
                selected = @enumFromInt(i);
                break;
            }
        }

        self.setWeather(selected);
        self.duration = MIN_WEATHER_DURATION +
            rng.float(f32) * (MAX_WEATHER_DURATION - MIN_WEATHER_DURATION);
    }

    /// Manually set weather type (with transition)
    pub fn setWeather(self: *Self, weather_type: WeatherType) void {
        if (self.current == weather_type and self.target == weather_type) return;

        self.target = weather_type;
        self.transition = 0;

        // Set target intensity based on weather
        self.target_intensity = switch (weather_type) {
            .clear => 0,
            .cloudy => 0.3,
            .rain => 0.7,
            .storm => 1.0,
            .snow => 0.6,
            .fog => 0.8,
        };
    }

    /// Force immediate weather change (no transition)
    pub fn forceWeather(self: *Self, weather_type: WeatherType) void {
        self.current = weather_type;
        self.target = weather_type;
        self.transition = 0;
        self.intensity = self.target_intensity;
    }

    /// Get the effective current weather (accounting for transitions)
    pub fn getEffectiveWeather(self: *const Self) WeatherType {
        if (self.transition < 0.5) {
            return self.current;
        }
        return self.target;
    }

    /// Get blended intensity for transitions
    pub fn getBlendedIntensity(self: *const Self) f32 {
        return self.intensity * (1.0 - self.transition * 0.3);
    }

    /// Get visibility distance (blocks)
    pub fn getVisibility(self: *const Self) f32 {
        const base_visibility: f32 = 256.0; // Clear day visibility

        const weather = self.getEffectiveWeather();
        const intensity = self.getBlendedIntensity();

        const visibility_mult: f32 = switch (weather) {
            .clear => 1.0,
            .cloudy => 0.95,
            .rain => 0.6 - intensity * 0.2,
            .storm => 0.4 - intensity * 0.15,
            .snow => 0.5 - intensity * 0.25,
            .fog => 0.15 - intensity * 0.1,
        };

        return base_visibility * @max(visibility_mult, 0.05);
    }

    /// Get sky darkening factor (0 = normal, 1 = very dark)
    pub fn getSkyDarkening(self: *const Self) f32 {
        const weather = self.getEffectiveWeather();
        const intensity = self.getBlendedIntensity();

        const base_darkening: f32 = switch (weather) {
            .clear => 0,
            .cloudy => 0.2,
            .rain => 0.4,
            .storm => 0.7,
            .snow => 0.25,
            .fog => 0.35,
        };

        return base_darkening * intensity;
    }

    /// Get cloud density (0-1)
    pub fn getCloudDensity(self: *const Self) f32 {
        const weather = self.getEffectiveWeather();
        const intensity = self.getBlendedIntensity();

        const base_density: f32 = switch (weather) {
            .clear => 0.1,
            .cloudy => 0.6,
            .rain => 0.8,
            .storm => 1.0,
            .snow => 0.7,
            .fog => 0.5,
        };

        // Blend between current and target during transitions
        if (self.transition > 0 and self.current != self.target) {
            const current_density: f32 = switch (self.current) {
                .clear => 0.1,
                .cloudy => 0.6,
                .rain => 0.8,
                .storm => 1.0,
                .snow => 0.7,
                .fog => 0.5,
            };
            return math.lerp(current_density, base_density, self.transition) * intensity;
        }

        return base_density * @max(intensity, 0.1);
    }

    /// Get sun intensity multiplier (reduced during bad weather)
    pub fn getSunIntensity(self: *const Self) f32 {
        return 1.0 - self.getSkyDarkening() * 0.8;
    }

    /// Get ambient light tint for current weather
    pub fn getAmbientTint(self: *const Self) Color {
        const weather = self.getEffectiveWeather();
        const intensity = self.getBlendedIntensity();

        const tint = switch (weather) {
            .clear => Color.fromRgba(255, 255, 255, 255),
            .cloudy => Color.fromRgba(220, 220, 230, 255),
            .rain => Color.fromRgba(180, 190, 210, 255),
            .storm => Color.fromRgba(140, 150, 180, 255),
            .snow => Color.fromRgba(230, 235, 250, 255),
            .fog => Color.fromRgba(200, 200, 210, 255),
        };

        // Blend with white based on intensity
        return Color.lerp(Color.WHITE, tint, intensity);
    }

    /// Get fog color based on time of day and weather
    pub fn getFogColor(self: *const Self) Color {
        const time = self.time_of_day;

        // Base fog color varies by time of day
        const base_color = if (time < 0.25 or time > 0.75)
            Color.fromRgb(30, 35, 50) // Night fog
        else if (time < 0.35)
            Color.fromRgb(180, 140, 120) // Dawn fog
        else if (time > 0.65)
            Color.fromRgb(200, 150, 100) // Dusk fog
        else
            Color.fromRgb(180, 190, 200); // Day fog

        // Weather affects fog color
        const weather = self.getEffectiveWeather();
        const weather_tint = switch (weather) {
            .clear, .cloudy => Color.fromRgb(200, 210, 220),
            .rain => Color.fromRgb(150, 160, 180),
            .storm => Color.fromRgb(100, 110, 130),
            .snow => Color.fromRgb(220, 225, 240),
            .fog => Color.fromRgb(180, 185, 195),
        };

        return Color.lerp(base_color, weather_tint, 0.5);
    }

    /// Get current fog density
    pub fn getFogDensity(self: *const Self) f32 {
        return self.fog_density;
    }

    /// Update fog density based on conditions
    fn updateFogDensity(self: *Self, dt: f32) void {
        const weather = self.getEffectiveWeather();
        const intensity = self.getBlendedIntensity();

        var target_fog: f32 = switch (weather) {
            .clear => 0.02,
            .cloudy => 0.05,
            .rain => 0.15,
            .storm => 0.25,
            .snow => 0.2,
            .fog => 0.7,
        };

        // Morning mist (around dawn)
        if (self.time_of_day > 0.2 and self.time_of_day < 0.35) {
            target_fog = @max(target_fog, 0.3);
        }

        target_fog *= intensity;

        // Smooth transition
        const fog_speed: f32 = 0.1;
        if (self.fog_density < target_fog) {
            self.fog_density = @min(self.fog_density + fog_speed * dt, target_fog);
        } else {
            self.fog_density = @max(self.fog_density - fog_speed * dt, target_fog);
        }
    }

    /// Randomize wind direction and speed
    fn randomizeWind(self: *Self, rng: *std.Random) void {
        const weather = self.getEffectiveWeather();

        const max_wind: f32 = switch (weather) {
            .clear => 1.0,
            .cloudy => 2.0,
            .rain => 4.0,
            .storm => 8.0,
            .snow => 2.5,
            .fog => 0.5,
        };

        const angle = rng.float(f32) * std.math.tau;
        const speed = rng.float(f32) * max_wind * self.intensity;

        self.target_wind = math.Vec2.init(
            @cos(angle) * speed,
            @sin(angle) * speed,
        );
    }

    /// Trigger a lightning strike
    fn triggerLightning(self: *Self, rng: *std.Random, player_pos: math.Vec3) void {
        // Random position near player
        const offset_x = (rng.float(f32) - 0.5) * 200;
        const offset_z = (rng.float(f32) - 0.5) * 200;
        const strike_pos = math.Vec3.init(
            player_pos.x() + offset_x,
            128, // Sky height
            player_pos.z() + offset_z,
        );

        self.lightning.trigger(strike_pos, player_pos);

        // Queue thunder sound
        self.queueThunder(self.lightning.getThunderDelay(), 1.0 - self.lightning.distance / 200.0);
    }

    /// Trigger lightning at specific position
    pub fn triggerLightningAt(self: *Self, pos: math.Vec3, player_pos: math.Vec3) void {
        self.lightning.trigger(pos, player_pos);
        self.queueThunder(self.lightning.getThunderDelay(), 1.0 - self.lightning.distance / 200.0);
    }

    /// Queue a thunder sound effect
    fn queueThunder(self: *Self, delay: f32, volume: f32) void {
        for (&self.pending_thunder) |*pt| {
            if (!pt.active) {
                pt.delay = delay;
                pt.volume = std.math.clamp(volume, 0.1, 1.0);
                pt.active = true;
                self.pending_thunder_count += 1;
                break;
            }
        }
    }

    /// Check if thunder sound should play this frame
    pub fn shouldPlayThunder(self: *Self) ?f32 {
        for (&self.pending_thunder) |*pt| {
            if (pt.active and pt.delay <= 0) {
                pt.active = false;
                if (self.pending_thunder_count > 0) {
                    self.pending_thunder_count -= 1;
                }
                return pt.volume;
            }
        }
        return null;
    }

    /// Get lightning flash intensity (for screen brightening)
    pub fn getLightningIntensity(self: *const Self) f32 {
        return self.lightning.intensity;
    }

    /// Get precipitation configuration for current weather
    pub fn getPrecipitationConfig(self: *const Self) ?PrecipitationConfig {
        const weather = self.getEffectiveWeather();

        var config: ?PrecipitationConfig = switch (weather) {
            .rain => PrecipitationConfig.RAIN,
            .storm => PrecipitationConfig.STORM_RAIN,
            .snow => PrecipitationConfig.SNOW,
            else => null,
        };

        if (config) |*c| {
            // Apply wind to precipitation direction
            c.velocity = math.Vec3.init(
                c.velocity.x() + self.wind.x() * 0.5,
                c.velocity.y(),
                c.velocity.z() + self.wind.y() * 0.5,
            );
            // Scale emit rate by intensity
            c.emit_rate *= self.intensity;
        }

        return config;
    }

    /// Get precipitation type for particle spawning
    pub fn getPrecipitationType(self: *const Self) ?particles.ParticlePreset {
        return switch (self.getEffectiveWeather()) {
            .rain, .storm => .rain,
            .snow => .snow,
            else => null,
        };
    }

    /// Get splash configuration for rain hitting surfaces
    pub fn getSplashConfig(self: *const Self) ?particles.PresetConfig {
        if (self.getEffectiveWeather() == .rain or self.getEffectiveWeather() == .storm) {
            return particles.ParticlePreset.water_splash.getConfig();
        }
        return null;
    }

    /// Set time of day (affects fog and weather behavior)
    pub fn setTimeOfDay(self: *Self, time: f32) void {
        self.time_of_day = std.math.clamp(time, 0, 1);
    }

    /// Pause/resume weather updates
    pub fn setPaused(self: *Self, paused: bool) void {
        self.paused = paused;
    }

    /// Check if puddles should be visible (rain accumulation)
    pub fn shouldShowPuddles(self: *const Self) bool {
        return self.precipitation_accumulation > 30.0 and
            (self.getEffectiveWeather() == .rain or self.getEffectiveWeather() == .storm);
    }

    /// Get puddle intensity (0-1)
    pub fn getPuddleIntensity(self: *const Self) f32 {
        if (!self.shouldShowPuddles()) return 0;
        return std.math.clamp(self.precipitation_accumulation / 120.0, 0, 1);
    }

    /// Check if snow should accumulate visually
    pub fn shouldShowSnowAccumulation(self: *const Self) bool {
        return self.precipitation_accumulation > 60.0 and
            self.getEffectiveWeather() == .snow;
    }

    /// Get snow accumulation level (0-1)
    pub fn getSnowAccumulation(self: *const Self) f32 {
        if (!self.shouldShowSnowAccumulation()) return 0;
        return std.math.clamp(self.precipitation_accumulation / 300.0, 0, 1);
    }
};

/// Biome-specific weather behavior
pub const BiomeWeather = struct {
    /// Get weather probability weights for a biome
    pub fn getWeatherWeights(biome_type: biome.BiomeType) [6]f32 {
        // Weights for: clear, cloudy, rain, storm, snow, fog
        return switch (biome_type) {
            .plains => .{ 0.40, 0.25, 0.20, 0.08, 0.02, 0.05 },
            .forest => .{ 0.30, 0.30, 0.25, 0.08, 0.02, 0.05 },
            .desert => .{ 0.80, 0.15, 0.02, 0.01, 0.00, 0.02 }, // Very rare rain
            .mountains => .{ 0.30, 0.30, 0.15, 0.10, 0.10, 0.05 },
            .ocean => .{ 0.25, 0.25, 0.25, 0.15, 0.02, 0.08 }, // More storms
            .beach => .{ 0.45, 0.25, 0.15, 0.08, 0.00, 0.07 },
            .snow => .{ 0.20, 0.20, 0.00, 0.00, 0.55, 0.05 }, // Always snow, never rain
            .swamp => .{ 0.15, 0.25, 0.30, 0.10, 0.00, 0.20 }, // Very foggy
            .taiga => .{ 0.25, 0.25, 0.10, 0.05, 0.30, 0.05 },
            .savanna => .{ 0.55, 0.25, 0.12, 0.05, 0.00, 0.03 },
        };
    }

    /// Check if biome converts rain to snow
    pub fn convertsRainToSnow(biome_type: biome.BiomeType) bool {
        return switch (biome_type) {
            .snow, .taiga => true,
            .mountains => true, // At high altitudes
            else => false,
        };
    }

    /// Get fog intensity modifier for biome
    pub fn getFogModifier(biome_type: biome.BiomeType) f32 {
        return switch (biome_type) {
            .swamp => 1.5, // Extra foggy
            .ocean => 1.2,
            .mountains => 0.8, // Less fog at altitude
            .desert => 0.3, // Very clear
            else => 1.0,
        };
    }

    /// Check if biome has morning mist
    pub fn hasMorningMist(biome_type: biome.BiomeType) bool {
        return switch (biome_type) {
            .swamp, .forest, .taiga, .ocean => true,
            else => false,
        };
    }

    /// Select weather for biome
    pub fn selectWeatherForBiome(biome_type: biome.BiomeType, rng: *std.Random) WeatherType {
        const weights = getWeatherWeights(biome_type);

        var total: f32 = 0;
        for (weights) |w| total += w;

        var roll = rng.float(f32) * total;

        for (weights, 0..) |weight, i| {
            roll -= weight;
            if (roll <= 0) {
                return @enumFromInt(i);
            }
        }

        return .clear;
    }

    /// Adjust weather for biome (e.g., rain becomes snow)
    pub fn adjustWeatherForBiome(weather: WeatherType, biome_type: biome.BiomeType) WeatherType {
        // Convert rain/storm to snow in cold biomes
        if (convertsRainToSnow(biome_type)) {
            return switch (weather) {
                .rain => .snow,
                .storm => .snow, // Heavy snow instead of thunderstorm
                else => weather,
            };
        }

        return weather;
    }
};

/// Weather audio state for sound integration
pub const WeatherAudio = struct {
    /// Current rain volume (0-1)
    rain_volume: f32,
    /// Target rain volume for smoothing
    target_rain_volume: f32,
    /// Current wind volume (0-1)
    wind_volume: f32,
    /// Target wind volume
    target_wind_volume: f32,
    /// Thunder sound pending
    thunder_pending: bool,
    /// Thunder volume when triggered
    thunder_volume: f32,

    pub fn init() WeatherAudio {
        return .{
            .rain_volume = 0,
            .target_rain_volume = 0,
            .wind_volume = 0,
            .target_wind_volume = 0,
            .thunder_pending = false,
            .thunder_volume = 0,
        };
    }

    /// Update audio state from weather
    pub fn updateFromWeather(self: *WeatherAudio, weather: *Weather, dt: f32) void {
        const effective_weather = weather.getEffectiveWeather();
        const intensity = weather.getBlendedIntensity();

        // Rain volume
        self.target_rain_volume = switch (effective_weather) {
            .rain => 0.5 * intensity,
            .storm => 0.8 * intensity,
            else => 0,
        };

        // Wind volume (based on wind speed)
        const wind_speed = math.Vec2.length(weather.wind);
        self.target_wind_volume = std.math.clamp(wind_speed / 8.0, 0, 1) * intensity;

        // Smooth transitions
        const audio_smooth: f32 = 2.0;
        self.rain_volume = math.lerp(self.rain_volume, self.target_rain_volume, audio_smooth * dt);
        self.wind_volume = math.lerp(self.wind_volume, self.target_wind_volume, audio_smooth * dt);

        // Check for thunder
        if (weather.shouldPlayThunder()) |volume| {
            self.thunder_pending = true;
            self.thunder_volume = volume;
        }
    }

    /// Consume thunder trigger (call after playing sound)
    pub fn consumeThunder(self: *WeatherAudio) ?f32 {
        if (self.thunder_pending) {
            self.thunder_pending = false;
            return self.thunder_volume;
        }
        return null;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "weather init" {
    const weather = Weather.init();
    try std.testing.expectEqual(WeatherType.clear, weather.current);
    try std.testing.expectEqual(WeatherType.clear, weather.target);
    try std.testing.expect(!weather.paused);
}

test "weather transitions" {
    var weather = Weather.init();
    weather.setWeather(.rain);

    try std.testing.expectEqual(WeatherType.clear, weather.current);
    try std.testing.expectEqual(WeatherType.rain, weather.target);

    // Simulate time passing
    var rng = std.Random.DefaultPrng.init(12345);
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        weather.update(0.1, &rng.random());
    }

    try std.testing.expectEqual(WeatherType.rain, weather.current);
}

test "weather visibility" {
    var weather = Weather.init();

    // Clear weather should have maximum visibility
    const clear_vis = weather.getVisibility();
    try std.testing.expect(clear_vis > 200);

    // Fog should reduce visibility significantly
    weather.forceWeather(.fog);
    weather.intensity = 1.0;
    const fog_vis = weather.getVisibility();
    try std.testing.expect(fog_vis < 50);
}

test "weather sky darkening" {
    var weather = Weather.init();

    // Clear sky should not darken
    try std.testing.expectApproxEqAbs(@as(f32, 0), weather.getSkyDarkening(), 0.01);

    // Storm should darken significantly
    weather.forceWeather(.storm);
    weather.intensity = 1.0;
    try std.testing.expect(weather.getSkyDarkening() > 0.5);
}

test "biome weather adjustment" {
    // Rain in snow biome should become snow
    const adjusted = BiomeWeather.adjustWeatherForBiome(.rain, .snow);
    try std.testing.expectEqual(WeatherType.snow, adjusted);

    // Rain in plains stays rain
    const plains_rain = BiomeWeather.adjustWeatherForBiome(.rain, .plains);
    try std.testing.expectEqual(WeatherType.rain, plains_rain);
}

test "precipitation config" {
    var weather = Weather.init();

    // Clear weather has no precipitation
    try std.testing.expect(weather.getPrecipitationConfig() == null);

    // Rain weather has precipitation
    weather.forceWeather(.rain);
    weather.intensity = 1.0;
    const config = weather.getPrecipitationConfig();
    try std.testing.expect(config != null);
}

test "lightning flash" {
    var flash = LightningFlash.init();
    try std.testing.expect(!flash.active);

    flash.trigger(math.Vec3.init(100, 128, 100), math.Vec3.ZERO);
    try std.testing.expect(flash.active);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), flash.intensity, 0.01);

    // After update, intensity should decrease
    flash.update(0.05);
    try std.testing.expect(flash.intensity < 1.0);
    try std.testing.expect(flash.active);

    // After full duration, should be inactive
    flash.update(0.2);
    try std.testing.expect(!flash.active);
}

test "fog density" {
    var weather = Weather.init();
    weather.setTimeOfDay(0.3); // Morning

    var rng = std.Random.DefaultPrng.init(42);

    // Simulate fog weather
    weather.forceWeather(.fog);
    weather.intensity = 1.0;

    var i: usize = 0;
    while (i < 50) : (i += 1) {
        weather.update(0.1, &rng.random());
    }

    try std.testing.expect(weather.getFogDensity() > 0.3);
}

test "weather audio state" {
    var weather = Weather.init();
    var audio = WeatherAudio.init();

    weather.forceWeather(.rain);
    weather.intensity = 1.0;

    audio.updateFromWeather(&weather, 1.0);

    try std.testing.expect(audio.rain_volume > 0);
}
