const std = @import("std");
const engine_mod = @import("engine.zig");
const Engine = engine_mod.Engine;
const Audio = engine_mod.Audio;
const Input = engine_mod.Input;
const Shapes = engine_mod.Shapes;
const Text = engine_mod.Text;
const KeyboardKey = engine_mod.KeyboardKey;
const Color = engine_mod.Color;
const Rectangle = engine_mod.Rectangle;

// ============================================================================
// Constants
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

// Animation constants
const ITEM_PULSE_SPEED: f32 = 3.0;
const ITEM_PULSE_AMPLITUDE: f32 = 0.2;

// Grid constants
const GRID_SIZE: f32 = 50.0;

// UI constants
const UI_PANEL_X: i32 = 10;
const UI_PANEL_Y: i32 = 10;
const UI_PANEL_WIDTH: i32 = 200;
const UI_PANEL_HEIGHT: i32 = 100;
const UI_PANEL_BORDER_WIDTH: f32 = 2.0;
const UI_TEXT_X: i32 = 20;
const UI_SCORE_Y: i32 = 20;
const UI_TIME_Y: i32 = 45;
const UI_FPS_Y: i32 = 70;
const UI_FONT_SIZE: i32 = 20;
const UI_INSTRUCTION_FONT_SIZE: i32 = 16;
const UI_WIN_FONT_SIZE: i32 = 40;
const UI_INSTRUCTION_Y_OFFSET: i32 = 30;
const UI_WIN_Y_OFFSET: i32 = 20;

// Colors
const COLOR_BACKGROUND = Color{ .r = 30, .g = 30, .b = 50, .a = 255 };
const COLOR_GRID = Color{ .r = 40, .g = 40, .b = 60, .a = 255 };
const COLOR_ITEM = Color{ .r = 255, .g = 215, .b = 0, .a = 255 };
const COLOR_ITEM_OUTLINE = Color{ .r = 255, .g = 255, .b = 100, .a = 255 };
const COLOR_PLAYER_IDLE = Color{ .r = 150, .g = 150, .b = 255, .a = 255 };
const COLOR_PLAYER_MOVING = Color{ .r = 100, .g = 200, .b = 255, .a = 255 };
const COLOR_PLAYER_OUTLINE = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
const COLOR_UI_BACKGROUND = Color{ .r = 0, .g = 0, .b = 0, .a = 180 };
const COLOR_UI_BORDER = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
const COLOR_TEXT_WHITE = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
const COLOR_TEXT_BLUE = Color{ .r = 200, .g = 200, .b = 255, .a = 255 };
const COLOR_TEXT_GRAY = Color{ .r = 200, .g = 200, .b = 200, .a = 255 };
const COLOR_WIN = Color{ .r = 0, .g = 255, .b = 0, .a = 255 };

// ============================================================================
// Game State
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
    game_time: f32 = 0.0,
};

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
fn checkCollisions(game_state: *GameState) void {
    for (&game_state.items) |*item| {
        if (!item.collected) {
            const dx = game_state.player_x - item.x;
            const dy = game_state.player_y - item.y;
            const distance = @sqrt(dx * dx + dy * dy);

            if (distance < ITEM_COLLECTION_RADIUS) {
                item.collected = true;
                game_state.score += ITEM_SCORE_VALUE;
            }
        }
    }
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
fn drawUI(game_state: *const GameState) !void {
    // Draw UI background panel
    const ui_bg = Rectangle{
        .x = UI_PANEL_X,
        .y = UI_PANEL_Y,
        .width = UI_PANEL_WIDTH,
        .height = UI_PANEL_HEIGHT,
    };
    Shapes.drawRectangleRec(ui_bg, COLOR_UI_BACKGROUND);
    Shapes.drawRectangleLinesEx(ui_bg, UI_PANEL_BORDER_WIDTH, COLOR_UI_BORDER);

    // Draw score
    var score_text: [32:0]u8 = undefined;
    const score_str = try std.fmt.bufPrintZ(&score_text, "Score: {}", .{game_state.score});
    Text.draw(score_str, UI_TEXT_X, UI_SCORE_Y, UI_FONT_SIZE, COLOR_TEXT_WHITE);

    // Draw time
    var time_text: [32:0]u8 = undefined;
    const time_str = try std.fmt.bufPrintZ(&time_text, "Time: {d:.1}s", .{game_state.game_time});
    Text.draw(time_str, UI_TEXT_X, UI_TIME_Y, UI_FONT_SIZE, COLOR_TEXT_BLUE);

    // Draw FPS
    Text.drawFPS(UI_TEXT_X, UI_FPS_Y);
}

/// Draw instructions at the bottom of the screen
fn drawInstructions(screen_width: f32, screen_height: f32) void {
    const instructions = "WASD or Arrow Keys to move";
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
}

// ============================================================================
// Main Entry Point
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize engine with raylib backend
    var engine = try Engine.init(allocator, .{
        .backend = .raylib,
        .width = WINDOW_WIDTH,
        .height = WINDOW_HEIGHT,
        .title = WINDOW_TITLE,
        .target_fps = TARGET_FPS,
        .resizable = false,
        .vsync = true,
    });
    defer engine.deinit();

    var game_state = GameState{};
    const window_size = engine.getWindowSize();
    const screen_width = @as(f32, @floatFromInt(window_size.width));
    const screen_height = @as(f32, @floatFromInt(window_size.height));

    // Initialize audio device
    Audio.initDevice();
    defer Audio.closeDevice();

    // Main game loop
    while (!engine.shouldClose()) {
        engine.pollEvents();
        engine.beginDrawing();

        // Update game time
        const delta_time = engine.getFrameTime();
        game_state.game_time += delta_time;

        // Handle input and update player position
        const player_moved = handleInput(&game_state, delta_time, screen_width, screen_height);

        // Check for collisions
        checkCollisions(&game_state);

        // Clear background
        engine.clearBackground(COLOR_BACKGROUND);

        // Draw game elements
        drawGrid(screen_width, screen_height);
        drawItems(&game_state);
        drawPlayer(&game_state, player_moved);

        // Draw UI
        try drawUI(&game_state);
        drawInstructions(screen_width, screen_height);

        // Draw win message if game is won
        if (isGameWon(&game_state)) {
            drawWinMessage(screen_width, screen_height);
        }

        engine.endDrawing();
    }
}
