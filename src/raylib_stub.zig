const std = @import("std");

pub const Vector2 = extern struct {
    x: f32,
    y: f32,
};

pub const Vector3 = extern struct {
    x: f32,
    y: f32,
    z: f32,
};

pub const Ray = extern struct {
    position: Vector3,
    direction: Vector3,
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
    pub const yellow = Color{ .r = 253, .g = 249, .b = 0, .a = 255 };
    pub const gray = Color{ .r = 130, .g = 130, .b = 130, .a = 255 };
};

pub const Sound = extern struct {
    stream: AudioStream,
    frameCount: c_uint,
};

pub const AudioStream = extern struct {
    buffer: ?*anyopaque,
    processor: ?*anyopaque,
    sampleRate: c_uint,
    sampleSize: c_uint,
    channels: c_uint,
};

pub const BoundingBox = extern struct {
    min: Vector3,
    max: Vector3,
};

pub const MouseButton = enum(c_int) {
    left = 0,
    right = 1,
    middle = 2,
    side = 3,
    extra = 4,
    forward = 5,
    back = 6,
};

pub extern fn isMouseButtonDown(button: MouseButton) bool;
pub extern fn isMouseButtonPressed(button: MouseButton) bool;
pub extern fn isMouseButtonReleased(button: MouseButton) bool;
pub extern fn loadShader(vsFileName: ?[*:0]const u8, fsFileName: ?[*:0]const u8) Shader;
pub extern fn getModelBoundingBox(model: Model) BoundingBox;
pub extern fn unloadModel(model: Model) void;
pub extern fn fileExists(fileName: [*:0]const u8) bool;
pub extern fn loadFileText(fileName: [*:0]const u8) ?[*:0]u8;
pub extern fn unloadFileText(text: [*:0]u8) void;
pub extern fn saveFileText(fileName: [*:0]const u8, text: [*:0]const u8) bool;
pub extern fn loadRenderTexture(width: c_int, height: c_int) RenderTexture2D;
pub extern fn unloadRenderTexture(target: RenderTexture2D) void;
pub extern fn beginDrawing() void;
pub extern fn endDrawing() void;
pub extern fn clearBackground(color: Color) void;
pub const FilePathList = extern struct {
    capacity: c_uint,
    count: c_uint,
    paths: [*][*:0]u8,
};

pub extern fn loadDirectoryFiles(dirPath: [*:0]const u8) FilePathList;
pub extern fn unloadDirectoryFiles(files: FilePathList) void;
pub extern fn loadFileData(fileName: [*:0]const u8, dataSize: *c_int) ?[*]u8;
pub extern fn unloadFileData(data: [*]u8) void;
pub extern fn getFrameTime() f32;
pub extern fn getFontDefault() Font;
pub extern fn loadFontEx(fileName: [*:0]const u8, fontSize: c_int, fontChars: ?[*]c_int, glyphCount: c_int) Font;
pub extern fn unloadFont(font: Font) void;

pub const ConfigFlags = packed struct {
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
    transparent_window: bool = false,
    high_dpi: bool = false,
    mouse_cursor_hidden: bool = false,
    mouse_cursor_centered: bool = false,
    audio_soft: bool = false,
    msaa_4x_hint: bool = false,
};

pub const Rectangle = extern struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

pub const Font = extern struct {
    baseSize: c_int,
    glyphCount: c_int,
    glyphPadding: c_int,
    texture: Texture2D,
    recs: ?[*]Rectangle,
    glyphs: ?*anyopaque, // GlyphInfo
};

pub extern fn drawText(text: [*:0]const u8, posX: c_int, posY: c_int, fontSize: c_int, color: Color) void;
pub extern fn unloadSound(sound: Sound) void;
pub extern fn closeWindow() void;
pub extern fn unloadMaterial(material: Material) void;
pub extern fn drawRectangleRec(rec: Rectangle, color: Color) void;
pub extern fn drawRectangleLinesEx(rec: Rectangle, lineThick: c_int, color: Color) void;
pub extern fn isWindowResized() bool;
pub extern fn measureText(text: [*:0]const u8, fontSize: c_int) c_int;
pub extern fn unloadModelAnimation(anim: ModelAnimation) void;
pub extern fn unloadTexture(texture: Texture2D) void;
pub extern fn loadModel(fileName: [*:0]const u8) Model; // Error union handled by wrapper if needed, but extern just returns Model
pub extern fn closeAudioDevice() void;
pub extern fn unloadMesh(mesh: Mesh) void;
pub extern fn unloadShader(shader: Shader) void;
pub extern fn directoryExists(dirPath: [*:0]const u8) bool;
pub extern fn makeDirectory(dirPath: [*:0]const u8) bool;

