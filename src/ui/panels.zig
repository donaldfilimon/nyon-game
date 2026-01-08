//! Panel Utilities - Helper functions for panel layout and docking.
//!
//! This module provides utilities for managing panel positioning, sizing,
//! and docking behavior using raygui.

const std = @import("std");
const raygui = @import("raygui");
const config = @import("../config/constants.zig");
const ui_mod = @import("ui.zig");

pub const Rectangle = raygui.Rectangle;

pub const DockPosition = enum {
    left,
    right,
    top,
    bottom,
};

pub const DockThreshold = struct {
    edge_ratio: f32 = 0.25,
    min_size: f32 = config.UI.MIN_PANEL_WIDTH,
};

const default_threshold = DockThreshold{};
const MIN_PANEL_WIDTH: f32 = config.UI.MIN_PANEL_WIDTH;
const MIN_PANEL_HEIGHT: f32 = config.UI.MIN_PANEL_HEIGHT;

pub fn clampPanelRect(rect: *Rectangle, screen_width: f32, screen_height: f32) void {
    if (rect.width > screen_width) rect.width = screen_width;
    if (rect.height > screen_height) rect.height = screen_height;

    if (rect.x < 0.0) rect.x = 0.0;
    if (rect.y < 0.0) rect.y = 0.0;

    const max_x = screen_width - rect.width;
    const max_y = screen_height - rect.height;
    if (rect.x > max_x) rect.x = max_x;
    if (rect.y > max_y) rect.y = max_y;
}

pub fn splitDockPanels(
    moving: *ui_mod.PanelConfig,
    target: *ui_mod.PanelConfig,
    position: DockPosition,
) void {
    const target_rect = target.rect;

    switch (position) {
        .left => {
            const half = @max(MIN_PANEL_WIDTH, target_rect.width / 2.0);
            moving.rect = Rectangle{
                .x = target_rect.x,
                .y = target_rect.y,
                .width = half,
                .height = target_rect.height,
            };
            target.rect.width = @max(MIN_PANEL_WIDTH, target_rect.width - half);
        },
        .right => {
            const half = @max(MIN_PANEL_WIDTH, target_rect.width / 2.0);
            moving.rect = Rectangle{
                .x = target_rect.x + target_rect.width - half,
                .y = target_rect.y,
                .width = half,
                .height = target_rect.height,
            };
            target.rect.width = @max(MIN_PANEL_WIDTH, target_rect.width - half);
        },
        .top => {
            const half = @max(MIN_PANEL_HEIGHT, target_rect.height / 2.0);
            moving.rect = Rectangle{
                .x = target_rect.x,
                .y = target_rect.y,
                .width = target_rect.width,
                .height = half,
            };
            target.rect.y = target_rect.y + half;
            target.rect.height = @max(MIN_PANEL_HEIGHT, target_rect.height - half);
        },
        .bottom => {
            const half = @max(MIN_PANEL_HEIGHT, target_rect.height / 2.0);
            moving.rect = Rectangle{
                .x = target_rect.x,
                .y = target_rect.y + target_rect.height - half,
                .width = target_rect.width,
                .height = half,
            };
            target.rect.height = @max(MIN_PANEL_HEIGHT, target_rect.height - half);
        },
    }
}

/// Detect which dock position a mouse is hovering over relative to a panel.
/// Returns null if mouse is not close enough to panel edge.
pub fn detectDockPosition(
    mouse_x: f32,
    mouse_y: f32,
    target_rect: Rectangle,
    _: DockThreshold,
) ?DockPosition {
    const tx = target_rect.x + target_rect.width / 2.0;
    const ty = target_rect.y + target_rect.height / 2.0;
    const dx = mouse_x - tx;
    const dy = mouse_y - ty;
    const adx = @abs(dx);
    const ady = @abs(dy);

    if (adx > ady) {
        if (adx > target_rect.width * 0.5) return null;
        if (dx > 0) return .right else return .left;
    } else {
        if (ady > target_rect.height * 0.5) return null;
        if (dy > 0) return .bottom else return .top;
    }
}

pub fn getActivePanelId(panel_id: ui_mod.PanelId) u64 {
    return @as(u64, @intFromEnum(panel_id)) + 1;
}

pub fn isPanelActive(active_id: u64, panel_id: ui_mod.PanelId) bool {
    return active_id == getActivePanelId(panel_id);
}

test "clampPanelRect bounds" {
    var rect = Rectangle{ .x = -10, .y = -10, .width = 100, .height = 100 };
    clampPanelRect(&rect, 800, 600);
    try std.testing.expect(rect.x >= 0);
    try std.testing.expect(rect.y >= 0);
}

test "clampPanelRect max bounds" {
    var rect = Rectangle{ .x = 1000, .y = 1000, .width = 500, .height = 500 };
    clampPanelRect(&rect, 800, 600);
    try std.testing.expect(rect.x + rect.width <= 800);
    try std.testing.expect(rect.y + rect.height <= 600);
}

test "splitDockPanels left" {
    var target = ui_mod.PanelConfig{ .rect = Rectangle{ .x = 100, .y = 100, .width = 400, .height = 300 } };
    var moving = ui_mod.PanelConfig{ .rect = undefined };
    splitDockPanels(&moving, &target, .left);

    try std.testing.expect(moving.rect.x == 100);
    try std.testing.expect(moving.rect.width >= MIN_PANEL_WIDTH);
    try std.testing.expect(target.rect.x > 100);
}

test "detectDockPosition left edge" {
    const result = detectDockPosition(110, 150, Rectangle{ .x = 100, .y = 100, .width = 400, .height = 300 }, default_threshold);
    try std.testing.expect(result == .left);
}

test "detectDockPosition center" {
    const result = detectDockPosition(250, 250, Rectangle{ .x = 100, .y = 100, .width = 400, .height = 300 }, default_threshold);
    try std.testing.expect(result == null);
}

test "detectDockPosition outside" {
    const result = detectDockPosition(50, 50, Rectangle{ .x = 100, .y = 100, .width = 400, .height = 300 }, default_threshold);
    try std.testing.expect(result == null);
}
