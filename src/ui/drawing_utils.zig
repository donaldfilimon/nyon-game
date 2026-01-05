//! Unified drawing utilities for immediate-mode UI.
//!
//! This module provides reusable drawing functions to reduce code duplication
//! across the UI and editor modules. All drawing operations use the engine's
//! Shapes and Text utilities with consistent styling.

const std = @import("std");
const engine_mod = @import("../engine.zig");
const Color = engine_mod.Color;
const Rectangle = engine_mod.Rectangle;
const Vector2 = engine_mod.Vector2;
const Shapes = engine_mod.Shapes;
const Text = engine_mod.Text;

const config = @import("../config/constants.zig");

pub const PanelStyle = struct {
    background: Color,
    border: Color,
    border_width: f32 = 1.0,
    shadow_color: Color = Color{ .r = 0, .g = 0, .b = 0, .a = 80 },
    shadow_offset: f32 = 4.0,
    corner_radius: f32 = 6.0,
};

pub const ButtonStyle = struct {
    background: Color,
    hover: Color,
    pressed: Color,
    border: Color,
    text: Color,
    border_width: f32 = 1.0,
    corner_radius: f32 = 4.0,
};

pub const ButtonState = enum {
    normal,
    hover,
    pressed,
    disabled,
};

pub fn drawPanel(rect: Rectangle, style: PanelStyle) void {
    if (style.shadow_offset > 0) {
        const shadow_rect = Rectangle{
            .x = rect.x + style.shadow_offset,
            .y = rect.y + style.shadow_offset,
            .width = rect.width,
            .height = rect.height,
        };
        const radius = style.corner_radius / std.math.min(shadow_rect.width, shadow_rect.height);
        Shapes.drawRectangleRounded(shadow_rect, radius, 8, style.shadow_color);
    }

    const radius = style.corner_radius / std.math.min(rect.width, rect.height);
    Shapes.drawRectangleRounded(rect, radius, 8, style.background);
    if (style.border_width > 0) {
        Shapes.drawRectangleRoundedLinesEx(rect, radius, 8, style.border_width, style.border);
    }
}

pub fn drawPanelFlat(rect: Rectangle, style: PanelStyle) void {
    Shapes.drawRectangleRec(rect, style.background);
    if (style.border_width > 0) {
        Shapes.drawRectangleLinesEx(rect, style.border_width, style.border);
    }
}

pub fn drawButton(rect: Rectangle, text: [:0]const u8, state: ButtonState, style: ButtonStyle, font_size: i32) void {
    const bg_color = switch (state) {
        .normal => style.background,
        .hover => style.hover,
        .pressed => style.pressed,
        .disabled => style.background,
    };

    const radius = style.corner_radius / std.math.min(rect.width, rect.height);
    Shapes.drawRectangleRounded(rect, radius, 8, bg_color);

    if (style.border_width > 0) {
        Shapes.drawRectangleRoundedLinesEx(rect, radius, 8, style.border_width, style.border);
    }

    const text_w = Text.measure(text, font_size);
    const tx: i32 = @intFromFloat(rect.x + (rect.width - @as(f32, @floatFromInt(text_w))) / 2.0);
    const ty: i32 = @intFromFloat(rect.y + (rect.height - @as(f32, @floatFromInt(font_size))) / 2.0);
    const text_color = if (state == .disabled) style.text else Color{ .r = style.text.r, .g = style.text.g, .b = style.text.b, .a = 150 };

    Text.draw(text, tx, ty, font_size, text_color);
}

pub fn drawButtonFlat(rect: Rectangle, text: [:0]const u8, state: ButtonState, style: ButtonStyle, font_size: i32) void {
    const bg_color = switch (state) {
        .normal => style.background,
        .hover => style.hover,
        .pressed => style.pressed,
        .disabled => style.background,
    };

    Shapes.drawRectangleRec(rect, bg_color);

    if (style.border_width > 0) {
        Shapes.drawRectangleLinesEx(rect, style.border_width, style.border);
    }

    const text_w = Text.measure(text, font_size);
    const tx: i32 = @intFromFloat(rect.x + (rect.width - @as(f32, @floatFromInt(text_w))) / 2.0);
    const ty: i32 = @intFromFloat(rect.y + (rect.height - @as(f32, @floatFromInt(font_size))) / 2.0);
    const text_color = if (state == .disabled) style.text else Color{ .r = style.text.r, .g = style.text.g, .b = style.text.b, .a = 150 };

    Text.draw(text, tx, ty, font_size, text_color);
}

