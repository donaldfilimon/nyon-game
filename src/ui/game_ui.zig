//! Game UI - HUD, menus, and overlays for gameplay mode.
//!
//! This module provides UI components specifically for the game/survival mode,
//! including HUD display, win screens, progress bars, and game-specific
//! interactive elements.

const std = @import("std");
const engine = @import("../engine.zig");
const ui_mod = @import("ui.zig");
const StatusMessage = @import("status_message.zig").StatusMessage;
const FontManager = @import("../font_manager.zig").FontManager;
const game_state_module = @import("../game/state.zig");
const config = @import("../config/constants.zig");



pub const COLOR_BACKGROUND = engine.Color{ .r = 30, .g = 30, .b = 50, .a = 255 };
const COLOR_GRID = engine.Color{ .r = 40, .g = 40, .b = 60, .a = 255 };
const COLOR_ITEM = engine.Color{ .r = 255, .g = 215, .b = 0, .a = 255 };
const COLOR_ITEM_OUTLINE = engine.Color{ .r = 255, .g = 255, .b = 100, .a = 255 };
const COLOR_PLAYER_IDLE = engine.Color{ .r = 150, .g = 150, .b = 255, .a = 255 };
const COLOR_PLAYER_MOVING = engine.Color{ .r = 100, .g = 200, .b = 255, .a = 255 };
const COLOR_PLAYER_OUTLINE = engine.Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
const COLOR_WIN = engine.Color{ .r = 0, .g = 255, .b = 0, .a = 255 };
const COLOR_TEXT_GRAY = engine.Color{ .r = config.Colors.TEXT_MUTED.r, .g = config.Colors.TEXT_MUTED.g, .b = config.Colors.TEXT_MUTED.b, .a = config.Colors.TEXT_MUTED.a };
const COLOR_PROGRESS_BG = engine.Color{ .r = 60, .g = 60, .b = 80, .a = 255 };
const COLOR_PROGRESS_FILL = engine.Color{ .r = 255, .g = 175, .b = 0, .a = 255 };

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
    const scale = engine.Window.getScaleDPI();
    const avg = (scale.x + scale.y) / 2.0;
    if (avg <= 0.0) return 1.0;
    if (avg < config.UI.MIN_SCALE) return config.UI.MIN_SCALE;
    if (avg > config.UI.MAX_SCALE) return config.UI.MAX_SCALE;
    return avg;
}

const shared_ui = @import("shared_ui.zig");

