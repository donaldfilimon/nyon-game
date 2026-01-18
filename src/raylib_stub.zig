//! Temporary stub raylib bindings for refactoring
//! This provides the minimal API needed by the current codebase
//! TODO: Replace with proper raylib bindings once dependency issues are resolved

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

pub const BoundingBox = extern struct {
    min: Vector3,
    max: Vector3,
};

pub const KeyboardKey = enum(c_int) {
    space = 32,
    escape = 256,
    enter = 257,
    backspace = 259,
    tab = 258,
    right = 262,
    left = 263,
    delete = 261,
    down = 264,
    up = 265,
    f1 = 290,
    f2 = 291,
    left_control = 341,
    right_control = 345,
    a = 65,
    c = 67,
    d = 68,
    r = 82,
    s = 83,
    w = 87,
};

pub const MouseButton = enum(c_int) {
    left = 0,
    right = 1,
    middle = 2,
};

// ============================================================================
// Stub Functions (non-functional)
// ============================================================================

pub fn initWindow(width: c_int, height: c_int, title: [*:0]const u8) void {
    _ = width;
    _ = height;
    _ = title;
    // Stub - does nothing
}

pub fn closeWindow() void {
    // Stub - does nothing
}

pub fn setWindowPosition(x: c_int, y: c_int) void {
    _ = x;
    _ = y;
    // Stub - does nothing
}

pub fn getWindowScaleDPI() Vector2 {
    // Stub - return default DPI
    return .{ .x = 1.0, .y = 1.0 };
}

pub fn windowShouldClose() bool {
    // Stub - always return false
    return false;
}

pub fn setTargetFPS(fps: c_int) void {
    _ = fps;
    // Stub - does nothing
}

pub fn beginDrawing() void {
    // Stub - does nothing
}

pub fn endDrawing() void {
    // Stub - does nothing
}

pub fn clearBackground(color: Color) void {
    _ = color;
    // Stub - does nothing
}

pub fn getScreenWidth() c_int {
    // Stub - return default width
    return 800;
}

pub fn getScreenHeight() c_int {
    // Stub - return default height
    return 600;
}

pub fn getWindowPosition() Vector2 {
    // Stub - return default position
    return Vector2{ .x = 100, .y = 100 };
}

pub fn getFrameTime() f32 {
    // Stub - return fixed frame time
    return 1.0 / 60.0;
}

pub fn getTime() f64 {
    // Stub - return fixed time
    return 0.0;
}

pub fn getFPS() c_int {
    // Stub - return fixed FPS
    return 60;
}

pub fn isKeyPressed(key: KeyboardKey) bool {
    _ = key;
    // Stub - always return false
    return false;
}

pub fn isKeyDown(key: KeyboardKey) bool {
    _ = key;
    // Stub - always return false
    return false;
}

pub fn isKeyReleased(key: KeyboardKey) bool {
    _ = key;
    // Stub - always return false
    return false;
}

pub fn isKeyUp(key: KeyboardKey) bool {
    _ = key;
    // Stub - always return true
    return true;
}

pub fn getCharPressed() c_int {
    // Stub - return 0 (no key pressed)
    return 0;
}

pub fn isMouseButtonPressed(button: MouseButton) bool {
    _ = button;
    // Stub - always return false
    return false;
}

pub fn isMouseButtonDown(button: MouseButton) bool {
    _ = button;
    // Stub - always return false
    return false;
}

pub fn isMouseButtonReleased(button: MouseButton) bool {
    _ = button;
    // Stub - always return false
    return false;
}

pub fn isMouseButtonUp(button: MouseButton) bool {
    _ = button;
    // Stub - always return true
    return true;
}

pub fn getMouseX() c_int {
    // Stub - return center X
    return 400;
}

pub fn getMouseY() c_int {
    // Stub - return center Y
    return 300;
}

pub fn getMousePosition() Vector2 {
    // Stub - return center position
    return .{ .x = 400, .y = 300 };
}

pub fn getMouseDelta() Vector2 {
    // Stub - return no delta
    return .{ .x = 0, .y = 0 };
}

pub fn setMousePosition(x: c_int, y: c_int) void {
    _ = x;
    _ = y;
    // Stub - does nothing
}

pub fn getMouseWheelMove() f32 {
    // Stub - return no movement
    return 0;
}

pub fn setMouseCursor(cursor: c_int) void {
    _ = cursor;
    // Stub - does nothing
}

pub fn getMouseWheelMoveV() Vector2 {
    // Stub - return no movement
    return .{ .x = 0, .y = 0 };
}

pub fn drawPixel(posX: c_int, posY: c_int, color: Color) void {
    _ = posX;
    _ = posY;
    _ = color;
    // Stub - does nothing
}

pub fn drawLine(startPosX: c_int, startPosY: c_int, endPosX: c_int, endPosY: c_int, color: Color) void {
    _ = startPosX;
    _ = startPosY;
    _ = endPosX;
    _ = endPosY;
    _ = color;
    // Stub - does nothing
}

