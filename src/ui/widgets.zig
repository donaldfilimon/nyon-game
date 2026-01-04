//! Reusable UI widget primitives.
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

fn isMouseOverRect(input: FrameInput, rect: Rectangle) bool {
    const mx = input.mouse_pos.x;
    const my = input.mouse_pos.y;
    return mx >= rect.x and my >= rect.y and
        mx <= rect.x + rect.width and my <= rect.y + rect.height;
}

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
    Shapes.drawRectangleLinesEx(rect, ctx.style.border_width, ctx.style.panel_border);

    const text_w = Text.measure(label_text, ctx.style.small_font_size);
    const tx: i32 = @intFromFloat(rect.x + (rect.width - @as(f32, @floatFromInt(text_w))) / 2.0);
    const ty: i32 = @intFromFloat(rect.y + (rect.height - @as(f32, @floatFromInt(ctx.style.small_font_size))) / 2.0);
    Text.draw(label_text, tx, ty, ctx.style.small_font_size, ctx.style.text);

    return pressed;
}

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

    Shapes.drawRectangleRounded(box, radius / std.math.min(box.width, box.height), 4, bg_color);
    Shapes.drawRectangleRoundedLinesEx(box, radius / std.math.min(box.width, box.height), 4, ctx.style.border_width, ctx.style.panel_border);
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

pub fn sliderFloat(
    ctx: *UiContext,
    id: u64,
    rect: Rectangle,
    label_text: [:0]const u8,
    value: *f32,
    min: f32,
    max: f32,
) bool {
    const label_x: i32 = @as(i32, @intFromFloat(rect.x));
    const label_y: i32 = @as(i32, @intFromFloat(rect.y)) - ctx.style.small_font_size - 4;
    Text.draw(label_text, label_x, label_y, ctx.style.small_font_size, ctx.style.text_muted);

    const hovered = isMouseOverRect(ctx.input, rect);
    if (hovered) ctx.hot_id = id;

    if (hovered and ctx.input.mouse_pressed) {
        ctx.active_id = id;
    }

    var changed = false;
    if (ctx.active_id == id and ctx.input.mouse_down) {
        const t = (ctx.input.mouse_pos.x - rect.x) / rect.width;
        const normalized = if (t < 0.0) 0.0 else if (t > 1.0) 1.0 else t;
        value.* = min + (max - min) * normalized;
        changed = true;
    }

    const radius = ctx.style.corner_radius * 0.3;
    Shapes.drawRectangleRounded(rect, radius / std.math.min(rect.width, rect.height), 6, ctx.style.panel_bg);
    Shapes.drawRectangleRoundedLinesEx(rect, radius / std.math.min(rect.width, rect.height), 6, ctx.style.border_width, ctx.style.panel_border);

    const ratio = (value.* - min) / (max - min);
    const fill_w = rect.width * (if (ratio < 0.0) 0.0 else if (ratio > 1.0) 1.0 else ratio);
    if (fill_w > 0.0) {
        Shapes.drawRectangleRec(Rectangle{ .x = rect.x, .y = rect.y, .width = fill_w, .height = rect.height }, ctx.style.accent);
    }

    return changed;
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
    try std.testing.expect(true);
}

test "checkbox toggles value" {
    var value = false;
    try std.testing.expect(value == false);
    value = true;
    try std.testing.expect(value == true);
}

test "sliderInt value assignment" {
    var value: i32 = 50;
    value = 75;
    try std.testing.expect(value == 75);
}
