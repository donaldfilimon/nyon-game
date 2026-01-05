//! Platform abstraction utilities for Nyon Game Engine.

const std = @import("std");

pub const Platform = enum {
    windows,
    macos,
    linux,
    wasm,
};

pub fn getCurrentPlatform() Platform {
    const os = @import("builtin").os.tag;
    return switch (os) {
        .windows => .windows,
        .macos => .macos,
        .linux => .linux,
        .wasi => .wasm,
        else => .linux,
    };
}

pub fn isCurrentPlatform(comptime p: Platform) bool {
    return getCurrentPlatform() == p;
}

pub const PathUtils = struct {
    pub const Separator = if (isCurrentPlatform(.windows)) '\\' else '/';

    pub fn join(allocator: std.mem.Allocator, parts: []const []const u8) ![]const u8 {
        if (parts.len == 0) return "";
        if (parts.len == 1) return try allocator.dupe(u8, parts[0]);

        var total_len: usize = 0;
        for (parts) |part| total_len += part.len;
        total_len += parts.len - 1;

        const result = try allocator.alloc(u8, total_len);
        var i: usize = 0;
        for (parts) |part| {
            if (i > 0) {
                result[i] = Separator;
                i += 1;
            }
            @memcpy(result[i..][0..part.len], part);
            i += part.len;
        }
        return result;
    }

    pub fn dirname(path: []const u8) []const u8 {
        if (path.len == 0) return "";
        var last_sep: usize = 0;
        var i = path.len;
        while (i > 0) : (i -= 1) {
            if (path[i - 1] == Separator or path[i - 1] == if (Separator == '\\') '/' else '\\') {
                last_sep = i - 1;
                break;
            }
        }
        return path[0..last_sep];
    }

    pub fn basename(path: []const u8) []const u8 {
        if (path.len == 0) return "";
        var i = path.len;
        while (i > 0) : (i -= 1) {
            if (path[i - 1] == Separator or path[i - 1] == if (Separator == '\\') '/' else '\\') {
                return path[i..];
            }
        }
        return path;
    }
};

pub const FontPaths = struct {
    pub fn getSystemFontPaths(allocator: std.mem.Allocator) ![][]const u8 {
        const platform = getCurrentPlatform();
        const fonts: []const []const u8 = switch (platform) {
            .windows => &[_][]const u8{
                "C:\\Windows\\Fonts\\segoeui.ttf",
                "C:\\Windows\\Fonts\\arial.ttf",
                "C:\\Windows\\Fonts\\tahoma.ttf",
                "C:\\Windows\\Fonts\\calibri.ttf",
            },
            .macos => &[_][]const u8{
                "/System/Library/Fonts/Helvetica.ttc",
                "/Library/Fonts/Arial.ttf",
            },
            .linux => &[_][]const u8{
                "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            },
            .wasm => &[_][]const u8{},
        };

        var result = try allocator.alloc([]const u8, fonts.len);
        for (0..fonts.len) |idx| {
            result[idx] = try allocator.dupe(u8, fonts[idx]);
        }
        return result;
    }

    pub fn getDefaultFontName() []const u8 {
        return switch (getCurrentPlatform()) {
            .windows => "segoeui",
            .macos => "helvetica",
            .linux => "dejavu sans",
            .wasm => "default",
        };
    }
};

pub const ExecutablePaths = struct {
    pub fn getExeDir(allocator: std.mem.Allocator) ![]const u8 {
        return std.fs.selfExePathAlloc(allocator);
    }

    pub fn getBaseDir(allocator: std.mem.Allocator) ![]const u8 {
        const exe_path = try getExeDir(allocator);
        defer allocator.free(exe_path);
        return allocator.dupe(u8, PathUtils.dirname(exe_path));
    }

    pub fn getConfigDir(allocator: std.mem.Allocator) ![]const u8 {
        const platform = getCurrentPlatform();
        return switch (platform) {
            .windows => {
                const appdata = std.os.getenv("APPDATA") orelse ".";
                return try allocator.dupe(u8, appdata);
            },
            .macos => {
                const home = std.os.getenv("HOME") orelse ".";
                return try std.fs.path.join(allocator, &.{ home, "Library/Application Support" });
            },
            .linux => {
                const xdg = std.os.getenv("XDG_CONFIG_HOME") orelse "";
                if (xdg.len > 0) {
                    return try allocator.dupe(u8, xdg);
                }
                const home = std.os.getenv("HOME") orelse ".";
                return try std.fs.path.join(allocator, &.{ home, ".config" });
            },
            .wasm => {
                return try allocator.dupe(u8, "/config");
            },
        };
    }

    pub fn getSaveDir(allocator: std.mem.Allocator) ![]const u8 {
        const base = try getBaseDir(allocator);
        defer allocator.free(base);
        return try std.fs.path.join(allocator, &.{ base, "saves" });
    }
};

test "PathUtils basename" {
    const test_path = if (isCurrentPlatform(.windows)) "C:\\Users\\test\\file.txt" else "/home/test/file.txt";
    try std.testing.expectEqualStrings("file.txt", PathUtils.basename(test_path));
}