pub const Mesh = extern struct {
    vertexCount: i32,
    triangleCount: i32,
    vertices: [*]f32,
    texcoords: [*]f32,
    texcoords2: [*]f32,
    normals: [*]f32,
    tangents: [*]f32,
    colors: [*]u8,
    indices: [*]u16,
    animVertices: [*]f32,
    animNormals: [*]f32,
    boneIds: [*]c_int,
    boneWeights: [*]f32,
    boneCount: i32,
    boneMatrices: [*]f32,
    vaoId: c_int,
    vboId: [*]c_int,
};

pub const Camera3D = extern struct {
    position: Vector3,
    target: Vector3,
    up: Vector3,
    fovy: f32,
    projection: CameraProjection,
};

pub const CameraProjection = enum(c_int) {
    perspective = 0,
    orthographic = 1,
};

pub const KeyboardKey = enum(c_int) {
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
};

pub fn setConfigFlags(_: ConfigFlags) void {}
pub extern fn initWindow(width: i32, height: i32, title: [*:0]const u8) void;
pub extern fn windowShouldClose() bool;
pub extern fn setTargetFPS(fps: i32) void;
pub extern fn setExitKey(key: KeyboardKey) void;
pub extern fn getScreenWidth() i32;
pub extern fn getScreenHeight() i32;
pub extern fn getWindowScaleDPI() Vector2;
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
};

pub const Vector4 = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,
};

pub const Quaternion = Vector4;

pub const Texture2D = extern struct {
    id: c_uint,
    width: c_int,
    height: c_int,
    mipmaps: c_int,
    format: c_int,
};

pub const Texture = Texture2D;

pub const RenderTexture2D = extern struct {
    id: c_uint,
    texture: Texture2D,
    depth: Texture2D,
};

pub const Image = extern struct {
    data: ?*anyopaque,
    width: c_int,
    height: c_int,
    mipmaps: c_int,
    format: c_int,
};

pub const Shader = extern struct {
    id: c_uint,
    locs: ?*c_int,
};

pub const MaterialMap = extern struct {
    texture: Texture2D,
    color: Color,
    value: f32,
};

pub const Material = extern struct {
    shader: Shader,
    maps: ?*MaterialMap,
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
    meshes: ?*Mesh,
    materials: ?*Material,
    meshMaterial: ?*c_int,
    boneCount: c_int,
    bones: ?*BoneInfo,
    bindPose: ?*Transform,
};

pub const ModelAnimation = extern struct {
    boneCount: c_int,
    frameCount: c_int,
    bones: ?*BoneInfo,
    framePoses: ?*?*Transform,
};

// Enum compatibility fix: accept enum types for extern functions where stub is used
pub extern fn isKeyDown(key: KeyboardKey) bool;
pub extern fn isKeyPressed(key: KeyboardKey) bool;
pub extern fn isKeyReleased(key: KeyboardKey) bool;
pub extern fn initAudioDevice() void;
pub extern fn getCharPressed() c_int;
pub extern fn getMousePosition() Vector2;
pub extern fn isWindowReady() bool;
pub extern fn enableCursor() void;
pub extern fn disableCursor() void;
pub extern fn beginMode3D(camera: Camera3D) void;
pub extern fn endMode3D() void;
pub extern fn drawLine(startPosX: c_int, startPosY: c_int, endPosX: c_int, endPosY: c_int, color: Color) void;
pub extern fn drawCircleV(center: Vector2, radius: f32, color: Color) void;
pub extern fn drawRectangleRounded(rec: Rectangle, roundness: f32, segments: c_int, color: Color) void;
pub extern fn beginScissorMode(x: c_int, y: c_int, width: c_int, height: c_int) void;
pub extern fn endScissorMode() void;
pub extern fn drawLine3D(startPos: Vector3, endPos: Vector3, color: Color) void;
pub extern fn getTime() f64;
pub extern fn drawPlane(centerPos: Vector3, size: Vector2, color: Color) void;
pub extern fn getScreenToWorldRay(mousePosition: Vector2, camera: Camera3D) Ray;
pub extern fn getMouseDelta() Vector2;
pub extern fn drawRectangleRoundedLinesEx(rec: Rectangle, roundness: f32, segments: c_int, lineThick: f32, color: Color) void;
