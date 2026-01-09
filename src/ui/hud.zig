//! Game HUD
//!
//! Heads-up display for sandbox gameplay.

const std = @import("std");
const math = @import("../math/math.zig");
const render = @import("../render/render.zig");
const ui_mod = @import("ui.zig");
const game = @import("../game/sandbox.zig");

/// Draw the game HUD
pub fn drawHUD(
    ui: *ui_mod.Context,
    sandbox: *const game.SandboxGame,
    screen_width: u32,
    screen_height: u32,
) void {
    // Crosshair
    drawCrosshair(ui, screen_width, screen_height);

    // Hotbar
    drawHotbar(ui, sandbox, screen_width, screen_height);

    // Debug info
    if (sandbox.show_debug) {
        drawDebugOverlay(ui, sandbox);
    }
}

/// Draw crosshair in center of screen
fn drawCrosshair(ui: *ui_mod.Context, width: u32, height: u32) void {
    const cx: i32 = @intCast(width / 2);
    const cy: i32 = @intCast(height / 2);
    const size: i32 = 10;
    const thickness: i32 = 2;

    const color = render.Color.WHITE;

    // Horizontal line
    var y = cy - thickness / 2;
    while (y < cy + thickness / 2) : (y += 1) {
        var x = cx - size;
        while (x <= cx + size) : (x += 1) {
            if (x < cx - 2 or x > cx + 2) {
                ui.renderer.drawPixel(x, y, 0, color);
            }
        }
    }

    // Vertical line
    var x = cx - thickness / 2;
    while (x < cx + thickness / 2) : (x += 1) {
        y = cy - size;
        while (y <= cy + size) : (y += 1) {
            if (y < cy - 2 or y > cy + 2) {
                ui.renderer.drawPixel(x, y, 0, color);
            }
        }
    }
}

/// Draw hotbar at bottom of screen
fn drawHotbar(ui: *ui_mod.Context, sandbox: *const game.SandboxGame, width: u32, height: u32) void {
    const slot_size: i32 = 40;
    const slot_padding: i32 = 4;
    const total_width = 9 * slot_size + 8 * slot_padding;
    const start_x: i32 = @as(i32, @intCast(width / 2)) - total_width / 2;
    const start_y: i32 = @as(i32, @intCast(height)) - slot_size - 10;

    for (0..9) |i| {
        const x = start_x + @as(i32, @intCast(i)) * (slot_size + slot_padding);
        const y = start_y;

        // Slot background
        const is_selected = i == sandbox.hotbar_index;
        const bg_color = if (is_selected)
            render.Color.fromRgba(100, 100, 100, 200)
        else
            render.Color.fromRgba(50, 50, 50, 150);

        drawFilledRect(ui.renderer, x, y, slot_size, slot_size, bg_color);

        // Block preview
        const block = sandbox.hotbar[i];
        const block_color_arr = block.getColor();
        const block_color = render.Color{
            .r = block_color_arr[0],
            .g = block_color_arr[1],
            .b = block_color_arr[2],
            .a = block_color_arr[3],
        };

        const inner_padding: i32 = 6;
        drawFilledRect(
            ui.renderer,
            x + inner_padding,
            y + inner_padding,
            slot_size - inner_padding * 2,
            slot_size - inner_padding * 2,
            block_color,
        );

        // Selection border
        if (is_selected) {
            drawRectOutline(ui.renderer, x, y, slot_size, slot_size, render.Color.WHITE);
        }
    }
}

/// Draw debug overlay
fn drawDebugOverlay(ui: *ui_mod.Context, sandbox: *const game.SandboxGame) void {
    const info = sandbox.getDebugInfo();
    // ui is used for drawing below

    // Simple text-less debug for now (text rendering would need font support)
    // The debug info struct is available for future text rendering

    // Draw position indicator bar (X position as horizontal bar)
    const bar_x: i32 = 10;
    const bar_y: i32 = 10;
    const bar_width: i32 = 200;
    const bar_height: i32 = 4;

    // X position bar
    const x_ratio = std.math.clamp((info.position.x() + 100) / 200, 0, 1);
    const x_fill: i32 = @intFromFloat(@as(f32, @floatFromInt(bar_width)) * x_ratio);
    drawFilledRect(ui.renderer, bar_x, bar_y, bar_width, bar_height, render.Color.fromRgba(50, 50, 50, 150));
    drawFilledRect(ui.renderer, bar_x, bar_y, x_fill, bar_height, render.Color.fromRgb(255, 100, 100));

    // Y position bar
    const y_ratio = std.math.clamp((info.position.y() + 50) / 100, 0, 1);
    const y_fill: i32 = @intFromFloat(@as(f32, @floatFromInt(bar_width)) * y_ratio);
    drawFilledRect(ui.renderer, bar_x, bar_y + 8, bar_width, bar_height, render.Color.fromRgba(50, 50, 50, 150));
    drawFilledRect(ui.renderer, bar_x, bar_y + 8, y_fill, bar_height, render.Color.fromRgb(100, 255, 100));

    // Z position bar
    const z_ratio = std.math.clamp((info.position.z() + 100) / 200, 0, 1);
    const z_fill: i32 = @intFromFloat(@as(f32, @floatFromInt(bar_width)) * z_ratio);
    drawFilledRect(ui.renderer, bar_x, bar_y + 16, bar_width, bar_height, render.Color.fromRgba(50, 50, 50, 150));
    drawFilledRect(ui.renderer, bar_x, bar_y + 16, z_fill, bar_height, render.Color.fromRgb(100, 100, 255));

    // Grounded indicator
    const grounded_color = if (info.grounded) render.Color.fromRgb(100, 255, 100) else render.Color.fromRgb(255, 100, 100);
    drawFilledRect(ui.renderer, bar_x, bar_y + 28, 20, 20, grounded_color);
}

/// Helper to draw filled rectangle
fn drawFilledRect(renderer: *render.Renderer, x: i32, y: i32, w: i32, h: i32, color: render.Color) void {
    var py = y;
    while (py < y + h) : (py += 1) {
        var px = x;
        while (px < x + w) : (px += 1) {
            renderer.drawPixel(px, py, 0, color);
        }
    }
}

/// Helper to draw rectangle outline
fn drawRectOutline(renderer: *render.Renderer, x: i32, y: i32, w: i32, h: i32, color: render.Color) void {
    // Top and bottom
    var px = x;
    while (px < x + w) : (px += 1) {
        renderer.drawPixel(px, y, 0, color);
        renderer.drawPixel(px, y + h - 1, 0, color);
    }
    // Left and right
    var py = y;
    while (py < y + h) : (py += 1) {
        renderer.drawPixel(x, py, 0, color);
        renderer.drawPixel(x + w - 1, py, 0, color);
    }
}
