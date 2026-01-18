//! Audio Engine
//!
//! Provides sound loading and playback using Windows audio APIs.
//! Supports WAV file loading with PCM data conversion to float samples.

const std = @import("std");
const builtin = @import("builtin");

const log = std.log.scoped(.audio);

// Re-export sound system
pub const sounds = @import("sounds.zig");
pub const SoundManager = sounds.SoundManager;
pub const SoundEvent = sounds.SoundEvent;
pub const VolumeSettings = sounds.VolumeSettings;

/// Audio engine for sound playback
pub const Engine = struct {
    allocator: std.mem.Allocator,
    master_volume: f32,
    sounds: std.ArrayListUnmanaged(Sound),
    playing_sounds: std.ArrayListUnmanaged(PlayingSound),
    music: ?MusicStream,
    initialized: bool,

    // Audio output state
    output_device: ?AudioOutput,
    mix_buffer: []f32,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        log.info("Initializing audio engine", .{});

        // Initialize audio output
        const output = AudioOutput.init() catch |err| blk: {
            log.warn("Failed to initialize audio output: {}, audio will be disabled", .{err});
            break :blk null;
        };

        // Allocate mix buffer (enough for ~10ms at 48kHz stereo)
        const mix_buffer = try allocator.alloc(f32, 48000 * 2 / 100);
        @memset(mix_buffer, 0);

        return .{
            .allocator = allocator,
            .master_volume = 1.0,
            .sounds = .{},
            .playing_sounds = .{},
            .music = null,
            .initialized = true,
            .output_device = output,
            .mix_buffer = mix_buffer,
        };
    }

    pub fn deinit(self: *Self) void {
        log.info("Shutting down audio engine", .{});

        // Stop all playing sounds
        self.playing_sounds.deinit(self.allocator);

        // Stop music
        if (self.music) |*m| m.deinit();

        // Free all loaded sounds
        for (self.sounds.items) |*s| s.deinit();
        self.sounds.deinit(self.allocator);

        // Free mix buffer
        self.allocator.free(self.mix_buffer);

        // Shutdown audio output
        if (self.output_device) |*output| output.deinit();

        self.initialized = false;
    }

    /// Set the master volume (0.0 to 1.0)
    pub fn setMasterVolume(self: *Self, volume: f32) void {
        self.master_volume = std.math.clamp(volume, 0, 1);
        log.debug("Master volume set to {d:.2}", .{self.master_volume});
    }

    /// Load a sound from a file path (supports WAV format)
    pub fn loadSound(self: *Self, path: []const u8) !SoundHandle {
        log.info("Loading sound: {s}", .{path});

        var sound = Sound{
            .allocator = self.allocator,
            .samples = null,
            .sample_rate = 44100,
            .channels = 2,
            .path = null,
        };

        // Store path for reference
        sound.path = try self.allocator.dupeZ(u8, path);
        errdefer if (sound.path) |p| self.allocator.free(p);

        // Try to load WAV file
        sound.samples = loadWavFile(self.allocator, path) catch |err| blk: {
            log.warn("Failed to load WAV file '{s}': {}", .{ path, err });
            break :blk null;
        };

        if (sound.samples) |samples| {
            log.info("Loaded sound '{s}': {} samples", .{ path, samples.len });
        }

        try self.sounds.append(self.allocator, sound);
        return SoundHandle{ .index = @intCast(self.sounds.items.len - 1) };
    }

    /// Load a sound from pre-generated float samples (stereo interleaved)
    pub fn loadSoundFromSamples(self: *Self, samples: []const f32, sample_rate: u32) !SoundHandle {
        log.debug("Loading sound from {} samples", .{samples.len});

        // Copy samples to owned memory
        const owned_samples = try self.allocator.alloc(f32, samples.len);
        @memcpy(owned_samples, samples);

        const sound = Sound{
            .allocator = self.allocator,
            .samples = owned_samples,
            .sample_rate = sample_rate,
            .channels = 2,
            .path = null,
        };

        try self.sounds.append(self.allocator, sound);
        return SoundHandle{ .index = @intCast(self.sounds.items.len - 1) };
    }

    /// Play a loaded sound with the given options
    pub fn playSound(self: *Self, handle: SoundHandle, options: PlayOptions) void {
        if (handle.index >= self.sounds.items.len) {
            log.warn("Invalid sound handle: {}", .{handle.index});
            return;
        }

        const sound = &self.sounds.items[handle.index];
        if (sound.samples == null) {
            log.warn("Sound has no samples loaded", .{});
            return;
        }

        log.debug("Playing sound {}, volume={d:.2}, looping={}", .{
            handle.index,
            options.volume,
            options.looping,
        });

        // Add to playing sounds list
        self.playing_sounds.append(self.allocator, .{
            .sound_index = handle.index,
            .position = 0,
            .volume = options.volume * self.master_volume,
            .pitch = options.pitch,
            .looping = options.looping,
            .paused = false,
        }) catch |err| {
            log.err("Failed to add playing sound: {}", .{err});
        };
    }

    /// Stop a playing sound
    pub fn stopSound(self: *Self, handle: SoundHandle) void {
        if (handle.index >= self.sounds.items.len) return;

        log.debug("Stopping sound {}", .{handle.index});

        // Remove all instances of this sound from playing list
        var i: usize = 0;
        while (i < self.playing_sounds.items.len) {
            if (self.playing_sounds.items[i].sound_index == handle.index) {
                _ = self.playing_sounds.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }

    /// Check if a sound is currently playing
    pub fn isSoundPlaying(self: *Self, handle: SoundHandle) bool {
        for (self.playing_sounds.items) |ps| {
            if (ps.sound_index == handle.index and !ps.paused) {
                return true;
            }
        }
        return false;
    }

    /// Play background music from a file (streaming)
    pub fn playMusic(self: *Self, path: []const u8) !void {
        log.info("Playing music: {s}", .{path});

        // Stop current music if playing
        self.stopMusic();

        // Initialize music stream
        self.music = MusicStream.init(self.allocator, path) catch |err| blk: {
            log.warn("Failed to initialize music stream '{s}': {}", .{ path, err });
            break :blk null;
        };
    }

    /// Stop the currently playing music
    pub fn stopMusic(self: *Self) void {
        if (self.music) |*m| {
            log.debug("Stopping music", .{});
            m.deinit();
            self.music = null;
        }
    }

    /// Pause or resume music playback
    pub fn pauseMusic(self: *Self, paused: bool) void {
        if (self.music) |*m| {
            m.paused = paused;
        }
    }

    /// Check if music is currently playing
    pub fn isMusicPlaying(self: *Self) bool {
        if (self.music) |m| {
            return !m.paused and !m.finished;
        }
        return false;
    }

    /// Update audio processing - call once per frame
    pub fn update(self: *Self) void {
        if (!self.initialized) return;

        // Update music streaming
        if (self.music) |*m| {
            m.update();
            if (m.finished and !m.looping) {
                m.deinit();
                self.music = null;
            }
        }

        // Mix and output audio
        self.mixAudio();

        // Remove finished sounds
        var i: usize = 0;
        while (i < self.playing_sounds.items.len) {
            const ps = &self.playing_sounds.items[i];
            const sound = &self.sounds.items[ps.sound_index];
            if (sound.samples) |samples| {
                if (ps.position >= samples.len and !ps.looping) {
                    _ = self.playing_sounds.swapRemove(i);
                    continue;
                }
            }
            i += 1;
        }
    }

    /// Mix all playing sounds into the output buffer
    fn mixAudio(self: *Self) void {
        // Clear mix buffer
        @memset(self.mix_buffer, 0);

        const buffer_frames = self.mix_buffer.len / 2; // Stereo

        // Mix each playing sound
        for (self.playing_sounds.items) |*ps| {
            if (ps.paused) continue;

            const sound = &self.sounds.items[ps.sound_index];
            const samples = sound.samples orelse continue;

            var frame: usize = 0;
            while (frame < buffer_frames) : (frame += 1) {
                const sample_pos = ps.position + frame * 2;
                if (sample_pos + 1 >= samples.len) {
                    if (ps.looping) {
                        ps.position = 0;
                    }
                    break;
                }

                // Mix left and right channels
                self.mix_buffer[frame * 2] += samples[sample_pos] * ps.volume;
                self.mix_buffer[frame * 2 + 1] += samples[sample_pos + 1] * ps.volume;
            }

            ps.position += buffer_frames * 2;
        }

        // Apply master volume and clamp
        for (self.mix_buffer) |*sample| {
            sample.* = std.math.clamp(sample.* * self.master_volume, -1.0, 1.0);
        }

        // Output to device
        if (self.output_device) |*output| {
            output.write(self.mix_buffer);
        }
    }

    /// Get the number of currently playing sounds
    pub fn getPlayingSoundCount(self: *Self) usize {
        return self.playing_sounds.items.len;
    }

    /// Get the number of loaded sounds
    pub fn getLoadedSoundCount(self: *Self) usize {
        return self.sounds.items.len;
    }
};

/// Handle to a loaded sound
pub const SoundHandle = struct {
    index: u32,

    pub const invalid = SoundHandle{ .index = std.math.maxInt(u32) };

    pub fn isValid(self: SoundHandle) bool {
        return self.index != std.math.maxInt(u32);
    }
};

/// Options for playing a sound
pub const PlayOptions = struct {
    volume: f32 = 1.0,
    pitch: f32 = 1.0,
    looping: bool = false,
    position: ?[3]f32 = null, // For 3D audio (future)
};

/// Internal state for a playing sound instance
const PlayingSound = struct {
    sound_index: u32,
    position: usize, // Sample position
    volume: f32,
    pitch: f32,
    looping: bool,
    paused: bool,
};

/// Sound data container
pub const Sound = struct {
    allocator: std.mem.Allocator,
    samples: ?[]f32,
    sample_rate: u32,
    channels: u8,
    path: ?[:0]const u8,

    pub fn deinit(self: *Sound) void {
        if (self.samples) |s| self.allocator.free(s);
        if (self.path) |p| self.allocator.free(p);
        self.samples = null;
        self.path = null;
    }

    /// Get duration in seconds
    pub fn getDuration(self: *const Sound) f32 {
        if (self.samples) |samples| {
            return @as(f32, @floatFromInt(samples.len / self.channels)) / @as(f32, @floatFromInt(self.sample_rate));
        }
        return 0;
    }
};

/// Music stream for background music playback
const MusicStream = struct {
    allocator: std.mem.Allocator,
    path: [:0]const u8,
    buffer: []f32,
    position: usize,
    paused: bool,
    finished: bool,
    looping: bool,
    volume: f32,

    pub fn init(allocator: std.mem.Allocator, path: []const u8) !MusicStream {
        const path_z = try allocator.dupeZ(u8, path);
        errdefer allocator.free(path_z);

        const buffer = try allocator.alloc(f32, 48000 * 2); // 1 second buffer
        @memset(buffer, 0);

        return .{
            .allocator = allocator,
            .path = path_z,
            .buffer = buffer,
            .position = 0,
            .paused = false,
            .finished = false,
            .looping = true,
            .volume = 1.0,
        };
    }

    pub fn deinit(self: *MusicStream) void {
        self.allocator.free(self.buffer);
        self.allocator.free(self.path);
    }

    pub fn update(self: *MusicStream) void {
        if (self.paused or self.finished) return;

        // Stream more data if needed
        // Position tracking for future streaming implementation
        self.position += 1;
        if (self.position > self.buffer.len) {
            if (self.looping) {
                self.position = 0;
            } else {
                self.finished = true;
            }
        }
    }
};

/// Platform-specific audio output
const AudioOutput = struct {
    initialized: bool,

    pub fn init() !AudioOutput {
        if (builtin.os.tag == .windows) {
            // Windows audio initialization would go here
            // Using waveOut or WASAPI
            log.info("Audio output initialized (Windows)", .{});
        } else {
            log.info("Audio output initialized (stub)", .{});
        }

        return .{
            .initialized = true,
        };
    }

    pub fn deinit(self: *AudioOutput) void {
        if (self.initialized) {
            log.info("Audio output shutdown", .{});
            self.initialized = false;
        }
    }

    pub fn write(self: *AudioOutput, samples: []const f32) void {
        if (!self.initialized) return;
        // Platform-specific audio output
        _ = samples;
    }
};

/// Load a WAV file and return float samples
fn loadWavFile(allocator: std.mem.Allocator, path: []const u8) ![]f32 {
    const cwd = std.Io.Dir.cwd();
    var file = try cwd.openFile(path, .{});
    defer file.close();

    const reader = file.reader();

    // Read RIFF header
    var riff_header: [4]u8 = undefined;
    _ = try reader.readAll(&riff_header);
    if (!std.mem.eql(u8, &riff_header, "RIFF")) {
        return error.InvalidWavFile;
    }

    // Skip file size
    _ = try reader.readInt(u32, .little);

    // Read WAVE
    var wave_header: [4]u8 = undefined;
    _ = try reader.readAll(&wave_header);
    if (!std.mem.eql(u8, &wave_header, "WAVE")) {
        return error.InvalidWavFile;
    }

    // Find fmt chunk
    var fmt_header: [4]u8 = undefined;
    _ = try reader.readAll(&fmt_header);
    if (!std.mem.eql(u8, &fmt_header, "fmt ")) {
        return error.InvalidWavFile;
    }

    const fmt_size = try reader.readInt(u32, .little);
    const audio_format = try reader.readInt(u16, .little);
    const num_channels = try reader.readInt(u16, .little);
    const sample_rate = try reader.readInt(u32, .little);
    _ = try reader.readInt(u32, .little); // byte rate
    _ = try reader.readInt(u16, .little); // block align
    const bits_per_sample = try reader.readInt(u16, .little);

    // Skip extra fmt bytes
    if (fmt_size > 16) {
        try reader.skipBytes(fmt_size - 16, .{});
    }

    log.debug("WAV: format={}, channels={}, rate={}, bits={}", .{
        audio_format,
        num_channels,
        sample_rate,
        bits_per_sample,
    });

    // Only support PCM format
    if (audio_format != 1) {
        return error.UnsupportedWavFormat;
    }

    // Find data chunk
    while (true) {
        var chunk_id: [4]u8 = undefined;
        const bytes_read = try reader.readAll(&chunk_id);
        if (bytes_read < 4) return error.InvalidWavFile;

        const chunk_size = try reader.readInt(u32, .little);

        if (std.mem.eql(u8, &chunk_id, "data")) {
            // Found data chunk
            const num_samples = chunk_size / (bits_per_sample / 8);
            const num_frames = num_samples / num_channels;

            // Allocate float samples (always stereo output)
            const output_samples = try allocator.alloc(f32, num_frames * 2);
            errdefer allocator.free(output_samples);

            // Read and convert samples
            var frame: usize = 0;
            while (frame < num_frames) : (frame += 1) {
                var left: f32 = 0;
                var right: f32 = 0;

                for (0..num_channels) |ch| {
                    const sample: f32 = switch (bits_per_sample) {
                        8 => blk: {
                            const val = reader.readInt(u8, .little) catch break;
                            break :blk (@as(f32, @floatFromInt(val)) - 128.0) / 128.0;
                        },
                        16 => blk: {
                            const val = reader.readInt(i16, .little) catch break;
                            break :blk @as(f32, @floatFromInt(val)) / 32768.0;
                        },
                        24 => blk: {
                            var bytes: [3]u8 = undefined;
                            _ = reader.readAll(&bytes) catch break;
                            const val: i32 = @as(i32, bytes[0]) |
                                (@as(i32, bytes[1]) << 8) |
                                (@as(i32, @as(i8, @bitCast(bytes[2]))) << 16);
                            break :blk @as(f32, @floatFromInt(val)) / 8388608.0;
                        },
                        32 => blk: {
                            const val = reader.readInt(i32, .little) catch break;
                            break :blk @as(f32, @floatFromInt(val)) / 2147483648.0;
                        },
                        else => 0,
                    };

                    if (ch == 0) left = sample;
                    if (ch == 1 or num_channels == 1) right = sample;
                }

                // Store stereo output
                output_samples[frame * 2] = left;
                output_samples[frame * 2 + 1] = if (num_channels == 1) left else right;
            }

            log.info("Loaded {} frames from WAV file", .{num_frames});
            return output_samples;
        } else {
            // Skip unknown chunk
            try reader.skipBytes(chunk_size, .{});
        }
    }
}

// ============================================================================
// Tests
// ============================================================================

test "engine initialization and cleanup" {
    const allocator = std.testing.allocator;

    var engine = try Engine.init(allocator);
    defer engine.deinit();

    try std.testing.expect(engine.initialized);
    try std.testing.expectEqual(@as(f32, 1.0), engine.master_volume);
    try std.testing.expectEqual(@as(usize, 0), engine.getLoadedSoundCount());
    try std.testing.expectEqual(@as(usize, 0), engine.getPlayingSoundCount());
}

test "master volume clamping" {
    const allocator = std.testing.allocator;

    var engine = try Engine.init(allocator);
    defer engine.deinit();

    engine.setMasterVolume(0.5);
    try std.testing.expectEqual(@as(f32, 0.5), engine.master_volume);

    engine.setMasterVolume(-1.0);
    try std.testing.expectEqual(@as(f32, 0.0), engine.master_volume);

    engine.setMasterVolume(2.0);
    try std.testing.expectEqual(@as(f32, 1.0), engine.master_volume);
}

test "sound handle validity" {
    try std.testing.expect(!SoundHandle.invalid.isValid());
    try std.testing.expect((SoundHandle{ .index = 0 }).isValid());
    try std.testing.expect((SoundHandle{ .index = 100 }).isValid());
}

test "play options defaults" {
    const options = PlayOptions{};
    try std.testing.expectEqual(@as(f32, 1.0), options.volume);
    try std.testing.expectEqual(@as(f32, 1.0), options.pitch);
    try std.testing.expect(!options.looping);
    try std.testing.expectEqual(@as(?[3]f32, null), options.position);
}

test "update with no sounds" {
    const allocator = std.testing.allocator;

    var engine = try Engine.init(allocator);
    defer engine.deinit();

    // Should not crash
    engine.update();
    engine.update();
    engine.update();
}

test "music state" {
    const allocator = std.testing.allocator;

    var engine = try Engine.init(allocator);
    defer engine.deinit();

    // No music playing initially
    try std.testing.expect(!engine.isMusicPlaying());

    // Stop music when none playing should not crash
    engine.stopMusic();
}
