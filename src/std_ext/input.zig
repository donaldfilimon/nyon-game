//! Input Utilities for Game Engine Development
//!

const std = @import("std");

/// Key codes matching common keyboard layouts
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
    f13 = 302,
    f14 = 303,
    f15 = 304,
    f16 = 305,
    f17 = 306,
    f18 = 307,
    f19 = 308,
    f20 = 309,
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
    kp_decimal = 330,
    kp_divide = 331,
    kp_multiply = 332,
    kp_subtract = 333,
    kp_add = 334,
    kp_enter = 335,
    kp_equal = 336,
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

/// Mouse buttons
pub const MouseButton = enum(u8) {
    left = 0,
    right = 1,
    middle = 2,
};

/// Input state
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

/// Action binding for input mapping
pub const ActionBinding = struct {
    name: []const u8,
    keys: std.ArrayList(KeyCode),
    mouse_buttons: std.ArrayList(MouseButton),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !ActionBinding {
        return ActionBinding{
            .name = try allocator.dupe(u8, name),
            .keys = std.ArrayList(KeyCode).init(allocator),
            .mouse_buttons = std.ArrayList(MouseButton).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ActionBinding) void {
        self.allocator.free(self.name);
        self.keys.deinit();
        self.mouse_buttons.deinit();
    }

    pub fn bindKey(self: *ActionBinding, key: KeyCode) !void {
        try self.keys.append(key);
    }

    pub fn bindMouseButton(self: *ActionBinding, button: MouseButton) !void {
        try self.mouse_buttons.append(button);
    }

    pub fn isTriggered(self: *const ActionBinding, input: *const InputState) bool {
        for (self.keys.items) |key| {
            if (input.isKeyDown(key)) return true;
        }
        for (self.mouse_buttons.items) |button| {
            if (input.mouse_buttons[@intFromEnum(button)]) return true;
        }
        return false;
    }
};

/// Action mapping for managing input bindings
pub const ActionMap = struct {
    actions: std.StringHashMap(ActionBinding),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ActionMap {
        return ActionMap{
            .actions = std.StringHashMap(ActionBinding).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ActionMap) void {
        var iter = self.actions.valueIterator();
        while (iter.next()) |action| {
            action.deinit();
        }
        self.actions.deinit();
    }

    pub fn createAction(self: *ActionMap, name: []const u8) !ActionBinding {
        const binding = try ActionBinding.init(self.allocator, name);
        try self.actions.put(name, binding);
        return binding;
    }

    pub fn getAction(self: *ActionMap, name: []const u8) ?*ActionBinding {
        return self.actions.getPtr(name);
    }

    pub fn isActionTriggered(self: *ActionMap, name: []const u8, input: *const InputState) bool {
        if (self.actions.get(name)) |action| {
            return action.isTriggered(input);
        }
        return false;
    }
};
