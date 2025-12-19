//! Audio System - Core audio types and mathematics
//!
//! This module provides the fundamental types and mathematical operations
//! needed for 3D spatial audio, mixing, and audio processing.

const std = @import("std");

/// Audio sample format
pub const SampleFormat = enum {
    f32, // 32-bit float
    i16, // 16-bit signed integer
    u8, // 8-bit unsigned integer
};

/// Audio channel configuration
pub const ChannelLayout = enum {
    mono,
    stereo,
    surround_5_1,
    surround_7_1,

    pub fn channelCount(self: ChannelLayout) u32 {
        return switch (self) {
            .mono => 1,
            .stereo => 2,
            .surround_5_1 => 6,
            .surround_7_1 => 8,
        };
    }
};

/// Audio format descriptor
pub const AudioFormat = struct {
    sample_rate: u32,
    channels: ChannelLayout,
    sample_format: SampleFormat,

    pub fn bytesPerSample(self: AudioFormat) u32 {
        return switch (self.sample_format) {
            .f32 => 4,
            .i16 => 2,
            .u8 => 1,
        };
    }

    pub fn bytesPerFrame(self: AudioFormat) u32 {
        return self.bytesPerSample() * self.channels.channelCount();
    }

    pub fn framesToBytes(self: AudioFormat, frames: u32) u32 {
        return frames * self.bytesPerFrame();
    }

    pub fn bytesToFrames(self: AudioFormat, bytes: u32) u32 {
        return bytes / self.bytesPerFrame();
    }
};

/// 3D vector for audio positioning
pub const Vec3 = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn zero() Vec3 {
        return .{ .x = 0, .y = 0, .z = 0 };
    }

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }

    pub fn mul(v: Vec3, s: f32) Vec3 {
        return .{ .x = v.x * s, .y = v.y * s, .z = v.z * s };
    }

    pub fn dot(a: Vec3, b: Vec3) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }

    pub fn length(v: Vec3) f32 {
        return @sqrt(v.dot(v));
    }

    pub fn normalize(v: Vec3) Vec3 {
        const len = v.length();
        if (len > 0) {
            return v.mul(1.0 / len);
        }
        return Vec3.zero();
    }

    pub fn distance(a: Vec3, b: Vec3) f32 {
        return a.sub(b).length();
    }
};

/// Quaternion for 3D audio orientation
pub const Quat = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    w: f32 = 1,

    pub fn identity() Quat {
        return .{ .x = 0, .y = 0, .z = 0, .w = 1 };
    }

    pub fn fromEuler(pitch: f32, yaw: f32, roll: f32) Quat {
        const cr = @cos(roll * 0.5);
        const sr = @sin(roll * 0.5);
        const cp = @cos(pitch * 0.5);
        const sp = @sin(pitch * 0.5);
        const cy = @cos(yaw * 0.5);
        const sy = @sin(yaw * 0.5);

        return .{
            .w = cr * cp * cy + sr * sp * sy,
            .x = sr * cp * cy - cr * sp * sy,
            .y = cr * sp * cy + sr * cp * sy,
            .z = cr * cp * sy - sr * sp * cy,
        };
    }

    pub fn rotateVector(q: Quat, v: Vec3) Vec3 {
        const qv = Quat{ .x = v.x, .y = v.y, .z = v.z, .w = 0 };
        const result = q.mul(qv).mul(q.conjugate());
        return .{ .x = result.x, .y = result.y, .z = result.z };
    }

    pub fn mul(a: Quat, b: Quat) Quat {
        return .{
            .w = a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
            .x = a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
            .y = a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
            .z = a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
        };
    }

    pub fn conjugate(q: Quat) Quat {
        return .{
            .w = q.w,
            .x = -q.x,
            .y = -q.y,
            .z = -q.z,
        };
    }
};

