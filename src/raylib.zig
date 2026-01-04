//! Temporary stub raylib bindings for Nyon Game Engine
//!
//! This module provides minimal stub implementations for raylib functions
//! used during refactoring when proper raylib-zig bindings are unavailable.
//! TODO: Replace with proper raylib bindings once dependency issues are resolved.

const std = @import("std");

// ============================================================================
// Basic Types
// ============================================================================

pub const Color = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

// Common color constants
pub const WHITE = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
pub const BLACK = Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
pub const RED = Color{ .r = 255, .g = 0, .b = 0, .a = 255 };
pub const GREEN = Color{ .r = 0, .g = 255, .b = 0, .a = 255 };
pub const BLUE = Color{ .r = 0, .g = 0, .b = 255, .a = 255 };
pub const YELLOW = Color{ .r = 255, .g = 255, .b = 0, .a = 255 };
pub const MAGENTA = Color{ .r = 255, .g = 0, .b = 255, .a = 255 };
pub const CYAN = Color{ .r = 0, .g = 255, .b = 255, .a = 255 };

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

pub const Rectangle = extern struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

// ============================================================================
// Input Types
// ============================================================================

pub const KeyboardKey = enum(c_int) {
    space = 32,
    escape = 256,
    enter = 257,
    tab = 258,
    backspace = 259,
    right = 262,
    left = 263,
    down = 264,
    up = 265,
    f1 = 290,
    f2 = 291,
    left_control = 341,
    right_control = 345,
    a = 65,
    w = 87,
    s = 83,
    d = 68,
    p = 80,
};

pub const MouseButton = enum(c_int) {
    left = 0,
    right = 1,
    middle = 2,
};

pub const TraceLogLevel = enum(c_int) {
    all = 0,
    trace = 1,
    debug = 2,
    info = 3,
    warning = 4,
    err = 5,
    fatal = 6,
    none = 7,
};

pub const CameraProjection = enum(c_int) {
    perspective = 0,
    orthographic = 1,
};

// ============================================================================
// Graphics Types
// ============================================================================

pub const Mesh = extern struct {
    vertexCount: c_int,
    triangleCount: c_int,
    vertices: ?[*]f32,
    texcoords: ?[*]f32,
    texcoords2: ?[*]f32,
    normals: ?[*]f32,
    tangents: ?[*]f32,
    colors: ?[*]u8,
    indices: ?[*]u16,
    animVertices: ?[*]f32,
    animNormals: ?[*]f32,
    boneIds: ?[*]u8,
    boneWeights: ?[*]f32,
    boneCount: u32,
    vaoId: c_uint,
    vboId: ?[*]c_uint,
};

pub const Model = extern struct {
    transform: Matrix,
    meshes: ?[*]Mesh,
    materials: ?[*]Material,
    meshCount: c_int,
    materialCount: c_int,
    boneCount: c_int,
    bones: ?[*]BoneInfo,
    bindPose: ?[*]Transform,
};

/// 4x4 matrix in column-major order (OpenGL style)
/// Layout:
///   m0  m4  m8  m12
///   m1  m5  m9  m13
///   m2  m6  m10 m14
///   m3  m7  m11 m15
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

pub const Transform = extern struct {
    translation: Vector3,
    rotation: Vector3,
    scale: Vector3,
};

pub const Material = extern struct {
    shader: Shader,
    maps: ?[*]MaterialMap,
    params: [4]f32,
};

pub const Shader = extern struct {
    id: c_uint,
    locs: ?[*]c_int,
};

pub const MaterialMap = extern struct {
    texture: Texture2D,
    color: Color,
    value: f32,
};

pub const Texture2D = extern struct {
    id: c_uint,
    width: c_int,
    height: c_int,
    mipmaps: c_int,
    format: c_int,
};

pub const Image = extern struct {
    data: ?*anyopaque,
    width: c_int,
    height: c_int,
    mipmaps: c_int,
    format: c_int,
};

pub const BoundingBox = extern struct {
    min: Vector3,
    max: Vector3,
};

pub const Camera3D = extern struct {
    position: Vector3,
    target: Vector3,
    up: Vector3,
    fovy: f32,
    projection: c_int,
};

pub const Font = extern struct {
    baseSize: c_int,
    glyphCount: c_int,
    glyphPadding: c_int,
    texture: Texture2D,
    recs: ?[*]Rectangle,
    glyphs: ?[*]GlyphInfo,
};

pub const GlyphInfo = extern struct {
    value: c_int,
    offsetX: c_int,
    offsetY: c_int,
    advanceX: c_int,
    image: Image,
    id: u32,
};

pub const BoneInfo = extern struct {
    id: [32]u8,
    parent: c_int,
};

// ============================================================================
// Stub Functions
// ============================================================================

pub fn initWindow(width: c_int, height: c_int, title: [*:0]const u8) void {
    _ = width;
    _ = height;
    _ = title;
}

pub fn closeWindow() void {}

pub fn windowShouldClose() bool {
    return false;
}

pub fn setWindowPosition(x: c_int, y: c_int) void {
    _ = x;
    _ = y;
}

pub fn getWindowPosition() Vector2 {
    return Vector2{ .x = 0, .y = 0 };
}

pub fn clearBackground(color: Color) void {
    _ = color;
}

pub fn beginDrawing() void {}

pub fn endDrawing() void {}

pub fn isKeyDown(_: KeyboardKey) bool {
    return false;
}

pub fn isKeyPressed(_: KeyboardKey) bool {
    return false;
}

pub fn isKeyReleased(_: KeyboardKey) bool {
    return false;
}

pub fn getMousePosition() Vector2 {
    return Vector2{ .x = 0, .y = 0 };
}

pub fn isMouseButtonDown(_: MouseButton) bool {
    return false;
}

