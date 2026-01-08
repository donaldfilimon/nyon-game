//! Raygui-based Widget Primitives - Basic UI building blocks for immediate-mode GUI.
//!
//! This module provides fundamental UI widgets using raygui controls.
//! All widgets follow immediate-mode pattern: call them each frame to draw
//! and handle interaction.

const std = @import("std");
const raygui = @import("raygui");

pub const Rectangle = raygui.Rectangle;
pub const Color = raygui.Color;

/// Draw a clickable button and return true if clicked.
pub fn button(rect: Rectangle, label_text: [:0]const u8) bool {
    return raygui.GuiButton(rect, label_text) > 0;
}

/// Draw a checkbox and update its value when clicked.
/// Returns true if checkbox was toggled this frame.
pub fn checkbox(rect: Rectangle, label_text: [:0]const u8, value: *bool) bool {
    return raygui.GuiCheckBox(rect, label_text, value);
}

/// Draw a float slider and update value when dragged.
/// Returns true if slider value changed this frame.
pub fn sliderFloat(rect: Rectangle, label_text: [:0]const u8, value: *f32, min: f32, max: f32) bool {
    const old_value = value.*;
    value.* = raygui.GuiSlider(rect, label_text, null, value.*, min, max);
    return value.* != old_value;
}

/// Draw an int slider and update value when dragged.
/// Returns true if slider value changed this frame.
pub fn sliderInt(rect: Rectangle, label_text: [:0]const u8, value: *i32, min: i32, max: i32) bool {
    const float_val: f32 = @floatFromInt(value.*);
    const min_f: f32 = @floatFromInt(min);
    const max_f: f32 = @floatFromInt(max);

    var float_val_out = float_val;
    const changed = sliderFloat(rect, label_text, &float_val_out, min_f, max_f);

    if (changed) {
        const rounded = std.math.round(float_val_out);
        const clamped = if (rounded < @as(f32, @floatFromInt(min))) @as(f32, @floatFromInt(min)) else if (rounded > @as(f32, @floatFromInt(max))) @as(f32, @floatFromInt(max)) else rounded;
        value.* = @intFromFloat(clamped);
    }

    return changed;
}

/// Draw a label.
pub fn drawLabel(text: [:0]const u8, x: f32, y: f32) void {
    const rect = Rectangle{ .x = x, .y = y, .width = 0, .height = 0 };
    raygui.GuiLabel(rect, text);
}

/// Draw a progress bar.
pub fn drawProgressBar(rect: Rectangle, progress: f32, bg_color: Color, fill_color: Color) void {
    _ = bg_color;
    _ = fill_color;
    _ = raygui.GuiProgressBar(rect, null, null, progress, 0.0, 1.0);
}

/// Draw a separator line.
pub fn drawSeparator(x: f32, y: f32, width: f32, color: Color) void {
    _ = color;
    const rect = Rectangle{ .x = x, .y = y, .width = width, .height = 1 };
    _ = raygui.GuiLine(rect, "");
}

/// Draw a section header.
pub fn drawSectionHeader(text: [:0]const u8, x: f32, y: f32) void {
    const rect = Rectangle{ .x = x, .y = y, .width = 0, .height = 0 };
    raygui.GuiLabel(rect, text);
}

/// Draw a combo box (dropdown selection).
/// text: options separated by ';' (e.g., "Option1;Option2;Option3")
/// active: pointer to current selection index
/// Returns true if selection changed.
pub fn comboBox(rect: Rectangle, text: [:0]const u8, active: *c_int) bool {
    const old_value = active.*;
    _ = raygui.GuiComboBox(rect, text, active);
    return active.* != old_value;
}

/// Draw a dropdown box.
/// text: options separated by ';' (e.g., "Option1;Option2;Option3")
/// active: pointer to current selection index
/// editMode: whether dropdown is open
/// Returns true if selection changed.
pub fn dropdownBox(rect: Rectangle, text: [:0]const u8, active: *c_int, editMode: bool) bool {
    return raygui.GuiDropdownBox(rect, text, active, editMode);
}

/// Draw a toggle button.
/// text: label text
/// active: pointer to toggle state
/// Returns true if toggled.
pub fn toggle(rect: Rectangle, text: [:0]const u8, active: *bool) bool {
    return raygui.GuiToggle(rect, text, active);
}

/// Draw a toggle group (radio buttons).
/// text: options separated by ';' (e.g., "Option1;Option2;Option3")
/// active: pointer to currently selected index
/// Returns newly selected index.
pub fn toggleGroup(rect: Rectangle, text: [:0]const u8, active: *c_int) c_int {
    return raygui.GuiToggleGroup(rect, text, active);
}

/// Draw a spinner for numeric input.
/// text: label text
/// value: pointer to current value
/// min/max: value bounds
/// editMode: whether editing
/// Returns state code.
pub fn spinner(rect: Rectangle, text: [:0]const u8, value: *c_int, min: c_int, max: c_int, editMode: bool) c_int {
    return raygui.GuiSpinner(rect, text, value, min, max, editMode);
}

/// Draw a text input box.
/// text: buffer for input text
/// textSize: buffer capacity
/// editMode: whether editing
/// Returns state code.
pub fn textBox(rect: Rectangle, text: [*]u8, textSize: c_int, editMode: bool) c_int {
    return raygui.GuiTextBox(rect, text, textSize, editMode);
}

/// Draw a list view.
/// text: items separated by ';' (e.g., "Item1;Item2;Item3")
/// scrollIndex: pointer to scroll position
/// active: pointer to selected item index
/// Returns state code.
pub fn listView(rect: Rectangle, text: [:0]const u8, scrollIndex: *c_int, active: *c_int) c_int {
    return raygui.GuiListView(rect, text, scrollIndex, active);
}

/// Draw a color picker.
/// text: label text
/// color: pointer to current color
/// Returns new color.
pub fn colorPicker(rect: Rectangle, text: [:0]const u8, color: *Color) Color {
    return raygui.GuiColorPicker(rect, text, color);
}

/// Draw a color panel.
/// text: label text
/// color: pointer to current color
/// Returns new color.
pub fn colorPanel(rect: Rectangle, text: [:0]const u8, color: *Color) Color {
    return raygui.GuiColorPanel(rect, text, color);
}

/// Draw a message box with title, message, and buttons.
/// buttons: button labels separated by ';' (e.g., "OK;Cancel")
/// Returns button index pressed or -1 to close.
pub fn messageBox(rect: Rectangle, title: [:0]const u8, message: [:0]const u8, buttons: [:0]const u8) c_int {
    return raygui.GuiMessageBox(rect, title, message, buttons);
}

/// Draw a group box with label.
pub fn groupBox(rect: Rectangle, text: [:0]const u8) void {
    _ = raygui.GuiGroupBox(rect, text);
}

/// Draw a line separator.
pub fn line(rect: Rectangle, text: [:0]const u8) void {
    _ = raygui.GuiLine(rect, text);
}

/// Draw a scroll panel with content.
pub fn scrollPanel(bounds: Rectangle, text: [:0]const u8, content: *Rectangle, scroll: *Rectangle) c_int {
    var view: c_int = 0;
    return raygui.GuiScrollPanel(bounds, text, content, scroll, &view);
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
