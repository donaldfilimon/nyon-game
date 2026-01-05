//! Minimal immediate-mode UI helpers built on top of the engine wrappers.
//!
//! This intentionally stays small (no external `raygui` dependency) while still
//! enabling draggable panels, buttons, checkboxes, and sliders for sample tools
//! and the demo game.

const std = @import("std");
const raylib = @import("raylib");

const engine_mod = @import("../engine.zig");
const Color = engine_mod.Color;
const Rectangle = engine_mod.Rectangle;
const Vector2 = engine_mod.Vector2;
const Shapes = engine_mod.Shapes;
const Text = engine_mod.Text;
const config = @import("../config/constants.zig");
const platform = @import("../platform/paths.zig");

// Re-export modules for convenience
pub const widgets = @import("widgets.zig");
pub const panels = @import("panels.zig");
pub const scaling = @import("scaling.zig");

// ============================================================================
// Types
// ============================================================================

pub const UiTheme = enum {
    dark,
    light,
};

pub const FrameInput = struct {
    mouse_pos: Vector2,
    mouse_pressed: bool,
    mouse_down: bool,
    mouse_released: bool,
};

pub const FontSet = struct {
    regular: raylib.Font,
    bold: raylib.Font,
    mono: raylib.Font,
    icon: raylib.Font,

    pub fn init() FontSet {
        return FontSet{
            .regular = std.mem.zeroes(raylib.Font),
            .bold = std.mem.zeroes(raylib.Font),
            .mono = std.mem.zeroes(raylib.Font),
            .icon = std.mem.zeroes(raylib.Font),
        };
    }

    pub fn loadDefault(self: *FontSet) void {
        const default_font = raylib.getFontDefault() catch std.mem.zeroes(raylib.Font);
        self.regular = default_font;
        self.bold = default_font;
        self.mono = default_font;
        self.icon = default_font;
    }

    pub fn loadCustomFonts(self: *FontSet, font_size: i32) void {
        const fallback = raylib.getFontDefault() catch undefined;
        const paths = platform.FontPaths.getSystemFontPaths(std.heap.page_allocator) catch fallback;
        defer {
            for (paths) |p| std.heap.page_allocator.free(p);
            std.heap.page_allocator.free(paths);
        }

        if (paths.len > 0) {
            self.regular = raylib.loadFontEx(paths[0], font_size, null) catch fallback;
        } else {
            self.regular = fallback;
        }
        self.bold = self.regular;
        self.mono = self.regular;
        self.icon = raylib.getFontDefault() catch self.regular;
    }

    pub fn unload(self: FontSet) void {
        const default_font = raylib.getFontDefault() catch std.mem.zeroes(raylib.Font);
        if (self.regular.texture.id != default_font.texture.id) raylib.unloadFont(self.regular);
        if (self.bold.texture.id != default_font.texture.id and self.bold.texture.id != self.regular.texture.id) raylib.unloadFont(self.bold);
        if (self.mono.texture.id != default_font.texture.id and self.mono.texture.id != self.regular.texture.id) raylib.unloadFont(self.mono);
        if (self.icon.texture.id != default_font.texture.id) raylib.unloadFont(self.icon);
    }
};

