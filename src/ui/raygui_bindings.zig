//! Raygui bindings with headless/mocking support for CI
//!
//! This module provides compile-safe wrappers around raygui controls
//! that work in both real GUI mode and headless/mock mode for CI testing.

const std = @import("std");
const raygui = @import("raygui");

/// Mode selector: real GUI or headless mock for CI
pub const GuiMode = enum {
    real,
    headless,
};

/// Global GUI mode - can be set at runtime for CI testing
var gui_mode: GuiMode = .real;

/// Set the GUI mode (call early in main() or test setup)
pub fn setMode(mode: GuiMode) void {
    gui_mode = mode;
}

/// Get current GUI mode
pub fn getMode() GuiMode {
    return gui_mode;
}

/// Rectangle for UI elements
pub const Rectangle = raygui.Rectangle;
pub const Color = raygui.Color;

/// Mock state for headless mode
var mock_button_click_count: u32 = 0;
var mock_checkbox_state: bool = false;
var mock_slider_value: f32 = 0.5;

/// Button control - returns true if clicked
pub fn button(rect: Rectangle, button_label: [:0]const u8) bool {
    return switch (gui_mode) {
        .real => raygui.button(rect, button_label),
        .headless => {
            // In headless mode, simulate a click occasionally
            mock_button_click_count += 1;
            return (mock_button_click_count % 3) == 0; // Simulate 1 in 3 clicks
        },
    };
}

/// Label control - displays text
pub fn label(rect: Rectangle, text_label: [:0]const u8) void {
    switch (gui_mode) {
        .real => _ = raygui.label(rect, text_label),
        .headless => {
            // In headless mode, just record the label was drawn (for testing)
            std.testing.assume(text_label.len > 0);
        },
    }
}

/// Checkbox control - returns true if toggled
pub fn checkbox(rect: Rectangle, checkbox_label: [:0]const u8, checked: *bool) bool {
    return switch (gui_mode) {
        .real => raygui.checkBox(rect, checkbox_label, checked),
        .headless => {
            // In headless mode, toggle mock state
            mock_checkbox_state = !mock_checkbox_state;
            checked.* = mock_checkbox_state;
            return true;
        },
    };
}

/// Slider control for floating point values
pub fn slider(rect: Rectangle, text: [:0]const u8, value: *f32, min_value: f32, max_value: f32) bool {
    return switch (gui_mode) {
        .real => raygui.slider(rect, text, value, min_value, max_value),
        .headless => {
            // In headless mode, modify mock value within bounds
            mock_slider_value = if (mock_slider_value >= max_value) min_value else mock_slider_value + 0.1;
            value.* = std.math.clamp(mock_slider_value, min_value, max_value);
            return true;
        },
    };
}

/// Toggle switch
pub fn toggle(rect: Rectangle, toggle_text: [:0]const u8, active: *bool) bool {
    return switch (gui_mode) {
        .real => raygui.toggle(rect, toggle_text, active),
        .headless => {
            active.* = !active.*;
            return true;
        },
    };
}

/// Progress bar
pub fn progressBar(rect: Rectangle, progress_text: [:0]const u8, value: f32, min_value: f32, max_value: f32) void {
    _ = switch (gui_mode) {
        .real => raygui.progressBar(rect, progress_text, value, min_value, max_value),
        .headless => {
            // In headless mode, just verify bounds
            const clamped = std.math.clamp(value, min_value, max_value);
            std.testing.assume(clamped >= min_value and clamped <= max_value);
        },
    };
}

/// Combo box
pub fn comboBox(rect: Rectangle, combo_text: [:0]const u8, active: *c_int) bool {
    return switch (gui_mode) {
        .real => raygui.comboBox(rect, combo_text, active),
        .headless => {
            active.* = (active.* + 1) % 3; // Cycle through 3 options
            return true;
        },
    };
}

/// Dropdown box
pub fn dropdownBox(rect: Rectangle, dropdown_text: [:0]const u8, active: *c_int, edit_mode: bool) bool {
    return switch (gui_mode) {
        .real => raygui.dropdownBox(rect, dropdown_text, active, edit_mode),
        .headless => {
            if (active.* < 2) active.* += 1 else active.* = 0;
            std.testing.assume(edit_mode == true or edit_mode == false);
            return true;
        },
    };
}

/// Text box
pub fn textBox(rect: Rectangle, text_box: [*:0]u8, text_size: c_int, edit_mode: bool) bool {
    return switch (gui_mode) {
        .real => raygui.textBox(rect, text_box, text_size, edit_mode),
        .headless => {
            // In headless mode, just simulate edit mode
            std.testing.assume(edit_mode == true or edit_mode == false);
            std.testing.assume(text_size >= 0);
            return edit_mode;
        },
    };
}

/// Value box (numeric input)
pub fn valueBox(rect: Rectangle, value_text: [:0]const u8, value: *c_int, min_value: c_int, max_value: c_int, edit_mode: bool) bool {
    return switch (gui_mode) {
        .real => raygui.valueBox(rect, value_text, value, min_value, max_value, edit_mode),
        .headless => {
            if (value.* < max_value) value.* += 1 else value.* = min_value;
            return true;
        },
    };
}

