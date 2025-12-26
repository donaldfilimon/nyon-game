//! HUD and UI helpers for the 3D sandbox experience.

const std = @import("std");
const nyon_game = @import("../root.zig");
const ui_mod = nyon_game.ui;
const StatusMessage = nyon_game.status_message.StatusMessage;
const sandbox_mod = @import("../game/sandbox.zig");
const game_ui_mod = @import("game_ui.zig");

pub const SandboxUiState = game_ui_mod.GameUiState;
pub const defaultUiScaleFromDpi = game_ui_mod.defaultUiScaleFromDpi;

const UI_INSTRUCTION_FONT_SIZE: i32 = 16;
const UI_INSTRUCTION_Y_OFFSET: i32 = 30;
const STATUS_MESSAGE_FONT_SIZE: i32 = 18;
const STATUS_MESSAGE_DURATION: f32 = 3.0;
const STATUS_MESSAGE_Y_OFFSET: i32 = 8;

const COLOR_TEXT_GRAY = nyon_game.engine.Color{ .r = 210, .g = 210, .b = 210, .a = 255 };
const COLOR_STATUS_MESSAGE = nyon_game.engine.Color{ .r = 200, .g = 220, .b = 255, .a = 255 };
const COLOR_CROSSHAIR = nyon_game.engine.Color{ .r = 255, .g = 255, .b = 255, .a = 200 };

fn clampPanelRect(rect: *nyon_game.engine.Rectangle, screen_width: f32, screen_height: f32) void {
    if (rect.width > screen_width) rect.width = screen_width;
    if (rect.height > screen_height) rect.height = screen_height;

    if (rect.x < 0.0) rect.x = 0.0;
    if (rect.y < 0.0) rect.y = 0.0;

    if (rect.x + rect.width > screen_width) rect.x = screen_width - rect.width;
    if (rect.y + rect.height > screen_height) rect.y = screen_height - rect.height;
}

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

    clampPanelRect(&rect, screen_width, screen_height);
    ui_state.config.hud.rect = rect;

    const padding_f: f32 = @floatFromInt(style.padding);
    const text_x: i32 = @intFromFloat(rect.x + padding_f);
    const start_y: i32 = @intFromFloat(rect.y + @as(f32, @floatFromInt(style.panel_title_height)) + padding_f);
    const line_step: i32 = style.font_size + @as(i32, @intFromFloat(std.math.round(6.0 * style.scale)));

    var line_y = start_y;

    const active_world = world_name orelse "Unsaved World";
    var world_buf: [96:0]u8 = undefined;
    const world_str = try std.fmt.bufPrintZ(&world_buf, "World: {s}", .{active_world});
    nyon_game.engine.Text.draw(world_str, text_x, line_y, style.font_size, style.text);

    line_y += line_step;
    var block_buf: [64:0]u8 = undefined;
    const block_str = try std.fmt.bufPrintZ(&block_buf, "Blocks: {d}", .{sandbox_state.world.count()});
    nyon_game.engine.Text.draw(block_str, text_x, line_y, style.font_size, style.accent);

    line_y += line_step;
    const active_color = sandbox_state.activeColor();
    var color_buf: [64:0]u8 = undefined;
    const color_str = try std.fmt.bufPrintZ(&color_buf, "Block: {s}", .{active_color.name});
    nyon_game.engine.Text.draw(color_str, text_x, line_y, style.font_size, style.text);

    line_y += line_step;
    var cam_buf: [96:0]u8 = undefined;
    const cam_pos = sandbox_state.camera.position;
    const cam_str = try std.fmt.bufPrintZ(&cam_buf, "Camera: {d:.1} {d:.1} {d:.1}", .{
        cam_pos.x,
        cam_pos.y,
        cam_pos.z,
    });
    nyon_game.engine.Text.draw(cam_str, text_x, line_y, style.small_font_size, style.text_muted);
}

