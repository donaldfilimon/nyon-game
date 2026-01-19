//! Unit Tests for Nyon Game Engine
//!
//! This module provides unit tests for core game functionality.

const std = @import("std");

// ============================================================================
// Test Modules
// ============================================================================

// Game state tests
const game_state_mod = @import("game/state.zig");

// ============================================================================
// Unit Tests
// ============================================================================

test "game state - reset initializes correctly" {
    var state = game_state_mod.GameState{};
    game_state_mod.resetGameState(&state);

    try std.testing.expectEqual(state.player_x, game_state_mod.PLAYER_START_X);
    try std.testing.expectEqual(state.player_y, game_state_mod.PLAYER_START_Y);
    try std.testing.expectEqual(state.score, 0);
    try std.testing.expectEqual(state.remaining_items, game_state_mod.DEFAULT_ITEM_COUNT);
    try std.testing.expectEqual(state.has_won, false);
}

test "game state - collectible items are reset" {
    var state = game_state_mod.GameState{};
    // Modify some items
    state.items[0].collected = true;
    state.items[1].x = 999;

    game_state_mod.resetGameState(&state);

    // Check items are reset
    try std.testing.expectEqual(state.items[0].collected, false);
    try std.testing.expectEqual(state.items[0].x, 100);
    try std.testing.expectEqual(state.items[1].x, 200);
}

test "world session - deinit cleans up properly" {
    const allocator = std.testing.allocator;
    var session = game_state_mod.WorldSession{
        .allocator = allocator,
        .folder = try allocator.dupe(u8, "test_folder"),
        .name = try allocator.dupe(u8, "test_world"),
    };

    session.deinit();

    // Should have empty fields
    try std.testing.expectEqual(session.folder.len, 0);
    try std.testing.expectEqual(session.name.len, 0);
}

test "world session - folder and name allocation" {
    const allocator = std.testing.allocator;

    var session = game_state_mod.WorldSession{
        .allocator = allocator,
        .folder = try allocator.dupe(u8, "test_folder"),
        .name = try allocator.dupe(u8, "test_world"),
    };
    defer session.deinit();

    try std.testing.expectEqualStrings(session.folder, "test_folder");
    try std.testing.expectEqualStrings(session.name, "test_world");
}
