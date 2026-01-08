//! Improved raylib stub designed for easy migration to raylib-zig
//! This stub provides the same API surface as raylib-zig for seamless replacement

const std = @import("std");

// ============================================================================
// Basic Types (matching raylib-zig exactly)
// C type aliases for raylib compatibility
pub const raylib_c_int = i32;
pub const raylib_c_uint = u32;
pub const raylib_c_ushort = u16;

// ============================================================================

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

    pub fn identity() Matrix {
        return .{
            .m0 = 1,
            .m4 = 0,
            .m8 = 0,
            .m12 = 0,
            .m1 = 0,
            .m5 = 1,
            .m9 = 0,
            .m13 = 0,
            .m2 = 0,
            .m6 = 0,
            .m10 = 1,
            .m14 = 0,
            .m3 = 0,
            .m7 = 0,
            .m11 = 0,
            .m15 = 1,
        };
    }

    pub fn perspective(fovy: f64, aspect: f64, near: f64, far: f64) Matrix {
        _ = fovy;
        _ = aspect;
        _ = near;
        _ = far;
        return identity();
    }

    pub fn multiply(self: Matrix, other: Matrix) Matrix {
        _ = self;
        _ = other;
        return identity();
    }

    pub fn getM11(self: Matrix) f32 {
        return self.m0;
    }
    pub fn getM21(self: Matrix) f32 {
        return self.m1;
    }
    pub fn getM31(self: Matrix) f32 {
        return self.m2;
    }
    pub fn getM41(self: Matrix) f32 {
        return self.m3;
    }
    pub fn getM14(self: Matrix) f32 {
        return self.m12;
    }
    pub fn getM24(self: Matrix) f32 {
        return self.m13;
    }
    pub fn getM34(self: Matrix) f32 {
        return self.m14;
    }
    pub fn getM44(self: Matrix) f32 {
        return self.m15;
    }
};

pub const Color = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub const white = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
    pub const black = Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
    pub const red = Color{ .r = 255, .g = 0, .b = 0, .a = 255 };
    pub const green = Color{ .r = 0, .g = 255, .b = 0, .a = 255 };
    pub const blue = Color{ .r = 0, .g = 0, .b = 255, .a = 255 };
    pub const yellow = Color{ .r = 255, .g = 255, .b = 0, .a = 255 };
    pub const magenta = Color{ .r = 255, .g = 0, .b = 255, .a = 255 };
    pub const cyan = Color{ .r = 0, .g = 255, .b = 255, .a = 255 };
    pub const light_gray = Color{ .r = 200, .g = 200, .b = 200, .a = 255 };
    pub const gray = Color{ .r = 130, .g = 130, .b = 130, .a = 255 };
    pub const dark_gray = Color{ .r = 80, .g = 80, .b = 80, .a = 255 };
    pub const ray_white = white;
};

pub const Rectangle = extern struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

// ============================================================================
// Graphics Types
// ============================================================================

pub const Texture2D = extern struct {
    id: raylib_c_uint,
    width: raylib_c_int,
    height: raylib_c_int,
    mipmaps: raylib_c_int,
    format: raylib_c_int,
};

pub const Texture = Texture2D;

pub const RenderTexture2D = extern struct {
    id: raylib_c_uint,
    texture: Texture2D,
    depth: Texture2D,
};

pub const Camera3D = extern struct {
    position: Vector3,
    target: Vector3,
    up: Vector3,
    fovy: f32,
    projection: CameraProjection,
};

pub const CameraProjection = enum(raylib_c_int) {
    perspective = 0,
    orthographic = 1,
};

pub const Model = extern struct {
    transform: Matrix,
    meshCount: raylib_c_int,
    materialCount: raylib_c_int,
    meshes: ?[*]Mesh,
    materials: ?[*]Material,
    meshMaterial: ?[*]raylib_c_int,
    boneCount: raylib_c_int,
    bones: ?[*]BoneInfo,
    bindPose: ?[*]Transform,
};

pub const Mesh = extern struct {
    vertexCount: raylib_c_int,
    triangleCount: raylib_c_int,
    vertices: ?[*]f32,
    texcoords: ?[*]f32,
    texcoords2: ?[*]f32,
    normals: ?[*]f32,
    tangents: ?[*]f32,
    colors: ?[*]u8,
    indices: ?[*]raylib_c_ushort,
    animVertices: ?[*]f32,
    animNormals: ?[*]f32,
    boneIds: ?[*]u8,
    boneWeights: ?[*]f32,
    vaoId: raylib_c_uint,
    vboId: ?[*]raylib_c_uint,
};

