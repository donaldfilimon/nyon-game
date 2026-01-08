//! World save management for the Minecraft-style flow.
//!
//! A "world" is a directory under `saves/` with a `world.json` metadata file.
//! This module provides helpers to list/create/update worlds.

const std = @import("std");
const raylib = @import("raylib");
const config = @import("../config/constants.zig");

// ============================================================================
// Constants
// ============================================================================

pub const SAVES_DIR: []const u8 = "saves";
pub const WORLD_META_FILE: []const u8 = "world.json";
pub const WORLD_VERSION: u32 = 1;

// ============================================================================
// Types
// ============================================================================

pub const WorldMeta = struct {
    version: u32 = WORLD_VERSION,
    name: []const u8,
    created_ns: i64,
    last_played_ns: i64,
    best_score: u32 = 0,
    best_time_ms: ?u32 = null,
};

pub const WorldEntry = struct {
    allocator: std.mem.Allocator,
    folder: []u8,
    meta: WorldMeta,

    pub fn deinit(self: *WorldEntry) void {
        self.allocator.free(self.folder);
        self.allocator.free(self.meta.name);
        self.* = undefined;
    }

    pub fn dirPathZ(self: *const WorldEntry, buffer: *[std.fs.max_path_bytes:0]u8) ![:0]const u8 {
        return try std.fmt.bufPrintZ(buffer, "{s}\\{s}", .{ SAVES_DIR, self.folder });
    }
};

pub const WorldError = error{
    InvalidName,
    SavesDirMissing,
    WorldMetaMissing,
    WorldMetaInvalid,
    FileWriteError,
};

// ============================================================================
// Public API
// ============================================================================

// ============================================================================
// Public API
// ============================================================================

pub fn ensureSavesDir() !void {
    const saves_dir_z = SAVES_DIR ++ "\x00";
    if (!raylib.directoryExists(saves_dir_z)) {
        _ = raylib.makeDirectory(saves_dir_z);
    }
}

pub fn listWorlds(allocator: std.mem.Allocator) ![]WorldEntry {
    try ensureSavesDir();

    const saves_dir_z = SAVES_DIR ++ "\x00";
    const files = raylib.loadDirectoryFiles(saves_dir_z);
    defer raylib.unloadDirectoryFiles(files);

    var worlds = std.ArrayList(WorldEntry).initCapacity(allocator, 8) catch unreachable;
    errdefer {
        for (worlds.items) |*entry| entry.deinit();
        worlds.deinit(allocator);
    }

    var i: usize = 0;
    while (i < files.count) : (i += 1) {
        const file_path_z = files.paths[i];
        const file_path = std.mem.span(file_path_z);

        // Skip . and ..
        if (std.mem.eql(u8, file_path, ".") or std.mem.eql(u8, file_path, "..")) continue;

        // In raylib, LoadDirectoryFiles returns names relative to the path provided?
        // Or full paths? Raylib docs say "file names".
        // Assuming file names. We need to check if it's a directory?
        // Raylib doesn't have IsDirectory easily exposed without other checks.
        // We'll rely on loadWorldMeta failing if it's not a directory with world.json inside.

        if (loadWorldMeta(allocator, file_path)) |meta| {
            const folder_copy = try allocator.dupe(u8, file_path);
            const meta_name = try allocator.dupe(u8, meta.name);
            try worlds.append(allocator, .{
                .allocator = allocator,
                .folder = folder_copy,
                .meta = .{
                    .version = meta.version,
                    .name = meta_name,
                    .created_ns = meta.created_ns,
                    .last_played_ns = meta.last_played_ns,
                    .best_score = meta.best_score,
                    .best_time_ms = meta.best_time_ms,
                },
            });
        } else |_| {
            // Ignore invalid worlds
        }
    }

    // Sort by last played (descending).
    std.sort.pdq(WorldEntry, worlds.items, {}, struct {
        fn lessThan(_: void, a: WorldEntry, b: WorldEntry) bool {
            return a.meta.last_played_ns > b.meta.last_played_ns;
        }
    }.lessThan);

    return worlds.toOwnedSlice(allocator);
}

pub fn getMostRecentWorld(allocator: std.mem.Allocator) ?WorldEntry {
    const worlds = listWorlds(allocator) catch return null;
    defer {
        for (worlds) |*entry| entry.deinit();
        allocator.free(worlds);
    }
    if (worlds.len == 0) return null;
    const entry = worlds[0];
    return .{
        .allocator = allocator,
        .folder = allocator.dupe(u8, entry.folder) catch return null,
        .meta = .{
            .version = entry.meta.version,
            .name = allocator.dupe(u8, entry.meta.name) catch return null,
            .created_ns = entry.meta.created_ns,
            .last_played_ns = entry.meta.last_played_ns,
            .best_score = entry.meta.best_score,
            .best_time_ms = entry.meta.best_time_ms,
        },
    };
}

