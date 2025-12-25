const std = @import("std");
const math = std.math;
const nyon_game = @import("root.zig");
const engine_mod = nyon_game.engine;
const status_msg = nyon_game.status_message;

// Direct types from engine modules
const Engine = engine_mod.Engine;
const Audio = engine_mod.Audio;
const File = engine_mod.File;
const Input = engine_mod.Input;
const Shapes = engine_mod.Shapes;
const Text = engine_mod.Text;
const Window = engine_mod.Window;
const KeyboardKey = engine_mod.KeyboardKey;
const MouseButton = engine_mod.MouseButton;
const Color = engine_mod.Color;
const Rectangle = engine_mod.Rectangle;

const fs = std.fs;
const ui_mod = @import("ui/ui.zig");
const StatusMessage = @import("ui/status_message.zig").StatusMessage;
const FileDetail = @import("io/file_detail.zig").FileDetail;
const file_metadata = @import("io/file_metadata.zig");
const worlds_mod = @import("game/worlds.zig");
const FontManager = @import("font_manager.zig").FontManager;

// Import game state module
const game_state = @import("game/state.zig");

// ============================================================================
// Game Constants (keeping local copies for now during refactoring)
// ============================================================================

const WINDOW_WIDTH: u32 = 800;
const WINDOW_HEIGHT: u32 = 600;
const WINDOW_TITLE = "Nyon Game - Collect Items!";
const TARGET_FPS: u32 = 60;

// Game constants
const PLAYER_START_X: f32 = 400.0;
const PLAYER_START_Y: f32 = 300.0;
const PLAYER_SPEED: f32 = 200.0;
const PLAYER_SIZE: f32 = 30.0;
const ITEM_SIZE: f32 = 15.0;
const ITEM_COLLECTION_RADIUS: f32 = PLAYER_SIZE + ITEM_SIZE;
const ITEM_SCORE_VALUE: u32 = 10;
const DEFAULT_ITEM_COUNT: usize = 5;
const INITIAL_ITEM_POSITIONS: [DEFAULT_ITEM_COUNT][2]f32 = .{
    .{ 100, 100 },
    .{ 200, 150 },
    .{ 300, 200 },
    .{ 500, 250 },
    .{ 700, 400 },
};

// Animation constants
const ITEM_PULSE_SPEED: f32 = 3.0;
const ITEM_PULSE_AMPLITUDE: f32 = 0.2;

// ============================================================================
// Game State Structures (keeping local copies for now during refactoring)
// ============================================================================

const CollectibleItem = struct {
    x: f32,
    y: f32,
    collected: bool,
};

const GameState = struct {
    player_x: f32 = PLAYER_START_X,
    player_y: f32 = PLAYER_START_Y,
    player_speed: f32 = PLAYER_SPEED,
    player_size: f32 = PLAYER_SIZE,

    items: [5]CollectibleItem = .{
        .{ .x = 100, .y = 100, .collected = false },
        .{ .x = 200, .y = 150, .collected = false },
        .{ .x = 300, .y = 200, .collected = false },
        .{ .x = 500, .y = 250, .collected = false },
        .{ .x = 700, .y = 400, .collected = false },
    },

    score: u32 = 0,
    remaining_items: usize = DEFAULT_ITEM_COUNT,
    best_score: u32 = 0,
    best_time: ?f32 = null,
    has_won: bool = false,
    game_time: f32 = 0.0,
    file_info: FileDetail = FileDetail{},
};

const WorldSession = struct {
    allocator: std.mem.Allocator,
    folder: []u8,
    name: []u8,

    pub fn deinit(self: *WorldSession) void {
        self.allocator.free(self.folder);
        self.allocator.free(self.name);
        self.* = undefined;
    }
};

// Grid constants
const GRID_SIZE: f32 = 50.0;

// UI constants
const UI_INSTRUCTION_FONT_SIZE: i32 = 16;
const UI_INSTRUCTION_Y_OFFSET: i32 = 30;
const UI_WIN_FONT_SIZE: i32 = 40;
const UI_WIN_Y_OFFSET: i32 = 20;
const UI_PROGRESS_HEIGHT: f32 = 10.0;
const STATUS_MESSAGE_FONT_SIZE: i32 = 18;
const STATUS_MESSAGE_DURATION: f32 = 3.0;
const STATUS_MESSAGE_Y_OFFSET: i32 = 8;
const COLOR_STATUS_MESSAGE = Color{ .r = 200, .g = 220, .b = 255, .a = 255 };

// Colors
const COLOR_BACKGROUND = Color{ .r = 30, .g = 30, .b = 50, .a = 255 };
const COLOR_GRID = Color{ .r = 40, .g = 40, .b = 60, .a = 255 };
const COLOR_ITEM = Color{ .r = 255, .g = 215, .b = 0, .a = 255 };
const COLOR_ITEM_OUTLINE = Color{ .r = 255, .g = 255, .b = 100, .a = 255 };
const COLOR_PLAYER_IDLE = Color{ .r = 150, .g = 150, .b = 255, .a = 255 };
const COLOR_PLAYER_MOVING = Color{ .r = 100, .g = 200, .b = 255, .a = 255 };
const COLOR_PLAYER_OUTLINE = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
const COLOR_WIN = Color{ .r = 0, .g = 255, .b = 0, .a = 255 };
const COLOR_TEXT_GRAY = Color{ .r = 200, .g = 200, .b = 200, .a = 255 };
const COLOR_PROGRESS_BG = Color{ .r = 60, .g = 60, .b = 80, .a = 255 };
const COLOR_PROGRESS_FILL = Color{ .r = 255, .g = 175, .b = 0, .a = 255 };

const AppMode = enum {
    title,
    worlds,
    create_world,
    server_browser,
    playing,
    paused,
};

const TitleMenuAction = enum {
    none,
    singleplayer,
    multiplayer,

    quit,
};

const WorldMenuAction = enum {
    none,
    play_selected,
    create_world,
    back,
};

const PauseMenuAction = enum {
    none,
    unpause,
    quit_to_title,
};

