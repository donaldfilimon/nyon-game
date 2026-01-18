//! Game HUD
//!
//! Heads-up display for sandbox gameplay.

const std = @import("std");
const math = @import("../math/math.zig");
const render = @import("../render/render.zig");
const ui_mod = @import("ui.zig");
const text = @import("text.zig");
const game = @import("../game/sandbox.zig");

/// Crosshair target type for color selection
pub const CrosshairTarget = enum {
    none,
    block,
    entity,
};

/// Extra debug info passed to HUD
pub const DebugStats = struct {
    fps: f64 = 0,
    frame_time_ms: f64 = 0,
    entity_count: u32 = 0,
};

/// Draw the game HUD (legacy - defaults to no entity targeting)
pub fn drawHUD(
    ui: *ui_mod.Context,
    sandbox: *const game.SandboxGame,
    screen_width: u32,
    screen_height: u32,
) void {
    drawHUDWithEntityTarget(ui, sandbox, screen_width, screen_height, false, null);
}

/// Draw the game HUD with entity targeting info
pub fn drawHUDWithEntityTarget(
    ui: *ui_mod.Context,
    sandbox: *const game.SandboxGame,
    screen_width: u32,
    screen_height: u32,
    targeting_entity: bool,
    debug_stats: ?DebugStats,
) void {
    // Crosshair (changes color based on target type)
    const target: CrosshairTarget = if (targeting_entity)
        .entity
    else if (sandbox.target_block != null)
        .block
    else
        .none;
    drawCrosshair(ui, screen_width, screen_height, target);

    // Hotbar
    drawHotbar(ui, sandbox, screen_width, screen_height);

    // Health and hunger bars
    drawStatusBars(ui, sandbox, screen_width, screen_height);

    // Time display (top right)
    drawTimeDisplay(ui, sandbox, screen_width);

    // Inventory hint
    if (!sandbox.inventory_open) {
        text.drawText(ui.renderer, &text.default_font, "E: Inventory", 10, @as(i32, @intCast(screen_height)) - 25, .{
            .color = render.Color.fromRgba(200, 200, 200, 150),
        });
    }

    // Debug info
    if (sandbox.show_debug) {
        drawDebugOverlay(ui, sandbox, screen_width, screen_height, debug_stats);
    }
}

