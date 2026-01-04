//! Shared UI functions for common HUD, settings, and docking behavior.
//!
//! This module provides reusable UI drawing functions that are shared
//! between sandbox mode and game mode, eliminating code duplication.

const std = @import("std");
const nyon_game = @import("../root.zig");
const ui_mod = nyon_game.ui;
const StatusMessage = nyon_game.status_message.StatusMessage;
const panels = ui_mod.panels;
const common = @import("../common/error_handling.zig");
const config = @import("../config/constants.zig");

const GameUiState = @import("game_ui.zig").GameUiState;

/// Draw the shared settings panel with UI options.
/// This panel is used by both sandbox and game modes.
pub fn drawSettingsPanel(
    ui_state: *GameUiState,
    status_message: *StatusMessage,
    allocator: std.mem.Allocator,
    screen_width: f32,
    screen_height: f32,
) !void {
    if (!ui_state.config.settings.visible) return;

    var rect = ui_state.config.settings.rect;
    const style = ui_state.ctx.style;

    const result = ui_state.ctx.panel(.settings, &rect, "Settings", ui_state.edit_mode);
    if (result.dragged) ui_state.dirty = true;
    if (ui_state.edit_mode) {
        if (ui_state.ctx.resizeHandle(.settings, &rect, 240.0, 190.0)) ui_state.dirty = true;
    }

    panels.clampPanelRect(&rect, screen_width, screen_height);
    ui_state.config.settings.rect = rect;

    const pad_f: f32 = common.Cast.toFloat(f32, style.padding);
    const x = rect.x + pad_f;
    var y = rect.y + common.Cast.toFloat(f32, style.panel_title_height) + pad_f;
    const w = rect.width - pad_f * 2.0;

    const row_h: f32 = common.Cast.toFloat(f32, @max(style.small_font_size + 8, 22));

    if (ui_state.edit_mode) {
        nyon_game.engine.Text.draw("UI Edit Mode (F1 to exit)", common.Cast.toInt(i32, x), common.Cast.toInt(i32, y), style.small_font_size, style.accent);
        y += row_h;
    } else {
        nyon_game.engine.Text.draw("Press F1 to edit UI layout", common.Cast.toInt(i32, x), common.Cast.toInt(i32, y), style.small_font_size, style.text_muted);
        y += row_h;
    }

    const show_hud_id: u64 = std.hash.Wyhash.hash(0, "settings_show_hud");
    _ = ui_state.ctx.checkbox(
        show_hud_id,
        nyon_game.engine.Rectangle{ .x = x, .y = y, .width = w, .height = row_h },
        "Show HUD",
        &ui_state.config.hud.visible,
    );
    y += row_h + 6;

    var theme_buf: [32:0]u8 = undefined;
    const theme_label = try std.fmt.bufPrintZ(&theme_buf, "Theme: {s}", .{if (ui_state.config.theme == .dark) "Dark" else "Light"});
    const theme_id: u64 = std.hash.Wyhash.hash(0, "settings_theme");
    if (ui_state.ctx.button(theme_id, nyon_game.engine.Rectangle{ .x = x, .y = y, .width = w, .height = row_h + 6 }, theme_label)) {
        ui_state.config.theme = if (ui_state.config.theme == .dark) .light else .dark;
        ui_state.dirty = true;
    }
    y += row_h + 18;

    const scale_id: u64 = std.hash.Wyhash.hash(0, "settings_scale");
    var scale = ui_state.config.scale;
    if (ui_state.ctx.sliderFloat(scale_id, nyon_game.engine.Rectangle{ .x = x, .y = y, .width = w, .height = 14.0 * style.scale }, "Scale", &scale, 0.6, 2.5)) {
        ui_state.config.scale = scale;
        ui_state.dirty = true;
    }
    y += row_h + 22;

    const opacity_id: u64 = std.hash.Wyhash.hash(0, "settings_opacity");
    var opacity_f: f32 = common.Cast.toFloat(f32, ui_state.config.opacity);
    if (ui_state.ctx.sliderFloat(opacity_id, nyon_game.engine.Rectangle{ .x = x, .y = y, .width = w, .height = 14.0 * style.scale }, "Panel Opacity", &opacity_f, 60.0, 255.0)) {
        const rounded = std.math.round(opacity_f);
        const clamped = if (rounded < 0.0) 0.0 else if (rounded > 255.0) 255.0 else rounded;
        ui_state.config.opacity = common.Cast.toInt(i32, clamped);
        ui_state.dirty = true;
    }
    y += row_h + 18;

    nyon_game.engine.Text.draw("Audio", common.Cast.toInt(i32, x), common.Cast.toInt(i32, y), style.small_font_size, style.accent);
    y += row_h;

    const master_vol_id: u64 = std.hash.Wyhash.hash(0, "settings_master_volume");
    var master_vol = ui_state.config.game.master_volume;
    if (ui_state.ctx.sliderFloat(master_vol_id, nyon_game.engine.Rectangle{ .x = x, .y = y, .width = w, .height = 14.0 * style.scale }, "Master Volume", &master_vol, 0.0, 1.0)) {
        ui_state.config.game.master_volume = master_vol;
        ui_state.dirty = true;
    }
    y += row_h + 6;

    const music_vol_id: u64 = std.hash.Wyhash.hash(0, "settings_music_volume");
    var music_vol = ui_state.config.game.music_volume;
    if (ui_state.ctx.sliderFloat(music_vol_id, nyon_game.engine.Rectangle{ .x = x, .y = y, .width = w, .height = 14.0 * style.scale }, "Music Volume", &music_vol, 0.0, 1.0)) {
        ui_state.config.game.music_volume = music_vol;
        ui_state.dirty = true;
    }
    y += row_h + 6;

    const sfx_vol_id: u64 = std.hash.Wyhash.hash(0, "settings_sfx_volume");
    var sfx_vol = ui_state.config.game.sfx_volume;
    if (ui_state.ctx.sliderFloat(sfx_vol_id, nyon_game.engine.Rectangle{ .x = x, .y = y, .width = w, .height = 14.0 * style.scale }, "SFX Volume", &sfx_vol, 0.0, 1.0)) {
        ui_state.config.game.sfx_volume = sfx_vol;
        ui_state.dirty = true;
    }
    y += row_h + 12;

    nyon_game.engine.Text.draw("Graphics", common.Cast.toInt(i32, x), common.Cast.toInt(i32, y), style.small_font_size, style.accent);
    y += row_h;

    const show_fps_id: u64 = std.hash.Wyhash.hash(0, "settings_show_fps");
    _ = ui_state.ctx.checkbox(
        show_fps_id,
        nyon_game.engine.Rectangle{ .x = x, .y = y, .width = w, .height = row_h },
        "Show FPS",
        &ui_state.config.game.show_fps,
    );
    y += row_h + 6;

    const vsync_id: u64 = std.hash.Wyhash.hash(0, "settings_vsync");
    _ = ui_state.ctx.checkbox(
        vsync_id,
        nyon_game.engine.Rectangle{ .x = x, .y = y, .width = w, .height = row_h },
        "VSync",
        &ui_state.config.game.vsync,
    );
    y += row_h + 6;

    const fullscreen_id: u64 = std.hash.Wyhash.hash(0, "settings_fullscreen");
    _ = ui_state.ctx.checkbox(
        fullscreen_id,
        nyon_game.engine.Rectangle{ .x = x, .y = y, .width = w, .height = row_h },
        "Fullscreen",
        &ui_state.config.game.fullscreen,
    );
    y += row_h + 12;

    nyon_game.engine.Text.draw("Accessibility", common.Cast.toInt(i32, x), common.Cast.toInt(i32, y), style.small_font_size, style.accent);
    y += row_h;

    const high_contrast_id: u64 = std.hash.Wyhash.hash(0, "settings_high_contrast");
    _ = ui_state.ctx.checkbox(
        high_contrast_id,
        nyon_game.engine.Rectangle{ .x = x, .y = y, .width = w, .height = row_h },
        "High Contrast",
        &ui_state.config.game.high_contrast,
    );
    y += row_h + 6;

    const large_text_id: u64 = std.hash.Wyhash.hash(0, "settings_large_text");
    _ = ui_state.ctx.checkbox(
        large_text_id,
        nyon_game.engine.Rectangle{ .x = x, .y = y, .width = w, .height = row_h },
        "Large Text",
        &ui_state.config.game.large_text,
    );
    y += row_h + 6;

    const reduced_motion_id: u64 = std.hash.Wyhash.hash(0, "settings_reduced_motion");
    _ = ui_state.ctx.checkbox(
        reduced_motion_id,
        nyon_game.engine.Rectangle{ .x = x, .y = y, .width = w, .height = row_h },
        "Reduced Motion",
        &ui_state.config.game.reduced_motion,
    );
    y += row_h + 12;

    nyon_game.engine.Text.draw("Fonts", common.Cast.toInt(i32, x), common.Cast.toInt(i32, y), style.small_font_size, style.accent);
    y += row_h;

    const system_font_id: u64 = std.hash.Wyhash.hash(0, "settings_system_font");
    _ = ui_state.ctx.checkbox(
        system_font_id,
        nyon_game.engine.Rectangle{ .x = x, .y = y, .width = w, .height = row_h },
        "Use System Font",
        &ui_state.config.font.use_system_font,
    );
    y += row_h + 6;

    const dpi_scale_id: u64 = std.hash.Wyhash.hash(0, "settings_dpi_scale");
    var dpi_scale = ui_state.config.font.dpi_scale;
    if (ui_state.ctx.sliderFloat(dpi_scale_id, nyon_game.engine.Rectangle{ .x = x, .y = y, .width = w, .height = 14.0 * style.scale }, "DPI Scale", &dpi_scale, 0.5, 2.0)) {
        ui_state.config.font.dpi_scale = dpi_scale;
        ui_state.dirty = true;
    }
    y += row_h + 12;

    const save_id: u64 = std.hash.Wyhash.hash(0, "settings_save");
    const reset_id: u64 = std.hash.Wyhash.hash(0, "settings_reset");
    const half_w = (w - 10.0) / 2.0;
    if (ui_state.ctx.button(save_id, nyon_game.engine.Rectangle{ .x = x, .y = y, .width = half_w, .height = row_h + 8 }, "Save Layout")) {
        if (ui_state.config.save(allocator, ui_mod.UiConfig.DEFAULT_PATH)) |_| {
            ui_state.dirty = false;
            status_message.set("Saved UI layout", config.UI.STATUS_MESSAGE_DURATION);
        } else |err| {
            std.log.err("Failed to save UI layout: {}", .{err});
            status_message.set("Failed to save UI layout", config.UI.STATUS_MESSAGE_DURATION);
            return;
        }
    }
    if (ui_state.ctx.button(reset_id, nyon_game.engine.Rectangle{ .x = x + half_w + 10.0, .y = y, .width = half_w, .height = row_h + 8 }, "Reset")) {
        ui_state.config = ui_mod.UiConfig{};
        ui_state.dirty = true;
        status_message.set("Reset UI layout", config.UI.STATUS_MESSAGE_DURATION);
    }

    if (ui_state.dirty) {
        const note_y: i32 = common.Cast.toInt(i32, rect.y + rect.height - pad_f - common.Cast.toFloat(f32, style.small_font_size));
        nyon_game.engine.Text.draw("Unsaved changes", common.Cast.toInt(i32, x), note_y, style.small_font_size, style.text_muted);
    }
}