pub const UiStyle = struct {
    scale: f32 = 1.0,
    fonts: ?FontSet = null,

    font_size: i32 = config.UI.DEFAULT_FONT_SIZE,
    small_font_size: i32 = config.UI.SMALL_FONT_SIZE,
    padding: i32 = config.UI.DEFAULT_PADDING,
    panel_title_height: i32 = config.UI.PANEL_TITLE_HEIGHT,
    border_width: f32 = 2.0,
    corner_radius: f32 = 6.0,
    shadow_offset: f32 = 4.0,

    panel_bg: Color,
    panel_border: Color,
    panel_shadow: Color,
    text: Color,
    text_muted: Color,
    accent: Color,
    accent_hover: Color,
    accent_pressed: Color,

    pub fn fromTheme(theme: UiTheme, opacity: u8, scale: f32) UiStyle {
        const clamped_scale = scaling.UiScale.clamp(scale);

        const base_font: i32 = @intFromFloat(std.math.round(@as(f32, @floatFromInt(config.UI.DEFAULT_FONT_SIZE)) * clamped_scale));
        const small_font: i32 = @intFromFloat(std.math.round(@as(f32, @floatFromInt(config.UI.SMALL_FONT_SIZE)) * clamped_scale));
        const pad: i32 = @intFromFloat(std.math.round(16.0 * clamped_scale));
        const title_h: i32 = @intFromFloat(std.math.round(36.0 * clamped_scale));

        return switch (theme) {
            .dark => .{
                .scale = clamped_scale,
                .font_size = base_font,
                .small_font_size = small_font,
                .padding = pad,
                .panel_title_height = title_h,
                .border_width = 1.5,
                .corner_radius = 8.0,
                .shadow_offset = 4.0,
                .panel_bg = Color{ .r = 24, .g = 24, .b = 28, .a = opacity },
                .panel_border = Color{ .r = 60, .g = 60, .b = 70, .a = 255 },
                .panel_shadow = Color{ .r = 0, .g = 0, .b = 0, .a = 80 },
                .text = Color{ .r = 240, .g = 240, .b = 250, .a = 255 },
                .text_muted = Color{ .r = 160, .g = 160, .b = 175, .a = 255 },
                .accent = Color{ .r = 100, .g = 180, .b = 255, .a = 255 },
                .accent_hover = Color{ .r = 130, .g = 200, .b = 255, .a = 255 },
                .accent_pressed = Color{ .r = 80, .g = 160, .b = 235, .a = 255 },
            },
            .light => .{
                .scale = clamped_scale,
                .font_size = base_font,
                .small_font_size = small_font,
                .padding = pad,
                .panel_title_height = title_h,
                .border_width = 1.5,
                .corner_radius = 8.0,
                .shadow_offset = 4.0,
                .panel_bg = Color{ .r = 250, .g = 250, .b = 252, .a = opacity },
                .panel_border = Color{ .r = 200, .g = 200, .b = 210, .a = 255 },
                .panel_shadow = Color{ .r = 0, .g = 0, .b = 0, .a = 50 },
                .text = Color{ .r = 25, .g = 25, .b = 35, .a = 255 },
                .text_muted = Color{ .r = 120, .g = 120, .b = 135, .a = 255 },
                .accent = Color{ .r = 40, .g = 120, .b = 220, .a = 255 },
                .accent_hover = Color{ .r = 65, .g = 150, .b = 245, .a = 255 },
                .accent_pressed = Color{ .r = 25, .g = 100, .b = 200, .a = 255 },
            },
        };
    }
};

pub const PanelId = enum(u8) {
    hud,
    settings,
};

pub const PanelConfig = struct {
    rect: Rectangle,
    visible: bool = true,
};

pub const FontConfig = struct {
    use_system_font: bool = true,
    font_path: ?[]const u8 = null,
    font_size: i32 = config.UI.DEFAULT_FONT_SIZE,
    title_font_size: i32 = config.UI.TITLE_FONT_SIZE,
    small_font_size: i32 = config.UI.SMALL_FONT_SIZE,
    dpi_scale: f32 = 1.0,

    pub fn effectiveFontSize(self: FontConfig, base_size: i32) i32 {
        return @intFromFloat(@as(f32, @floatFromInt(base_size)) * self.dpi_scale);
    }
};

pub const GameSettings = struct {
    master_volume: f32 = 1.0,
    music_volume: f32 = 0.8,
    sfx_volume: f32 = 1.0,
    audio_enabled: bool = true,
    show_fps: bool = true,
    vsync: bool = true,
    fullscreen: bool = false,
    target_fps: u32 = 60,
    high_contrast: bool = false,
    reduced_motion: bool = false,
    large_text: bool = false,
    debug_mode: bool = false,
    show_performance: bool = false,
};