/// Draw health and hunger status bars
fn drawStatusBars(ui: *ui_mod.Context, sandbox: *const game.SandboxGame, width: u32, height: u32) void {
    const bar_width: i32 = 160;
    const bar_height: i32 = 8;
    const padding: i32 = 10;
    const start_x: i32 = @as(i32, @intCast(width / 2)) - bar_width - 20;
    const start_y: i32 = @as(i32, @intCast(height)) - 60;

    // Health bar (left side of hotbar)
    const health_percent = sandbox.health / sandbox.max_health;
    const health_fill: i32 = @intFromFloat(@as(f32, @floatFromInt(bar_width)) * health_percent);

    // Health background
    drawFilledRect(ui.renderer, start_x, start_y, bar_width, bar_height, render.Color.fromRgba(60, 20, 20, 200));
    // Health fill
    drawFilledRect(ui.renderer, start_x, start_y, health_fill, bar_height, render.Color.fromRgb(200, 50, 50));
    // Health outline
    drawRectOutline(ui.renderer, start_x, start_y, bar_width, bar_height, render.Color.fromRgb(100, 40, 40));

    // Heart icon
    text.drawText(ui.renderer, &text.default_font, "<3", start_x - 20, start_y - 1, .{
        .color = render.Color.fromRgb(255, 100, 100),
    });

    // Hunger bar (right side of hotbar)
    const hunger_x: i32 = @as(i32, @intCast(width / 2)) + 20;
    const hunger_percent = sandbox.hunger / sandbox.max_hunger;
    const hunger_fill: i32 = @intFromFloat(@as(f32, @floatFromInt(bar_width)) * hunger_percent);

    // Hunger background
    drawFilledRect(ui.renderer, hunger_x, start_y, bar_width, bar_height, render.Color.fromRgba(60, 40, 20, 200));
    // Hunger fill (changes color based on level)
    const hunger_color = if (hunger_percent > 0.5)
        render.Color.fromRgb(180, 120, 50)
    else if (hunger_percent > 0.25)
        render.Color.fromRgb(200, 100, 30)
    else
        render.Color.fromRgb(150, 60, 20);
    drawFilledRect(ui.renderer, hunger_x, start_y, hunger_fill, bar_height, hunger_color);
    // Hunger outline
    drawRectOutline(ui.renderer, hunger_x, start_y, bar_width, bar_height, render.Color.fromRgb(100, 60, 30));

    // Hunger icon (drumstick-ish)
    text.drawText(ui.renderer, &text.default_font, "~o", hunger_x + bar_width + 5, start_y - 1, .{
        .color = render.Color.fromRgb(200, 150, 80),
    });

    // Experience bar (above hotbar, spanning full width)
    const xp_bar_width: i32 = bar_width * 2 + 40; // Span between health and hunger
    const xp_bar_height: i32 = 4;
    const xp_bar_x: i32 = @as(i32, @intCast(width / 2)) - @divFloor(xp_bar_width, 2);
    const xp_bar_y: i32 = start_y + bar_height + 4;

    const xp_progress = sandbox.getExperienceProgress();
    const xp_fill: i32 = @intFromFloat(@as(f32, @floatFromInt(xp_bar_width)) * xp_progress);

    // XP background
    drawFilledRect(ui.renderer, xp_bar_x, xp_bar_y, xp_bar_width, xp_bar_height, render.Color.fromRgba(20, 40, 20, 200));
    // XP fill (green)
    if (xp_fill > 0) {
        drawFilledRect(ui.renderer, xp_bar_x, xp_bar_y, xp_fill, xp_bar_height, render.Color.fromRgb(80, 200, 80));
    }
    // XP outline
    drawRectOutline(ui.renderer, xp_bar_x, xp_bar_y, xp_bar_width, xp_bar_height, render.Color.fromRgb(40, 80, 40));

    // Level display (centered above XP bar)
    if (sandbox.experience_level > 0) {
        var level_buf: [8]u8 = undefined;
        const level_str = std.fmt.bufPrint(&level_buf, "{}", .{sandbox.experience_level}) catch "?";
        const level_width = @as(i32, @intCast(level_str.len * 8));
        text.drawText(ui.renderer, &text.default_font, level_str, @as(i32, @intCast(width / 2)) - @divFloor(level_width, 2), xp_bar_y - 12, .{
            .color = render.Color.fromRgb(120, 255, 120),
        });
    }

    _ = padding;
}

