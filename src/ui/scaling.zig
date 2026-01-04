//! UI scaling utilities with DPI awareness.
//!
//! Provides consistent scaling across different display configurations,
//! supporting both high-DPI displays and accessibility preferences.

const std = @import("std");
const engine_mod = @import("../engine.zig");
const Color = engine_mod.Color;

const MIN_SCALE: f32 = 0.6;
const MAX_SCALE: f32 = 2.5;
const MIN_TOUCH_TARGET: f32 = 44.0;

pub const ScaleMode = enum {
    dpi,
    manual,
    accessibility,
};

pub const UiScale = struct {
    scale: f32,
    mode: ScaleMode = .dpi,
    min_touch_target: f32 = MIN_TOUCH_TARGET,

    pub fn init() UiScale {
        return UiScale{ .scale = defaultFromDpi() };
    }

    pub fn fromDpi(scale: f32) UiScale {
        const clamped = clamp(scale);
        return UiScale{ .scale = clamped, .mode = .dpi };
    }

    pub fn manual(scale: f32) UiScale {
        const clamped = clamp(scale);
        return UiScale{ .scale = clamped, .mode = .manual };
    }

    pub fn accessibility(scale: f32) UiScale {
        const clamped = clamp(scale);
        return UiScale{ .scale = clamped, .mode = .accessibility };
    }

    pub fn clamp(scale: f32) f32 {
        if (scale < MIN_SCALE) return MIN_SCALE;
        if (scale > MAX_SCALE) return MAX_SCALE;
        return scale;
    }

    pub fn apply(self: UiScale, value: f32) f32 {
        return value * self.scale;
    }

    pub fn applyInt(self: UiScale, value: i32) i32 {
        return @intFromFloat(@as(f32, @floatFromInt(value)) * self.scale);
    }

    pub fn applyPadding(self: UiScale, base_padding: i32) i32 {
        const scaled = @as(f32, @floatFromInt(base_padding)) * self.scale;
        return @intFromFloat(std.math.round(scaled));
    }

    pub fn applyFontSize(self: UiScale, base_size: i32) i32 {
        const scaled = @as(f32, @floatFromInt(base_size)) * self.scale;
        return @intFromFloat(std.math.round(scaled));
    }

    pub fn touchTarget(self: UiScale) f32 {
        return self.min_touch_target * self.scale;
    }

    pub fn toPixel(self: UiScale, normalized: f32, screen_size: f32) f32 {
        return normalized * screen_size * self.scale;
    }

    pub fn toNormalized(self: UiScale, pixel: f32, screen_size: f32) f32 {
        return pixel / (screen_size * self.scale);
    }

    pub fn scaleRounded(self: UiScale, value: f32) f32 {
        return std.math.round(value * self.scale);
    }
};

pub fn defaultFromDpi() f32 {
    const scale = engine_mod.Window.getScaleDPI();
    const avg = (scale.x + scale.y) / 2.0;
    if (avg <= 0.0) return 1.0;
    return UiScale.clamp(avg);
}

pub const DpiInfo = struct {
    scale_x: f32,
    scale_y: f32,
    raw_dpi_x: f32,
    raw_dpi_y: f32,
    is_high_dpi: bool,

    pub fn detect() DpiInfo {
        const scale = engine_mod.Window.getScaleDPI();
        const avg = (scale.x + scale.y) / 2.0;

        return DpiInfo{
            .scale_x = scale.x,
            .scale_y = scale.y,
            .raw_dpi_x = scale.x * 96.0,
            .raw_dpi_y = scale.y * 96.0,
            .is_high_dpi = avg > 1.25,
        };
    }
};

pub const ResponsiveConfig = struct {
    base_width: f32 = 1920.0,
    base_height: f32 = 1080.0,
    scale_mode: ScaleMode = .dpi,

    pub fn scaleToScreen(self: ResponsiveConfig, value: f32, screen_width: f32, screen_height: f32) f32 {
        const base_min = std.math.min(self.base_width, self.base_height);
        const screen_min = std.math.min(screen_width, screen_height);
        const ratio = screen_min / base_min;
        return value * ratio;
    }

    pub fn responsiveScale(self: ResponsiveConfig, base_scale: f32, screen_width: f32, screen_height: f32) f32 {
        const screen_scale = self.scaleToScreen(base_scale, screen_width, screen_height);
        return UiScale.clamp(screen_scale);
    }
};

test "UiScale clamping" {
    try std.testing.expectEqual(@as(f32, 0.6), UiScale.clamp(0.3));
    try std.testing.expectEqual(@as(f32, 1.0), UiScale.clamp(1.0));
    try std.testing.expectEqual(@as(f32, 2.5), UiScale.clamp(3.0));
    try std.testing.expectEqual(@as(f32, 1.5), UiScale.clamp(1.5));
}

test "UiScale apply" {
    const scale = UiScale.manual(1.5);
    try std.testing.expectEqual(@as(f32, 30.0), scale.apply(20.0));
    try std.testing.expectEqual(@as(f32, 45), scale.applyInt(30));
}

test "UiScale touch target" {
    const scale = UiScale.manual(1.0);
    try std.testing.expectEqual(@as(f32, 44.0), scale.touchTarget());

    const large_scale = UiScale.manual(2.0);
    try std.testing.expectEqual(@as(f32, 88.0), large_scale.touchTarget());
}
