//! Nyon Editor - Visual Game Editor

const std = @import("std");
const nyon = @import("nyon_game");

/// Global editor instance for callback access
var g_editor: ?*Editor = null;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.log.info("Nyon Editor v{s}", .{nyon.VERSION.string});

    var engine = try nyon.Engine.init(allocator, .{
        .window_width = 1600,
        .window_height = 900,
        .window_title = "Nyon Editor",
        .enable_debug = true,
    });
    defer engine.deinit();

    // Editor state
    var editor = Editor.init(allocator, &engine);
    defer editor.deinit();

    // Set global reference for callback
    g_editor = &editor;
    defer g_editor = null;

    // Add initial log message
    editor.addLog("Nyon Editor initialized");

    // Run editor loop
    engine.run(struct {
        fn update(eng: *nyon.Engine) void {
            _ = eng;
            if (g_editor) |ed| {
                ed.update();
            }
        }
    }.update);
}

const Editor = struct {
    const MAX_LOG_LINES = 100;
    const LOG_LINE_LEN = 128;

    allocator: std.mem.Allocator,
    engine: *nyon.Engine,
    selected_entity: ?nyon.Entity,
    show_hierarchy: bool,
    show_inspector: bool,
    show_assets: bool,
    show_console: bool,

    // Console log storage
    log_lines: std.ArrayListUnmanaged([]u8),
    console_scroll: i32,

    // Asset panel state
    selected_category: u32,

    // Viewport state
    viewport_grid_visible: bool,

    pub fn init(allocator: std.mem.Allocator, engine: *nyon.Engine) Editor {
        return .{
            .allocator = allocator,
            .engine = engine,
            .selected_entity = null,
            .show_hierarchy = true,
            .show_inspector = true,
            .show_assets = true,
            .show_console = true,
            .log_lines = .{},
            .console_scroll = 0,
            .selected_category = 0,
            .viewport_grid_visible = true,
        };
    }

    pub fn deinit(self: *Editor) void {
        // Free all log line strings
        for (self.log_lines.items) |line| {
            self.allocator.free(line);
        }
        self.log_lines.deinit(self.allocator);
    }

    /// Add a message to the console log
    pub fn addLog(self: *Editor, message: []const u8) void {
        // Truncate if needed and copy
        const len = @min(message.len, LOG_LINE_LEN);
        const line = self.allocator.alloc(u8, len) catch return;
        @memcpy(line, message[0..len]);

        // Remove oldest if at capacity
        if (self.log_lines.items.len >= MAX_LOG_LINES) {
            const removed = self.log_lines.orderedRemove(0);
            self.allocator.free(removed);
        }

        self.log_lines.append(self.allocator, line) catch {
            self.allocator.free(line);
        };
    }

    pub fn update(self: *Editor) void {
        // Handle keyboard shortcuts
        const input_state = &self.engine.input_state;

        // Toggle panels with F-keys
        if (input_state.isKeyPressed(.f1)) {
            self.show_hierarchy = !self.show_hierarchy;
            self.addLog(if (self.show_hierarchy) "Hierarchy panel shown" else "Hierarchy panel hidden");
        }
        if (input_state.isKeyPressed(.f2)) {
            self.show_inspector = !self.show_inspector;
            self.addLog(if (self.show_inspector) "Inspector panel shown" else "Inspector panel hidden");
        }
        if (input_state.isKeyPressed(.f3)) {
            self.show_assets = !self.show_assets;
            self.addLog(if (self.show_assets) "Assets panel shown" else "Assets panel hidden");
        }
        if (input_state.isKeyPressed(.f4)) {
            self.show_console = !self.show_console;
            self.addLog(if (self.show_console) "Console panel shown" else "Console panel hidden");
        }
        if (input_state.isKeyPressed(.g)) {
            self.viewport_grid_visible = !self.viewport_grid_visible;
            self.addLog(if (self.viewport_grid_visible) "Grid enabled" else "Grid disabled");
        }

        // Draw all panels (viewport first as background)
        self.drawViewport();
        if (self.show_hierarchy) self.drawHierarchy();
        if (self.show_inspector) self.drawInspector();
        if (self.show_assets) self.drawAssets();
        if (self.show_console) self.drawConsole();
    }

    fn drawHierarchy(self: *Editor) void {
        const ui_ctx = &self.engine.ui_context;
        const x: i32 = 0;
        const y: i32 = 0;
        const w: i32 = 300;
        const h: i32 = @intCast(self.engine.config.window_height);
        _ = h; // autofix

        ui_ctx.label(x + 10, y + 10, "Hierarchy");

        // Simple list of entities
        var entity_query = nyon.ecs.Query(&[_]type{nyon.ecs.Name}).init(&self.engine.world);
        var iter = entity_query.iter();
        var i: i32 = 0;
        while (iter.next()) |res| {
            var res_copy = res;
            const name = res_copy.get(nyon.ecs.Name).get();
            const id = res_copy.entity.hash();

            if (ui_ctx.button(id, x + 10, y + 40 + i * 30, w - 20, 25, name)) {
                self.selected_entity = res_copy.entity;
            }
            i += 1;
        }
    }

    fn drawInspector(self: *Editor) void {
        const entity = self.selected_entity orelse return;
        const ui_ctx = &self.engine.ui_context;
        const x: i32 = @intCast(self.engine.config.window_width - 300);
        const y: i32 = 0;
        const w: i32 = 300;
        const h: i32 = @intCast(self.engine.config.window_height);
        _ = h;

        ui_ctx.label(x + 10, y + 10, "Inspector");

        if (self.engine.world.getComponent(entity, nyon.ecs.Transform)) |transform| {
            ui_ctx.label(x + 10, y + 40, "Transform");
            // Mock sliders for position
            transform.position.data[0] = ui_ctx.slider(entity.hash() + 1, x + 10, y + 60, w - 20, 20, transform.position.x(), -10, 10);
            transform.position.data[1] = ui_ctx.slider(entity.hash() + 2, x + 10, y + 90, w - 20, 20, transform.position.y(), -10, 10);
            transform.position.data[2] = ui_ctx.slider(entity.hash() + 3, x + 10, y + 120, w - 20, 20, transform.position.z(), -10, 10);
        }
    }

    fn drawAssets(self: *Editor) void {
        const ui_ctx = &self.engine.ui_context;
        const panel_w: i32 = 300;
        const panel_h: i32 = 200;
        const x: i32 = 310; // Right of hierarchy panel
        const y: i32 = @as(i32, @intCast(self.engine.config.window_height)) - panel_h - 10;

        // Draw panel background
        const renderer = &self.engine.renderer;
        const bg_color = nyon.render.Color.fromRgb(40, 40, 55);
        self.drawPanelBackground(renderer, x, y, panel_w, panel_h, bg_color);

        // Panel title
        ui_ctx.label(x + 10, y + 10, "Assets");

        // Asset categories
        const categories = [_][]const u8{ "Models", "Textures", "Audio", "Scripts" };
        const category_icons = [_][]const u8{ "[M]", "[T]", "[A]", "[S]" };

        for (categories, 0..) |category, idx| {
            const i: i32 = @intCast(idx);
            const btn_y = y + 40 + i * 35;
            const btn_id: u64 = 0x41535345_00000000 | @as(u64, idx); // "ASSE" prefix + index

            // Category button
            if (ui_ctx.button(btn_id, x + 10, btn_y, panel_w - 20, 30, category)) {
                self.selected_category = @intCast(idx);
                self.addLog(category);
            }

            // Icon label
            ui_ctx.label(x + 20, btn_y + 8, category_icons[idx]);
        }
    }

    /// Helper to draw a panel background rectangle
    fn drawPanelBackground(_: *Editor, renderer: *nyon.render.Renderer, x: i32, y: i32, w: i32, h: i32, color: nyon.render.Color) void {
        var py: i32 = y;
        while (py < y + h) : (py += 1) {
            var px: i32 = x;
            while (px < x + w) : (px += 1) {
                renderer.drawPixel(px, py, 0.0, color);
            }
        }
    }

    fn drawConsole(self: *Editor) void {
        const ui_ctx = &self.engine.ui_context;
        const panel_w: i32 = 500;
        const panel_h: i32 = 200;
        const win_w: i32 = @intCast(self.engine.config.window_width);
        const win_h: i32 = @intCast(self.engine.config.window_height);
        const x: i32 = win_w - panel_w - 310; // Left of inspector area
        const y: i32 = win_h - panel_h - 10;

        // Draw panel background
        const renderer = &self.engine.renderer;
        const bg_color = nyon.render.Color.fromRgb(25, 25, 35);
        self.drawPanelBackground(renderer, x, y, panel_w, panel_h, bg_color);

        // Panel title
        ui_ctx.label(x + 10, y + 10, "Console");

        // Clear button
        const clear_btn_id: u64 = 0x434C5200_00000000; // "CLR" prefix
        if (ui_ctx.button(clear_btn_id, x + panel_w - 60, y + 5, 50, 20, "Clear")) {
            // Clear all log lines
            for (self.log_lines.items) |line| {
                self.allocator.free(line);
            }
            self.log_lines.clearRetainingCapacity();
            self.console_scroll = 0;
        }

        // Draw log lines (newest at bottom, scrollable)
        const line_height: i32 = 16;
        const visible_lines = @divFloor(panel_h - 40, line_height);
        const total_lines: i32 = @intCast(self.log_lines.items.len);

        // Calculate scroll range
        const max_scroll = @max(0, total_lines - visible_lines);
        self.console_scroll = std.math.clamp(self.console_scroll, 0, max_scroll);

        // Handle scroll input with buttons
        const scroll_up_id: u64 = 0x53435550_00000000; // "SCUP"
        const scroll_dn_id: u64 = 0x5343444E_00000000; // "SCDN"
        if (ui_ctx.button(scroll_up_id, x + panel_w - 25, y + 30, 20, 20, "^")) {
            self.console_scroll = @max(0, self.console_scroll - 1);
        }
        if (ui_ctx.button(scroll_dn_id, x + panel_w - 25, y + panel_h - 30, 20, 20, "v")) {
            self.console_scroll = @min(max_scroll, self.console_scroll + 1);
        }

        // Draw visible log lines
        const start_line: usize = @intCast(self.console_scroll);
        const end_line: usize = @min(self.log_lines.items.len, start_line + @as(usize, @intCast(visible_lines)));

        var line_idx: i32 = 0;
        for (self.log_lines.items[start_line..end_line]) |line| {
            const text_y = y + 35 + line_idx * line_height;
            ui_ctx.label(x + 10, text_y, line);
            line_idx += 1;
        }

        // Show line count
        var count_buf: [32]u8 = undefined;
        const count_str = std.fmt.bufPrint(&count_buf, "{d} lines", .{total_lines}) catch "? lines";
        ui_ctx.label(x + 10, y + panel_h - 20, count_str);
    }

    fn drawViewport(self: *Editor) void {
        if (!self.viewport_grid_visible) return;

        const renderer = &self.engine.renderer;

        // Draw a simple 3D grid in the viewport
        // Grid parameters
        const grid_size: i32 = 10;
        const grid_spacing: f32 = 1.0;
        const grid_color = nyon.render.Color.fromRgb(60, 60, 80);
        const axis_x_color = nyon.render.Color.fromRgb(200, 80, 80); // Red for X
        const axis_z_color = nyon.render.Color.fromRgb(80, 80, 200); // Blue for Z

        // Set up a simple camera view for the grid
        const eye = nyon.Vec3{ .data = .{ 5.0, 5.0, 5.0, 0.0 } };
        const target = nyon.Vec3{ .data = .{ 0.0, 0.0, 0.0, 0.0 } };
        const up = nyon.Vec3{ .data = .{ 0.0, 1.0, 0.0, 0.0 } };

        const aspect = @as(f32, @floatFromInt(self.engine.config.window_width)) /
            @as(f32, @floatFromInt(self.engine.config.window_height));
        const view = nyon.Mat4.lookAt(eye, target, up);
        const proj = nyon.Mat4.perspective(nyon.math.radians(60.0), aspect, 0.1, 100.0);

        renderer.setCamera(view, proj);

        // Draw grid lines along X axis
        var i: i32 = -grid_size;
        while (i <= grid_size) : (i += 1) {
            const z = @as(f32, @floatFromInt(i)) * grid_spacing;
            const color = if (i == 0) axis_x_color else grid_color;

            const start = nyon.Vec3{ .data = .{ -@as(f32, @floatFromInt(grid_size)) * grid_spacing, 0.0, z, 0.0 } };
            const end = nyon.Vec3{ .data = .{ @as(f32, @floatFromInt(grid_size)) * grid_spacing, 0.0, z, 0.0 } };

            self.drawWorldLine(renderer, view, proj, start, end, color);
        }

        // Draw grid lines along Z axis
        i = -grid_size;
        while (i <= grid_size) : (i += 1) {
            const x = @as(f32, @floatFromInt(i)) * grid_spacing;
            const color = if (i == 0) axis_z_color else grid_color;

            const start = nyon.Vec3{ .data = .{ x, 0.0, -@as(f32, @floatFromInt(grid_size)) * grid_spacing, 0.0 } };
            const end = nyon.Vec3{ .data = .{ x, 0.0, @as(f32, @floatFromInt(grid_size)) * grid_spacing, 0.0 } };

            self.drawWorldLine(renderer, view, proj, start, end, color);
        }

        // Draw Y axis (up)
        const axis_y_color = nyon.render.Color.fromRgb(80, 200, 80); // Green for Y
        const y_start = nyon.Vec3{ .data = .{ 0.0, 0.0, 0.0, 0.0 } };
        const y_end = nyon.Vec3{ .data = .{ 0.0, 3.0, 0.0, 0.0 } };
        self.drawWorldLine(renderer, view, proj, y_start, y_end, axis_y_color);

        // Draw viewport label
        const ui_ctx = &self.engine.ui_context;
        ui_ctx.label(320, 10, "Viewport (G to toggle grid)");
    }

    /// Draw a line in world space, projected to screen
    fn drawWorldLine(
        _: *Editor,
        renderer: *nyon.render.Renderer,
        view: nyon.Mat4,
        proj: nyon.Mat4,
        start: nyon.Vec3,
        end: nyon.Vec3,
        color: nyon.render.Color,
    ) void {
        const mvp = nyon.Mat4.mul(proj, view);

        const p1_clip = nyon.Mat4.mulVec4(mvp, nyon.Vec4.fromVec3(start, 1.0));
        const p2_clip = nyon.Mat4.mulVec4(mvp, nyon.Vec4.fromVec3(end, 1.0));

        // Skip if behind camera
        if (p1_clip.w() <= 0 or p2_clip.w() <= 0) return;

        // Perspective divide
        const p1_ndc = nyon.Vec4.init(
            p1_clip.x() / p1_clip.w(),
            p1_clip.y() / p1_clip.w(),
            p1_clip.z() / p1_clip.w(),
            1.0,
        );
        const p2_ndc = nyon.Vec4.init(
            p2_clip.x() / p2_clip.w(),
            p2_clip.y() / p2_clip.w(),
            p2_clip.z() / p2_clip.w(),
            1.0,
        );

        // Convert to screen space
        const w: f32 = @floatFromInt(renderer.width);
        const h: f32 = @floatFromInt(renderer.height);

        const x1: i32 = @intFromFloat((p1_ndc.x() + 1.0) * 0.5 * w);
        const y1: i32 = @intFromFloat((1.0 - p1_ndc.y()) * 0.5 * h);
        const x2: i32 = @intFromFloat((p2_ndc.x() + 1.0) * 0.5 * w);
        const y2: i32 = @intFromFloat((1.0 - p2_ndc.y()) * 0.5 * h);

        renderer.drawLine(x1, y1, x2, y2, color);
    }
};