pub const Material = extern struct {
    shader: Shader,
    maps: ?[*]MaterialMap,
    params: [4]f32,
};

pub const Shader = extern struct {
    id: raylib_c_uint,
    locs: ?[*]raylib_c_int,
};

pub const MaterialMap = extern struct {
    texture: Texture2D,
    color: Color,
    value: f32,
};

pub const BoneInfo = extern struct {
    name: [32]u8,
    parent: raylib_c_int,
};

pub const Transform = extern struct {
    translation: Vector3,
    rotation: Quaternion,
    scale: Vector3,
};

pub const BoundingBox = extern struct {
    min: Vector3,
    max: Vector3,
};

pub const ModelAnimation = extern struct {
    boneCount: raylib_c_int,
    frameCount: raylib_c_int,
    bones: ?[*]BoneInfo,
    framePoses: ?[*][*]Transform,
    name: [32]u8,
};

pub const Font = extern struct {
    baseSize: raylib_c_int,
    glyphCount: raylib_c_int,
    glyphPadding: raylib_c_int,
    texture: Texture2D,
    recs: ?[*]Rectangle,
    glyphs: ?[*]GlyphInfo,
};

pub const GlyphInfo = extern struct {
    value: raylib_c_int,
    offsetX: raylib_c_int,
    offsetY: raylib_c_int,
    advanceX: raylib_c_int,
    image: Image,
};

pub const Image = extern struct {
    data: ?*anyopaque,
    width: raylib_c_int,
    height: raylib_c_int,
    mipmaps: raylib_c_int,
    format: raylib_c_int,
};

// ============================================================================
// Audio Types
// ============================================================================

pub const Sound = extern struct {
    stream: AudioStream,
    frameCount: raylib_c_uint,
};

pub const Music = extern struct {
    stream: AudioStream,
    frameCount: raylib_c_uint,
    looping: bool,
    ctxType: raylib_c_int,
    ctxData: ?*anyopaque,
};

pub const AudioStream = extern struct {
    buffer: ?*anyopaque,
    processor: ?*anyopaque,
    sampleRate: raylib_c_uint,
    sampleSize: raylib_c_uint,
    channels: raylib_c_uint,
};

// ============================================================================
// Input Types
// ============================================================================

pub const KeyboardKey = enum(raylib_c_int) {
    null = 0,
    apostrophe = 39,
    comma = 44,
    minus = 45,
    period = 46,
    slash = 47,
    zero = 48,
    one = 49,
    two = 50,
    three = 51,
    four = 52,
    five = 53,
    six = 54,
    seven = 55,
    eight = 56,
    nine = 57,
    semicolon = 59,
    equal = 61,
    a = 65,
    b = 66,
    c = 67,
    d = 68,
    e = 69,
    f = 70,
    g = 71,
    h = 72,
    i = 73,
    j = 74,
    k = 75,
    l = 76,
    m = 77,
    n = 78,
    o = 79,
    p = 80,
    q = 81,
    r = 82,
    s = 83,
    t = 84,
    u = 85,
    v = 86,
    w = 87,
    x = 88,
    y = 89,
    z = 90,
    left_bracket = 91,
    backslash = 92,
    right_bracket = 93,
    grave = 96,
    space = 32,
    escape = 256,
    enter = 257,
    tab = 258,
    backspace = 259,
    insert = 260,
    delete = 261,
    right = 262,
    left = 263,
    down = 264,
    up = 265,
    page_up = 266,
    page_down = 267,
    home = 268,
    end = 269,
    caps_lock = 280,
    scroll_lock = 281,
    num_lock = 282,
    print_screen = 283,
    pause = 284,
    f1 = 290,
    f2 = 291,
    f3 = 292,
    f4 = 293,
    f5 = 294,
    f6 = 295,
    f7 = 296,
    f8 = 297,
    f9 = 298,
    f10 = 299,
    f11 = 300,
    f12 = 301,
    left_shift = 340,
    left_control = 341,
    left_alt = 342,
    left_super = 343,
    right_shift = 344,
    right_control = 345,
    right_alt = 346,
    right_super = 347,
    kb_menu = 348,
};

pub const MouseButton = enum(raylib_c_int) {
    left = 0,
    right = 1,
    middle = 2,
    side = 3,
    extra = 4,
    forward = 5,
    back = 6,
};

// ============================================================================
// Configuration Types
// ============================================================================

