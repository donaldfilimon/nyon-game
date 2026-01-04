const std = @import("std");
const math = std.math;
const nyon_game = @import("../root.zig");
const ui_mod = nyon_game.ui;
const StatusMessage = nyon_game.status_message.StatusMessage;
const FontManager = nyon_game.font_manager.FontManager;
const game_state_module = @import("../game/state.zig");
const panels = ui_mod.panels;

const GRID_SIZE: f32 = 50.0;

const UI_INSTRUCTION_FONT_SIZE: i32 = 16;
const UI_INSTRUCTION_Y_OFFSET: i32 = 30;
const UI_WIN_FONT_SIZE: i32 = 40;
const UI_WIN_Y_OFFSET: i32 = 20;
const UI_PROGRESS_HEIGHT: f32 = 10.0;
const STATUS_MESSAGE_FONT_SIZE: i32 = 18;
const STATUS_MESSAGE_DURATION: f32 = 3.0;
const STATUS_MESSAGE_Y_OFFSET: i32 = 8;

pub const COLOR_BACKGROUND = nyon_game.engine.Color{ .r = 30, .g = 30, .b = 50, .a = 255 };
const COLOR_GRID = nyon_game.engine.Color{ .r = 40, .g = 40, .b = 60, .a = 255 };
const COLOR_ITEM = nyon_game.engine.Color{ .r = 255, .g = 215, .b = 0, .a = 255 };
const COLOR_ITEM_OUTLINE = nyon_game.engine.Color{ .r = 255, .g = 255, .b = 100, .a = 255 };
const COLOR_PLAYER_IDLE = nyon_game.engine.Color{ .r = 150, .g = 150, .b = 255, .a = 255 };
const COLOR_PLAYER_MOVING = nyon_game.engine.Color{ .r = 100, .g = 200, .b = 255, .a = 255 };
const COLOR_PLAYER_OUTLINE = nyon_game.engine.Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
const COLOR_WIN = nyon_game.engine.Color{ .r = 0, .g = 255, .b = 0, .a = 255 };
const COLOR_TEXT_GRAY = nyon_game.engine.Color{ .r = 200, .g = 200, .b = 200, .a = 255 };
const COLOR_PROGRESS_BG = nyon_game.engine.Color{ .r = 60, .g = 60, .b = 80, .a = 255 };
const COLOR_PROGRESS_FILL = nyon_game.engine.Color{ .r = 255, .g = 175, .b = 0, .a = 255 };
const COLOR_STATUS_MESSAGE = nyon_game.engine.Color{ .r = 200, .g = 220, .b = 255, .a = 255 };

pub const GameUiState = struct {
    config: ui_mod.UiConfig,
    ctx: ui_mod.UiContext = ui_mod.UiContext{ .style = ui_mod.UiStyle.fromTheme(.dark, 180, 1.0) },
    edit_mode: bool = false,
    dirty: bool = false,
    font_manager: FontManager,

    pub fn initWithDefaultScale(allocator: std.mem.Allocator, default_scale: f32) GameUiState {
        var cfg = ui_mod.UiConfig{};
        cfg.scale = default_scale;
        cfg.font.dpi_scale = default_scale;

        if (ui_mod.UiConfig.load(allocator, ui_mod.UiConfig.DEFAULT_PATH)) |loaded_cfg| {
            cfg = loaded_cfg;
        } else |_| {
            cfg.sanitize();
        }

        const font_manager = FontManager.init(allocator);

        return .{
            .config = cfg,
            .font_manager = font_manager,
        };
    }

    pub fn style(self: *const GameUiState) ui_mod.UiStyle {
        return ui_mod.UiStyle.fromTheme(self.config.theme, self.config.opacity, self.config.scale);
    }

    pub fn deinit(self: *GameUiState) void {
        self.font_manager.deinit();
    }
};

pub fn defaultUiScaleFromDpi() f32 {
    const scale = nyon_game.engine.Window.getScaleDPI();
    const avg = (scale.x + scale.y) / 2.0;
    if (avg <= 0.0) return 1.0;
    if (avg < 0.6) return 0.6;
    if (avg > 2.5) return 2.5;
    return avg;
}

