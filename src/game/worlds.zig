//! World save management for the Minecraft-style flow.
//!
//! A "world" is a directory under `saves/` with a `world.json` metadata file.
//! This module provides helpers to list/create/update worlds.

const std = @import("std");

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
};

// ============================================================================
// Public API
// ============================================================================

pub fn ensureSavesDir() !void {
    try std.fs.cwd().makePath(SAVES_DIR);
}

pub fn listWorlds(allocator: std.mem.Allocator) ![]WorldEntry {
    try ensureSavesDir();

    var dir = try std.fs.cwd().openDir(SAVES_DIR, .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();
    var worlds = std.ArrayList(WorldEntry).initCapacity(allocator, 0) catch unreachable;
    errdefer {
        for (worlds.items) |*entry| entry.deinit();
        worlds.deinit(allocator);
    }

    while (try it.next()) |entry| {
        if (entry.kind != .directory) continue;
        if (std.mem.eql(u8, entry.name, ".") or std.mem.eql(u8, entry.name, "..")) continue;

        if (loadWorldMeta(allocator, &dir, entry.name)) |meta| {
            const folder_copy = try allocator.dupe(u8, entry.name);
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
            // Ignore invalid worlds for now.
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

pub fn createWorld(allocator: std.mem.Allocator, display_name: []const u8) !WorldEntry {
    try ensureSavesDir();

    const cleaned = try sanitizeName(allocator, display_name);
    defer allocator.free(cleaned);

    const unique_folder = try uniquifyFolderName(allocator, cleaned);
    errdefer allocator.free(unique_folder);

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const sub_path = try std.fmt.bufPrint(&path_buf, "{s}\\{s}", .{ SAVES_DIR, unique_folder });
    var world_dir = try std.fs.cwd().makeOpenPath(sub_path, .{});
    defer world_dir.close();

    const now_ns: i64 = @intCast(std.time.nanoTimestamp());

    const meta = WorldMeta{
        .version = WORLD_VERSION,
        .name = try allocator.dupe(u8, display_name),
        .created_ns = now_ns,
        .last_played_ns = now_ns,
        .best_score = 0,
        .best_time_ms = null,
    };
    errdefer allocator.free(meta.name);

    try saveWorldMeta(&world_dir, meta);

    return .{
        .allocator = allocator,
        .folder = unique_folder,
        .meta = meta,
    };
}

pub fn touchWorld(allocator: std.mem.Allocator, folder: []const u8, best_score: ?u32, best_time_ms: ?u32) !void {
    var dir = try std.fs.cwd().openDir(SAVES_DIR, .{ .iterate = false });
    defer dir.close();

    var world_dir = try dir.openDir(folder, .{});
    defer world_dir.close();

    var meta = try loadWorldMeta(allocator, &dir, folder);
    defer allocator.free(meta.name);

    meta.last_played_ns = @intCast(std.time.nanoTimestamp());
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

    try saveWorldMeta(&world_dir, meta);
}

// ============================================================================
// Internals
// ============================================================================

fn loadWorldMeta(allocator: std.mem.Allocator, saves_dir: *std.fs.Dir, folder: []const u8) !WorldMeta {
    var world_dir = try saves_dir.openDir(folder, .{});
    defer world_dir.close();

    const bytes = try world_dir.readFileAlloc(WORLD_META_FILE, allocator, std.Io.Limit.limited(128 * 1024));
    defer allocator.free(bytes);

    const Parsed = std.json.Parsed(WorldMeta);
    var parsed: Parsed = try std.json.parseFromSlice(WorldMeta, allocator, bytes, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    if (parsed.value.version == 0) return WorldError.WorldMetaInvalid;
    return parsed.value;
}

fn saveWorldMeta(world_dir: *std.fs.Dir, meta: WorldMeta) !void {
    var file = try world_dir.createFile(WORLD_META_FILE, .{ .truncate = true });
    defer file.close();

    var buffer: [4096]u8 = undefined;
    var writer = file.writer(&buffer);
    try std.json.Stringify.value(meta, .{ .whitespace = .indent_2 }, &writer.interface);
    try writer.interface.flush();
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
    try ensureSavesDir();

    var dir = try std.fs.cwd().openDir(SAVES_DIR, .{ .iterate = true });
    defer dir.close();

    if (!dirExists(&dir, base)) {
        return allocator.dupe(u8, base);
    }

    var idx: u32 = 2;
    while (idx < 10000) : (idx += 1) {
        const candidate = try std.fmt.allocPrint(allocator, "{s}_{d}", .{ base, idx });
        errdefer allocator.free(candidate);
        if (!dirExists(&dir, candidate)) {
            return candidate;
        }
        allocator.free(candidate);
    }

    return allocator.dupe(u8, base);
}

fn dirExists(dir: *std.fs.Dir, name: []const u8) bool {
    if (dir.openDir(name, .{}) catch null) |d| {
        d.close();
        return true;
    }
    return false;
}
