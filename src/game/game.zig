//! Core Game Logic
//!
//! This module contains the main game logic, input handling,
//! and game loop functionality.

const std = @import("std");
const math = std.math;
const engine_mod = @import("../engine.zig");
const state_mod = @import("state.zig");

const Engine = engine_mod.Engine;
const Input = engine_mod.Input;
const Shapes = engine_mod.Shapes;
const KeyboardKey = engine_mod.KeyboardKey;
const MouseButton = engine_mod.MouseButton;

// Grid constants
const GRID_SIZE: f32 = 50.0;

// Colors
const COLOR_GRID = engine_mod.Color{ .r = 40, .g = 40, .b = 60, .a = 255 };
const COLOR_ITEM = engine_mod.Color{ .r = 255, .g = 215, .b = 0, .a = 255 };
const COLOR_ITEM_OUTLINE = engine_mod.Color{ .r = 255, .g = 255, .b = 100, .a = 255 };
const COLOR_PLAYER_IDLE = engine_mod.Color{ .r = 150, .g = 150, .b = 255, .a = 255 };
const COLOR_PLAYER_MOVING = engine_mod.Color{ .r = 100, .g = 200, .b = 255, .a = 255 };
const COLOR_PLAYER_OUTLINE = engine_mod.Color{ .r = 255, .g = 255, .b = 255, .a = 255 };

// ============================================================================
// Input Handling
// ============================================================================

/// Handle player input and update player position
/// Returns true if the player moved this frame
pub fn handleInput(game_state: *state_mod.GameState, delta_time: f32, screen_width: f32, screen_height: f32) bool {
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

/// Handle dropped files
pub fn handleDroppedFile(
    game_state: *state_mod.GameState,
    ui_state: anytype, // TODO: Define proper UI state type
    status_message: anytype, // TODO: Define proper status message type
    allocator: std.mem.Allocator,
    frame_allocator: std.mem.Allocator,
) !void {
    _ = game_state;
    _ = ui_state;
    _ = status_message;
    _ = allocator;
    _ = frame_allocator;
    // TODO: Implement file dropping functionality
    // Temporarily disabled due to build issues
}

/// Load file metadata into game state
pub fn loadFileMetadata(game_state: *state_mod.GameState, status_message: anytype, path: []const u8) !void {
    try state_mod.updateFileInfo(game_state, path);

    var msg_buf: [160:0]u8 = undefined;
    const msg = try std.fmt.bufPrintZ(&msg_buf, "Loaded {s} ({d} bytes)", .{ path, game_state.file_info.size });
    // TODO: Set status message
    _ = msg;
    _ = status_message;
}

// ============================================================================
// Game Logic
// ============================================================================

/// Check if all items have been collected
pub fn isGameWon(game_state: *const state_mod.GameState) bool {
    for (game_state.items) |item| {
        if (!item.collected) {
            return false;
        }
    }
    return true;
}

/// Check for collisions between player and collectible items
/// Updates item collection state and score
pub fn checkCollisions(game_state: *state_mod.GameState) usize {
    var collected: usize = 0;
    for (game_state.items[0..]) |*item| {
        if (!item.collected) {
            const dx = game_state.player_x - item.x;
            const dy = game_state.player_y - item.y;
            const distance = @sqrt(dx * dx + dy * dy);

            if (distance < state_mod.ITEM_COLLECTION_RADIUS) {
                item.collected = true;
                game_state.score += state_mod.ITEM_SCORE_VALUE;
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

/// Update game state for one frame
pub fn updateGame(game_state: *state_mod.GameState, delta_time: f32) void {
    game_state.game_time += delta_time;

    // Check for collisions
    const collected = checkCollisions(game_state);

    // Check win condition
    const has_won = isGameWon(game_state);
    if (has_won and !game_state.has_won) {
        game_state.has_won = true;
        const completion_time = game_state.game_time;
        if (game_state.best_time) |prev_best| {
            if (completion_time < prev_best) {
                game_state.best_time = completion_time;
            }
        } else {
            game_state.best_time = completion_time;
        }
    } else if (!has_won) {
        game_state.has_won = false;
    }

    _ = collected; // TODO: Use for status messages
}

/// Reset game when R key is pressed
pub fn handleGameReset(game_state: *state_mod.GameState, status_message: anytype) void {
    state_mod.resetGameState(game_state);
    // TODO: Set status message
    _ = status_message;
}

// ============================================================================
// Drawing Functions
// ============================================================================

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
pub fn drawItems(game_state: *const state_mod.GameState) void {
    for (game_state.items) |item| {
        if (!item.collected) {
            // Pulsing animation
            const pulse = @sin(game_state.game_time * state_mod.ITEM_PULSE_SPEED) * state_mod.ITEM_PULSE_AMPLITUDE + 1.0;
            const size: f32 = state_mod.ITEM_SIZE * pulse;

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
pub fn drawPlayer(game_state: *const state_mod.GameState, is_moving: bool) void {
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