/// Draw crosshair in center of screen
/// Changes color based on target type: gray (none), white (block), red (entity)
fn drawCrosshair(ui: *ui_mod.Context, width: u32, height: u32, target: CrosshairTarget) void {
    const cx: i32 = @intCast(width / 2);
    const cy: i32 = @intCast(height / 2);
    const size: i32 = 10;
    const thickness: i32 = 2;

    // Color based on target type
    const color = switch (target) {
        .none => render.Color.fromRgb(180, 180, 180), // Gray
        .block => render.Color.WHITE, // White
        .entity => render.Color.fromRgb(255, 80, 80), // Red for entities
    };

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

    // Draw center dot when targeting something
    if (target != .none) {
        const dot_color = switch (target) {
            .none => render.Color.fromRgb(180, 180, 180),
            .block => render.Color.fromRgb(255, 200, 100), // Orange for blocks
            .entity => render.Color.fromRgb(255, 50, 50), // Bright red for entities
        };
        ui.renderer.drawPixel(cx, cy, 0, dot_color);
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

        // Check inventory for item in this slot
        const inv_slot = sandbox.inventory.slots[i];
        if (inv_slot) |stack| {
            // Draw item from inventory
            const item_color = getItemDisplayColor(stack);
            const inner_padding: i32 = 6;
            drawFilledRect(
                ui.renderer,
                x + inner_padding,
                y + inner_padding,
                slot_size - inner_padding * 2,
                slot_size - inner_padding * 2,
                item_color,
            );

            // Draw durability bar for tools
            if (stack.durability != null) {
                const dur_percent = stack.getDurabilityPercent();
                const bar_width: i32 = @intFromFloat(@as(f32, @floatFromInt(slot_size - inner_padding * 2)) * dur_percent);
                const bar_y = y + slot_size - inner_padding - 3;

                // Background
                drawFilledRect(ui.renderer, x + inner_padding, bar_y, slot_size - inner_padding * 2, 2, render.Color.fromRgb(40, 40, 40));
                // Fill (green to red)
                const r: u8 = @intFromFloat(255.0 * (1.0 - dur_percent));
                const g: u8 = @intFromFloat(255.0 * dur_percent);
                drawFilledRect(ui.renderer, x + inner_padding, bar_y, bar_width, 2, render.Color.fromRgb(r, g, 0));
            }

            // Draw count (if more than 1)
            if (stack.count > 1) {
                var count_buf: [3]u8 = undefined;
                const count_len = formatCount(stack.count, &count_buf);
                text.drawText(ui.renderer, &text.default_font, count_buf[0..count_len], x + slot_size - 8 * @as(i32, @intCast(count_len)), y + slot_size - 12, .{
                    .color = render.Color.WHITE,
                });
            }
        } else {
            // Fallback to legacy block display
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
        }

        // Selection border
        if (is_selected) {
            drawRectOutline(ui.renderer, x, y, slot_size, slot_size, render.Color.WHITE);
            drawRectOutline(ui.renderer, x + 1, y + 1, slot_size - 2, slot_size - 2, render.Color.WHITE);
        }

        // Slot number
        var num_buf: [1]u8 = undefined;
        num_buf[0] = '1' + @as(u8, @intCast(i));
        text.drawText(ui.renderer, &text.default_font, &num_buf, x + 3, y + 2, .{
            .color = if (is_selected) render.Color.WHITE else render.Color.fromRgb(150, 150, 150),
        });
    }
}

/// Get display color for an item stack
fn getItemDisplayColor(stack: game.ItemStack) render.Color {
    const item = stack.getItem() orelse return render.Color.fromRgb(100, 100, 100);

    // For blocks, use block color
    if (item.block_type) |block| {
        const c = block.getColor();
        return render.Color{ .r = c[0], .g = c[1], .b = c[2], .a = c[3] };
    }

    // For other items, use type-based colors
    return switch (item.item_type) {
        .tool => render.Color.fromRgb(160, 120, 80),
        .weapon => render.Color.fromRgb(180, 80, 80),
        .armor => render.Color.fromRgb(100, 100, 140),
        .food => render.Color.fromRgb(200, 150, 100),
        .material => render.Color.fromRgb(140, 140, 100),
        .special => render.Color.fromRgb(200, 180, 255),
        .block => render.Color.fromRgb(100, 100, 100),
    };
}

/// Format count as string
fn formatCount(n: u32, buf: []u8) usize {
    if (n >= 100) {
        buf[0] = '0' + @as(u8, @intCast((n / 100) % 10));
        buf[1] = '0' + @as(u8, @intCast((n / 10) % 10));
        buf[2] = '0' + @as(u8, @intCast(n % 10));
        return 3;
    } else if (n >= 10) {
        buf[0] = '0' + @as(u8, @intCast((n / 10) % 10));
        buf[1] = '0' + @as(u8, @intCast(n % 10));
        return 2;
    } else {
        buf[0] = '0' + @as(u8, @intCast(n % 10));
        return 1;
    }
}

