//! UI Widgets

const std = @import("std");
const ui = @import("ui.zig");
const render = @import("../render/render.zig");

/// Text input widget state
pub const TextInput = struct {
    buffer: [256]u8 = undefined,
    len: usize = 0,
    cursor: usize = 0,
    focused: bool = false,

    pub fn getText(self: *const TextInput) []const u8 {
        return self.buffer[0..self.len];
    }

    pub fn setText(self: *TextInput, text: []const u8) void {
        if (text.len > self.buffer.len) {
            std.log.warn("TextInput truncated: '{s}' exceeds buffer size {}", .{ text, self.buffer.len });
        }
        const copy_len = @min(text.len, self.buffer.len);
        @memcpy(self.buffer[0..copy_len], text[0..copy_len]);
        self.len = copy_len;
        self.cursor = copy_len;
    }
};

/// Panel for grouping widgets
pub const Panel = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    title: []const u8,
    collapsed: bool,
    draggable: bool,
    resizable: bool,

    pub fn init(x: i32, y: i32, w: i32, h: i32, title: []const u8) Panel {
        return .{
            .x = x,
            .y = y,
            .width = w,
            .height = h,
            .title = title,
            .collapsed = false,
            .draggable = true,
            .resizable = true,
        };
    }
};

/// Scrollable list
pub const ScrollList = struct {
    scroll_offset: f32 = 0,
    item_height: i32 = 24,
    selected_index: ?usize = null,
};

/// Tree view node (simplified - no ArrayList)
pub const TreeNode = struct {
    label: []const u8,
    expanded: bool = false,
    user_data: ?*anyopaque = null,
};
