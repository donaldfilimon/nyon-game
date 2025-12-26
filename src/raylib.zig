const std = @import("std");

// TODO: Replace with proper raylib-zig bindings

// Raylib Zig bindings - Minimal stub for development
// TODO: Replace with proper raylib-zig bindings when dependency issues are resolved

// Basic types
pub const Vector2 = struct {
    x: f32,
    y: f32,
};

pub const Vector3 = struct {
    x: f32,
    y: f32,
    z: f32,
};

pub const Vector4 = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,
};

pub const Quaternion = Vector4;

pub const Matrix = struct {
    m0: f32,
    m4: f32,
    m8: f32,
    m12: f32,
    m1: f32,
    m5: f32,
    m9: f32,
    m13: f32,
    m2: f32,
    m6: f32,
    m10: f32,
    m14: f32,
    m3: f32,
    m7: f32,
    m11: f32,
    m15: f32,
};

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

pub const Rectangle = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

// Configuration Flags
pub const ConfigFlags = enum(c_int) {
    FLAG_VSYNC_HINT = 0x00000040,
    FLAG_FULLSCREEN_MODE = 0x00000002,
    FLAG_WINDOW_RESIZABLE = 0x00000004,
    FLAG_WINDOW_UNDECORATED = 0x00000008,
    FLAG_WINDOW_HIDDEN = 0x00000080,
    FLAG_WINDOW_MINIMIZED = 0x00000200,
    FLAG_WINDOW_MAXIMIZED = 0x00000400,
    FLAG_WINDOW_UNFOCUSED = 0x00000800,
    FLAG_WINDOW_TOPMOST = 0x00001000,
    FLAG_WINDOW_ALWAYS_RUN = 0x00000100,
    FLAG_MSAA_4X_HINT = 0x00000020,
    FLAG_INTERLACED_HINT = 0x00010000,
};

// Keyboard Keys
pub const KeyboardKey = enum(c_int) {
    KEY_NULL = 0,
    KEY_APOSTROPHE = 39,
    KEY_COMMA = 44,
    KEY_MINUS = 45,
    KEY_PERIOD = 46,
    KEY_SLASH = 47,
    KEY_ZERO = 48,
    KEY_ONE = 49,
    KEY_TWO = 50,
    KEY_THREE = 51,
    KEY_FOUR = 52,
    KEY_FIVE = 53,
    KEY_SIX = 54,
    KEY_SEVEN = 55,
    KEY_EIGHT = 56,
    KEY_NINE = 57,
    KEY_SEMICOLON = 59,
    KEY_EQUAL = 61,
    KEY_A = 65,
    KEY_B = 66,
    KEY_C = 67,
    KEY_D = 68,
    KEY_E = 69,
    KEY_F = 70,
    KEY_G = 71,
    KEY_H = 72,
    KEY_I = 73,
    KEY_J = 74,
    KEY_K = 75,
    KEY_L = 76,
    KEY_M = 77,
    KEY_N = 78,
    KEY_O = 79,
    KEY_P = 80,
    KEY_Q = 81,
    KEY_R = 82,
    KEY_S = 83,
    KEY_T = 84,
    KEY_U = 85,
    KEY_V = 86,
    KEY_W = 87,
    KEY_X = 88,
    KEY_Y = 89,
    KEY_Z = 90,
    KEY_LEFT_BRACKET = 91,
    KEY_BACKSLASH = 92,
    KEY_RIGHT_BRACKET = 93,
    KEY_GRAVE = 96,
    KEY_SPACE = 32,
    KEY_ESCAPE = 256,
    KEY_ENTER = 257,
    KEY_TAB = 258,
    KEY_BACKSPACE = 259,
    KEY_INSERT = 260,
    KEY_DELETE = 261,
    KEY_RIGHT = 262,
    KEY_LEFT = 263,
    KEY_DOWN = 264,
    KEY_UP = 265,
    KEY_PAGE_UP = 266,
    KEY_PAGE_DOWN = 267,
    KEY_HOME = 268,
    KEY_END = 269,
    KEY_CAPS_LOCK = 280,
    KEY_SCROLL_LOCK = 281,
    KEY_NUM_LOCK = 282,
    KEY_PRINT_SCREEN = 283,
    KEY_PAUSE = 284,
    KEY_F1 = 290,
    KEY_F2 = 291,
    KEY_F3 = 292,
    KEY_F4 = 293,
    KEY_F5 = 294,
    KEY_F6 = 295,
    KEY_F7 = 296,
    KEY_F8 = 297,
    KEY_F9 = 298,
    KEY_F10 = 299,
    KEY_F11 = 300,
    KEY_F12 = 301,
    KEY_LEFT_SHIFT = 340,
    KEY_LEFT_CONTROL = 341,
    KEY_LEFT_ALT = 342,
    KEY_LEFT_SUPER = 343,
    KEY_RIGHT_SHIFT = 344,
    KEY_RIGHT_CONTROL = 345,
    KEY_RIGHT_ALT = 346,
    KEY_RIGHT_SUPER = 347,
    KEY_KB_MENU = 348,
};

