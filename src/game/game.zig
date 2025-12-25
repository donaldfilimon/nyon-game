//! Core Game Logic
//!
//! This module contains the main game logic, input handling,
//! and game loop functionality.

const std = @import("std");
const engine_mod = @import("../engine.zig");
const state_mod = @import("state.zig");

const Engine = engine_mod.Engine;
const Input = engine_mod.Input;
const KeyboardKey = engine_mod.KeyboardKey;
const MouseButton = engine_mod.MouseButton;

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

/// Update game state for one frame
pub fn updateGame(game_state: *state_mod.GameState, delta_time: f32) void {
    game_state.game_time += delta_time;

    // Check for collisions
    const collected = state_mod.checkCollisions(game_state);

    // Check win condition
    const has_won = state_mod.isGameWon(game_state);
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
