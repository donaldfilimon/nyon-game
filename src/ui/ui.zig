//! Immediate Mode UI System

const std = @import("std");
const math = @import("../math/math.zig");
const render = @import("../render/render.zig");

pub const widgets = @import("widgets.zig");
pub const layout = @import("layout.zig");

/// UI Context for immediate mode rendering
pub const Context = struct {
    allocator: std.mem.Allocator,
    renderer: *render.Renderer,
    mouse_x: i32,
    mouse_y: i32,
    mouse_down: bool,
    mouse_clicked: bool,
    hot_id: ?u64,
    active_id: ?u64,
    current_z: f32,
    style: Style,

    pub fn init(allocator: std.mem.Allocator, renderer: *render.Renderer) Context {
        return .{
            .allocator = allocator,
            .renderer = renderer,
            .mouse_x = 0,
            .mouse_y = 0,
            .mouse_down = false,
            .mouse_clicked = false,
            .hot_id = null,
            .active_id = null,
            .current_z = 0,
            .style = Style.default(),
        };
    }

    pub fn beginFrame(self: *Context, mx: i32, my: i32, down: bool) void {
        self.mouse_clicked = down and !self.mouse_down;
        self.mouse_x = mx;
        self.mouse_y = my;
        self.mouse_down = down;
        self.hot_id = null;
    }

    pub fn endFrame(self: *Context) void {
        if (!self.mouse_down) {
            self.active_id = null;
        }
    }

    fn isHot(self: *Context, id: u64) bool {
        return self.hot_id == id;
    }

    fn isActive(self: *Context, id: u64) bool {
        return self.active_id == id;
    }

    fn setHot(self: *Context, id: u64) void {
        if (self.active_id == null) {
            self.hot_id = id;
        }
    }

    fn setActive(self: *Context, id: u64) void {
        self.active_id = id;
    }

    fn inRect(self: *Context, x: i32, y: i32, w: i32, h: i32) bool {
        return self.mouse_x >= x and self.mouse_x < x + w and
            self.mouse_y >= y and self.mouse_y < y + h;
    }

    /// Draw a button, returns true if clicked
    pub fn button(self: *Context, id: u64, x: i32, y: i32, w: i32, h: i32, text: []const u8) bool {
        _ = text;
        const hover = self.inRect(x, y, w, h);
        if (hover) self.setHot(id);

        if (self.isActive(id)) {
            if (!self.mouse_down) {
                if (hover) return true;
            }
        } else if (hover and self.mouse_clicked) {
            self.setActive(id);
        }

        // Render button
        const color = if (self.isActive(id))
            self.style.button_active
        else if (self.isHot(id))
            self.style.button_hot
        else
            self.style.button_normal;

        self.drawRect(x, y, w, h, color);
        return false;
    }

    /// Draw a slider, returns new value
    pub fn slider(self: *Context, id: u64, x: i32, y: i32, w: i32, h: i32, value: f32, min_val: f32, max_val: f32) f32 {
        const hover = self.inRect(x, y, w, h);
        if (hover) self.setHot(id);

        var new_value = value;

        if (self.isActive(id)) {
            const ratio = std.math.clamp(
                @as(f32, @floatFromInt(self.mouse_x - x)) / @as(f32, @floatFromInt(w)),
                0,
                1,
            );
            new_value = min_val + ratio * (max_val - min_val);
        } else if (hover and self.mouse_clicked) {
            self.setActive(id);
        }

        // Render slider
        self.drawRect(x, y, w, h, self.style.slider_bg);
        const fill_w: i32 = @intFromFloat(@as(f32, @floatFromInt(w)) * (value - min_val) / (max_val - min_val));
        self.drawRect(x, y, fill_w, h, self.style.slider_fill);

        return new_value;
    }

    /// Draw a checkbox, returns new state
    pub fn checkbox(self: *Context, id: u64, x: i32, y: i32, checked: bool) bool {
        const size: i32 = 20;
        const hover = self.inRect(x, y, size, size);
        if (hover) self.setHot(id);

        var new_state = checked;

        if (hover and self.mouse_clicked) {
            new_state = !checked;
        }

        // Render checkbox
        self.drawRect(x, y, size, size, self.style.button_normal);
        if (checked) {
            self.drawRect(x + 4, y + 4, size - 8, size - 8, self.style.accent);
        }

        return new_state;
    }

    /// Draw text
    pub fn label(self: *Context, x: i32, y: i32, text: []const u8) void {
        _ = text;
        _ = y;
        _ = x;
        _ = self;
        // Text rendering would go here
    }

    fn drawRect(self: *Context, x: i32, y: i32, w: i32, h: i32, color: render.Color) void {
        var py: i32 = y;
        while (py < y + h) : (py += 1) {
            var px: i32 = x;
            while (px < x + w) : (px += 1) {
                self.renderer.drawPixel(px, py, self.current_z, color);
            }
        }
    }
};

/// UI Style configuration
pub const Style = struct {
    background: render.Color,
    foreground: render.Color,
    accent: render.Color,
    button_normal: render.Color,
    button_hot: render.Color,
    button_active: render.Color,
    slider_bg: render.Color,
    slider_fill: render.Color,
    text_color: render.Color,
    font_size: u32,

    pub fn default() Style {
        return .{
            .background = render.Color.fromRgb(30, 30, 40),
            .foreground = render.Color.fromRgb(50, 50, 65),
            .accent = render.Color.fromRgb(80, 140, 220),
            .button_normal = render.Color.fromRgb(60, 60, 80),
            .button_hot = render.Color.fromRgb(80, 80, 100),
            .button_active = render.Color.fromRgb(100, 100, 130),
            .slider_bg = render.Color.fromRgb(40, 40, 55),
            .slider_fill = render.Color.fromRgb(80, 140, 220),
            .text_color = render.Color.WHITE,
            .font_size = 14,
        };
    }

    pub fn dark() Style {
        return default();
    }

    pub fn light() Style {
        var s = default();
        s.background = render.Color.fromRgb(240, 240, 245);
        s.foreground = render.Color.fromRgb(220, 220, 230);
        s.text_color = render.Color.fromRgb(30, 30, 40);
        return s;
    }
};
