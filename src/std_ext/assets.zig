//! Asset Loading Utilities for Game Engine Development
//!

const std = @import("std");

/// Asset loader for common file types
pub const AssetLoader = struct {
    allocator: std.mem.Allocator,
    cache: std.StringHashMap([]u8),
    base_path: []const u8,

    pub fn init(allocator: std.mem.Allocator, base_path: []const u8) !AssetLoader {
        const path_copy = try allocator.dupe(u8, base_path);
        return AssetLoader{
            .allocator = allocator,
            .cache = std.StringHashMap([]u8).init(allocator),
            .base_path = path_copy,
        };
    }

    pub fn deinit(self: *AssetLoader) void {
        var iter = self.cache.valueIterator();
        while (iter.next()) |data| {
            self.allocator.free(data.*);
        }
        self.cache.deinit();
        self.allocator.free(self.base_path);
    }

    pub fn load(self: *AssetLoader, path: []const u8) ![]u8 {
        // Check cache first
        if (self.cache.get(path)) |cached| {
            return self.allocator.dupe(u8, cached.*);
        }

        // Build full path
        var full_path: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const full = try std.fs.path.join(&full_path, &[_][]const u8{ self.base_path, path });

        // Read file
        const file = try std.fs.cwd().openFile(full, .{});
        defer file.close();

        const stat = try file.stat();
        const data = try self.allocator.alloc(u8, @intCast(stat.size));
        errdefer self.allocator.free(data);

        const bytes_read = try file.readAll(data);
        if (bytes_read != stat.size) return error.IncompleteRead;

        // Cache it
        try self.cache.put(path, data);
        // Return a copy that the caller must free
        // Note: The original data remains in the cache and will be freed in deinit()
        return self.allocator.dupe(u8, data);
    }

    pub fn loadText(self: *AssetLoader, path: []const u8) ![]const u8 {
        const data = try self.load(path);
        return @as([]const u8, data);
    }

    pub fn unload(self: *AssetLoader, path: []const u8) void {
        if (self.cache.fetchRemove(path)) |entry| {
            self.allocator.free(entry.value);
        }
    }

    pub fn clearCache(self: *AssetLoader) void {
        var iter = self.cache.valueIterator();
        while (iter.next()) |data| {
            self.allocator.free(data.*);
        }
        self.cache.clearRetainingCapacity();
    }
};

/// Asset metadata
pub const AssetMetadata = struct {
    path: []const u8,
    size: usize,
    modified_time: i128,
    hash: [32]u8,

    pub fn fromFile(allocator: std.mem.Allocator, path: []const u8) !AssetMetadata {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const stat = try file.stat();
        const hash = computeFileHash(file);

        return AssetMetadata{
            .path = try allocator.dupe(u8, path),
            .size = @intCast(stat.size),
            .modified_time = stat.mtime.nanoseconds,
            .hash = hash,
        };
    }
};

fn computeFileHash(file: std.fs.File) [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    var buffer: [4096]u8 = undefined;

    while (true) {
        const bytes = file.read(&buffer) catch return undefined[0..0].*;
        if (bytes == 0) break;
        hasher.update(buffer[0..bytes]);
    }

    return hasher.finalResult();
}

/// Hot reload watcher for assets
pub const AssetWatcher = struct {
    paths: std.StringHashMap(i128),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) AssetWatcher {
        return AssetWatcher{
            .paths = std.StringHashMap(i128).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AssetWatcher) void {
        self.paths.deinit();
    }

    pub fn watch(self: *AssetWatcher, path: []const u8) !void {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const stat = try file.stat();
        const path_copy = try self.allocator.dupe(u8, path);
        try self.paths.put(path_copy, stat.mtime.nanoseconds);
    }

    pub fn checkChanged(self: *AssetWatcher, path: []const u8) !bool {
        const file = try std.fs.cwd().openFile(path, .{}) catch return false;
        defer file.close();

        const stat = try file.stat();
        const current_time = stat.mtime.nanoseconds;

        if (self.paths.get(path)) |last_time| {
            if (current_time > last_time) {
                self.paths.put(path, current_time) catch {};
                return true;
            }
        } else {
            try self.watch(path);
        }
        return false;
    }
};