fn drawHudPanel(game_state: *const game_state_module.GameState, ui_state: *GameUiState, screen_width: f32, screen_height: f32) !void {
    if (!ui_state.config.hud.visible) return;

    var rect = ui_state.config.hud.rect;
    const style = ui_state.ctx.style;

    const result = ui_state.ctx.panel(.hud, &rect, "HUD", ui_state.edit_mode);
    if (result.dragged) ui_state.dirty = true;
    if (ui_state.edit_mode) {
        if (ui_state.ctx.resizeHandle(.hud, &rect, 220.0, 160.0)) ui_state.dirty = true;
    }

    panels.clampPanelRect(&rect, screen_width, screen_height);
    ui_state.config.hud.rect = rect;

    const padding_f: f32 = @floatFromInt(style.padding);
    const text_x: i32 = @intFromFloat(rect.x + padding_f);
    const start_y: i32 = @intFromFloat(rect.y + @as(f32, @floatFromInt(style.panel_title_height)) + padding_f);
    const line_step: i32 = style.font_size + @as(i32, @intFromFloat(std.math.round(6.0 * style.scale)));

    var line_y = start_y;

    var score_buf: [64:0]u8 = undefined;
    const score_str = try std.fmt.bufPrintZ(&score_buf, "Score {:>4}", .{game_state.score});
    nyon_game.engine.Text.draw(score_str, text_x, line_y, style.font_size, style.text);

    line_y += line_step;
    var remaining_buf: [64:0]u8 = undefined;
    const remaining_str = try std.fmt.bufPrintZ(&remaining_buf, "Remaining: {d}", .{game_state.remaining_items});
    nyon_game.engine.Text.draw(remaining_str, text_x, line_y, style.font_size, style.accent);

    line_y += line_step;
    var best_buf: [64:0]u8 = undefined;
    const best_str = try std.fmt.bufPrintZ(&best_buf, "Best: {d}", .{game_state.best_score});
    nyon_game.engine.Text.draw(best_str, text_x, line_y, style.font_size, style.text);

    line_y += line_step;
    var time_buf: [48:0]u8 = undefined;
    const time_str = try std.fmt.bufPrintZ(&time_buf, "Time {d:.1}s", .{game_state.game_time});
    nyon_game.engine.Text.draw(time_str, text_x, line_y, style.font_size, style.text_muted);

    line_y += line_step;
    if (game_state.best_time) |fastest| {
        var fastest_buf: [64:0]u8 = undefined;
        const fastest_str = try std.fmt.bufPrintZ(&fastest_buf, "Fastest {d:.1}s", .{fastest});
        nyon_game.engine.Text.draw(fastest_str, text_x, line_y, style.font_size, style.accent);
    } else {
        nyon_game.engine.Text.draw("Fastest --", text_x, line_y, style.font_size, style.accent);
    }

    if (game_state.file_info.hasFile()) {
        line_y += line_step;
        var path_buf: [220:0]u8 = undefined;
        const path_str = try std.fmt.bufPrintZ(&path_buf, "Loaded: {s}", .{game_state.file_info.path()});
        nyon_game.engine.Text.draw(path_str, text_x, line_y, style.small_font_size, style.text);

        line_y += style.small_font_size + @as(i32, @intFromFloat(std.math.round(6.0 * style.scale)));
        var info_buf: [128:0]u8 = undefined;
        if (game_state.file_info.has_time) {
            const modified_seconds: i64 = @intCast(@divTrunc(game_state.file_info.modified_ns, std.time.ns_per_s));
            const info_str = try std.fmt.bufPrintZ(&info_buf, "Size {d}b · Modified {d}", .{ game_state.file_info.size, modified_seconds });
            nyon_game.engine.Text.draw(info_str, text_x, line_y, style.small_font_size, style.text_muted);
        } else {
            const info_str = try std.fmt.bufPrintZ(&info_buf, "Size {d}b", .{game_state.file_info.size});
            nyon_game.engine.Text.draw(info_str, text_x, line_y, style.small_font_size, style.text_muted);
        }
    }

    const prog_h = UI_PROGRESS_HEIGHT * style.scale;
    const prog_x = rect.x + padding_f;
    const prog_w = rect.width - padding_f * 2.0;
    const prog_y = rect.y + rect.height - padding_f - prog_h;
    const progress_bg = nyon_game.engine.Rectangle{ .x = prog_x, .y = prog_y, .width = prog_w, .height = prog_h };
    nyon_game.engine.Shapes.drawRectangleRec(progress_bg, COLOR_PROGRESS_BG);

    const remaining_float: f32 = @floatFromInt(game_state.remaining_items);
    const total_float: f32 = @floatFromInt(game_state_module.DEFAULT_ITEM_COUNT);
    const raw_ratio = if (game_state.remaining_items == 0) 1.0 else 1.0 - remaining_float / total_float;
    const fill_ratio = if (raw_ratio < 0.0) 0.0 else if (raw_ratio > 1.0) 1.0 else raw_ratio;
    const fill_w = prog_w * fill_ratio;
    if (fill_w > 0.0) {
        nyon_game.engine.Shapes.drawRectangleRec(nyon_game.engine.Rectangle{ .x = prog_x, .y = prog_y, .width = fill_w, .height = prog_h }, style.accent);
    }

    const fps_y: i32 = @as(i32, @intFromFloat(prog_y)) - @as(i32, @intFromFloat(std.math.round(10.0 * style.scale)));
    nyon_game.engine.Text.drawFPS(text_x, fps_y);
}

