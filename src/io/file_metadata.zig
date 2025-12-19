//! Portable file metadata helpers.
//!
//! The engine samples use this module to stat arbitrary paths (relative or
//! absolute) and to surface size/mtime data in UIs without pulling platform-
//! specific logic into gameplay code.

const std = @import("std");

// ============================================================================
// Types
// ============================================================================

pub const FileMetadataError = error{
    InvalidPath,
};

pub const FileMetadata = struct {
    size: usize,
    modified_ns: ?i96,
};

// ============================================================================
// API
// ============================================================================

/// Read file size and modification time for `path`.
pub fn get(path: []const u8) !FileMetadata {
    if (path.len == 0) return FileMetadataError.InvalidPath;

    const is_abs = std.fs.path.isAbsolute(path);

    if (is_abs) {
        const file = try std.fs.openFileAbsolute(path, .{});
        defer file.close();
        const stat = try file.stat();
        return .{
            .size = @intCast(stat.size),
            .modified_ns = stat.mtime.nanoseconds,
        };
    }

    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    return .{
        .size = @intCast(stat.size),
        .modified_ns = stat.mtime.nanoseconds,
    };
}