pub fn createWorld(allocator: std.mem.Allocator, display_name: []const u8) !WorldEntry {
    try ensureSavesDir();

    const cleaned = try sanitizeName(allocator, display_name);
    defer allocator.free(cleaned);

    const unique_folder = try uniquifyFolderName(allocator, cleaned);
    errdefer allocator.free(unique_folder);

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const sub_path = try std.fmt.bufPrintZ(&path_buf, "{s}/{s}", .{ SAVES_DIR, unique_folder });

    if (!raylib.makeDirectory(sub_path)) {
        // If it fails, maybe it already exists? But uniquify should prevent that.
        // Or maybe permission error.
        return WorldError.SavesDirMissing; // Close enough
    }

    const now_ns: i64 = 0;

    const meta = WorldMeta{
        .version = WORLD_VERSION,
        .name = try allocator.dupe(u8, display_name),
        .created_ns = now_ns,
        .last_played_ns = now_ns,
        .best_score = 0,
        .best_time_ms = null,
    };
    errdefer allocator.free(meta.name);

    try saveWorldMeta(unique_folder, meta, allocator);

    return .{
        .allocator = allocator,
        .folder = unique_folder,
        .meta = meta,
    };
}

pub fn touchWorld(allocator: std.mem.Allocator, folder: []const u8, best_score: ?u32, best_time_ms: ?u32) !void {
    var meta = try loadWorldMeta(allocator, folder);
    defer allocator.free(meta.name);

    meta.last_played_ns = 0;
    if (best_score) |score| {
        if (score > meta.best_score) meta.best_score = score;
    }
    if (best_time_ms) |t| {
        if (meta.best_time_ms) |prev| {
            if (t < prev) meta.best_time_ms = t;
        } else {
            meta.best_time_ms = t;
        }
    }

    try saveWorldMeta(folder, meta, allocator);
}

// ============================================================================
// Internals
// ============================================================================

fn loadWorldMeta(allocator: std.mem.Allocator, folder: []const u8) !WorldMeta {
    var path_buf: [std.fs.max_path_bytes:0]u8 = undefined;
    // Raylib needs null terminated string
    const meta_path = try std.fmt.bufPrintZ(&path_buf, "{s}/{s}/{s}", .{ SAVES_DIR, folder, WORLD_META_FILE });

    const text_ptr = raylib.loadFileText(meta_path);
    if (text_ptr == null) return error.WorldMetaMissing;
    defer raylib.unloadFileText(text_ptr.?);

    const text_slice = std.mem.span(text_ptr.?);

    var parsed = try std.json.parseFromSlice(WorldMeta, allocator, text_slice, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    if (parsed.value.version == 0) return WorldError.WorldMetaInvalid;

    const name_copy = try allocator.dupe(u8, parsed.value.name);
    return WorldMeta{
        .version = parsed.value.version,
        .name = name_copy,
        .created_ns = parsed.value.created_ns,
        .last_played_ns = parsed.value.last_played_ns,
        .best_score = parsed.value.best_score,
        .best_time_ms = parsed.value.best_time_ms,
    };
}

fn saveWorldMeta(folder: []const u8, meta: WorldMeta, allocator: std.mem.Allocator) !void {
    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();
    var write_stream: std.json.Stringify = .{
        .writer = &out.writer,
        .options = .{ .whitespace = .indent_2 },
    };
    try write_stream.write(meta);

    // Create null-terminated version of json content
    const json_z = try allocator.dupeZ(u8, out.written());
    defer allocator.free(json_z);

    var path_buf: [std.fs.max_path_bytes:0]u8 = undefined;
    const meta_path = try std.fmt.bufPrintZ(&path_buf, "{s}/{s}/{s}", .{ SAVES_DIR, folder, WORLD_META_FILE });

    // Save to file using Raylib
    if (!raylib.saveFileText(meta_path, json_z)) {
        return WorldError.FileWriteError;
    }
}

fn sanitizeName(allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    var trimmed = std.mem.trim(u8, name, " \t\r\n");
    if (trimmed.len == 0) return WorldError.InvalidName;

    var buf = std.ArrayList(u8).initCapacity(allocator, trimmed.len) catch unreachable;
    errdefer buf.deinit(allocator);

    for (trimmed) |c| {
        const out: u8 = if (std.ascii.isAlphanumeric(c)) c else if (c == ' ' or c == '-' or c == '_') '_' else 0;
        if (out == 0) continue;
        try buf.append(allocator, std.ascii.toLower(out));
    }

    if (buf.items.len == 0) return WorldError.InvalidName;
    return buf.toOwnedSlice(allocator);
}

fn uniquifyFolderName(allocator: std.mem.Allocator, base: []const u8) ![]u8 {
    // Check base first
    var check_path_buf: [std.fs.max_path_bytes:0]u8 = undefined;
    const base_path = try std.fmt.bufPrintZ(&check_path_buf, "{s}/{s}", .{ SAVES_DIR, base });
    if (!raylib.directoryExists(base_path)) {
        return allocator.dupe(u8, base);
    }

    var idx: u32 = 2;
    while (idx < 10000) : (idx += 1) {
        const candidate = try std.fmt.allocPrint(allocator, "{s}_{d}", .{ base, idx });
        defer allocator.free(candidate);

        const cand_path = try std.fmt.bufPrintZ(&check_path_buf, "{s}/{s}", .{ SAVES_DIR, candidate });

        if (!raylib.directoryExists(cand_path)) {
            return allocator.dupe(u8, candidate);
        }
    }

    return allocator.dupe(u8, base);
}
