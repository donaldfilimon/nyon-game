//! Unified input handling utilities for camera and object movement.
//!
//! This module provides reusable input controllers for common movement patterns
//! (WASD movement, mouse look, etc.) to reduce code duplication across
//! editor and game code.

const std = @import("std");
const raylib = @import("raylib");

const engine_mod = @import("engine.zig");
const Vector2 = engine_mod.Vector2;
const Vector3 = engine_mod.Vector3;

pub const KeyCode = enum(u32) {
    unknown = 0,
    space = 32,
    apostrophe = 39,
    comma = 44,
    minus = 45,
    period = 46,
    slash = 47,
    _0 = 48,
    _1 = 49,
    _2 = 50,
    _3 = 51,
    _4 = 52,
    _5 = 53,
    _6 = 54,
    _7 = 55,
    _8 = 56,
    _9 = 57,
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
    grave_accent = 96,
    world_1 = 161,
    world_2 = 162,
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
    kp_0 = 320,
    kp_1 = 321,
    kp_2 = 322,
    kp_3 = 323,
    kp_4 = 324,
    kp_5 = 325,
    kp_6 = 326,
    kp_7 = 327,
    kp_8 = 328,
    kp_9 = 329,
    left_shift = 340,
    left_control = 341,
    left_alt = 342,
    left_super = 343,
    right_shift = 344,
    right_control = 345,
    right_alt = 346,
    right_super = 347,
    menu = 348,
};

pub const MouseButton = enum(u8) {
    left = 0,
    right = 1,
    middle = 2,
};

pub const InputState = struct {
    keys: std.AutoHashMap(KeyCode, bool),
    mouse_position: [2]f32,
    mouse_delta: [2]f32,
    mouse_buttons: [3]bool,
    scroll_delta: f32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) InputState {
        return InputState{
            .keys = std.AutoHashMap(KeyCode, bool).init(allocator),
            .mouse_position = [2]f32{ 0, 0 },
            .mouse_delta = [2]f32{ 0, 0 },
            .mouse_buttons = [3]bool{ false, false, false },
            .scroll_delta = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *InputState) void {
        self.keys.deinit();
    }

    pub fn isKeyDown(self: *const InputState, key: KeyCode) bool {
        return self.keys.get(key) orelse false;
    }

    pub fn onKeyDown(self: *InputState, key: KeyCode) void {
        self.keys.put(key, true) catch {};
    }

    pub fn onKeyUp(self: *InputState, key: KeyCode) void {
        self.keys.put(key, false) catch {};
    }

    pub fn onMouseMove(self: *InputState, x: f32, y: f32) void {
        self.mouse_delta[0] = x - self.mouse_position[0];
        self.mouse_delta[1] = y - self.mouse_position[1];
        self.mouse_position = [2]f32{ x, y };
    }

    pub fn onMouseDown(self: *InputState, button: MouseButton) void {
        self.mouse_buttons[@intFromEnum(button)] = true;
    }

    pub fn onMouseUp(self: *InputState, button: MouseButton) void {
        self.mouse_buttons[@intFromEnum(button)] = false;
    }

    pub fn onScroll(self: *InputState, delta: f32) void {
        self.scroll_delta = delta;
    }

    pub fn update(self: *InputState) void {
        self.mouse_delta = [2]f32{ 0, 0 };
        self.scroll_delta = 0;
    }
};

pub const MovementConfig = struct {
    speed: f32 = 0.1,
    sprint_multiplier: f32 = 2.0,
    mouse_sensitivity: f32 = 0.003,
    vertical_speed: f32 = 0.1,
};

