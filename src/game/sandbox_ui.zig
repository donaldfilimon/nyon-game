//! Sandbox Game UI System
//!
//! Manages menus, HUD, and UI state for the sandbox game.

const std = @import("std");
const nyon_game = @import("../root.zig");
const engine = @import("../engine.zig");
const ui = @import("../ui/ui.zig");
const worlds = @import("worlds.zig");
const game_state_mod = @import("state.zig");

const Color = engine.Color;
const Rectangle = engine.Rectangle;
const Text = engine.Text;
const Shapes = engine.Shapes;
const Window = engine.Window;

pub const AppMode = enum {
    title,
    worlds,
    create_world,
    server_browser,
    playing,
    paused,
};

pub const TitleMenuAction = enum {
    none,
    singleplayer,
    multiplayer,
    quit,
};

pub const WorldMenuAction = enum {
    none,
    play_selected,
    create_world,
    back,
};

pub const PauseMenuAction = enum {
    none,
    unpause,
    quit_to_title,
};

pub const NameInput = struct {
    buffer: [32]u8 = [_]u8{0} ** 32,
    len: usize = 0,

    pub fn clear(self: *NameInput) void {
        self.len = 0;
        self.buffer[0] = 0;
    }

    pub fn asSlice(self: *const NameInput) []const u8 {
        return self.buffer[0..self.len];
    }

    pub fn pushAscii(self: *NameInput, c: u8) void {
        if (self.len + 1 >= self.buffer.len) return;
        self.buffer[self.len] = c;
        self.len += 1;
        self.buffer[self.len] = 0;
    }

    pub fn pop(self: *NameInput) void {
        if (self.len == 0) return;
        self.len -= 1;
        self.buffer[self.len] = 0;
    }
};

pub const MenuState = struct {
    allocator: std.mem.Allocator,
    ctx: ui.UiContext = .{ .style = ui.UiStyle.fromTheme(.dark, 180, 1.0) },
    worlds_list: []worlds.WorldEntry = &.{},
    selected_world: ?usize = null,
    create_name: NameInput = NameInput{},

    pub fn init(allocator: std.mem.Allocator) MenuState {
        return .{
            .allocator = allocator,
            .ctx = .{ .style = ui.UiStyle.fromTheme(.dark, 180, 1.0) },
        };
    }

    pub fn deinit(self: *MenuState) void {
        self.freeWorlds();
    }

    pub fn refreshWorlds(self: *MenuState) void {
        self.freeWorlds();
        self.worlds_list = worlds.listWorlds(self.allocator) catch &.{};
        self.selected_world = if (self.worlds_list.len > 0) 0 else null;
    }

    fn freeWorlds(self: *MenuState) void {
        for (self.worlds_list) |*entry| entry.deinit();
        if (self.worlds_list.len > 0) self.allocator.free(self.worlds_list);
        self.worlds_list = &.{};
        self.selected_world = null;
    }
};

pub const GameUiState = struct {
    config: ui.UiConfig,
    ctx: ui.UiContext = .{ .style = ui.UiStyle.fromTheme(.dark, 180, 1.0) },
    edit_mode: bool = false,
    dirty: bool = false,
    font_manager: nyon_game.FontManager,

    pub fn initWithDefaultScale(allocator: std.mem.Allocator, default_scale: f32) GameUiState {
        var cfg = ui.UiConfig{};
        cfg.scale = default_scale;
        cfg.font.dpi_scale = default_scale;

        if (ui.UiConfig.load(allocator, ui.UiConfig.DEFAULT_PATH)) |loaded_cfg| {
            cfg = loaded_cfg;
        } else |_| {
            cfg.sanitize();
        }

        const font_manager = nyon_game.FontManager.init(allocator);

        return .{
            .config = cfg,
            .ctx = .{ .style = ui.UiStyle.fromTheme(cfg.theme, cfg.opacity, cfg.scale) },
            .font_manager = font_manager,
        };
    }

    pub fn style(self: *const GameUiState) ui.UiStyle {
        return ui.UiStyle.fromTheme(self.config.theme, self.config.opacity, self.config.scale);
    }

    pub fn deinit(self: *GameUiState) void {
        self.font_manager.deinit();
    }
};

pub fn defaultUiScaleFromDpi() f32 {
    const scale = Window.getScaleDPI();
    const avg = (scale.x + scale.y) / 2.0;
    if (avg <= 0.0) return 1.0;
    if (avg < 0.6) return 0.6;
    if (avg > 2.5) return 2.5;
    return avg;
}

