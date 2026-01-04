//! Game UI - HUD, menus, and overlays for gameplay mode.
//!
//! This module provides UI components specifically for the game/survival mode,
//! including HUD display, win screens, progress bars, and game-specific
//! interactive elements.

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
        } else |err| {
            std.log.warn("Failed to load UI config from '{s}': {}, using defaults", .{ ui_mod.UiConfig.DEFAULT_PATH, err });
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

const shared_ui = @import("shared_ui.zig");

// HUD panel drawing moved to shared_ui.zig for code deduplication
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
            // Safely convert nanoseconds to seconds with overflow protection
            // Use @divTrunc which handles large values correctly
            const modified_seconds: i64 = @divTrunc(game_state.file_info.modified_ns, std.time.ns_per_s);
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

pub fn drawUI(
    game_state: *const game_state_module.GameState,
    ui_state: *GameUiState,
    status_message: *StatusMessage,
    allocator: std.mem.Allocator,
    screen_width: f32,
    screen_height: f32,
) !void {
    try drawHudPanel(game_state, ui_state, screen_width, screen_height);
    try shared_ui.drawSettingsPanel(ui_state, status_message, allocator, screen_width, screen_height);
    shared_ui.applyDocking(ui_state, status_message);
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
