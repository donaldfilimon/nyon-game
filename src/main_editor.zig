//!
//! Unified Main Editor System for Nyon Game Engine
//!
//! Provides a professional editor interface comparable to Blender, with multiple
//! integrated editing modes and real-time rendering capabilities.
//!

const std = @import("std");
const raylib = @import("raylib");

// ============================================================================
// Imports and Dependencies
// ============================================================================

const engine = @import("engine.zig");
const scene = @import("scene.zig");
const material = @import("material.zig");
const rendering = @import("rendering.zig");
const animation = @import("animation.zig");
const keyframe = @import("keyframe.zig");
const asset = @import("asset.zig");
const undo_redo = @import("undo_redo.zig");
const performance = @import("performance.zig");
const nodes = @import("nodes/node_graph.zig");
const geometry_nodes = @import("geometry_nodes.zig");
const docking = @import("docking.zig");
const property_inspector = @import("property_inspector.zig");
const post_processing = @import("post_processing.zig");
const editor_tabs = @import("editor_tabs.zig");
const ui_context = @import("ui_context.zig");
const gizmo_system = @import("gizmo_system.zig");
const tool_system = @import("tool_system.zig");

// ============================================================================
// Main Editor System
// ============================================================================

/// Unified main editor system with multiple editing modes
pub const MainEditor = struct {
    allocator: std.mem.Allocator,

    // Core systems
    scene_system: scene.Scene,
    rendering_system: rendering.RenderingSystem,
    asset_manager: asset.AssetManager,
    undo_redo_system: undo_redo.UndoRedoSystem,
    performance_system: performance.PerformanceSystem,
    keyframe_system: keyframe.KeyframeSystem,
    animation_system: animation.AnimationSystem,

    // Editor UI systems
    docking_system: docking.DockingSystem,
    property_inspector: property_inspector.PropertyInspector,

    // Node-based editors
    geometry_node_editor: geometry_nodes.GeometryNodeSystem,
    material_node_editor: MaterialNodeEditor,

    // Current editor mode
    current_mode: EditorMode,

    // UI state
    screen_width: f32,
    screen_height: f32,
    tab_bar_height: f32 = 40,
    toolbar_height: f32 = 35,
    status_bar_height: f32 = 25,

    // Scene editor state
    selected_scene_object: ?usize,

    // Animation editor state
    animation_timeline_visible: bool = false,
    animation_playback: bool = false,

    // TUI state
    tui_command_buffer: std.ArrayList(u8),
    tui_command_history: std.ArrayList([]const u8),
    tui_output_lines: std.ArrayList([]const u8),
    tui_cursor_pos: usize = 0,
    tui_history_index: i32 = -1,

    pub const EditorMode = enum {
        geometry_nodes,
        scene_editor,
        material_editor,
        animation_editor,
        tui_mode,
    };

    /// Initialize the main editor system
    pub fn init(allocator: std.mem.Allocator, screen_width: f32, screen_height: f32) !MainEditor {
        // Initialize core systems
        var scene_sys = scene.Scene.init(allocator);
        errdefer scene_sys.deinit();

        var render_sys = rendering.RenderingSystem.init(allocator);
        errdefer render_sys.deinit();

        var asset_mgr = asset.AssetManager.init(allocator);
        errdefer asset_mgr.deinit();

        var undo_redo_sys = undo_redo.UndoRedoSystem.init(allocator);
        errdefer undo_redo_sys.deinit();

        var perf_sys = performance.PerformanceSystem.init(allocator);
        errdefer perf_sys.deinit();

        var keyframe_sys = keyframe.KeyframeSystem.init(allocator);
        errdefer keyframe_sys.deinit();

        var anim_sys = animation.AnimationSystem.init(allocator);
        errdefer anim_sys.deinit();

        // Initialize UI systems
        var dock_sys = docking.DockingSystem.init(allocator, screen_width, screen_height);
        errdefer dock_sys.deinit();

        var prop_inspector = property_inspector.PropertyInspector.init(allocator);
        errdefer prop_inspector.deinit();

        // Initialize node editors
        var geom_node_editor = try geometry_nodes.GeometryNodeSystem.init(allocator);
        errdefer geom_node_editor.deinit();

        var mat_node_editor = try MaterialNodeEditor.init(allocator);
        errdefer mat_node_editor.deinit();

        // Create default camera
        const default_camera_id = try render_sys.addCamera(rendering.RenderingSystem.Camera.create(
            allocator,
            "Main Camera",
            raylib.Vector3{ .x = 0, .y = 5, .z = 10 },
            raylib.Vector3{ .x = 0, .y = 0, .z = 0 },
            45.0,
        ) catch unreachable);
        render_sys.setActiveCamera(default_camera_id);

        // Add default light
        _ = try render_sys.addLight(rendering.RenderingSystem.Light.createDirectional(
            raylib.Vector3{ .x = 0, .y = 10, .z = 0 },
            raylib.Vector3{ .x = 0, .y = -1, .z = 0 },
            raylib.Color.white,
            1.0,
        ));

        // Create default docking panels
        _ = try dock_sys.createPanel(
            .property_inspector,
            "Properties",
            raylib.Rectangle{ .x = screen_width - 300, .y = 40, .width = 300, .height = screen_height - 40 },
            null,
        );

        _ = try dock_sys.createPanel(
            .scene_outliner,
            "Scene Outliner",
            raylib.Rectangle{ .x = 0, .y = screen_height - 200, .width = 300, .height = 200 },
            null,
        );

        // Initialize TUI state
        var command_buffer = std.ArrayList(u8).init(allocator);
        errdefer command_buffer.deinit();

        var command_history = std.ArrayList([]const u8).init(allocator);
        errdefer command_history.deinit();

        var output_lines = std.ArrayList([]const u8).init(allocator);
        errdefer output_lines.deinit();

        // Add welcome message
        try output_lines.append(try allocator.dupe(u8, "Nyon Game Engine TUI v1.0"));
        try output_lines.append(try allocator.dupe(u8, "Type 'help' for available commands"));
        try output_lines.append(try allocator.dupe(u8, ""));

        return MainEditor{
            .allocator = allocator,
            .scene_system = scene_sys,
            .rendering_system = render_sys,
            .asset_manager = asset_mgr,
            .undo_redo_system = undo_redo_sys,
            .performance_system = perf_sys,
            .keyframe_system = keyframe_sys,
            .animation_system = anim_sys,
            .docking_system = dock_sys,
            .property_inspector = prop_inspector,
            .geometry_node_editor = geom_node_editor,
            .material_node_editor = mat_node_editor,
            .current_mode = .scene_editor,
            .screen_width = screen_width,
            .screen_height = screen_height,
            .selected_scene_object = null,
            .animation_timeline_visible = false,
            .animation_playback = false,
            .tui_command_buffer = command_buffer,
            .tui_command_history = command_history,
            .tui_output_lines = output_lines,
            .tui_cursor_pos = 0,
            .tui_history_index = -1,
        };
    }

    /// Deinitialize the main editor system
    pub fn deinit(self: *MainEditor) void {
        self.scene_system.deinit();
        self.rendering_system.deinit();
        self.asset_manager.deinit();
        self.undo_redo_system.deinit();
        self.performance_system.deinit();
        self.keyframe_system.deinit();
        self.animation_system.deinit();
        self.docking_system.deinit();
        self.property_inspector.deinit();
        self.geometry_node_editor.deinit();
        self.material_node_editor.deinit();

        // Clean up TUI resources
        self.tui_command_buffer.deinit();
        for (self.tui_command_history.items) |cmd| {
            self.allocator.free(cmd);
        }
        self.tui_command_history.deinit();
        for (self.tui_output_lines.items) |line| {
            self.allocator.free(line);
        }
        self.tui_output_lines.deinit();
    }

    /// Update the editor system
    pub fn update(self: *MainEditor, dt: f32) !void {
        // Update performance monitoring
        self.performance_system.updateCameras(dt);

        // Handle mode switching
        self.handleModeSwitching();

        // Update based on current mode
        switch (self.current_mode) {
            .scene_editor => try self.updateSceneEditor(dt),
            .geometry_nodes => self.updateGeometryNodeEditor(dt),
            .material_editor => self.updateMaterialEditor(dt),
            .animation_editor => try self.updateAnimationEditor(dt),
            .tui_mode => self.updateTUIMode(dt),
        }

        // Update animation systems
        self.keyframe_system.update(dt);
        if (self.animation_playback) {
            self.animation_system.update(dt);
        }

        // Update docking system
        self.handleDockingInput();

        // Update performance stats
        self.performance_system.resetStats();
    }

    /// Render the editor system
    pub fn render(self: *MainEditor) !void {
        // Render tab bar
        self.renderTabBar();

        // Render toolbar
        self.renderToolbar();

        // Render based on current mode
        const content_rect = raylib.Rectangle{
            .x = 0,
            .y = self.tab_bar_height + self.toolbar_height,
            .width = self.screen_width,
            .height = self.screen_height - self.tab_bar_height - self.toolbar_height - self.status_bar_height,
        };

        switch (self.current_mode) {
            .scene_editor => try self.renderSceneEditor(content_rect),
            .geometry_nodes => self.renderGeometryNodeEditor(content_rect),
            .material_editor => self.renderMaterialEditor(content_rect),
            .animation_editor => try self.renderAnimationEditor(content_rect),
            .tui_mode => self.renderTUIMode(content_rect),
        }

        // Render docking panels
        self.docking_system.render();

        // Render property inspector if active
        if (self.property_inspector.selected_object) |_| {
            const panel = self.docking_system.getPanel(0); // Properties panel
            if (panel) |p| {
                self.property_inspector.render(p.rect);
            }
        }

        // Render status bar
        self.renderStatusBar();

        // Render performance overlay
        self.renderPerformanceOverlay();
    }

    /// Handle input events
    pub fn handleInput(self: *MainEditor) !void {
        // Global shortcuts
        if (raylib.isKeyPressed(.z) and raylib.isKeyDown(.left_control)) {
            _ = self.undo_redo_system.undo();
        }
        if (raylib.isKeyPressed(.y) and raylib.isKeyDown(.left_control)) {
            _ = self.undo_redo_system.redo();
        }

        // Mode-specific input
        switch (self.current_mode) {
            .scene_editor => try self.handleSceneEditorInput(),
            .geometry_nodes => self.handleGeometryNodeInput(),
            .material_editor => self.handleMaterialEditorInput(),
            .animation_editor => try self.handleAnimationEditorInput(),
            .tui_mode => self.handleTUIInput(),
        }
    }

    fn renderToolbar(self: *MainEditor) void {
        const toolbar_y = self.tab_bar_height;
        const toolbar_rect = raylib.Rectangle{
            .x = 0,
            .y = toolbar_y,
            .width = self.screen_width,
            .height = self.toolbar_height,
        };

        // Toolbar background
        raylib.drawRectangleRec(toolbar_rect, raylib.Color{ .r = 50, .g = 50, .b = 60, .a = 255 });

        // Toolbar buttons based on current mode
        var button_x: f32 = 10;
        const button_spacing: f32 = 5;
        const button_height = self.toolbar_height - 6;
        const button_width: f32 = 80;

        switch (self.current_mode) {
            .scene_editor => {
                // Transform tools
                if (self.renderToolbarButton("Select", button_x, toolbar_y + 3, button_width, button_height)) {
                    // Select tool activated
                }
                button_x += button_width + button_spacing;

                if (self.renderToolbarButton("Move", button_x, toolbar_y + 3, button_width, button_height)) {
                    // Move tool activated
                }
                button_x += button_width + button_spacing;

                if (self.renderToolbarButton("Rotate", button_x, toolbar_y + 3, button_width, button_height)) {
                    // Rotate tool activated
                }
                button_x += button_width + button_spacing;

                if (self.renderToolbarButton("Scale", button_x, toolbar_y + 3, button_width, button_height)) {
                    // Scale tool activated
                }
            },
            .geometry_nodes => {
                if (self.renderToolbarButton("Add Node", button_x, toolbar_y + 3, button_width, button_height)) {
                    // Add node dialog
                }
                button_x += button_width + button_spacing;

                if (self.renderToolbarButton("Execute", button_x, toolbar_y + 3, button_width, button_height)) {
                    self.geometry_node_editor.executeGraph();
                }
            },
            .material_editor => {
                if (self.renderToolbarButton("New Material", button_x, toolbar_y + 3, button_width, button_height)) {
                    // New material
                }
            },
            .animation_editor => {
                if (self.renderToolbarButton("Play", button_x, toolbar_y + 3, button_width, button_height)) {
                    self.animation_playback = !self.animation_playback;
                }
                button_x += button_width + button_spacing;

                if (self.renderToolbarButton("Stop", button_x, toolbar_y + 3, button_width, button_height)) {
                    self.animation_playback = false;
                    // Reset to beginning
                }
            },
        }

        // Status text on the right
        const status_text = switch (self.current_mode) {
            .scene_editor => "3D Scene Editor - Ready",
            .geometry_nodes => "Geometry Node Editor - Ready",
            .material_editor => "Material Editor - Ready",
            .animation_editor => if (self.animation_playback) "Animation Editor - Playing" else "Animation Editor - Paused",
        };
        const status_x = self.screen_width - 200;
        raylib.drawText(status_text, @intFromFloat(status_x), @intFromFloat(toolbar_y + 8), 12, raylib.Color.white);
    }

    fn renderToolbarButton(self: *MainEditor, text: []const u8, x: f32, y: f32, width: f32, height: f32) bool {
        const mouse_pos = raylib.getMousePosition();
        const button_rect = raylib.Rectangle{ .x = x, .y = y, .width = width, .height = height };
        const hovered = raylib.checkCollisionPointRec(mouse_pos, button_rect);
        const clicked = hovered and raylib.isMouseButtonPressed(.left);

        const bg_color = if (hovered) raylib.Color{ .r = 70, .g = 70, .b = 90, .a = 255 } else raylib.Color{ .r = 60, .g = 60, .b = 80, .a = 255 };
        raylib.drawRectangleRec(button_rect, bg_color);
        raylib.drawText(text, @intFromFloat(x + 8), @intFromFloat(y + 6), 12, raylib.Color.white);

        return clicked;
    }

    // ============================================================================
    // TUI Mode
    // ============================================================================

    fn updateTUIMode(self: *MainEditor, _: f32) void {
        // TUI mode doesn't need continuous updates
        _ = self;
    }

    fn renderTUIMode(self: *MainEditor, content_rect: raylib.Rectangle) void {
        raylib.beginScissorMode(
            @intFromFloat(content_rect.x),
            @intFromFloat(content_rect.y),
            @intFromFloat(content_rect.width),
            @intFromFloat(content_rect.height),
        );

        // TUI background
        raylib.drawRectangleRec(content_rect, raylib.Color{ .r = 20, .g = 20, .b = 30, .a = 255 });

        // Render output lines
        const line_height: f32 = 20;
        const max_visible_lines = @as(usize, @intFromFloat(content_rect.height / line_height)) - 2; // Leave space for input

        var y: f32 = content_rect.y + 10;
        var start_line = if (self.tui_output_lines.items.len > max_visible_lines)
            self.tui_output_lines.items.len - max_visible_lines
        else
            0;

        for (self.tui_output_lines.items[start_line..]) |line| {
            raylib.drawText(line, @intFromFloat(content_rect.x + 10), @intFromFloat(y), 16, raylib.Color.white);
            y += line_height;
            if (y > content_rect.y + content_rect.height - 60) break; // Leave space for input
        }

        // Render command prompt
        const prompt_y = content_rect.y + content_rect.height - 40;
        raylib.drawText(">", @intFromFloat(content_rect.x + 10), @intFromFloat(prompt_y), 16, raylib.Color.green);

        // Render command buffer
        const command_text = self.tui_command_buffer.items;
        raylib.drawText(command_text, @intFromFloat(content_rect.x + 25), @intFromFloat(prompt_y), 16, raylib.Color.white);

        // Render cursor
        if (raylib.getTime() - @floor(raylib.getTime()) < 0.5) { // Blinking cursor
            const cursor_x = content_rect.x + 25 + @as(f32, @floatFromInt(self.tui_cursor_pos)) * 8.5; // Approximate character width
            raylib.drawLine(@intFromFloat(cursor_x), @intFromFloat(prompt_y), @intFromFloat(cursor_x), @intFromFloat(prompt_y + 16), raylib.Color.white);
        }

        raylib.endScissorMode();
    }

    fn handleTUIInput(self: *MainEditor) void {
        // Handle text input
        const char = raylib.getCharPressed();
        if (char != 0) {
            if (self.tui_cursor_pos < self.tui_command_buffer.items.len) {
                self.tui_command_buffer.insert(self.tui_cursor_pos, @as(u8, @intCast(char))) catch return;
            } else {
                self.tui_command_buffer.append(@as(u8, @intCast(char))) catch return;
            }
            self.tui_cursor_pos += 1;
        }

        // Handle special keys
        if (raylib.isKeyPressed(.backspace)) {
            if (self.tui_cursor_pos > 0) {
                _ = self.tui_command_buffer.orderedRemove(self.tui_cursor_pos - 1);
                self.tui_cursor_pos -= 1;
            }
        }

        if (raylib.isKeyPressed(.enter)) {
            self.executeTUICommand();
        }

        if (raylib.isKeyPressed(.up)) {
            if (self.tui_history_index < @as(i32, @intCast(self.tui_command_history.items.len)) - 1) {
                self.tui_history_index += 1;
                const history_cmd = self.tui_command_history.items[self.tui_command_history.items.len - 1 - @as(usize, @intCast(self.tui_history_index))];
                self.tui_command_buffer.clearRetainingCapacity();
                self.tui_command_buffer.appendSlice(history_cmd) catch return;
                self.tui_cursor_pos = history_cmd.len;
            }
        }

        if (raylib.isKeyPressed(.down)) {
            if (self.tui_history_index > 0) {
                self.tui_history_index -= 1;
                const history_cmd = self.tui_command_history.items[self.tui_command_history.items.len - 1 - @as(usize, @intCast(self.tui_history_index))];
                self.tui_command_buffer.clearRetainingCapacity();
                self.tui_command_buffer.appendSlice(history_cmd) catch return;
                self.tui_cursor_pos = history_cmd.len;
            } else if (self.tui_history_index == 0) {
                self.tui_history_index = -1;
                self.tui_command_buffer.clearRetainingCapacity();
                self.tui_cursor_pos = 0;
            }
        }

        // Handle left/right arrow keys for cursor movement
        if (raylib.isKeyPressed(.left)) {
            if (self.tui_cursor_pos > 0) {
                self.tui_cursor_pos -= 1;
            }
        }
        if (raylib.isKeyPressed(.right)) {
            if (self.tui_cursor_pos < self.tui_command_buffer.items.len) {
                self.tui_cursor_pos += 1;
            }
        }
    }

    fn executeTUICommand(self: *MainEditor) void {
        const command = self.tui_command_buffer.items;
        if (command.len == 0) return;

        // Add command to history
        const cmd_copy = self.allocator.dupe(u8, command) catch return;
        self.tui_command_history.append(cmd_copy) catch {
            self.allocator.free(cmd_copy);
            return;
        };

        // Add command to output
        var output_line = std.ArrayList(u8).initCapacity(self.allocator, command.len + 3) catch return;
        defer output_line.deinit();
        output_line.appendSlice("> ") catch return;
        output_line.appendSlice(command) catch return;
        const output_cmd = output_line.toOwnedSlice() catch return;
        self.tui_output_lines.append(output_cmd) catch {
            self.allocator.free(output_cmd);
        };

        // Execute command
        if (std.mem.eql(u8, command, "help")) {
            self.addTUIOutput("Available commands:");
            self.addTUIOutput("  help          - Show this help");
            self.addTUIOutput("  clear         - Clear terminal");
            self.addTUIOutput("  mode scene    - Switch to scene editor");
            self.addTUIOutput("  mode geometry - Switch to geometry nodes");
            self.addTUIOutput("  mode material - Switch to material editor");
            self.addTUIOutput("  mode animation- Switch to animation editor");
            self.addTUIOutput("  mode tui      - Stay in TUI mode");
            self.addTUIOutput("  exit          - Exit application");
        } else if (std.mem.eql(u8, command, "clear")) {
            for (self.tui_output_lines.items) |line| {
                self.allocator.free(line);
            }
            self.tui_output_lines.clearRetainingCapacity();
            self.addTUIOutput("Terminal cleared");
        } else if (std.mem.startsWith(u8, command, "mode ")) {
            const mode_arg = command[5..];
            if (std.mem.eql(u8, mode_arg, "scene")) {
                self.current_mode = .scene_editor;
                self.addTUIOutput("Switched to Scene Editor");
            } else if (std.mem.eql(u8, mode_arg, "geometry")) {
                self.current_mode = .geometry_nodes;
                self.addTUIOutput("Switched to Geometry Nodes");
            } else if (std.mem.eql(u8, mode_arg, "material")) {
                self.current_mode = .material_editor;
                self.addTUIOutput("Switched to Material Editor");
            } else if (std.mem.eql(u8, mode_arg, "animation")) {
                self.current_mode = .animation_editor;
                self.addTUIOutput("Switched to Animation Editor");
            } else if (std.mem.eql(u8, mode_arg, "tui")) {
                self.addTUIOutput("Already in TUI mode");
            } else {
                self.addTUIOutput("Unknown mode. Use: scene, geometry, material, animation, tui");
            }
        } else if (std.mem.eql(u8, command, "exit")) {
            // This would need to be handled at a higher level
            self.addTUIOutput("Use Ctrl+C or close window to exit");
        } else {
            var unknown_msg = std.ArrayList(u8).initCapacity(self.allocator, command.len + 20) catch return;
            defer unknown_msg.deinit();
            unknown_msg.appendSlice("Unknown command: ") catch return;
            unknown_msg.appendSlice(command) catch return;
            const unknown_str = unknown_msg.toOwnedSlice() catch return;
            self.tui_output_lines.append(unknown_str) catch {
                self.allocator.free(unknown_str);
            };
        }

        // Clear command buffer
        self.tui_command_buffer.clearRetainingCapacity();
        self.tui_cursor_pos = 0;
        self.tui_history_index = -1;
    }

    fn addTUIOutput(self: *MainEditor, text: []const u8) void {
        const output_line = self.allocator.dupe(u8, text) catch return;
        self.tui_output_lines.append(output_line) catch {
            self.allocator.free(output_line);
        };
    }

    fn renderStatusBar(self: *MainEditor) void {
        const status_bar_y = self.screen_height - self.status_bar_height;
        const status_bar_rect = raylib.Rectangle{
            .x = 0,
            .y = status_bar_y,
            .width = self.screen_width,
            .height = self.status_bar_height,
        };

        // Status bar background
        raylib.drawRectangleRec(status_bar_rect, raylib.Color{ .r = 40, .g = 40, .b = 50, .a = 255 });

        // Left side: mode info
        const mode_text = switch (self.current_mode) {
            .scene_editor => "Scene Editor",
            .geometry_nodes => "Geometry Nodes",
            .material_editor => "Material Editor",
            .animation_editor => "Animation Editor",
        };
        raylib.drawText(mode_text, 10, @intFromFloat(status_bar_y + 6), 12, raylib.Color.white);

        // Right side: performance info
        var perf_buf: [64]u8 = undefined;
        const fps_text = std.fmt.bufPrint(&perf_buf, "FPS: {}", .{raylib.getFPS()}) catch "FPS: ?";
        const fps_x = self.screen_width - 80;
        raylib.drawText(fps_text, @intFromFloat(fps_x), @intFromFloat(status_bar_y + 6), 12, raylib.Color.white);
    }

    // ============================================================================
    // Mode Switching
    // ============================================================================

    fn handleModeSwitching(self: *MainEditor) void {
        const mouse_pos = raylib.getMousePosition();
        const mouse_pressed = raylib.isMouseButtonPressed(.left);

        if (mouse_pressed and mouse_pos.y <= self.tab_bar_height) {
            const tab_width = self.screen_width / 4;
            const tab_index = @as(usize, @intFromFloat(mouse_pos.x / tab_width));

            self.current_mode = switch (tab_index) {
                0 => .geometry_nodes,
                1 => .scene_editor,
                2 => .material_editor,
                3 => .animation_editor,
                4 => .tui_mode,
                else => self.current_mode,
            };
        }
    }

    fn renderTabBar(self: *MainEditor) void {
        // Background
        raylib.drawRectangle(0, 0, @intFromFloat(self.screen_width), @intFromFloat(self.tab_bar_height), raylib.Color{ .r = 40, .g = 40, .b = 50, .a = 255 });

        const tab_names = [_][:0]const u8{ "Geometry Nodes", "Scene Editor", "Material Editor", "Animation Editor", "TUI" };
        const tab_width = self.screen_width / @as(f32, @floatFromInt(tab_names.len));

        for (tab_names, 0..) |name, i| {
            const x = @as(f32, @floatFromInt(i)) * tab_width;
            const tab_rect = raylib.Rectangle{ .x = x, .y = 0, .width = tab_width, .height = self.tab_bar_height };

            const is_active = @intFromEnum(self.current_mode) == i;
            const bg_color = if (is_active) raylib.Color{ .r = 60, .g = 60, .b = 80, .a = 255 } else raylib.Color{ .r = 50, .g = 50, .b = 60, .a = 255 };

            raylib.drawRectangleRec(tab_rect, bg_color);
            raylib.drawText(name, @intFromFloat(x + 10), 10, 16, raylib.Color.white);
        }
    }

    // ============================================================================
    // Scene Editor Mode
    // ============================================================================

    fn updateSceneEditor(self: *MainEditor, dt: f32) !void {
        // Update camera controls
        if (self.rendering_system.getActiveCamera()) |camera| {
            camera.update(dt);

            // Handle camera orbit controls
            if (raylib.isMouseButtonDown(.right)) {
                const delta = raylib.getMouseDelta();
                const distance = raylib.vector3Distance(camera.camera.target, camera.camera.position);

                camera.orbit(
                    camera.camera.target,
                    distance,
                    camera.camera.position.x + delta.x * 0.01,
                    camera.camera.position.y + delta.y * 0.01,
                );
            }

            // Handle zoom
            const wheel = raylib.getMouseWheelMove();
            if (wheel != 0) {
                camera.zoom(1.0 + wheel * 0.1);
            }
        }

        // Update scene raycasting for selection
        if (raylib.isMouseButtonPressed(.left) and !self.isMouseOverUI()) {
            const ray = raylib.getMouseRay(raylib.getMousePosition(), self.rendering_system.getActiveCamera().?.camera);
            if (self.scene_system.raycast(ray)) |hit| {
                self.selected_scene_object = hit.model_index;
                self.property_inspector.setSelectedObject(.{ .scene_node = hit.model_index });
            } else {
                self.selected_scene_object = null;
                self.property_inspector.setSelectedObject(null);
            }
        }
    }

    fn renderSceneEditor(self: *MainEditor, content_rect: raylib.Rectangle) !void {
        // 3D scene rendering
        raylib.beginScissorMode(
            @intFromFloat(content_rect.x),
            @intFromFloat(content_rect.y),
            @intFromFloat(content_rect.width),
            @intFromFloat(content_rect.height),
        );

        self.rendering_system.beginRendering();

        // Clear background
        raylib.clearBackground(raylib.Color{ .r = 30, .g = 30, .b = 40, .a = 255 });

        // Render scene
        self.scene_system.render();

        // Render lights
        self.rendering_system.renderLights();

        // Render grid
        self.drawGrid();

        // Highlight selected object
        if (self.selected_scene_object) |obj_id| {
            if (self.scene_system.getModelInfo(obj_id)) |info| {
                // Draw selection outline (simplified)
                raylib.drawCubeWires(info.position, 1.1, 1.1, 1.1, raylib.Color.yellow);
            }
        }

        self.rendering_system.endRendering();
        raylib.endScissorMode();

        // Render UI overlays
        self.renderSceneUI();
    }

    fn handleSceneEditorInput(self: *MainEditor) !void {
        // Object manipulation
        if (self.selected_scene_object) |obj_id| {
            if (self.scene_system.getModelInfo(obj_id)) |info| {
                var transform_changed = false;
                var new_pos = info.position;
                var new_rot = info.rotation;
                var new_scale = info.scale;

                // Translation controls (simplified)
                if (raylib.isKeyDown(.w)) {
                    new_pos.z -= 0.1;
                    transform_changed = true;
                }
                if (raylib.isKeyDown(.s)) {
                    new_pos.z += 0.1;
                    transform_changed = true;
                }
                if (raylib.isKeyDown(.a)) {
                    new_pos.x -= 0.1;
                    transform_changed = true;
                }
                if (raylib.isKeyDown(.d)) {
                    new_pos.x += 0.1;
                    transform_changed = true;
                }
                if (raylib.isKeyDown(.q)) {
                    new_pos.y += 0.1;
                    transform_changed = true;
                }
                if (raylib.isKeyDown(.e)) {
                    new_pos.y -= 0.1;
                    transform_changed = true;
                }

                if (transform_changed) {
                    self.scene_system.setPosition(obj_id, new_pos);
                    self.scene_system.setRotation(obj_id, new_rot);
                    self.scene_system.setScale(obj_id, new_scale);
                }
            }
        }
    }

    fn renderSceneUI(self: *MainEditor) void {
        var ui_y: f32 = self.tab_bar_height + 10;

        // Scene info
        var buf: [64]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "Objects: {}", .{self.scene_system.modelCount()}) catch "Objects: ?";
        raylib.drawText(text[0..text.len :0], 10, @intFromFloat(ui_y), 16, raylib.Color.white);
        ui_y += 20;

        if (self.selected_scene_object) |id| {
            const sel_text = std.fmt.bufPrint(&buf, "Selected: Object {}", .{id}) catch "Selected: ?";
            raylib.drawText(sel_text[0..sel_text.len :0], 10, @intFromFloat(ui_y), 16, raylib.Color.yellow);
        }
    }

    // ============================================================================
    // Geometry Node Editor Mode
    // ============================================================================

    fn updateGeometryNodeEditor(self: *MainEditor, _: f32) void {
        // Update geometry node editor
        const mouse_pos = raylib.getMousePosition();
        const mouse_pressed = raylib.isMouseButtonPressed(.left);
        const mouse_down = raylib.isMouseButtonDown(.left);
        const key_delete = raylib.isKeyPressed(.delete) or raylib.isKeyPressed(.backspace);

        // Convert to editor coordinates (assuming left side for now)
        const editor_offset_x = 0;
        self.geometry_node_editor.updateNodeEditor(mouse_pos, mouse_pressed, mouse_down, key_delete, editor_offset_x);
    }

    fn renderGeometryNodeEditor(self: *MainEditor, content_rect: raylib.Rectangle) void {
        // Create a more sophisticated layout with panels
        const panel_margin: f32 = 5;
        const panel_header_height: f32 = 25;

        // Left panel: 3D Preview (40%)
        const preview_width = content_rect.width * 0.4;
        const left_panel_rect = raylib.Rectangle{
            .x = content_rect.x + panel_margin,
            .y = content_rect.y + panel_margin,
            .width = preview_width - panel_margin * 2,
            .height = content_rect.height - panel_margin * 2,
        };

        // Right panel: Node Editor (60%)
        const right_panel_rect = raylib.Rectangle{
            .x = content_rect.x + preview_width + panel_margin,
            .y = content_rect.y + panel_margin,
            .width = content_rect.width - preview_width - panel_margin * 2,
            .height = content_rect.height - panel_margin * 2,
        };

        // Render left panel (3D Preview)
        self.renderGeometryPreviewPanel(left_panel_rect);

        // Render right panel (Node Editor)
        self.renderGeometryNodePanel(right_panel_rect);
    }

    fn renderGeometryPreviewPanel(self: *MainEditor, panel_rect: raylib.Rectangle) void {
        // Panel background
        raylib.drawRectangleRec(panel_rect, raylib.Color{ .r = 35, .g = 35, .b = 45, .a = 255 });
        raylib.drawRectangleLinesEx(panel_rect, 1, raylib.Color{ .r = 60, .g = 60, .b = 70, .a = 255 });

        // Panel header
        const header_rect = raylib.Rectangle{
            .x = panel_rect.x,
            .y = panel_rect.y,
            .width = panel_rect.width,
            .height = 25,
        };
        raylib.drawRectangleRec(header_rect, raylib.Color{ .r = 45, .g = 45, .b = 55, .a = 255 });
        raylib.drawText("3D Preview", @intFromFloat(panel_rect.x + 8), @intFromFloat(panel_rect.y + 6), 14, raylib.Color.white);

        // 3D content area
        const content_rect = raylib.Rectangle{
            .x = panel_rect.x + 2,
            .y = panel_rect.y + 27,
            .width = panel_rect.width - 4,
            .height = panel_rect.height - 29,
        };

        raylib.beginScissorMode(
            @intFromFloat(content_rect.x),
            @intFromFloat(content_rect.y),
            @intFromFloat(content_rect.width),
            @intFromFloat(content_rect.height),
        );

        self.rendering_system.beginRendering();
        raylib.clearBackground(raylib.Color{ .r = 25, .g = 25, .b = 35, .a = 255 });

        // Render geometry from nodes
        if (self.geometry_node_editor.getFinalGeometry()) |mesh| {
            const model = raylib.loadModelFromMesh(mesh) catch return;
            defer raylib.unloadModel(model);
            raylib.drawModel(model, raylib.Vector3{ .x = 0, .y = 0, .z = 0 }, 1.0, raylib.Color.white);
            raylib.drawModelWires(model, raylib.Vector3{ .x = 0, .y = 0, .z = 0 }, 1.0, raylib.Color.gray);
        }

        self.drawGrid();
        self.rendering_system.endRendering();
        raylib.endScissorMode();
    }

    fn renderGeometryNodePanel(self: *MainEditor, panel_rect: raylib.Rectangle) void {
        // Panel background
        raylib.drawRectangleRec(panel_rect, raylib.Color{ .r = 35, .g = 35, .b = 45, .a = 255 });
        raylib.drawRectangleLinesEx(panel_rect, 1, raylib.Color{ .r = 60, .g = 60, .b = 70, .a = 255 });

        // Panel header with controls
        const header_rect = raylib.Rectangle{
            .x = panel_rect.x,
            .y = panel_rect.y,
            .width = panel_rect.width,
            .height = 25,
        };
        raylib.drawRectangleRec(header_rect, raylib.Color{ .r = 45, .g = 45, .b = 55, .a = 255 });
        raylib.drawText("Node Editor", @intFromFloat(panel_rect.x + 8), @intFromFloat(panel_rect.y + 6), 14, raylib.Color.white);

        // Node editor content area
        const content_rect = raylib.Rectangle{
            .x = panel_rect.x + 2,
            .y = panel_rect.y + 27,
            .width = panel_rect.width - 4,
            .height = panel_rect.height - 29,
        };

        raylib.beginScissorMode(
            @intFromFloat(content_rect.x),
            @intFromFloat(content_rect.y),
            @intFromFloat(content_rect.width),
            @intFromFloat(content_rect.height),
        );

        self.geometry_node_editor.renderNodeEditor(content_rect.width, content_rect.height);
        raylib.endScissorMode();
    }

    fn handleGeometryNodeInput(self: *MainEditor) void {
        // Geometry node specific shortcuts
        if (raylib.isKeyPressed(.space)) {
            self.geometry_node_editor.executeGraph();
        }
    }

    // ============================================================================
    // Material Editor Mode
    // ============================================================================

    fn updateMaterialEditor(self: *MainEditor, _: f32) void {
        // Update material node editor (simplified)
        self.material_node_editor.update();
    }

    fn renderMaterialEditor(self: *MainEditor, content_rect: raylib.Rectangle) void {
        raylib.beginScissorMode(
            @intFromFloat(content_rect.x),
            @intFromFloat(content_rect.y),
            @intFromFloat(content_rect.width),
            @intFromFloat(content_rect.height),
        );

        // Render material node editor
        self.material_node_editor.render(content_rect.width, content_rect.height);
        raylib.endScissorMode();
    }

    fn handleMaterialEditorInput(self: *MainEditor) void {
        // Material editor specific input
        _ = self;
    }

    // ============================================================================
    // Animation Editor Mode
    // ============================================================================

    fn updateAnimationEditor(self: *MainEditor, dt: f32) !void {
        // Update animation timeline
        if (self.animation_timeline_visible) {
            // Timeline controls
            if (raylib.isKeyPressed(.space)) {
                self.animation_playback = !self.animation_playback;
            }
        }

        // Update animation systems
        self.keyframe_system.update(dt);
        if (self.animation_playback) {
            self.animation_system.update(dt);
            self.keyframe_system.applyToScene(&self.scene_system);
        }
    }

    fn renderAnimationEditor(self: *MainEditor, content_rect: raylib.Rectangle) !void {
        raylib.beginScissorMode(
            @intFromFloat(content_rect.x),
            @intFromFloat(content_rect.y),
            @intFromFloat(content_rect.width),
            @intFromFloat(content_rect.height),
        );

        // Render 3D scene (top half)
        const scene_height = content_rect.height * 0.6;
        raylib.beginScissorMode(
            @intFromFloat(content_rect.x),
            @intFromFloat(content_rect.y),
            @intFromFloat(content_rect.width),
            @intFromFloat(scene_height),
        );

        self.rendering_system.beginRendering();
        raylib.clearBackground(raylib.Color{ .r = 25, .g = 25, .b = 35, .a = 255 });
        self.scene_system.render();
        self.drawGrid();
        self.rendering_system.endRendering();
        raylib.endScissorMode();

        // Render timeline (bottom half)
        raylib.beginScissorMode(
            @intFromFloat(content_rect.x),
            @intFromFloat(content_rect.y + scene_height),
            @intFromFloat(content_rect.width),
            @intFromFloat(content_rect.height - scene_height),
        );

        self.renderAnimationTimeline(content_rect.width, content_rect.height - scene_height);
        raylib.endScissorMode();

        raylib.endScissorMode();
    }

    fn handleAnimationEditorInput(self: *MainEditor) !void {
        // Animation editor specific input
        if (raylib.isKeyPressed(.t)) {
            self.animation_timeline_visible = !self.animation_timeline_visible;
        }
    }

    fn renderAnimationTimeline(self: *MainEditor, width: f32, height: f32) void {
        // Timeline background
        raylib.drawRectangle(0, 0, @intFromFloat(width), @intFromFloat(height), raylib.Color{ .r = 35, .g = 35, .b = 45, .a = 255 });

        // Timeline header
        raylib.drawRectangle(0, 0, @intFromFloat(width), 30, raylib.Color{ .r = 45, .g = 45, .b = 55, .a = 255 });
        raylib.drawText("Animation Timeline", 10, 8, 16, raylib.Color.white);

        // Play/pause button
        const play_color = if (self.animation_playback) raylib.Color.green else raylib.Color.gray;
        raylib.drawRectangle(@intFromFloat(width - 60), 5, 25, 20, play_color);
        const play_text = if (self.animation_playback) "PAUSE" else "PLAY";
        raylib.drawText(play_text.ptr, @intFromFloat(width - 50), 8, 14, raylib.Color.white);

        const total_duration = self.keyframe_system.timeline.total_duration;
        if (total_duration > 0) {
            // Current time indicator
            const time_x = (self.keyframe_system.timeline.current_time / total_duration) * (width - 100) + 50;
            raylib.drawLine(@intFromFloat(time_x), 30, @intFromFloat(time_x), @intFromFloat(height), raylib.Color.red);

            // Time markers
            var t: f32 = 0;
            while (t <= total_duration) : (t += 1.0) {
                const marker_x = (t / total_duration) * (width - 100) + 50;
                raylib.drawLine(@intFromFloat(marker_x), @intFromFloat(height - 10), @intFromFloat(marker_x), @intFromFloat(height), raylib.Color.gray);
            }
        }

        // Track lanes
        var track_y: f32 = 35;
        for (self.keyframe_system.tracks.items) |*track| {
            raylib.drawRectangle(0, @intFromFloat(track_y), @intFromFloat(width), 25, raylib.Color{ .r = 40, .g = 40, .b = 50, .a = 255 });
            var buf: [64]u8 = undefined;
            const track_name = std.fmt.bufPrint(&buf, "{s}", .{track.name}) catch "Track";
            raylib.drawText(track_name.ptr, 10, @intFromFloat(track_y + 5), 12, raylib.Color.white);

            // Render keyframes
            if (total_duration > 0) {
                for (track.keyframes.items) |keyframe| {
                    const key_x = (keyframe.time / total_duration) * (width - 100) + 50;
                    raylib.drawCircle(@intFromFloat(key_x), @intFromFloat(track_y + 12), 3, raylib.Color.yellow);
                }
            }

            track_y += 25;
        }
    }

    // ============================================================================
    // Utility Functions
    // ============================================================================

    fn handleDockingInput(self: *MainEditor) void {
        const mouse_pos = raylib.getMousePosition();
        const mouse_delta = raylib.getMouseDelta();

        self.docking_system.handleMouseInteraction(mouse_pos, mouse_delta);

        if (raylib.isMouseButtonReleased(.left)) {
            self.docking_system.endDrag();
        }
    }

    fn isMouseOverUI(self: *MainEditor) bool {
        const mouse_pos = raylib.getMousePosition();
        return mouse_pos.y <= self.tab_bar_height;
    }

    fn drawGrid(self: *MainEditor) void {
        const grid_size = 20;
        const half_size = 10;

        var i: i32 = -half_size;
        while (i <= half_size) : (i += 1) {
            // X lines
            raylib.drawLine3D(
                raylib.Vector3{ .x = @as(f32, @floatFromInt(i)), .y = 0, .z = @as(f32, @floatFromInt(-half_size)) },
                raylib.Vector3{ .x = @as(f32, @floatFromInt(i)), .y = 0, .z = @as(f32, @floatFromInt(half_size)) },
                raylib.Color{ .r = 80, .g = 80, .b = 80, .a = 100 },
            );
            // Z lines
            raylib.drawLine3D(
                raylib.Vector3{ .x = @as(f32, @floatFromInt(-half_size)), .y = 0, .z = @as(f32, @floatFromInt(i)) },
                raylib.Vector3{ .x = @as(f32, @floatFromInt(half_size)), .y = 0, .z = @as(f32, @floatFromInt(i)) },
                raylib.Color{ .r = 80, .g = 80, .b = 80, .a = 100 },
            );
        }
    }

    fn renderPerformanceOverlay(self: *MainEditor) void {
        const fps = raylib.getFPS();

        var buf: [128]u8 = undefined;
        const perf_text = std.fmt.bufPrint(&buf, "FPS: {}", .{fps}) catch "Performance";
        raylib.drawText(perf_text.ptr, @intFromFloat(self.screen_width - 200), 10, 14, raylib.Color.yellow);
    }
};

// ============================================================================
// Material Node Editor (Simplified)
// ============================================================================

/// Node-based material editor
pub const MaterialNodeEditor = struct {
    allocator: std.mem.Allocator,
    graph: nodes.NodeGraph,

    pub fn init(allocator: std.mem.Allocator) !MaterialNodeEditor {
        return MaterialNodeEditor{
            .allocator = allocator,
            .graph = nodes.NodeGraph.init(allocator),
        };
    }

    pub fn deinit(self: *MaterialNodeEditor) void {
        self.graph.deinit();
    }

    pub fn update(self: *MaterialNodeEditor) void {
        _ = self; // Simplified
    }

    pub fn render(self: *MaterialNodeEditor, width: f32, height: f32) void {
        // Background
        raylib.drawRectangle(0, 0, @intFromFloat(width), @intFromFloat(height), raylib.Color{ .r = 30, .g = 30, .b = 40, .a = 255 });

        // Placeholder text
        raylib.drawText("Material Node Editor", @intFromFloat(width / 2 - 100), @intFromFloat(height / 2 - 10), 20, raylib.Color.gray);
        raylib.drawText("(Under Development)", @intFromFloat(width / 2 - 80), @intFromFloat(height / 2 + 15), 16, raylib.Color.gray);
    }
};
