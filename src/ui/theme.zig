//! UI Theming System
//!
//! Provides configurable color themes for the UI system.
//! Includes predefined themes for game HUD, editor, and menus.

const std = @import("std");
const render = @import("../render/render.zig");

/// Complete UI color theme
pub const Theme = struct {
    // Base colors
    background: render.Color,
    background_alt: render.Color,
    foreground: render.Color,
    border: render.Color,

    // Text colors
    text_primary: render.Color,
    text_secondary: render.Color,
    text_disabled: render.Color,
    text_highlight: render.Color,

    // Accent colors
    accent: render.Color,
    accent_hover: render.Color,
    accent_pressed: render.Color,

    // Semantic colors
    success: render.Color,
    warning: render.Color,
    error_color: render.Color,
    info: render.Color,

    // Widget-specific
    button_normal: render.Color,
    button_hover: render.Color,
    button_pressed: render.Color,
    button_disabled: render.Color,

    slider_track: render.Color,
    slider_fill: render.Color,
    slider_thumb: render.Color,

    input_background: render.Color,
    input_border: render.Color,
    input_focus: render.Color,

    panel_header: render.Color,
    panel_body: render.Color,

    // Game-specific
    health_bar: render.Color,
    health_bar_low: render.Color,
    stamina_bar: render.Color,
    mana_bar: render.Color,
    xp_bar: render.Color,

    hotbar_selected: render.Color,
    hotbar_normal: render.Color,

    crosshair: render.Color,

    /// Get interpolated color between two theme colors
    pub fn lerp(self: *const Theme, other: *const Theme, t: f32) Theme {
        return Theme{
            .background = lerpColor(self.background, other.background, t),
            .background_alt = lerpColor(self.background_alt, other.background_alt, t),
            .foreground = lerpColor(self.foreground, other.foreground, t),
            .border = lerpColor(self.border, other.border, t),
            .text_primary = lerpColor(self.text_primary, other.text_primary, t),
            .text_secondary = lerpColor(self.text_secondary, other.text_secondary, t),
            .text_disabled = lerpColor(self.text_disabled, other.text_disabled, t),
            .text_highlight = lerpColor(self.text_highlight, other.text_highlight, t),
            .accent = lerpColor(self.accent, other.accent, t),
            .accent_hover = lerpColor(self.accent_hover, other.accent_hover, t),
            .accent_pressed = lerpColor(self.accent_pressed, other.accent_pressed, t),
            .success = lerpColor(self.success, other.success, t),
            .warning = lerpColor(self.warning, other.warning, t),
            .error_color = lerpColor(self.error_color, other.error_color, t),
            .info = lerpColor(self.info, other.info, t),
            .button_normal = lerpColor(self.button_normal, other.button_normal, t),
            .button_hover = lerpColor(self.button_hover, other.button_hover, t),
            .button_pressed = lerpColor(self.button_pressed, other.button_pressed, t),
            .button_disabled = lerpColor(self.button_disabled, other.button_disabled, t),
            .slider_track = lerpColor(self.slider_track, other.slider_track, t),
            .slider_fill = lerpColor(self.slider_fill, other.slider_fill, t),
            .slider_thumb = lerpColor(self.slider_thumb, other.slider_thumb, t),
            .input_background = lerpColor(self.input_background, other.input_background, t),
            .input_border = lerpColor(self.input_border, other.input_border, t),
            .input_focus = lerpColor(self.input_focus, other.input_focus, t),
            .panel_header = lerpColor(self.panel_header, other.panel_header, t),
            .panel_body = lerpColor(self.panel_body, other.panel_body, t),
            .health_bar = lerpColor(self.health_bar, other.health_bar, t),
            .health_bar_low = lerpColor(self.health_bar_low, other.health_bar_low, t),
            .stamina_bar = lerpColor(self.stamina_bar, other.stamina_bar, t),
            .mana_bar = lerpColor(self.mana_bar, other.mana_bar, t),
            .xp_bar = lerpColor(self.xp_bar, other.xp_bar, t),
            .hotbar_selected = lerpColor(self.hotbar_selected, other.hotbar_selected, t),
            .hotbar_normal = lerpColor(self.hotbar_normal, other.hotbar_normal, t),
            .crosshair = lerpColor(self.crosshair, other.crosshair, t),
        };
    }
};