pub const ConfigFlags = packed struct(u16) {
    vsync_hint: bool = false,
    fullscreen_mode: bool = false,
    window_resizable: bool = false,
    window_undecorated: bool = false,
    window_hidden: bool = false,
    window_minimized: bool = false,
    window_maximized: bool = false,
    window_unfocused: bool = false,
    window_topmost: bool = false,
    window_always_run: bool = false,
    window_transparent: bool = false,
    window_highdpi: bool = false,
    window_mouse_passthrough: bool = false,
    borderless_windowed_mode: bool = false,
    msaa_4x_hint: bool = false,
    interlaced_hint: bool = false,
};

// ============================================================================
// Utility Types
// ============================================================================

pub const Ray = extern struct {
    position: Vector3,
    direction: Vector3,
};

pub const FilePathList = extern struct {
    capacity: raylib_c_uint,
    count: raylib_c_uint,
    paths: [*][*:0]u8,
};

// ============================================================================
// Core Functions (matching raylib-zig API)
// ============================================================================

pub fn initWindow(width: i32, height: i32, title: [:0]const u8) void {
    _ = width;
    _ = height;
    _ = title;
}

pub fn closeWindow() void {}

pub fn windowShouldClose() bool {
    return false;
}

pub fn setConfigFlags(flags: ConfigFlags) void {
    _ = flags;
}

pub fn setTargetFPS(fps: i32) void {
    _ = fps;
}

pub fn setExitKey(key: KeyboardKey) void {
    _ = key;
}

pub fn getFrameTime() f32 {
    return 0.016; // ~60 FPS
}

pub fn getScreenWidth() raylib_c_int {
    return 800; // Default window width
}

pub fn getScreenHeight() raylib_c_int {
    return 600; // Default window height
}

pub fn isWindowReady() bool {
    return true; // Assume window is always ready
}

pub fn fileExists(fileName: [:0]const u8) bool {
    _ = fileName;
    return false; // Stub: assume files don't exist
}

pub fn getWindowScaleDPI() Vector2 {
    return .{ .x = 1.0, .y = 1.0 };
}

pub fn measureText(text: [*:0]const u8, fontSize: raylib_c_int) raylib_c_int {
    _ = text;
    _ = fontSize;
    return 100; // Dummy text width
}

pub fn measureTextEx(font: Font, text: [*:0]const u8, fontSize: f32, spacing: f32) Vector2 {
    _ = font;
    _ = text;
    _ = fontSize;
    _ = spacing;
    return .{ .x = 100, .y = 16 }; // Dummy text size
}

// ============================================================================
// Drawing Functions
// ============================================================================

pub fn beginDrawing() void {}

pub fn endDrawing() void {}

pub fn clearBackground(color: Color) void {
    _ = color;
}

pub fn beginMode3D(camera: Camera3D) void {
    _ = camera;
}

pub fn endMode3D() void {}

pub fn beginScissorMode(x: i32, y: i32, width: i32, height: i32) void {
    _ = x;
    _ = y;
    _ = width;
    _ = height;
}

pub fn endScissorMode() void {}

pub fn drawText(text: [:0]const u8, x: i32, y: i32, fontSize: i32, color: Color) void {
    _ = text;
    _ = x;
    _ = y;
    _ = fontSize;
    _ = color;
}

pub fn drawCircle(centerX: i32, centerY: i32, radius: f32, color: Color) void {
    _ = centerX;
    _ = centerY;
    _ = radius;
    _ = color;
}

pub fn drawRectangle(posX: i32, posY: i32, width: i32, height: i32, color: Color) void {
    _ = posX;
    _ = posY;
    _ = width;
    _ = height;
    _ = color;
}

pub fn drawModel(model: Model, position: Vector3, scale: f32, tint: Color) void {
    _ = model;
    _ = position;
    _ = scale;
    _ = tint;
}

pub fn drawModelEx(model: Model, position: Vector3, rotationAxis: Vector3, rotationAngle: f32, scale: Vector3, tint: Color) void {
    _ = model;
    _ = position;
    _ = rotationAxis;
    _ = rotationAngle;
    _ = scale;
    _ = tint;
}

pub fn drawModelWires(model: Model, position: Vector3, scale: f32, tint: Color) void {
    _ = model;
    _ = position;
    _ = scale;
    _ = tint;
}

pub fn drawCube(position: Vector3, width: f32, height: f32, length: f32, color: Color) void {
    _ = position;
    _ = width;
    _ = height;
    _ = length;
    _ = color;
}