pub fn drawCircle(centerX: c_int, centerY: c_int, radius: f32, color: Color) void {
    _ = centerX;
    _ = centerY;
    _ = radius;
    _ = color;
    // Stub - does nothing
}

pub fn drawCircleLines(centerX: c_int, centerY: c_int, radius: f32, color: Color) void {
    _ = centerX;
    _ = centerY;
    _ = radius;
    _ = color;
    // Stub - does nothing
}

pub fn drawRectangle(posX: c_int, posY: c_int, width: c_int, height: c_int, color: Color) void {
    _ = posX;
    _ = posY;
    _ = width;
    _ = height;
    _ = color;
    // Stub - does nothing
}

pub fn drawRectangleRec(rec: Rectangle, color: Color) void {
    _ = rec;
    _ = color;
    // Stub - does nothing
}

pub fn drawRectangleLinesEx(rec: Rectangle, lineThick: f32, color: Color) void {
    _ = rec;
    _ = lineThick;
    _ = color;
    // Stub - does nothing
}

pub fn drawRectangleLines(posX: c_int, posY: c_int, width: c_int, height: c_int, color: Color) void {
    _ = posX;
    _ = posY;
    _ = width;
    _ = height;
    _ = color;
    // Stub - does nothing
}

pub fn drawRectangleRounded(rec: Rectangle, roundness: f32, segments: c_int, color: Color) void {
    _ = rec;
    _ = roundness;
    _ = segments;
    _ = color;
    // Stub - does nothing
}

pub fn drawRectangleRoundedLines(rec: Rectangle, roundness: f32, segments: c_int, lineThick: f32, color: Color) void {
    _ = rec;
    _ = roundness;
    _ = segments;
    _ = lineThick;
    _ = color;
    // Stub - does nothing
}

pub fn drawText(text: [*:0]const u8, posX: c_int, posY: c_int, fontSize: c_int, color: Color) void {
    _ = text;
    _ = posX;
    _ = posY;
    _ = fontSize;
    _ = color;
    // Stub - does nothing
}

pub fn measureText(text: [*:0]const u8, fontSize: c_int) c_int {
    _ = text;
    _ = fontSize;
    // Stub - return approximate width
    return 100;
}

pub fn drawFPS(posX: c_int, posY: c_int) void {
    _ = posX;
    _ = posY;
    // Stub - does nothing
}

pub fn getFontDefault() Font {
    // Stub - return zeroed font
    return std.mem.zeroes(Font);
}

pub const Font = extern struct {
    baseSize: c_int,
    glyphCount: c_int,
    glyphPadding: c_int,
    texture: Texture2D,
    recs: ?[*]Rectangle,
    glyphs: ?[*]GlyphInfo,
};

pub fn unloadFont(font: Font) void {
    _ = font;
    // Stub - does nothing
}

pub const Texture2D = extern struct {
    id: c_uint,
    width: c_int,
    height: c_int,
    mipmaps: c_int,
    format: c_int,
};

pub const GlyphInfo = extern struct {
    value: c_int,
    offsetX: c_int,
    offsetY: c_int,
    advanceX: c_int,
    image: Image,
};

pub const Image = extern struct {
    data: ?*anyopaque,
    width: c_int,
    height: c_int,
    mipmaps: c_int,
    format: c_int,
};

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
    boneCount: c_int,
    boneMatrices: ?[*]Matrix,
    vaoId: c_uint,
    vboId: ?[*]c_uint,
};

pub fn genMeshCube(width: f32, height: f32, length: f32) Mesh {
    _ = width;
    _ = height;
    _ = length;
    // Stub - return empty mesh
    return Mesh{
        .vertexCount = 0,
        .triangleCount = 0,
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
        .boneMatrices = null,
        .vaoId = 0,
        .vboId = null,
    };
}

pub fn genMeshSphere(radius: f32, rings: c_int, slices: c_int) Mesh {
    _ = radius;
    _ = rings;
    _ = slices;
    // Stub - return empty mesh
    return Mesh{
        .vertexCount = 0,
        .triangleCount = 0,
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
        .boneMatrices = null,
        .vaoId = 0,
        .vboId = null,
    };
}

pub fn uploadMesh(mesh: *Mesh, dynamic: bool) void {
    _ = mesh;
    _ = dynamic;
    // Stub - does nothing
}

pub fn beginScissorMode(x: c_int, y: c_int, width: c_int, height: c_int) void {
    _ = x;
    _ = y;
    _ = width;
    _ = height;
    // Stub - does nothing
}

pub fn endScissorMode() void {
    // Stub - does nothing
}

pub fn beginMode3D(camera: Camera3D) void {
    _ = camera;
    // Stub - does nothing
}

pub fn endMode3D() void {
    // Stub - does nothing
}

pub fn loadModelFromMesh(mesh: Mesh) !Model {
    _ = mesh;
    // Stub - return zeroed model
    return std.mem.zeroes(Model);
}

pub fn unloadModel(model: Model) void {
    _ = model;
    // Stub - does nothing
}

pub fn drawModel(model: Model, position: Vector3, scale: f32, tint: Color) void {
    _ = model;
    _ = position;
    _ = scale;
    _ = tint;
    // Stub - does nothing
}