/// Audio buffer for PCM data
pub const AudioBuffer = struct {
    data: []u8,
    format: AudioFormat,
    frame_count: u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, format: AudioFormat, frame_count: u32) !AudioBuffer {
        const size = format.framesToBytes(frame_count);
        const data = try allocator.alloc(u8, size);

        return .{
            .data = data,
            .format = format,
            .frame_count = frame_count,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AudioBuffer) void {
        self.allocator.free(self.data);
    }

    pub fn getSampleF32(self: AudioBuffer, frame: u32, channel: u32) f32 {
        if (frame >= self.frame_count or channel >= self.format.channels.channelCount()) {
            return 0.0;
        }

        const sample_index = frame * self.format.channels.channelCount() + channel;
        const byte_offset = sample_index * self.format.bytesPerSample();

        return switch (self.format.sample_format) {
            .f32 => {
                const ptr = @as(*const f32, @ptrCast(@alignCast(&self.data[byte_offset])));
                return ptr.*;
            },
            .i16 => {
                const ptr = @as(*const i16, @ptrCast(@alignCast(&self.data[byte_offset])));
                return @as(f32, @floatFromInt(ptr.*)) / 32768.0;
            },
            .u8 => {
                const value = self.data[byte_offset];
                return (@as(f32, @floatFromInt(value)) - 128.0) / 128.0;
            },
        };
    }

    pub fn setSampleF32(self: *AudioBuffer, frame: u32, channel: u32, value: f32) void {
        if (frame >= self.frame_count or channel >= self.format.channels.channelCount()) {
            return;
        }

        const clamped_value = std.math.clamp(value, -1.0, 1.0);
        const sample_index = frame * self.format.channels.channelCount() + channel;
        const byte_offset = sample_index * self.format.bytesPerSample();

        switch (self.format.sample_format) {
            .f32 => {
                const ptr = @as(*f32, @ptrCast(@alignCast(&self.data[byte_offset])));
                ptr.* = clamped_value;
            },
            .i16 => {
                const ptr = @as(*i16, @ptrCast(@alignCast(&self.data[byte_offset])));
                ptr.* = @intFromFloat(clamped_value * 32767.0);
            },
            .u8 => {
                const ptr = @as(*u8, @ptrCast(@alignCast(&self.data[byte_offset])));
                ptr.* = @intFromFloat((clamped_value * 127.0) + 128.0);
            },
        }
    }

    /// Mix another buffer into this one
    pub fn mixBuffer(self: *AudioBuffer, other: AudioBuffer, gain: f32) void {
        if (self.format.sample_rate != other.format.sample_rate or
            self.format.channels != other.format.channels)
        {
            return; // Incompatible formats
        }

        const mix_frames = @min(self.frame_count, other.frame_count);

        for (0..mix_frames) |frame| {
            for (0..self.format.channels.channelCount()) |channel| {
                const current = self.getSampleF32(@intCast(frame), @intCast(channel));
                const input = other.getSampleF32(@intCast(frame), @intCast(channel));
                const mixed = current + input * gain;
                self.setSampleF32(@intCast(frame), @intCast(channel), mixed);
            }
        }
    }

    /// Clear the buffer to silence
    pub fn clear(self: *AudioBuffer) void {
        @memset(self.data, 0);
    }
};

/// Audio clip resource (loaded audio data)
pub const AudioClip = struct {
    name: []const u8,
    buffer: AudioBuffer,
    loop: bool = false,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, buffer: AudioBuffer) !AudioClip {
        return .{
            .name = try allocator.dupe(u8, name),
            .buffer = buffer,
            .loop = false,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AudioClip) void {
        self.allocator.free(self.name);
        self.buffer.deinit();
    }
};

// ============================================================================
// Spatial Audio Mathematics
// ============================================================================

/// Calculate distance attenuation for 3D audio
pub fn calculateDistanceAttenuation(
    distance: f32,
    min_distance: f32,
    max_distance: f32,
    rolloff_factor: f32,
) f32 {
    if (distance <= min_distance) {
        return 1.0;
    }
    if (distance >= max_distance) {
        return 0.0;
    }

    // Inverse distance model
    const attenuation = min_distance / (min_distance + rolloff_factor * (distance - min_distance));
    return std.math.clamp(attenuation, 0.0, 1.0);
}

