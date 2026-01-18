//! Save/Load Menu UI
//!
//! UI for managing saved worlds including creating, loading, and deleting saves.

const std = @import("std");
const ui = @import("ui.zig");
const render = @import("../render/render.zig");
const text = @import("text.zig");
const theme = @import("theme.zig");
const icons = @import("icons.zig");

const game = @import("../game/sandbox.zig");
const save = @import("../game/save.zig");
const SaveSystem = save.SaveSystem;
const SaveInfo = save.SaveInfo;

/// Save menu state
pub const SaveMenuState = enum {
    closed,
    main_menu,
    world_select,
    create_world,
    confirm_delete,
    loading,
    saving,
};

/// Save/Load Menu UI
pub const SaveMenu = struct {
    state: SaveMenuState = .closed,
    selected_save_index: ?usize = null,
    saves_list: ?[]SaveInfo = null,
    allocator: std.mem.Allocator,

    // Text input buffer for new world name
    world_name_input: [64]u8 = [_]u8{0} ** 64,
    world_name_len: usize = 0,

    // Confirmation dialog target
    delete_target: ?[]const u8 = null,

    // Error/status message
    status_message: ?[]const u8 = null,
    status_is_error: bool = false,

    // Animation state
    animation_timer: f32 = 0,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.freeSavesList();
    }

    fn freeSavesList(self: *Self) void {
        if (self.saves_list) |saves| {
            for (saves) |*s| {
                s.deinit();
            }
            self.allocator.free(saves);
            self.saves_list = null;
        }
    }

    /// Open the save menu
    pub fn open(self: *Self, save_system: *SaveSystem) void {
        self.state = .main_menu;
        self.selected_save_index = null;
        self.status_message = null;
        self.refreshSavesList(save_system);
    }

    /// Close the save menu
    pub fn close(self: *Self) void {
        self.state = .closed;
        self.freeSavesList();
    }

    /// Check if menu is open
    pub fn isOpen(self: *const Self) bool {
        return self.state != .closed;
    }

    /// Refresh the saves list
    pub fn refreshSavesList(self: *Self, save_system: *SaveSystem) void {
        self.freeSavesList();
        self.saves_list = save_system.listSaves() catch null;
    }

    /// Update the menu
    pub fn update(self: *Self, dt: f32) void {
        self.animation_timer += dt;
    }

    /// Draw the save menu
    pub fn draw(
        self: *Self,
        ctx: *ui.Context,
        width: u32,
        height: u32,
    ) void {
        if (self.state == .closed) return;

        const w: i32 = @intCast(width);
        const h: i32 = @intCast(height);

        // Semi-transparent background overlay
        ctx.drawRect(0, 0, w, h, render.Color.fromRgba(0, 0, 0, 180));

        switch (self.state) {
            .closed => {},
            .main_menu => self.drawMainMenu(ctx, w, h),
            .world_select => self.drawWorldSelect(ctx, w, h),
            .create_world => self.drawCreateWorld(ctx, w, h),
            .confirm_delete => self.drawConfirmDelete(ctx, w, h),
            .loading, .saving => self.drawLoadingScreen(ctx, w, h),
        }
    }

    fn drawMainMenu(self: *Self, ctx: *ui.Context, w: i32, h: i32) void {
        const panel_w: i32 = 400;
        const panel_h: i32 = 300;
        const panel_x = @divFloor(w - panel_w, 2);
        const panel_y = @divFloor(h - panel_h, 2);

        // Draw panel
        ctx.panel(panel_x, panel_y, panel_w, panel_h, "Save/Load Menu");

        const padding: i32 = 20;
        const btn_h: i32 = 40;
        const btn_spacing: i32 = 10;
        var y = panel_y + 50;

        // Title area
        const title_height = @as(i32, @intCast(theme.sizing.title_bar_height));
        y = panel_y + title_height + padding;

        // Continue button
        if (ctx.styledButton(
            hashId("continue"),
            panel_x + padding,
            y,
            panel_w - padding * 2,
            btn_h,
            "Continue Playing",
            .primary,
            true,
        )) {
            self.close();
        }
        y += btn_h + btn_spacing;

        // Load world button
        if (ctx.styledButton(
            hashId("load_world"),
            panel_x + padding,
            y,
            panel_w - padding * 2,
            btn_h,
            "Load World",
            .secondary,
            self.saves_list != null and self.saves_list.?.len > 0,
        )) {
            self.state = .world_select;
        }
        y += btn_h + btn_spacing;

        // New world button
        if (ctx.styledButton(
            hashId("new_world"),
            panel_x + padding,
            y,
            panel_w - padding * 2,
            btn_h,
            "Create New World",
            .secondary,
            true,
        )) {
            self.state = .create_world;
            self.world_name_len = 0;
            @memset(&self.world_name_input, 0);
        }
        y += btn_h + btn_spacing;

        // Quick save button
        if (ctx.styledButton(
            hashId("quick_save"),
            panel_x + padding,
            y,
            panel_w - padding * 2,
            btn_h,
            "Quick Save (F5)",
            .ghost,
            true,
        )) {
            self.state = .saving;
        }
        y += btn_h + btn_spacing + 10;

        // Status message
        if (self.status_message) |msg| {
            const color = if (self.status_is_error)
                ctx.current_theme.error_color
            else
                ctx.current_theme.success;
            text.drawText(ctx.renderer, &text.default_font, msg, panel_x + padding, y, .{ .color = color });
        }
    }

    fn drawWorldSelect(self: *Self, ctx: *ui.Context, w: i32, h: i32) void {
        const panel_w: i32 = 500;
        const panel_h: i32 = 400;
        const panel_x = @divFloor(w - panel_w, 2);
        const panel_y = @divFloor(h - panel_h, 2);

        // Draw panel
        ctx.panel(panel_x, panel_y, panel_w, panel_h, "Select World");

        const padding: i32 = 15;
        const title_height = @as(i32, @intCast(theme.sizing.title_bar_height));
        const item_h: i32 = 60;
        const list_y = panel_y + title_height + padding;
        const list_h = panel_h - title_height - padding * 3 - 40;

        // Draw save list
        if (self.saves_list) |saves| {
            var y = list_y;
            for (saves, 0..) |info, i| {
                if (y + item_h > list_y + list_h) break;

                const is_selected = self.selected_save_index == i;
                const item_x = panel_x + padding;
                const item_w = panel_w - padding * 2;

                // Item background
                const bg_color = if (is_selected)
                    ctx.current_theme.accent
                else if (ctx.inRect(item_x, y, item_w, item_h))
                    ctx.current_theme.hover_overlay
                else
                    ctx.current_theme.panel_body;

                ctx.drawRoundedRect(item_x, y, item_w, item_h, 4, bg_color);

                // Click detection
                if (ctx.inRect(item_x, y, item_w, item_h) and ctx.mouse_clicked) {
                    self.selected_save_index = i;
                }

                // World name
                const text_color = if (is_selected) render.Color.WHITE else ctx.current_theme.text_primary;
                text.drawText(ctx.renderer, &text.default_font, info.name, item_x + 10, y + 8, .{ .color = text_color });

                // Info line
                var info_buf: [128]u8 = undefined;
                const play_hours = @as(u32, @intFromFloat(info.play_time / 3600));
                const play_mins = @as(u32, @intFromFloat(@mod(info.play_time, 3600) / 60));
                const info_text = std.fmt.bufPrint(&info_buf, "Played: {}h {}m | Seed: {}", .{
                    play_hours,
                    play_mins,
                    info.world_seed,
                }) catch "...";
                const secondary_color = if (is_selected) render.Color.fromRgba(255, 255, 255, 180) else ctx.current_theme.text_secondary;
                text.drawText(ctx.renderer, &text.default_font, info_text, item_x + 10, y + 28, .{ .color = secondary_color });

                // File size
                const size_kb = info.file_size / 1024;
                var size_buf: [32]u8 = undefined;
                const size_text = std.fmt.bufPrint(&size_buf, "{} KB", .{size_kb}) catch "?";
                text.drawText(ctx.renderer, &text.default_font, size_text, item_x + 10, y + 44, .{ .color = secondary_color });

                y += item_h + 5;
            }
        } else {
            text.drawText(ctx.renderer, &text.default_font, "No saved worlds found", panel_x + padding, list_y + 20, .{
                .color = ctx.current_theme.text_secondary,
            });
        }

        // Buttons at bottom
        const btn_y = panel_y + panel_h - 50;
        const btn_w: i32 = 100;
        const btn_h: i32 = 35;

        // Back button
        if (ctx.styledButton(
            hashId("world_back"),
            panel_x + padding,
            btn_y,
            btn_w,
            btn_h,
            "Back",
            .ghost,
            true,
        )) {
            self.state = .main_menu;
            self.selected_save_index = null;
        }

        // Delete button
        if (ctx.styledButton(
            hashId("world_delete"),
            panel_x + padding + btn_w + 10,
            btn_y,
            btn_w,
            btn_h,
            "Delete",
            .danger,
            self.selected_save_index != null,
        )) {
            if (self.selected_save_index) |idx| {
                if (self.saves_list) |saves| {
                    if (idx < saves.len) {
                        self.delete_target = saves[idx].name;
                        self.state = .confirm_delete;
                    }
                }
            }
        }

        // Load button
        if (ctx.styledButton(
            hashId("world_load"),
            panel_x + panel_w - padding - btn_w,
            btn_y,
            btn_w,
            btn_h,
            "Load",
            .primary,
            self.selected_save_index != null,
        )) {
            self.state = .loading;
        }
    }

    fn drawCreateWorld(self: *Self, ctx: *ui.Context, w: i32, h: i32) void {
        const panel_w: i32 = 400;
        const panel_h: i32 = 250;
        const panel_x = @divFloor(w - panel_w, 2);
        const panel_y = @divFloor(h - panel_h, 2);

        ctx.panel(panel_x, panel_y, panel_w, panel_h, "Create New World");

        const padding: i32 = 20;
        const title_height = @as(i32, @intCast(theme.sizing.title_bar_height));
        var y = panel_y + title_height + padding;

        // World name label
        text.drawText(ctx.renderer, &text.default_font, "World Name:", panel_x + padding, y, .{
            .color = ctx.current_theme.text_primary,
        });
        y += 20;

        // World name input (simplified - show current text)
        const input_h: i32 = 36;
        ctx.drawRoundedRect(
            panel_x + padding,
            y,
            panel_w - padding * 2,
            input_h,
            4,
            ctx.current_theme.input_background,
        );
        ctx.drawRoundedRectOutline(
            panel_x + padding,
            y,
            panel_w - padding * 2,
            input_h,
            4,
            ctx.current_theme.input_border,
        );

        // Display input text
        const display_name = if (self.world_name_len > 0)
            self.world_name_input[0..self.world_name_len]
        else
            "New World";

        text.drawText(ctx.renderer, &text.default_font, display_name, panel_x + padding + 10, y + 10, .{
            .color = if (self.world_name_len > 0) ctx.current_theme.text_primary else ctx.current_theme.text_secondary,
        });

        // Cursor blink
        if (self.world_name_len < 63) {
            const cursor_visible = @mod(@as(i32, @intFromFloat(self.animation_timer * 2)), 2) == 0;
            if (cursor_visible) {
                const cursor_x = panel_x + padding + 10 + @as(i32, @intCast(self.world_name_len)) * 8;
                ctx.drawRect(cursor_x, y + 8, 2, 20, ctx.current_theme.text_primary);
            }
        }

        y += input_h + 20;

        // Seed info
        text.drawText(ctx.renderer, &text.default_font, "A random seed will be generated", panel_x + padding, y, .{
            .color = ctx.current_theme.text_secondary,
        });
        y += 30;

        // Buttons
        const btn_y = panel_y + panel_h - 55;
        const btn_w: i32 = 100;
        const btn_h: i32 = 35;

        // Cancel button
        if (ctx.styledButton(
            hashId("create_cancel"),
            panel_x + padding,
            btn_y,
            btn_w,
            btn_h,
            "Cancel",
            .ghost,
            true,
        )) {
            self.state = .main_menu;
        }

        // Create button
        if (ctx.styledButton(
            hashId("create_confirm"),
            panel_x + panel_w - padding - btn_w,
            btn_y,
            btn_w,
            btn_h,
            "Create",
            .primary,
            true,
        )) {
            // Will trigger world creation
            self.state = .loading;
        }
    }

    fn drawConfirmDelete(self: *Self, ctx: *ui.Context, w: i32, h: i32) void {
        const panel_w: i32 = 350;
        const panel_h: i32 = 180;
        const panel_x = @divFloor(w - panel_w, 2);
        const panel_y = @divFloor(h - panel_h, 2);

        ctx.panel(panel_x, panel_y, panel_w, panel_h, "Confirm Delete");

        const padding: i32 = 20;
        const title_height = @as(i32, @intCast(theme.sizing.title_bar_height));
        var y = panel_y + title_height + padding;

        // Warning message
        text.drawText(ctx.renderer, &text.default_font, "Delete this world?", panel_x + padding, y, .{
            .color = ctx.current_theme.text_primary,
        });
        y += 20;

        if (self.delete_target) |name| {
            text.drawText(ctx.renderer, &text.default_font, name, panel_x + padding, y, .{
                .color = ctx.current_theme.error_color,
            });
        }
        y += 20;

        text.drawText(ctx.renderer, &text.default_font, "This cannot be undone!", panel_x + padding, y, .{
            .color = ctx.current_theme.text_secondary,
        });

        // Buttons
        const btn_y = panel_y + panel_h - 55;
        const btn_w: i32 = 100;
        const btn_h: i32 = 35;

        // Cancel button
        if (ctx.styledButton(
            hashId("delete_cancel"),
            panel_x + padding,
            btn_y,
            btn_w,
            btn_h,
            "Cancel",
            .ghost,
            true,
        )) {
            self.state = .world_select;
            self.delete_target = null;
        }

        // Delete button
        if (ctx.styledButton(
            hashId("delete_confirm"),
            panel_x + panel_w - padding - btn_w,
            btn_y,
            btn_w,
            btn_h,
            "Delete",
            .danger,
            true,
        )) {
            // Will trigger deletion
            self.state = .world_select;
            self.delete_target = null;
        }
    }

    fn drawLoadingScreen(self: *Self, ctx: *ui.Context, w: i32, h: i32) void {
        const panel_w: i32 = 300;
        const panel_h: i32 = 100;
        const panel_x = @divFloor(w - panel_w, 2);
        const panel_y = @divFloor(h - panel_h, 2);

        ctx.drawRoundedRect(panel_x, panel_y, panel_w, panel_h, 8, ctx.current_theme.panel_body);
        ctx.drawRoundedRectOutline(panel_x, panel_y, panel_w, panel_h, 8, ctx.current_theme.border);

        const message = if (self.state == .saving) "Saving..." else "Loading...";
        const size = text.measureText(&text.default_font, message, 1);
        text.drawText(
            ctx.renderer,
            &text.default_font,
            message,
            panel_x + @divFloor(panel_w - size.width, 2),
            panel_y + 25,
            .{ .color = ctx.current_theme.text_primary },
        );

        // Simple progress indicator (animated dots)
        const dots = @mod(@as(usize, @intFromFloat(self.animation_timer * 3)), 4);
        var dots_buf: [4]u8 = .{ '.', '.', '.', ' ' };
        const dots_str = dots_buf[0..dots];
        text.drawText(
            ctx.renderer,
            &text.default_font,
            dots_str,
            panel_x + @divFloor(panel_w, 2) + 30,
            panel_y + 25,
            .{ .color = ctx.current_theme.text_secondary },
        );

        // Progress bar
        const progress = @mod(self.animation_timer, 2.0) / 2.0;
        ctx.progressBar(panel_x + 20, panel_y + 60, panel_w - 40, progress, null);
    }

    /// Process keyboard input for text entry
    pub fn handleKeyInput(self: *Self, key: u8) void {
        if (self.state != .create_world) return;

        if (key == 8) {
            // Backspace
            if (self.world_name_len > 0) {
                self.world_name_len -= 1;
                self.world_name_input[self.world_name_len] = 0;
            }
        } else if (key >= 32 and key < 127 and self.world_name_len < 63) {
            // Printable ASCII
            self.world_name_input[self.world_name_len] = key;
            self.world_name_len += 1;
        }
    }

    /// Get the selected save info
    pub fn getSelectedSave(self: *const Self) ?*const SaveInfo {
        if (self.selected_save_index) |idx| {
            if (self.saves_list) |saves| {
                if (idx < saves.len) {
                    return &saves[idx];
                }
            }
        }
        return null;
    }

    /// Get the entered world name for creation
    pub fn getNewWorldName(self: *const Self) []const u8 {
        if (self.world_name_len > 0) {
            return self.world_name_input[0..self.world_name_len];
        }
        return "New World";
    }

    fn drawRoundedRectOutline(ctx: *ui.Context, x: i32, y: i32, w: i32, h: i32, radius: u32, color: render.Color) void {
        ctx.drawRoundedRectOutline(x, y, w, h, radius, color);
    }
};

/// Generate a hash ID from a string
fn hashId(name: []const u8) u64 {
    var hash: u64 = 5381;
    for (name) |c| {
        hash = ((hash << 5) +% hash) +% c;
    }
    return hash;
}

// ============================================================================
// Tests
// ============================================================================

test "save menu init" {
    const allocator = std.testing.allocator;
    var menu = SaveMenu.init(allocator);
    defer menu.deinit();

    try std.testing.expect(!menu.isOpen());
    try std.testing.expectEqual(SaveMenuState.closed, menu.state);
}

test "hash id generation" {
    const id1 = hashId("test");
    const id2 = hashId("test");
    const id3 = hashId("other");

    try std.testing.expectEqual(id1, id2);
    try std.testing.expect(id1 != id3);
}
