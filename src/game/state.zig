//! Game state management for the Nyon Game Engine
//!
//! This module handles the core game state structures and management
//! functions for the collect-items game.

const std = @import("std");
const FileDetail = @import("../io/file_detail.zig").FileDetail;
const file_metadata = @import("../io/file_metadata.zig");

// ============================================================================
// Game Constants
// ============================================================================

pub const WINDOW_WIDTH: u32 = 800;
pub const WINDOW_HEIGHT: u32 = 600;
pub const WINDOW_TITLE = "Nyon Game - Collect Items!";
pub const TARGET_FPS: u32 = 60;

// Game constants
pub const PLAYER_START_X: f32 = 400.0;
pub const PLAYER_START_Y: f32 = 300.0;
pub const PLAYER_SPEED: f32 = 200.0;
pub const PLAYER_SIZE: f32 = 30.0;
pub const ITEM_SIZE: f32 = 15.0;
pub const ITEM_COLLECTION_RADIUS: f32 = PLAYER_SIZE + ITEM_SIZE;
pub const ITEM_SCORE_VALUE: u32 = 10;
pub const DEFAULT_ITEM_COUNT: usize = 5;
pub const INITIAL_ITEM_POSITIONS: [DEFAULT_ITEM_COUNT][2]f32 = .{
    .{ 100, 100 },
    .{ 200, 150 },
    .{ 300, 200 },
    .{ 500, 250 },
    .{ 700, 400 },
};

// Animation constants
pub const ITEM_PULSE_SPEED: f32 = 3.0;
pub const ITEM_PULSE_AMPLITUDE: f32 = 0.2;

// ============================================================================
// Game State Structures
// ============================================================================

/// Represents a collectible item in the game
pub const CollectibleItem = struct {
    x: f32,
    y: f32,
    collected: bool,
};

/// Main game state structure containing all game data
pub const GameState = struct {
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

/// Represents a world session for save/load functionality
pub const WorldSession = struct {
    allocator: std.mem.Allocator,
    folder: []u8,
    name: []u8,

    pub fn deinit(self: *WorldSession) void {
        self.allocator.free(self.folder);
        self.allocator.free(self.name);
        self.* = undefined;
    }
};

// ============================================================================
// Game State Management Functions
// ============================================================================

/// Reset the game state to initial values
pub fn resetGameState(game_state: *GameState) void {
    var idx: usize = 0;
    for (game_state.items[0..]) |*item| {
        const pos = INITIAL_ITEM_POSITIONS[idx];
        item.* = CollectibleItem{ .x = pos[0], .y = pos[1], .collected = false };
        idx += 1;
    }
    game_state.remaining_items = DEFAULT_ITEM_COUNT;
    game_state.score = 0;
    game_state.game_time = 0.0;
    game_state.player_x = PLAYER_START_X;
    game_state.player_y = PLAYER_START_Y;
    game_state.has_won = false;
    game_state.file_info.clear();
}

/// Update file information in the game state
pub fn updateFileInfo(game_state: *GameState, path: []const u8) !void {
    const meta = try file_metadata.get(path);
    game_state.file_info.set(path, meta.size, meta.modified_ns);
}

/// Clear a world session
pub fn clearWorldSession(session: *?WorldSession) void {
    if (session.*) |*active| {
        active.deinit();
        session.* = null;
    }
}

/// Set a new world session
pub fn setWorldSession(session: *?WorldSession, value: WorldSession) void {
    clearWorldSession(session);
    session.* = value;
}