pub fn isMouseButtonPressed(_: MouseButton) bool {
    return false;
}

pub fn isMouseButtonReleased(_: MouseButton) bool {
    return false;
}

pub fn isFileDropped() bool {
    return false;
}

pub fn getDroppedFiles() [*][*:0]const u8 {
    return &[_][*:0]const u8{};
}

pub fn drawPixel(posX: c_int, posY: c_int, color: Color) void {
    _ = posX;
    _ = posY;
    _ = color;
}

pub fn drawLine(startPosX: c_int, startPosY: c_int, endPosX: c_int, endPosY: c_int, color: Color) void {
    _ = startPosX;
    _ = startPosY;
    _ = endPosX;
    _ = endPosY;
    _ = color;
}

pub fn drawLineEx(startPos: Vector2, endPos: Vector2, thick: f32, color: Color) void {
    _ = startPos;
    _ = endPos;
    _ = thick;
    _ = color;
}

pub fn drawCircle(centerX: c_int, centerY: c_int, radius: f32, color: Color) void {
    _ = centerX;
    _ = centerY;
    _ = radius;
    _ = color;
}

pub fn drawCircleLines(centerX: c_int, centerY: c_int, radius: f32, color: Color) void {
    _ = centerX;
    _ = centerY;
    _ = radius;
    _ = color;
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

pub fn drawRectangleRounded(rec: Rectangle, roundness: f32, segments: c_int, color: Color) void {
    _ = .{ rec, roundness, segments, color };
}

pub fn drawRectangleRoundedLines(rec: Rectangle, roundness: f32, segments: c_int, lineThick: f32, color: Color) void {
    _ = rec;
    _ = roundness;
    _ = segments;
    _ = lineThick;
    _ = color;
}

pub fn drawText(text: [*:0]const u8, posX: c_int, posY: c_int, fontSize: c_int, color: Color) void {
    _ = text;
    _ = posX;
    _ = posY;
    _ = fontSize;
    _ = color;
}

pub fn measureText(text: [*:0]const u8, fontSize: c_int) c_int {
    // Calculate length of null-terminated string
    var len: usize = 0;
    while (text[len] != 0) : (len += 1) {}
    return @intCast(len * fontSize);
}

pub fn checkCollisionPointRec(point: Vector2, rec: Rectangle) bool {
    _ = point;
    _ = rec;
    return false;
}

pub fn drawFPS(posX: c_int, posY: c_int) void {
    _ = posX;
    _ = posY;
}

pub fn setTargetFPS(target: c_int) void {
    _ = target;
}

pub fn getFPS() c_int {
    return 60;
}

pub fn getFrameTime() f32 {
    return 1.0 / 60.0;
}

pub fn loadMusic(data: [*]const u8, dataSize: c_int) Music {
    _ = data;
    _ = dataSize;
    return Music{};
}

pub fn unloadMusic(music: Music) void {
    _ = music;
}

pub fn playMusic(music: Music) void {
    _ = music;
}

pub fn playSound(sound: Sound) void {
    _ = sound;
}

pub const Sound = struct {};

pub const Music = struct {};

pub fn initAudioDevice() void {}

pub fn closeAudioDevice() void {}

pub fn setTraceLogLevel(level: TraceLogLevel) void {
    _ = level;
}

pub fn setConfigFlags(flags: u32) void {
    _ = flags;
}

pub fn setExitKey(key: c_int) void {
    _ = key;
}

pub fn getScreenWidth() c_int {
    return 800;
}

pub fn getScreenHeight() c_int {
    return 600;
}

pub fn loadModel(filename: [*:0]const u8) Model {
    _ = filename;
    return Model{};
}

pub fn unloadModel(model: Model) void {
    _ = model;
}

pub fn drawModel(model: Model) void {
    _ = model;
}

/// 4x4 identity matrix (diagonal = 1, all others = 0)
pub const MatrixIdentity = Matrix{
    .m0 = 1,
    .m1 = 0,
    .m2 = 0,
    .m3 = 0,
    .m4 = 0,
    .m5 = 1,
    .m6 = 0,
    .m7 = 0,
    .m8 = 0,
    .m9 = 0,
    .m10 = 1,
    .m11 = 0,
    .m12 = 0,
    .m13 = 0,
    .m14 = 0,
    .m15 = 1,
};

pub fn genMeshCube(_: f32, _: f32, _: f32) Mesh {
    return Mesh{
        .vertexCount = 24,
        .triangleCount = 12,
        .vertices = null,
        .texcoords = null,
        .texcoords2 = null,
        .normals = null,
        .tangents = null,
        .colors = null,
        .indices = null,
        .animVertices = null,
        .animNormals = null,
        .boneIds = null,
        .boneWeights = null,
        .boneCount = 0,
        .vaoId = 0,
        .vboId = null,
    };
}

pub fn genMeshSphere(_: f32, _: i32, _: i32) Mesh {
    return Mesh{
        .vertexCount = 100,
        .triangleCount = 180,
        .vertices = null,
        .texcoords = null,
        .texcoords2 = null,
        .normals = null,
        .tangents = null,
        .colors = null,
        .indices = null,
        .animVertices = null,
        .animNormals = null,
        .boneIds = null,
        .boneWeights = null,
        .boneCount = 0,
        .vaoId = 0,
        .vboId = null,
    };
}

pub fn getDPI() Vector2 {
    return Vector2{ .x = 1.0, .y = 1.0 };
}

pub const FilePathList = extern struct {
    capacity: c_uint,
    count: c_uint,
    paths: ?[*][*:0]const u8,
};

pub fn loadDirectoryFiles(dirPath: [*:0]const u8) FilePathList {
    _ = dirPath;
    return FilePathList{ .capacity = 0, .count = 0, .paths = null };
}
