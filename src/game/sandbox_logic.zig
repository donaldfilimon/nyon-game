//! Sandbox Game Logic and Rendering
//!
//! Handles core game mechanics, input, and game-specific drawing.

const std = @import("std");
const engine = @import("../engine.zig");
const game_state_mod = @import("state.zig");

const Color = engine.Color;
const Rectangle = engine.Rectangle;
const Input = engine.Input;
const KeyboardKey = engine.KeyboardKey;
const Shapes = engine.Shapes;

// Grid constants
pub const GRID_SIZE: f32 = 50.0;
pub const COLOR_GRID = Color{ .r = 40, .g = 40, .b = 60, .a = 255 };
pub const COLOR_ITEM = Color{ .r = 255, .g = 215, .b = 0, .a = 255 };
pub const COLOR_ITEM_OUTLINE = Color{ .r = 255, .g = 255, .b = 100, .a = 255 };
pub const COLOR_PLAYER_IDLE = Color{ .r = 150, .g = 150, .b = 255, .a = 255 };
pub const COLOR_PLAYER_MOVING = Color{ .r = 100, .g = 200, .b = 255, .a = 255 };
pub const COLOR_PLAYER_OUTLINE = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
pub const COLOR_PROGRESS_BG = Color{ .r = 60, .g = 60, .b = 80, .a = 255 };

/// Handle player input and update player position
pub fn handleInput(game_state: *game_state_mod.GameState, delta_time: f32, screen_width: f32, screen_height: f32) bool {
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
    game_state.player_x = std.math.clamp(game_state.player_x, game_state.player_size, screen_width - game_state.player_size);
    game_state.player_y = std.math.clamp(game_state.player_y, game_state.player_size, screen_height - game_state.player_size);

    return moved;
}

/// Check for collisions between player and collectible items
pub fn checkCollisions(game_state: *game_state_mod.GameState) usize {
    var collected: usize = 0;
    for (game_state.items[0..]) |*item| {
        if (!item.collected) {
            const dx = game_state.player_x - item.x;
            const dy = game_state.player_y - item.y;
            const distance = @sqrt(dx * dx + dy * dy);

            if (distance < game_state_mod.ITEM_COLLECTION_RADIUS) {
                item.collected = true;
                game_state.score += game_state_mod.ITEM_SCORE_VALUE;
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
pub fn isGameWon(game_state: *const game_state_mod.GameState) bool {
    for (game_state.items) |item| {
        if (!item.collected) {
            return false;
        }
    }
    return true;
}

/// Draw the grid background
pub fn drawGrid(screen_width: f32, screen_height: f32) void {
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
pub fn drawItems(game_state: *const game_state_mod.GameState) void {
    for (game_state.items) |item| {
        if (!item.collected) {
            const pulse = @sin(game_state.game_time * game_state_mod.ITEM_PULSE_SPEED) * game_state_mod.ITEM_PULSE_AMPLITUDE + 1.0;
            const size: f32 = game_state_mod.ITEM_SIZE * pulse;

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
pub fn drawPlayer(game_state: *const game_state_mod.GameState, is_moving: bool) void {
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