fn drawSettingsPanel(ui_state: *GameUiState, status_message: *StatusMessage, allocator: std.mem.Allocator, screen_width: f32, screen_height: f32) !void {
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

fn applyDocking(ui_state: *GameUiState, status_message: *StatusMessage) void {
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
    status_message.set(msg, STATUS_MESSAGE_DURATION);
}

pub fn drawUI(
    game_state: *const game_state_module.GameState,
    ui_state: *GameUiState,
    status_message: *StatusMessage,
    allocator: std.mem.Allocator,
    screen_width: f32,
    screen_height: f32,
) !void {
    try drawHudPanel(game_state, ui_state, screen_width, screen_height);
    try drawSettingsPanel(ui_state, status_message, allocator, screen_width, screen_height);
    applyDocking(ui_state, status_message);
    ui_state.config.sanitize();
}

pub fn drawInstructions(screen_width: f32, screen_height: f32) void {
    const instructions = "WASD / Arrows move — R restart — F1 edit UI — F2 settings — Drop files (or nyon_ui.json)";
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

pub fn drawWinMessage(screen_width: f32, screen_height: f32) void {
    const win_text = "YOU WIN!";
    const win_width = nyon_game.engine.Text.measure(win_text, UI_WIN_FONT_SIZE);
    const win_x = @as(i32, @intFromFloat((screen_width - @as(f32, @floatFromInt(win_width))) / 2.0));
    const win_y = @as(i32, @intFromFloat(screen_height / 2.0 - UI_WIN_Y_OFFSET));

    nyon_game.engine.Text.draw(
        win_text,
        win_x,
        win_y,
        UI_WIN_FONT_SIZE,
        COLOR_WIN,
    );

    const hint_text = "Press R to replay";
    const hint_width = nyon_game.engine.Text.measure(hint_text, UI_INSTRUCTION_FONT_SIZE);
    const hint_x = @as(i32, @intFromFloat((screen_width - @as(f32, @floatFromInt(hint_width))) / 2.0));
    const hint_y = win_y + UI_WIN_FONT_SIZE + 10;
    nyon_game.engine.Text.draw(
        hint_text,
        hint_x,
        hint_y,
        UI_INSTRUCTION_FONT_SIZE,
        COLOR_TEXT_GRAY,
    );
}