pub fn drawCubeWires(position: Vector3, width: f32, height: f32, length: f32, color: Color) void {
    _ = position;
    _ = width;
    _ = height;
    _ = length;
    _ = color;
}

pub fn drawSphere(centerPos: Vector3, radius: f32, color: Color) void {
    _ = centerPos;
    _ = radius;
    _ = color;
}

pub fn drawSphereWires(centerPos: Vector3, radius: f32, rings: i32, slices: i32, color: Color) void {
    _ = centerPos;
    _ = radius;
    _ = rings;
    _ = slices;
    _ = color;
}

// ============================================================================
// Input Functions
// ============================================================================

pub fn isKeyPressed(key: KeyboardKey) bool {
    _ = key;
    return false;
}

pub fn isKeyDown(key: KeyboardKey) bool {
    _ = key;
    return false;
}

pub fn isMouseButtonPressed(button: MouseButton) bool {
    _ = button;
    return false;
}

pub fn isMouseButtonDown(button: MouseButton) bool {
    _ = button;
    return false;
}

pub fn isMouseButtonReleased(button: MouseButton) bool {
    _ = button;
    return false;
}

pub fn getMousePosition() Vector2 {
    return .{ .x = 0, .y = 0 };
}

pub fn getMouseDelta() Vector2 {
    return .{ .x = 0, .y = 0 };
}

pub fn getMouseWheelMove() f32 {
    return 0;
}

pub fn checkCollisionPointRec(point: Vector2, rec: Rectangle) bool {
    _ = point;
    _ = rec;
    return false;
}

pub fn getMouseRay(mousePosition: Vector2, camera: Camera3D) Ray {
    _ = mousePosition;
    _ = camera;
    return .{
        .position = .{ .x = 0, .y = 0, .z = 0 },
        .direction = .{ .x = 0, .y = 0, .z = -1 },
    };
}

// ============================================================================
// Audio Functions
// ============================================================================

pub fn initAudioDevice() void {}

pub fn closeAudioDevice() void {}

pub fn loadSound(fileName: [:0]const u8) Sound {
    _ = fileName;
    return std.mem.zeroes(Sound);
}

pub fn unloadSound(sound: Sound) void {
    _ = sound;
}

pub fn playSound(sound: Sound) void {
    _ = sound;
}

pub fn stopSound(sound: Sound) void {
    _ = sound;
}

pub fn isSoundPlaying(sound: Sound) bool {
    _ = sound;
    return false;
}

pub fn setSoundVolume(sound: Sound, volume: f32) void {
    _ = sound;
    _ = volume;
}

pub fn setSoundPitch(sound: Sound, pitch: f32) void {
    _ = sound;
    _ = pitch;
}

// ============================================================================
// File I/O Functions
// ============================================================================

pub fn loadFileData(fileName: [:0]const u8, dataSize: *raylib_c_int) ?[*]u8 {
    _ = fileName;
    dataSize.* = 0;
    return null; // File not found
}

pub fn unloadFileData(data: [*]u8) void {
    _ = data;
}

pub fn loadFileText(fileName: [:0]const u8) ?[*:0]u8 {
    _ = fileName;
    // Return a valid null-terminated empty string, or null on error
    return @constCast("");
}

pub fn unloadFileText(text: ?[*:0]u8) void {
    _ = text;
}

pub fn saveFileText(fileName: [:0]const u8, text: [*:0]const u8) bool {
    _ = fileName;
    _ = text;
    return false;
}

// ============================================================================
// Asset Loading Functions
// ============================================================================

pub fn loadTexture(fileName: [:0]const u8) Texture2D {
    _ = fileName;
    return std.mem.zeroes(Texture2D);
}

pub fn unloadTexture(texture: Texture2D) void {
    _ = texture;
}

pub fn loadModel(fileName: [:0]const u8) Model {
    _ = fileName;
    return std.mem.zeroes(Model);
}

pub fn unloadModel(model: Model) void {
    _ = model;
}

pub fn loadShader(vsFileName: ?[:0]const u8, fsFileName: ?[:0]const u8) Shader {
    _ = vsFileName;
    _ = fsFileName;
    return std.mem.zeroes(Shader);
}

pub fn unloadShader(shader: Shader) void {
    _ = shader;
}

pub fn loadRenderTexture(width: i32, height: i32) RenderTexture2D {
    _ = width;
    _ = height;
    return std.mem.zeroes(RenderTexture2D);
}

pub fn unloadRenderTexture(target: RenderTexture2D) void {
    _ = target;
}

