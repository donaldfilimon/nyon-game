//! Bitmap Font Text Rendering System
//!
//! Provides simple bitmap font rendering for UI text display.
//! Uses an embedded 8x8 pixel font for maximum compatibility.

const std = @import("std");
const render = @import("../render/render.zig");

/// Character glyph data
pub const Glyph = struct {
    width: u8,
    height: u8,
    advance: u8,
    bitmap: [8]u8, // 8x8 bitmap (1 bit per pixel, row-major)
};

/// Bitmap font
pub const Font = struct {
    glyphs: [128]Glyph,
    line_height: u8,
    base_size: u8,

    /// Get glyph for character
    pub fn getGlyph(self: *const Font, char: u8) *const Glyph {
        if (char >= 128) return &self.glyphs[0]; // Default to space
        return &self.glyphs[char];
    }
};

/// Text alignment options
pub const Alignment = enum {
    left,
    center,
    right,
};

/// Text rendering options
pub const TextOptions = struct {
    color: render.Color = render.Color.WHITE,
    scale: u8 = 1,
    alignment: Alignment = .left,
    max_width: ?i32 = null,
    line_spacing: i32 = 2,
};

/// Measure text dimensions
pub fn measureText(font: *const Font, text: []const u8, scale: u8) struct { width: i32, height: i32 } {
    var width: i32 = 0;
    var max_width: i32 = 0;
    var lines: i32 = 1;

    for (text) |char| {
        if (char == '\n') {
            max_width = @max(max_width, width);
            width = 0;
            lines += 1;
            continue;
        }
        const glyph = font.getGlyph(char);
        width += @as(i32, glyph.advance) * @as(i32, scale);
    }
    max_width = @max(max_width, width);

    return .{
        .width = max_width,
        .height = lines * (@as(i32, font.line_height) * @as(i32, scale)),
    };
}

/// Draw text to renderer
pub fn drawText(
    renderer: *render.Renderer,
    font: *const Font,
    text: []const u8,
    x: i32,
    y: i32,
    options: TextOptions,
) void {
    var draw_x = x;
    var draw_y = y;

    // Handle alignment
    if (options.alignment != .left) {
        const size = measureText(font, text, options.scale);
        switch (options.alignment) {
            .center => draw_x = x - @divFloor(size.width, 2),
            .right => draw_x = x - size.width,
            .left => {},
        }
    }

    const scale: i32 = @intCast(options.scale);

    for (text) |char| {
        if (char == '\n') {
            draw_x = x;
            draw_y += (@as(i32, font.line_height) + options.line_spacing) * scale;
            continue;
        }

        const glyph = font.getGlyph(char);
        drawGlyph(renderer, glyph, draw_x, draw_y, scale, options.color);
        draw_x += @as(i32, glyph.advance) * scale;
    }
}

