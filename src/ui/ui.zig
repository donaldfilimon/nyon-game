//! Raygui-based UI system for Nyon Game Engine.
//!
//! This module wraps raygui controls to provide an easy-to-use immediate-mode
//! GUI API that integrates with the raylib rendering pipeline.

const std = @import("std");
const raygui = @import("raygui");
const raylib = @import("raylib");
const config = @import("../config/constants.zig");

pub const Rectangle = raygui.Rectangle;
pub const Color = raygui.Color;
pub const Vector2 = extern struct {
    x: f32,
    y: f32,
};

pub const UiTheme = enum {
    dark,
    light,
};

pub const FontSet = struct {
    regular: raygui.Font = undefined,
    bold: raygui.Font = undefined,
    mono: raygui.Font = undefined,
    icon: raygui.Font = undefined,
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
    scale: f32 = 1.0,
    opacity: u8 = 180,
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
        const path_z = try allocator.dupeZ(u8, path);
        defer allocator.free(path_z);

        const text_ptr = raylib.loadFileText(path_z);
        if (text_ptr == null) return error.FileNotFound;
        defer raylib.unloadFileText(text_ptr.?);

        const text = std.mem.span(text_ptr.?);

        var parsed = try std.json.parseFromSlice(UiConfig, allocator, text, .{
            .ignore_unknown_fields = true,
        });
        defer parsed.deinit();

        var cfg = parsed.value;
        cfg.sanitize();
        return cfg;
    }

    pub fn save(self: *const UiConfig, allocator: std.mem.Allocator, path: []const u8) !void {
        var buffer = try std.ArrayList(u8).initCapacity(allocator, 0);
        defer buffer.deinit(allocator);

        try buffer.print(allocator, "{f}", .{std.json.fmt(self, .{})});

        const path_z = try allocator.dupeZ(u8, path);
        defer allocator.free(path_z);

        const buffer_str = buffer.items;
        if (!raylib.saveFileText(path_z, @ptrCast(buffer_str.ptr))) {
            return error.SaveFailed;
        }
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

pub const PanelResult = struct {
    dragged: bool = false,
    clicked: bool = false,
    resized: bool = false,
};

pub const PanelId = enum(u8) {
    hud,
    settings,
};

pub const FrameInput = struct {
    mouse_pos: raygui.Vector2,
    mouse_pressed: bool,
    mouse_down: bool,
    mouse_released: bool,
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

    pub fn fromTheme(theme: UiTheme, scale: f32) UiStyle {
        const clamped_scale = std.math.clamp(scale, config.UI.MIN_SCALE, config.UI.MAX_SCALE);

        return switch (theme) {
            .dark => .{
                .scale = clamped_scale,
                .font_size = @intFromFloat(@as(f32, @floatFromInt(config.UI.DEFAULT_FONT_SIZE)) * clamped_scale),
                .small_font_size = @intFromFloat(@as(f32, @floatFromInt(config.UI.SMALL_FONT_SIZE)) * clamped_scale),
                .padding = @intFromFloat(16.0 * clamped_scale),
                .panel_title_height = @intFromFloat(36.0 * clamped_scale),
                .border_width = 1.5,
                .corner_radius = 8.0,
                .shadow_offset = 4.0,
                .panel_bg = Color{ .r = 24, .g = 24, .b = 28, .a = 180 },
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
                .font_size = @intFromFloat(@as(f32, @floatFromInt(config.UI.DEFAULT_FONT_SIZE)) * clamped_scale),
                .small_font_size = @intFromFloat(@as(f32, @floatFromInt(config.UI.SMALL_FONT_SIZE)) * clamped_scale),
                .padding = @intFromFloat(16.0 * clamped_scale),
                .panel_title_height = @intFromFloat(36.0 * clamped_scale),
                .border_width = 1.5,
                .corner_radius = 8.0,
                .shadow_offset = 4.0,
                .panel_bg = Color{ .r = 250, .g = 250, .b = 252, .a = 180 },
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

pub const UiContext = struct {
    style: UiStyle,
    scale: f32 = 1.0,
    fonts: ?FontSet = null,
    hot_id: u64 = 0,
    active_id: u64 = 0,
    input: FrameInput = undefined,

    pub fn init(scale: f32) UiContext {
        const clamped_scale = std.math.clamp(scale, config.UI.MIN_SCALE, config.UI.MAX_SCALE);

        return .{
            .style = UiStyle.fromTheme(.dark, clamped_scale),
            .scale = clamped_scale,
            .fonts = null,
        };
    }

    pub fn beginFrame(self: *UiContext, input: FrameInput, style: UiStyle) void {
        self.input = input;
        self.style = style;
    }

    pub fn endFrame(self: *UiContext) void {
        self.hot_id = 0;
    }

    pub fn getStyle(self: *UiContext) UiStyle {
        return UiStyle.fromTheme(.dark, self.scale);
    }

    pub fn panel(self: *UiContext, id: PanelId, rect: *Rectangle, title: [:0]const u8) PanelResult {
        _ = self;
        _ = id;
        _ = rect;
        _ = title;
        return .{};
    }

    pub fn button(self: *UiContext, rect: Rectangle, label: [:0]const u8) bool {
        _ = self;
        _ = rect;
        _ = label;
        return false;
    }

    pub fn checkbox(self: *UiContext, rect: Rectangle, label: [:0]const u8, value: *bool) bool {
        _ = self;
        _ = rect;
        _ = label;
        _ = value;
        return false;
    }

    pub fn sliderFloat(self: *UiContext, rect: Rectangle, label: [:0]const u8, value: *f32, min: f32, max: f32) bool {
        _ = self;
        _ = rect;
        _ = label;
        if (value.* < min) value.* = min;
        if (value.* > max) value.* = max;
        return false;
    }

    pub fn drawLabel(self: *UiContext, text: [:0]const u8, x: f32, y: f32) void {
        _ = self;
        _ = text;
        _ = x;
        _ = y;
    }

    pub fn drawProgressBar(self: *UiContext, rect: Rectangle, progress: f32) void {
        _ = self;
        _ = rect;
        _ = progress;
    }

    pub fn comboBox(self: *UiContext, rect: Rectangle, text: [:0]const u8, active: *c_int) bool {
        _ = self;
        _ = rect;
        _ = text;
        _ = active;
        return false;
    }

    pub fn dropdownBox(self: *UiContext, rect: Rectangle, text: [:0]const u8, active: *c_int, editMode: bool) bool {
        _ = self;
        _ = rect;
        _ = text;
        _ = active;
        _ = editMode;
        return false;
    }

    pub fn toggle(self: *UiContext, rect: Rectangle, text: [:0]const u8, active: *bool) bool {
        _ = self;
        _ = rect;
        _ = text;
        _ = active;
        return false;
    }

    pub fn toggleGroup(self: *UiContext, rect: Rectangle, text: [:0]const u8, active: *c_int) c_int {
        _ = self;
        _ = rect;
        _ = text;
        _ = active;
        return 0;
    }

    pub fn spinner(self: *UiContext, rect: Rectangle, text: [:0]const u8, value: *c_int, min: c_int, max: c_int, editMode: bool) c_int {
        _ = self;
        _ = rect;
        _ = text;
        _ = value;
        _ = min;
        _ = max;
        _ = editMode;
        return 0;
    }

    pub fn textBox(self: *UiContext, rect: Rectangle, text: [*]u8, textSize: c_int, editMode: bool) c_int {
        _ = self;
        _ = rect;
        _ = text;
        _ = textSize;
        _ = editMode;
        return 0;
    }

    pub fn listView(self: *UiContext, rect: Rectangle, text: [:0]const u8, scrollIndex: *c_int, active: *c_int) c_int {
        _ = self;
        _ = rect;
        _ = text;
        _ = scrollIndex;
        _ = active;
        return 0;
    }

    pub fn colorPicker(self: *UiContext, rect: Rectangle, text: [:0]const u8, color: *Color) Color {
        _ = self;
        _ = rect;
        _ = text;
        _ = color;
        return Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
    }

    pub fn colorPanel(self: *UiContext, rect: Rectangle, text: [:0]const u8, color: *Color) Color {
        _ = self;
        _ = rect;
        _ = text;
        _ = color;
        return Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
    }

    pub fn messageBox(self: *UiContext, rect: Rectangle, title: [:0]const u8, message: [:0]const u8, buttons: [:0]const u8) c_int {
        _ = self;
        _ = rect;
        _ = title;
        _ = message;
        _ = buttons;
        return 0;
    }

    pub fn groupBox(self: *UiContext, rect: Rectangle, text: [:0]const u8) void {
        _ = self;
        _ = rect;
        _ = text;
    }

    pub fn line(self: *UiContext, rect: Rectangle, text: [:0]const u8) void {
        _ = self;
        _ = rect;
        _ = text;
    }

    pub fn scrollPanel(self: *UiContext, bounds: Rectangle, text: [:0]const u8, content: *Rectangle, scroll: *Rectangle) c_int {
        _ = self;
        _ = bounds;
        _ = text;
        _ = content;
        _ = scroll;
        return 0;
    }
};