pub const UiConfig = struct {
    version: u32 = 2,
    theme: UiTheme = .dark,
    opacity: u8 = 180,
    scale: f32 = 1.0,
    font: FontConfig = .{},
    game: GameSettings = .{},
    hud: PanelConfig = .{
        .rect = Rectangle{ .x = 10, .y = 10, .width = 320, .height = 240 },
        .visible = true,
    },
    settings: PanelConfig = .{
        .rect = Rectangle{ .x = 10, .y = 270, .width = 380, .height = 380 },
        .visible = true,
    },

    pub const DEFAULT_PATH = "nyon_ui.json";

    pub fn loadOrDefault(allocator: std.mem.Allocator, path: []const u8) UiConfig {
        return UiConfig.load(allocator, path) catch |err| {
            std.log.warn("Failed to load UI config from '{s}': {}, using defaults", .{ path, err });
            return UiConfig{};
        };
    }

    pub fn load(allocator: std.mem.Allocator, path: []const u8) !UiConfig {
        const file = try @import("std").fs.cwd().openFile(path, .{ .mode = .read_only });
        defer file.close();
        const file_bytes = try file.reader().readAllAlloc(allocator, 256 * 1024);

        var parsed: std.json.Parsed(UiConfig) = try std.json.parseFromSlice(UiConfig, allocator, file_bytes, .{
            .ignore_unknown_fields = true,
        });
        defer parsed.deinit();

        var cfg = parsed.value;
        cfg.sanitize();
        return cfg;
    }

    pub fn save(self: *const UiConfig, allocator: std.mem.Allocator, path: []const u8) !void {
        _ = allocator;
        var file = try @import("std").fs.cwd().createFile(path, .{ .truncate = true });
        defer file.close();

        var buffer: [4096]u8 = undefined;
        var writer = file.writer(&buffer);
        try std.json.Stringify.value(self.*, .{ .whitespace = .indent_2 }, &writer.interface);
        try writer.interface.flush();
    }

    pub fn sanitize(self: *UiConfig) void {
        if (self.scale < 0.6) self.scale = 0.6;
        if (self.scale > 2.5) self.scale = 2.5;
        if (self.hud.rect.width < 220) self.hud.rect.width = 220;
        if (self.settings.rect.width < 220) self.settings.rect.width = 220;
        if (self.hud.rect.height < 140) self.hud.rect.height = 140;
        if (self.settings.rect.height < 160) self.settings.rect.height = 160;
    }
};

pub const PanelResult = struct {
    dragged: bool = false,
    clicked: bool = false,
};

// ============================================================================
// UI Context
// ============================================================================