pub fn drawModelWires(model: Model, position: Vector3, scale: f32, tint: Color) void {
    _ = model;
    _ = position;
    _ = scale;
    _ = tint;
    // Stub - does nothing
}

pub fn drawLine3D(startPos: Vector3, endPos: Vector3, color: Color) void {
    _ = startPos;
    _ = endPos;
    _ = color;
    // Stub - does nothing
}

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

pub const BoneInfo = extern struct {
    name: [32]u8,
    parent: c_int,
};

pub const Transform = extern struct {
    translation: Vector3,
    rotation: Vector4,
    scale: Vector3,
};

pub const CameraProjection = enum(c_int) {
    perspective = 0,
    orthographic = 1,
};

pub const Camera3D = extern struct {
    position: Vector3,
    target: Vector3,
    up: Vector3,
    fovy: f32,
    projection: c_int,
};

pub const ConfigFlags = packed struct(u32) {
    fullscreen_mode: bool,
    window_resizable: bool,
    window_undecorated: bool,
    window_transparent: bool,
    msaa_4x_hint: bool,
    vsync_hint: bool,
    window_hidden: bool,
    window_always_run: bool,
    _padding: u24,
};

pub fn setConfigFlags(flags: ConfigFlags) void {
    _ = flags;
    // Stub - does nothing
}

pub fn initAudioDevice() void {
    // Stub - does nothing
}

pub fn closeAudioDevice() void {
    // Stub - does nothing
}

pub fn isAudioDeviceReady() bool {
    // Stub - return true
    return true;
}

pub fn loadFileData(fileName: [*:0]const u8, bytesRead: [*c]c_uint) ?[*]u8 {
    _ = fileName;
    _ = bytesRead;
    // Stub - return null
    return null;
}

pub fn unloadFileData(data: [*]u8) void {
    _ = data;
    // Stub - does nothing
}

pub fn loadFileText(fileName: [*:0]const u8) ?[*:0]u8 {
    _ = fileName;
    // Stub - return null
    return null;
}

pub fn unloadFileText(text: [*:0]u8) void {
    _ = text;
    // Stub - does nothing
}

pub fn fileExists(fileName: [*:0]const u8) bool {
    _ = fileName;
    // Stub - return false
    return false;
}

pub fn directoryExists(dirPath: [*:0]const u8) bool {
    _ = dirPath;
    // Stub - return false
    return false;
}

pub fn getFileLength(fileName: [*:0]const u8) c_int {
    _ = fileName;
    // Stub - return 0
    return 0;
}

pub fn saveFileText(fileName: [*:0]const u8, text: [*:0]const u8) bool {
    _ = fileName;
    _ = text;
    // Stub - return false
    return false;
}

pub const FilePathList = extern struct {
    capacity: c_uint,
    count: c_uint,
    paths: ?[*][*:0]u8,
};

pub fn loadDirectoryFiles(dirPath: [*:0]const u8) FilePathList {
    _ = dirPath;
    // Stub - return empty list
    return .{
        .capacity = 0,
        .count = 0,
        .paths = null,
    };
}

pub fn unloadDirectoryFiles(files: FilePathList) void {
    _ = files;
    // Stub - does nothing
}

pub fn isFileDropped() bool {
    // Stub - return false
    return false;
}

pub fn loadDroppedFiles() FilePathList {
    // Stub - return empty list
    return .{
        .capacity = 0,
        .count = 0,
        .paths = null,
    };
}

pub fn unloadDroppedFiles(files: FilePathList) void {
    _ = files;
    // Stub - does nothing
}

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

pub fn setTraceLogLevel(logLevel: TraceLogLevel) void {
    _ = logLevel;
    // Stub - does nothing
}

pub fn traceLog(logLevel: TraceLogLevel, text: [*:0]const u8, ...) void {
    _ = logLevel;
    _ = text;
    // Stub - does nothing
}

pub fn setRandomSeed(seed: c_uint) void {
    _ = seed;
    // Stub - does nothing
}

pub fn getRandomValue(_: c_int, _: c_int) c_int {
    // Stub - return 0
    return 0;
}

pub fn checkCollisionPointRec(point: Vector2, rec: Rectangle) bool {
    // Stub - basic rectangle collision check
    return point.x >= rec.x and point.x <= rec.x + rec.width and
        point.y >= rec.y and point.y <= rec.y + rec.height;
}

// ============================================================================
// Constants
// ============================================================================

pub const RAYLIB_VERSION_MAJOR = 5;
pub const RAYLIB_VERSION_MINOR = 0;
pub const RAYLIB_VERSION_PATCH = 0;
pub const RAYLIB_VERSION = "5.0.0";
pub const MAX_TOUCH_POINTS = 10;
pub const MAX_MATERIAL_MAPS = 12;
pub const MAX_SHADER_LOCATIONS = 32;

// ============================================================================
// Color Constants
// ============================================================================

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
pub const ray_white = RAYWHITE;

// ============================================================================
// Error Types
// ============================================================================

pub const RaylibError = error{
    // Stub - no actual errors
    };
