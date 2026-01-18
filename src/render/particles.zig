//! Particle System
//!
//! Provides a flexible particle system for visual effects like block breaking,
//! dust, smoke, fire, water, and ambient particles.

const std = @import("std");
const math = @import("../math/math.zig");
const Color = @import("color.zig").Color;

/// Maximum number of particles in the system
pub const MAX_PARTICLES: u32 = 4096;

/// Maximum number of emitters
pub const MAX_EMITTERS: u32 = 64;

/// Individual particle state
pub const Particle = struct {
    position: math.Vec3,
    velocity: math.Vec3,
    color: Color,
    life: f32, // Remaining lifetime in seconds
    max_life: f32, // Initial lifetime (for fade calculations)
    size: f32, // Render size in pixels
    gravity: f32, // Gravity multiplier (0 = no gravity, 1 = normal, negative = rise)
    fade: bool, // Whether to fade alpha over lifetime
    additive: bool, // Use additive blending (for fire/sparkles)

    /// Check if particle is still alive
    pub fn isAlive(self: *const Particle) bool {
        return self.life > 0;
    }

    /// Get current alpha based on remaining life
    pub fn getCurrentAlpha(self: *const Particle) u8 {
        if (!self.fade or self.max_life <= 0) return self.color.a;
        const t = self.life / self.max_life;
        return @intFromFloat(@as(f32, @floatFromInt(self.color.a)) * t);
    }

    /// Get current color with faded alpha
    pub fn getCurrentColor(self: *const Particle) Color {
        return Color.fromRgba(
            self.color.r,
            self.color.g,
            self.color.b,
            self.getCurrentAlpha(),
        );
    }

    /// Update particle physics
    pub fn update(self: *Particle, dt: f32) void {
        if (!self.isAlive()) return;

        // Apply gravity
        const gravity_force = math.Vec3.init(0, -9.81 * self.gravity, 0);
        self.velocity = self.velocity.add(gravity_force.scale(dt));

        // Update position
        self.position = self.position.add(self.velocity.scale(dt));

        // Decrease lifetime
        self.life -= dt;
    }
};

/// Particle emitter configuration
pub const ParticleEmitter = struct {
    position: math.Vec3,
    emit_rate: f32, // Particles per second
    particle_lifetime: f32,
    lifetime_variance: f32, // +/- variance
    initial_velocity: math.Vec3,
    velocity_variance: f32, // Random spread factor
    color: Color,
    color_variance: Color, // RGB variance (alpha used for fade setting)
    size: f32,
    size_variance: f32,
    gravity: f32,
    fade: bool,
    additive: bool,
    active: bool,

    // Internal state
    emit_accumulator: f32, // Accumulated time for emission

    pub fn init() ParticleEmitter {
        return .{
            .position = math.Vec3.ZERO,
            .emit_rate = 10.0,
            .particle_lifetime = 1.0,
            .lifetime_variance = 0.2,
            .initial_velocity = math.Vec3.ZERO,
            .velocity_variance = 0.5,
            .color = Color.WHITE,
            .color_variance = Color.fromRgba(0, 0, 0, 0),
            .size = 2.0,
            .size_variance = 0.5,
            .gravity = 1.0,
            .fade = true,
            .additive = false,
            .active = false,
            .emit_accumulator = 0,
        };
    }

    /// Calculate how many particles to emit this frame
    pub fn getEmitCount(self: *ParticleEmitter, dt: f32) u32 {
        if (!self.active or self.emit_rate <= 0) return 0;

        self.emit_accumulator += dt * self.emit_rate;
        const count: u32 = @intFromFloat(self.emit_accumulator);
        self.emit_accumulator -= @floatFromInt(count);
        return count;
    }
};

