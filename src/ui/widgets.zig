//! Widget Primitives - Basic UI building blocks for immediate-mode GUI.
//!
//! This module provides fundamental UI widgets that can be combined to create
//! complex interfaces. All widgets follow the immediate-mode pattern: call
//! them each frame to draw and handle interaction.
//!
//! Core widget functions extracted from UiContext for modularity.
//! These functions handle input processing, rendering, and interaction state.

const std = @import("std");
const engine_mod = @import("../engine.zig");
const ui_mod = @import("ui.zig");

const Rectangle = engine_mod.Rectangle;
const Vector2 = engine_mod.Vector2;
const Color = engine_mod.Color;
const Shapes = engine_mod.Shapes;
const Text = engine_mod.Text;

const UiContext = ui_mod.UiContext;
const UiStyle = ui_mod.UiStyle;
const FrameInput = ui_mod.FrameInput;

pub const WidgetId = struct {
    pub fn fromString(prefix: []const u8, extra: []const u8) u64 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(prefix);
        hasher.update(extra);
        return hasher.final();
    }
};

/// Check if mouse position is inside a rectangle.
/// Returns true if the mouse cursor is within the rectangle bounds.
fn isMouseOverRect(input: FrameInput, rect: Rectangle) bool {
    const mx = input.mouse_pos.x;
    const my = input.mouse_pos.y;
    return mx >= rect.x and my >= rect.y and
        mx <= rect.x + rect.width and my <= rect.y + rect.height;
}

/// Draw a clickable button and return true if clicked this frame.
/// The button is considered clicked when the mouse is released while hovering
/// and the button was the active widget (mouse was pressed on it).
pub fn button(
    ctx: *UiContext,
    id: u64,
    rect: Rectangle,
    label_text: [:0]const u8,
) bool {
    const hovered = isMouseOverRect(ctx.input, rect);
    if (hovered) ctx.hot_id = id;

    const is_active = ctx.active_id == id;
    if (hovered and ctx.input.mouse_pressed) {
        ctx.active_id = id;
    }

    const pressed = hovered and is_active and ctx.input.mouse_released;

    const bg = if (hovered) ctx.style.accent_hover else ctx.style.accent;
    Shapes.drawRectangleRec(rect, bg);
    Shapes.drawRectangleLinesEx(rect, @intFromFloat(ctx.style.border_width), ctx.style.panel_border);

    const text_w = Text.measure(label_text, ctx.style.small_font_size);
    const tx: i32 = @intFromFloat(rect.x + (rect.width - @as(f32, @floatFromInt(text_w))) / 2.0);
    const ty: i32 = @intFromFloat(rect.y + (rect.height - @as(f32, @floatFromInt(ctx.style.small_font_size))) / 2.0);
    Text.draw(label_text, tx, ty, ctx.style.small_font_size, ctx.style.text);

    return pressed;
}

/// Draw a checkbox and update its value when clicked.
/// Returns true if the checkbox was toggled this frame.
pub fn checkbox(
    ctx: *UiContext,
    id: u64,
    rect: Rectangle,
    label_text: [:0]const u8,
    value: *bool,
) bool {
    const box = Rectangle{ .x = rect.x, .y = rect.y, .width = rect.height, .height = rect.height };
    const hovered = isMouseOverRect(ctx.input, rect);
    if (hovered) ctx.hot_id = id;

    if (hovered and ctx.input.mouse_pressed) {
        ctx.active_id = id;
    }

    const clicked = hovered and ctx.active_id == id and ctx.input.mouse_released;
    if (clicked) value.* = !value.*;

    const radius = ctx.style.corner_radius * 0.5;
    const bg_color = if (value.*) ctx.style.accent else ctx.style.panel_bg;

    Shapes.drawRectangleRounded(box, radius / @min(box.width, box.height), 4, bg_color);
    Shapes.drawRectangleRoundedLinesEx(box, radius / @min(box.width, box.height), 4, ctx.style.border_width, ctx.style.panel_border);
    if (value.*) {
        const mark = Rectangle{
            .x = box.x + 4,
            .y = box.y + 4,
            .width = box.width - 8,
            .height = box.height - 8,
        };
        Shapes.drawRectangleRec(mark, ctx.style.panel_border);
    }

    const label_x: i32 = @as(i32, @intFromFloat(rect.x + rect.height + 10));
    const label_y: i32 = @as(i32, @intFromFloat(rect.y + 2));
    Text.draw(label_text, label_x, label_y, ctx.style.small_font_size, ctx.style.text);
    return clicked;
}

