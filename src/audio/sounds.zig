//! Sound Event System
//!
//! High-level game sound management with procedural sound generation,
//! 3D positional audio, and ambient soundscapes.

const std = @import("std");
const audio = @import("audio.zig");
const math = @import("../math/math.zig");
const world_module = @import("../game/world.zig");
const biome_module = @import("../world/biome.zig");

const log = std.log.scoped(.sounds);

const Block = world_module.Block;
const BiomeType = biome_module.BiomeType;
const AudioEngine = audio.Engine;
const SoundHandle = audio.SoundHandle;
const PlayOptions = audio.PlayOptions;
const Vec3 = math.Vec3;

// ============================================================================
// Sound Events
// ============================================================================

/// Game sound events
pub const SoundEvent = enum {
    // Block sounds
    block_break_stone,
    block_break_dirt,
    block_break_wood,
    block_break_sand,
    block_break_glass,
    block_break_gravel,
    block_break_snow,
    block_place,

    // Player sounds
    footstep_grass,
    footstep_stone,
    footstep_wood,
    footstep_sand,
    footstep_snow,
    footstep_gravel,
    player_jump,
    player_land,
    player_hurt,
    player_eat,
    player_swim,

    // UI sounds
    ui_click,
    ui_open,
    ui_close,
    ui_select,

    // Mob sounds
    mob_hurt,
    mob_death,
    pig_ambient,
    cow_ambient,
    chicken_ambient,
    zombie_ambient,
    skeleton_ambient,
    creeper_fuse,
    explosion,

    // Ambient
    ambient_cave,
    ambient_wind,
    ambient_birds,
    ambient_crickets,
    ambient_underwater,

    // Weather
    rain_loop,
    thunder,
    wind_gust,

    pub const COUNT = @typeInfo(SoundEvent).@"enum".fields.len;
};

/// Block material for sound selection
pub const BlockMaterial = enum {
    stone,
    dirt,
    wood,
    sand,
    glass,
    gravel,
    snow,
    metal,
    cloth,

    /// Get material from block type
    pub fn fromBlock(block: Block) BlockMaterial {
        return switch (block) {
            .stone, .cobblestone, .brick, .obsidian => .stone,
            .dirt, .grass, .clay => .dirt,
            .wood, .planks, .leaves => .wood,
            .sand => .sand,
            .glass, .ice => .glass,
            .gravel => .gravel,
            .snow => .snow,
            .gold, .iron, .coal => .metal,
            else => .stone,
        };
    }

    /// Get break sound event for material
    pub fn getBreakSound(self: BlockMaterial) SoundEvent {
        return switch (self) {
            .stone, .metal => .block_break_stone,
            .dirt, .cloth => .block_break_dirt,
            .wood => .block_break_wood,
            .sand => .block_break_sand,
            .glass => .block_break_glass,
            .gravel => .block_break_gravel,
            .snow => .block_break_snow,
        };
    }

    /// Get footstep sound event for material
    pub fn getFootstepSound(self: BlockMaterial) SoundEvent {
        return switch (self) {
            .stone, .metal => .footstep_stone,
            .dirt, .cloth => .footstep_grass,
            .wood => .footstep_wood,
            .sand => .footstep_sand,
            .glass => .footstep_stone,
            .gravel => .footstep_gravel,
            .snow => .footstep_snow,
        };
    }
};

// ============================================================================
// Procedural Sound Generation
// ============================================================================

/// Types of procedurally generated sounds
pub const SoundType = enum {
    sine, // Pure tone
    square, // Retro game sounds
    triangle, // Softer tone
    sawtooth, // Harsh/buzzy
    noise, // White noise for wind/rain
    click, // Short click
    thump, // Low impact
    crack, // Breaking sound
    pop, // Quick pop
};