/// Particle effect presets
pub const ParticlePreset = enum {
    block_break,
    block_place,
    dust,
    smoke,
    fire,
    water_splash,
    water_drip,
    snow,
    rain,
    sparkle,
    leaves,

    /// Get preset configuration
    pub fn getConfig(self: ParticlePreset) PresetConfig {
        return switch (self) {
            .block_break => .{
                .lifetime = 0.8,
                .lifetime_variance = 0.2,
                .velocity = math.Vec3.init(0, 2, 0),
                .velocity_variance = 3.0,
                .color = Color.WHITE, // Will be overridden by block color
                .color_variance = Color.fromRgba(30, 30, 30, 0),
                .size = 3.0,
                .size_variance = 1.0,
                .gravity = 1.5,
                .fade = true,
                .additive = false,
            },
            .block_place => .{
                .lifetime = 0.4,
                .lifetime_variance = 0.1,
                .velocity = math.Vec3.init(0, 0.5, 0),
                .velocity_variance = 1.5,
                .color = Color.fromRgba(200, 180, 150, 180),
                .color_variance = Color.fromRgba(20, 20, 20, 0),
                .size = 2.0,
                .size_variance = 0.5,
                .gravity = 0.5,
                .fade = true,
                .additive = false,
            },
            .dust => .{
                .lifetime = 3.0,
                .lifetime_variance = 1.0,
                .velocity = math.Vec3.init(0, 0.3, 0),
                .velocity_variance = 0.5,
                .color = Color.fromRgba(180, 160, 140, 80),
                .color_variance = Color.fromRgba(20, 20, 20, 0),
                .size = 1.5,
                .size_variance = 0.5,
                .gravity = -0.05, // Float upward slightly
                .fade = true,
                .additive = false,
            },
            .smoke => .{
                .lifetime = 2.5,
                .lifetime_variance = 0.5,
                .velocity = math.Vec3.init(0, 1.5, 0),
                .velocity_variance = 0.8,
                .color = Color.fromRgba(100, 100, 100, 150),
                .color_variance = Color.fromRgba(30, 30, 30, 0),
                .size = 4.0,
                .size_variance = 1.5,
                .gravity = -0.3, // Rise
                .fade = true,
                .additive = false,
            },
            .fire => .{
                .lifetime = 0.8,
                .lifetime_variance = 0.3,
                .velocity = math.Vec3.init(0, 2.5, 0),
                .velocity_variance = 1.0,
                .color = Color.fromRgba(255, 150, 50, 200),
                .color_variance = Color.fromRgba(0, 50, 30, 0),
                .size = 3.0,
                .size_variance = 1.0,
                .gravity = -0.5, // Rise
                .fade = true,
                .additive = true,
            },
            .water_splash => .{
                .lifetime = 0.6,
                .lifetime_variance = 0.2,
                .velocity = math.Vec3.init(0, 4, 0),
                .velocity_variance = 2.5,
                .color = Color.fromRgba(100, 150, 255, 180),
                .color_variance = Color.fromRgba(20, 20, 30, 0),
                .size = 2.5,
                .size_variance = 0.8,
                .gravity = 2.0, // Fall quickly
                .fade = true,
                .additive = false,
            },
            .water_drip => .{
                .lifetime = 1.5,
                .lifetime_variance = 0.3,
                .velocity = math.Vec3.init(0, -1, 0),
                .velocity_variance = 0.2,
                .color = Color.fromRgba(80, 140, 255, 200),
                .color_variance = Color.fromRgba(10, 20, 20, 0),
                .size = 2.0,
                .size_variance = 0.3,
                .gravity = 1.0,
                .fade = false,
                .additive = false,
            },
            .snow => .{
                .lifetime = 8.0,
                .lifetime_variance = 2.0,
                .velocity = math.Vec3.init(0, -1.0, 0),
                .velocity_variance = 0.5,
                .color = Color.fromRgba(255, 255, 255, 220),
                .color_variance = Color.fromRgba(0, 0, 0, 0),
                .size = 2.0,
                .size_variance = 0.5,
                .gravity = 0.1, // Slow fall
                .fade = false,
                .additive = false,
            },
            .rain => .{
                .lifetime = 1.0,
                .lifetime_variance = 0.2,
                .velocity = math.Vec3.init(0, -15, 0),
                .velocity_variance = 1.0,
                .color = Color.fromRgba(150, 180, 255, 150),
                .color_variance = Color.fromRgba(10, 10, 20, 0),
                .size = 1.5,
                .size_variance = 0.3,
                .gravity = 0.5,
                .fade = false,
                .additive = false,
            },
            .sparkle => .{
                .lifetime = 0.5,
                .lifetime_variance = 0.2,
                .velocity = math.Vec3.init(0, 0.5, 0),
                .velocity_variance = 1.5,
                .color = Color.fromRgba(255, 255, 200, 255),
                .color_variance = Color.fromRgba(0, 0, 50, 0),
                .size = 2.0,
                .size_variance = 1.0,
                .gravity = 0,
                .fade = true,
                .additive = true,
            },
            .leaves => .{
                .lifetime = 6.0,
                .lifetime_variance = 2.0,
                .velocity = math.Vec3.init(0.5, -0.5, 0),
                .velocity_variance = 1.0,
                .color = Color.fromRgba(50, 150, 50, 200),
                .color_variance = Color.fromRgba(30, 50, 20, 0),
                .size = 3.0,
                .size_variance = 1.0,
                .gravity = 0.15,
                .fade = true,
                .additive = false,
            },
        };
    }
};

