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

pub const Color = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

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
    baseSize: i32,
    baseHeight: i32,
    textureCount: i32,
    padding: i32,
    atlasSize: i32,
    recs: [*]Rectangle,
    chars: [*]f32,
};

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
    projection: c_int,
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
pub extern fn isKeyDown(key: i32) bool;
pub extern fn initAudioDevice() void;
pub extern fn genMeshCube(width: f32, height: f32, depth: f32) Mesh;
pub extern fn genMeshSphere(radius: f32, rings: i32, slices: i32) Mesh;
pub extern fn isWindowReady() bool;
pub extern fn closeWindow() void;
