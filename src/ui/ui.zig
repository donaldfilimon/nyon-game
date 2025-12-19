//! Minimal immediate-mode UI helpers built on top of the engine wrappers.
//!
//! This intentionally stays small (no external `raygui` dependency) while still
//! enabling draggable panels, buttons, checkboxes, and sliders for sample tools
//! and the demo game.

const std = @import("std");

const engine_mod = @import("../engine.zig");
const Color = engine_mod.Color;
const Rectangle = engine_mod.Rectangle;
const Vector2 = engine_mod.Vector2;
const Shapes = engine_mod.Shapes;
const Text = engine_mod.Text;

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

pub const UiStyle = struct {
    scale: f32 = 1.0,

    font_size: i32 = 20,
    small_font_size: i32 = 16,
    padding: i32 = 14,
    panel_title_height: i32 = 30,
    border_width: f32 = 2.0,
    corner_radius: f32 = 0.0,

    panel_bg: Color,
    panel_border: Color,
    text: Color,
    text_muted: Color,
    accent: Color,
    accent_hover: Color,

    pub fn fromTheme(theme: UiTheme, opacity: u8, scale: f32) UiStyle {
        const clamped_scale = if (scale < 0.6) 0.6 else if (scale > 2.5) 2.5 else scale;

        const base_font: i32 = @intFromFloat(std.math.round(20.0 * clamped_scale));
        const small_font: i32 = @intFromFloat(std.math.round(16.0 * clamped_scale));
        const pad: i32 = @intFromFloat(std.math.round(14.0 * clamped_scale));
        const title_h: i32 = @intFromFloat(std.math.round(30.0 * clamped_scale));

        return switch (theme) {
            .dark => .{
                .scale = clamped_scale,
                .font_size = base_font,
                .small_font_size = small_font,
                .padding = pad,
                .panel_title_height = title_h,
                .border_width = 2.0,
                .corner_radius = 0.0,
                .panel_bg = Color{ .r = 0, .g = 0, .b = 0, .a = opacity },
                .panel_border = Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
                .text = Color{ .r = 240, .g = 240, .b = 250, .a = 255 },
                .text_muted = Color{ .r = 200, .g = 200, .b = 210, .a = 255 },
                .accent = Color{ .r = 110, .g = 190, .b = 255, .a = 255 },
                .accent_hover = Color{ .r = 160, .g = 220, .b = 255, .a = 255 },
            },
            .light => .{
                .scale = clamped_scale,
                .font_size = base_font,
                .small_font_size = small_font,
                .padding = pad,
                .panel_title_height = title_h,
                .border_width = 2.0,
                .corner_radius = 0.0,
                .panel_bg = Color{ .r = 250, .g = 250, .b = 255, .a = opacity },
                .panel_border = Color{ .r = 30, .g = 30, .b = 40, .a = 255 },
                .text = Color{ .r = 25, .g = 25, .b = 35, .a = 255 },
                .text_muted = Color{ .r = 90, .g = 90, .b = 105, .a = 255 },
                .accent = Color{ .r = 40, .g = 120, .b = 220, .a = 255 },
                .accent_hover = Color{ .r = 65, .g = 150, .b = 245, .a = 255 },
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

/// Persisted UI configuration for sample apps.
pub const UiConfig = struct {
    version: u32 = 1,
    theme: UiTheme = .dark,
    opacity: u8 = 180,
    scale: f32 = 1.0,

    hud: PanelConfig = .{
        .rect = Rectangle{ .x = 10, .y = 10, .width = 320, .height = 240 },
        .visible = true,
    },
    settings: PanelConfig = .{
        .rect = Rectangle{ .x = 10, .y = 270, .width = 320, .height = 210 },
        .visible = true,
    },

    pub const DEFAULT_PATH = "nyon_ui.json";

    pub fn loadOrDefault(allocator: std.mem.Allocator, path: []const u8) UiConfig {
        return UiConfig.load(allocator, path) catch UiConfig{};
    }

    pub fn load(allocator: std.mem.Allocator, path: []const u8) !UiConfig {
        const file_bytes = try std.fs.cwd().readFileAlloc(path, allocator, std.Io.Limit.limited(256 * 1024));
        defer allocator.free(file_bytes);

        const Parsed = std.json.Parsed(UiConfig);
        var parsed: Parsed = try std.json.parseFromSlice(UiConfig, allocator, file_bytes, .{
            .ignore_unknown_fields = true,
        });
        defer parsed.deinit();

        var cfg = parsed.value;
        cfg.sanitize();
        return cfg;
    }

    pub fn save(self: *const UiConfig, allocator: std.mem.Allocator, path: []const u8) !void {
        _ = allocator;
        var file = try std.fs.cwd().createFile(path, .{ .truncate = true });
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

/// Immediate-mode UI context with basic interaction state.
pub const UiContext = struct {
    style: UiStyle = UiStyle.fromTheme(.dark, 180, 1.0),
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
        self.hot_id = 0;
    }

    pub fn endFrame(self: *UiContext) void {
        if (!self.input.mouse_down) {
            self.active_id = 0;
        }
        self.hot_id = 0;
    }

    pub fn makeId(comptime prefix: []const u8, extra: []const u8) u64 {
        return std.hash.Wyhash.hash(0, prefix ++ extra);
    }

    fn isMouseOverRect(self: *const UiContext, rect: Rectangle) bool {
        const mx = self.input.mouse_pos.x;
        const my = self.input.mouse_pos.y;
        return mx >= rect.x and my >= rect.y and mx <= rect.x + rect.width and my <= rect.y + rect.height;
    }

    pub fn drawPanel(self: *UiContext, rect: Rectangle, title: [:0]const u8, highlight: bool) void {
        Shapes.drawRectangleRec(rect, self.style.panel_bg);
        Shapes.drawRectangleLinesEx(rect, self.style.border_width, self.style.panel_border);

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
        const hovered = self.isMouseOverRect(rect);
        if (hovered) self.hot_id = id;

        const is_active = self.active_id == id;
        if (hovered and self.input.mouse_pressed) {
            self.active_id = id;
        }

        const pressed = hovered and is_active and self.input.mouse_released;

        const bg = if (hovered) self.style.accent_hover else self.style.accent;
        Shapes.drawRectangleRec(rect, bg);
        Shapes.drawRectangleLinesEx(rect, self.style.border_width, self.style.panel_border);

        const text_w = Text.measure(label, self.style.small_font_size);
        const tx: i32 = @intFromFloat(rect.x + (rect.width - @as(f32, @floatFromInt(text_w))) / 2.0);
        const ty: i32 = @intFromFloat(rect.y + (rect.height - @as(f32, @floatFromInt(self.style.small_font_size))) / 2.0);
        Text.draw(label, tx, ty, self.style.small_font_size, self.style.text);

        return pressed;
    }

    pub fn checkbox(self: *UiContext, id: u64, rect: Rectangle, label: [:0]const u8, value: *bool) bool {
        const box = Rectangle{ .x = rect.x, .y = rect.y, .width = rect.height, .height = rect.height };
        const hovered = self.isMouseOverRect(rect);
        if (hovered) self.hot_id = id;

        if (hovered and self.input.mouse_pressed) {
            self.active_id = id;
        }

        const clicked = hovered and self.active_id == id and self.input.mouse_released;
        if (clicked) value.* = !value.*;

        Shapes.drawRectangleRec(box, if (value.*) self.style.accent else self.style.panel_bg);
        Shapes.drawRectangleLinesEx(box, self.style.border_width, self.style.panel_border);
        if (value.*) {
            const mark = Rectangle{
                .x = box.x + 4,
                .y = box.y + 4,
                .width = box.width - 8,
                .height = box.height - 8,
            };
            Shapes.drawRectangleRec(mark, self.style.panel_border);
        }

        const label_x: i32 = @as(i32, @intFromFloat(rect.x + rect.height + 10));
        const label_y: i32 = @as(i32, @intFromFloat(rect.y + 2));
        Text.draw(label, label_x, label_y, self.style.small_font_size, self.style.text);
        return clicked;
    }

    pub fn sliderFloat(self: *UiContext, id: u64, rect: Rectangle, label: [:0]const u8, value: *f32, min: f32, max: f32) bool {
        const label_x: i32 = @as(i32, @intFromFloat(rect.x));
        const label_y: i32 = @as(i32, @intFromFloat(rect.y)) - self.style.small_font_size - 4;
        Text.draw(label, label_x, label_y, self.style.small_font_size, self.style.text_muted);

        const hovered = self.isMouseOverRect(rect);
        if (hovered) self.hot_id = id;

        if (hovered and self.input.mouse_pressed) {
            self.active_id = id;
        }

        var changed = false;
        if (self.active_id == id and self.input.mouse_down) {
            const t = (self.input.mouse_pos.x - rect.x) / rect.width;
            const clamped = if (t < 0.0) 0.0 else if (t > 1.0) 1.0 else t;
            value.* = min + (max - min) * clamped;
            changed = true;
        }

        Shapes.drawRectangleRec(rect, self.style.panel_bg);
        Shapes.drawRectangleLinesEx(rect, self.style.border_width, self.style.panel_border);

        const ratio = (value.* - min) / (max - min);
        const fill_w = rect.width * (if (ratio < 0.0) 0.0 else if (ratio > 1.0) 1.0 else ratio);
        if (fill_w > 0.0) {
            Shapes.drawRectangleRec(Rectangle{ .x = rect.x, .y = rect.y, .width = fill_w, .height = rect.height }, self.style.accent);
        }

        return changed;
    }
};
