//! Portable file metadata helpers.
//!
//! The engine samples use this module to stat arbitrary paths (relative or
//! absolute) and to surface size/mtime data in UIs without pulling platform-
//! specific logic into gameplay code.

const std = @import("std");

// ============================================================================
// Types
// ============================================================================

pub const FileMetadataError = union(enum) {
    invalid_path: struct {
        path: []const u8,
        reason: []const u8,
    },
    file_not_found: struct {
        path: []const u8,
        attempted_location: []const u8,
    },
    permission_denied: struct {
        path: []const u8,
        operation: []const u8,
    },
    system_error: struct {
        path: []const u8,
        underlying_error: []const u8,
    },
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
    if (path.len == 0) return error.InvalidPath;

    const is_abs = std.fs.path.isAbsolute(path);

    if (is_abs) {
        const file = std.fs.openFileAbsolute(path, .{}) catch |err| {
            return switch (err) {
                error.FileNotFound => error.FileNotFound,
                else => error.Unexpected,
            };
        };
        defer file.close();

        const stat = file.stat() catch {
            return error.Unexpected;
        };

        return .{
            .size = @intCast(stat.size),
            .modified_ns = stat.mtime.nanoseconds,
        };
    }

    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        return switch (err) {
            error.FileNotFound => error.FileNotFound,
            error.AccessDenied => error.AccessDenied,
            else => error.Unexpected,
        };
    };
    defer file.close();

    const stat = file.stat() catch {
        return error.Unexpected;
    };

    return .{
        .size = @intCast(stat.size),
        .modified_ns = stat.mtime.nanoseconds,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "FileMetadataError detailed context" {
    const err = FileMetadataError{ .invalid_path = .{
        .path = "",
        .reason = "Empty path provided",
    } };

    try std.testing.expect(std.mem.eql(u8, err.invalid_path.path, ""));
    try std.testing.expect(std.mem.eql(u8, err.invalid_path.reason, "Empty path provided"));
}

test "FileMetadata structure" {
    const meta = FileMetadata{
        .size = 1024,
        .modified_ns = 1234567890000,
    };

    try std.testing.expectEqual(meta.size, 1024);
    try std.testing.expectEqual(meta.modified_ns, 1234567890000);
}
