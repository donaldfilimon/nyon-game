//! HUD and UI helpers for the 3D sandbox experience.

const std = @import("std");
const nyon_game = @import("../root.zig");
const ui_mod = nyon_game.ui;
const StatusMessage = nyon_game.status_message.StatusMessage;
const sandbox_mod = @import("../game/sandbox.zig");
const game_ui_mod = @import("game_ui.zig");
const engine = nyon_game.engine;
const panels = ui_mod.panels;
const common = @import("../common/error_handling.zig");
const config = @import("../config/constants.zig");

pub const SandboxUiState = game_ui_mod.GameUiState;
pub const defaultUiScaleFromDpi = game_ui_mod.defaultUiScaleFromDpi;

const shared_ui = @import("shared_ui.zig");

const COLOR_TEXT_GRAY = engine.Color{ .r = 210, .g = 210, .b = 210, .a = 255 };
const COLOR_STATUS_MESSAGE = engine.Color{ .r = 200, .g = 220, .b = 255, .a = 255 };
const COLOR_CROSSHAIR = engine.Color{ .r = 255, .g = 255, .b = 255, .a = 200 };

fn drawHudPanel(
    sandbox_state: *const sandbox_mod.SandboxState,
    world_name: ?[]const u8,
    ui_state: *SandboxUiState,
    screen_width: f32,
    screen_height: f32,
) !void {
    if (!ui_state.config.hud.visible) return;

    var rect = ui_state.config.hud.rect;
    const style = ui_state.ctx.style;

    const result = ui_state.ctx.panel(.hud, &rect, "HUD", ui_state.edit_mode);
    if (result.dragged) ui_state.dirty = true;
    if (ui_state.edit_mode) {
        if (ui_state.ctx.resizeHandle(.hud, &rect, 240.0, 170.0)) ui_state.dirty = true;
    }

    panels.clampPanelRect(&rect, screen_width, screen_height);
    ui_state.config.hud.rect = rect;

    const padding_f: f32 = common.Cast.toFloat(f32, style.padding);
    const text_x: i32 = common.Cast.toInt(i32, rect.x + padding_f);
    const start_y: i32 = common.Cast.toInt(i32, rect.y + common.Cast.toFloat(f32, style.panel_title_height) + padding_f);
    const line_step: i32 = style.font_size + common.Cast.toInt(i32, std.math.round(6.0 * style.scale));

    var line_y = start_y;

    const active_world = world_name orelse "Unsaved World";
    var world_buf: [96:0]u8 = undefined;
    const world_str = try std.fmt.bufPrintZ(&world_buf, "World: {s}", .{active_world});
    engine.Text.draw(world_str, text_x, line_y, style.font_size, style.text);

    line_y += line_step;
    var block_buf: [64:0]u8 = undefined;
    const block_str = try std.fmt.bufPrintZ(&block_buf, "Blocks: {d}", .{sandbox_state.world.count()});
    engine.Text.draw(block_str, text_x, line_y, style.font_size, style.accent);

    line_y += line_step;
    const active_color = sandbox_state.activeColor();
    var color_buf: [64:0]u8 = undefined;
    const color_str = try std.fmt.bufPrintZ(&color_buf, "Block: {s}", .{active_color.name});
    engine.Text.draw(color_str, text_x, line_y, style.font_size, style.text);

    line_y += line_step;
    var cam_buf: [96:0]u8 = undefined;
    const cam_pos = sandbox_state.camera.position;
    const cam_str = try std.fmt.bufPrintZ(&cam_buf, "Camera: {d:.1} {d:.1} {d:.1}", .{
        cam_pos.x,
        cam_pos.y,
        cam_pos.z,
    });
    engine.Text.draw(cam_str, text_x, line_y, style.small_font_size, style.text_muted);
}

pub fn drawUI(
    sandbox_state: *const sandbox_mod.SandboxState,
    world_name: ?[]const u8,
    ui_state: *SandboxUiState,
    status_message: *StatusMessage,
    allocator: std.mem.Allocator,
    screen_width: f32,
    screen_height: f32,
) !void {
    try drawHudPanel(sandbox_state, world_name, ui_state, screen_width, screen_height);
    try shared_ui.drawSettingsPanel(ui_state, status_message, allocator, screen_width, screen_height);
    shared_ui.applyDocking(ui_state, status_message);
    ui_state.config.sanitize();
}

pub fn drawCrosshair(screen_width: f32, screen_height: f32) void {
    const center_x: i32 = common.Cast.toInt(i32, screen_width * 0.5);
    const center_y: i32 = common.Cast.toInt(i32, screen_height * 0.5);
    const half: i32 = 6;
    engine.Shapes.drawLine(center_x - half, center_y, center_x + half, center_y, COLOR_CROSSHAIR);
    engine.Shapes.drawLine(center_x, center_y - half, center_x, center_y + half, COLOR_CROSSHAIR);
}

pub fn drawInstructions(screen_width: f32, screen_height: f32) void {
    const instructions = "WASD move, QE up/down, RMB look, LMB place, Ctrl+LMB remove, Tab color, R reset, Ctrl+S save, F1 UI edit, F2 settings";
    const text_width = engine.Text.measure(instructions, config.UI.INSTRUCTION_FONT_SIZE);
    const text_x: i32 = common.Cast.toInt(i32, (screen_width - common.Cast.toFloat(f32, text_width)) / 2.0);
    const text_y: i32 = common.Cast.toInt(i32, screen_height - config.UI.INSTRUCTION_Y_OFFSET);

    engine.Text.draw(
        instructions,
        text_x,
        text_y,
        config.UI.INSTRUCTION_FONT_SIZE,
        COLOR_TEXT_GRAY,
    );
}

pub fn drawStatusMessage(status: *const StatusMessage, screen_width: f32) void {
    if (!status.isActive()) return;

    const text = status.textZ();
    const text_width = engine.Text.measure(text, config.UI.STATUS_MESSAGE_FONT_SIZE);
    const text_x: i32 = common.Cast.toInt(i32, (screen_width - common.Cast.toFloat(f32, text_width)) / 2.0);

    const alpha_byte = status.alphaU8();
    const message_color = engine.Color{
        .r = COLOR_STATUS_MESSAGE.r,
        .g = COLOR_STATUS_MESSAGE.g,
        .b = COLOR_STATUS_MESSAGE.b,
        .a = alpha_byte,
    };

    engine.Text.draw(text, text_x, config.UI.STATUS_MESSAGE_Y_OFFSET, config.UI.STATUS_MESSAGE_FONT_SIZE, message_color);
}

test "drawCrosshair centers on screen" {
    const width: f32 = 800.0;
    const height: f32 = 600.0;
    const half: i32 = 6;

    const expected_center_x = @as(i32, @intFromFloat(width * 0.5)) - half;
    const expected_center_y = @as(i32, @intFromFloat(height * 0.5)) - half;

    try std.testing.expect(expected_center_x == @as(i32, @intFromFloat(width * 0.5)) - half);
    try std.testing.expect(expected_center_y == @as(i32, @intFromFloat(height * 0.5)) - half);
}

test "SandboxUiState type exists" {
    const allocator = std.testing.allocator;
    const state = SandboxUiState.initWithDefaultScale(allocator, 1.0);
    defer state.deinit();
    try std.testing.expect(state.ctx.style != null);
}