/// Apply panel docking functionality when in edit mode.
/// Allows panels to be docked to each other by dragging them together.
pub fn applyDocking(ui_state: *GameUiState, status_message: *StatusMessage) void {
    if (!ui_state.edit_mode) return;
    if (!ui_state.ctx.input.mouse_released) return;

    const active = ui_state.ctx.active_id;
    const hud_active: u64 = panels.getActivePanelId(.hud);
    const settings_active: u64 = panels.getActivePanelId(.settings);

    var moving: ?*ui_mod.PanelConfig = null;
    var target: ?*ui_mod.PanelConfig = null;
    var moving_name: [:0]const u8 = "Panel";

    if (active == hud_active) {
        moving = &ui_state.config.hud;
        target = &ui_state.config.settings;
        moving_name = "HUD";
    } else if (active == settings_active) {
        moving = &ui_state.config.settings;
        target = &ui_state.config.hud;
        moving_name = "Settings";
    } else {
        return;
    }

    const mouse = ui_state.ctx.input.mouse_pos;
    const target_rect = target.?.rect;
    const over_target = mouse.x >= target_rect.x and mouse.y >= target_rect.y and mouse.x <= target_rect.x + target_rect.width and mouse.y <= target_rect.y + target_rect.height;
    if (!over_target) return;

    const position = panels.detectDockPosition(mouse.x, mouse.y, target_rect, .{}) orelse return;

    panels.splitDockPanels(moving.?, target.?, position);
    ui_state.dirty = true;

    var msg_buf: [96:0]u8 = undefined;
    const pos_str: [:0]const u8 = switch (position) {
        .left => "left",
        .right => "right",
        .top => "top",
        .bottom => "bottom",
    };
    const msg = std.fmt.bufPrintZ(&msg_buf, "Docked {s} {s}", .{ moving_name, pos_str }) catch "Docked panel";
    status_message.set(msg, config.UI.STATUS_MESSAGE_DURATION);
}
