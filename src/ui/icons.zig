//! UI Icon System
//!
//! 8x8 pixel art icons for the UI system.
//! Each icon is stored as an 8-byte array where each byte is a row (MSB = left pixel).

const std = @import("std");
const render = @import("../render/render.zig");

/// Icon bitmap (8x8 pixels, 1 bit per pixel)
pub const Icon = struct {
    bitmap: [8]u8,

    /// Draw the icon at specified position with scaling
    pub fn draw(
        self: *const Icon,
        renderer: *render.Renderer,
        x: i32,
        y: i32,
        scale: i32,
        color: render.Color,
    ) void {
        for (0..8) |row| {
            const row_data = self.bitmap[row];
            for (0..8) |col| {
                const bit: u3 = @intCast(7 - col);
                if ((row_data >> bit) & 1 == 1) {
                    const px = x + @as(i32, @intCast(col)) * scale;
                    const py = y + @as(i32, @intCast(row)) * scale;

                    var sy: i32 = 0;
                    while (sy < scale) : (sy += 1) {
                        var sx: i32 = 0;
                        while (sx < scale) : (sx += 1) {
                            renderer.drawPixel(px + sx, py + sy, 0, color);
                        }
                    }
                }
            }
        }
    }
};

// =============================================================================
// Window Controls
// =============================================================================

/// Close icon (X)
pub const close = Icon{ .bitmap = .{
    0b00000000,
    0b01000010,
    0b00100100,
    0b00011000,
    0b00011000,
    0b00100100,
    0b01000010,
    0b00000000,
} };

/// Minimize icon (horizontal line)
pub const minimize = Icon{ .bitmap = .{
    0b00000000,
    0b00000000,
    0b00000000,
    0b00000000,
    0b01111110,
    0b01111110,
    0b00000000,
    0b00000000,
} };

/// Maximize icon (square outline)
pub const maximize = Icon{ .bitmap = .{
    0b00000000,
    0b01111110,
    0b01000010,
    0b01000010,
    0b01000010,
    0b01000010,
    0b01111110,
    0b00000000,
} };

/// Restore icon (overlapping squares)
pub const restore = Icon{ .bitmap = .{
    0b00011110,
    0b00010010,
    0b01111010,
    0b01001010,
    0b01001110,
    0b01000010,
    0b01111110,
    0b00000000,
} };

// =============================================================================
// File System
// =============================================================================

/// Folder icon
pub const folder = Icon{ .bitmap = .{
    0b00000000,
    0b01110000,
    0b01111110,
    0b01000010,
    0b01000010,
    0b01000010,
    0b01111110,
    0b00000000,
} };

/// Folder open icon
pub const folder_open = Icon{ .bitmap = .{
    0b00000000,
    0b01110000,
    0b01111110,
    0b01111110,
    0b01100010,
    0b01000010,
    0b01111110,
    0b00000000,
} };

/// File icon
pub const file = Icon{ .bitmap = .{
    0b00000000,
    0b00111100,
    0b00101110,
    0b00100010,
    0b00100010,
    0b00100010,
    0b00111110,
    0b00000000,
} };

/// Settings gear icon
pub const settings = Icon{ .bitmap = .{
    0b00011000,
    0b01111110,
    0b11011011,
    0b11100111,
    0b11100111,
    0b11011011,
    0b01111110,
    0b00011000,
} };

// =============================================================================
// Media Controls
// =============================================================================

/// Play icon (right-pointing triangle)
pub const play = Icon{ .bitmap = .{
    0b00010000,
    0b00011000,
    0b00011100,
    0b00011110,
    0b00011110,
    0b00011100,
    0b00011000,
    0b00010000,
} };

/// Pause icon (two vertical bars)
pub const pause = Icon{ .bitmap = .{
    0b00000000,
    0b01100110,
    0b01100110,
    0b01100110,
    0b01100110,
    0b01100110,
    0b01100110,
    0b00000000,
} };

/// Stop icon (filled square)
pub const stop = Icon{ .bitmap = .{
    0b00000000,
    0b01111110,
    0b01111110,
    0b01111110,
    0b01111110,
    0b01111110,
    0b01111110,
    0b00000000,
} };

/// Skip forward icon
pub const skip_forward = Icon{ .bitmap = .{
    0b00000000,
    0b00100010,
    0b00110010,
    0b00111010,
    0b00111010,
    0b00110010,
    0b00100010,
    0b00000000,
} };

