//! UI Layout System

const std = @import("std");

/// Layout direction
pub const Direction = enum { horizontal, vertical };

/// Layout container
pub const Container = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    direction: Direction,
    padding: i32,
    spacing: i32,
    cursor_x: i32,
    cursor_y: i32,

    pub fn init(x: i32, y: i32, w: i32, h: i32) Container {
        return .{
            .x = x,
            .y = y,
            .width = w,
            .height = h,
            .direction = .vertical,
            .padding = 8,
            .spacing = 4,
            .cursor_x = x + 8,
            .cursor_y = y + 8,
        };
    }

    pub fn allocate(self: *Container, w: i32, h: i32) struct { x: i32, y: i32 } {
        const result = .{ .x = self.cursor_x, .y = self.cursor_y };

        switch (self.direction) {
            .horizontal => {
                self.cursor_x += w + self.spacing;
            },
            .vertical => {
                self.cursor_y += h + self.spacing;
            },
        }

        return result;
    }

    pub fn newRow(self: *Container) void {
        self.cursor_x = self.x + self.padding;
        self.cursor_y += self.spacing;
    }

    pub fn remainingWidth(self: *const Container) i32 {
        return self.width - (self.cursor_x - self.x) - self.padding;
    }

    pub fn remainingHeight(self: *const Container) i32 {
        return self.height - (self.cursor_y - self.y) - self.padding;
    }
};

/// Docking layout
pub const DockLayout = struct {
    left: ?*Container = null,
    right: ?*Container = null,
    top: ?*Container = null,
    bottom: ?*Container = null,
    center: ?*Container = null,
    left_width: i32 = 250,
    right_width: i32 = 250,
    top_height: i32 = 100,
    bottom_height: i32 = 200,
};
