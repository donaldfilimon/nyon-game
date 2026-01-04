//! Audio Utilities for Game Engine Development
//!

const std = @import("std");

/// Audio sample types
pub const SampleType = f32;

/// Audio buffer for holding sample data
pub const AudioBuffer = struct {
    samples: []SampleType,
    sample_rate: u32,
    channels: u16,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, sample_count: usize, sample_rate: u32, channels: u16) !AudioBuffer {
        const samples = try allocator.alloc(SampleType, sample_count * channels);
        return AudioBuffer{
            .samples = samples,
            .sample_rate = sample_rate,
            .channels = channels,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AudioBuffer) void {
        self.allocator.free(self.samples);
    }

    pub fn getSample(self: *AudioBuffer, frame: usize, channel: u16) SampleType {
        if (frame < self.samples.len / self.channels) {
            return self.samples[frame * self.channels + channel];
        }
        return 0;
    }

    pub fn setSample(self: *AudioBuffer, frame: usize, channel: u16, value: SampleType) void {
        if (frame < self.samples.len / self.channels) {
            self.samples[frame * self.channels + channel] = value;
        }
    }

    pub fn duration(self: *const AudioBuffer) f32 {
        const num_frames = self.samples.len / self.channels;
        return @as(f32, @floatFromInt(num_frames)) / @as(f32, @floatFromInt(self.sample_rate));
    }
};

/// Simple audio mixer
pub const AudioMixer = struct {
    master_volume: f32,
    channels: std.ArrayList(MixerChannel),
    allocator: std.mem.Allocator,

    const MixerChannel = struct {
        volume: f32,
        pan: f32,
        buffer: []SampleType,
        muted: bool,
    };

    pub fn init(allocator: std.mem.Allocator) AudioMixer {
        return AudioMixer{
            .master_volume = 1.0,
            .channels = std.ArrayList(MixerChannel).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AudioMixer) void {
        for (self.channels.items) |channel| {
            self.allocator.free(channel.buffer);
        }
        self.channels.deinit();
    }

    pub fn addChannel(self: *AudioMixer, sample_count: usize, channels: u16) !usize {
        const buffer = try self.allocator.alloc(SampleType, sample_count * channels);
        @memset(buffer, 0);

        try self.channels.append(MixerChannel{
            .volume = 1.0,
            .pan = 0.0,
            .buffer = buffer,
            .muted = false,
        });

        return self.channels.items.len - 1;
    }

    pub fn setVolume(self: *AudioMixer, channel: usize, volume: f32) void {
        if (channel < self.channels.items.len) {
            self.channels.items[channel].volume = volume;
        }
    }

    pub fn setPan(self: *AudioMixer, channel: usize, pan: f32) void {
        if (channel < self.channels.items.len) {
            self.channels.items[channel].pan = pan;
        }
    }

    pub fn mix(self: *AudioMixer, output: []SampleType, num_channels: u16) void {
        @memset(output, 0);

        for (self.channels.items) |channel| {
            if (channel.muted or channel.volume == 0) continue;

            const left_gain = channel.volume * (1.0 - (channel.pan + 1.0) / 2.0);
            const right_gain = channel.volume * (channel.pan + 1.0) / 2.0;

            const num_frames = @min(output.len / num_channels, channel.buffer.len / channel.channels);

            for (0..num_frames) |frame| {
                const sample = channel.buffer[frame * channel.channels];
                const left_idx = frame * num_channels;
                const right_idx = frame * num_channels + 1;

                output[left_idx] += sample * left_gain * self.master_volume;
                if (num_channels > 1) {
                    output[right_idx] += sample * right_gain * self.master_volume;
                }
            }
        }
    }
};

/// Simple sine wave oscillator
pub fn generateSineWave(allocator: std.mem.Allocator, frequency: f32, duration: f32, sample_rate: u32, amplitude: f32) ![]SampleType {
    const num_samples = @as(usize, @intFromFloat(duration * @as(f32, @floatFromInt(sample_rate))));
    const samples = try allocator.alloc(SampleType, num_samples);

    for (0..num_samples) |i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(sample_rate));
        samples[i] = amplitude * std.math.sin(2.0 * std.math.pi * frequency * t);
    }

    return samples;
}
