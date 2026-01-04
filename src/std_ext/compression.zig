//! Compression Utilities for Game Engine Development
//!

const std = @import("std");

/// Compress data using zlib
pub fn compressZlib(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    var compressed = std.ArrayList(u8).init(allocator);
    errdefer compressed.deinit();

    var compressor = std.compress.zlib.compressor(compressed.writer(), .{}) catch {
        return error.CompressionFailed;
    };
    defer compressor.deinit() catch {};

    compressor.writer().writeAll(data) catch {
        return error.CompressionFailed;
    };
    compressor.finish() catch {
        return error.CompressionFailed;
    };

    return compressed.toOwnedSlice();
}

/// Decompress zlib data
pub fn decompressZlib(allocator: std.mem.Allocator, compressed: []const u8) ![]u8 {
    var decompressed = std.ArrayList(u8).init(allocator);
    errdefer decompressed.deinit();

    var decompressor = std.compress.zlib.decompressor(std.io.fixedBufferStream(compressed).reader(), decompressed.writer(), .{}) catch {
        return error.DecompressionFailed;
    };

    decompressor.decompress() catch {
        return error.DecompressionFailed;
    };

    return decompressed.toOwnedSlice();
}

/// Compress data using gzip
pub fn compressGzip(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    var compressed = std.ArrayList(u8).init(allocator);
    errdefer compressed.deinit();

    var compressor = std.compress.gzip.compressor(compressed.writer(), .{}) catch {
        return error.CompressionFailed;
    };
    defer compressor.deinit() catch {};

    compressor.writer().writeAll(data) catch {
        return error.CompressionFailed;
    };
    compressor.finish() catch {
        return error.CompressionFailed;
    };

    return compressed.toOwnedSlice();
}

/// Decompress gzip data
pub fn decompressGzip(allocator: std.mem.Allocator, compressed: []const u8) ![]u8 {
    var decompressed = std.ArrayList(u8).init(allocator);
    errdefer decompressed.deinit();

    var decompressor = std.compress.gzip.decompressor(std.io.fixedBufferStream(compressed).reader(), decompressed.writer(), .{}) catch {
        return error.DecompressionFailed;
    };

    decompressor.decompress() catch {
        return error.DecompressionFailed;
    };

    return decompressed.toOwnedSlice();
}

/// Simple LZ4-style delta compression for consecutive data
pub fn deltaCompress(allocator: std.mem.Allocator, previous: []const u8, current: []const u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    // Write the length of current data
    try result.appendSlice(std.mem.asBytes(&current.len));

    const min_len = @min(previous.len, current.len);
    var i: usize = 0;

    // Find unchanged prefix
    while (i < min_len and previous[i] == current[i]) : (i += 1) {}

    try result.appendSlice(std.mem.asBytes(&i));

    // Write the rest
    if (i < current.len) {
        try result.appendSlice(current[i..]);
    }

    return result.toOwnedSlice();
}

/// Delta decompression
pub fn deltaDecompress(allocator: std.mem.Allocator, previous: []const u8, compressed: []const u8) ![]u8 {
    if (compressed.len < 8) return error.InvalidData;

    const current_len = std.mem.readIntLittle(usize, compressed[0..8]);
    const prefix_len = std.mem.readIntLittle(usize, compressed[8..16]);

    var result = try allocator.alloc(u8, current_len);
    errdefer allocator.free(result);

    // Copy prefix from previous
    @memcpy(result[0..prefix_len], previous[0..prefix_len]);

    // Copy remaining from compressed data
    if (prefix_len < current_len) {
        const rest_start = 16;
        const rest_len = current_len - prefix_len;
        @memcpy(result[prefix_len..], compressed[rest_start .. rest_start + rest_len]);
    }

    return result;
}
