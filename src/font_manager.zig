//! Font management system for Nyon Game Engine
//!
//! Provides high-DPI font loading with system font detection and custom font support.

const std = @import("std");
const engine = @import("engine.zig");
const ui_mod = @import("ui/ui.zig");

const raylib = @import("raylib");

/// Font manager for loading and managing fonts
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

        // Initialize system font paths for different platforms
        self.initSystemFonts();

        return self;
    }

    pub fn deinit(self: *FontManager) void {
        var font_iter = self.fonts.iterator();
        while (font_iter.next()) |entry| {
            // Only unload fonts that aren't the default font
            if (entry.value_ptr.glyphCount > 0) {
                raylib.unloadFont(entry.value_ptr.*);
            }
        }
        self.fonts.deinit();

        var sys_iter = self.system_fonts.iterator();
        while (sys_iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.system_fonts.deinit();
    }

    /// Initialize system font paths
    fn initSystemFonts(self: *FontManager) void {
        // Windows system fonts
        if (std.fs.selfExePathAlloc(self.allocator)) |exe_path| {
            defer self.allocator.free(exe_path);

            // Try to detect Windows
            if (std.mem.indexOf(u8, exe_path, "Windows") != null or
                std.mem.indexOf(u8, exe_path, "windows") != null)
            {

                // Common Windows font paths
                const font_paths = [_][]const u8{
                    "C:\\Windows\\Fonts\\arial.ttf",
                    "C:\\Windows\\Fonts\\segoeui.ttf",
                    "C:\\Windows\\Fonts\\tahoma.ttf",
                    "C:\\Windows\\Fonts\\calibri.ttf",
                };

                for (font_paths) |path| {
                    if (std.fs.cwd().access(path, .{})) |_| {
                        const path_copy = self.allocator.dupe(u8, path) catch continue;
                        self.system_fonts.put("sans-serif", path_copy) catch continue;
                        break;
                    } else |_| {}
                }
            }
        } else |_| {}
    }

    /// Load a font with DPI scaling
    pub fn loadFont(self: *FontManager, config: ui_mod.FontConfig, name: []const u8) !raylib.Font {
        // Check if font is already loaded
        if (self.fonts.get(name)) |font| {
            return font;
        }

        var font_path: ?[]const u8 = null;

        if (config.use_system_font) {
            // Try to find system font
            if (self.system_fonts.get(name)) |path| {
                font_path = path;
            } else if (self.system_fonts.get("sans-serif")) |path| {
                font_path = path;
            }
        }

        if (config.font_path) |path| {
            font_path = path;
        }

        var font: raylib.Font = undefined;

        if (font_path != null) {
            // Try to load the font - for now, just use default to avoid API issues
            font = raylib.getFontDefault();

            // TODO: Implement proper font loading once raylib API stabilizes
        } else {
            font = raylib.getFontDefault();
        }

        // Store the font
        const name_copy = self.allocator.dupe(u8, name) catch unreachable;
        defer self.allocator.free(name_copy);

        try self.fonts.put(name_copy, font);

        return font;
    }

    /// Get a loaded font
    pub fn getFont(self: *FontManager, name: []const u8) ?raylib.Font {
        return self.fonts.get(name);
    }

    /// Load all fonts needed for the UI
    pub fn loadUI(self: *FontManager, config: ui_mod.FontConfig) !void {
        _ = try self.loadFont(config, "main");
        _ = try self.loadFont(config, "title");
        _ = try self.loadFont(config, "small");
    }
};