pub const UiContext = struct {
    style: UiStyle,
    input: FrameInput = .{
        .mouse_pos = Vector2{ .x = 0, .y = 0 },
        .mouse_pressed = false,
        .mouse_down = false,
        .mouse_released = false,
    },

    hot_id: u64 = 0,
    active_id: u64 = 0,
    drag_offset: Vector2 = Vector2{ .x = 0, .y = 0 },
    resize_start_mouse: Vector2 = Vector2{ .x = 0, .y = 0 },
    resize_start_rect: Rectangle = Rectangle{ .x = 0, .y = 0, .width = 0, .height = 0 },

    pub fn beginFrame(self: *UiContext, input: FrameInput, style: UiStyle) void {
        self.input = input;
        self.style = style;
        if (self.style.fonts == null) {
            self.style.fonts = FontSet.init();
        }
        if (self.style.fonts.?.regular.texture.id == 0) {
            self.style.fonts.?.loadDefault();
        }
        self.hot_id = 0;
    }

    pub fn getStyle(self: UiContext) UiStyle {
        var style = self.style;
        if (style.fonts == null) {
            style.fonts = FontSet.init();
        }
        if (style.fonts.?.regular.texture.id == 0) {
            style.fonts.?.loadDefault();
        }
        return style;
    }

    pub fn endFrame(_: *UiContext) void {}

    pub fn makeId(prefix: []const u8, extra: []const u8) u64 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(prefix);
        hasher.update(extra);
        return hasher.final();
    }

    fn isMouseOverRect(self: *const UiContext, rect: Rectangle) bool {
        const mx = self.input.mouse_pos.x;
        const my = self.input.mouse_pos.y;
        return mx >= rect.x and my >= rect.y and mx <= rect.x + rect.width and my <= rect.y + rect.height;
    }

    pub fn drawPanel(self: *UiContext, rect: Rectangle, title: [:0]const u8, highlight: bool) void {
        const radius = self.style.corner_radius;
        const bg_color = if (highlight) self.style.accent else self.style.panel_bg;

        Shapes.drawRectangleRounded(rect, radius / std.math.min(rect.width, rect.height), 8, bg_color);
        Shapes.drawRectangleRoundedLinesEx(rect, radius / std.math.min(rect.width, rect.height), 8, self.style.border_width, self.style.panel_border);

        const title_color = if (highlight) self.style.accent_hover else self.style.text;
        const title_y: i32 = @as(i32, @intFromFloat(rect.y)) + @divTrunc(self.style.padding, 2);
        const title_x: i32 = @as(i32, @intFromFloat(rect.x)) + self.style.padding;
        Text.draw(title, title_x, title_y, self.style.small_font_size, title_color);
    }

    pub fn panel(self: *UiContext, id: PanelId, rect: *Rectangle, title: [:0]const u8, draggable: bool) PanelResult {
        const title_bar = Rectangle{
            .x = rect.x,
            .y = rect.y,
            .width = rect.width,
            .height = @floatFromInt(self.style.panel_title_height),
        };

        const panel_id: u64 = @intFromEnum(id) + 1;
        const over_title = self.isMouseOverRect(title_bar);
        const highlight = over_title and draggable;

        if (draggable and over_title and self.input.mouse_pressed) {
            self.active_id = panel_id;
            self.drag_offset = Vector2{ .x = self.input.mouse_pos.x - rect.x, .y = self.input.mouse_pos.y - rect.y };
        }

        var result = PanelResult{};
        if (draggable and self.active_id == panel_id and self.input.mouse_down) {
            rect.x = self.input.mouse_pos.x - self.drag_offset.x;
            rect.y = self.input.mouse_pos.y - self.drag_offset.y;
            result.dragged = true;
        }

        if (over_title and self.input.mouse_pressed) {
            result.clicked = true;
        }

        self.drawPanel(rect.*, title, highlight);
        return result;
    }

    pub fn resizeHandle(
        self: *UiContext,
        panel_id: PanelId,
        rect: *Rectangle,
        min_width: f32,
        min_height: f32,
    ) bool {
        const handle_size: f32 = @floatFromInt(@max(12, @divTrunc(self.style.panel_title_height, 2)));
        const handle_rect = Rectangle{
            .x = rect.x + rect.width - handle_size,
            .y = rect.y + rect.height - handle_size,
            .width = handle_size,
            .height = handle_size,
        };

        const id: u64 = 1000 + @as(u64, @intFromEnum(panel_id));
        const hovered = self.isMouseOverRect(handle_rect);
        if (hovered) self.hot_id = id;

        if (hovered and self.input.mouse_pressed) {
            self.active_id = id;
            self.resize_start_mouse = self.input.mouse_pos;
            self.resize_start_rect = rect.*;
        }

        var changed = false;
        if (self.active_id == id and self.input.mouse_down) {
            const dx = self.input.mouse_pos.x - self.resize_start_mouse.x;
            const dy = self.input.mouse_pos.y - self.resize_start_mouse.y;
            rect.width = self.resize_start_rect.width + dx;
            rect.height = self.resize_start_rect.height + dy;

            if (rect.width < min_width) rect.width = min_width;
            if (rect.height < min_height) rect.height = min_height;
            changed = true;
        }

        const handle_color = if (hovered or self.active_id == id) self.style.accent_hover else self.style.accent;
        Shapes.drawRectangleRec(handle_rect, handle_color);
        Shapes.drawRectangleLinesEx(handle_rect, self.style.border_width, self.style.panel_border);
        return changed;
    }

    pub fn button(self: *UiContext, id: u64, rect: Rectangle, label: [:0]const u8) bool {
        return widgets.button(self, id, rect, label);
    }

    pub fn checkbox(self: *UiContext, id: u64, rect: Rectangle, label: [:0]const u8, value: *bool) bool {
        return widgets.checkbox(self, id, rect, label, value);
    }

    pub fn sliderFloat(self: *UiContext, id: u64, rect: Rectangle, label: [:0]const u8, value: *f32, min: f32, max: f32) bool {
        return widgets.sliderFloat(self, id, rect, label, value, min, max);
    }
};