pub fn drawHudPanel(
    game_state: *const game_state_module.GameState,
    ui_state: *GameUiState,
    screen_width: f32,
    screen_height: f32,
) !void {
    const style = ui_state.ctx.style;
    const layout = shared_ui.beginHudPanel(
        ui_state,
        screen_width,
        screen_height,
        config.UI.MIN_PANEL_WIDTH,
        config.UI.MIN_PANEL_HEIGHT,
    ) orelse return;

    const text_x = layout.text_x;
    var line_y = layout.start_y;
    const line_step = layout.line_step;

    var score_buf: [64:0]u8 = undefined;
    const score_str = try std.fmt.bufPrintZ(&score_buf, "Score {:>4}", .{game_state.score});
    engine.Text.draw(score_str, text_x, line_y, style.font_size, style.text);

    line_y += line_step;
    var remaining_buf: [64:0]u8 = undefined;
    const remaining_str = try std.fmt.bufPrintZ(&remaining_buf, "Remaining: {d}", .{game_state.remaining_items});
    engine.Text.draw(remaining_str, text_x, line_y, style.font_size, style.accent);

    line_y += line_step;
    var best_buf: [64:0]u8 = undefined;
    const best_str = try std.fmt.bufPrintZ(&best_buf, "Best: {d}", .{game_state.best_score});
    engine.Text.draw(best_str, text_x, line_y, style.font_size, style.text);

    line_y += line_step;
    var time_buf: [48:0]u8 = undefined;
    const time_str = try std.fmt.bufPrintZ(&time_buf, "Time {d:.1}s", .{game_state.game_time});
    engine.Text.draw(time_str, text_x, line_y, style.font_size, style.text_muted);

    line_y += line_step;
    if (game_state.best_time) |fastest| {
        var fastest_buf: [64:0]u8 = undefined;
        const fastest_str = try std.fmt.bufPrintZ(&fastest_buf, "Fastest {d:.1}s", .{fastest});
        engine.Text.draw(fastest_str, text_x, line_y, style.font_size, style.accent);
    } else {
        engine.Text.draw("Fastest --", text_x, line_y, style.font_size, style.accent);
    }

    if (game_state.file_info.hasFile()) {
        line_y += line_step;
        var path_buf: [220:0]u8 = undefined;
        const path_str = try std.fmt.bufPrintZ(&path_buf, "Loaded: {s}", .{game_state.file_info.path()});
        engine.Text.draw(path_str, text_x, line_y, style.small_font_size, style.text);

        line_y += style.small_font_size + @as(i32, @intFromFloat(std.math.round(6.0 * style.scale)));
        var info_buf: [128:0]u8 = undefined;
        if (game_state.file_info.has_time) {
            const modified_seconds: i64 = @divTrunc(game_state.file_info.modified_ns, std.time.ns_per_s);
            const info_str = try std.fmt.bufPrintZ(&info_buf, "Size {d}b · Modified {d}", .{ game_state.file_info.size, modified_seconds });
            engine.Text.draw(info_str, text_x, line_y, style.small_font_size, style.text_muted);
        } else {
            const info_str = try std.fmt.bufPrintZ(&info_buf, "Size {d}b", .{game_state.file_info.size});
            engine.Text.draw(info_str, text_x, line_y, style.small_font_size, style.text_muted);
        }
    }

    const prog_h = config.UI.PROGRESS_HEIGHT * style.scale;
    const prog_x = layout.rect.x + layout.padding_f;
    const prog_w = layout.rect.width - layout.padding_f * 2.0;
    const prog_y = layout.rect.y + layout.rect.height - layout.padding_f - prog_h;
    const progress_bg = engine.Rectangle{ .x = prog_x, .y = prog_y, .width = prog_w, .height = prog_h };
    engine.Shapes.drawRectangleRec(progress_bg, COLOR_PROGRESS_BG);

    const remaining_float: f32 = @floatFromInt(game_state.remaining_items);
    const total_float: f32 = @floatFromInt(game_state_module.DEFAULT_ITEM_COUNT);
    const raw_ratio = if (game_state.remaining_items == 0) 1.0 else 1.0 - remaining_float / total_float;
    const fill_ratio = if (raw_ratio < 0.0) 0.0 else if (raw_ratio > 1.0) 1.0 else raw_ratio;
    const fill_w = prog_w * fill_ratio;
    if (fill_w > 0.0) {
        engine.Shapes.drawRectangleRec(engine.Rectangle{ .x = prog_x, .y = prog_y, .width = fill_w, .height = prog_h }, style.accent);
    }

    const fps_y: i32 = @as(i32, @intFromFloat(prog_y)) - @as(i32, @intFromFloat(std.math.round(10.0 * style.scale)));
    engine.Text.drawFPS(text_x, fps_y);
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
    const text_width = engine.Text.measure(instructions, config.UI.INSTRUCTION_FONT_SIZE);
    const text_x: i32 = @intFromFloat((screen_width - @as(f32, @floatFromInt(text_width))) / 2.0);
    const text_y: i32 = @intFromFloat(screen_height - config.UI.INSTRUCTION_Y_OFFSET);

    engine.Text.draw(
        instructions,
        text_x,
        text_y,
        config.UI.INSTRUCTION_FONT_SIZE,
        COLOR_TEXT_GRAY,
    );
}

pub fn drawStatusMessage(status: *const StatusMessage, screen_width: f32) void {
    shared_ui.drawStatusMessage(status, screen_width);
}

pub fn drawWinMessage(screen_width: f32, screen_height: f32) void {
    const win_text = "YOU WIN!";
    const win_width = engine.Text.measure(win_text, config.UI.WIN_FONT_SIZE);
    const win_x = @as(i32, @intFromFloat((screen_width - @as(f32, @floatFromInt(win_width))) / 2.0));
    const win_y = @as(i32, @intFromFloat(screen_height / 2.0 - config.UI.WIN_Y_OFFSET));

    engine.Text.draw(
        win_text,
        win_x,
        win_y,
        config.UI.WIN_FONT_SIZE,
        COLOR_WIN,
    );

    const hint_text = "Press R to replay";
    const hint_width = engine.Text.measure(hint_text, config.UI.INSTRUCTION_FONT_SIZE);
    const hint_x = @as(i32, @intFromFloat((screen_width - @as(f32, @floatFromInt(hint_width))) / 2.0));
    const hint_y = win_y + config.UI.WIN_FONT_SIZE + 10;
    engine.Text.draw(
        hint_text,
        hint_x,
        hint_y,
        config.UI.INSTRUCTION_FONT_SIZE,
        COLOR_TEXT_GRAY,
    );
}