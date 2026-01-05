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
    pub const SETTINGS_MIN_WIDTH: f32 = 240.0;
    pub const SETTINGS_MIN_HEIGHT: f32 = 190.0;
    pub const DEFAULT_OPACITY: u8 = 180;
    pub const STATUS_DURATION: f32 = 3.0;
    pub const INSTRUCTION_FONT_SIZE: i32 = 16;
    pub const INSTRUCTION_Y_OFFSET: i32 = 30;
    pub const STATUS_MESSAGE_FONT_SIZE: i32 = 18;
    pub const STATUS_MESSAGE_DURATION: f32 = 3.0;
    pub const STATUS_MESSAGE_Y_OFFSET: i32 = 8;
    pub const PROGRESS_HEIGHT: f32 = 10.0;
    pub const WIN_FONT_SIZE: i32 = 40;
    pub const WIN_Y_OFFSET: i32 = 20;
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
    pub const EPSILON: f32 = 0.05; // Position comparison tolerance
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
    pub const TAB_BAR_HEIGHT: f32 = 40.0;
    pub const TOOLBAR_HEIGHT: f32 = 35.0;
    pub const STATUS_BAR_HEIGHT: f32 = 25.0;
    pub const PANEL_WIDTH: f32 = 300.0;
    pub const PANEL_HEIGHT: f32 = 200.0;
    pub const SCENE_OUTLINER_WIDTH: f32 = 300.0;
    pub const PROPERTY_INSPECTOR_WIDTH: f32 = 300.0;
};

pub const Scene = struct {
    pub const INITIAL_MODEL_CAPACITY: usize = 8;
    pub const INITIAL_LIGHT_CAPACITY: usize = 16;
    pub const INITIAL_CAMERA_CAPACITY: usize = 4;
};

pub const Colors = struct {
    pub const BACKGROUND = struct { r: u8 = 20, g: u8 = 28, b: u8 = 36, a: u8 = 255 };
    pub const GROUND = struct { r: u8 = 60, g: u8 = 70, b: u8 = 80, a: u8 = 255 };
    pub const HIGHLIGHT = struct { r: u8 = 255, g: u8 = 220, b: u8 = 120, a: u8 = 255 };
    pub const PREVIEW = struct { r: u8 = 120, g: u8 = 220, b: u8 = 160, a: u8 = 200 };
    pub const STATUS_MESSAGE = struct { r: u8 = 200, g: u8 = 220, b: u8 = 255, a: u8 = 255 };
    pub const TEXT_MUTED = struct { r: u8 = 200, g: u8 = 200, b: u8 = 200, a: u8 = 255 };
    pub const CROSSHAIR = struct { r: u8 = 255, g: u8 = 255, b: u8 = 255, a: u8 = 200 };
};

pub const Input = struct {
    pub const MOVEMENT_SPEED: f32 = 0.1;
    pub const CAMERA_SPEED: f32 = 5.0;
    pub const ZOOM_SPEED: f32 = 0.1;
    pub const MOUSE_SENSITIVITY: f32 = 0.003;
    pub const SPRINT_MULTIPLIER: f32 = 2.0;
    pub const VERTICAL_SPEED: f32 = 0.1;
};

pub const EditorColors = struct {
    const Color = extern struct { r: u8, g: u8, b: u8, a: u8 };

    pub const PANEL_BACKGROUND = Color{ .r = 35, .g = 35, .b = 45, .a = 255 };
    pub const PANEL_BORDER = Color{ .r = 60, .g = 60, .b = 70, .a = 255 };
    pub const BUTTON_HOVER = Color{ .r = 70, .g = 70, .b = 90, .a = 255 };
    pub const BUTTON_PRESSED = Color{ .r = 50, .g = 50, .b = 70, .a = 255 };
    pub const TEXT_NORMAL = Color{ .r = 240, .g = 240, .b = 250, .a = 255 };
    pub const TEXT_MUTED = Color{ .r = 160, .g = 160, .b = 175, .a = 255 };
    pub const ACCENT = Color{ .r = 100, .g = 180, .b = 255, .a = 255 };
    pub const ACCENT_HOVER = Color{ .r = 130, .g = 200, .b = 255, .a = 255 };
    pub const ACCENT_PRESSED = Color{ .r = 80, .g = 160, .b = 235, .a = 255 };
    pub const SHADOW = Color{ .r = 0, .g = 0, .b = 0, .a = 80 };
};

test "UI constants valid" {
    try std.testing.expect(UI.MIN_SCALE < UI.MAX_SCALE);
    try std.testing.expect(UI.MIN_TOUCH_TARGET > 0);
}

test "Rendering constants valid" {
    try std.testing.expect(Rendering.DEFAULT_WIDTH > 0);
    try std.testing.expect(Rendering.SHADOW_MAP_SIZE >= 1024);
}