const NameInput = struct {
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

const MenuState = struct {
    allocator: std.mem.Allocator,
    ctx: ui_mod.UiContext = ui_mod.UiContext{},
    worlds: []worlds_mod.WorldEntry = &.{},
    selected_world: ?usize = null,
    create_name: NameInput = NameInput{},

    pub fn init(allocator: std.mem.Allocator) MenuState {
        return .{
            .allocator = allocator,
            .ctx = .{ .style = ui_mod.UiStyle.fromTheme(.dark, 180, 1.0) },
        };
    }

    pub fn deinit(self: *MenuState) void {
        self.freeWorlds();
    }

    pub fn refreshWorlds(self: *MenuState) void {
        self.freeWorlds();
        self.worlds = worlds_mod.listWorlds(self.allocator) catch &.{};
        self.selected_world = if (self.worlds.len > 0) 0 else null;
    }

    fn freeWorlds(self: *MenuState) void {
        for (self.worlds) |*entry| entry.deinit();
        if (self.worlds.len > 0) self.allocator.free(self.worlds);
        self.worlds = &.{};
        self.selected_world = null;
    }
};

const GameUiState = struct {
    config: ui_mod.UiConfig,
    ctx: ui_mod.UiContext = ui_mod.UiContext{},
    edit_mode: bool = false,
    dirty: bool = false,
    font_manager: FontManager,

    pub fn initWithDefaultScale(allocator: std.mem.Allocator, default_scale: f32) GameUiState {
        var cfg = ui_mod.UiConfig{};
        cfg.scale = default_scale;
        cfg.font.dpi_scale = default_scale; // Initialize DPI scale

        // Try to load saved config
        if (ui_mod.UiConfig.load(allocator, ui_mod.UiConfig.DEFAULT_PATH)) |loaded_cfg| {
            cfg = loaded_cfg;
        } else |_| {
            cfg.sanitize();
        }

        const font_manager = FontManager.init(allocator);
        // Temporarily disable font loading to fix build
        // font_manager.loadUI(cfg.font) catch {
        //     // Font loading failed, continue with defaults
        // };

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

fn defaultUiScaleFromDpi() f32 {
    const scale = Window.getScaleDPI();
    const avg = (scale.x + scale.y) / 2.0;
    if (avg <= 0.0) return 1.0;
    if (avg < 0.6) return 0.6;
    if (avg > 2.5) return 2.5;
    return avg;
}

fn resetGameState(game_state: *GameState) void {
    var idx: usize = 0;
    for (game_state.items[0..]) |*item| {
        const pos = game_state.INITIAL_ITEM_POSITIONS[idx];
        item.* = CollectibleItem{ .x = pos[0], .y = pos[1], .collected = false };
        idx += 1;
    }
    game_state.remaining_items = game_state.DEFAULT_ITEM_COUNT;
    game_state.score = 0;
    game_state.game_time = 0.0;
    game_state.player_x = game_state.PLAYER_START_X;
    game_state.player_y = game_state.PLAYER_START_Y;
    game_state.has_won = false;
    game_state.file_info.clear();
}

fn updateFileInfo(game_state: *GameState, path: []const u8) !void {
    const meta = try file_metadata.get(path);
    game_state.file_info.set(path, meta.size, meta.modified_ns);
}

fn loadFileMetadata(game_state: *GameState, status_message: *StatusMessage, path: []const u8) !void {
    try updateFileInfo(game_state, path);

    var msg_buf: [160:0]u8 = undefined;
    const msg = try std.fmt.bufPrintZ(&msg_buf, "Loaded {s} ({d} bytes)", .{ path, game_state.file_info.size });
    status_message.set(msg, STATUS_MESSAGE_DURATION + 1.5);
}

fn handleDroppedFile(
    game_state: *GameState,
    ui_state: *GameUiState,
    status_message: *StatusMessage,
    allocator: std.mem.Allocator,
    frame_allocator: std.mem.Allocator,
) !void {
    _ = game_state;
    _ = ui_state;
    _ = status_message;
    _ = allocator;
    _ = frame_allocator;
    // Temporarily disabled due to build issues
    // TODO: Re-enable once raylib dependency issues are resolved
}

// ============================================================================
// Input Handling
// ============================================================================

/// Handle player input and update player position
/// Returns true if the player moved this frame
fn handleInput(game_state: *GameState, delta_time: f32, screen_width: f32, screen_height: f32) bool {
    var moved = false;

    if (Input.Keyboard.isDown(KeyboardKey.w) or Input.Keyboard.isDown(KeyboardKey.up)) {
        game_state.player_y -= game_state.player_speed * delta_time;
        moved = true;
    }
    if (Input.Keyboard.isDown(KeyboardKey.s) or Input.Keyboard.isDown(KeyboardKey.down)) {
        game_state.player_y += game_state.player_speed * delta_time;
        moved = true;
    }
    if (Input.Keyboard.isDown(KeyboardKey.a) or Input.Keyboard.isDown(KeyboardKey.left)) {
        game_state.player_x -= game_state.player_speed * delta_time;
        moved = true;
    }
    if (Input.Keyboard.isDown(KeyboardKey.d) or Input.Keyboard.isDown(KeyboardKey.right)) {
        game_state.player_x += game_state.player_speed * delta_time;
        moved = true;
    }

    // Keep player in bounds
    game_state.player_x = @max(game_state.player_size, @min(screen_width - game_state.player_size, game_state.player_x));
    game_state.player_y = @max(game_state.player_size, @min(screen_height - game_state.player_size, game_state.player_y));

    return moved;
}

// ============================================================================
// Collision Detection
// ============================================================================

/// Check for collisions between player and collectible items
/// Updates item collection state and score
fn checkCollisions(game_state: *GameState) usize {
    var collected: usize = 0;
    for (game_state.items[0..]) |*item| {
        if (!item.collected) {
            const dx = game_state.player_x - item.x;
            const dy = game_state.player_y - item.y;
            const distance = @sqrt(dx * dx + dy * dy);

            if (distance < ITEM_COLLECTION_RADIUS) {
                item.collected = true;
                game_state.score += ITEM_SCORE_VALUE;
                if (game_state.score > game_state.best_score) {
                    game_state.best_score = game_state.score;
                }
                if (game_state.remaining_items > 0) {
                    game_state.remaining_items -= 1;
                }
                collected += 1;
            }
        }
    }
    return collected;
}

/// Check if all items have been collected
fn isGameWon(game_state: *const GameState) bool {
    for (game_state.items) |item| {
        if (!item.collected) {
            return false;
        }
    }
    return true;
}

// ============================================================================
// Drawing Functions
// ============================================================================

/// Draw the grid background
fn drawGrid(screen_width: f32, screen_height: f32) void {
    var x: f32 = 0;
    while (x < screen_width) : (x += GRID_SIZE) {
        Shapes.drawLine(
            @intFromFloat(x),
            0,
            @intFromFloat(x),
            @intFromFloat(screen_height),
            COLOR_GRID,
        );
    }

    var y: f32 = 0;
    while (y < screen_height) : (y += GRID_SIZE) {
        Shapes.drawLine(
            0,
            @intFromFloat(y),
            @intFromFloat(screen_width),
            @intFromFloat(y),
            COLOR_GRID,
        );
    }
}

/// Draw all collectible items with pulsing animation
fn drawItems(game_state: *const GameState) void {
    for (game_state.items) |item| {
        if (!item.collected) {
            // Pulsing animation
            const pulse = @sin(game_state.game_time * ITEM_PULSE_SPEED) * ITEM_PULSE_AMPLITUDE + 1.0;
            const size: f32 = ITEM_SIZE * pulse;

            Shapes.drawCircle(
                @intFromFloat(item.x),
                @intFromFloat(item.y),
                size,
                COLOR_ITEM,
            );
            Shapes.drawCircleLines(
                @intFromFloat(item.x),
                @intFromFloat(item.y),
                size,
                COLOR_ITEM_OUTLINE,
            );
        }
    }
}

/// Draw the player character
fn drawPlayer(game_state: *const GameState, is_moving: bool) void {
    const player_color = if (is_moving) COLOR_PLAYER_MOVING else COLOR_PLAYER_IDLE;

    Shapes.drawCircle(
        @intFromFloat(game_state.player_x),
        @intFromFloat(game_state.player_y),
        game_state.player_size,
        player_color,
    );
    Shapes.drawCircleLines(
        @intFromFloat(game_state.player_x),
        @intFromFloat(game_state.player_y),
        game_state.player_size,
        COLOR_PLAYER_OUTLINE,
    );
}

/// Draw the UI panel with score, time, and FPS
fn clampPanelRect(rect: *Rectangle, screen_width: f32, screen_height: f32) void {
    if (rect.width > screen_width) rect.width = screen_width;
    if (rect.height > screen_height) rect.height = screen_height;

    if (rect.x < 0.0) rect.x = 0.0;
    if (rect.y < 0.0) rect.y = 0.0;

    if (rect.x + rect.width > screen_width) rect.x = screen_width - rect.width;
    if (rect.y + rect.height > screen_height) rect.y = screen_height - rect.height;
}

fn drawHudPanel(game_state: *const GameState, ui_state: *GameUiState, screen_width: f32, screen_height: f32) !void {
    if (!ui_state.config.hud.visible) return;

    var rect = ui_state.config.hud.rect;
    const style = ui_state.ctx.style;

    const result = ui_state.ctx.panel(.hud, &rect, "HUD", ui_state.edit_mode);
    if (result.dragged) ui_state.dirty = true;
    if (ui_state.edit_mode) {
        if (ui_state.ctx.resizeHandle(.hud, &rect, 220.0, 160.0)) ui_state.dirty = true;
    }

    clampPanelRect(&rect, screen_width, screen_height);
    ui_state.config.hud.rect = rect;

    const padding_f: f32 = @floatFromInt(style.padding);
    const text_x: i32 = @intFromFloat(rect.x + padding_f);
    const start_y: i32 = @intFromFloat(rect.y + @as(f32, @floatFromInt(style.panel_title_height)) + padding_f);
    const line_step: i32 = style.font_size + @as(i32, @intFromFloat(std.math.round(6.0 * style.scale)));

    var line_y = start_y;

    var score_buf: [64:0]u8 = undefined;
    const score_str = try std.fmt.bufPrintZ(&score_buf, "Score {:>4}", .{game_state.score});
    Text.draw(score_str, text_x, line_y, style.font_size, style.text);

    line_y += line_step;
    var remaining_buf: [64:0]u8 = undefined;
    const remaining_str = try std.fmt.bufPrintZ(&remaining_buf, "Remaining: {d}", .{game_state.remaining_items});
    Text.draw(remaining_str, text_x, line_y, style.font_size, style.accent);

    line_y += line_step;
    var best_buf: [64:0]u8 = undefined;
    const best_str = try std.fmt.bufPrintZ(&best_buf, "Best: {d}", .{game_state.best_score});
    Text.draw(best_str, text_x, line_y, style.font_size, style.text);

    line_y += line_step;
    var time_buf: [48:0]u8 = undefined;
    const time_str = try std.fmt.bufPrintZ(&time_buf, "Time {d:.1}s", .{game_state.game_time});
    Text.draw(time_str, text_x, line_y, style.font_size, style.text_muted);

    line_y += line_step;
    if (game_state.best_time) |fastest| {
        var fastest_buf: [64:0]u8 = undefined;
        const fastest_str = try std.fmt.bufPrintZ(&fastest_buf, "Fastest {d:.1}s", .{fastest});
        Text.draw(fastest_str, text_x, line_y, style.font_size, style.accent);
    } else {
        Text.draw("Fastest --", text_x, line_y, style.font_size, style.accent);
    }

    if (game_state.file_info.hasFile()) {
        line_y += line_step;
        var path_buf: [220:0]u8 = undefined;
        const path_str = try std.fmt.bufPrintZ(&path_buf, "Loaded: {s}", .{game_state.file_info.path()});
        Text.draw(path_str, text_x, line_y, style.small_font_size, style.text);

        line_y += style.small_font_size + @as(i32, @intFromFloat(std.math.round(6.0 * style.scale)));
        var info_buf: [128:0]u8 = undefined;
        if (game_state.file_info.has_time) {
            const modified_seconds: i64 = @intCast(@divTrunc(game_state.file_info.modified_ns, std.time.ns_per_s));
            const info_str = try std.fmt.bufPrintZ(&info_buf, "Size {d}b · Modified {d}", .{ game_state.file_info.size, modified_seconds });
            Text.draw(info_str, text_x, line_y, style.small_font_size, style.text_muted);
        } else {
            const info_str = try std.fmt.bufPrintZ(&info_buf, "Size {d}b", .{game_state.file_info.size});
            Text.draw(info_str, text_x, line_y, style.small_font_size, style.text_muted);
        }
    }

    const prog_h = UI_PROGRESS_HEIGHT * style.scale;
    const prog_x = rect.x + padding_f;
    const prog_w = rect.width - padding_f * 2.0;
    const prog_y = rect.y + rect.height - padding_f - prog_h;
    const progress_bg = Rectangle{ .x = prog_x, .y = prog_y, .width = prog_w, .height = prog_h };
    Shapes.drawRectangleRec(progress_bg, COLOR_PROGRESS_BG);

    const remaining_float: f32 = @floatFromInt(game_state.remaining_items);
    const total_float: f32 = @floatFromInt(DEFAULT_ITEM_COUNT);
    const raw_ratio = if (game_state.remaining_items == 0) 1.0 else 1.0 - remaining_float / total_float;
    const fill_ratio = if (raw_ratio < 0.0) 0.0 else if (raw_ratio > 1.0) 1.0 else raw_ratio;
    const fill_w = prog_w * fill_ratio;
    if (fill_w > 0.0) {
        Shapes.drawRectangleRec(Rectangle{ .x = prog_x, .y = prog_y, .width = fill_w, .height = prog_h }, style.accent);
    }

    const fps_y: i32 = @as(i32, @intFromFloat(prog_y)) - @as(i32, @intFromFloat(std.math.round(10.0 * style.scale)));
    Text.drawFPS(text_x, fps_y);
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

    clampPanelRect(&rect, screen_width, screen_height);
    ui_state.config.settings.rect = rect;

    const pad_f: f32 = @floatFromInt(style.padding);
    const x = rect.x + pad_f;
    var y = rect.y + @as(f32, @floatFromInt(style.panel_title_height)) + pad_f;
    const w = rect.width - pad_f * 2.0;

    const row_h: f32 = @floatFromInt(@max(style.small_font_size + 8, 22));

    // Edit mode indicator
    if (ui_state.edit_mode) {
        Text.draw("UI Edit Mode (F1 to exit)", @intFromFloat(x), @intFromFloat(y), style.small_font_size, style.accent);
        y += row_h;
    } else {
        Text.draw("Press F1 to edit UI layout", @intFromFloat(x), @intFromFloat(y), style.small_font_size, style.text_muted);
        y += row_h;
    }

    // Show HUD toggle
    const show_hud_id: u64 = std.hash.Wyhash.hash(0, "settings_show_hud");
    _ = ui_state.ctx.checkbox(
        show_hud_id,
        Rectangle{ .x = x, .y = y, .width = w, .height = row_h },
        "Show HUD",
        &ui_state.config.hud.visible,
    );
    y += row_h + 6;

    // Theme toggle button
    var theme_buf: [32:0]u8 = undefined;
    const theme_label = try std.fmt.bufPrintZ(&theme_buf, "Theme: {s}", .{if (ui_state.config.theme == .dark) "Dark" else "Light"});
    const theme_id: u64 = std.hash.Wyhash.hash(0, "settings_theme");
    if (ui_state.ctx.button(theme_id, Rectangle{ .x = x, .y = y, .width = w, .height = row_h + 6 }, theme_label)) {
        ui_state.config.theme = if (ui_state.config.theme == .dark) .light else .dark;
        ui_state.dirty = true;
    }
    y += row_h + 18;

    // Scale slider
    const scale_id: u64 = std.hash.Wyhash.hash(0, "settings_scale");
    var scale = ui_state.config.scale;
    if (ui_state.ctx.sliderFloat(scale_id, Rectangle{ .x = x, .y = y, .width = w, .height = 14.0 * style.scale }, "Scale", &scale, 0.6, 2.5)) {
        ui_state.config.scale = scale;
        ui_state.dirty = true;
    }
    y += row_h + 22;

    // Opacity slider (stored as u8)
    const opacity_id: u64 = std.hash.Wyhash.hash(0, "settings_opacity");
    var opacity_f: f32 = @floatFromInt(ui_state.config.opacity);
    if (ui_state.ctx.sliderFloat(opacity_id, Rectangle{ .x = x, .y = y, .width = w, .height = 14.0 * style.scale }, "Panel Opacity", &opacity_f, 60.0, 255.0)) {
        const rounded = std.math.round(opacity_f);
        const clamped = if (rounded < 0.0) 0.0 else if (rounded > 255.0) 255.0 else rounded;
        ui_state.config.opacity = @intFromFloat(clamped);
        ui_state.dirty = true;
    }
    y += row_h + 18;

    // Audio Settings Section
    Text.draw("Audio", @intFromFloat(x), @intFromFloat(y), style.small_font_size, style.accent);
    y += row_h;

    const master_vol_id: u64 = std.hash.Wyhash.hash(0, "settings_master_volume");
    var master_vol = ui_state.config.game.master_volume;
    if (ui_state.ctx.sliderFloat(master_vol_id, Rectangle{ .x = x, .y = y, .width = w, .height = 14.0 * style.scale }, "Master Volume", &master_vol, 0.0, 1.0)) {
        ui_state.config.game.master_volume = master_vol;
        ui_state.dirty = true;
    }
    y += row_h + 6;

    const music_vol_id: u64 = std.hash.Wyhash.hash(0, "settings_music_volume");
    var music_vol = ui_state.config.game.music_volume;
    if (ui_state.ctx.sliderFloat(music_vol_id, Rectangle{ .x = x, .y = y, .width = w, .height = 14.0 * style.scale }, "Music Volume", &music_vol, 0.0, 1.0)) {
        ui_state.config.game.music_volume = music_vol;
        ui_state.dirty = true;
    }
    y += row_h + 6;

    const sfx_vol_id: u64 = std.hash.Wyhash.hash(0, "settings_sfx_volume");
    var sfx_vol = ui_state.config.game.sfx_volume;
    if (ui_state.ctx.sliderFloat(sfx_vol_id, Rectangle{ .x = x, .y = y, .width = w, .height = 14.0 * style.scale }, "SFX Volume", &sfx_vol, 0.0, 1.0)) {
        ui_state.config.game.sfx_volume = sfx_vol;
        ui_state.dirty = true;
    }
    y += row_h + 12;

    // Graphics Settings Section
    Text.draw("Graphics", @intFromFloat(x), @intFromFloat(y), style.small_font_size, style.accent);
    y += row_h;

    const show_fps_id: u64 = std.hash.Wyhash.hash(0, "settings_show_fps");
    _ = ui_state.ctx.checkbox(
        show_fps_id,
        Rectangle{ .x = x, .y = y, .width = w, .height = row_h },
        "Show FPS",
        &ui_state.config.game.show_fps,
    );
    y += row_h + 6;

    const vsync_id: u64 = std.hash.Wyhash.hash(0, "settings_vsync");
    _ = ui_state.ctx.checkbox(
        vsync_id,
        Rectangle{ .x = x, .y = y, .width = w, .height = row_h },
        "VSync",
        &ui_state.config.game.vsync,
    );
    y += row_h + 6;

    const fullscreen_id: u64 = std.hash.Wyhash.hash(0, "settings_fullscreen");
    _ = ui_state.ctx.checkbox(
        fullscreen_id,
        Rectangle{ .x = x, .y = y, .width = w, .height = row_h },
        "Fullscreen",
        &ui_state.config.game.fullscreen,
    );
    y += row_h + 12;

    // Accessibility Settings Section
    Text.draw("Accessibility", @intFromFloat(x), @intFromFloat(y), style.small_font_size, style.accent);
    y += row_h;

    const high_contrast_id: u64 = std.hash.Wyhash.hash(0, "settings_high_contrast");
    _ = ui_state.ctx.checkbox(
        high_contrast_id,
        Rectangle{ .x = x, .y = y, .width = w, .height = row_h },
        "High Contrast",
        &ui_state.config.game.high_contrast,
    );
    y += row_h + 6;

    const large_text_id: u64 = std.hash.Wyhash.hash(0, "settings_large_text");
    _ = ui_state.ctx.checkbox(
        large_text_id,
        Rectangle{ .x = x, .y = y, .width = w, .height = row_h },
        "Large Text",
        &ui_state.config.game.large_text,
    );
    y += row_h + 6;

    const reduced_motion_id: u64 = std.hash.Wyhash.hash(0, "settings_reduced_motion");
    _ = ui_state.ctx.checkbox(
        reduced_motion_id,
        Rectangle{ .x = x, .y = y, .width = w, .height = row_h },
        "Reduced Motion",
        &ui_state.config.game.reduced_motion,
    );
    y += row_h + 12;

    // Font Settings Section
    Text.draw("Fonts", @intFromFloat(x), @intFromFloat(y), style.small_font_size, style.accent);
    y += row_h;

    const system_font_id: u64 = std.hash.Wyhash.hash(0, "settings_system_font");
    _ = ui_state.ctx.checkbox(
        system_font_id,
        Rectangle{ .x = x, .y = y, .width = w, .height = row_h },
        "Use System Font",
        &ui_state.config.font.use_system_font,
    );
    y += row_h + 6;

    const dpi_scale_id: u64 = std.hash.Wyhash.hash(0, "settings_dpi_scale");
    var dpi_scale = ui_state.config.font.dpi_scale;
    if (ui_state.ctx.sliderFloat(dpi_scale_id, Rectangle{ .x = x, .y = y, .width = w, .height = 14.0 * style.scale }, "DPI Scale", &dpi_scale, 0.5, 2.0)) {
        ui_state.config.font.dpi_scale = dpi_scale;
        ui_state.dirty = true;
    }
    y += row_h + 12;

    const save_id: u64 = std.hash.Wyhash.hash(0, "settings_save");
    const reset_id: u64 = std.hash.Wyhash.hash(0, "settings_reset");
    const half_w = (w - 10.0) / 2.0;
    if (ui_state.ctx.button(save_id, Rectangle{ .x = x, .y = y, .width = half_w, .height = row_h + 8 }, "Save Layout")) {
        ui_state.config.save(allocator, ui_mod.UiConfig.DEFAULT_PATH) catch {
            status_message.set("Failed to save UI layout", STATUS_MESSAGE_DURATION);
            return;
        };
        ui_state.dirty = false;
        status_message.set("Saved UI layout", STATUS_MESSAGE_DURATION);
    }
    if (ui_state.ctx.button(reset_id, Rectangle{ .x = x + half_w + 10.0, .y = y, .width = half_w, .height = row_h + 8 }, "Reset")) {
        ui_state.config = ui_mod.UiConfig{};
        ui_state.dirty = true;
        status_message.set("Reset UI layout", STATUS_MESSAGE_DURATION);
    }

    if (ui_state.dirty) {
        const note_y: i32 = @intFromFloat(rect.y + rect.height - pad_f - @as(f32, @floatFromInt(style.small_font_size)));
        Text.draw("Unsaved changes", @intFromFloat(x), note_y, style.small_font_size, style.text_muted);
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
            moving.rect = Rectangle{
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
            moving.rect = Rectangle{
                .x = target_rect.x + target_rect.width - half,
                .y = target_rect.y,
                .width = half,
                .height = target_rect.height,
            };
            target.rect.width = @max(min_w, target_rect.width - half);
        },
        .top => {
            const half = @max(min_h, target_rect.height / 2.0);
            moving.rect = Rectangle{
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
            moving.rect = Rectangle{
                .x = target_rect.x,
                .y = target_rect.y + target_rect.height - half,
                .width = target_rect.width,
                .height = half,
            };
            target.rect.height = @max(min_h, target_rect.height - half);
        },
    }
}

fn applyDocking(ui_state: *GameUiState, status_message: *StatusMessage) void {
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

fn drawUI(
    game_state: *const GameState,
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

fn drawTitleMenu(menu: *MenuState, ui_style: ui_mod.UiStyle, status_message: *StatusMessage, screen_width: f32, screen_height: f32) TitleMenuAction {
    const title = "NYON";
    const subtitle = "A Zig + raylib sandbox";

    const title_size: i32 = @intFromFloat(std.math.round(64.0 * ui_style.scale));
    const subtitle_size: i32 = ui_style.small_font_size;

    const title_w = Text.measure(title, title_size);
    const title_x: i32 = @intFromFloat((screen_width - @as(f32, @floatFromInt(title_w))) / 2.0);
    Text.draw(title, title_x, @intFromFloat(screen_height * 0.12), title_size, ui_style.text);

    const sub_w = Text.measure(subtitle, subtitle_size);
    const sub_x: i32 = @intFromFloat((screen_width - @as(f32, @floatFromInt(sub_w))) / 2.0);
    Text.draw(subtitle, sub_x, @as(i32, @intFromFloat(screen_height * 0.12)) + title_size + 8, subtitle_size, ui_style.text_muted);

    const button_w: f32 = 340.0 * ui_style.scale;
    const button_h: f32 = 46.0 * ui_style.scale;
    const start_y: f32 = screen_height * 0.42;
    const x: f32 = (screen_width - button_w) / 2.0;

    const single_id = std.hash.Wyhash.hash(0, "menu_singleplayer");
    if (menu.ctx.button(single_id, Rectangle{ .x = x, .y = start_y, .width = button_w, .height = button_h }, "Singleplayer")) {
        menu.refreshWorlds();
        status_message.set("Select a world", STATUS_MESSAGE_DURATION);
        return .singleplayer;
    }

    const multiplayer_id = std.hash.Wyhash.hash(0, "menu_multiplayer");
    if (menu.ctx.button(multiplayer_id, Rectangle{ .x = x, .y = start_y + button_h + 12, .width = button_w, .height = button_h }, "Multiplayer")) {
        return .multiplayer;
    }

    const options_id = std.hash.Wyhash.hash(0, "menu_options");
    if (menu.ctx.button(options_id, Rectangle{ .x = x, .y = start_y + (button_h + 12) * 2, .width = button_w, .height = button_h }, "Options")) {
        status_message.set("Use in-game Settings panel for now (F2)", STATUS_MESSAGE_DURATION + 1.5);
        return .none;
    }

    const quit_id = std.hash.Wyhash.hash(0, "menu_quit");
    if (menu.ctx.button(quit_id, Rectangle{ .x = x, .y = start_y + (button_h + 12) * 3, .width = button_w, .height = button_h }, "Quit")) {
        return .quit;
    }

    return .none;
}

fn drawWorldListMenu(menu: *MenuState, ui_style: ui_mod.UiStyle, status_message: *StatusMessage, screen_width: f32, screen_height: f32) WorldMenuAction {
    const header = "Select World";
    const header_w = Text.measure(header, ui_style.font_size);
    Text.draw(header, @intFromFloat((screen_width - @as(f32, @floatFromInt(header_w))) / 2.0), @intFromFloat(24.0 * ui_style.scale), ui_style.font_size, ui_style.text);

    const list_w: f32 = 620.0 * ui_style.scale;
    const row_h: f32 = 44.0 * ui_style.scale;
    const list_x: f32 = (screen_width - list_w) / 2.0;
    const list_y: f32 = 90.0 * ui_style.scale;
    const max_rows: usize = @intFromFloat(@max(1.0, (screen_height - list_y - 180.0 * ui_style.scale) / (row_h + 10.0)));

    const start_index: usize = 0;
    const end_index: usize = @min(menu.worlds.len, start_index + max_rows);

    var selected: ?usize = null;
    for (start_index..end_index) |i| {
        const entry = menu.worlds[i];
        var name_buf: [80:0]u8 = undefined;
        const label = std.fmt.bufPrintZ(&name_buf, "{s}", .{entry.meta.name}) catch "World";
        const y = list_y + @as(f32, @floatFromInt(i - start_index)) * (row_h + 10.0);
        const id = std.hash.Wyhash.hash(0, entry.folder);
        const clicked = menu.ctx.button(id, Rectangle{ .x = list_x, .y = y, .width = list_w, .height = row_h }, label);
        if (clicked) {
            menu.selected_world = i;
            selected = i;
        }
    }

    if (menu.worlds.len == 0) {
        Text.draw("No worlds found.", @intFromFloat(list_x), @intFromFloat(list_y), ui_style.small_font_size, ui_style.text_muted);
        Text.draw("Create a new world to begin.", @intFromFloat(list_x), @intFromFloat(list_y + 22.0 * ui_style.scale), ui_style.small_font_size, ui_style.text_muted);
    }

    const button_w: f32 = 300.0 * ui_style.scale;
    const button_h: f32 = 44.0 * ui_style.scale;
    const button_y: f32 = screen_height - 120.0 * ui_style.scale;
    const left_x: f32 = (screen_width - (button_w * 2.0 + 20.0 * ui_style.scale)) / 2.0;

    const create_id = std.hash.Wyhash.hash(0, "world_create");
    if (menu.ctx.button(create_id, Rectangle{ .x = left_x, .y = button_y, .width = button_w, .height = button_h }, "Create New World")) {
        menu.create_name.clear();
        status_message.set("Type a name and press Enter", STATUS_MESSAGE_DURATION + 1.5);
        menu.selected_world = null;
        return .create_world;
    }

    const back_id = std.hash.Wyhash.hash(0, "world_back");
    if (menu.ctx.button(back_id, Rectangle{ .x = left_x + button_w + 20.0 * ui_style.scale, .y = button_y, .width = button_w, .height = button_h }, "Back")) {
        return .back;
    }

    if (selected != null) {
        status_message.set("Press Play to start", STATUS_MESSAGE_DURATION);
    }

    const play_id = std.hash.Wyhash.hash(0, "world_play");
    const play_y: f32 = button_y - (button_h + 12.0 * ui_style.scale);
    const play_x: f32 = (screen_width - button_w) / 2.0;
    const can_play = menu.selected_world != null and menu.selected_world.? < menu.worlds.len;
    const play_label: [:0]const u8 = if (can_play) "Play Selected World" else "Select a World";
    if (menu.ctx.button(play_id, Rectangle{ .x = play_x, .y = play_y, .width = button_w, .height = button_h }, play_label) and can_play) {
        return .play_selected;
    }

    return .none;
}

const ServerBrowserAction = enum {
    none,
    back,
    connect,
};

fn drawServerBrowser(menu: *MenuState, ui_style: ui_mod.UiStyle, status_message: *StatusMessage, screen_width: f32, screen_height: f32) ServerBrowserAction {
    const header = "Server Browser";
    const header_w = Text.measure(header, ui_style.font_size);
    Text.draw(header, @intFromFloat((screen_width - @as(f32, @floatFromInt(header_w))) / 2.0), @intFromFloat(24.0 * ui_style.scale), ui_style.font_size, ui_style.text);

    const list_w: f32 = 620.0 * ui_style.scale;
    const row_h: f32 = 44.0 * ui_style.scale;
    const list_x: f32 = (screen_width - list_w) / 2.0;
    const list_y: f32 = 90.0 * ui_style.scale;

    // Placeholder server list (in a real implementation, this would be fetched from a server)
    const servers = [_][]const u8{
        "localhost:1234 - Local Development Server",
        "game.example.com:5678 - Public Server 1",
        "multiplayer.demo.net:9999 - Demo Server",
    };

    var selected: ?usize = null;
    for (servers, 0..) |server, i| {
        const y = list_y + @as(f32, @floatFromInt(i)) * (row_h + 10.0);
        const id = std.hash.Wyhash.hash(0, std.fmt.allocPrint(menu.allocator, "server_{d}", .{i}) catch "server");
        // Convert server name to null-terminated string for button label
        var server_buf: [128:0]u8 = undefined;
        const server_label = std.fmt.bufPrintZ(&server_buf, "{s}", .{server}) catch "Server";
        const clicked = menu.ctx.button(id, Rectangle{ .x = list_x, .y = y, .width = list_w, .height = row_h }, server_label);
        if (clicked) {
            selected = i;
        }
    }

    const button_w: f32 = 300.0 * ui_style.scale;
    const button_h: f32 = 44.0 * ui_style.scale;
    const button_y: f32 = screen_height - 120.0 * ui_style.scale;
    const left_x: f32 = (screen_width - (button_w * 2.0 + 20.0 * ui_style.scale)) / 2.0;

    const connect_id = std.hash.Wyhash.hash(0, "server_connect");
    if (menu.ctx.button(connect_id, Rectangle{ .x = left_x, .y = button_y, .width = button_w, .height = button_h }, "Connect to Selected") and selected != null) {
        return .connect;
    }

    const back_id = std.hash.Wyhash.hash(0, "server_back");
    if (menu.ctx.button(back_id, Rectangle{ .x = left_x + button_w + 20.0 * ui_style.scale, .y = button_y, .width = button_w, .height = button_h }, "Back")) {
        return .back;
    }

    if (selected != null) {
        status_message.set("Click Connect to join server", STATUS_MESSAGE_DURATION);
    }

    return .none;
}

fn updateNameInput(input: *NameInput) void {
    var c: i32 = Input.Keyboard.getCharPressed();
    while (c != 0) : (c = Input.Keyboard.getCharPressed()) {
        if (c >= 32 and c <= 126) {
            input.pushAscii(@intCast(c));
        }
    }

    if (Input.Keyboard.isPressed(KeyboardKey.backspace)) {
        input.pop();
    }
}

const CreateWorldResult = union(enum) {
    none,
    back,
    created: WorldSession,
};

fn drawCreateWorldMenu(menu: *MenuState, ui_style: ui_mod.UiStyle, status_message: *StatusMessage, screen_width: f32, screen_height: f32) CreateWorldResult {
    const header = "Create New World";
    const header_w = Text.measure(header, ui_style.font_size);
    Text.draw(header, @intFromFloat((screen_width - @as(f32, @floatFromInt(header_w))) / 2.0), @intFromFloat(24.0 * ui_style.scale), ui_style.font_size, ui_style.text);

    updateNameInput(&menu.create_name);

    const field_w: f32 = 620.0 * ui_style.scale;
    const field_h: f32 = 54.0 * ui_style.scale;
    const field_x: f32 = (screen_width - field_w) / 2.0;
    const field_y: f32 = screen_height * 0.32;

    Shapes.drawRectangleRec(Rectangle{ .x = field_x, .y = field_y, .width = field_w, .height = field_h }, ui_style.panel_bg);
    Shapes.drawRectangleLinesEx(Rectangle{ .x = field_x, .y = field_y, .width = field_w, .height = field_h }, ui_style.border_width, ui_style.panel_border);

    var text_buf: [64:0]u8 = undefined;
    const name = menu.create_name.asSlice();
    const display = if (name.len == 0) "World name..." else std.fmt.bufPrintZ(&text_buf, "{s}", .{name}) catch "World";
    Text.draw(display, @intFromFloat(field_x + 14.0 * ui_style.scale), @intFromFloat(field_y + 16.0 * ui_style.scale), ui_style.font_size, if (name.len == 0) ui_style.text_muted else ui_style.text);

    if (Input.Keyboard.isPressed(KeyboardKey.enter)) {
        const world = worlds_mod.createWorld(menu.allocator, name) catch {
            status_message.set("Invalid world name", STATUS_MESSAGE_DURATION);
            return .none;
        };

        const session = WorldSession{
            .allocator = menu.allocator,
            .folder = menu.allocator.dupe(u8, world.folder) catch unreachable,
            .name = menu.allocator.dupe(u8, world.meta.name) catch unreachable,
        };
        // world owns its buffers; free it now.
        var tmp = world;
        tmp.deinit();

        status_message.set("World created!", STATUS_MESSAGE_DURATION);
        return .{ .created = session };
    }

    const button_w: f32 = 300.0 * ui_style.scale;
    const button_h: f32 = 44.0 * ui_style.scale;
    const button_y: f32 = screen_height - 120.0 * ui_style.scale;
    const left_x: f32 = (screen_width - (button_w * 2.0 + 20.0 * ui_style.scale)) / 2.0;

    const create_id = std.hash.Wyhash.hash(0, "create_confirm");
    if (menu.ctx.button(create_id, Rectangle{ .x = left_x, .y = button_y, .width = button_w, .height = button_h }, "Create")) {
        if (name.len == 0) {
            status_message.set("Enter a world name", STATUS_MESSAGE_DURATION);
            return .none;
        }
        const world = worlds_mod.createWorld(menu.allocator, name) catch {
            status_message.set("Invalid world name", STATUS_MESSAGE_DURATION);
            return .none;
        };

        const session = WorldSession{
            .allocator = menu.allocator,
            .folder = menu.allocator.dupe(u8, world.folder) catch unreachable,
            .name = menu.allocator.dupe(u8, world.meta.name) catch unreachable,
        };
        var tmp = world;
        tmp.deinit();

        status_message.set("World created!", STATUS_MESSAGE_DURATION);
        return .{ .created = session };
    }

    const back_id = std.hash.Wyhash.hash(0, "create_back");
    if (menu.ctx.button(back_id, Rectangle{ .x = left_x + button_w + 20.0 * ui_style.scale, .y = button_y, .width = button_w, .height = button_h }, "Back")) {
        return .back;
    }

    Text.draw("Press Enter to create.", @intFromFloat(field_x), @intFromFloat(field_y + field_h + 10.0 * ui_style.scale), ui_style.small_font_size, ui_style.text_muted);
    return .none;
}

fn drawPauseMenu(menu: *MenuState, ui_style: ui_mod.UiStyle, status_message: *StatusMessage, screen_width: f32, screen_height: f32) PauseMenuAction {
    _ = status_message;
    Shapes.drawRectangleRec(Rectangle{ .x = 0, .y = 0, .width = screen_width, .height = screen_height }, Color{ .r = 0, .g = 0, .b = 0, .a = 120 });

    const header = "Paused";
    const header_w = Text.measure(header, ui_style.font_size);
    Text.draw(header, @intFromFloat((screen_width - @as(f32, @floatFromInt(header_w))) / 2.0), @intFromFloat(screen_height * 0.2), ui_style.font_size, ui_style.text);

    const button_w: f32 = 340.0 * ui_style.scale;
    const button_h: f32 = 46.0 * ui_style.scale;
    const start_y: f32 = screen_height * 0.34;
    const x: f32 = (screen_width - button_w) / 2.0;

    const resume_id = std.hash.Wyhash.hash(0, "pause_resume");
    if (menu.ctx.button(resume_id, Rectangle{ .x = x, .y = start_y, .width = button_w, .height = button_h }, "Resume Game")) {
        return .unpause;
    }

    const quit_id = std.hash.Wyhash.hash(0, "pause_quit");
    if (menu.ctx.button(quit_id, Rectangle{ .x = x, .y = start_y + button_h + 12, .width = button_w, .height = button_h }, "Save & Quit to Title")) {
        return .quit_to_title;
    }

    return .none;
}

/// Draw instructions at the bottom of the screen
fn drawInstructions(screen_width: f32, screen_height: f32) void {
    const instructions = "WASD / Arrows move — R restart — F1 edit UI — F2 settings — Drop files (or nyon_ui.json)";
    const text_width = Text.measure(instructions, UI_INSTRUCTION_FONT_SIZE);
    const text_x: i32 = @intFromFloat((screen_width - @as(f32, @floatFromInt(text_width))) / 2.0);
    const text_y: i32 = @intFromFloat(screen_height - UI_INSTRUCTION_Y_OFFSET);

    Text.draw(
        instructions,
        text_x,
        text_y,
        UI_INSTRUCTION_FONT_SIZE,
        COLOR_TEXT_GRAY,
    );
}

fn drawStatusMessage(status: *const StatusMessage, screen_width: f32) void {
    if (!status.isActive()) return;

    const text = status.textZ();
    const text_width = Text.measure(text, STATUS_MESSAGE_FONT_SIZE);
    const text_x: i32 = @intFromFloat((screen_width - @as(f32, @floatFromInt(text_width))) / 2.0);

    const alpha_byte = status.alphaU8();
    const message_color = Color{
        .r = COLOR_STATUS_MESSAGE.r,
        .g = COLOR_STATUS_MESSAGE.g,
        .b = COLOR_STATUS_MESSAGE.b,
        .a = alpha_byte,
    };

    Text.draw(text, text_x, STATUS_MESSAGE_Y_OFFSET, STATUS_MESSAGE_FONT_SIZE, message_color);
}

/// Draw win message if all items are collected
fn drawWinMessage(screen_width: f32, screen_height: f32) void {
    const win_text = "YOU WIN!";
    const win_width = Text.measure(win_text, UI_WIN_FONT_SIZE);
    const win_x = @as(i32, @intFromFloat((screen_width - @as(f32, @floatFromInt(win_width))) / 2.0));
    const win_y = @as(i32, @intFromFloat(screen_height / 2.0 - UI_WIN_Y_OFFSET));

    Text.draw(
        win_text,
        win_x,
        win_y,
        UI_WIN_FONT_SIZE,
        COLOR_WIN,
    );

    const hint_text = "Press R to replay";
    const hint_width = Text.measure(hint_text, UI_INSTRUCTION_FONT_SIZE);
    const hint_x = @as(i32, @intFromFloat((screen_width - @as(f32, @floatFromInt(hint_width))) / 2.0));
    const hint_y = win_y + UI_WIN_FONT_SIZE + 10;
    Text.draw(
        hint_text,
        hint_x,
        hint_y,
        UI_INSTRUCTION_FONT_SIZE,
        COLOR_TEXT_GRAY,
    );
}

// ============================================================================
// Main Entry Point
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Use arena allocator for frame-based allocations (modern pattern)
    var frame_arena = std.heap.ArenaAllocator.init(allocator);
    defer frame_arena.deinit();
    const frame_allocator = frame_arena.allocator();

    // Initialize engine with raylib backend
    var engine = try Engine.init(allocator, .{
        .backend = .raylib,
        .width = WINDOW_WIDTH,
        .height = WINDOW_HEIGHT,
        .title = WINDOW_TITLE,
        .target_fps = TARGET_FPS,
        .resizable = true,
        .vsync = true,
        .samples = 4,
    });
    defer engine.deinit();

    var game_state = GameState{};
    resetGameState(&game_state);
    var status_message = StatusMessage{};
    status_message.set("Collect every item to win!", STATUS_MESSAGE_DURATION);
    var ui_state = GameUiState.initWithDefaultScale(allocator, defaultUiScaleFromDpi());
    var menu_state = MenuState.init(allocator);
    defer menu_state.deinit();
    defer ui_state.deinit();

    var app_mode: AppMode = .title;
    var world_session: ?WorldSession = null;
    defer clearWorldSession(&world_session);

    var args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len > 1) {
        const arg_path = args[1];
        if (arg_path.len > 0) {
            loadFileMetadata(&game_state, &status_message, arg_path) catch {
                var err_buf: [128:0]u8 = undefined;
                const err_msg = std.fmt.bufPrintZ(&err_buf, "Could not open {s}", .{arg_path}) catch "Could not open file";
                status_message.set(err_msg, STATUS_MESSAGE_DURATION);
            };
        }
    }

    // Initialize audio device
    Audio.initDevice();
    defer Audio.closeDevice();

    // Main game loop
    var quit_requested = false;
    while (!engine.shouldClose() and !quit_requested) {
        // Reset frame arena for temporary allocations
        _ = frame_arena.reset(.{ .retain_capacity = {} });

        engine.pollEvents();
        const window_size = engine.getWindowSize();
        const screen_width = @as(f32, @floatFromInt(window_size.width));
        const screen_height = @as(f32, @floatFromInt(window_size.height));

        const ctrl_down = Input.Keyboard.isDown(KeyboardKey.left_control) or Input.Keyboard.isDown(KeyboardKey.right_control);

        const ui_input = ui_mod.FrameInput{
            .mouse_pos = Input.Mouse.getPosition(),
            .mouse_pressed = Input.Mouse.isButtonPressed(MouseButton.left),
            .mouse_down = Input.Mouse.isButtonDown(MouseButton.left),
            .mouse_released = Input.Mouse.isButtonReleased(MouseButton.left),
        };

        engine.beginDrawing();

        // Update game time
        const delta_time = try engine.getFrameTime();
        status_message.update(delta_time);

        // Clear background
        engine.clearBackground(COLOR_BACKGROUND);

        switch (app_mode) {
            .title => {
                menu_state.ctx.beginFrame(ui_input, ui_state.style());
                defer menu_state.ctx.endFrame();

                const action = drawTitleMenu(&menu_state, ui_state.style(), &status_message, screen_width, screen_height);
                drawStatusMessage(&status_message, screen_width);
                if (action == .singleplayer) {
                    app_mode = .worlds;
                } else if (action == .multiplayer) {
                    app_mode = .server_browser;
                } else if (action == .quit) {
                    quit_requested = true;
                }
            },
            .worlds => {
                if (Input.Keyboard.isPressed(KeyboardKey.escape)) {
                    app_mode = .title;
                }

                menu_state.ctx.beginFrame(ui_input, ui_state.style());
                defer menu_state.ctx.endFrame();

                const action = drawWorldListMenu(&menu_state, ui_state.style(), &status_message, screen_width, screen_height);
                drawStatusMessage(&status_message, screen_width);

                if (action == .back) {
                    app_mode = .title;
                } else if (action == .create_world) {
                    app_mode = .create_world;
                } else if (action == .play_selected) {
                    if (menu_state.selected_world) |idx| {
                        const entry = menu_state.worlds[idx];
                        setWorldSession(&world_session, WorldSession{
                            .allocator = allocator,
                            .folder = try allocator.dupe(u8, entry.folder),
                            .name = try allocator.dupe(u8, entry.meta.name),
                        });
                        game_state.best_score = entry.meta.best_score;
                        if (entry.meta.best_time_ms) |ms| {
                            game_state.best_time = @as(f32, @floatFromInt(ms)) / 1000.0;
                        } else {
                            game_state.best_time = null;
                        }
                        resetGameState(&game_state);
                        status_message.set("World loaded!", STATUS_MESSAGE_DURATION);
                        app_mode = .playing;
                    }
                }
            },
            .create_world => {
                if (Input.Keyboard.isPressed(KeyboardKey.escape)) {
                    app_mode = .worlds;
                }

                menu_state.ctx.beginFrame(ui_input, ui_state.style());
                defer menu_state.ctx.endFrame();

                const result = drawCreateWorldMenu(&menu_state, ui_state.style(), &status_message, screen_width, screen_height);
                drawStatusMessage(&status_message, screen_width);
                switch (result) {
                    .none => {},
                    .back => app_mode = .worlds,
                    .created => |session| {
                        setWorldSession(&world_session, session);
                        game_state.best_score = 0;
                        game_state.best_time = null;
                        resetGameState(&game_state);
                        status_message.set("Entering new world...", STATUS_MESSAGE_DURATION);
                        app_mode = .playing;
                    },
                }
            },
            .server_browser => {
                if (Input.Keyboard.isPressed(KeyboardKey.escape)) {
                    app_mode = .title;
                }

                menu_state.ctx.beginFrame(ui_input, ui_state.style());
                defer menu_state.ctx.endFrame();

                const action = drawServerBrowser(&menu_state, ui_state.style(), &status_message, screen_width, screen_height);
                drawStatusMessage(&status_message, screen_width);

                if (action == .back) {
                    app_mode = .title;
                } else if (action == .connect) {
                    // TODO: Implement server connection
                    status_message.set("Server connection not yet implemented", STATUS_MESSAGE_DURATION);
                }
            },
            .playing, .paused => {
                ui_state.ctx.beginFrame(ui_input, ui_state.style());
                defer ui_state.ctx.endFrame();

                var player_moved_draw = false;
                var has_won_draw = isGameWon(&game_state);

                if (app_mode == .playing) {
                    if (Input.Keyboard.isPressed(KeyboardKey.escape)) {
                        app_mode = .paused;
                    }

                    if (Input.Keyboard.isPressed(KeyboardKey.f1)) {
                        ui_state.edit_mode = !ui_state.edit_mode;
                        status_message.set(if (ui_state.edit_mode) "UI edit mode enabled" else "UI edit mode disabled", STATUS_MESSAGE_DURATION);
                    }

                    if (Input.Keyboard.isPressed(KeyboardKey.f2)) {
                        ui_state.config.settings.visible = !ui_state.config.settings.visible;
                        ui_state.dirty = true;
                        status_message.set(if (ui_state.config.settings.visible) "Settings opened" else "Settings hidden", STATUS_MESSAGE_DURATION);
                    }

                    if (ctrl_down and Input.Keyboard.isPressed(KeyboardKey.s)) {
                        ui_state.config.save(allocator, ui_mod.UiConfig.DEFAULT_PATH) catch {
                            status_message.set("Failed to save UI layout", STATUS_MESSAGE_DURATION);
                        };
                        ui_state.dirty = false;
                        status_message.set("Saved UI layout", STATUS_MESSAGE_DURATION);
                    }

                    if (ctrl_down and Input.Keyboard.isPressed(KeyboardKey.r)) {
                        ui_state.config = ui_mod.UiConfig{};
                        ui_state.dirty = true;
                        status_message.set("Reset UI layout", STATUS_MESSAGE_DURATION);
                    } else if (Input.Keyboard.isPressed(KeyboardKey.r)) {
                        resetGameState(&game_state);
                        status_message.set("Reset complete! Collect them again!", STATUS_MESSAGE_DURATION);
                    }

                    game_state.game_time += delta_time;
                    handleDroppedFile(&game_state, &ui_state, &status_message, allocator, frame_allocator) catch {
                        status_message.set("Failed to read dropped file", STATUS_MESSAGE_DURATION);
                    };

                    const player_moved = if (ui_state.edit_mode and (ui_input.mouse_down or ctrl_down))
                        false
                    else
                        handleInput(&game_state, delta_time, screen_width, screen_height);
                    player_moved_draw = player_moved;

                    const collected = checkCollisions(&game_state);
                    if (collected > 0 and game_state.remaining_items > 0) {
                        var collect_buf: [80:0]u8 = undefined;
                        const collect_str = try std.fmt.bufPrintZ(&collect_buf, "{d} item(s) left", .{game_state.remaining_items});
                        status_message.set(collect_str, STATUS_MESSAGE_DURATION);
                    }

                    const has_won = isGameWon(&game_state);
                    has_won_draw = has_won;
                    if (has_won and !game_state.has_won) {
                        game_state.has_won = true;
                        const completion_time = game_state.game_time;
                        var win_buf: [128:0]u8 = undefined;
                        if (game_state.best_time) |prev_best| {
                            if (completion_time < prev_best) {
                                game_state.best_time = completion_time;
                                const win_str = try std.fmt.bufPrintZ(&win_buf, "New personal best! {d:.2}s", .{completion_time});
                                status_message.set(win_str, STATUS_MESSAGE_DURATION + 1.5);
                            } else {
                                const win_str = try std.fmt.bufPrintZ(&win_buf, "You win! {d:.2}s (best {d:.2}s)", .{ completion_time, prev_best });
                                status_message.set(win_str, STATUS_MESSAGE_DURATION);
                            }
                        } else {
                            game_state.best_time = completion_time;
                            const win_str = try std.fmt.bufPrintZ(&win_buf, "First win in {d:.2}s!", .{completion_time});
                            status_message.set(win_str, STATUS_MESSAGE_DURATION + 1.5);
                        }
                    } else if (!has_won) {
                        game_state.has_won = false;
                    }
                } else {
                    if (Input.Keyboard.isPressed(KeyboardKey.escape)) {
                        app_mode = .playing;
                    }
                }

                // Draw game elements
                drawGrid(screen_width, screen_height);
                drawItems(&game_state);
                drawPlayer(&game_state, player_moved_draw);

                // Draw UI
                try drawUI(&game_state, &ui_state, &status_message, allocator, screen_width, screen_height);
                drawStatusMessage(&status_message, screen_width);
                drawInstructions(screen_width, screen_height);

                if (has_won_draw) {
                    drawWinMessage(screen_width, screen_height);
                }

                if (app_mode == .paused) {
                    menu_state.ctx.beginFrame(ui_input, ui_state.style());
                    defer menu_state.ctx.endFrame();

                    const action = drawPauseMenu(&menu_state, ui_state.style(), &status_message, screen_width, screen_height);
                    if (action == .unpause) {
                        app_mode = .playing;
                    } else if (action == .quit_to_title) {
                        if (world_session) |session| {
                            const best_time_ms: ?u32 = if (game_state.best_time) |t| @intFromFloat(t * 1000.0) else null;
                            worlds_mod.touchWorld(allocator, session.folder, game_state.best_score, best_time_ms) catch {};
                        }
                        clearWorldSession(&world_session);
                        app_mode = .title;
                    }
                }
            },
        }

        engine.endDrawing();
    }

    if (ui_state.dirty) {
        ui_state.config.save(allocator, ui_mod.UiConfig.DEFAULT_PATH) catch {};
    }

    if (world_session) |session| {
        const best_time_ms: ?u32 = if (game_state.best_time) |t| @intFromFloat(t * 1000.0) else null;
        worlds_mod.touchWorld(allocator, session.folder, game_state.best_score, best_time_ms) catch {};
    }
}
