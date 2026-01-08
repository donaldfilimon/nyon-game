//! Raygui bindings for Nyon Game Engine.
//!
//! This module provides Zig bindings for raygui, a simple and easy-to-use
//! immediate-mode GUI library that works with raylib.

const std = @import("std");

pub extern fn GuiButton(bounds: Rectangle, text: [*:0]const u8) c_int;
pub extern fn GuiLabel(bounds: Rectangle, text: [*:0]const u8) void;
pub extern fn GuiCheckBox(bounds: Rectangle, text: [*:0]const u8, checked: *bool) bool;
pub extern fn GuiSlider(bounds: Rectangle, textLeft: [*:0]const u8, textRight: [*:0]const u8, value: f32, minValue: f32, maxValue: f32) f32;
pub extern fn GuiSliderBar(bounds: Rectangle, textLeft: [*:0]const u8, textRight: [*:0]const u8, value: f32, minValue: f32, maxValue: f32) f32;
pub extern fn GuiProgressBar(bounds: Rectangle, textLeft: [*:0]const u8, textRight: [*:0]const u8, value: f32, minValue: f32, maxValue: f32) f32;
pub extern fn GuiStatusBar(bounds: Rectangle, text: [*:0]const u8) void;
pub extern fn GuiDummyRec(bounds: Rectangle, text: [*:0]const u8) c_int;
pub extern fn GuiGrid(bounds: Rectangle, text: [*:0]const u8, spacing: f32, subdivs: c_int) c_int;
pub extern fn GuiGroupBox(bounds: Rectangle, text: [*:0]const u8) c_int;
pub extern fn GuiLine(bounds: Rectangle, text: [*:0]const u8) c_int;
pub extern fn GuiPanel(bounds: Rectangle, text: [*:0]const u8) c_int;
pub extern fn GuiScrollPanel(bounds: Rectangle, text: [*:0]const u8, content: *Rectangle, scroll: *Rectangle, view: [*]c_int) c_int;
pub extern fn GuiWindowBox(bounds: Rectangle, title: [*:0]const u8) c_int;

pub extern fn GuiSetStyle(control: c_int, property: c_int, value: c_int) void;
pub extern fn GuiGetStyle(control: c_int, property: c_int) c_int;
pub extern fn GuiLoadStyle(fileName: [*:0]const u8) void;
pub extern fn GuiLoadStyleDefault() void;
pub extern fn GuiEnable() void;
pub extern fn GuiDisable() void;
pub extern fn GuiLock() void;
pub extern fn GuiUnlock() void;
pub extern fn GuiIsLocked() bool;
pub extern fn GuiFade(alpha: f32) void;
pub extern fn GuiSetState(state: c_int) void;
pub extern fn GuiGetState() c_int;
pub extern fn GuiSetFont(font: Font) void;
pub extern fn GuiGetFont() Font;
pub extern fn GuiSetIconScale(scale: f32) void;
pub extern fn GuiGetIconScale() f32;
pub extern fn GuiToggle(bounds: Rectangle, text: [*:0]const u8, active: *bool) bool;
pub extern fn GuiToggleGroup(bounds: Rectangle, text: [*:0]const u8, active: *c_int) c_int;
pub extern fn GuiToggleSlider(bounds: Rectangle, text: [*:0]const u8, active: *bool) bool;
pub extern fn GuiComboBox(bounds: Rectangle, text: [*:0]const u8, active: *c_int) c_int;
pub extern fn GuiDropdownBox(bounds: Rectangle, text: [*:0]const u8, active: *c_int) bool;
pub extern fn GuiSpinner(bounds: Rectangle, text: [*:0]const u8, value: *c_int, minValue: c_int, maxValue: c_int, editMode: bool) c_int;
pub extern fn GuiValueBox(bounds: Rectangle, text: [*:0]const u8, value: *c_int, minValue: c_int, maxValue: c_int, editMode: bool) c_int;
pub extern fn GuiTextInput(bounds: Rectangle, text: [*:0]const u8, textSize: c_int, editMode: bool) c_int;
pub extern fn GuiTextBox(bounds: Rectangle, text: [*:0]const u8, textSize: c_int, editMode: bool) c_int;
pub extern fn GuiColorPicker(bounds: Rectangle, text: [*:0]const u8, color: *Color) Color;
pub extern fn GuiColorPanel(bounds: Rectangle, text: [*:0]const u8, color: *Color) Color;
pub extern fn GuiColorBarAlpha(bounds: Rectangle, text: [*:0]const u8, alpha: *f32) f32;
pub extern fn GuiColorBarHue(bounds: Rectangle, text: [*:0]const u8, hue: *f32) f32;
pub extern fn GuiListView(bounds: Rectangle, text: [*:0]const u8, scrollIndex: *c_int, active: *c_int) c_int;
pub extern fn GuiMessageBox(bounds: Rectangle, title: [*:0]const u8, message: [*:0]const u8, buttons: [*:0]const u8) c_int;
pub extern fn GuiTextInputBox(bounds: Rectangle, title: [*:0]const u8, message: [*:0]const u8, buttons: [*:0]const u8, text: [*:0]const u8, textMaxSize: c_int) c_int;

pub const Rectangle = extern struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

pub const Color = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

pub const Font = extern struct {
    baseSize: c_int,
    glyphCount: c_int,
    glyphPadding: c_int,
    texture: Texture2D,
    recs: [*]Rectangle,
    glyphs: [*]GlyphInfo,
};

pub const Texture2D = extern struct {
    id: c_uint,
    width: c_int,
    height: c_int,
    mipmaps: c_int,
    format: c_int,
};

pub const GlyphInfo = extern struct {
    value: c_int,
    offsetX: c_int,
    offsetY: c_int,
    advanceX: c_int,
    image: Image,
    id: u32,
};

pub const Image = extern struct {
    data: ?*anyopaque,
    width: c_int,
    height: c_int,
    mipmaps: c_int,
    format: c_int,
};

pub const GuiControlState = enum(c_int) {
    normal = 0,
    focused = 1,
    pressed = 2,
    disabled = 3,
};

pub const GuiTextAlignment = enum(c_int) {
    left = 0,
    center = 1,
    right = 2,
};

pub const GuiControl = enum(c_int) {
    default = 0,
    label,
    button,
    toggle,
    slider,
    progressBar,
    checkBox,
    comboBox,
    dropdownBox,
    textBox,
    valueBox,
    spinner,
    listView,
    colorPicker,
    scrollBar,
    scrollPanel,
};

pub const GuiControlProperty = enum(c_int) {
    border_color = 0,
    base_color = 1,
    text_color = 2,
    border_width = 3,
    text_padding = 4,
    text_alignment = 5,
};
