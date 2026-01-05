const std = @import("std");
const raylib = @import("raylib");
const config = @import("config/constants.zig");

/// Docking UI Framework for the Nyon Game Editor
///
/// Provides a flexible docking system with panels that can be rearranged,
/// resized, and contain different types of content (property inspectors,
/// scene outliners, node editors, etc.).
pub const DockingSystem = struct {
    allocator: std.mem.Allocator,
    panels: std.ArrayList(Panel),
    drag_state: ?DragState,
    screen_width: f32,
    screen_height: f32,

    pub const PanelId = usize;

    pub const PanelType = enum {
        property_inspector,
        scene_outliner,
        node_editor,
        asset_browser,
        console,
        custom,
    };

    pub const Panel = struct {
        id: PanelId,
        panel_type: PanelType,
        title: []const u8,
        rect: raylib.Rectangle,
        is_visible: bool,
        is_docked: bool,
        dock_parent: ?PanelId,
        children: std.ArrayList(PanelId),
        content_callback: ?ContentCallback,

        pub const ContentCallback = *const fn (panel: *Panel, allocator: std.mem.Allocator) void;
    };

    pub const DragState = struct {
        panel_id: PanelId,
        drag_offset: raylib.Vector2,
        original_rect: raylib.Rectangle,
    };

    pub fn init(allocator: std.mem.Allocator, screen_width: f32, screen_height: f32) DockingSystem {
        return .{
            .allocator = allocator,
            .panels = std.ArrayList(Panel).initCapacity(allocator, 8) catch unreachable,
            .drag_state = null,
            .screen_width = screen_width,
            .screen_height = screen_height,
        };
    }

    pub fn deinit(self: *DockingSystem) void {
        for (self.panels.items) |*panel| {
            self.allocator.free(panel.title);
            panel.children.deinit(self.allocator);
        }
        self.panels.deinit(self.allocator);
    }

    /// Create a new panel
    pub fn createPanel(
        self: *DockingSystem,
        panel_type: PanelType,
        title: []const u8,
        rect: raylib.Rectangle,
        content_callback: ?Panel.ContentCallback,
    ) !PanelId {
        const id = self.panels.items.len;
        const title_copy = try self.allocator.dupe(u8, title);
        errdefer self.allocator.free(title_copy);

        try self.panels.append(self.allocator, .{
            .id = id,
            .panel_type = panel_type,
            .title = title_copy,
            .rect = rect,
            .is_visible = true,
            .is_docked = false,
            .dock_parent = null,
            .children = std.ArrayList(PanelId).initCapacity(self.allocator, 4) catch unreachable,
            .content_callback = content_callback,
        });

        return id;
    }

    /// Dock a panel to another panel
    pub fn dockPanel(self: *DockingSystem, panel_id: PanelId, parent_id: PanelId, position: DockPosition) !void {
        if (panel_id >= self.panels.items.len or parent_id >= self.panels.items.len) return error.InvalidPanelId;

        var panel = &self.panels.items[panel_id];
        var parent = &self.panels.items[parent_id];

        panel.is_docked = true;
        panel.dock_parent = parent_id;

        try parent.children.append(self.allocator, panel_id);

        // Adjust panel rectangles based on docking position
        try self.adjustDockedRectangles(parent_id, position);
    }

    pub const DockPosition = enum {
        left,
        right,
        top,
        bottom,
    };

    fn adjustDockedRectangles(self: *DockingSystem, parent_id: PanelId, position: DockPosition) !void {
        var parent = &self.panels.items[parent_id];
        const child_count = parent.children.items.len;

        if (child_count == 0) return;

        // Simple layout: divide space equally
        const parent_rect = parent.rect;
        var child_rects: [4]raylib.Rectangle = undefined;

        switch (position) {
            .left => {
                const child_width = parent_rect.width / @as(f32, @floatFromInt(child_count + 1));
                child_rects[0] = .{
                    .x = parent_rect.x,
                    .y = parent_rect.y,
                    .width = child_width,
                    .height = parent_rect.height,
                };
                for (parent.children.items, 0..) |child_id, i| {
                    self.panels.items[child_id].rect = .{
                        .x = parent_rect.x + child_width * @as(f32, @floatFromInt(i + 1)),
                        .y = parent_rect.y,
                        .width = child_width,
                        .height = parent_rect.height,
                    };
                }
                parent.rect.x += child_width;
                parent.rect.width -= child_width;
            },
            .right => {
                const child_width = parent_rect.width / @as(f32, @floatFromInt(child_count + 1));
                for (parent.children.items, 0..) |child_id, i| {
                    self.panels.items[child_id].rect = .{
                        .x = parent_rect.x + parent_rect.width - child_width * @as(f32, @floatFromInt(child_count - i)),
                        .y = parent_rect.y,
                        .width = child_width,
                        .height = parent_rect.height,
                    };
                }
                parent.rect.width -= child_width;
            },
            .top => {
                const child_height = parent_rect.height / @as(f32, @floatFromInt(child_count + 1));
                child_rects[0] = .{
                    .x = parent_rect.x,
                    .y = parent_rect.y,
                    .width = parent_rect.width,
                    .height = child_height,
                };
                for (parent.children.items, 0..) |child_id, i| {
                    self.panels.items[child_id].rect = .{
                        .x = parent_rect.x,
                        .y = parent_rect.y + child_height * @as(f32, @floatFromInt(i + 1)),
                        .width = parent_rect.width,
                        .height = child_height,
                    };
                }
                parent.rect.y += child_height;
                parent.rect.height -= child_height;
            },
            .bottom => {
                const child_height = parent_rect.height / @as(f32, @floatFromInt(child_count + 1));
                for (parent.children.items, 0..) |child_id, i| {
                    self.panels.items[child_id].rect = .{
                        .x = parent_rect.x,
                        .y = parent_rect.y + parent_rect.height - child_height * @as(f32, @floatFromInt(child_count - i)),
                        .width = parent_rect.width,
                        .height = child_height,
                    };
                }
                parent.rect.height -= child_height;
            },
        }
    }

    /// Handle mouse interaction for docking/dragging
    pub fn handleMouseInteraction(self: *DockingSystem, mouse_pos: raylib.Vector2, _: raylib.Vector2) void {
        const mouse_x = mouse_pos.x;
        const mouse_y = mouse_pos.y;

        // Handle dragging
        if (self.drag_state) |*drag| {
            var panel = &self.panels.items[drag.panel_id];
            panel.rect.x = mouse_x - drag.drag_offset.x;
            panel.rect.y = mouse_y - drag.drag_offset.y;

            // Check for docking targets
            for (self.panels.items, 0..) |other_panel, i| {
                if (i == drag.panel_id) continue;

                if (raylib.checkCollisionPointRec(mouse_pos, other_panel.rect)) {
                    // Highlight potential dock target
                    self.drawDockHighlight(other_panel.rect);
                    break;
                }
            }

            return;
        }

        // Check for panel header clicks
        for (self.panels.items, 0..) |panel, i| {
            if (!panel.is_visible) continue;

            const header_rect = raylib.Rectangle{
                .x = panel.rect.x,
                .y = panel.rect.y - 25, // Header above panel
                .width = panel.rect.width,
                .height = 25,
            };

            if (raylib.checkCollisionPointRec(mouse_pos, header_rect)) {
                if (raylib.isMouseButtonPressed(.left)) {
                    // Start dragging
                    self.drag_state = .{
                        .panel_id = i,
                        .drag_offset = .{
                            .x = mouse_x - panel.rect.x,
                            .y = mouse_y - panel.rect.y,
                        },
                        .original_rect = panel.rect,
                    };
                }
                break;
            }
        }
    }

    /// End dragging operation
    pub fn endDrag(self: *DockingSystem) void {
        if (self.drag_state) |_| {
            self.drag_state = null;
        }
    }

    /// Render all panels
    pub fn render(self: *DockingSystem) void {
        for (self.panels.items) |*panel| {
            if (!panel.is_visible) continue;

            // Render panel background
            raylib.drawRectangleRec(panel.rect, raylib.Color{ .r = 45, .g = 45, .b = 55, .a = 255 });
            raylib.drawRectangleLinesEx(panel.rect, 2, raylib.Color{ .r = 100, .g = 100, .b = 120, .a = 255 });

            // Render panel header
            const header_rect = raylib.Rectangle{
                .x = panel.rect.x,
                .y = panel.rect.y - 25,
                .width = panel.rect.width,
                .height = 25,
            };
            raylib.drawRectangleRec(header_rect, raylib.Color{ .r = 60, .g = 60, .b = 80, .a = 255 });
            raylib.drawRectangleLinesEx(header_rect, 1, raylib.Color.white);
            raylib.drawText(panel.title, @intFromFloat(panel.rect.x + 5), @intFromFloat(panel.rect.y - 20), 16, raylib.Color.white);

            // Render panel content
            if (panel.content_callback) |callback| {
                callback(panel, self.allocator);
            }
        }
    }

    fn drawDockHighlight(_: *DockingSystem, rect: raylib.Rectangle) void {
        raylib.drawRectangleLinesEx(rect, 3, raylib.Color{ .r = 0, .g = 255, .b = 0, .a = 255 });
    }

    /// Get panel by ID
    pub fn getPanel(self: *DockingSystem, id: PanelId) ?*Panel {
        if (id >= self.panels.items.len) return null;
        return &self.panels.items[id];
    }

    /// Show/hide panel
    pub fn setPanelVisible(self: *DockingSystem, id: PanelId, visible: bool) void {
        if (id < self.panels.items.len) {
            self.panels.items[id].is_visible = visible;
        }
    }

    /// Update screen size
    pub fn updateScreenSize(self: *DockingSystem, width: f32, height: f32) void {
        self.screen_width = width;
        self.screen_height = height;
        self.screen_width = width;
        self.screen_height = height;
    }
};