/// Calculate stereo panning from 3D position
pub fn calculateStereoPan(
    source_pos: Vec3,
    listener_pos: Vec3,
    listener_forward: Vec3,
    listener_up: Vec3,
) f32 {
    // Calculate direction from listener to source
    const direction = source_pos.sub(listener_pos).normalize();

    // Calculate right vector
    const right = listener_forward.cross(listener_up).normalize();

    // Project direction onto right vector
    const dot_right = direction.dot(right);

    // Convert to pan value (-1 = full left, 1 = full right)
    return std.math.clamp(dot_right, -1.0, 1.0);
}

/// Calculate Doppler shift for moving sources
pub fn calculateDopplerShift(
    source_velocity: Vec3,
    listener_velocity: Vec3,
    sound_direction: Vec3,
    speed_of_sound: f32,
) f32 {
    // Calculate relative velocity along the line of sight
    const relative_velocity = source_velocity.sub(listener_velocity);
    const velocity_projection = relative_velocity.dot(sound_direction);

    // Avoid division by zero
    if (@abs(velocity_projection) < 0.001) {
        return 1.0; // No Doppler shift
    }

    // Calculate frequency ratio
    const ratio = speed_of_sound / (speed_of_sound + velocity_projection);
    return std.math.clamp(ratio, 0.1, 4.0); // Reasonable frequency limits
}

/// Convert linear amplitude to decibels
pub fn amplitudeToDb(amplitude: f32) f32 {
    if (amplitude <= 0.0) return -std.math.inf(f32);
    return 20.0 * std.math.log10(amplitude);
}

/// Convert decibels to linear amplitude
pub fn dbToAmplitude(db: f32) f32 {
    return std.math.pow(f32, 10.0, db / 20.0);
}

// ============================================================================
// Tests
// ============================================================================

test "audio format calculations" {
    const format = AudioFormat{
        .sample_rate = 44100,
        .channels = .stereo,
        .sample_format = .f32,
    };

    try std.testing.expect(format.bytesPerSample() == 4);
    try std.testing.expect(format.bytesPerFrame() == 8); // 2 channels * 4 bytes
    try std.testing.expect(format.framesToBytes(100) == 800);
    try std.testing.expect(format.bytesToFrames(800) == 100);
}

test "vector operations" {
    const a = Vec3.init(1, 2, 3);
    const b = Vec3.init(4, 5, 6);

    const sum = a.add(b);
    try std.testing.expect(sum.x == 5 and sum.y == 7 and sum.z == 9);

    const dot = a.dot(b);
    try std.testing.expect(dot == 32); // 1*4 + 2*5 + 3*6

    const len = a.length();
    try std.testing.expect(@abs(len - 3.741657) < 0.001);
}

test "audio buffer operations" {
    var buffer = try AudioBuffer.init(std.testing.allocator, .{
        .sample_rate = 44100,
        .channels = .mono,
        .sample_format = .f32,
    }, 100);
    defer buffer.deinit();

    // Set a sample
    buffer.setSampleF32(50, 0, 0.5);
    const retrieved = buffer.getSampleF32(50, 0);
    try std.testing.expect(@abs(retrieved - 0.5) < 0.001);

    // Clear buffer
    buffer.clear();
    const cleared = buffer.getSampleF32(50, 0);
    try std.testing.expect(cleared == 0.0);
}

test "spatial audio calculations" {
    const source_pos = Vec3.init(10, 0, 0);
    const listener_pos = Vec3.init(0, 0, 0);
    const listener_forward = Vec3.init(1, 0, 0); // Facing +X
    const listener_up = Vec3.init(0, 1, 0);

    const pan = calculateStereoPan(source_pos, listener_pos, listener_forward, listener_up);
    try std.testing.expect(@abs(pan - 1.0) < 0.001); // Should be full right

    const attenuation = calculateDistanceAttenuation(10, 1, 100, 1);
    try std.testing.expect(attenuation > 0 and attenuation < 1);
}

test "amplitude conversions" {
    const amplitude = 0.5;
    const db = amplitudeToDb(amplitude);
    const back_to_amplitude = dbToAmplitude(db);

    try std.testing.expect(@abs(back_to_amplitude - amplitude) < 0.001);
}