pub fn clampPanelRect(rect: *Rectangle, screen_width: f32, screen_height: f32) void {
    if (rect.width > screen_width) rect.width = screen_width;
    if (rect.height > screen_height) rect.height = screen_height;

    if (rect.x < 0.0) rect.x = 0.0;
    if (rect.y < 0.0) rect.y = 0.0;

    if (rect.x + rect.width > screen_width) rect.x = screen_width - rect.width;
    if (rect.y + rect.height > screen_height) rect.y = screen_height - rect.height;
}

pub fn drawHudPanel(game_state: *const game_state_mod.GameState, ui_state: *GameUiState, screen_width: f32, screen_height: f32) !void {
    if (!ui_state.config.hud.visible) return;

    var rect = ui_state.config.hud.rect;
    const s = ui_state.ctx.style;

    const result = ui_state.ctx.panel(.hud, &rect, "HUD", ui_state.edit_mode);
    if (result.dragged) ui_state.dirty = true;
    if (ui_state.edit_mode) {
        if (ui_state.ctx.resizeHandle(.hud, &rect, 220.0, 160.0)) ui_state.dirty = true;
    }

    clampPanelRect(&rect, screen_width, screen_height);
    ui_state.config.hud.rect = rect;

    const padding_f: f32 = @floatFromInt(s.padding);
    const text_x: i32 = @intFromFloat(rect.x + padding_f);
    const start_y: i32 = @intFromFloat(rect.y + @as(f32, @floatFromInt(s.panel_title_height)) + padding_f);
    const line_step: i32 = s.font_size + @as(i32, @intFromFloat(std.math.round(6.0 * s.scale)));

    var line_y = start_y;

    var score_buf: [64:0]u8 = undefined;
    const score_str = try std.fmt.bufPrintZ(&score_buf, "Score {:>4}", .{game_state.score});
    Text.draw(score_str, text_x, line_y, s.font_size, s.text);

    line_y += line_step;
    var remaining_buf: [64:0]u8 = undefined;
    const remaining_str = try std.fmt.bufPrintZ(&remaining_buf, "Remaining: {d}", .{game_state.remaining_items});
    Text.draw(remaining_str, text_x, line_y, s.font_size, s.accent);

    line_y += line_step;
    var best_buf: [64:0]u8 = undefined;
    const best_str = try std.fmt.bufPrintZ(&best_buf, "Best: {d}", .{game_state.best_score});
    Text.draw(best_str, text_x, line_y, s.font_size, s.text);

    line_y += line_step;
    var time_buf: [48:0]u8 = undefined;
    const time_str = try std.fmt.bufPrintZ(&time_buf, "Time {d:.1}s", .{game_state.game_time});
    Text.draw(time_str, text_x, line_y, s.font_size, s.text_muted);

    line_y += line_step;
    if (game_state.best_time) |fastest| {
        var fastest_buf: [64:0]u8 = undefined;
        const fastest_str = try std.fmt.bufPrintZ(&fastest_buf, "Fastest {d:.1}s", .{fastest});
        Text.draw(fastest_str, text_x, line_y, s.font_size, s.accent);
    } else {
        Text.draw("Fastest --", text_x, line_y, s.font_size, s.accent);
    }

    const prog_h = 10.0 * s.scale;
    const prog_x = rect.x + padding_f;
    const prog_w = rect.width - padding_f * 2.0;
    const prog_y = rect.y + rect.height - padding_f - prog_h;
    const progress_bg = Rectangle{ .x = prog_x, .y = prog_y, .width = prog_w, .height = prog_h };
    Shapes.drawRectangleRec(progress_bg, Color{ .r = 60, .g = 60, .b = 80, .a = 255 });

    const remaining_float: f32 = @floatFromInt(game_state.remaining_items);
    const total_float: f32 = @floatFromInt(game_state_mod.DEFAULT_ITEM_COUNT);
    const raw_ratio = if (game_state.remaining_items == 0) 1.0 else 1.0 - remaining_float / total_float;
    const fill_ratio = if (raw_ratio < 0.0) 0.0 else if (raw_ratio > 1.0) 1.0 else raw_ratio;
    const fill_w = prog_w * fill_ratio;
    if (fill_w > 0.0) {
        Shapes.drawRectangleRec(Rectangle{ .x = prog_x, .y = prog_y, .width = fill_w, .height = prog_h }, s.accent);
    }

    const fps_y: i32 = @as(i32, @intFromFloat(prog_y)) - @as(i32, @intFromFloat(std.math.round(10.0 * s.scale)));
    Text.drawFPS(text_x, fps_y);
}
