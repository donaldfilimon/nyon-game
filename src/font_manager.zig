//! Font management system for Nyon Game Engine.

const std = @import("std");
const raylib = @import("raylib");
const ui_mod = @import("ui/ui.zig");
const platform = @import("platform/paths.zig");
const config = @import("config/constants.zig");

pub const FontManager = struct {
    allocator: std.mem.Allocator,
    fonts: std.StringHashMap(raylib.Font),
    system_fonts: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) FontManager {
        var self = FontManager{
            .allocator = allocator,
            .fonts = std.StringHashMap(raylib.Font).init(allocator),
            .system_fonts = std.StringHashMap([]const u8).init(allocator),
        };
        self.initSystemFonts();
        return self;
    }

    pub fn deinit(self: *FontManager) void {
        var font_iter = self.fonts.iterator();
        while (font_iter.next()) |entry| {
            if (entry.value_ptr.glyphCount > 0) {
                raylib.unloadFont(entry.value_ptr.*);
            }
            self.allocator.free(entry.key_ptr.*);
        }
        self.fonts.deinit();

        var sys_iter = self.system_fonts.iterator();
        while (sys_iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.system_fonts.deinit();
    }

    fn initSystemFonts(self: *FontManager) void {
        const font_paths = platform.FontPaths.getSystemFontPaths(self.allocator) catch return;
        defer {
            for (font_paths) |path| {
                self.allocator.free(path);
            }
            self.allocator.free(font_paths);
        }

        for (font_paths) |path| {
            const path_z = self.allocator.dupeZ(u8, path) catch continue;
            defer self.allocator.free(path_z);

            if (raylib.fileExists(path_z)) {
                const path_copy = self.allocator.dupe(u8, path) catch {
                    std.log.warn("Failed to duplicate font path '{s}', skipping", .{path});
                    continue;
                };
                self.system_fonts.put("sans-serif", path_copy) catch {
                    self.allocator.free(path_copy);
                    std.log.warn("Failed to store font path '{s}' in cache, skipping", .{path});
                    continue;
                };
                break;
            }
        }
    }

    pub fn loadFont(self: *FontManager, name: []const u8) !raylib.Font {
        if (self.fonts.get(name)) |font| {
            return font;
        }

        var font_path: ?[]const u8 = null;
        if (self.system_fonts.get(name)) |path| {
            font_path = path;
        } else if (self.system_fonts.get("sans-serif")) |path| {
            font_path = path;
        }

        const font = if (font_path) |path| {
            raylib.loadFontEx(path, config.UI.DEFAULT_FONT_SIZE, null) catch {
                raylib.getFontDefault() catch undefined;
            };
        } else {
            raylib.getFontDefault() catch undefined;
        };

        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);

        try self.fonts.put(name_copy, font);
        return font;
    }

    pub fn getFont(self: *FontManager, name: []const u8) ?raylib.Font {
        return self.fonts.get(name);
    }
};