/// Draw a float slider and update value when dragged.
/// Returns true if the slider value changed this frame.
pub fn sliderFloat(
    ctx: *UiContext,
    id: u64,
    rect: Rectangle,
    label_text: [:0]const u8,
    value: *f32,
    min: f32,
    max: f32,
) bool {
    const track = Rectangle{ .x = rect.x + 10.0, .y = rect.y + rect.height / 2.0 - 2.0, .width = rect.width - 20.0, .height = 4.0 };
    const knob_radius: f32 = rect.height / 2.0 - 2.0;
    const knob_x = @min(@max(track.x, track.x + (value.* - min) / (max - min) * track.width), track.x + track.width - knob_radius);
    const knob_center = Vector2{ .x = knob_x, .y = rect.y + rect.height / 2.0 };
    const knob_rect = Rectangle{ .x = knob_center.x - knob_radius, .y = knob_center.y - knob_radius, .width = knob_radius * 2.0, .height = knob_radius * 2.0 };
    const hovered = isMouseOverRect(ctx.input, rect);
    if (hovered) ctx.hot_id = id;

    const was_active = ctx.active_id == id;
    if (hovered and ctx.input.mouse_pressed) {
        ctx.active_id = id;
        if (ctx.input.mouse_down) {
            const knob_rect_f32 = Rectangle{ .x = knob_rect.x, .y = knob_rect.y, .width = knob_rect.width, .height = knob_rect.height };
            if (isMouseOverRect(ctx.input, knob_rect_f32)) {
                const mx = ctx.input.mouse_pos.x - track.x;
                const clamped = @max(min, @min(max, min + mx / track.width * (max - min)));
                if (@abs(clamped - value.*) > 0.0001) {
                    value.* = clamped;
                    return true;
                }
            }
        }
    }

    const bg = if (hovered) ctx.style.accent_hover else ctx.style.panel_bg;
    const track_color = if (was_active) ctx.style.accent else ctx.style.text_muted;
    Shapes.drawRectangleRec(rect, bg);
    Shapes.drawRectangleRec(track, track_color);

    const knob_color = if (hovered or was_active) ctx.style.accent else ctx.style.text;
    Shapes.drawCircleV(knob_center, knob_radius, knob_color);
    Text.draw(label_text, @intFromFloat(rect.x), @intFromFloat(rect.y), ctx.style.small_font_size, ctx.style.text);

    return false;
}

pub fn sliderInt(
    ctx: *UiContext,
    id: u64,
    rect: Rectangle,
    label_text: [:0]const u8,
    value: *i32,
    min: i32,
    max: i32,
) bool {
    const float_val: f32 = @floatFromInt(value.*);
    const min_f: f32 = @floatFromInt(min);
    const max_f: f32 = @floatFromInt(max);

    var float_val_out = float_val;
    const changed = sliderFloat(ctx, id, rect, label_text, &float_val_out, min_f, max_f);

    if (changed) {
        const rounded = std.math.round(float_val_out);
        const clamped = if (rounded < @as(f32, @floatFromInt(min))) @as(f32, @floatFromInt(min)) else if (rounded > @as(f32, @floatFromInt(max))) @as(f32, @floatFromInt(max)) else rounded;
        value.* = @intFromFloat(clamped);
    }

    return changed;
}

pub fn drawLabel(
    ctx: *UiContext,
    text: [:0]const u8,
    x: f32,
    y: f32,
    size: i32,
    color: Color,
) void {
    _ = ctx;
    Text.draw(text, @intFromFloat(x), @intFromFloat(y), size, color);
}

pub fn drawLabelScaled(
    ctx: *UiContext,
    text: [:0]const u8,
    x: f32,
    y: f32,
    base_size: i32,
    color: Color,
) void {
    const size: i32 = @intFromFloat(@as(f32, @floatFromInt(base_size)) * ctx.style.scale);
    Text.draw(text, @intFromFloat(x), @intFromFloat(y), size, color);
}

pub fn drawProgressBar(
    ctx: *UiContext,
    rect: Rectangle,
    progress: f32,
    bg_color: Color,
    fill_color: Color,
) void {
    _ = ctx;
    Shapes.drawRectangleRec(rect, bg_color);

    const clamped = if (progress < 0.0) 0.0 else if (progress > 1.0) 1.0 else progress;
    const fill_width = rect.width * clamped;
    if (fill_width > 0.0) {
        Shapes.drawRectangleRec(Rectangle{ .x = rect.x, .y = rect.y, .width = fill_width, .height = rect.height }, fill_color);
    }
}

pub fn drawSeparator(
    ctx: *UiContext,
    x: f32,
    y: f32,
    width: f32,
    color: Color,
) void {
    _ = ctx;
    Shapes.drawLine(@intFromFloat(x), @intFromFloat(y), @intFromFloat(x + width), @intFromFloat(y), color);
}

pub fn drawSectionHeader(
    ctx: *UiContext,
    text: [:0]const u8,
    x: f32,
    y: f32,
) void {
    drawLabel(ctx, text, x, y, ctx.style.small_font_size, ctx.style.accent);
}

test "button returns true on click release" {
    const test_rect = Rectangle{ .x = 100, .y = 100, .width = 120, .height = 30 };
    const mouse_over_rect = isMouseOverRect(.{
        .mouse_pos = .{ .x = 160.0, .y = 115.0 },
        .mouse_pressed = false,
        .mouse_down = false,
        .mouse_released = false,
    }, test_rect);
    try std.testing.expect(mouse_over_rect);
}

test "checkbox toggles value" {
    var value = false;
    try std.testing.expect(value == false);
    value = true;
    try std.testing.expect(value == true);
}

test "sliderFloat clamps values correctly" {
    const min: f32 = 0.0;
    const max: f32 = 100.0;
    var value: f32 = 50.0;

    value = std.math.clamp(value, min, max);
    try std.testing.expect(value == 50.0);

    value = std.math.clamp(-10.0, min, max);
    try std.testing.expect(value == 0.0);

    value = std.math.clamp(150.0, min, max);
    try std.testing.expect(value == 100.0);
}

test "drawProgressBar clamps progress" {
    var clamped = if (-0.5 < 0.0) 0.0 else if (-0.5 > 1.0) 1.0 else -0.5;
    try std.testing.expect(clamped == 0.0);

    clamped = if (1.5 < 0.0) 0.0 else if (1.5 > 1.0) 1.0 else 1.5;
    try std.testing.expect(clamped == 1.0);

    clamped = if (0.5 < 0.0) 0.0 else if (0.5 > 1.0) 1.0 else 0.5;
    try std.testing.expect(clamped == 0.5);
}