/// Generate procedural sound samples
pub fn generateSound(
    allocator: std.mem.Allocator,
    sound_type: SoundType,
    frequency: f32,
    duration: f32,
    sample_rate: u32,
) ![]f32 {
    const num_samples: usize = @intFromFloat(duration * @as(f32, @floatFromInt(sample_rate)));
    const samples = try allocator.alloc(f32, num_samples * 2); // Stereo

    var prng = std.Random.DefaultPrng.init(@intFromFloat(@mod(frequency * 12345.6789, 4294967295.0)));
    const random = prng.random();

    for (0..num_samples) |i| {
        const t: f32 = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(sample_rate));
        const phase = t * frequency * std.math.tau;

        var sample: f32 = switch (sound_type) {
            .sine => @sin(phase),
            .square => if (@sin(phase) > 0) @as(f32, 1.0) else @as(f32, -1.0),
            .triangle => 2.0 * @abs(2.0 * (phase / std.math.tau - @floor(phase / std.math.tau + 0.5))) - 1.0,
            .sawtooth => 2.0 * (phase / std.math.tau - @floor(phase / std.math.tau + 0.5)),
            .noise => random.float(f32) * 2.0 - 1.0,
            .click => blk: {
                const env = @exp(-t * 100.0);
                break :blk @sin(phase * 4.0) * env;
            },
            .thump => blk: {
                const env = @exp(-t * 20.0);
                const freq_decay = frequency * @exp(-t * 10.0);
                break :blk @sin(t * freq_decay * std.math.tau) * env;
            },
            .crack => blk: {
                const env = @exp(-t * 30.0);
                const noise_val = random.float(f32) * 2.0 - 1.0;
                break :blk (noise_val * 0.7 + @sin(phase * 2.0) * 0.3) * env;
            },
            .pop => blk: {
                const env = @exp(-t * 50.0);
                break :blk @sin(phase * 2.0) * env;
            },
        };

        // Apply envelope for non-continuous sounds
        const envelope: f32 = switch (sound_type) {
            .noise => @min(1.0, @max(0.0, 1.0 - t / duration)),
            else => 1.0,
        };

        sample *= envelope * 0.8; // Slightly reduce volume to prevent clipping

        // Stereo output (same on both channels)
        samples[i * 2] = sample;
        samples[i * 2 + 1] = sample;
    }

    return samples;
}

/// Generate a sound with ADSR envelope
pub fn generateSoundADSR(
    allocator: std.mem.Allocator,
    sound_type: SoundType,
    frequency: f32,
    attack: f32,
    decay: f32,
    sustain: f32,
    release: f32,
    sample_rate: u32,
) ![]f32 {
    const duration = attack + decay + sustain + release;
    const num_samples: usize = @intFromFloat(duration * @as(f32, @floatFromInt(sample_rate)));
    const samples = try allocator.alloc(f32, num_samples * 2);

    var prng = std.Random.DefaultPrng.init(@intFromFloat(@mod(frequency * 54321.0, 4294967295.0)));
    const random = prng.random();

    for (0..num_samples) |i| {
        const t: f32 = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(sample_rate));
        const phase = t * frequency * std.math.tau;

        // Generate waveform
        var sample: f32 = switch (sound_type) {
            .sine => @sin(phase),
            .square => if (@sin(phase) > 0) @as(f32, 0.8) else @as(f32, -0.8),
            .triangle => 2.0 * @abs(2.0 * (phase / std.math.tau - @floor(phase / std.math.tau + 0.5))) - 1.0,
            .sawtooth => 2.0 * (phase / std.math.tau - @floor(phase / std.math.tau + 0.5)),
            .noise => random.float(f32) * 2.0 - 1.0,
            else => @sin(phase),
        };

        // ADSR envelope
        const envelope: f32 = if (t < attack)
            t / attack
        else if (t < attack + decay)
            1.0 - (t - attack) / decay * 0.3
        else if (t < attack + decay + sustain)
            0.7
        else
            0.7 * (1.0 - (t - attack - decay - sustain) / release);

        sample *= envelope * 0.7;

        samples[i * 2] = sample;
        samples[i * 2 + 1] = sample;
    }

    return samples;
}

// ============================================================================
// Ambient Source
// ============================================================================

/// A positioned ambient sound source
pub const AmbientSource = struct {
    position: Vec3,
    sound_event: SoundEvent,
    volume: f32,
    radius: f32, // Falloff radius
    active: bool,
    loop_timer: f32,
    loop_interval: f32,
};

