//! Immediate Mode UI System
//!
//! Modern UI system with rounded corners, shadows, and smooth styling.

const std = @import("std");
const math = @import("../math/math.zig");
const render = @import("../render/render.zig");
const text_module = @import("text.zig");
const theme_module = @import("theme.zig");
const icons = @import("icons.zig");

pub const widgets = @import("widgets.zig");
pub const layout = @import("layout.zig");
pub const save_menu = @import("save_menu.zig");
pub const theme = theme_module;
pub const text = text_module;
pub const Icons = icons;

// Re-export save menu types
pub const SaveMenu = save_menu.SaveMenu;
pub const SaveMenuState = save_menu.SaveMenuState;

// =============================================================================
// Button Styles
// =============================================================================

/// Button style variants
pub const ButtonStyle = enum {
    /// Primary filled button with accent color
    primary,
    /// Secondary outlined button
    secondary,
    /// Ghost button (transparent background)
    ghost,
    /// Danger button (red)
    danger,
    /// Icon-only button (square)
    icon,
};

// =============================================================================
// UI Context
// =============================================================================

/// UI Context for immediate mode rendering
pub const Context = struct {
    allocator: std.mem.Allocator,
    renderer: *render.Renderer,
    mouse_x: i32,
    mouse_y: i32,
    mouse_down: bool,
    mouse_clicked: bool,
    mouse_released: bool,
    hot_id: ?u64,
    active_id: ?u64,
    current_z: f32,
    style: Style,
    current_theme: *const theme_module.Theme,

    pub fn init(allocator: std.mem.Allocator, renderer: *render.Renderer) Context {
        return .{
            .allocator = allocator,
            .renderer = renderer,
            .mouse_x = 0,
            .mouse_y = 0,
            .mouse_down = false,
            .mouse_clicked = false,
            .mouse_released = false,
            .hot_id = null,
            .active_id = null,
            .current_z = 0,
            .style = Style.default(),
            .current_theme = theme_module.getTheme(),
        };
    }

    pub fn beginFrame(self: *Context, mx: i32, my: i32, down: bool) void {
        self.mouse_clicked = down and !self.mouse_down;
        self.mouse_released = !down and self.mouse_down;
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

    pub fn isHot(self: *Context, id: u64) bool {
        return self.hot_id == id;
    }

    pub fn isActive(self: *Context, id: u64) bool {
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

    pub fn inRect(self: *Context, x: i32, y: i32, w: i32, h: i32) bool {
        return self.mouse_x >= x and self.mouse_x < x + w and
            self.mouse_y >= y and self.mouse_y < y + h;
    }

    // =========================================================================
    // Core Drawing Functions
    // =========================================================================

    /// Draw a filled rectangle
    pub fn drawRect(self: *Context, x: i32, y: i32, w: i32, h: i32, color: render.Color) void {
        var py: i32 = y;
        while (py < y + h) : (py += 1) {
            var px: i32 = x;
            while (px < x + w) : (px += 1) {
                self.renderer.drawPixel(px, py, self.current_z, color);
            }
        }
    }

    /// Draw a rectangle outline
    pub fn drawRectOutline(self: *Context, x: i32, y: i32, w: i32, h: i32, color: render.Color) void {
        // Top and bottom
        var px: i32 = x;
        while (px < x + w) : (px += 1) {
            self.renderer.drawPixel(px, y, self.current_z, color);
            self.renderer.drawPixel(px, y + h - 1, self.current_z, color);
        }
        // Left and right
        var py: i32 = y;
        while (py < y + h) : (py += 1) {
            self.renderer.drawPixel(x, py, self.current_z, color);
            self.renderer.drawPixel(x + w - 1, py, self.current_z, color);
        }
    }

    /// Draw a rounded rectangle (simulated with corner cutoffs)
    pub fn drawRoundedRect(self: *Context, x: i32, y: i32, w: i32, h: i32, radius: u32, color: render.Color) void {
        const r_casted: i32 = @intCast(radius);
        const r: i32 = @min(r_casted, @divFloor(w, 2), @divFloor(h, 2));

        // Main body (excluding corners)
        var py: i32 = y + r;
        while (py < y + h - r) : (py += 1) {
            var px: i32 = x;
            while (px < x + w) : (px += 1) {
                self.renderer.drawPixel(px, py, self.current_z, color);
            }
        }

        // Top and bottom strips (between corners)
        py = y;
        while (py < y + r) : (py += 1) {
            var px: i32 = x + r;
            while (px < x + w - r) : (px += 1) {
                self.renderer.drawPixel(px, py, self.current_z, color);
            }
        }
        py = y + h - r;
        while (py < y + h) : (py += 1) {
            var px: i32 = x + r;
            while (px < x + w - r) : (px += 1) {
                self.renderer.drawPixel(px, py, self.current_z, color);
            }
        }

        // Draw rounded corners
        self.drawCorner(x + r, y + r, r, .top_left, color);
        self.drawCorner(x + w - r - 1, y + r, r, .top_right, color);
        self.drawCorner(x + r, y + h - r - 1, r, .bottom_left, color);
        self.drawCorner(x + w - r - 1, y + h - r - 1, r, .bottom_right, color);
    }

    const CornerPosition = enum { top_left, top_right, bottom_left, bottom_right };

    fn drawCorner(self: *Context, cx: i32, cy: i32, radius: i32, corner: CornerPosition, color: render.Color) void {
        const r_sq = radius * radius;
        var dy: i32 = 0;
        while (dy <= radius) : (dy += 1) {
            var dx: i32 = 0;
            while (dx <= radius) : (dx += 1) {
                if (dx * dx + dy * dy <= r_sq) {
                    const px = switch (corner) {
                        .top_left => cx - dx,
                        .top_right => cx + dx,
                        .bottom_left => cx - dx,
                        .bottom_right => cx + dx,
                    };
                    const py = switch (corner) {
                        .top_left => cy - dy,
                        .top_right => cy - dy,
                        .bottom_left => cy + dy,
                        .bottom_right => cy + dy,
                    };
                    self.renderer.drawPixel(px, py, self.current_z, color);
                }
            }
        }
    }

    /// Draw a drop shadow under a rectangle
    pub fn drawShadow(self: *Context, x: i32, y: i32, w: i32, h: i32, offset: i32, blur: i32) void {
        const shadow_color = self.current_theme.shadow;
        const base_alpha = shadow_color.a;

        // Draw multiple layers for blur effect
        var layer: i32 = blur;
        while (layer >= 0) : (layer -= 1) {
            const alpha_factor = @as(f32, @floatFromInt(blur - layer + 1)) / @as(f32, @floatFromInt(blur + 1));
            const layer_alpha: u8 = @intFromFloat(@as(f32, @floatFromInt(base_alpha)) * alpha_factor * 0.5);
            const layer_color = render.Color{
                .r = shadow_color.r,
                .g = shadow_color.g,
                .b = shadow_color.b,
                .a = layer_alpha,
            };

            const ox = x + offset + layer;
            const oy = y + offset + layer;
            self.drawRect(ox, oy, w, h, layer_color);
        }
    }

    /// Draw an icon
    pub fn drawIcon(self: *Context, icon: *const icons.Icon, x: i32, y: i32, scale: i32, color: render.Color) void {
        icon.draw(self.renderer, x, y, scale, color);
    }

    // =========================================================================
    // Widget: Button (Modern with variants)
    // =========================================================================

    /// Draw a styled button, returns true if clicked
    pub fn button(self: *Context, id: u64, x: i32, y: i32, w: i32, h: i32, label_text: []const u8) bool {
        return self.styledButton(id, x, y, w, h, label_text, .primary, true);
    }

    /// Draw a button with specific style
    pub fn styledButton(
        self: *Context,
        id: u64,
        x: i32,
        y: i32,
        w: i32,
        h: i32,
        label_text: []const u8,
        btn_style: ButtonStyle,
        enabled: bool,
    ) bool {
        const hover = self.inRect(x, y, w, h) and enabled;
        if (hover) self.setHot(id);

        var clicked = false;
        if (enabled) {
            if (self.isActive(id)) {
                if (!self.mouse_down) {
                    if (hover) clicked = true;
                }
            } else if (hover and self.mouse_clicked) {
                self.setActive(id);
            }
        }

        const sizing = &theme_module.sizing;
        const radius = sizing.border_radius;

        // Determine colors based on style and state
        var bg_color: render.Color = undefined;
        var text_color: render.Color = undefined;
        var border_color: ?render.Color = null;

        if (!enabled) {
            bg_color = self.current_theme.button_disabled;
            text_color = self.current_theme.text_disabled;
        } else if (self.isActive(id)) {
            switch (btn_style) {
                .primary => {
                    bg_color = self.current_theme.accent_pressed;
                    text_color = render.Color.WHITE;
                },
                .secondary => {
                    bg_color = theme_module.Theme.withAlpha(self.current_theme.accent, 40);
                    text_color = self.current_theme.accent;
                    border_color = self.current_theme.accent_pressed;
                },
                .ghost => {
                    bg_color = theme_module.Theme.withAlpha(self.current_theme.text_primary, 20);
                    text_color = self.current_theme.text_primary;
                },
                .danger => {
                    bg_color = theme_module.Theme.darken(self.current_theme.error_color, 0.2);
                    text_color = render.Color.WHITE;
                },
                .icon => {
                    bg_color = self.current_theme.button_pressed;
                    text_color = self.current_theme.text_primary;
                },
            }
        } else if (self.isHot(id)) {
            switch (btn_style) {
                .primary => {
                    bg_color = self.current_theme.accent_hover;
                    text_color = render.Color.WHITE;
                },
                .secondary => {
                    bg_color = theme_module.Theme.withAlpha(self.current_theme.accent, 20);
                    text_color = self.current_theme.accent;
                    border_color = self.current_theme.accent_hover;
                },
                .ghost => {
                    bg_color = self.current_theme.hover_overlay;
                    text_color = self.current_theme.text_primary;
                },
                .danger => {
                    bg_color = theme_module.Theme.lighten(self.current_theme.error_color, 0.1);
                    text_color = render.Color.WHITE;
                },
                .icon => {
                    bg_color = self.current_theme.button_hover;
                    text_color = self.current_theme.text_primary;
                },
            }
        } else {
            switch (btn_style) {
                .primary => {
                    bg_color = self.current_theme.accent;
                    text_color = render.Color.WHITE;
                },
                .secondary => {
                    bg_color = render.Color.fromRgba(0, 0, 0, 0);
                    text_color = self.current_theme.accent;
                    border_color = self.current_theme.accent;
                },
                .ghost => {
                    bg_color = render.Color.fromRgba(0, 0, 0, 0);
                    text_color = self.current_theme.text_primary;
                },
                .danger => {
                    bg_color = self.current_theme.error_color;
                    text_color = render.Color.WHITE;
                },
                .icon => {
                    bg_color = self.current_theme.button_normal;
                    text_color = self.current_theme.text_primary;
                },
            }
        }

        // Draw shadow for primary/danger buttons
        if (enabled and (btn_style == .primary or btn_style == .danger)) {
            self.drawShadow(x, y, w, h, 1, 2);
        }

        // Draw button background
        self.drawRoundedRect(x, y, w, h, radius, bg_color);

        // Draw border for secondary style
        if (border_color) |bc| {
            self.drawRoundedRectOutline(x, y, w, h, radius, bc);
        }

        // Draw centered text
        const size = text_module.measureText(&text_module.default_font, label_text, 1);
        const text_x = x + @divFloor(w - size.width, 2);
        const text_y = y + @divFloor(h - size.height, 2);
        text_module.drawText(self.renderer, &text_module.default_font, label_text, text_x, text_y, .{
            .color = text_color,
        });

        return clicked;
    }

    /// Draw an icon button
    pub fn iconButton(self: *Context, id: u64, x: i32, y: i32, size: i32, icon: *const icons.Icon, enabled: bool) bool {
        const hover = self.inRect(x, y, size, size) and enabled;
        if (hover) self.setHot(id);

        var clicked = false;
        if (enabled) {
            if (self.isActive(id)) {
                if (!self.mouse_down and hover) clicked = true;
            } else if (hover and self.mouse_clicked) {
                self.setActive(id);
            }
        }

        const radius = theme_module.sizing.border_radius;

        // Determine colors
        var bg_color: render.Color = undefined;
        var icon_color: render.Color = undefined;

        if (!enabled) {
            bg_color = self.current_theme.button_disabled;
            icon_color = self.current_theme.text_disabled;
        } else if (self.isActive(id)) {
            bg_color = self.current_theme.button_pressed;
            icon_color = self.current_theme.text_primary;
        } else if (self.isHot(id)) {
            bg_color = self.current_theme.button_hover;
            icon_color = self.current_theme.text_primary;
        } else {
            bg_color = self.current_theme.button_normal;
            icon_color = self.current_theme.text_secondary;
        }

        self.drawRoundedRect(x, y, size, size, radius, bg_color);

        // Center icon
        const icon_size: i32 = 8;
        const icon_x = x + @divFloor(size - icon_size, 2);
        const icon_y = y + @divFloor(size - icon_size, 2);
        self.drawIcon(icon, icon_x, icon_y, 1, icon_color);

        return clicked;
    }

    fn drawRoundedRectOutline(self: *Context, x: i32, y: i32, w: i32, h: i32, radius: u32, color: render.Color) void {
        const r_casted: i32 = @intCast(radius);
        const r: i32 = @min(r_casted, @divFloor(w, 2), @divFloor(h, 2));

        // Top and bottom edges
        var px: i32 = x + r;
        while (px < x + w - r) : (px += 1) {
            self.renderer.drawPixel(px, y, self.current_z, color);
            self.renderer.drawPixel(px, y + h - 1, self.current_z, color);
        }

        // Left and right edges
        var py: i32 = y + r;
        while (py < y + h - r) : (py += 1) {
            self.renderer.drawPixel(x, py, self.current_z, color);
            self.renderer.drawPixel(x + w - 1, py, self.current_z, color);
        }

        // Corner arcs (simplified)
        self.drawCornerArc(x + r, y + r, r, .top_left, color);
        self.drawCornerArc(x + w - r - 1, y + r, r, .top_right, color);
        self.drawCornerArc(x + r, y + h - r - 1, r, .bottom_left, color);
        self.drawCornerArc(x + w - r - 1, y + h - r - 1, r, .bottom_right, color);
    }

    fn drawCornerArc(self: *Context, cx: i32, cy: i32, radius: i32, corner: CornerPosition, color: render.Color) void {
        // Simple arc approximation using quarter circle points
        const r_sq = radius * radius;
        var prev_x: i32 = 0;
        var dy: i32 = 0;
        while (dy <= radius) : (dy += 1) {
            // Find x at this y level on the circle edge
            var dx: i32 = radius;
            while (dx >= 0 and dx * dx + dy * dy > r_sq) : (dx -= 1) {}

            // Draw from prev_x to dx on this row (edge pixels only)
            if (dy > 0 and dx != prev_x) {
                var draw_x = dx;
                while (draw_x <= prev_x) : (draw_x += 1) {
                    const px = switch (corner) {
                        .top_left => cx - draw_x,
                        .top_right => cx + draw_x,
                        .bottom_left => cx - draw_x,
                        .bottom_right => cx + draw_x,
                    };
                    const py = switch (corner) {
                        .top_left => cy - dy,
                        .top_right => cy - dy,
                        .bottom_left => cy + dy,
                        .bottom_right => cy + dy,
                    };
                    self.renderer.drawPixel(px, py, self.current_z, color);
                }
            } else {
                const px = switch (corner) {
                    .top_left => cx - dx,
                    .top_right => cx + dx,
                    .bottom_left => cx - dx,
                    .bottom_right => cx + dx,
                };
                const py = switch (corner) {
                    .top_left => cy - dy,
                    .top_right => cy - dy,
                    .bottom_left => cy + dy,
                    .bottom_right => cy + dy,
                };
                self.renderer.drawPixel(px, py, self.current_z, color);
            }
            prev_x = dx;
        }
    }

    // =========================================================================
    // Widget: Slider (Modern)
    // =========================================================================

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

        const radius = theme_module.sizing.border_radius;
        const track_height: i32 = 6;
        const track_y = y + @divFloor(h - track_height, 2);

        // Draw track
        self.drawRoundedRect(x, track_y, w, track_height, @intCast(@divFloor(track_height, 2)), self.current_theme.slider_track);

        // Draw fill
        const fill_ratio = (value - min_val) / (max_val - min_val);
        const fill_w: i32 = @intFromFloat(@as(f32, @floatFromInt(w)) * fill_ratio);
        if (fill_w > 0) {
            self.drawRoundedRect(x, track_y, @max(fill_w, track_height), track_height, @intCast(@divFloor(track_height, 2)), self.current_theme.slider_fill);
        }

        // Draw thumb
        const thumb_size: i32 = 14;
        const thumb_x = x + fill_w - @divFloor(thumb_size, 2);
        const thumb_y = y + @divFloor(h - thumb_size, 2);

        // Thumb shadow
        self.drawShadow(thumb_x, thumb_y, thumb_size, thumb_size, 1, 1);

        // Thumb color based on state
        var thumb_color = self.current_theme.slider_thumb;
        if (self.isActive(id)) {
            thumb_color = self.current_theme.accent;
        } else if (self.isHot(id)) {
            thumb_color = theme_module.Theme.lighten(self.current_theme.slider_thumb, 0.1);
        }

        self.drawRoundedRect(thumb_x, thumb_y, thumb_size, thumb_size, radius, thumb_color);

        return new_value;
    }

    // =========================================================================
    // Widget: Checkbox (Modern with checkmark)
    // =========================================================================

    /// Draw a checkbox, returns new state
    pub fn checkbox(self: *Context, id: u64, x: i32, y: i32, checked: bool) bool {
        const size: i32 = @intCast(theme_module.sizing.control_size);
        const hover = self.inRect(x, y, size, size);
        if (hover) self.setHot(id);

        var new_state = checked;

        if (hover and self.mouse_clicked) {
            new_state = !checked;
        }

        const radius = @min(theme_module.sizing.border_radius, @as(u32, @intCast(@divFloor(size, 3))));

        // Background
        var bg_color: render.Color = undefined;
        var border_color: render.Color = undefined;

        if (checked) {
            bg_color = self.current_theme.accent;
            border_color = self.current_theme.accent;
        } else if (self.isHot(id)) {
            bg_color = self.current_theme.input_background;
            border_color = self.current_theme.accent_hover;
        } else {
            bg_color = self.current_theme.input_background;
            border_color = self.current_theme.input_border;
        }

        self.drawRoundedRect(x, y, size, size, radius, bg_color);
        self.drawRoundedRectOutline(x, y, size, size, radius, border_color);

        // Draw checkmark
        if (checked) {
            self.drawIcon(&icons.check, x + 2, y + 2, 1, render.Color.WHITE);
        }

        return new_state;
    }

    /// Draw a checkbox with label
    pub fn checkboxLabeled(self: *Context, id: u64, x: i32, y: i32, checked: bool, label_text: []const u8) bool {
        const size: i32 = @intCast(theme_module.sizing.control_size);
        const spacing: i32 = @intCast(theme_module.sizing.spacing);

        const result = self.checkbox(id, x, y, checked);

        // Draw label
        const text_y = y + @divFloor(size - 8, 2);
        text_module.drawText(self.renderer, &text_module.default_font, label_text, x + size + spacing, text_y, .{
            .color = self.current_theme.text_primary,
        });

        return result;
    }

    // =========================================================================
    // Widget: Radio Button
    // =========================================================================

    /// Draw a radio button, returns true if selected
    pub fn radio(self: *Context, id: u64, x: i32, y: i32, selected: bool) bool {
        const size: i32 = @intCast(theme_module.sizing.control_size);
        const hover = self.inRect(x, y, size, size);
        if (hover) self.setHot(id);

        var new_selected = selected;

        if (hover and self.mouse_clicked and !selected) {
            new_selected = true;
        }

        const radius: i32 = @divFloor(size, 2);
        const cx = x + radius;
        const cy = y + radius;

        // Outer circle
        var border_color: render.Color = undefined;
        if (selected) {
            border_color = self.current_theme.accent;
        } else if (self.isHot(id)) {
            border_color = self.current_theme.accent_hover;
        } else {
            border_color = self.current_theme.input_border;
        }

        self.drawCircle(cx, cy, radius, self.current_theme.input_background);
        self.drawCircleOutline(cx, cy, radius, border_color);

        // Inner dot if selected
        if (selected) {
            const inner_radius = @max(2, @divFloor(radius, 2));
            self.drawCircle(cx, cy, inner_radius, self.current_theme.accent);
        }

        return new_selected;
    }

    /// Draw a radio button with label
    pub fn radioLabeled(self: *Context, id: u64, x: i32, y: i32, selected: bool, label_text: []const u8) bool {
        const size: i32 = @intCast(theme_module.sizing.control_size);
        const spacing: i32 = @intCast(theme_module.sizing.spacing);

        const result = self.radio(id, x, y, selected);

        // Draw label
        const text_y = y + @divFloor(size - 8, 2);
        text_module.drawText(self.renderer, &text_module.default_font, label_text, x + size + spacing, text_y, .{
            .color = self.current_theme.text_primary,
        });

        return result;
    }

    fn drawCircle(self: *Context, cx: i32, cy: i32, radius: i32, color: render.Color) void {
        const r_sq = radius * radius;
        var dy: i32 = -radius;
        while (dy <= radius) : (dy += 1) {
            var dx: i32 = -radius;
            while (dx <= radius) : (dx += 1) {
                if (dx * dx + dy * dy <= r_sq) {
                    self.renderer.drawPixel(cx + dx, cy + dy, self.current_z, color);
                }
            }
        }
    }

    fn drawCircleOutline(self: *Context, cx: i32, cy: i32, radius: i32, color: render.Color) void {
        const r_sq = radius * radius;
        const inner_sq = (radius - 1) * (radius - 1);
        var dy: i32 = -radius;
        while (dy <= radius) : (dy += 1) {
            var dx: i32 = -radius;
            while (dx <= radius) : (dx += 1) {
                const dist_sq = dx * dx + dy * dy;
                if (dist_sq <= r_sq and dist_sq >= inner_sq) {
                    self.renderer.drawPixel(cx + dx, cy + dy, self.current_z, color);
                }
            }
        }
    }

    // =========================================================================
    // Widget: Progress Bar
    // =========================================================================

    /// Draw a progress bar (0.0 to 1.0)
    pub fn progressBar(self: *Context, x: i32, y: i32, w: i32, progress: f32, color: ?render.Color) void {
        const h: i32 = @intCast(theme_module.sizing.progress_height);
        const radius: u32 = @intCast(@divFloor(h, 2));
        const fill_color = color orelse self.current_theme.accent;

        // Background
        self.drawRoundedRect(x, y, w, h, radius, self.current_theme.slider_track);

        // Fill
        const clamped = std.math.clamp(progress, 0, 1);
        const fill_w: i32 = @intFromFloat(@as(f32, @floatFromInt(w)) * clamped);
        if (fill_w > 0) {
            self.drawRoundedRect(x, y, @max(fill_w, h), h, radius, fill_color);
        }
    }

    // =========================================================================
    // Widget: Label
    // =========================================================================

    /// Draw text
    pub fn label(self: *Context, x: i32, y: i32, label_text: []const u8) void {
        text_module.drawText(self.renderer, &text_module.default_font, label_text, x, y, .{
            .color = self.current_theme.text_primary,
        });
    }

    /// Draw secondary text (muted)
    pub fn labelSecondary(self: *Context, x: i32, y: i32, label_text: []const u8) void {
        text_module.drawText(self.renderer, &text_module.default_font, label_text, x, y, .{
            .color = self.current_theme.text_secondary,
        });
    }

    // =========================================================================
    // Widget: Panel
    // =========================================================================

    /// Draw a modern panel with optional title bar
    pub fn panel(self: *Context, x: i32, y: i32, w: i32, h: i32, title: ?[]const u8) void {
        const radius = theme_module.sizing.border_radius;
        const title_height: i32 = @intCast(theme_module.sizing.title_bar_height);

        // Shadow
        self.drawShadow(x, y, w, h, 2, 3);

        if (title) |t| {
            // Title bar
            self.drawRoundedRect(x, y, w, title_height, radius, self.current_theme.panel_header);
            // Body (only round bottom corners)
            self.drawRect(x, y + title_height, w, h - title_height, self.current_theme.panel_body);
            // Bottom corners
            self.drawCorner(x + @as(i32, @intCast(radius)), y + h - @as(i32, @intCast(radius)) - 1, @intCast(radius), .bottom_left, self.current_theme.panel_body);
            self.drawCorner(x + w - @as(i32, @intCast(radius)) - 1, y + h - @as(i32, @intCast(radius)) - 1, @intCast(radius), .bottom_right, self.current_theme.panel_body);

            // Title text
            const padding: i32 = @intCast(theme_module.sizing.padding);
            text_module.drawText(self.renderer, &text_module.default_font, t, x + padding, y + @divFloor(title_height - 8, 2), .{
                .color = self.current_theme.text_primary,
            });
        } else {
            // Simple panel without title
            self.drawRoundedRect(x, y, w, h, radius, self.current_theme.panel_body);
        }

        // Border
        self.drawRoundedRectOutline(x, y, w, h, radius, self.current_theme.border);
    }

    /// Draw panel with close button, returns true if close clicked
    pub fn panelWithClose(self: *Context, id: u64, x: i32, y: i32, w: i32, h: i32, title: []const u8) bool {
        self.panel(x, y, w, h, title);

        // Close button
        const title_height: i32 = @intCast(theme_module.sizing.title_bar_height);
        const btn_size: i32 = 20;
        const btn_x = x + w - btn_size - 4;
        const btn_y = y + @divFloor(title_height - btn_size, 2);

        return self.iconButton(id, btn_x, btn_y, btn_size, &icons.close, true);
    }

    // =========================================================================
    // Widget: Separator
    // =========================================================================

    /// Draw a horizontal separator line
    pub fn separator(self: *Context, x: i32, y: i32, w: i32) void {
        self.drawRect(x, y, w, 1, self.current_theme.border);
    }

    /// Draw a vertical separator line
    pub fn separatorVertical(self: *Context, x: i32, y: i32, h: i32) void {
        self.drawRect(x, y, 1, h, self.current_theme.border);
    }

    // =========================================================================
    // Widget: Tooltip (simple)
    // =========================================================================

    /// Draw a tooltip at position
    pub fn tooltip(self: *Context, x: i32, y: i32, tooltip_text: []const u8) void {
        const size = text_module.measureText(&text_module.default_font, tooltip_text, 1);
        const padding: i32 = 6;
        const w = size.width + padding * 2;
        const h = size.height + padding * 2;

        // Shadow
        self.drawShadow(x, y, w, h, 1, 2);

        // Background
        self.drawRoundedRect(x, y, w, h, 3, self.current_theme.foreground);
        self.drawRoundedRectOutline(x, y, w, h, 3, self.current_theme.border);

        // Text
        text_module.drawText(self.renderer, &text_module.default_font, tooltip_text, x + padding, y + padding, .{
            .color = self.current_theme.text_primary,
        });
    }
};

// =============================================================================
// Legacy Style (kept for compatibility)
// =============================================================================

/// UI Style configuration (legacy - use Theme instead)
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

// =============================================================================
// Tests
// =============================================================================

test "context init" {
    // Basic test that Context can be created (renderer not actually used)
    const allocator = std.testing.allocator;
    _ = allocator;
    // Cannot test fully without a renderer, but structure is valid
}

test "button style variants" {
    try std.testing.expectEqual(ButtonStyle.primary, ButtonStyle.primary);
    try std.testing.expect(ButtonStyle.secondary != ButtonStyle.primary);
}