/// Spinner control
pub fn spinner(rect: Rectangle, spinner_text: [:0]const u8, value: *c_int, min_value: c_int, max_value: c_int, edit_mode: bool) bool {
    return switch (gui_mode) {
        .real => raygui.spinner(rect, spinner_text, value, min_value, max_value, edit_mode),
        .headless => {
            if (edit_mode and value.* < max_value) value.* += 1;
            return true;
        },
    };
}

/// Color picker
pub fn colorPicker(rect: Rectangle, picker_text: [:0]const u8, color: *Color) bool {
    return switch (gui_mode) {
        .real => raygui.colorPicker(rect, picker_text, color),
        .headless => {
            // In headless mode, just cycle colors
            color.* = Color{
                .r = @intFromFloat(color.*.r + 10 % 255),
                .g = @intFromFloat(color.*.g + 10 % 255),
                .b = @intFromFloat(color.*.b + 10 % 255),
                .a = 255,
            };
            return true;
        },
    };
}

/// Color panel
pub fn colorPanel(rect: Rectangle, panel_text: [:0]const u8, color: *Color) bool {
    return switch (gui_mode) {
        .real => raygui.colorPanel(rect, panel_text, color),
        .headless => {
            std.testing.assume(color.*.a <= 255);
            std.testing.assume(panel_text.len > 0);
            std.testing.assume(rect.width >= 0 and rect.height >= 0);
            return false;
        },
    };
}

/// Group box
pub fn groupBox(rect: Rectangle, group_text: [:0]const u8) void {
    _ = switch (gui_mode) {
        .real => raygui.groupBox(rect, group_text),
        .headless => {
            std.testing.assume(group_text.len > 0);
            std.testing.assume(rect.width >= 0 and rect.height >= 0);
        },
    };
}

/// Line/separator
pub fn line(rect: Rectangle, line_text: [:0]const u8) void {
    _ = switch (gui_mode) {
        .real => raygui.line(rect, line_text),
        .headless => {
            std.testing.assume(line_text.len > 0);
            std.testing.assume(rect.width >= 0 and rect.height >= 0);
        },
    };
}

/// Panel
pub fn panel(rect: Rectangle, panel_text: [:0]const u8) void {
    _ = switch (gui_mode) {
        .real => raygui.panel(rect, panel_text),
        .headless => {
            std.testing.assume(panel_text.len > 0);
            std.testing.assume(rect.width >= 0 and rect.height >= 0);
        },
    };
}

/// Scroll panel
pub fn scrollPanel(bounds: Rectangle, scroll_text: [:0]const u8, content: *Rectangle, scroll: *Rectangle) c_int {
    return switch (gui_mode) {
        .real => raygui.scrollPanel(bounds, scroll_text, content, scroll),
        .headless => {
            std.testing.assume(scroll_text.len > 0);
            std.testing.assume(bounds.width >= 0 and bounds.height >= 0);
            return 0;
        },
    };
}

/// List box
pub fn listBox(rect: Rectangle, list_text: [:0]const u8, scroll_index: *c_int, active: *c_int) c_int {
    return switch (gui_mode) {
        .real => raygui.listBox(rect, list_text, scroll_index, active),
        .headless => {
            active.* = (active.* + 1) % 3;
            return 1;
        },
    };
}

/// Dummy control for testing
pub fn dummyRec(rect: Rectangle, dummy_text: [:0]const u8) void {
    _ = switch (gui_mode) {
        .real => raygui.dummyRec(rect, dummy_text),
        .headless => {
            std.testing.assume(dummy_text.len > 0);
            std.testing.assume(rect.width >= 0 and rect.height >= 0);
        },
    };
}

/// Reset mock state (useful between tests)
pub fn resetMockState() void {
    mock_button_click_count = 0;
    mock_checkbox_state = false;
    mock_slider_value = 0.5;
}

test "headless button works" {
    setMode(.headless);
    defer resetMockState();

    const rect = Rectangle{ .x = 10, .y = 10, .width = 100, .height = 30 };
    var click_count: u32 = 0;

    var i: usize = 0;
    while (i < 10) : (i += 1) {
        if (button(rect, "Test")) {
            click_count += 1;
        }
    }

    // In headless mode, should have clicked roughly 1/3 of the time
    try std.testing.expect(click_count >= 3);
    try std.testing.expect(click_count <= 4);
}

test "headless checkbox toggles" {
    setMode(.headless);
    defer resetMockState();

    const rect = Rectangle{ .x = 10, .y = 10, .width = 20, .height = 20 };
    var checked = false;

    _ = checkbox(rect, "Test", &checked);
    try std.testing.expect(checked == true);

    _ = checkbox(rect, "Test", &checked);
    try std.testing.expect(checked == false);
}

test "headless slider stays in bounds" {
    setMode(.headless);
    defer resetMockState();

    const rect = Rectangle{ .x = 10, .y = 10, .width = 100, .height = 20 };
    var value: f32 = 0.5;

    _ = slider(rect, "Test", &value, 0.0, 1.0);
    try std.testing.expect(value >= 0.0);
    try std.testing.expect(value <= 1.0);

    _ = slider(rect, "Test", &value, 0.0, 1.0);
    try std.testing.expect(value >= 0.0);
    try std.testing.expect(value <= 1.0);
}