/// Time of day for ambient sounds
pub const TimeOfDay = enum {
    dawn, // 5:00 - 7:00
    day, // 7:00 - 17:00
    dusk, // 17:00 - 19:00
    night, // 19:00 - 5:00

    pub fn fromHour(hour: f32) TimeOfDay {
        if (hour >= 5.0 and hour < 7.0) return .dawn;
        if (hour >= 7.0 and hour < 17.0) return .day;
        if (hour >= 17.0 and hour < 19.0) return .dusk;
        return .night;
    }
};

/// Weather state for ambient sounds
pub const WeatherState = enum {
    clear,
    cloudy,
    rain,
    storm,
    snow,
};

// ============================================================================
// Sound Manager
// ============================================================================

/// Volume settings
pub const VolumeSettings = struct {
    master: f32 = 1.0,
    music: f32 = 0.7,
    sfx: f32 = 1.0,
    ambient: f32 = 0.5,
    ui: f32 = 0.8,

    /// Apply master volume to category volume
    pub fn getEffectiveVolume(self: VolumeSettings, category: VolumeCategory) f32 {
        const cat_vol = switch (category) {
            .music => self.music,
            .sfx => self.sfx,
            .ambient => self.ambient,
            .ui => self.ui,
        };
        return self.master * cat_vol;
    }
};

pub const VolumeCategory = enum {
    music,
    sfx,
    ambient,
    ui,
};

