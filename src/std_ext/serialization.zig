//! Serialization Utilities for Game Engine Development
//!

const std = @import("std");

/// JSON-based game state serializer
pub const JsonSerializer = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) JsonSerializer {
        return JsonSerializer{ .allocator = allocator };
    }

    pub fn serialize(self: *const JsonSerializer, value: anytype) ![]u8 {
        var buffer = try std.ArrayList(u8).initCapacity(self.allocator, 0);
        try buffer.print(self.allocator, "{f}", .{std.json.fmt(value, .{})});
        return buffer.toOwnedSlice(self.allocator);
    }

    pub fn deserialize(self: *const JsonSerializer, comptime T: type, data: []const u8) !T {
        const parsed = try std.json.parseFromSlice(T, self.allocator, data, .{});
        defer parsed.deinit();
        return parsed.value;
    }

    pub fn serializeToFile(self: *const JsonSerializer, value: anytype, path: []const u8) !void {
        const json = try self.serialize(value);
        defer self.allocator.free(json);

        const file = try std.Io.Dir.cwd().createFile(path, .{}) catch {
            return error.FileCreationFailed;
        };
        defer file.close();

        try file.writeAll(json);
    }

    pub fn deserializeFromFile(self: *const JsonSerializer, comptime T: type, path: []const u8) !T {
        const file = try std.Io.Dir.cwd().openFile(path, .{}) catch {
            return error.FileNotFound;
        };
        defer file.close();

        const stat = try file.stat();
        const data = try self.allocator.alloc(u8, @intCast(stat.size));
        defer self.allocator.free(data);

        const bytes_read = try file.readAll(data);
        if (bytes_read != stat.size) return error.IncompleteRead;

        return try self.deserialize(T, data);
    }
};

/// Simple binary writer
pub const BinaryWriter = struct {
    buffer: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) BinaryWriter {
        return BinaryWriter{
            .buffer = std.ArrayList(u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BinaryWriter) void {
        self.buffer.deinit();
    }

    pub fn write(self: *BinaryWriter, value: anytype) !void {
        const bytes = std.mem.asBytes(&value);
        try self.buffer.appendSlice(bytes);
    }

    pub fn writeBytes(self: *BinaryWriter, data: []const u8) !void {
        try self.buffer.appendSlice(data);
    }

    pub fn toOwnedSlice(self: *BinaryWriter) []u8 {
        return self.buffer.toOwnedSlice();
    }
};

/// Simple binary reader
pub const BinaryReader = struct {
    data: []const u8,
    offset: usize,

    pub fn init(data: []const u8) BinaryReader {
        return BinaryReader{ .data = data, .offset = 0 };
    }

    pub fn read(self: *BinaryReader, comptime T: type) !T {
        const size = @sizeOf(T);
        if (self.offset + size > self.data.len) return error.InvalidData;
        const value = std.mem.readIntLittle(T, self.data[self.offset .. self.offset + size]);
        self.offset += size;
        return value;
    }

    pub fn readBytes(self: *BinaryReader, len: usize) ![]const u8 {
        if (self.offset + len > self.data.len) return error.InvalidData;
        const slice = self.data[self.offset .. self.offset + len];
        self.offset += len;
        return slice;
    }

    pub fn remaining(self: *const BinaryReader) []const u8 {
        return self.data[self.offset..];
    }
};

fn computeChecksum(data: []const u8) u32 {
    var checksum: u32 = 0;
    for (data, 0..) |byte, i| {
        checksum ^= @as(u32, byte) << @as(u5, @intCast(i % 4));
    }
    return checksum;
}

/// Save game manager
pub const SaveManager = struct {
    allocator: std.mem.Allocator,
    saves_dir: []const u8,

    pub fn init(allocator: std.mem.Allocator, saves_dir: []const u8) !SaveManager {
        const dir = try allocator.dupe(u8, saves_dir);
        try std.Io.Dir.cwd().makePath(dir);
        return SaveManager{
            .allocator = allocator,
            .saves_dir = dir,
        };
    }

    pub fn deinit(self: *SaveManager) void {
        self.allocator.free(self.saves_dir);
    }

    pub fn save(self: *SaveManager, name: []const u8, data: []const u8) !void {
        var path: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const full_path = try std.fs.path.join(&path, &[_][]const u8{ self.saves_dir, name });

        const file = try std.Io.Dir.cwd().createFile(full_path, .{}) catch {
            return error.FileCreationFailed;
        };
        defer file.close();

        const checksum = computeChecksum(data);
        const version: u32 = 1;
        const timestamp = std.time.timestamp();

        try file.writeAll("NYON");
        try file.writeAll(std.mem.asBytes(&version));
        try file.writeAll(std.mem.asBytes(&timestamp));
        try file.writeAll(std.mem.asBytes(&checksum));
        try file.writeAll(data);
    }

    pub fn load(self: *const SaveManager, name: []const u8, allocator: std.mem.Allocator) ![]u8 {
        var path: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const full_path = try std.fs.path.join(&path, &[_][]const u8{ self.saves_dir, name });

        const file = try std.Io.Dir.cwd().openFile(full_path, .{}) catch {
            return error.FileNotFound;
        };
        defer file.close();

        var magic: [4]u8 = undefined;
        var version: u32 = undefined;
        var timestamp: i64 = undefined;
        var checksum: u32 = undefined;

        try file.readAll(&magic);
        try file.readAll(std.mem.asBytes(&version));
        try file.readAll(std.mem.asBytes(&timestamp));
        try file.readAll(std.mem.asBytes(&checksum));

        const stat = try file.stat();
        const data = try allocator.alloc(u8, @intCast(stat.size - 16));
        errdefer allocator.free(data);

        try file.readAll(data);

        if (checksum != computeChecksum(data)) return error.ChecksumMismatch;

        return data;
    }

    pub fn listSaves(self: *const SaveManager, allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
        var result = std.ArrayList([]const u8).init(allocator);
        errdefer result.deinit();

        const dir = try std.Io.Dir.cwd().openDir(self.saves_dir, .{});
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file) {
                const name = try allocator.dupe(u8, entry.name);
                try result.append(name);
            }
        }

        return result;
    }
};