fn drawSettingsPanel(
    ui_state: *SandboxUiState,
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

    clampPanelRect(&rect, screen_width, screen_height);
    ui_state.config.settings.rect = rect;

    const pad_f: f32 = @floatFromInt(style.padding);
    const x = rect.x + pad_f;
    var y = rect.y + @as(f32, @floatFromInt(style.panel_title_height)) + pad_f;
    const w = rect.width - pad_f * 2.0;

    const row_h: f32 = @floatFromInt(@max(style.small_font_size + 8, 22));

    if (ui_state.edit_mode) {
        nyon_game.engine.Text.draw("UI Edit Mode (F1 to exit)", @intFromFloat(x), @intFromFloat(y), style.small_font_size, style.accent);
        y += row_h;
    } else {
        nyon_game.engine.Text.draw("Press F1 to edit UI layout", @intFromFloat(x), @intFromFloat(y), style.small_font_size, style.text_muted);
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
    var opacity_f: f32 = @floatFromInt(ui_state.config.opacity);
    if (ui_state.ctx.sliderFloat(opacity_id, nyon_game.engine.Rectangle{ .x = x, .y = y, .width = w, .height = 14.0 * style.scale }, "Panel Opacity", &opacity_f, 60.0, 255.0)) {
        const rounded = std.math.round(opacity_f);
        const clamped = if (rounded < 0.0) 0.0 else if (rounded > 255.0) 255.0 else rounded;
        ui_state.config.opacity = @intFromFloat(clamped);
        ui_state.dirty = true;
    }
    y += row_h + 18;

    nyon_game.engine.Text.draw("Audio", @intFromFloat(x), @intFromFloat(y), style.small_font_size, style.accent);
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

    nyon_game.engine.Text.draw("Graphics", @intFromFloat(x), @intFromFloat(y), style.small_font_size, style.accent);
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

    nyon_game.engine.Text.draw("Accessibility", @intFromFloat(x), @intFromFloat(y), style.small_font_size, style.accent);
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

    nyon_game.engine.Text.draw("Fonts", @intFromFloat(x), @intFromFloat(y), style.small_font_size, style.accent);
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
        ui_state.config.save(allocator, ui_mod.UiConfig.DEFAULT_PATH) catch {
            status_message.set("Failed to save UI layout", STATUS_MESSAGE_DURATION);
            return;
        };
        ui_state.dirty = false;
        status_message.set("Saved UI layout", STATUS_MESSAGE_DURATION);
    }
    if (ui_state.ctx.button(reset_id, nyon_game.engine.Rectangle{ .x = x + half_w + 10.0, .y = y, .width = half_w, .height = row_h + 8 }, "Reset")) {
        ui_state.config = ui_mod.UiConfig{};
        ui_state.dirty = true;
        status_message.set("Reset UI layout", STATUS_MESSAGE_DURATION);
    }

    if (ui_state.dirty) {
        const note_y: i32 = @intFromFloat(rect.y + rect.height - pad_f - @as(f32, @floatFromInt(style.small_font_size)));
        nyon_game.engine.Text.draw("Unsaved changes", @intFromFloat(x), note_y, style.small_font_size, style.text_muted);
    }
}

const DockPosition = enum {
    left,
    right,
    top,
    bottom,
};

fn splitDockPanels(moving: *ui_mod.PanelConfig, target: *ui_mod.PanelConfig, position: DockPosition) void {
    const min_w: f32 = 220.0;
    const min_h: f32 = 160.0;
    const target_rect = target.rect;

    switch (position) {
        .left => {
            const half = @max(min_w, target_rect.width / 2.0);
            moving.rect = nyon_game.engine.Rectangle{
                .x = target_rect.x,
                .y = target_rect.y,
                .width = half,
                .height = target_rect.height,
            };
            target.rect.x = target_rect.x + half;
            target.rect.width = @max(min_w, target_rect.width - half);
        },
        .right => {
            const half = @max(min_w, target_rect.width / 2.0);
            moving.rect = nyon_game.engine.Rectangle{
                .x = target_rect.x + target_rect.width - half,
                .y = target_rect.y,
                .width = half,
                .height = target_rect.height,
            };
            target.rect.width = @max(min_w, target_rect.width - half);
        },
        .top => {
            const half = @max(min_h, target_rect.height / 2.0);
            moving.rect = nyon_game.engine.Rectangle{
                .x = target_rect.x,
                .y = target_rect.y,
                .width = target_rect.width,
                .height = half,
            };
            target.rect.y = target_rect.y + half;
            target.rect.height = @max(min_h, target_rect.height - half);
        },
        .bottom => {
            const half = @max(min_h, target_rect.height / 2.0);
            moving.rect = nyon_game.engine.Rectangle{
                .x = target_rect.x,
                .y = target_rect.y + target_rect.height - half,
                .width = target_rect.width,
                .height = half,
            };
            target.rect.height = @max(min_h, target_rect.height - half);
        },
    }
}

