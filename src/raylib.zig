const std = @import("std");

// Raylib C bindings - Direct translation from raylib.h

// Basic types
pub const Vector2 = extern struct {
    x: f32,
    y: f32,
};

pub const Vector3 = extern struct {
    x: f32,
    y: f32,
    z: f32,
};

pub const Vector4 = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,
};

pub const Quaternion = Vector4;

pub const Matrix = extern struct {
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

pub const Color = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

pub const Rectangle = extern struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

pub const Image = extern struct {
    data: ?*anyopaque,
    width: i32,
    height: i32,
    mipmaps: i32,
    format: i32,
};

pub const Texture = extern struct {
    id: u32,
    width: i32,
    height: i32,
    mipmaps: i32,
    format: i32,
};

pub const RenderTexture = extern struct {
    id: u32,
    texture: Texture,
    depth: Texture,
};

pub const NPatchInfo = extern struct {
    source: Rectangle,
    left: i32,
    top: i32,
    right: i32,
    bottom: i32,
    layout: i32,
};

pub const GlyphInfo = extern struct {
    value: i32,
    offsetX: i32,
    offsetY: i32,
    advanceX: i32,
    image: Image,
};

pub const Font = extern struct {
    baseSize: i32,
    glyphCount: i32,
    glyphPadding: i32,
    texture: Texture,
    recs: [*c]Rectangle,
    glyphs: [*c]GlyphInfo,
};

pub const Camera3D = extern struct {
    position: Vector3,
    target: Vector3,
    up: Vector3,
    fovy: f32,
    projection: i32,
};

pub const Camera2D = extern struct {
    offset: Vector2,
    target: Vector2,
    rotation: f32,
    zoom: f32,
};

pub const Mesh = extern struct {
    vertexCount: i32,
    triangleCount: i32,
    vertices: [*c]f32,
    texcoords: [*c]f32,
    texcoords2: [*c]f32,
    normals: [*c]f32,
    tangents: [*c]f32,
    colors: [*c]u8,
    indices: [*c]u16,
    animVertices: [*c]f32,
    animNormals: [*c]f32,
    boneIds: [*c]u8,
    boneWeights: [*c]f32,
    vaoId: u32,
    vboId: [*c]u32,
};

pub const Shader = extern struct {
    id: u32,
    locs: [*c]i32,
};

pub const MaterialMap = extern struct {
    texture: Texture,
    color: Color,
    value: f32,
};

pub const Material = extern struct {
    shader: Shader,
    maps: [*c]MaterialMap,
    params: [4]f32,
};

pub const Transform = extern struct {
    translation: Vector3,
    rotation: Quaternion,
    scale: Vector3,
};

pub const BoneInfo = extern struct {
    name: [32]u8,
    parent: c_int,
};

pub const Model = extern struct {
    transform: Matrix,
    meshCount: c_int,
    materialCount: c_int,
    meshes: [*c]Mesh,
    materials: [*c]Material,
    meshMaterial: [*c]c_int,
    boneCount: c_int,
    bones: [*c]BoneInfo,
    bindPose: [*c]Transform,
};

pub const ModelAnimation = extern struct {
    boneCount: c_int,
    frameCount: c_int,
    bones: [*c]BoneInfo,
    framePoses: [*c][*c]Transform,
};

pub const Ray = extern struct {
    position: Vector3,
    direction: Vector3,
};

pub const RayCollision = extern struct {
    hit: bool,
    distance: f32,
    point: Vector3,
    normal: Vector3,
};

pub const BoundingBox = extern struct {
    min: Vector3,
    max: Vector3,
};

pub const Wave = extern struct {
    frameCount: c_uint,
    sampleRate: c_uint,
    sampleSize: c_uint,
    channels: c_uint,
    data: ?*anyopaque,
};

pub const AudioStream = extern struct {
    buffer: ?*anyopaque,
    processor: ?*anyopaque,
    sampleRate: c_uint,
    sampleSize: c_uint,
    channels: c_uint,
};

pub const Sound = extern struct {
    stream: AudioStream,
    frameCount: c_uint,
};

pub const Music = extern struct {
    stream: AudioStream,
    frameCount: c_uint,
    looping: bool,
    ctxType: c_int,
    ctxData: ?*anyopaque,
};

pub const VrDeviceInfo = extern struct {
    hResolution: c_int,
    vResolution: c_int,
    hScreenSize: f32,
    vScreenSize: f32,
    vScreenCenter: f32,
    eyeToScreenDistance: f32,
    lensSeparationDistance: f32,
    interpupillaryDistance: f32,
    lensDistortionValues: [4]f32,
    chromaAbCorrection: [4]f32,
};

pub const VrStereoConfig = extern struct {
    projection: [2]Matrix,
    viewOffset: [2]Matrix,
    leftLensCenter: [2]f32,
    rightLensCenter: [2]f32,
    leftScreenCenter: [2]f32,
    rightScreenCenter: [2]f32,
    scale: [2]f32,
    scaleIn: [2]f32,
};

// C standard library types
const c_int_type = c_int;
const c_uint_type = c_uint;
const c_ushort_type = c_ushort;

// Constants
pub const PI = 3.14159265358979323846;

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

// Function declarations - Core
extern fn InitWindow(width: c_int, height: c_int, title: [*c]const u8) void;
extern fn WindowShouldClose() bool;
extern fn CloseWindow() void;
extern fn BeginDrawing() void;
extern fn EndDrawing() void;
extern fn ClearBackground(color: Color) void;
extern fn SetTargetFPS(fps: c_int) void;
extern fn GetFrameTime() f32;
extern fn GetScreenWidth() c_int;
extern fn GetScreenHeight() c_int;

// Function declarations - Shapes
extern fn DrawRectangle(posX: c_int, posY: c_int, width: c_int, height: c_int, color: Color) void;
extern fn DrawRectangleRec(rec: Rectangle, color: Color) void;
extern fn DrawRectangleLinesEx(rec: Rectangle, lineThick: f32, color: Color) void;

// Function declarations - Text
extern fn DrawText(text: [*c]const u8, posX: c_int, posY: c_int, fontSize: c_int, color: Color) void;
extern fn MeasureText(text: [*c]const u8, fontSize: c_int) c_int;

// Function declarations - Input
extern fn IsKeyPressed(key: c_int) bool;
extern fn IsKeyDown(key: c_int) bool;
extern fn GetKeyPressed() c_int;

// Function declarations - Files
extern fn FileExists(fileName: [*c]const u8) bool;
extern fn LoadFileData(fileName: [*c]const u8, bytesRead: [*c]c_uint) [*c]u8;
extern fn UnloadFileData(data: [*c]u8) void;

// Function declarations - Textures
extern fn LoadTexture(fileName: [*c]const u8) Texture;
extern fn UnloadTexture(texture: Texture) void;
extern fn DrawTexture(texture: Texture, posX: c_int, posY: c_int, tint: Color) void;

// Function declarations - Audio
extern fn InitAudioDevice() void;
extern fn CloseAudioDevice() void;
extern fn LoadSound(fileName: [*c]const u8) Sound;
extern fn UnloadSound(sound: Sound) void;
extern fn PlaySound(sound: Sound) void;

// Function declarations - Math
extern fn Vector2Zero() Vector2;
extern fn Vector2One() Vector2;
extern fn Vector2Add(v1: Vector2, v2: Vector2) Vector2;
extern fn Vector2Subtract(v1: Vector2, v2: Vector2) Vector2;
extern fn Vector2Scale(v: Vector2, scale: f32) Vector2;

// Exported functions - Core
pub fn initWindow(width: i32, height: i32, title: []const u8) void {
    InitWindow(@intCast(width), @intCast(height), title.ptr);
}

pub fn windowShouldClose() bool {
    return WindowShouldClose();
}

pub fn closeWindow() void {
    CloseWindow();
}

pub fn beginDrawing() void {
    BeginDrawing();
}

pub fn endDrawing() void {
    EndDrawing();
}

pub fn clearBackground(color: Color) void {
    ClearBackground(color);
}

pub fn setTargetFPS(fps: i32) void {
    SetTargetFPS(@intCast(fps));
}

pub fn getFrameTime() f32 {
    return GetFrameTime();
}

pub fn getScreenWidth() i32 {
    return @intCast(GetScreenWidth());
}

pub fn getScreenHeight() i32 {
    return @intCast(GetScreenHeight());
}

// Exported functions - Shapes
pub fn drawRectangle(posX: i32, posY: i32, width: i32, height: i32, color: Color) void {
    DrawRectangle(@intCast(posX), @intCast(posY), @intCast(width), @intCast(height), color);
}

pub fn drawRectangleRec(rec: Rectangle, color: Color) void {
    DrawRectangleRec(rec, color);
}

pub fn drawRectangleLinesEx(rec: Rectangle, lineThick: f32, color: Color) void {
    DrawRectangleLinesEx(rec, lineThick, color);
}

// Exported functions - Text
pub fn drawText(text: []const u8, posX: i32, posY: i32, fontSize: i32, color: Color) void {
    DrawText(text.ptr, @intCast(posX), @intCast(posY), @intCast(fontSize), color);
}

pub fn measureText(text: []const u8, fontSize: i32) i32 {
    return @intCast(MeasureText(text.ptr, @intCast(fontSize)));
}

// Exported functions - Input
pub fn isKeyPressed(key: i32) bool {
    return IsKeyPressed(@intCast(key));
}

pub fn isKeyDown(key: i32) bool {
    return IsKeyDown(@intCast(key));
}

pub fn getKeyPressed() i32 {
    return @intCast(GetKeyPressed());
}

// Exported functions - Files
pub fn fileExists(fileName: []const u8) bool {
    return FileExists(fileName.ptr);
}

pub fn loadFileData(fileName: []const u8, bytesRead: *u32) [*]u8 {
    return LoadFileData(fileName.ptr, @ptrCast(bytesRead));
}

pub fn unloadFileData(data: [*]u8) void {
    UnloadFileData(data);
}

// Exported functions - Textures
pub fn loadTexture(fileName: []const u8) Texture {
    return LoadTexture(fileName.ptr);
}

pub fn unloadTexture(texture: Texture) void {
    UnloadTexture(texture);
}

pub fn drawTexture(texture: Texture, posX: i32, posY: i32, tint: Color) void {
    DrawTexture(texture, @intCast(posX), @intCast(posY), tint);
}

// Exported functions - Audio
pub fn initAudioDevice() void {
    InitAudioDevice();
}

pub fn closeAudioDevice() void {
    CloseAudioDevice();
}

pub fn loadSound(fileName: []const u8) Sound {
    return LoadSound(fileName.ptr);
}

pub fn unloadSound(sound: Sound) void {
    UnloadSound(sound);
}

pub fn playSound(sound: Sound) void {
    PlaySound(sound);
}

// Exported functions - Math
pub fn vector2Zero() Vector2 {
    return Vector2Zero();
}

pub fn vector2One() Vector2 {
    return Vector2One();
}

pub fn vector2Add(v1: Vector2, v2: Vector2) Vector2 {
    return Vector2Add(v1, v2);
}

pub fn vector2Subtract(v1: Vector2, v2: Vector2) Vector2 {
    return Vector2Subtract(v1, v2);
}

pub fn vector2Scale(v: Vector2, scale: f32) Vector2 {
    return Vector2Scale(v, scale);
}

// Keyboard keys
pub const KEY_NULL = 0;
pub const KEY_APOSTROPHE = 39;
pub const KEY_COMMA = 44;
pub const KEY_MINUS = 45;
pub const KEY_PERIOD = 46;
pub const KEY_SLASH = 47;
pub const KEY_ZERO = 48;
pub const KEY_ONE = 49;
pub const KEY_TWO = 50;
pub const KEY_THREE = 51;
pub const KEY_FOUR = 52;
pub const KEY_FIVE = 53;
pub const KEY_SIX = 54;
pub const KEY_SEVEN = 55;
pub const KEY_EIGHT = 56;
pub const KEY_NINE = 57;
pub const KEY_SEMICOLON = 59;
pub const KEY_EQUAL = 61;
pub const KEY_A = 65;
pub const KEY_B = 66;
pub const KEY_C = 67;
pub const KEY_D = 68;
pub const KEY_E = 69;
pub const KEY_F = 70;
pub const KEY_G = 71;
pub const KEY_H = 72;
pub const KEY_I = 73;
pub const KEY_J = 74;
pub const KEY_K = 75;
pub const KEY_L = 76;
pub const KEY_M = 77;
pub const KEY_N = 78;
pub const KEY_O = 79;
pub const KEY_P = 80;
pub const KEY_Q = 81;
pub const KEY_R = 82;
pub const KEY_S = 83;
pub const KEY_T = 84;
pub const KEY_U = 85;
pub const KEY_V = 86;
pub const KEY_W = 87;
pub const KEY_X = 88;
pub const KEY_Y = 89;
pub const KEY_Z = 90;
pub const KEY_LEFT_BRACKET = 91;
pub const KEY_BACKSLASH = 92;
pub const KEY_RIGHT_BRACKET = 93;
pub const KEY_GRAVE = 96;
pub const KEY_SPACE = 32;
pub const KEY_ESCAPE = 256;
pub const KEY_ENTER = 257;
pub const KEY_TAB = 258;
pub const KEY_BACKSPACE = 259;
pub const KEY_INSERT = 260;
pub const KEY_DELETE = 261;
pub const KEY_RIGHT = 262;
pub const KEY_LEFT = 263;
pub const KEY_DOWN = 264;
pub const KEY_UP = 265;
pub const KEY_PAGE_UP = 266;
pub const KEY_PAGE_DOWN = 267;
pub const KEY_HOME = 268;
pub const KEY_END = 269;
pub const KEY_CAPS_LOCK = 280;
pub const KEY_SCROLL_LOCK = 281;
pub const KEY_NUM_LOCK = 282;
pub const KEY_PRINT_SCREEN = 283;
pub const KEY_PAUSE = 284;
pub const KEY_F1 = 290;
pub const KEY_F2 = 291;
pub const KEY_F3 = 292;
pub const KEY_F4 = 293;
pub const KEY_F5 = 294;
pub const KEY_F6 = 295;
pub const KEY_F7 = 296;
pub const KEY_F8 = 297;
pub const KEY_F9 = 298;
pub const KEY_F10 = 299;
pub const KEY_F11 = 300;
pub const KEY_F12 = 301;
pub const KEY_LEFT_SHIFT = 340;
pub const KEY_LEFT_CONTROL = 341;
pub const KEY_LEFT_ALT = 342;
pub const KEY_LEFT_SUPER = 343;
pub const KEY_RIGHT_SHIFT = 344;
pub const KEY_RIGHT_CONTROL = 345;
pub const KEY_RIGHT_ALT = 346;
pub const KEY_RIGHT_SUPER = 347;
pub const KEY_KB_MENU = 348;