/// Main sound manager for game audio
pub const SoundManager = struct {
    allocator: std.mem.Allocator,
    audio_engine: *AudioEngine,

    // Sound handles for each event
    sound_handles: [SoundEvent.COUNT]SoundHandle,

    // Ambient system
    ambient_sources: std.ArrayListUnmanaged(AmbientSource),
    current_biome_ambience: ?SoundHandle,
    current_weather_ambience: ?SoundHandle,

    // Listener state (player position/orientation)
    listener_position: Vec3,
    listener_forward: Vec3,

    // Time and weather for ambient sounds
    time_of_day: TimeOfDay,
    weather: WeatherState,
    world_hour: f32,

    // Volume controls
    volumes: VolumeSettings,

    // Footstep system
    footstep_timer: f32,
    footstep_interval: f32,
    last_ground_material: BlockMaterial,

    // Random for pitch variation
    prng: std.Random.DefaultPrng,

    const Self = @This();

    /// Initialize the sound manager
    pub fn init(allocator: std.mem.Allocator, audio_engine: *AudioEngine) Self {
        var handles: [SoundEvent.COUNT]SoundHandle = undefined;
        for (&handles) |*h| {
            h.* = SoundHandle.invalid;
        }

        return .{
            .allocator = allocator,
            .audio_engine = audio_engine,
            .sound_handles = handles,
            .ambient_sources = .{},
            .current_biome_ambience = null,
            .current_weather_ambience = null,
            .listener_position = Vec3.ZERO,
            .listener_forward = Vec3.Z,
            .time_of_day = .day,
            .weather = .clear,
            .world_hour = 12.0,
            .volumes = .{},
            .footstep_timer = 0,
            .footstep_interval = 0.4,
            .last_ground_material = .stone,
            .prng = std.Random.DefaultPrng.init(12345),
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        self.ambient_sources.deinit(self.allocator);
    }

    /// Generate all procedural sounds
    pub fn generateProceduralSounds(self: *Self) !void {
        log.info("Generating procedural sounds...", .{});

        // Block break sounds
        try self.generateBlockSound(.block_break_stone, 200.0, .crack, 0.15);
        try self.generateBlockSound(.block_break_dirt, 150.0, .thump, 0.12);
        try self.generateBlockSound(.block_break_wood, 300.0, .crack, 0.18);
        try self.generateBlockSound(.block_break_sand, 100.0, .noise, 0.1);
        try self.generateBlockSound(.block_break_glass, 800.0, .crack, 0.2);
        try self.generateBlockSound(.block_break_gravel, 120.0, .noise, 0.12);
        try self.generateBlockSound(.block_break_snow, 80.0, .noise, 0.08);
        try self.generateBlockSound(.block_place, 250.0, .thump, 0.1);

        // Footstep sounds
        try self.generateFootstepSound(.footstep_grass, 100.0, 0.08);
        try self.generateFootstepSound(.footstep_stone, 400.0, 0.06);
        try self.generateFootstepSound(.footstep_wood, 350.0, 0.07);
        try self.generateFootstepSound(.footstep_sand, 80.0, 0.1);
        try self.generateFootstepSound(.footstep_snow, 60.0, 0.09);
        try self.generateFootstepSound(.footstep_gravel, 200.0, 0.08);

        // Player sounds
        try self.generatePlayerSound(.player_jump, 250.0, 0.1);
        try self.generatePlayerSound(.player_land, 150.0, 0.15);
        try self.generatePlayerSound(.player_hurt, 400.0, 0.2);
        try self.generatePlayerSound(.player_eat, 300.0, 0.3);
        try self.generatePlayerSound(.player_swim, 100.0, 0.2);

        // UI sounds
        try self.generateUISound(.ui_click, 800.0, 0.05);
        try self.generateUISound(.ui_open, 600.0, 0.1);
        try self.generateUISound(.ui_close, 500.0, 0.08);
        try self.generateUISound(.ui_select, 700.0, 0.06);

        // Mob sounds
        try self.generateMobSound(.mob_hurt, 350.0, 0.15);
        try self.generateMobSound(.mob_death, 200.0, 0.3);
        try self.generateMobSound(.pig_ambient, 180.0, 0.4);
        try self.generateMobSound(.cow_ambient, 120.0, 0.5);
        try self.generateMobSound(.chicken_ambient, 500.0, 0.3);
        try self.generateMobSound(.zombie_ambient, 150.0, 0.6);
        try self.generateMobSound(.skeleton_ambient, 400.0, 0.4);
        try self.generateMobSound(.creeper_fuse, 600.0, 1.5);
        try self.generateExplosionSound();

        // Ambient sounds
        try self.generateAmbientSound(.ambient_cave, 80.0, 3.0);
        try self.generateAmbientSound(.ambient_wind, 60.0, 4.0);
        try self.generateAmbientSound(.ambient_birds, 1000.0, 2.0);
        try self.generateAmbientSound(.ambient_crickets, 2000.0, 3.0);
        try self.generateAmbientSound(.ambient_underwater, 100.0, 2.0);

        // Weather sounds
        try self.generateWeatherSound(.rain_loop, 5.0);
        try self.generateThunderSound();
        try self.generateAmbientSound(.wind_gust, 50.0, 2.0);

        log.info("Procedural sound generation complete", .{});
    }

    fn generateBlockSound(self: *Self, event: SoundEvent, freq: f32, sound_type: SoundType, duration: f32) !void {
        const samples = try generateSound(self.allocator, sound_type, freq, duration, 44100);
        defer self.allocator.free(samples);
        try self.registerSoundSamples(event, samples);
    }

    fn generateFootstepSound(self: *Self, event: SoundEvent, freq: f32, duration: f32) !void {
        const samples = try generateSound(self.allocator, .thump, freq, duration, 44100);
        defer self.allocator.free(samples);
        try self.registerSoundSamples(event, samples);
    }

    fn generatePlayerSound(self: *Self, event: SoundEvent, freq: f32, duration: f32) !void {
        const samples = try generateSoundADSR(self.allocator, .sine, freq, 0.01, 0.05, duration * 0.5, duration * 0.4, 44100);
        defer self.allocator.free(samples);
        try self.registerSoundSamples(event, samples);
    }

    fn generateUISound(self: *Self, event: SoundEvent, freq: f32, duration: f32) !void {
        const samples = try generateSoundADSR(self.allocator, .sine, freq, 0.005, 0.02, 0.0, duration, 44100);
        defer self.allocator.free(samples);
        try self.registerSoundSamples(event, samples);
    }

    fn generateMobSound(self: *Self, event: SoundEvent, freq: f32, duration: f32) !void {
        const samples = try generateSoundADSR(self.allocator, .sawtooth, freq, 0.02, 0.1, duration * 0.4, duration * 0.4, 44100);
        defer self.allocator.free(samples);
        try self.registerSoundSamples(event, samples);
    }

    fn generateExplosionSound(self: *Self) !void {
        const samples = try generateSound(self.allocator, .noise, 50.0, 0.8, 44100);
        defer self.allocator.free(samples);

        // Apply explosion envelope (quick attack, long decay)
        const num_frames = samples.len / 2;
        for (0..num_frames) |i| {
            const t: f32 = @as(f32, @floatFromInt(i)) / 44100.0;
            const env = @exp(-t * 3.0) * @min(1.0, t * 50.0);
            samples[i * 2] *= env;
            samples[i * 2 + 1] *= env;
        }

        try self.registerSoundSamples(.explosion, samples);
    }

    fn generateAmbientSound(self: *Self, event: SoundEvent, freq: f32, duration: f32) !void {
        const samples = try generateSound(self.allocator, .noise, freq, duration, 44100);
        defer self.allocator.free(samples);

        // Apply smooth looping envelope
        const num_frames = samples.len / 2;
        const fade_frames = num_frames / 10;
        for (0..num_frames) |i| {
            var env: f32 = 1.0;
            if (i < fade_frames) {
                env = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(fade_frames));
            } else if (i > num_frames - fade_frames) {
                env = @as(f32, @floatFromInt(num_frames - i)) / @as(f32, @floatFromInt(fade_frames));
            }
            samples[i * 2] *= env * 0.3;
            samples[i * 2 + 1] *= env * 0.3;
        }

        try self.registerSoundSamples(event, samples);
    }

    fn generateWeatherSound(self: *Self, event: SoundEvent, duration: f32) !void {
        const sample_rate: u32 = 44100;
        const num_samples: usize = @intFromFloat(duration * @as(f32, @floatFromInt(sample_rate)));
        const samples = try self.allocator.alloc(f32, num_samples * 2);
        defer self.allocator.free(samples);

        var prng = std.Random.DefaultPrng.init(98765);
        const random = prng.random();

        // Generate rain-like noise with droplet texture
        for (0..num_samples) |i| {
            const t: f32 = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(sample_rate));

            // Base noise
            var sample = random.float(f32) * 2.0 - 1.0;

            // Add occasional droplet sounds
            const droplet_chance = random.float(f32);
            if (droplet_chance > 0.998) {
                sample += @sin(t * 2000.0 * std.math.tau) * 0.5;
            }

            // Low-pass filter effect (simple moving average simulation)
            sample *= 0.3;

            // Looping envelope
            const fade_samples = num_samples / 20;
            var env: f32 = 1.0;
            if (i < fade_samples) {
                env = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(fade_samples));
            } else if (i > num_samples - fade_samples) {
                env = @as(f32, @floatFromInt(num_samples - i)) / @as(f32, @floatFromInt(fade_samples));
            }

            samples[i * 2] = sample * env;
            samples[i * 2 + 1] = sample * env;
        }

        try self.registerSoundSamples(event, samples);
    }

    fn generateThunderSound(self: *Self) !void {
        const sample_rate: u32 = 44100;
        const duration: f32 = 2.0;
        const num_samples: usize = @intFromFloat(duration * @as(f32, @floatFromInt(sample_rate)));
        const samples = try self.allocator.alloc(f32, num_samples * 2);
        defer self.allocator.free(samples);

        var prng = std.Random.DefaultPrng.init(11111);
        const random = prng.random();

        for (0..num_samples) |i| {
            const t: f32 = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(sample_rate));

            // Thunder is low frequency noise with sharp attack
            var sample = random.float(f32) * 2.0 - 1.0;

            // Low frequency rumble
            sample += @sin(t * 30.0 * std.math.tau) * 0.3;
            sample += @sin(t * 50.0 * std.math.tau) * 0.2;

            // Envelope: sharp crack then rumble
            const crack_env = @exp(-t * 10.0);
            const rumble_env = @exp(-(t - 0.1) * (t - 0.1) * 5.0);
            const env = @max(crack_env * 0.8, rumble_env * 0.5);

            sample *= env;

            samples[i * 2] = sample;
            samples[i * 2 + 1] = sample;
        }

        try self.registerSoundSamples(.thunder, samples);
    }

    fn registerSoundSamples(self: *Self, event: SoundEvent, samples: []f32) !void {
        // Create a sound in the audio engine
        // For now, we'll store the samples directly
        // In a full implementation, this would register with the audio engine
        _ = samples;

        // Mark the sound as available (in real implementation, would get handle from engine)
        self.sound_handles[@intFromEnum(event)] = SoundHandle{ .index = @intFromEnum(event) };
    }

    // ========================================================================
    // Playback API
    // ========================================================================

    /// Play a sound event
    pub fn play(self: *Self, event: SoundEvent) void {
        self.playWithOptions(event, .{});
    }

    /// Play a sound with volume and pitch options
    pub fn playWithOptions(self: *Self, event: SoundEvent, options: struct {
        volume: f32 = 1.0,
        pitch: f32 = 1.0,
        looping: bool = false,
    }) void {
        const handle = self.sound_handles[@intFromEnum(event)];
        if (!handle.isValid()) {
            log.warn("Sound not loaded: {}", .{event});
            return;
        }

        const category = getSoundCategory(event);
        const effective_volume = self.volumes.getEffectiveVolume(category) * options.volume;

        self.audio_engine.playSound(handle, .{
            .volume = effective_volume,
            .pitch = options.pitch,
            .looping = options.looping,
        });
    }

    /// Play a sound at a 3D position
    pub fn playAt(self: *Self, event: SoundEvent, position: Vec3) void {
        self.playAtWithOptions(event, position, .{});
    }

    /// Play a positioned sound with options
    pub fn playAtWithOptions(self: *Self, event: SoundEvent, position: Vec3, options: struct {
        volume: f32 = 1.0,
        pitch: f32 = 1.0,
        min_distance: f32 = 1.0,
        max_distance: f32 = 32.0,
    }) void {
        const handle = self.sound_handles[@intFromEnum(event)];
        if (!handle.isValid()) return;

        // Calculate distance-based attenuation
        const distance = Vec3.distance(self.listener_position, position);
        if (distance > options.max_distance) return;

        const attenuation = if (distance < options.min_distance)
            1.0
        else
            1.0 - (distance - options.min_distance) / (options.max_distance - options.min_distance);

        const category = getSoundCategory(event);
        const effective_volume = self.volumes.getEffectiveVolume(category) * options.volume * attenuation;

        // Calculate stereo panning based on listener orientation
        const to_sound = Vec3.normalize(Vec3.sub(position, self.listener_position));
        const right = Vec3.cross(self.listener_forward, Vec3.UP);
        const pan = Vec3.dot(to_sound, right); // -1 to 1

        // Apply panning (simplified - real implementation would adjust L/R channels)
        _ = pan;

        self.audio_engine.playSound(handle, .{
            .volume = effective_volume,
            .pitch = options.pitch,
            .looping = false,
            .position = .{ position.x(), position.y(), position.z() },
        });
    }

    /// Play with random pitch variation
    pub fn playWithPitchVariance(self: *Self, event: SoundEvent, variance: f32) void {
        const random = self.prng.random();
        const pitch = 1.0 + (random.float(f32) * 2.0 - 1.0) * variance;
        self.playWithOptions(event, .{ .pitch = pitch });
    }

    /// Set listener position and orientation for 3D audio
    pub fn setListenerPosition(self: *Self, position: Vec3, forward: Vec3) void {
        self.listener_position = position;
        self.listener_forward = Vec3.normalize(forward);
    }

    // ========================================================================
    // Game Integration
    // ========================================================================

    /// Play block break sound based on block type
    pub fn playBlockBreak(self: *Self, block: Block, position: Vec3) void {
        const material = BlockMaterial.fromBlock(block);
        const event = material.getBreakSound();
        self.playAtWithOptions(event, position, .{
            .pitch = 0.9 + self.prng.random().float(f32) * 0.2,
        });
    }

    /// Play block place sound
    pub fn playBlockPlace(self: *Self, position: Vec3) void {
        self.playAtWithOptions(.block_place, position, .{
            .pitch = 0.95 + self.prng.random().float(f32) * 0.1,
        });
    }

    /// Update footstep system
    pub fn updateFootsteps(self: *Self, dt: f32, is_moving: bool, is_running: bool, ground_block: Block) void {
        if (!is_moving) {
            self.footstep_timer = 0;
            return;
        }

        self.last_ground_material = BlockMaterial.fromBlock(ground_block);
        self.footstep_interval = if (is_running) 0.25 else 0.4;

        self.footstep_timer += dt;
        if (self.footstep_timer >= self.footstep_interval) {
            self.footstep_timer = 0;

            const event = self.last_ground_material.getFootstepSound();
            self.playWithPitchVariance(event, 0.15);
        }
    }

    /// Play jump sound
    pub fn playJump(self: *Self) void {
        self.playWithPitchVariance(.player_jump, 0.1);
    }

    /// Play land sound with intensity based on fall distance
    pub fn playLand(self: *Self, fall_distance: f32) void {
        const volume = @min(1.0, fall_distance / 10.0);
        self.playWithOptions(.player_land, .{ .volume = volume });
    }

    // ========================================================================
    // Ambient System
    // ========================================================================

    /// Update ambient sounds based on environment
    pub fn updateAmbient(self: *Self, dt: f32, biome: BiomeType, is_underground: bool, depth: f32) void {
        _ = dt;

        // Determine appropriate ambient sound
        const ambient_event: ?SoundEvent = if (is_underground and depth > 10.0)
            .ambient_cave
        else switch (self.time_of_day) {
            .day, .dawn => if (biome == .forest or biome == .plains) .ambient_birds else null,
            .night, .dusk => if (biome != .desert and biome != .snow) .ambient_crickets else null,
        };

        // Play ambient if changed
        if (ambient_event) |event| {
            const handle = self.sound_handles[@intFromEnum(event)];
            if (handle.isValid() and !self.audio_engine.isSoundPlaying(handle)) {
                self.playWithOptions(event, .{
                    .volume = 0.3,
                    .looping = true,
                });
            }
        }

        // Update weather ambience
        self.updateWeatherAmbient();
    }

    fn updateWeatherAmbient(self: *Self) void {
        if (self.weather == .rain or self.weather == .storm) {
            const rain_handle = self.sound_handles[@intFromEnum(SoundEvent.rain_loop)];
            if (rain_handle.isValid() and !self.audio_engine.isSoundPlaying(rain_handle)) {
                self.playWithOptions(.rain_loop, .{
                    .volume = if (self.weather == .storm) 0.8 else 0.5,
                    .looping = true,
                });
            }

            // Occasional thunder in storms
            if (self.weather == .storm) {
                const random = self.prng.random();
                if (random.float(f32) < 0.001) { // ~0.1% chance per update
                    self.play(.thunder);
                }
            }
        }
    }

    /// Set world time (0-24 hours)
    pub fn setWorldTime(self: *Self, hour: f32) void {
        self.world_hour = @mod(hour, 24.0);
        self.time_of_day = TimeOfDay.fromHour(self.world_hour);
    }

    /// Set weather state
    pub fn setWeather(self: *Self, weather: WeatherState) void {
        if (self.weather != weather) {
            // Stop current weather sounds
            if (self.weather == .rain or self.weather == .storm) {
                const rain_handle = self.sound_handles[@intFromEnum(SoundEvent.rain_loop)];
                if (rain_handle.isValid()) {
                    self.audio_engine.stopSound(rain_handle);
                }
            }
            self.weather = weather;
        }
    }

    // ========================================================================
    // Volume Controls
    // ========================================================================

    /// Set master volume (0.0 to 1.0)
    pub fn setMasterVolume(self: *Self, volume: f32) void {
        self.volumes.master = std.math.clamp(volume, 0.0, 1.0);
        self.audio_engine.setMasterVolume(self.volumes.master);
    }

    /// Set music volume (0.0 to 1.0)
    pub fn setMusicVolume(self: *Self, volume: f32) void {
        self.volumes.music = std.math.clamp(volume, 0.0, 1.0);
    }

    /// Set SFX volume (0.0 to 1.0)
    pub fn setSFXVolume(self: *Self, volume: f32) void {
        self.volumes.sfx = std.math.clamp(volume, 0.0, 1.0);
    }

    /// Set ambient volume (0.0 to 1.0)
    pub fn setAmbientVolume(self: *Self, volume: f32) void {
        self.volumes.ambient = std.math.clamp(volume, 0.0, 1.0);
    }

    /// Get current volume settings
    pub fn getVolumeSettings(self: *const Self) VolumeSettings {
        return self.volumes;
    }
};