fn applyDocking(ui_state: *SandboxUiState, status_message: *StatusMessage) void {
    if (!ui_state.edit_mode) return;
    if (!ui_state.ctx.input.mouse_released) return;

    const active = ui_state.ctx.active_id;
    const hud_active: u64 = @as(u64, @intFromEnum(ui_mod.PanelId.hud)) + 1;
    const settings_active: u64 = @as(u64, @intFromEnum(ui_mod.PanelId.settings)) + 1;

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

    const rel_x = (mouse.x - target_rect.x) / @max(1.0, target_rect.width);
    const rel_y = (mouse.y - target_rect.y) / @max(1.0, target_rect.height);

    const position: ?DockPosition = if (rel_x < 0.25)
        .left
    else if (rel_x > 0.75)
        .right
    else if (rel_y < 0.25)
        .top
    else if (rel_y > 0.75)
        .bottom
    else
        null;

    if (position == null) return;

    splitDockPanels(moving.?, target.?, position.?);
    ui_state.dirty = true;

    var msg_buf: [96:0]u8 = undefined;
    const pos_str: [:0]const u8 = switch (position.?) {
        .left => "left",
        .right => "right",
        .top => "top",
        .bottom => "bottom",
    };
    const msg = std.fmt.bufPrintZ(&msg_buf, "Docked {s} {s}", .{ moving_name, pos_str }) catch "Docked panel";
    status_message.set(msg, STATUS_MESSAGE_DURATION);
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
    try drawSettingsPanel(ui_state, status_message, allocator, screen_width, screen_height);
    applyDocking(ui_state, status_message);
    ui_state.config.sanitize();
}

pub fn drawCrosshair(screen_width: f32, screen_height: f32) void {
    const center_x: i32 = @intFromFloat(screen_width * 0.5);
    const center_y: i32 = @intFromFloat(screen_height * 0.5);
    const half: i32 = 6;
    nyon_game.engine.Shapes.drawLine(center_x - half, center_y, center_x + half, center_y, COLOR_CROSSHAIR);
    nyon_game.engine.Shapes.drawLine(center_x, center_y - half, center_x, center_y + half, COLOR_CROSSHAIR);
}

pub fn drawInstructions(screen_width: f32, screen_height: f32) void {
    const instructions = "WASD move, QE up/down, RMB look, LMB place, Ctrl+LMB remove, Tab color, R reset, Ctrl+S save, F1 UI edit, F2 settings";
    const text_width = nyon_game.engine.Text.measure(instructions, UI_INSTRUCTION_FONT_SIZE);
    const text_x: i32 = @intFromFloat((screen_width - @as(f32, @floatFromInt(text_width))) / 2.0);
    const text_y: i32 = @intFromFloat(screen_height - UI_INSTRUCTION_Y_OFFSET);

    nyon_game.engine.Text.draw(
        instructions,
        text_x,
        text_y,
        UI_INSTRUCTION_FONT_SIZE,
        COLOR_TEXT_GRAY,
    );
}

pub fn drawStatusMessage(status: *const StatusMessage, screen_width: f32) void {
    if (!status.isActive()) return;

    const text = status.textZ();
    const text_width = nyon_game.engine.Text.measure(text, STATUS_MESSAGE_FONT_SIZE);
    const text_x: i32 = @intFromFloat((screen_width - @as(f32, @floatFromInt(text_width))) / 2.0);

    const alpha_byte = status.alphaU8();
    const message_color = nyon_game.engine.Color{
        .r = COLOR_STATUS_MESSAGE.r,
        .g = COLOR_STATUS_MESSAGE.g,
        .b = COLOR_STATUS_MESSAGE.b,
        .a = alpha_byte,
    };

    nyon_game.engine.Text.draw(text, text_x, STATUS_MESSAGE_Y_OFFSET, STATUS_MESSAGE_FONT_SIZE, message_color);
}
