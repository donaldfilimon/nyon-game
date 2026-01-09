//! Input Handling

const std = @import("std");
const window = @import("window.zig");

/// Key codes
pub const Key = enum(u32) {
    unknown = 0,
    // Letters
    a = 65,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
    i,
    j,
    k,
    l,
    m,
    n,
    o,
    p,
    q,
    r,
    s,
    t,
    u,
    v,
    w,
    x,
    y,
    z,
    // Numbers
    num_0 = 48,
    num_1,
    num_2,
    num_3,
    num_4,
    num_5,
    num_6,
    num_7,
    num_8,
    num_9,
    // Function keys
    f1 = 112,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    f11,
    f12,
    // Special keys
    escape = 27,
    enter = 13,
    tab = 9,
    backspace = 8,
    space = 32,
    left = 37,
    up = 38,
    right = 39,
    down = 40,
    left_shift = 160,
    right_shift = 161,
    left_ctrl = 162,
    right_ctrl = 163,
    left_alt = 164,
    right_alt = 165,
};

/// Mouse buttons
pub const MouseButton = enum(u8) {
    left = 0,
    right = 1,
    middle = 2,
    x1 = 3,
    x2 = 4,
};

/// Input state
pub const State = struct {
    keys_down: [256]bool = [_]bool{false} ** 256,
    keys_pressed: [256]bool = [_]bool{false} ** 256,
    keys_released: [256]bool = [_]bool{false} ** 256,
    mouse_buttons: [5]bool = [_]bool{false} ** 5,
    mouse_x: i32 = 0,
    mouse_y: i32 = 0,
    mouse_dx: i32 = 0,
    mouse_dy: i32 = 0,
    scroll_x: f32 = 0,
    scroll_y: f32 = 0,
    quit_requested: bool = false,

    pub fn init() State {
        return .{};
    }

    pub fn poll(self: *State, win_handle: ?window.Handle) void {
        // Clear per-frame state
        @memset(&self.keys_pressed, false);
        @memset(&self.keys_released, false);
        self.mouse_dx = 0;
        self.mouse_dy = 0;
        self.scroll_x = 0;
        self.scroll_y = 0;

        _ = win_handle;
        // Poll platform events and update state
        window.pollEvents();
    }

    pub fn isKeyDown(self: *const State, key: Key) bool {
        const k = @intFromEnum(key);
        if (k < 256) return self.keys_down[k];
        return false;
    }

    pub fn isKeyPressed(self: *const State, key: Key) bool {
        const k = @intFromEnum(key);
        if (k < 256) return self.keys_pressed[k];
        return false;
    }

    pub fn isKeyReleased(self: *const State, key: Key) bool {
        const k = @intFromEnum(key);
        if (k < 256) return self.keys_released[k];
        return false;
    }

    pub fn isMouseButtonDown(self: *const State, button: MouseButton) bool {
        return self.mouse_buttons[@intFromEnum(button)];
    }

    pub fn getMousePosition(self: *const State) struct { x: i32, y: i32 } {
        return .{ .x = self.mouse_x, .y = self.mouse_y };
    }

    pub fn getMouseDelta(self: *const State) struct { dx: i32, dy: i32 } {
        return .{ .dx = self.mouse_dx, .dy = self.mouse_dy };
    }

    pub fn shouldQuit(self: *const State) bool {
        return self.quit_requested or self.isKeyPressed(.escape);
    }

    // Event handlers (called from platform layer)
    pub fn onKeyDown(self: *State, key: Key) void {
        const k = @intFromEnum(key);
        if (k < 256 and !self.keys_down[k]) {
            self.keys_down[k] = true;
            self.keys_pressed[k] = true;
        }
    }

    pub fn onKeyUp(self: *State, key: Key) void {
        const k = @intFromEnum(key);
        if (k < 256) {
            self.keys_down[k] = false;
            self.keys_released[k] = true;
        }
    }

    pub fn onMouseMove(self: *State, x: i32, y: i32) void {
        self.mouse_dx = x - self.mouse_x;
        self.mouse_dy = y - self.mouse_y;
        self.mouse_x = x;
        self.mouse_y = y;
    }

    pub fn onMouseButton(self: *State, button: MouseButton, pressed: bool) void {
        self.mouse_buttons[@intFromEnum(button)] = pressed;
    }

    pub fn onScroll(self: *State, dx: f32, dy: f32) void {
        self.scroll_x = dx;
        self.scroll_y = dy;
    }
};