// Mouse Buttons
pub const MouseButton = enum(c_int) {
    MOUSE_BUTTON_LEFT = 0,
    MOUSE_BUTTON_RIGHT = 1,
    MOUSE_BUTTON_MIDDLE = 2,
    MOUSE_BUTTON_SIDE = 3,
    MOUSE_BUTTON_EXTRA = 4,
    MOUSE_BUTTON_FORWARD = 5,
    MOUSE_BUTTON_BACK = 6,
};

// Color constants
pub const LIGHTGRAY = Color{ .r = 200, .g = 200, .b = 200, .a = 255 };
pub const GRAY = Color{ .r = 130, .g = 130, .b = 130, .a = 255 };
pub const DARKGRAY = Color{ .r = 80, .g = 80, .b = 80, .a = 255 };
pub const YELLOW = Color{ .r = 253, .g = 249, .b = 0, .a = 255 };
pub const GOLD = Color{ .r = 255, .g = 203, .b = 0, .a = 255 };
pub const ORANGE = Color{ .r = 255, .g = 161, .b = 0, .a = 255 };
pub const PINK = Color{ .r = 255, .g = 109, .b = 194, .a = 255 };
pub const RED = Color{ .r = 230, .g = 41, .b = 55, .a = 255 };
pub const MAROON = Color{ .r = 190, .g = 33, .b = 55, .a = 255 };
pub const GREEN = Color{ .r = 0, .g = 228, .b = 48, .a = 255 };
pub const LIME = Color{ .r = 0, .g = 158, .b = 47, .a = 255 };
pub const DARKGREEN = Color{ .r = 0, .g = 117, .b = 44, .a = 255 };
pub const SKYBLUE = Color{ .r = 102, .g = 191, .b = 255, .a = 255 };
pub const BLUE = Color{ .r = 0, .g = 121, .b = 241, .a = 255 };
pub const DARKBLUE = Color{ .r = 0, .g = 82, .b = 172, .a = 255 };
pub const PURPLE = Color{ .r = 200, .g = 122, .b = 255, .a = 255 };
pub const VIOLET = Color{ .r = 135, .g = 60, .b = 190, .a = 255 };
pub const DARKPURPLE = Color{ .r = 112, .g = 31, .b = 126, .a = 255 };
pub const BEIGE = Color{ .r = 211, .g = 176, .b = 131, .a = 255 };
pub const BROWN = Color{ .r = 127, .g = 106, .b = 79, .a = 255 };
pub const DARKBROWN = Color{ .r = 76, .g = 63, .b = 47, .a = 255 };
pub const WHITE = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
pub const BLACK = Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
pub const BLANK = Color{ .r = 0, .g = 0, .b = 0, .a = 0 };
pub const MAGENTA = Color{ .r = 255, .g = 0, .b = 255, .a = 255 };
pub const RAYWHITE = Color{ .r = 245, .g = 245, .b = 245, .a = 255 };

// Function declarations
pub extern fn InitWindow(width: c_int, height: c_int, title: [*c]const u8) void;
pub extern fn WindowShouldClose() bool;
pub extern fn CloseWindow() void;
pub extern fn BeginDrawing() void;
pub extern fn EndDrawing() void;
pub extern fn ClearBackground(color: Color) void;
pub extern fn SetTargetFPS(fps: c_int) void;
pub extern fn GetFrameTime() f32;
pub extern fn GetScreenWidth() c_int;
pub extern fn GetScreenHeight() c_int;
pub extern fn GetWindowScaleDPI() Vector2;
pub extern fn DrawText(text: [*c]const u8, posX: c_int, posY: c_int, fontSize: c_int, color: Color) void;
pub extern fn MeasureText(text: [*c]const u8, fontSize: c_int) c_int;
pub extern fn DrawRectangle(posX: c_int, posY: c_int, width: c_int, height: c_int, color: Color) void;
pub extern fn DrawRectangleRec(rec: Rectangle, color: Color) void;
pub extern fn DrawRectangleLinesEx(rec: Rectangle, lineThick: f32, color: Color) void;
pub extern fn IsKeyPressed(key: c_int) bool;
pub extern fn IsKeyDown(key: c_int) bool;
pub extern fn GetKeyPressed() c_int;
pub extern fn GetMousePosition() Vector2;
pub extern fn IsMouseButtonPressed(button: c_int) bool;
pub extern fn CheckCollisionPointRec(point: Vector2, rec: Rectangle) bool;
pub extern fn Vector2Zero() Vector2;
pub extern fn Vector2One() Vector2;
pub extern fn Vector2Add(v1: Vector2, v2: Vector2) Vector2;
pub extern fn Vector2Subtract(v1: Vector2, v2: Vector2) Vector2;
pub extern fn Vector2Scale(v: Vector2, scale: f32) Vector2;