pub fn getFontDefault() Font {
    return std.mem.zeroes(Font);
}

pub fn loadFont(fileName: [:0]const u8) Font {
    _ = fileName;
    return std.mem.zeroes(Font);
}

pub fn unloadFont(font: Font) void {
    _ = font;
}

// ============================================================================
// Directory Functions
// ============================================================================

pub fn loadDirectoryFiles(dirPath: [:0]const u8) FilePathList {
    _ = dirPath;
    return .{
        .capacity = 0,
        .count = 0,
        .paths = undefined,
    };
}

pub fn unloadDirectoryFiles(files: FilePathList) void {
    _ = files;
    // Stub implementation - nothing to unload
}

pub fn getModelBoundingBox(model: Model) BoundingBox {
    _ = model;
    return BoundingBox{ .min = .{ .x = -1, .y = -1, .z = -1 }, .max = .{ .x = 1, .y = 1, .z = 1 } };
}

pub fn enableCursor() void {}

pub fn disableCursor() void {}

pub fn hideCursor() void {}

pub fn showCursor() void {}

pub fn drawLine(startPosX: i32, startPosY: i32, endPosX: i32, endPosY: i32, color: Color) void {
    _ = startPosX;
    _ = startPosY;
    _ = endPosX;
    _ = endPosY;
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

pub fn drawPlane(centerPos: Vector3, size: Vector2, color: Color) void {
    _ = centerPos;
    _ = size;
    _ = color;
}

pub fn drawGrid(slices: i32, spacing: f32) void {
    _ = slices;
    _ = spacing;
}

pub fn getCharPressed() i32 {
    return 0;
}

pub fn getScreenToWorldRay(position: Vector2, camera: Camera3D) Ray {
    _ = position;
    _ = camera;
    return .{
        .position = .{ .x = 0, .y = 0, .z = 0 },
        .direction = .{ .x = 0, .y = 0, .z = -1 },
    };
}

pub fn unloadModelAnimation(anim: ModelAnimation) void {
    _ = anim;
}

pub fn isWindowResized() bool {
    return false;
}

pub fn unloadMesh(mesh: Mesh) void {
    _ = mesh;
}

pub fn unloadMaterial(material: Material) void {
    _ = material;
}

pub fn getRayCollisionBox(ray: Ray, box: BoundingBox) RayCollision {
    _ = ray;
    _ = box;
    return .{
        .hit = false,
        .distance = 0,
        .point = .{ .x = 0, .y = 0, .z = 0 },
        .normal = .{ .x = 0, .y = 0, .z = 0 },
    };
}

pub const RayCollision = extern struct {
    hit: bool,
    distance: f32,
    point: Vector3,
    normal: Vector3,
};

pub fn directoryExists(dirPath: [:0]const u8) bool {
    _ = dirPath;
    return false;
}

pub fn makeDirectory(dirPath: [:0]const u8) bool {
    _ = dirPath;
    return true; // Assume success
}

// ============================================================================
// Vector3 Math Functions
// ============================================================================

pub fn vec3Distance(v1: Vector3, v2: Vector3) f32 {
    const dx = v2.x - v1.x;
    const dy = v2.y - v1.y;
    const dz = v2.z - v1.z;
    return @sqrt(dx * dx + dy * dy + dz * dz);
}

// ============================================================================
// Camera Functions
// ============================================================================

pub fn getCameraMatrix(camera: Camera3D) Matrix {
    _ = camera;
    return Matrix.identity();
}

// ============================================================================
// Color Constants (matching raylib-zig)
// ============================================================================

pub const WHITE = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
pub const BLACK = Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
pub const RED = Color{ .r = 255, .g = 0, .b = 0, .a = 255 };
pub const BLUE = Color{ .r = 0, .g = 0, .b = 255, .a = 255 };
pub const GREEN = Color{ .r = 0, .g = 255, .b = 0, .a = 255 };
pub const YELLOW = Color{ .r = 255, .g = 255, .b = 0, .a = 255 };
pub const MAGENTA = Color{ .r = 255, .g = 0, .b = 255, .a = 255 };
pub const CYAN = Color{ .r = 0, .g = 255, .b = 255, .a = 255 };
pub const LIGHT_GRAY = Color{ .r = 200, .g = 200, .b = 200, .a = 255 };
pub const GRAY = Color{ .r = 130, .g = 130, .b = 130, .a = 255 };
pub const DARK_GRAY = Color{ .r = 80, .g = 80, .b = 80, .a = 255 };
pub const RAY_WHITE = WHITE;