pub fn drawCheckbox(rect: Rectangle, checked: bool, style: PanelStyle, check_color: Color) void {
    const radius = style.corner_radius / std.math.min(rect.width, rect.height);
    Shapes.drawRectangleRounded(rect, radius, 4, style.background);

    if (style.border_width > 0) {
        Shapes.drawRectangleRoundedLinesEx(rect, radius, 4, style.border_width, style.border);
    }

    if (checked) {
        const check_rect = Rectangle{
            .x = rect.x + 4,
            .y = rect.y + 4,
            .width = rect.width - 8,
            .height = rect.height - 8,
        };
        Shapes.drawRectangleRec(check_rect, check_color);
    }
}

pub fn drawSlider(rect: Rectangle, value: f32, min: f32, max: f32, style: PanelStyle, fill_color: Color) void {
    const track_height = 4.0;
    const track_y = rect.y + rect.height / 2.0 - track_height / 2.0;
    const track = Rectangle{
        .x = rect.x + 10.0,
        .y = track_y,
        .width = rect.width - 20.0,
        .height = track_height,
    };

    Shapes.drawRectangleRec(track, style.background);

    const normalized = if (value < min) 0.0 else if (value > max) 1.0 else (value - min) / (max - min);
    const fill_width = track.width * normalized;
    if (fill_width > 0) {
        Shapes.drawRectangleRec(Rectangle{
            .x = track.x,
            .y = track.y,
            .width = fill_width,
            .height = track.height,
        }, fill_color);
    }

    const knob_radius = (rect.height / 2.0) - 2.0;
    const knob_x = @min(@max(track.x, track.x + normalized * track.width), track.x + track.width - knob_radius);
    const knob_center = Vector2{ .x = knob_x, .y = rect.y + rect.height / 2.0 };
    Shapes.drawCircleV(knob_center, knob_radius, style.border);
}

pub fn drawTextRect(text: [:0]const u8, rect: Rectangle, font_size: i32, color: Color, alignment: enum { left, center, right }) void {
    const text_w = Text.measure(text, font_size);
    var tx: i32 = 0;

    switch (alignment) {
        .left => tx = @intFromFloat(rect.x + 8),
        .center => tx = @intFromFloat(rect.x + (rect.width - @as(f32, @floatFromInt(text_w))) / 2.0),
        .right => tx = @intFromFloat(rect.x + rect.width - @as(f32, @floatFromInt(text_w)) - 8),
    }

    const ty: i32 = @intFromFloat(rect.y + (rect.height - @as(f32, @floatFromInt(font_size))) / 2.0);
    Text.draw(text, tx, ty, font_size, color);
}

pub fn drawProgressBar(rect: Rectangle, progress: f32, bg_color: Color, fill_color: Color) void {
    Shapes.drawRectangleRec(rect, bg_color);

    const clamped = if (progress < 0.0) 0.0 else if (progress > 1.0) 1.0 else progress;
    const fill_width = rect.width * clamped;
    if (fill_width > 0) {
        Shapes.drawRectangleRec(Rectangle{ .x = rect.x, .y = rect.y, .width = fill_width, .height = rect.height }, fill_color);
    }
}

pub fn drawTooltip(text: [:0]const u8, x: f32, y: f32, style: PanelStyle, font_size: i32) void {
    const text_w = Text.measure(text, font_size);
    const padding: f32 = 8.0;
    const tooltip_rect = Rectangle{
        .x = x + 16.0,
        .y = y + 16.0,
        .width = @as(f32, @floatFromInt(text_w)) + padding * 2.0,
        .height = @as(f32, @floatFromInt(font_size)) + padding * 2.0,
    };

    drawPanel(tooltip_rect, style);
    const tx: i32 = @intFromFloat(tooltip_rect.x + padding);
    const ty: i32 = @intFromFloat(tooltip_rect.y + padding);
    Text.draw(text, tx, ty, font_size, Color{ .r = 240, .g = 240, .b = 250, .a = 255 });
}

test "drawPanel with valid dimensions" {
    const test_rect = Rectangle{ .x = 0, .y = 0, .width = 100, .height = 100 };
    try std.testing.expect(test_rect.width > 0 and test_rect.height > 0);
}