/// Draw a single glyph
fn drawGlyph(
    renderer: *render.Renderer,
    glyph: *const Glyph,
    x: i32,
    y: i32,
    scale: i32,
    color: render.Color,
) void {
    for (0..8) |row| {
        const row_data = glyph.bitmap[row];
        for (0..8) |col| {
            const bit: u3 = @intCast(7 - col);
            if ((row_data >> bit) & 1 == 1) {
                // Draw scaled pixel
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

/// Default embedded 8x8 bitmap font (ASCII printable characters)
pub const default_font: Font = blk: {
    var font = Font{
        .glyphs = undefined,
        .line_height = 10,
        .base_size = 8,
    };

    // Initialize all glyphs to empty
    for (&font.glyphs) |*g| {
        g.* = Glyph{ .width = 8, .height = 8, .advance = 8, .bitmap = .{ 0, 0, 0, 0, 0, 0, 0, 0 } };
    }

    // Space (32)
    font.glyphs[' '] = .{ .width = 8, .height = 8, .advance = 6, .bitmap = .{ 0, 0, 0, 0, 0, 0, 0, 0 } };

    // Numbers 0-9 (48-57)
    font.glyphs['0'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b00111100,
        0b01100110,
        0b01101110,
        0b01110110,
        0b01100110,
        0b01100110,
        0b00111100,
        0b00000000,
    } };
    font.glyphs['1'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b00011000,
        0b00111000,
        0b00011000,
        0b00011000,
        0b00011000,
        0b00011000,
        0b01111110,
        0b00000000,
    } };
    font.glyphs['2'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b00111100,
        0b01100110,
        0b00000110,
        0b00011100,
        0b00110000,
        0b01100000,
        0b01111110,
        0b00000000,
    } };
    font.glyphs['3'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b00111100,
        0b01100110,
        0b00000110,
        0b00011100,
        0b00000110,
        0b01100110,
        0b00111100,
        0b00000000,
    } };
    font.glyphs['4'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b00001100,
        0b00011100,
        0b00101100,
        0b01001100,
        0b01111110,
        0b00001100,
        0b00001100,
        0b00000000,
    } };
    font.glyphs['5'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b01111110,
        0b01100000,
        0b01111100,
        0b00000110,
        0b00000110,
        0b01100110,
        0b00111100,
        0b00000000,
    } };
    font.glyphs['6'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b00111100,
        0b01100000,
        0b01111100,
        0b01100110,
        0b01100110,
        0b01100110,
        0b00111100,
        0b00000000,
    } };
    font.glyphs['7'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b01111110,
        0b00000110,
        0b00001100,
        0b00011000,
        0b00110000,
        0b00110000,
        0b00110000,
        0b00000000,
    } };
    font.glyphs['8'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b00111100,
        0b01100110,
        0b01100110,
        0b00111100,
        0b01100110,
        0b01100110,
        0b00111100,
        0b00000000,
    } };
    font.glyphs['9'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b00111100,
        0b01100110,
        0b01100110,
        0b00111110,
        0b00000110,
        0b00001100,
        0b00111000,
        0b00000000,
    } };

    // Uppercase letters A-Z (65-90)
    font.glyphs['A'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b00011000,
        0b00111100,
        0b01100110,
        0b01100110,
        0b01111110,
        0b01100110,
        0b01100110,
        0b00000000,
    } };
    font.glyphs['B'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b01111100,
        0b01100110,
        0b01100110,
        0b01111100,
        0b01100110,
        0b01100110,
        0b01111100,
        0b00000000,
    } };
    font.glyphs['C'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b00111100,
        0b01100110,
        0b01100000,
        0b01100000,
        0b01100000,
        0b01100110,
        0b00111100,
        0b00000000,
    } };
    font.glyphs['D'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b01111000,
        0b01101100,
        0b01100110,
        0b01100110,
        0b01100110,
        0b01101100,
        0b01111000,
        0b00000000,
    } };
    font.glyphs['E'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b01111110,
        0b01100000,
        0b01100000,
        0b01111100,
        0b01100000,
        0b01100000,
        0b01111110,
        0b00000000,
    } };
    font.glyphs['F'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b01111110,
        0b01100000,
        0b01100000,
        0b01111100,
        0b01100000,
        0b01100000,
        0b01100000,
        0b00000000,
    } };
    font.glyphs['G'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b00111100,
        0b01100110,
        0b01100000,
        0b01101110,
        0b01100110,
        0b01100110,
        0b00111110,
        0b00000000,
    } };
    font.glyphs['H'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b01100110,
        0b01100110,
        0b01100110,
        0b01111110,
        0b01100110,
        0b01100110,
        0b01100110,
        0b00000000,
    } };
    font.glyphs['I'] = .{ .width = 8, .height = 8, .advance = 5, .bitmap = .{
        0b00111100,
        0b00011000,
        0b00011000,
        0b00011000,
        0b00011000,
        0b00011000,
        0b00111100,
        0b00000000,
    } };
    font.glyphs['J'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b00011110,
        0b00001100,
        0b00001100,
        0b00001100,
        0b01101100,
        0b01101100,
        0b00111000,
        0b00000000,
    } };
    font.glyphs['K'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b01100110,
        0b01101100,
        0b01111000,
        0b01110000,
        0b01111000,
        0b01101100,
        0b01100110,
        0b00000000,
    } };
    font.glyphs['L'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b01100000,
        0b01100000,
        0b01100000,
        0b01100000,
        0b01100000,
        0b01100000,
        0b01111110,
        0b00000000,
    } };
    font.glyphs['M'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b01100011,
        0b01110111,
        0b01111111,
        0b01101011,
        0b01100011,
        0b01100011,
        0b01100011,
        0b00000000,
    } };
    font.glyphs['N'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b01100110,
        0b01110110,
        0b01111110,
        0b01111110,
        0b01101110,
        0b01100110,
        0b01100110,
        0b00000000,
    } };
    font.glyphs['O'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b00111100,
        0b01100110,
        0b01100110,
        0b01100110,
        0b01100110,
        0b01100110,
        0b00111100,
        0b00000000,
    } };
    font.glyphs['P'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b01111100,
        0b01100110,
        0b01100110,
        0b01111100,
        0b01100000,
        0b01100000,
        0b01100000,
        0b00000000,
    } };
    font.glyphs['Q'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b00111100,
        0b01100110,
        0b01100110,
        0b01100110,
        0b01101010,
        0b01101100,
        0b00110110,
        0b00000000,
    } };
    font.glyphs['R'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b01111100,
        0b01100110,
        0b01100110,
        0b01111100,
        0b01101100,
        0b01100110,
        0b01100110,
        0b00000000,
    } };
    font.glyphs['S'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b00111100,
        0b01100110,
        0b01110000,
        0b00111100,
        0b00001110,
        0b01100110,
        0b00111100,
        0b00000000,
    } };
    font.glyphs['T'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b01111110,
        0b00011000,
        0b00011000,
        0b00011000,
        0b00011000,
        0b00011000,
        0b00011000,
        0b00000000,
    } };
    font.glyphs['U'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b01100110,
        0b01100110,
        0b01100110,
        0b01100110,
        0b01100110,
        0b01100110,
        0b00111100,
        0b00000000,
    } };
    font.glyphs['V'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b01100110,
        0b01100110,
        0b01100110,
        0b01100110,
        0b01100110,
        0b00111100,
        0b00011000,
        0b00000000,
    } };
    font.glyphs['W'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b01100011,
        0b01100011,
        0b01100011,
        0b01101011,
        0b01111111,
        0b01110111,
        0b01100011,
        0b00000000,
    } };
    font.glyphs['X'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b01100110,
        0b01100110,
        0b00111100,
        0b00011000,
        0b00111100,
        0b01100110,
        0b01100110,
        0b00000000,
    } };
    font.glyphs['Y'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b01100110,
        0b01100110,
        0b01100110,
        0b00111100,
        0b00011000,
        0b00011000,
        0b00011000,
        0b00000000,
    } };
    font.glyphs['Z'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b01111110,
        0b00000110,
        0b00001100,
        0b00011000,
        0b00110000,
        0b01100000,
        0b01111110,
        0b00000000,
    } };

    // Lowercase letters a-z (97-122) - use same as uppercase for simplicity
    font.glyphs['a'] = font.glyphs['A'];
    font.glyphs['b'] = font.glyphs['B'];
    font.glyphs['c'] = font.glyphs['C'];
    font.glyphs['d'] = font.glyphs['D'];
    font.glyphs['e'] = font.glyphs['E'];
    font.glyphs['f'] = font.glyphs['F'];
    font.glyphs['g'] = font.glyphs['G'];
    font.glyphs['h'] = font.glyphs['H'];
    font.glyphs['i'] = font.glyphs['I'];
    font.glyphs['j'] = font.glyphs['J'];
    font.glyphs['k'] = font.glyphs['K'];
    font.glyphs['l'] = font.glyphs['L'];
    font.glyphs['m'] = font.glyphs['M'];
    font.glyphs['n'] = font.glyphs['N'];
    font.glyphs['o'] = font.glyphs['O'];
    font.glyphs['p'] = font.glyphs['P'];
    font.glyphs['q'] = font.glyphs['Q'];
    font.glyphs['r'] = font.glyphs['R'];
    font.glyphs['s'] = font.glyphs['S'];
    font.glyphs['t'] = font.glyphs['T'];
    font.glyphs['u'] = font.glyphs['U'];
    font.glyphs['v'] = font.glyphs['V'];
    font.glyphs['w'] = font.glyphs['W'];
    font.glyphs['x'] = font.glyphs['X'];
    font.glyphs['y'] = font.glyphs['Y'];
    font.glyphs['z'] = font.glyphs['Z'];

    // Punctuation
    font.glyphs['.'] = .{ .width = 8, .height = 8, .advance = 4, .bitmap = .{
        0b00000000,
        0b00000000,
        0b00000000,
        0b00000000,
        0b00000000,
        0b00011000,
        0b00011000,
        0b00000000,
    } };
    font.glyphs[','] = .{ .width = 8, .height = 8, .advance = 4, .bitmap = .{
        0b00000000,
        0b00000000,
        0b00000000,
        0b00000000,
        0b00011000,
        0b00011000,
        0b00110000,
        0b00000000,
    } };
    font.glyphs[':'] = .{ .width = 8, .height = 8, .advance = 4, .bitmap = .{
        0b00000000,
        0b00011000,
        0b00011000,
        0b00000000,
        0b00011000,
        0b00011000,
        0b00000000,
        0b00000000,
    } };
    font.glyphs['-'] = .{ .width = 8, .height = 8, .advance = 6, .bitmap = .{
        0b00000000,
        0b00000000,
        0b00000000,
        0b01111110,
        0b00000000,
        0b00000000,
        0b00000000,
        0b00000000,
    } };
    font.glyphs['+'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b00000000,
        0b00011000,
        0b00011000,
        0b01111110,
        0b00011000,
        0b00011000,
        0b00000000,
        0b00000000,
    } };
    font.glyphs['!'] = .{ .width = 8, .height = 8, .advance = 4, .bitmap = .{
        0b00011000,
        0b00011000,
        0b00011000,
        0b00011000,
        0b00011000,
        0b00000000,
        0b00011000,
        0b00000000,
    } };
    font.glyphs['?'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b00111100,
        0b01100110,
        0b00000110,
        0b00001100,
        0b00011000,
        0b00000000,
        0b00011000,
        0b00000000,
    } };
    font.glyphs['/'] = .{ .width = 8, .height = 8, .advance = 6, .bitmap = .{
        0b00000110,
        0b00001100,
        0b00011000,
        0b00110000,
        0b01100000,
        0b11000000,
        0b00000000,
        0b00000000,
    } };
    font.glyphs['%'] = .{ .width = 8, .height = 8, .advance = 7, .bitmap = .{
        0b01100010,
        0b01100100,
        0b00001000,
        0b00010000,
        0b00100110,
        0b01000110,
        0b00000000,
        0b00000000,
    } };

    break :blk font;
};

// ============================================================================
// Tests
// ============================================================================

test "measure text" {
    const size = measureText(&default_font, "Hello", 1);
    try std.testing.expect(size.width > 0);
    try std.testing.expectEqual(@as(i32, 10), size.height);
}

test "measure multiline text" {
    const size = measureText(&default_font, "Hello\nWorld", 1);
    try std.testing.expectEqual(@as(i32, 20), size.height);
}