/// Linear interpolation between two colors
fn lerpColor(a: render.Color, b: render.Color, t: f32) render.Color {
    const t_clamped = std.math.clamp(t, 0, 1);
    const inv_t = 1.0 - t_clamped;
    return render.Color{
        .r = @intFromFloat(@as(f32, @floatFromInt(a.r)) * inv_t + @as(f32, @floatFromInt(b.r)) * t_clamped),
        .g = @intFromFloat(@as(f32, @floatFromInt(a.g)) * inv_t + @as(f32, @floatFromInt(b.g)) * t_clamped),
        .b = @intFromFloat(@as(f32, @floatFromInt(a.b)) * inv_t + @as(f32, @floatFromInt(b.b)) * t_clamped),
        .a = @intFromFloat(@as(f32, @floatFromInt(a.a)) * inv_t + @as(f32, @floatFromInt(b.a)) * t_clamped),
    };
}

// ============================================================================
// Predefined Themes
// ============================================================================

/// Dark theme - default for game and editor
pub const dark = Theme{
    .background = render.Color.fromRgba(25, 25, 30, 240),
    .background_alt = render.Color.fromRgba(35, 35, 42, 240),
    .foreground = render.Color.fromRgba(50, 50, 60, 255),
    .border = render.Color.fromRgba(70, 70, 85, 255),

    .text_primary = render.Color.fromRgb(240, 240, 245),
    .text_secondary = render.Color.fromRgb(160, 160, 175),
    .text_disabled = render.Color.fromRgb(100, 100, 115),
    .text_highlight = render.Color.fromRgb(100, 180, 255),

    .accent = render.Color.fromRgb(80, 140, 220),
    .accent_hover = render.Color.fromRgb(100, 160, 240),
    .accent_pressed = render.Color.fromRgb(60, 120, 200),

    .success = render.Color.fromRgb(80, 200, 120),
    .warning = render.Color.fromRgb(240, 180, 60),
    .error_color = render.Color.fromRgb(220, 80, 80),
    .info = render.Color.fromRgb(80, 180, 220),

    .button_normal = render.Color.fromRgba(60, 60, 75, 255),
    .button_hover = render.Color.fromRgba(75, 75, 95, 255),
    .button_pressed = render.Color.fromRgba(50, 50, 65, 255),
    .button_disabled = render.Color.fromRgba(45, 45, 55, 180),

    .slider_track = render.Color.fromRgba(40, 40, 50, 255),
    .slider_fill = render.Color.fromRgb(80, 140, 220),
    .slider_thumb = render.Color.fromRgb(200, 200, 210),

    .input_background = render.Color.fromRgba(20, 20, 25, 255),
    .input_border = render.Color.fromRgba(60, 60, 75, 255),
    .input_focus = render.Color.fromRgb(80, 140, 220),

    .panel_header = render.Color.fromRgba(45, 45, 55, 255),
    .panel_body = render.Color.fromRgba(30, 30, 38, 245),

    .health_bar = render.Color.fromRgb(220, 60, 60),
    .health_bar_low = render.Color.fromRgb(180, 40, 40),
    .stamina_bar = render.Color.fromRgb(60, 180, 60),
    .mana_bar = render.Color.fromRgb(80, 120, 220),
    .xp_bar = render.Color.fromRgb(200, 180, 60),

    .hotbar_selected = render.Color.fromRgba(100, 100, 120, 220),
    .hotbar_normal = render.Color.fromRgba(50, 50, 60, 180),

    .crosshair = render.Color.fromRgba(255, 255, 255, 200),
};