/// Skip backward icon
pub const skip_backward = Icon{ .bitmap = .{
    0b00000000,
    0b01000100,
    0b01001100,
    0b01011100,
    0b01011100,
    0b01001100,
    0b01000100,
    0b00000000,
} };

// =============================================================================
// Arrows
// =============================================================================

/// Arrow up
pub const arrow_up = Icon{ .bitmap = .{
    0b00000000,
    0b00011000,
    0b00111100,
    0b01111110,
    0b00011000,
    0b00011000,
    0b00011000,
    0b00000000,
} };

/// Arrow down
pub const arrow_down = Icon{ .bitmap = .{
    0b00000000,
    0b00011000,
    0b00011000,
    0b00011000,
    0b01111110,
    0b00111100,
    0b00011000,
    0b00000000,
} };

/// Arrow left
pub const arrow_left = Icon{ .bitmap = .{
    0b00000000,
    0b00001000,
    0b00011000,
    0b00111110,
    0b00111110,
    0b00011000,
    0b00001000,
    0b00000000,
} };

/// Arrow right
pub const arrow_right = Icon{ .bitmap = .{
    0b00000000,
    0b00010000,
    0b00011000,
    0b01111100,
    0b01111100,
    0b00011000,
    0b00010000,
    0b00000000,
} };

/// Chevron up (smaller arrow)
pub const chevron_up = Icon{ .bitmap = .{
    0b00000000,
    0b00000000,
    0b00011000,
    0b00111100,
    0b01100110,
    0b01000010,
    0b00000000,
    0b00000000,
} };

/// Chevron down
pub const chevron_down = Icon{ .bitmap = .{
    0b00000000,
    0b00000000,
    0b01000010,
    0b01100110,
    0b00111100,
    0b00011000,
    0b00000000,
    0b00000000,
} };

// =============================================================================
// Status Indicators
// =============================================================================

/// Check mark
pub const check = Icon{ .bitmap = .{
    0b00000000,
    0b00000001,
    0b00000010,
    0b00000100,
    0b01001000,
    0b00110000,
    0b00000000,
    0b00000000,
} };

/// Cross (X mark for errors)
pub const cross = Icon{ .bitmap = .{
    0b00000000,
    0b01000010,
    0b00100100,
    0b00011000,
    0b00011000,
    0b00100100,
    0b01000010,
    0b00000000,
} };

/// Plus sign
pub const plus = Icon{ .bitmap = .{
    0b00000000,
    0b00011000,
    0b00011000,
    0b01111110,
    0b01111110,
    0b00011000,
    0b00011000,
    0b00000000,
} };

/// Minus sign
pub const minus = Icon{ .bitmap = .{
    0b00000000,
    0b00000000,
    0b00000000,
    0b01111110,
    0b01111110,
    0b00000000,
    0b00000000,
    0b00000000,
} };

/// Info icon (i in circle)
pub const info = Icon{ .bitmap = .{
    0b00111100,
    0b01000010,
    0b01011010,
    0b01000010,
    0b01011010,
    0b01011010,
    0b01000010,
    0b00111100,
} };

/// Warning icon (triangle with !)
pub const warning = Icon{ .bitmap = .{
    0b00011000,
    0b00011000,
    0b00111100,
    0b00101100,
    0b01100110,
    0b01100110,
    0b11111111,
    0b00000000,
} };

/// Error icon (circle with X)
pub const err = Icon{ .bitmap = .{
    0b00111100,
    0b01100110,
    0b11011011,
    0b11000011,
    0b11011011,
    0b01100110,
    0b00111100,
    0b00000000,
} };

// =============================================================================
// UI Elements
// =============================================================================

/// Menu icon (hamburger)
pub const menu = Icon{ .bitmap = .{
    0b00000000,
    0b01111110,
    0b00000000,
    0b01111110,
    0b00000000,
    0b01111110,
    0b00000000,
    0b00000000,
} };

/// Search/magnifying glass
pub const search = Icon{ .bitmap = .{
    0b00111000,
    0b01000100,
    0b01000100,
    0b01000100,
    0b00111000,
    0b00001100,
    0b00000110,
    0b00000000,
} };

/// Refresh icon (circular arrows)
pub const refresh = Icon{ .bitmap = .{
    0b00111110,
    0b01000010,
    0b00000010,
    0b00001110,
    0b01110000,
    0b01000000,
    0b01000010,
    0b00111100,
} };

/// Lock icon
pub const lock = Icon{ .bitmap = .{
    0b00011000,
    0b00100100,
    0b00100100,
    0b01111110,
    0b01111110,
    0b01011010,
    0b01111110,
    0b00000000,
} };

