//! Centralized configuration for Nyon Game Engine.

const std = @import("std");

pub const UI = struct {
    pub const MIN_SCALE: f32 = 0.6;
    pub const MAX_SCALE: f32 = 2.5;
    pub const MIN_TOUCH_TARGET: f32 = 44.0;
    pub const DEFAULT_FONT_SIZE: i32 = 20;
    pub const SMALL_FONT_SIZE: i32 = 16;
    pub const TITLE_FONT_SIZE: i32 = 24;
    pub const DEFAULT_PADDING: i32 = 14;
    pub const PANEL_TITLE_HEIGHT: i32 = 30;
    pub const MIN_PANEL_WIDTH: f32 = 220.0;
    pub const MIN_PANEL_HEIGHT: f32 = 160.0;
    pub const DEFAULT_OPACITY: u8 = 180;
    pub const STATUS_DURATION: f32 = 3.0;
    pub const INSTRUCTION_FONT_SIZE: i32 = 16;
    pub const INSTRUCTION_Y_OFFSET: i32 = 30;
    pub const STATUS_MESSAGE_FONT_SIZE: i32 = 18;
    pub const STATUS_MESSAGE_DURATION: f32 = 3.0;
    pub const STATUS_MESSAGE_Y_OFFSET: i32 = 8;
};

pub const Rendering = struct {
    pub const DEFAULT_WIDTH: u32 = 1920;
    pub const DEFAULT_HEIGHT: u32 = 1080;
    pub const WINDOW_WIDTH: u32 = 1280;
    pub const WINDOW_HEIGHT: u32 = 720;
    pub const TARGET_FPS: u32 = 60;
    pub const SHADOW_MAP_SIZE: u32 = 2048;
    pub const CUBE_MAP_SIZE: u32 = 512;
    pub const MAX_LIGHTS: usize = 16;
    pub const MAX_CAMERAS: usize = 8;
    pub const MAX_MATERIALS: usize = 256;
    pub const MAX_TEXTURES: usize = 1024;
    pub const MAX_SHADERS: usize = 64;
    pub const FRAME_BUFFER_SIZE: usize = 4096;
};

pub const Physics = struct {
    pub const GRAVITY: f32 = -9.81;
    pub const MAX_VELOCITY: f32 = 100.0;
    pub const MIN_VELOCITY: f32 = -100.0;
    pub const PLAYER_MASS: f32 = 50.0;
    pub const ENEMY_MASS: f32 = 50.0;
    pub const PLAYER_FORCE: f32 = 100.0;
    pub const RESPAWN_Y: f32 = -50.0;
};

pub const Game = struct {
    pub const GRID_SIZE: f32 = 50.0;
    pub const GRID_CELL_SIZE: i32 = 4;
    pub const BLOCK_SIZE: f32 = 1.0;
    pub const MAX_BLOCKS: usize = 10000;
    pub const MAX_WORLD_SIZE: usize = 1024;
    pub const DEFAULT_ITEM_COUNT: usize = 10;
    pub const WORLD_FILE_LIMIT: usize = 128 * 1024;
    pub const WORLD_DATA_LIMIT: usize = 512 * 1024;
    pub const ASSET_FILE_LIMIT: usize = 256 * 1024;
    pub const HALF_BLOCK: f32 = BLOCK_SIZE * 0.5;
    pub const WORLD_DATA_FILE: []const u8 = "world_data.json";
    pub const WORLD_DATA_VERSION: u32 = 1;
};

pub const Memory = struct {
    pub const ARENA_INITIAL: usize = 64 * 1024;
    pub const ARENA_MAX: usize = 4 * 1024 * 1024;
    pub const TEMP_BUFFER: usize = 1024 * 1024;
    pub const STRING_BUFFER: usize = 256;
    pub const FILE_BUFFER: usize = 512;
    pub const COMMAND_BUFFER: usize = 1024;
    pub const ECS_ARCHETYPE_INITIAL: usize = 32;
    pub const ECS_COMPONENT_TYPES_INITIAL: usize = 8;
    pub const PHYSICS_BODIES_INITIAL: usize = 128;
    pub const PHYSICS_COLLIDERS_INITIAL: usize = 128;
    pub const PHYSICS_CONSTRAINTS_INITIAL: usize = 32;
    pub const PHYSICS_AABBS_INITIAL: usize = 128;
    pub const PHYSICS_POTENTIAL_PAIRS_INITIAL: usize = 256;
    pub const PHYSICS_MANIFOLDS_INITIAL: usize = 128;
};

pub const Performance = struct {
    pub const HIGH_TO_MEDIUM: f32 = 30.0;
    pub const MEDIUM_TO_LOW: f32 = 50.0;
    pub const LOW_TO_CULLED: f32 = 100.0;
    pub const MAX_INSTANCES: usize = 1024;
    pub const MAX_HISTORY: usize = 100;
};

pub const Editor = struct {
    pub const TIMELINE_HEIGHT: f32 = 100.0;
    pub const GIZMO_SIZE: f32 = 50.0;
    pub const GRID_SIZE: f32 = 50.0;
};

pub const Colors = struct {
    pub const BACKGROUND = struct { r: u8 = 20, g: u8 = 28, b: u8 = 36, a: u8 = 255 };
    pub const GROUND = struct { r: u8 = 60, g: u8 = 70, b: u8 = 80, a: u8 = 255 };
    pub const HIGHLIGHT = struct { r: u8 = 255, g: u8 = 220, b: u8 = 120, a: u8 = 255 };
    pub const PREVIEW = struct { r: u8 = 120, g: u8 = 220, b: u8 = 160, a: u8 = 200 };
};

test "UI constants valid" {
    try std.testing.expect(UI.MIN_SCALE < UI.MAX_SCALE);
    try std.testing.expect(UI.MIN_TOUCH_TARGET > 0);
}

test "Rendering constants valid" {
    try std.testing.expect(Rendering.DEFAULT_WIDTH > 0);
    try std.testing.expect(Rendering.SHADOW_MAP_SIZE >= 1024);
}