/// Draw time display in top-right corner
fn drawTimeDisplay(ui: *ui_mod.Context, sandbox: *const game.SandboxGame, screen_width: u32) void {
    const info = sandbox.getDebugInfo();
    const padding: i32 = 10;
    const box_w: i32 = 60;
    const box_h: i32 = 20;
    const x: i32 = @as(i32, @intCast(screen_width)) - box_w - padding;
    const y: i32 = padding;

    // Background
    const bg_color = if (info.is_night)
        render.Color.fromRgba(20, 20, 40, 180)
    else
        render.Color.fromRgba(60, 80, 120, 180);
    drawFilledRect(ui.renderer, x, y, box_w, box_h, bg_color);

    // Time text
    text.drawText(ui.renderer, &text.default_font, &info.time_string, x + 10, y + 5, .{
        .color = render.Color.WHITE,
    });

    // Day/night indicator icon
    const icon_x = x + box_w - 15;
    const icon_y = y + 5;
    if (info.is_night) {
        // Moon icon (simple circle)
        drawFilledRect(ui.renderer, icon_x, icon_y, 8, 8, render.Color.fromRgb(200, 200, 255));
    } else {
        // Sun icon (simple circle)
        drawFilledRect(ui.renderer, icon_x, icon_y, 8, 8, render.Color.fromRgb(255, 220, 100));
    }
}