/// Light theme - alternative for accessibility
pub const light = Theme{
    .background = render.Color.fromRgba(240, 240, 245, 250),
    .background_alt = render.Color.fromRgba(230, 230, 238, 250),
    .foreground = render.Color.fromRgba(220, 220, 230, 255),
    .border = render.Color.fromRgba(180, 180, 195, 255),

    .text_primary = render.Color.fromRgb(30, 30, 40),
    .text_secondary = render.Color.fromRgb(80, 80, 100),
    .text_disabled = render.Color.fromRgb(140, 140, 160),
    .text_highlight = render.Color.fromRgb(40, 100, 180),

    .accent = render.Color.fromRgb(60, 120, 200),
    .accent_hover = render.Color.fromRgb(80, 140, 220),
    .accent_pressed = render.Color.fromRgb(40, 100, 180),

    .success = render.Color.fromRgb(60, 160, 100),
    .warning = render.Color.fromRgb(200, 140, 40),
    .error_color = render.Color.fromRgb(200, 60, 60),
    .info = render.Color.fromRgb(60, 140, 200),

    .button_normal = render.Color.fromRgba(210, 210, 220, 255),
    .button_hover = render.Color.fromRgba(195, 195, 210, 255),
    .button_pressed = render.Color.fromRgba(180, 180, 195, 255),
    .button_disabled = render.Color.fromRgba(220, 220, 230, 180),

    .slider_track = render.Color.fromRgba(200, 200, 215, 255),
    .slider_fill = render.Color.fromRgb(60, 120, 200),
    .slider_thumb = render.Color.fromRgb(80, 80, 100),

    .input_background = render.Color.fromRgba(255, 255, 255, 255),
    .input_border = render.Color.fromRgba(180, 180, 195, 255),
    .input_focus = render.Color.fromRgb(60, 120, 200),

    .panel_header = render.Color.fromRgba(200, 200, 215, 255),
    .panel_body = render.Color.fromRgba(235, 235, 242, 250),

    .health_bar = render.Color.fromRgb(200, 50, 50),
    .health_bar_low = render.Color.fromRgb(160, 30, 30),
    .stamina_bar = render.Color.fromRgb(50, 160, 50),
    .mana_bar = render.Color.fromRgb(60, 100, 200),
    .xp_bar = render.Color.fromRgb(180, 160, 40),

    .hotbar_selected = render.Color.fromRgba(160, 160, 180, 230),
    .hotbar_normal = render.Color.fromRgba(200, 200, 215, 200),

    .crosshair = render.Color.fromRgba(40, 40, 50, 220),
};

/// Game HUD theme - optimized for in-game visibility
pub const game_hud = Theme{
    .background = render.Color.fromRgba(0, 0, 0, 150),
    .background_alt = render.Color.fromRgba(20, 20, 25, 180),
    .foreground = render.Color.fromRgba(40, 40, 50, 200),
    .border = render.Color.fromRgba(80, 80, 100, 180),

    .text_primary = render.Color.fromRgba(255, 255, 255, 255),
    .text_secondary = render.Color.fromRgba(200, 200, 210, 220),
    .text_disabled = render.Color.fromRgba(150, 150, 165, 180),
    .text_highlight = render.Color.fromRgb(255, 220, 80),

    .accent = render.Color.fromRgb(255, 200, 60),
    .accent_hover = render.Color.fromRgb(255, 220, 100),
    .accent_pressed = render.Color.fromRgb(220, 170, 40),

    .success = render.Color.fromRgb(100, 255, 140),
    .warning = render.Color.fromRgb(255, 200, 80),
    .error_color = render.Color.fromRgb(255, 100, 100),
    .info = render.Color.fromRgb(100, 200, 255),

    .button_normal = render.Color.fromRgba(60, 60, 80, 200),
    .button_hover = render.Color.fromRgba(80, 80, 110, 220),
    .button_pressed = render.Color.fromRgba(50, 50, 70, 200),
    .button_disabled = render.Color.fromRgba(40, 40, 55, 150),

    .slider_track = render.Color.fromRgba(30, 30, 40, 200),
    .slider_fill = render.Color.fromRgba(255, 200, 60, 255),
    .slider_thumb = render.Color.fromRgba(255, 255, 255, 255),

    .input_background = render.Color.fromRgba(15, 15, 20, 220),
    .input_border = render.Color.fromRgba(80, 80, 100, 180),
    .input_focus = render.Color.fromRgb(255, 200, 60),

    .panel_header = render.Color.fromRgba(40, 40, 55, 220),
    .panel_body = render.Color.fromRgba(25, 25, 35, 200),

    .health_bar = render.Color.fromRgb(255, 80, 80),
    .health_bar_low = render.Color.fromRgb(255, 50, 50),
    .stamina_bar = render.Color.fromRgb(80, 220, 100),
    .mana_bar = render.Color.fromRgb(100, 150, 255),
    .xp_bar = render.Color.fromRgb(255, 220, 80),

    .hotbar_selected = render.Color.fromRgba(255, 200, 60, 200),
    .hotbar_normal = render.Color.fromRgba(40, 40, 55, 180),

    .crosshair = render.Color.fromRgba(255, 255, 255, 230),
};