// Aliases for consistency
pub const initWindow = InitWindow;
pub const windowShouldClose = WindowShouldClose;
pub const closeWindow = CloseWindow;
pub const beginDrawing = BeginDrawing;
pub const endDrawing = EndDrawing;
pub const clearBackground = ClearBackground;
pub const setTargetFPS = SetTargetFPS;
pub const getFrameTime = GetFrameTime;
pub const getScreenWidth = GetScreenWidth;
pub const getScreenHeight = GetScreenHeight;
pub const getWindowScaleDPI = GetWindowScaleDPI;
pub const drawText = DrawText;
pub const measureText = MeasureText;
pub const drawRectangle = DrawRectangle;
pub const drawRectangleRec = DrawRectangleRec;
pub const drawRectangleLinesEx = DrawRectangleLinesEx;
pub const isKeyPressed = IsKeyPressed;
pub const isKeyDown = IsKeyDown;
pub const getKeyPressed = GetKeyPressed;
pub const getMousePosition = GetMousePosition;
pub const isMouseButtonPressed = IsMouseButtonPressed;
pub const checkCollisionPointRec = CheckCollisionPointRec;
pub const vector2Zero = Vector2Zero;
pub const vector2One = Vector2One;
pub const vector2Add = Vector2Add;
pub const vector2Subtract = Vector2Subtract;
pub const vector2Scale = Vector2Scale;

pub fn windowShouldClose() bool {
    return false;
}

pub fn closeWindow() void {
    std.debug.print("STUB: closeWindow - raylib not available\n", .{});
}

pub fn beginDrawing() void {}
pub fn endDrawing() void {}

pub fn clearBackground(color: Color) void {
    _ = color;
}

pub fn setTargetFPS(fps: c_int) void {
    _ = fps;
}

pub fn getFrameTime() f32 {
    return 1.0 / 60.0;
}

pub fn getScreenWidth() c_int {
    return 800;
}

pub fn getScreenHeight() c_int {
    return 600;
}

pub fn getWindowScaleDPI() Vector2 {
    return Vector2{ .x = 1.0, .y = 1.0 };
}

pub fn drawText(text: [*c]const u8, posX: c_int, posY: c_int, fontSize: c_int, color: Color) void {
    _ = text;
    _ = posX;
    _ = posY;
    _ = fontSize;
    _ = color;
}

pub fn measureText(text: [*c]const u8, fontSize: c_int) c_int {
    _ = text;
    _ = fontSize;
    return 0;
}

pub fn drawRectangle(posX: c_int, posY: c_int, width: c_int, height: c_int, color: Color) void {
    _ = posX;
    _ = posY;
    _ = width;
    _ = height;
    _ = color;
}

pub fn drawRectangleRec(rec: Rectangle, color: Color) void {
    _ = rec;
    _ = color;
}

pub fn drawRectangleLinesEx(rec: Rectangle, lineThick: f32, color: Color) void {
    _ = rec;
    _ = lineThick;
    _ = color;
}

pub fn isKeyPressed(key: c_int) bool {
    _ = key;
    return false;
}

pub fn isKeyDown(key: c_int) bool {
    _ = key;
    return false;
}

pub fn getKeyPressed() c_int {
    return 0;
}

pub fn getMousePosition() Vector2 {
    return Vector2{ .x = 0, .y = 0 };
}

pub fn isMouseButtonPressed(button: c_int) bool {
    _ = button;
    return false;
}

pub fn checkCollisionPointRec(point: Vector2, rec: Rectangle) bool {
    _ = point;
    _ = rec;
    return false;
}

pub fn vector2Zero() Vector2 {
    return Vector2{ .x = 0, .y = 0 };
}

pub fn vector2One() Vector2 {
    return Vector2{ .x = 1, .y = 1 };
}

pub fn vector2Add(v1: Vector2, v2: Vector2) Vector2 {
    return Vector2{ .x = v1.x + v2.x, .y = v1.y + v2.y };
}

pub fn vector2Subtract(v1: Vector2, v2: Vector2) Vector2 {
    return Vector2{ .x = v1.x - v2.x, .y = v1.y - v2.y };
}

pub fn vector2Scale(v: Vector2, scale: f32) Vector2 {
    return Vector2{ .x = v.x * scale, .y = v.y * scale };
}