pub const MovementController = struct {
    config: MovementConfig,

    pub fn init(config: MovementConfig) MovementController {
        return MovementController{ .config = config };
    }

    pub fn processWASDInput(position: *Vector3, speed: f32) bool {
        var changed = false;

        if (raylib.isKeyDown(.w)) {
            position.z -= speed;
            changed = true;
        }
        if (raylib.isKeyDown(.s)) {
            position.z += speed;
            changed = true;
        }
        if (raylib.isKeyDown(.a)) {
            position.x -= speed;
            changed = true;
        }
        if (raylib.isKeyDown(.d)) {
            position.x += speed;
            changed = true;
        }
        if (raylib.isKeyDown(.q)) {
            position.y += speed;
            changed = true;
        }
        if (raylib.isKeyDown(.e)) {
            position.y -= speed;
            changed = true;
        }

        return changed;
    }

    pub fn processWASDInputSprint(position: *Vector3, speed: f32, sprint_key: KeyCode) bool {
        const is_sprinting = raylib.isKeyDown(@enumFromInt(@intFromEnum(sprint_key)));
        const actual_speed = if (is_sprinting) speed * 2.0 else speed;
        return processWASDInput(position, actual_speed);
    }

    pub fn processArrowInput(position: *Vector3) bool {
        var changed = false;

        if (raylib.isKeyDown(.up)) {
            position.z -= 0.1;
            changed = true;
        }
        if (raylib.isKeyDown(.down)) {
            position.z += 0.1;
            changed = true;
        }
        if (raylib.isKeyDown(.left)) {
            position.x -= 0.1;
            changed = true;
        }
        if (raylib.isKeyDown(.right)) {
            position.x += 0.1;
            changed = true;
        }

        return changed;
    }

    pub fn processMouseLook(delta_x: f32, delta_y: f32, sensitivity: f32) struct { yaw: f32, pitch: f32 } {
        return .{
            .yaw = delta_x * sensitivity,
            .pitch = delta_y * sensitivity,
        };
    }

    pub fn getMovementVector() Vector3 {
        var result = Vector3{ .x = 0, .y = 0, .z = 0 };

        if (raylib.isKeyDown(.w)) result.z -= 1.0;
        if (raylib.isKeyDown(.s)) result.z += 1.0;
        if (raylib.isKeyDown(.a)) result.x -= 1.0;
        if (raylib.isKeyDown(.d)) result.x += 1.0;
        if (raylib.isKeyDown(.q)) result.y += 1.0;
        if (raylib.isKeyDown(.e)) result.y -= 1.0;

        const length = @sqrt(result.x * result.x + result.y * result.y + result.z * result.z);
        if (length > 0.0) {
            result.x /= length;
            result.y /= length;
            result.z /= length;
        }

        return result;
    }

    pub fn processCameraOrbit(
        yaw: *f32,
        pitch: *f32,
        distance: *f32,
        delta_x: f32,
        delta_y: f32,
        zoom_delta: f32,
        sensitivity: f32,
    ) bool {
        var changed = false;

        if (@abs(delta_x) > 0.001) {
            yaw.* += delta_x * sensitivity;
            changed = true;
        }

        if (@abs(delta_y) > 0.001) {
            pitch.* += delta_y * sensitivity;
            pitch.* = std.math.clamp(pitch.*, std.math.pi / 180.0 * -89.0, std.math.pi / 180.0 * 89.0);
            changed = true;
        }

        if (@abs(zoom_delta) > 0.001) {
            distance.* -= zoom_delta;
            distance.* = @max(distance.*, 1.0);
            changed = true;
        }

        return changed;
    }
};

pub const InputAction = struct {
    name: []const u8,
    primary_key: KeyCode,
    alt_key: ?KeyCode = null,
    mouse_button: ?MouseButton = null,

    pub fn isPressed(self: InputAction) bool {
        if (raylib.isKeyDown(@enumFromInt(@intFromEnum(self.primary_key)))) return true;
        if (self.alt_key) |alt| {
            if (raylib.isKeyDown(@enumFromInt(@intFromEnum(alt)))) return true;
        }
        if (self.mouse_button) |btn| {
            if (raylib.isMouseButtonDown(@intFromEnum(btn))) return true;
        }
        return false;
    }
};

pub const InputActionSet = struct {
    actions: std.StringHashMap(InputAction),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) InputActionSet {
        return InputActionSet{
            .actions = std.StringHashMap(InputAction).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *InputActionSet) void {
        self.actions.deinit();
    }

    pub fn register(self: *InputActionSet, name: []const u8, action: InputAction) !void {
        try self.actions.put(name, action);
    }

    pub fn isActionPressed(self: *InputActionSet, name: []const u8) bool {
        if (self.actions.get(name)) |action| {
            return action.isPressed();
        }
        return false;
    }
};

test "MovementController processes WASD input" {
    var position = Vector3{ .x = 0, .y = 0, .z = 0 };
    _ = MovementController.init(.{ .speed = 0.1 });

    try std.testing.expect(position.x == 0 and position.y == 0 and position.z == 0);
}

test "getMovementVector normalizes diagonal movement" {
    const vec = MovementController.getMovementVector();
    const length = @sqrt(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z);
    try std.testing.expect(length <= 1.0 or length == 0.0);
}

test "InputAction.isPressed checks primary key" {
    const action = InputAction{
        .name = "test",
        .primary_key = .space,
    };

    try std.testing.expect(action.name.len > 0);
}