/// Editor theme - professional look for content creation
pub const editor = Theme{
    .background = render.Color.fromRgba(35, 38, 45, 255),
    .background_alt = render.Color.fromRgba(42, 46, 54, 255),
    .foreground = render.Color.fromRgba(55, 60, 72, 255),
    .border = render.Color.fromRgba(75, 80, 95, 255),

    .text_primary = render.Color.fromRgb(220, 225, 235),
    .text_secondary = render.Color.fromRgb(150, 155, 170),
    .text_disabled = render.Color.fromRgb(95, 100, 115),
    .text_highlight = render.Color.fromRgb(130, 190, 255),

    .accent = render.Color.fromRgb(70, 150, 255),
    .accent_hover = render.Color.fromRgb(95, 170, 255),
    .accent_pressed = render.Color.fromRgb(50, 130, 235),

    .success = render.Color.fromRgb(95, 210, 130),
    .warning = render.Color.fromRgb(245, 190, 70),
    .error_color = render.Color.fromRgb(235, 95, 95),
    .info = render.Color.fromRgb(95, 190, 235),

    .button_normal = render.Color.fromRgba(55, 60, 72, 255),
    .button_hover = render.Color.fromRgba(65, 72, 88, 255),
    .button_pressed = render.Color.fromRgba(48, 52, 62, 255),
    .button_disabled = render.Color.fromRgba(50, 54, 64, 180),

    .slider_track = render.Color.fromRgba(45, 50, 60, 255),
    .slider_fill = render.Color.fromRgb(70, 150, 255),
    .slider_thumb = render.Color.fromRgb(190, 195, 210),

    .input_background = render.Color.fromRgba(28, 30, 38, 255),
    .input_border = render.Color.fromRgba(65, 70, 85, 255),
    .input_focus = render.Color.fromRgb(70, 150, 255),

    .panel_header = render.Color.fromRgba(48, 52, 62, 255),
    .panel_body = render.Color.fromRgba(38, 42, 50, 255),

    .health_bar = render.Color.fromRgb(235, 75, 75),
    .health_bar_low = render.Color.fromRgb(200, 50, 50),
    .stamina_bar = render.Color.fromRgb(75, 195, 95),
    .mana_bar = render.Color.fromRgb(90, 135, 235),
    .xp_bar = render.Color.fromRgb(215, 195, 75),

    .hotbar_selected = render.Color.fromRgba(90, 95, 115, 230),
    .hotbar_normal = render.Color.fromRgba(55, 60, 72, 200),

    .crosshair = render.Color.fromRgba(220, 225, 235, 220),
};

// ============================================================================
// Theme Manager
// ============================================================================

/// Currently active theme
pub var current: *const Theme = &dark;

/// Set the active theme
pub fn setTheme(theme: *const Theme) void {
    current = theme;
}

/// Get the active theme
pub fn getTheme() *const Theme {
    return current;
}

// ============================================================================
// Tests
// ============================================================================

test "theme lerp" {
    const mid = dark.lerp(&light, 0.5);
    // Middle should be between dark and light
    try std.testing.expect(mid.background.r > dark.background.r);
    try std.testing.expect(mid.background.r < light.background.r);
}

test "color lerp" {
    const a = render.Color.fromRgb(0, 0, 0);
    const b = render.Color.fromRgb(100, 100, 100);
    const mid = lerpColor(a, b, 0.5);
    try std.testing.expectEqual(@as(u8, 50), mid.r);
    try std.testing.expectEqual(@as(u8, 50), mid.g);
    try std.testing.expectEqual(@as(u8, 50), mid.b);
}
