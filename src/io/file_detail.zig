//! Lightweight file information used by HUDs and sample tools.
//!
//! This module stores a path in a fixed buffer to avoid allocations on the hot
//! path. Metadata like size and modification time are optional.

const std = @import("std");

// ============================================================================
// File Detail
// ============================================================================

/// Fixed-capacity file detail record used by UIs.
pub const FileDetail = struct {
    buffer: [512]u8 = [_]u8{0} ** 512,
    len: usize = 0,

    size: usize = 0,
    modified_ns: i96 = 0,
    has_time: bool = false,

    /// Reset the record to an empty state.
    pub fn clear(self: *FileDetail) void {
        self.len = 0;
        self.buffer[0] = 0;
        self.size = 0;
        self.modified_ns = 0;
        self.has_time = false;
    }

    /// Store the path and metadata.
    pub fn set(self: *FileDetail, file_path: []const u8, file_size: usize, modified_ns: ?i96) void {
        const max_copy = self.buffer.len - 1;
        const copy_len = if (file_path.len < max_copy) file_path.len else max_copy;
        std.mem.copyForwards(u8, self.buffer[0..copy_len], file_path[0..copy_len]);
        self.buffer[copy_len] = 0;

        self.len = copy_len;
        self.size = file_size;
        if (modified_ns) |ns| {
            self.modified_ns = ns;
            self.has_time = true;
        } else {
            self.modified_ns = 0;
            self.has_time = false;
        }
    }

    /// Returns true if a path is stored.
    pub fn hasFile(self: *const FileDetail) bool {
        return self.len > 0;
    }

    /// Return the stored path without a sentinel.
    pub fn path(self: *const FileDetail) []const u8 {
        return self.buffer[0..self.len];
    }
};