/// Unlock icon
pub const unlock = Icon{ .bitmap = .{
    0b00011100,
    0b00100000,
    0b00100000,
    0b01111110,
    0b01111110,
    0b01011010,
    0b01111110,
    0b00000000,
} };

/// Eye icon (visible)
pub const eye = Icon{ .bitmap = .{
    0b00000000,
    0b00111100,
    0b01000010,
    0b01011010,
    0b01011010,
    0b01000010,
    0b00111100,
    0b00000000,
} };

/// Eye off icon (hidden)
pub const eye_off = Icon{ .bitmap = .{
    0b01000001,
    0b00111010,
    0b01000110,
    0b01011010,
    0b01101010,
    0b01010010,
    0b00111100,
    0b10000010,
} };

/// Edit/pencil icon
pub const edit = Icon{ .bitmap = .{
    0b00000110,
    0b00001100,
    0b00011010,
    0b00110100,
    0b01101000,
    0b11010000,
    0b10100000,
    0b11000000,
} };

/// Trash/delete icon
pub const trash = Icon{ .bitmap = .{
    0b00111100,
    0b01111110,
    0b00100100,
    0b00100100,
    0b00100100,
    0b00100100,
    0b00111100,
    0b00000000,
} };

/// Copy icon
pub const copy = Icon{ .bitmap = .{
    0b00011110,
    0b00010010,
    0b01110010,
    0b01010010,
    0b01010010,
    0b01010010,
    0b01111110,
    0b00000000,
} };

/// Drag handle (dots)
pub const drag_handle = Icon{ .bitmap = .{
    0b00000000,
    0b01100110,
    0b00000000,
    0b01100110,
    0b00000000,
    0b01100110,
    0b00000000,
    0b00000000,
} };

/// Resize handle (corner)
pub const resize_handle = Icon{ .bitmap = .{
    0b00000000,
    0b00000000,
    0b00000000,
    0b00000010,
    0b00001010,
    0b00101010,
    0b10101010,
    0b00000000,
} };

// =============================================================================
// Game-Specific
// =============================================================================

/// Heart icon (health)
pub const heart = Icon{ .bitmap = .{
    0b00000000,
    0b01100110,
    0b11111111,
    0b11111111,
    0b11111111,
    0b01111110,
    0b00111100,
    0b00011000,
} };

/// Star icon
pub const star = Icon{ .bitmap = .{
    0b00011000,
    0b00011000,
    0b11111111,
    0b01111110,
    0b00111100,
    0b01100110,
    0b01000010,
    0b00000000,
} };

/// Coin icon
pub const coin = Icon{ .bitmap = .{
    0b00111100,
    0b01111110,
    0b11011011,
    0b11011011,
    0b11011011,
    0b11011011,
    0b01111110,
    0b00111100,
} };

// =============================================================================
// Radio/Checkbox
// =============================================================================

/// Unchecked checkbox (empty square)
pub const checkbox_unchecked = Icon{ .bitmap = .{
    0b01111110,
    0b01000010,
    0b01000010,
    0b01000010,
    0b01000010,
    0b01000010,
    0b01111110,
    0b00000000,
} };

/// Checked checkbox (square with check)
pub const checkbox_checked = Icon{ .bitmap = .{
    0b01111110,
    0b01000011,
    0b01000110,
    0b01001100,
    0b01011010,
    0b01110010,
    0b01111110,
    0b00000000,
} };

/// Radio unchecked (empty circle)
pub const radio_unchecked = Icon{ .bitmap = .{
    0b00111100,
    0b01000010,
    0b10000001,
    0b10000001,
    0b10000001,
    0b10000001,
    0b01000010,
    0b00111100,
} };

/// Radio checked (circle with dot)
pub const radio_checked = Icon{ .bitmap = .{
    0b00111100,
    0b01000010,
    0b10011001,
    0b10111101,
    0b10111101,
    0b10011001,
    0b01000010,
    0b00111100,
} };

// =============================================================================
// Tests
// =============================================================================

test "icon dimensions" {
    // All icons should have 8 rows
    try std.testing.expectEqual(@as(usize, 8), close.bitmap.len);
    try std.testing.expectEqual(@as(usize, 8), folder.bitmap.len);
    try std.testing.expectEqual(@as(usize, 8), play.bitmap.len);
}

test "check icon pattern" {
    // Verify the check icon has some set pixels
    var has_pixels = false;
    for (check.bitmap) |row| {
        if (row != 0) has_pixels = true;
    }
    try std.testing.expect(has_pixels);
}