/// Get volume category for a sound event
fn getSoundCategory(event: SoundEvent) VolumeCategory {
    return switch (event) {
        .ui_click, .ui_open, .ui_close, .ui_select => .ui,
        .ambient_cave, .ambient_wind, .ambient_birds, .ambient_crickets, .ambient_underwater, .rain_loop, .thunder, .wind_gust => .ambient,
        else => .sfx,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "sound event enum count" {
    try std.testing.expectEqual(@as(usize, 45), SoundEvent.COUNT);
}

test "block material mapping" {
    try std.testing.expectEqual(BlockMaterial.stone, BlockMaterial.fromBlock(.stone));
    try std.testing.expectEqual(BlockMaterial.dirt, BlockMaterial.fromBlock(.grass));
    try std.testing.expectEqual(BlockMaterial.wood, BlockMaterial.fromBlock(.planks));
    try std.testing.expectEqual(BlockMaterial.sand, BlockMaterial.fromBlock(.sand));
}

test "block material sounds" {
    try std.testing.expectEqual(SoundEvent.block_break_stone, BlockMaterial.stone.getBreakSound());
    try std.testing.expectEqual(SoundEvent.footstep_grass, BlockMaterial.dirt.getFootstepSound());
}

test "time of day from hour" {
    try std.testing.expectEqual(TimeOfDay.dawn, TimeOfDay.fromHour(6.0));
    try std.testing.expectEqual(TimeOfDay.day, TimeOfDay.fromHour(12.0));
    try std.testing.expectEqual(TimeOfDay.dusk, TimeOfDay.fromHour(18.0));
    try std.testing.expectEqual(TimeOfDay.night, TimeOfDay.fromHour(22.0));
    try std.testing.expectEqual(TimeOfDay.night, TimeOfDay.fromHour(3.0));
}

test "volume settings" {
    const settings = VolumeSettings{
        .master = 0.8,
        .sfx = 0.5,
    };
    try std.testing.expectApproxEqAbs(@as(f32, 0.4), settings.getEffectiveVolume(.sfx), 0.001);
}

test "procedural sound generation" {
    const allocator = std.testing.allocator;

    const samples = try generateSound(allocator, .sine, 440.0, 0.1, 44100);
    defer allocator.free(samples);

    // Should have stereo samples for 0.1 seconds at 44100 Hz
    try std.testing.expectEqual(@as(usize, 4410 * 2), samples.len);

    // First sample should be near zero (sine starts at 0)
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), samples[0], 0.1);
}

test "procedural ADSR sound generation" {
    const allocator = std.testing.allocator;

    const samples = try generateSoundADSR(allocator, .sine, 440.0, 0.01, 0.02, 0.05, 0.02, 44100);
    defer allocator.free(samples);

    // Total duration is 0.1 seconds
    try std.testing.expectEqual(@as(usize, 4410 * 2), samples.len);
}

test "sound manager initialization" {
    const allocator = std.testing.allocator;

    var audio_engine = try AudioEngine.init(allocator);
    defer audio_engine.deinit();

    var manager = SoundManager.init(allocator, &audio_engine);
    defer manager.deinit();

    try std.testing.expectEqual(TimeOfDay.day, manager.time_of_day);
    try std.testing.expectEqual(WeatherState.clear, manager.weather);
}

test "volume category mapping" {
    try std.testing.expectEqual(VolumeCategory.ui, getSoundCategory(.ui_click));
    try std.testing.expectEqual(VolumeCategory.ambient, getSoundCategory(.ambient_cave));
    try std.testing.expectEqual(VolumeCategory.sfx, getSoundCategory(.explosion));
}