/// Configuration for a particle preset
pub const PresetConfig = struct {
    lifetime: f32,
    lifetime_variance: f32,
    velocity: math.Vec3,
    velocity_variance: f32,
    color: Color,
    color_variance: Color,
    size: f32,
    size_variance: f32,
    gravity: f32,
    fade: bool,
    additive: bool,
};

/// Main particle system
pub const ParticleSystem = struct {
    particles: [MAX_PARTICLES]Particle,
    active_count: u32,
    emitters: [MAX_EMITTERS]ParticleEmitter,
    emitter_count: u32,
    rng: std.Random.DefaultPrng,

    const Self = @This();

    /// Initialize the particle system
    pub fn init() ParticleSystem {
        var system = ParticleSystem{
            .particles = undefined,
            .active_count = 0,
            .emitters = undefined,
            .emitter_count = 0,
            .rng = std.Random.DefaultPrng.init(0),
        };

        // Initialize all particles as dead
        for (&system.particles) |*p| {
            p.life = 0;
        }

        // Initialize emitters as inactive
        for (&system.emitters) |*e| {
            e.* = ParticleEmitter.init();
        }

        return system;
    }

    /// Initialize with a specific random seed
    pub fn initWithSeed(seed: u64) ParticleSystem {
        var system = init();
        system.rng = std.Random.DefaultPrng.init(seed);
        return system;
    }

    /// Update all particles and emitters
    pub fn update(self: *Self, dt: f32) void {
        // Update existing particles
        var alive_count: u32 = 0;
        for (&self.particles) |*p| {
            if (p.isAlive()) {
                p.update(dt);
                if (p.isAlive()) {
                    alive_count += 1;
                }
            }
        }
        self.active_count = alive_count;

        // Process emitters
        for (&self.emitters) |*emitter| {
            if (!emitter.active) continue;

            const emit_count = emitter.getEmitCount(dt);
            var i: u32 = 0;
            while (i < emit_count) : (i += 1) {
                _ = self.spawnParticleFromEmitter(emitter);
            }
        }
    }

    /// Spawn a single particle from an emitter
    fn spawnParticleFromEmitter(self: *Self, emitter: *const ParticleEmitter) bool {
        const slot = self.findFreeSlot() orelse return false;

        // Calculate random variations
        const vel_spread = math.Vec3.init(
            (self.rng.random().float(f32) - 0.5) * 2.0 * emitter.velocity_variance,
            (self.rng.random().float(f32) - 0.5) * 2.0 * emitter.velocity_variance,
            (self.rng.random().float(f32) - 0.5) * 2.0 * emitter.velocity_variance,
        );

        const lifetime = emitter.particle_lifetime +
            (self.rng.random().float(f32) - 0.5) * 2.0 * emitter.lifetime_variance;

        const size = emitter.size +
            (self.rng.random().float(f32) - 0.5) * 2.0 * emitter.size_variance;

        // Color variance
        const color = self.varyColor(emitter.color, emitter.color_variance);

        self.particles[slot] = .{
            .position = emitter.position,
            .velocity = emitter.initial_velocity.add(vel_spread),
            .color = color,
            .life = @max(0.1, lifetime),
            .max_life = @max(0.1, lifetime),
            .size = @max(0.5, size),
            .gravity = emitter.gravity,
            .fade = emitter.fade,
            .additive = emitter.additive,
        };

        self.active_count += 1;
        return true;
    }

    /// Spawn particles at a position using a preset
    pub fn spawnParticles(self: *Self, position: math.Vec3, preset: ParticlePreset, count: u32) void {
        self.spawnParticlesWithColor(position, preset, count, null);
    }

    /// Spawn particles with a custom base color
    pub fn spawnParticlesWithColor(
        self: *Self,
        position: math.Vec3,
        preset: ParticlePreset,
        count: u32,
        base_color: ?Color,
    ) void {
        const config = preset.getConfig();

        var i: u32 = 0;
        while (i < count) : (i += 1) {
            const slot = self.findFreeSlot() orelse break;

            // Calculate random variations
            const vel_spread = math.Vec3.init(
                (self.rng.random().float(f32) - 0.5) * 2.0 * config.velocity_variance,
                (self.rng.random().float(f32) - 0.5) * 2.0 * config.velocity_variance,
                (self.rng.random().float(f32) - 0.5) * 2.0 * config.velocity_variance,
            );

            const lifetime = config.lifetime +
                (self.rng.random().float(f32) - 0.5) * 2.0 * config.lifetime_variance;

            const size = config.size +
                (self.rng.random().float(f32) - 0.5) * 2.0 * config.size_variance;

            // Use custom color or preset color
            const color = self.varyColor(
                base_color orelse config.color,
                config.color_variance,
            );

            self.particles[slot] = .{
                .position = position,
                .velocity = config.velocity.add(vel_spread),
                .color = color,
                .life = @max(0.1, lifetime),
                .max_life = @max(0.1, lifetime),
                .size = @max(0.5, size),
                .gravity = config.gravity,
                .fade = config.fade,
                .additive = config.additive,
            };

            self.active_count += 1;
        }
    }

    /// Spawn a single particle with full control
    pub fn spawnParticle(
        self: *Self,
        position: math.Vec3,
        velocity: math.Vec3,
        color: Color,
        lifetime: f32,
        size: f32,
        gravity: f32,
        fade: bool,
        additive: bool,
    ) bool {
        const slot = self.findFreeSlot() orelse return false;

        self.particles[slot] = .{
            .position = position,
            .velocity = velocity,
            .color = color,
            .life = lifetime,
            .max_life = lifetime,
            .size = size,
            .gravity = gravity,
            .fade = fade,
            .additive = additive,
        };

        self.active_count += 1;
        return true;
    }

    /// Create an emitter and return its index
    pub fn createEmitter(self: *Self) ?u32 {
        for (&self.emitters, 0..) |*emitter, i| {
            if (!emitter.active) {
                emitter.* = ParticleEmitter.init();
                emitter.active = true;
                self.emitter_count += 1;
                return @intCast(i);
            }
        }
        return null;
    }

    /// Get an emitter by index
    pub fn getEmitter(self: *Self, index: u32) ?*ParticleEmitter {
        if (index >= MAX_EMITTERS) return null;
        if (!self.emitters[index].active) return null;
        return &self.emitters[index];
    }

    /// Remove an emitter
    pub fn removeEmitter(self: *Self, index: u32) void {
        if (index >= MAX_EMITTERS) return;
        if (self.emitters[index].active) {
            self.emitters[index].active = false;
            if (self.emitter_count > 0) {
                self.emitter_count -= 1;
            }
        }
    }

    /// Clear all particles
    pub fn clear(self: *Self) void {
        for (&self.particles) |*p| {
            p.life = 0;
        }
        self.active_count = 0;
    }

    /// Clear all emitters
    pub fn clearEmitters(self: *Self) void {
        for (&self.emitters) |*e| {
            e.active = false;
        }
        self.emitter_count = 0;
    }

    /// Find a free particle slot
    fn findFreeSlot(self: *Self) ?usize {
        for (&self.particles, 0..) |*p, i| {
            if (!p.isAlive()) {
                return i;
            }
        }
        return null;
    }

    /// Apply color variance
    fn varyColor(self: *Self, base: Color, variance: Color) Color {
        const vr = @as(i16, variance.r);
        const vg = @as(i16, variance.g);
        const vb = @as(i16, variance.b);

        const r_var = if (vr > 0) @as(i16, @intFromFloat((self.rng.random().float(f32) - 0.5) * 2.0 * @as(f32, @floatFromInt(vr)))) else 0;
        const g_var = if (vg > 0) @as(i16, @intFromFloat((self.rng.random().float(f32) - 0.5) * 2.0 * @as(f32, @floatFromInt(vg)))) else 0;
        const b_var = if (vb > 0) @as(i16, @intFromFloat((self.rng.random().float(f32) - 0.5) * 2.0 * @as(f32, @floatFromInt(vb)))) else 0;

        return Color.fromRgba(
            @intCast(std.math.clamp(@as(i16, base.r) + r_var, 0, 255)),
            @intCast(std.math.clamp(@as(i16, base.g) + g_var, 0, 255)),
            @intCast(std.math.clamp(@as(i16, base.b) + b_var, 0, 255)),
            base.a,
        );
    }

    /// Render all particles (called by the renderer)
    /// This is a simple implementation - actual rendering will be done by the Renderer
    pub fn getActiveParticles(self: *const Self) ParticleIterator {
        return ParticleIterator.init(self);
    }

    /// Get the number of active particles
    pub fn getActiveCount(self: *const Self) u32 {
        return self.active_count;
    }
};

