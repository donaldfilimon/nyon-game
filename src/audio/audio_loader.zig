//! Audio loader for Nyon Game Engine.
//!
//! Provides WAV file loading for audio clips.

const std = @import("std");
const audio_types = @import("types.zig");

/// WAV file header
const WavHeader = extern struct {
    riff: [4]u8, // "RIFF"
    file_size: u32,
    wave: [4]u8, // "WAVE"
    fmt_marker: [4]u8, // "fmt "
    fmt_size: u32,
    format_type: u16,
    channels: u16,
    sample_rate: u32,
    byte_rate: u32,
    block_align: u16,
    bits_per_sample: u16,
};

/// Load a WAV file into an AudioClip
pub fn loadWav(allocator: std.mem.Allocator, path: []const u8) !audio_types.AudioClip {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        std.debug.print("Failed to open WAV file: {s} - {}\n", .{ path, err });
        return error.FileNotFound;
    };
    defer file.close();

    var reader = file.reader();

    // Read header
    var header_bytes: [@sizeOf(WavHeader)]u8 = undefined;
    _ = reader.readAll(&header_bytes) catch |err| {
        std.debug.print("Failed to read WAV header: {}\n", .{err});
        return error.InvalidFormat;
    };
    const header: *const WavHeader = @ptrCast(@alignCast(&header_bytes));

    // Validate header
    if (!std.mem.eql(u8, &header.riff, "RIFF") or !std.mem.eql(u8, &header.wave, "WAVE")) {
        return error.InvalidFormat;
    }

    // Find data chunk
    var data_size: u32 = 0;
    while (true) {
        var chunk_id: [4]u8 = undefined;
        var chunk_size: u32 = undefined;

        _ = reader.readAll(&chunk_id) catch break;
        chunk_size = reader.readInt(u32, .little) catch break;

        if (std.mem.eql(u8, &chunk_id, "data")) {
            data_size = chunk_size;
            break;
        } else {
            // Skip this chunk
            reader.skipBytes(chunk_size, .{}) catch break;
        }
    }

    if (data_size == 0) {
        return error.NoDataChunk;
    }

    // Determine format
    const sample_format: audio_types.SampleFormat = switch (header.bits_per_sample) {
        8 => .u8,
        16 => .i16,
        32 => .f32,
        else => return error.UnsupportedFormat,
    };

    const channel_layout: audio_types.ChannelLayout = switch (header.channels) {
        1 => .mono,
        2 => .stereo,
        6 => .surround_5_1,
        8 => .surround_7_1,
        else => return error.UnsupportedChannelCount,
    };

    const format = audio_types.AudioFormat{
        .sample_rate = header.sample_rate,
        .channels = channel_layout,
        .sample_format = sample_format,
    };

    const frame_count = format.bytesToFrames(data_size);

    // Create buffer and read data
    var buffer = try audio_types.AudioBuffer.init(allocator, format, frame_count);
    errdefer buffer.deinit();

    _ = reader.readAll(buffer.data) catch |err| {
        std.debug.print("Failed to read WAV data: {}\n", .{err});
        return error.ReadFailed;
    };

    // Create clip
    const name = std.fs.path.basename(path);
    return audio_types.AudioClip.init(allocator, name, buffer);
}

/// Load audio from file (auto-detects format)
pub fn loadAudio(allocator: std.mem.Allocator, path: []const u8) !audio_types.AudioClip {
    const ext = std.fs.path.extension(path);
    if (std.mem.eql(u8, ext, ".wav")) {
        return loadWav(allocator, path);
    }
    return error.UnsupportedFormat;
}

/// Audio file information (without loading full data)
pub const AudioFileInfo = struct {
    sample_rate: u32,
    channels: u16,
    bits_per_sample: u16,
    duration_seconds: f32,
    file_size: u64,
};

/// Get information about an audio file without loading it
pub fn getAudioFileInfo(path: []const u8) !AudioFileInfo {
    const file = std.fs.cwd().openFile(path, .{}) catch return error.FileNotFound;
    defer file.close();

    const stat = file.stat() catch return error.StatFailed;
    var reader = file.reader();

    var header_bytes: [@sizeOf(WavHeader)]u8 = undefined;
    _ = reader.readAll(&header_bytes) catch return error.InvalidFormat;
    const header: *const WavHeader = @ptrCast(@alignCast(&header_bytes));

    if (!std.mem.eql(u8, &header.riff, "RIFF")) {
        return error.InvalidFormat;
    }

    const bytes_per_sample = header.bits_per_sample / 8;
    const bytes_per_frame = bytes_per_sample * header.channels;
    const data_size = header.file_size - @sizeOf(WavHeader);
    const frame_count = data_size / bytes_per_frame;
    const duration = @as(f32, @floatFromInt(frame_count)) / @as(f32, @floatFromInt(header.sample_rate));

    return .{
        .sample_rate = header.sample_rate,
        .channels = header.channels,
        .bits_per_sample = header.bits_per_sample,
        .duration_seconds = duration,
        .file_size = stat.size,
    };
}

test "WAV header size" {
    try std.testing.expectEqual(@sizeOf(WavHeader), 36);
}