/// Draw debug overlay with detailed information
fn drawDebugOverlay(ui: *ui_mod.Context, sandbox: *const game.SandboxGame, screen_width: u32, screen_height: u32, debug_stats: ?DebugStats) void {
    _ = screen_height;
    _ = screen_width;
    const info = sandbox.getDebugInfo();

    const panel_x: i32 = 10;
    const panel_y: i32 = 10;
    const panel_w: i32 = 240;
    const line_h: i32 = 12;
    var y: i32 = panel_y;

    // Panel background (increased height for all info)
    drawFilledRect(ui.renderer, panel_x, panel_y, panel_w, line_h * 22, render.Color.fromRgba(0, 0, 0, 180));

    // Title with FPS
    text.drawText(ui.renderer, &text.default_font, "DEBUG INFO F3", panel_x + 5, y, .{
        .color = render.Color.fromRgb(255, 255, 100),
    });

    // FPS display (right side of title)
    if (debug_stats) |stats| {
        var fps_buf: [16]u8 = undefined;
        const fps_str = std.fmt.bufPrint(&fps_buf, "{d:.0} FPS", .{stats.fps}) catch "? FPS";
        text.drawText(ui.renderer, &text.default_font, fps_str, panel_x + panel_w - 70, y, .{
            .color = if (stats.fps >= 60) render.Color.fromRgb(100, 255, 100) else if (stats.fps >= 30) render.Color.fromRgb(255, 255, 100) else render.Color.fromRgb(255, 100, 100),
        });
    }
    y += line_h + 4;

    // Position with numeric values
    text.drawText(ui.renderer, &text.default_font, "POSITION", panel_x + 5, y, .{
        .color = render.Color.fromRgb(150, 150, 150),
    });
    y += line_h;

    // Numeric position display
    var pos_buf: [32]u8 = undefined;
    const pos_str = std.fmt.bufPrint(&pos_buf, "X:{d:.1} Y:{d:.1} Z:{d:.1}", .{ info.position.x(), info.position.y(), info.position.z() }) catch "???";
    text.drawText(ui.renderer, &text.default_font, pos_str, panel_x + 5, y, .{
        .color = render.Color.WHITE,
    });
    y += line_h;

    // Chunk position
    const chunk_x = @divFloor(@as(i32, @intFromFloat(@floor(info.position.x()))), 16);
    const chunk_z = @divFloor(@as(i32, @intFromFloat(@floor(info.position.z()))), 16);
    var chunk_buf: [24]u8 = undefined;
    const chunk_str = std.fmt.bufPrint(&chunk_buf, "Chunk: {},{}", .{ chunk_x, chunk_z }) catch "???";
    text.drawText(ui.renderer, &text.default_font, chunk_str, panel_x + 5, y, .{
        .color = render.Color.fromRgb(180, 180, 180),
    });
    y += line_h;

    // X position bar
    const bar_w: i32 = 180;
    const bar_h: i32 = 4;
    const x_ratio = std.math.clamp((info.position.x() + 100) / 200, 0, 1);
    const x_fill: i32 = @intFromFloat(@as(f32, @floatFromInt(bar_w)) * x_ratio);
    text.drawText(ui.renderer, &text.default_font, "X", panel_x + 5, y, .{
        .color = render.Color.fromRgb(255, 100, 100),
    });
    drawFilledRect(ui.renderer, panel_x + 20, y + 2, bar_w, bar_h, render.Color.fromRgba(50, 50, 50, 150));
    drawFilledRect(ui.renderer, panel_x + 20, y + 2, x_fill, bar_h, render.Color.fromRgb(255, 100, 100));
    y += line_h;

    // Y position bar
    const y_ratio = std.math.clamp((info.position.y() + 50) / 100, 0, 1);
    const y_fill: i32 = @intFromFloat(@as(f32, @floatFromInt(bar_w)) * y_ratio);
    text.drawText(ui.renderer, &text.default_font, "Y", panel_x + 5, y, .{
        .color = render.Color.fromRgb(100, 255, 100),
    });
    drawFilledRect(ui.renderer, panel_x + 20, y + 2, bar_w, bar_h, render.Color.fromRgba(50, 50, 50, 150));
    drawFilledRect(ui.renderer, panel_x + 20, y + 2, y_fill, bar_h, render.Color.fromRgb(100, 255, 100));
    y += line_h;

    // Z position bar
    const z_ratio = std.math.clamp((info.position.z() + 100) / 200, 0, 1);
    const z_fill: i32 = @intFromFloat(@as(f32, @floatFromInt(bar_w)) * z_ratio);
    text.drawText(ui.renderer, &text.default_font, "Z", panel_x + 5, y, .{
        .color = render.Color.fromRgb(100, 100, 255),
    });
    drawFilledRect(ui.renderer, panel_x + 20, y + 2, bar_w, bar_h, render.Color.fromRgba(50, 50, 50, 150));
    drawFilledRect(ui.renderer, panel_x + 20, y + 2, z_fill, bar_h, render.Color.fromRgb(100, 100, 255));
    y += line_h + 4;

    // Player state
    text.drawText(ui.renderer, &text.default_font, "STATE", panel_x + 5, y, .{
        .color = render.Color.fromRgb(150, 150, 150),
    });
    y += line_h;

    // Flight/Ground mode indicator
    if (info.is_flying) {
        drawFilledRect(ui.renderer, panel_x + 5, y, 12, 12, render.Color.fromRgb(100, 200, 255));
        text.drawText(ui.renderer, &text.default_font, "FLYING F4", panel_x + 22, y + 2, .{
            .color = render.Color.fromRgb(100, 200, 255),
        });
    } else {
        const grounded_color = if (info.grounded) render.Color.fromRgb(100, 255, 100) else render.Color.fromRgb(255, 100, 100);
        drawFilledRect(ui.renderer, panel_x + 5, y, 12, 12, grounded_color);
        text.drawText(ui.renderer, &text.default_font, if (info.grounded) "GROUNDED" else "AIRBORNE", panel_x + 22, y + 2, .{
            .color = render.Color.WHITE,
        });
    }
    y += line_h + 4;

    // World info
    text.drawText(ui.renderer, &text.default_font, "WORLD", panel_x + 5, y, .{
        .color = render.Color.fromRgb(150, 150, 150),
    });
    y += line_h;

    // Chunks loaded (numeric + visual)
    const chunks = info.chunk_count;
    var chunks_buf: [20]u8 = undefined;
    const chunks_str = std.fmt.bufPrint(&chunks_buf, "Chunks: {}", .{chunks}) catch "?";
    text.drawText(ui.renderer, &text.default_font, chunks_str, panel_x + 5, y, .{
        .color = render.Color.fromRgb(100, 200, 100),
    });

    // Visual chunk indicator
    const max_boxes: u32 = 15;
    const boxes_to_draw = @min(chunks / 8, max_boxes);
    var bx: u32 = 0;
    while (bx < boxes_to_draw) : (bx += 1) {
        drawFilledRect(ui.renderer, panel_x + 100 + @as(i32, @intCast(bx)) * 6, y + 2, 5, 8, render.Color.fromRgb(80, 160, 80));
    }
    y += line_h;

    // Entity count
    if (debug_stats) |stats| {
        var ent_buf: [20]u8 = undefined;
        const ent_str = std.fmt.bufPrint(&ent_buf, "Entities: {}", .{stats.entity_count}) catch "?";
        text.drawText(ui.renderer, &text.default_font, ent_str, panel_x + 5, y, .{
            .color = render.Color.fromRgb(200, 150, 100),
        });
    }
    y += line_h;

    // World seed
    var seed_buf: [24]u8 = undefined;
    const seed_str = std.fmt.bufPrint(&seed_buf, "Seed: {}", .{info.world_seed}) catch "?";
    text.drawText(ui.renderer, &text.default_font, seed_str, panel_x + 5, y, .{
        .color = render.Color.fromRgb(150, 150, 150),
    });
    y += line_h + 4;

    // Stats
    text.drawText(ui.renderer, &text.default_font, "STATS", panel_x + 5, y, .{
        .color = render.Color.fromRgb(150, 150, 150),
    });
    y += line_h;

    // Blocks placed/broken indicators
    const placed_bars = @min(info.blocks_placed, 20);
    var pb: u32 = 0;
    while (pb < placed_bars) : (pb += 1) {
        drawFilledRect(ui.renderer, panel_x + 5 + @as(i32, @intCast(pb)) * 6, y, 5, 5, render.Color.fromRgb(100, 200, 100));
    }
    text.drawText(ui.renderer, &text.default_font, "+", panel_x + 130, y - 2, .{
        .color = render.Color.fromRgb(100, 200, 100),
    });
    y += line_h - 2;

    const broken_bars = @min(info.blocks_broken, 20);
    var bb: u32 = 0;
    while (bb < broken_bars) : (bb += 1) {
        drawFilledRect(ui.renderer, panel_x + 5 + @as(i32, @intCast(bb)) * 6, y, 5, 5, render.Color.fromRgb(200, 100, 100));
    }
    text.drawText(ui.renderer, &text.default_font, "-", panel_x + 130, y - 2, .{
        .color = render.Color.fromRgb(200, 100, 100),
    });
    y += line_h + 4;

    // Biome info
    text.drawText(ui.renderer, &text.default_font, "BIOME", panel_x + 5, y, .{
        .color = render.Color.fromRgb(150, 150, 150),
    });
    y += line_h;

    // Biome name with color indicator
    const biome_color = getBiomeColor(info.biome);
    drawFilledRect(ui.renderer, panel_x + 5, y, 12, 12, biome_color);
    text.drawText(ui.renderer, &text.default_font, info.biome.getName(), panel_x + 22, y + 2, .{
        .color = render.Color.WHITE,
    });
}

/// Get color for biome visualization
fn getBiomeColor(biome: game.BiomeType) render.Color {
    return switch (biome) {
        .plains => render.Color.fromRgb(120, 180, 80),
        .forest => render.Color.fromRgb(40, 120, 40),
        .desert => render.Color.fromRgb(220, 200, 120),
        .mountains => render.Color.fromRgb(140, 140, 150),
        .ocean => render.Color.fromRgb(50, 100, 200),
        .beach => render.Color.fromRgb(240, 220, 160),
        .snow => render.Color.fromRgb(240, 245, 255),
        .swamp => render.Color.fromRgb(80, 100, 70),
        .taiga => render.Color.fromRgb(60, 100, 80),
        .savanna => render.Color.fromRgb(180, 160, 80),
    };
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