/// Iterator for active particles (for rendering)
pub const ParticleIterator = struct {
    system: *const ParticleSystem,
    index: usize,

    pub fn init(system: *const ParticleSystem) ParticleIterator {
        return .{
            .system = system,
            .index = 0,
        };
    }

    pub fn next(self: *ParticleIterator) ?*const Particle {
        while (self.index < MAX_PARTICLES) {
            const p = &self.system.particles[self.index];
            self.index += 1;
            if (p.isAlive()) {
                return p;
            }
        }
        return null;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "particle system init" {
    const system = ParticleSystem.init();
    try std.testing.expectEqual(@as(u32, 0), system.active_count);
    try std.testing.expectEqual(@as(u32, 0), system.emitter_count);
}

test "particle spawn and update" {
    var system = ParticleSystem.initWithSeed(42);

    // Spawn some particles
    system.spawnParticles(math.Vec3.ZERO, .dust, 10);
    try std.testing.expect(system.active_count > 0);

    const initial_count = system.active_count;

    // Update with a large dt to kill some particles
    system.update(5.0);

    // Some particles should have died
    try std.testing.expect(system.active_count <= initial_count);
}

test "particle preset configs" {
    // Test that all presets have valid configurations
    inline for (@typeInfo(ParticlePreset).@"enum".fields) |field| {
        const preset: ParticlePreset = @enumFromInt(field.value);
        const config = preset.getConfig();
        try std.testing.expect(config.lifetime > 0);
        try std.testing.expect(config.size > 0);
    }
}

test "emitter creation and removal" {
    var system = ParticleSystem.init();

    // Create an emitter
    const idx = system.createEmitter();
    try std.testing.expect(idx != null);
    try std.testing.expectEqual(@as(u32, 1), system.emitter_count);

    // Get and configure emitter
    if (system.getEmitter(idx.?)) |emitter| {
        emitter.position = math.Vec3.init(1, 2, 3);
        emitter.emit_rate = 100;
        try std.testing.expect(emitter.active);
    }

    // Remove emitter
    system.removeEmitter(idx.?);
    try std.testing.expectEqual(@as(u32, 0), system.emitter_count);
}

test "particle iterator" {
    var system = ParticleSystem.initWithSeed(123);
    system.spawnParticles(math.Vec3.ZERO, .sparkle, 5);

    var count: u32 = 0;
    var iter = system.getActiveParticles();
    while (iter.next()) |_| {
        count += 1;
    }

    try std.testing.expect(count > 0);
    try std.testing.expectEqual(system.active_count, count);
}

test "particle color fading" {
    var p = Particle{
        .position = math.Vec3.ZERO,
        .velocity = math.Vec3.ZERO,
        .color = Color.fromRgba(255, 255, 255, 200),
        .life = 0.5,
        .max_life = 1.0,
        .size = 2.0,
        .gravity = 0,
        .fade = true,
        .additive = false,
    };

    // At half life, alpha should be half
    const alpha = p.getCurrentAlpha();
    try std.testing.expectApproxEqAbs(@as(f32, 100), @as(f32, @floatFromInt(alpha)), 5);
}
