//! Core Editor Coordination for Nyon Game Engine
//!
//! This module provides the central editor coordination system,
//! managing subsystems and delegating to mode-specific implementations.

const std = @import("std");
const raylib = @import("raylib");

// ============================================================================
// Imports and Dependencies
// ============================================================================

const engine = @import("../engine.zig");
const scene = @import("../scene.zig");
const material = @import("../material.zig");
const rendering = @import("../rendering.zig");
const animation = @import("../animation.zig");
const keyframe = @import("../keyframe.zig");
const asset = @import("../asset.zig");
const undo_redo = @import("../undo_redo.zig");
const performance = @import("../performance.zig");
const nodes = @import("../nodes/node_graph.zig");
const geometry_nodes = @import("../geometry_nodes.zig");
const docking = @import("../docking.zig");
const property_inspector = @import("../property_inspector.zig");
const post_processing = @import("../post_processing.zig");
const editor_tabs = @import("../editor_tabs.zig");
const ui_context = @import("../ui_context.zig");
const gizmo_system = @import("../gizmo_system.zig");
const tool_system = @import("../tool_system.zig");

// Mode-specific implementations
const scene_editor_mod = @import("scene_editor.zig");
const tui_mode_mod = @import("tui_mode.zig");

// ============================================================================
// Core Editor System
// ============================================================================

/// Main Editor structure for the Nyon Game Engine.
/// This structure acts as the core owner and coordinator of all major editor subsystems.
pub const MainEditor = struct {
    /// Allocator for all editor memory needs.
    allocator: std.mem.Allocator,
    /// Engine-level subsystems.
    scene_system: scene.Scene,
    rendering_system: rendering.RenderingSystem,
    asset_manager: asset.AssetManager,
    undo_redo_system: undo_redo.UndoRedoSystem,
    performance_system: performance.PerformanceSystem,
    keyframe_system: keyframe.KeyframeSystem,
    animation_system: animation.AnimationSystem,

    /// Editor UI systems.
    docking_system: docking.DockingSystem,
    property_inspector: property_inspector.PropertyInspector,

    /// Node/graph based editor subsystems.
    geometry_node_editor: geometry_nodes.GeometryNodeSystem,
    material_node_editor: MaterialNodeEditor,

    /// Which functional editor mode is currently active.
    current_mode: EditorMode,

    /// Main window and UI layout dimensions.
    screen_width: f32,
    screen_height: f32,
    tab_bar_height: f32 = 40,
    toolbar_height: f32 = 35,
    status_bar_height: f32 = 25,

    /// Selected object in the 3D scene.
    selected_scene_object: ?usize,

    /// Animation editor state.
    animation_timeline_visible: bool = false,
    animation_playback: bool = false,

    /// Scene editor state
    scene_editor: scene_editor_mod.SceneEditor,

    /// TUI mode state
    tui_mode: tui_mode_mod.TUIMode,

    /// Modes supported by the main editor.
    pub const EditorMode = enum {
        geometry_nodes, // Node-based geometry system ("Geometry Nodes")
        scene_editor, // The main 3D scene editor
        material_editor, // Node graph for editing PBR materials
        animation_editor, // Timeline-based 3D animation editing
        tui_mode, // Terminal-like in-editor command line UI
    };

    /// Create and fully initialize a MainEditor, including all system dependencies.
    pub fn init(
        allocator: std.mem.Allocator,
        screen_width: f32,
        screen_height: f32,
    ) !MainEditor {
        // Engine and subsystems initialization.
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

        // Editor UI system initialization.
        var dock_sys = docking.DockingSystem.init(allocator, screen_width, screen_height);
        errdefer dock_sys.deinit();
        var prop_inspector = property_inspector.PropertyInspector.init(allocator);
        errdefer prop_inspector.deinit();

        // Node-based editors.
        var geom_node_editor = try geometry_nodes.GeometryNodeSystem.init(allocator);
        errdefer geom_node_editor.deinit();
        var mat_node_editor = try MaterialNodeEditor.init(allocator);
        errdefer mat_node_editor.deinit();

        // Default camera and light setup.
        const default_camera_id = try render_sys.addCamera(rendering.RenderingSystem.Camera.create(
            allocator,
            "Main Camera",
            raylib.Vector3{ .x = 0, .y = 5, .z = 10 },
            raylib.Vector3{ .x = 0, .y = 0, .z = 0 },
            45.0,
        ) catch unreachable);
        render_sys.setActiveCamera(default_camera_id);
        _ = try render_sys.addLight(rendering.RenderingSystem.Light.createDirectional(
            raylib.Vector3{ .x = 0, .y = 10, .z = 0 },
            raylib.Vector3{ .x = 0, .y = -1, .z = 0 },
            raylib.Color.white,
            1.0,
        ));

        // Initial docking panel definitions. @Browser
        _ = try dock_sys.createPanel(.property_inspector, "Properties", raylib.Rectangle{ .x = screen_width - 300, .y = 40, .width = 300, .height = screen_height - 40 }, null);
        _ = try dock_sys.createPanel(.scene_outliner, "Scene Outliner", raylib.Rectangle{ .x = 0, .y = screen_height - 200, .width = 300, .height = 200 }, null);

        // Initialize mode-specific state
        var scene_editor_state = try scene_editor_mod.SceneEditor.init(allocator);
        errdefer scene_editor_state.deinit();

        var tui_mode_state = try tui_mode_mod.TUIMode.init(allocator);
        errdefer tui_mode_state.deinit();

        // Construct the editor with all systems.
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
            .scene_editor = scene_editor_state,
            .tui_mode = tui_mode_state,
        };
    }

    /// Properly clean up all systems and editor memory.
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

        self.scene_editor.deinit();
        self.tui_mode.deinit();
    }

    /// Main update loop: calls the active mode's update, handles mode switches, etc.
    pub fn update(self: *MainEditor, dt: f32) !void {
        self.performance_system.updateCameras(dt);

        self.handleModeSwitching();

        switch (self.current_mode) {
            .scene_editor => try self.scene_editor.update(self, dt),
            .geometry_nodes => self.updateGeometryNodeEditor(dt),
            .material_editor => self.updateMaterialEditor(dt),
            .animation_editor => try self.updateAnimationEditor(dt),
            .tui_mode => self.tui_mode.update(self, dt),
        }

        self.keyframe_system.update(dt);
        if (self.animation_playback) self.animation_system.update(dt);

        self.handleDockingInput();
        self.performance_system.resetStats();
    }

    /// Renders the main editor UI and invokes content/mode rendering as needed.
    pub fn render(self: *MainEditor) !void {
        self.renderTabBar();
        self.renderToolbar();

        // Browser Content Rectangle definition.
        const content_rect = raylib.Rectangle{
            .x = 0,
            .y = self.tab_bar_height + self.toolbar_height,
            .width = self.screen_width,
            .height = self.screen_height - self.tab_bar_height - self.toolbar_height - self.status_bar_height,
        };

        switch (self.current_mode) {
            .scene_editor => try self.scene_editor.render(self, content_rect),
            .geometry_nodes => self.renderGeometryNodeEditor(content_rect),
            .material_editor => self.renderMaterialEditor(content_rect),
            .animation_editor => try self.renderAnimationEditor(content_rect),
            .tui_mode => self.tui_mode.render(self, content_rect),
        }

        self.docking_system.render();

        // Render property inspector only if an object is selected and the inspect panel exists.
        if (self.selected_scene_object) |selected_id| {
            if (self.docking_system.findPanel(.property_inspector)) |panel| {
                self.property_inspector.render(panel.rect, selected_id);
            }
        }

        self.renderStatusBar();
        self.renderPerformanceOverlay();
    }

    /// Handle keyboard shortcuts for switching between editor modes.
    fn handleModeSwitching(self: *MainEditor) void {
        if (raylib.isKeyPressed(raylib.KeyboardKey.f1)) {
            self.current_mode = .scene_editor;
        } else if (raylib.isKeyPressed(raylib.KeyboardKey.f2)) {
            self.current_mode = .geometry_nodes;
        } else if (raylib.isKeyPressed(raylib.KeyboardKey.f3)) {
            self.current_mode = .material_editor;
        } else if (raylib.isKeyPressed(raylib.KeyboardKey.f4)) {
            self.current_mode = .animation_editor;
        } else if (raylib.isKeyPressed(raylib.KeyboardKey.f5)) {
            self.current_mode = .tui_mode;
        }
    }

    /// Handle input for the docking system.
    fn handleDockingInput(self: *MainEditor) void {
        const mouse_pos = raylib.getMousePosition();
        const mouse_pressed = raylib.isMouseButtonPressed(raylib.MouseButton.left);
        const mouse_down = raylib.isMouseButtonDown(raylib.MouseButton.left);

        self.docking_system.handleInput(mouse_pos, mouse_pressed, mouse_down);
    }

    /// Render the tab bar at the top of the editor.
    fn renderTabBar(self: *MainEditor) void {
        // Tab bar background
        raylib.drawRectangle(0, 0, @intFromFloat(self.screen_width), @intFromFloat(self.tab_bar_height), raylib.Color{ .r = 45, .g = 45, .b = 55, .a = 255 });

        const tab_width = self.screen_width / 5.0;
        const tab_names = [_][]const u8{ "Scene", "Geometry", "Material", "Animation", "TUI" };
        const tab_modes = [_]EditorMode{ .scene_editor, .geometry_nodes, .material_editor, .animation_editor, .tui_mode };

        for (tab_names, tab_modes, 0..) |name, mode, i| {
            const tab_x = @as(f32, @floatFromInt(i)) * tab_width;
            const is_active = self.current_mode == mode;

            const tab_color = if (is_active)
                raylib.Color{ .r = 70, .g = 70, .b = 90, .a = 255 }
            else if (raylib.checkCollisionPointRec(raylib.getMousePosition(), raylib.Rectangle{ .x = tab_x, .y = 0, .width = tab_width, .height = self.tab_bar_height }))
                raylib.Color{ .r = 55, .g = 55, .b = 70, .a = 255 }
            else
                raylib.Color{ .r = 45, .g = 45, .b = 55, .a = 255 };

            raylib.drawRectangle(@intFromFloat(tab_x), 0, @intFromFloat(tab_width), @intFromFloat(self.tab_bar_height), tab_color);

            const text_width = raylib.measureText(name, 16);
            const text_x = tab_x + (tab_width - @as(f32, @floatFromInt(text_width))) / 2.0;
            raylib.drawText(name, @intFromFloat(text_x), 12, 16, if (is_active) raylib.Color.white else raylib.Color.gray);

            // Handle tab clicking
            if (raylib.checkCollisionPointRec(raylib.getMousePosition(), raylib.Rectangle{ .x = tab_x, .y = 0, .width = tab_width, .height = self.tab_bar_height }) and raylib.isMouseButtonPressed(raylib.MouseButton.left)) {
                self.current_mode = mode;
            }
        }
    }

    /// Render the toolbar below the tab bar.
    fn renderToolbar(self: *MainEditor) void {
        const toolbar_y = self.tab_bar_height;
        raylib.drawRectangle(0, @intFromFloat(toolbar_y), @intFromFloat(self.screen_width), @intFromFloat(self.toolbar_height), raylib.Color{ .r = 50, .g = 50, .b = 60, .a = 255 });

        // Simple toolbar buttons
        const button_texts = [_][]const u8{ "Save", "Load", "Undo", "Redo", "Play" };
        const button_width = 80.0;
        const button_height = self.toolbar_height - 4;
        const button_y = toolbar_y + 2;

        for (button_texts, 0..) |text, i| {
            const button_x = 10 + @as(f32, @floatFromInt(i)) * (button_width + 5);
            const button_rect = raylib.Rectangle{ .x = button_x, .y = button_y, .width = button_width, .height = button_height };

            const is_hovered = raylib.checkCollisionPointRec(raylib.getMousePosition(), button_rect);
            const button_color = if (is_hovered) raylib.Color{ .r = 70, .g = 70, .b = 80, .a = 255 } else raylib.Color{ .r = 60, .g = 60, .b = 70, .a = 255 };

            raylib.drawRectangleRec(button_rect, button_color);
            raylib.drawRectangleLinesEx(button_rect, 1, raylib.Color{ .r = 100, .g = 100, .b = 110, .a = 255 });

            const text_width = raylib.measureText(text, 14);
            const text_x = button_x + (button_width - @as(f32, @floatFromInt(text_width))) / 2.0;
            raylib.drawText(text, @intFromFloat(text_x), @intFromFloat(button_y + 4), 14, raylib.Color.white);
        }
    }

    /// Render the status bar at the bottom of the editor.
    fn renderStatusBar(self: *MainEditor) void {
        const status_y = self.screen_height - self.status_bar_height;
        raylib.drawRectangle(0, @intFromFloat(status_y), @intFromFloat(self.screen_width), @intFromFloat(self.status_bar_height), raylib.Color{ .r = 40, .g = 40, .b = 50, .a = 255 });
        raylib.drawLine(0, @intFromFloat(status_y), @intFromFloat(self.screen_width), @intFromFloat(status_y), raylib.Color{ .r = 60, .g = 60, .b = 70, .a = 255 });

        const mode_text = switch (self.current_mode) {
            .scene_editor => "Scene Editor",
            .geometry_nodes => "Geometry Nodes",
            .material_editor => "Material Editor",
            .animation_editor => "Animation Editor",
            .tui_mode => "Terminal UI",
        };

        raylib.drawText(mode_text, 10, @intFromFloat(status_y + 4), 14, raylib.Color.gray);

        // Show FPS in the bottom right
        const fps_text = std.fmt.allocPrintZ(self.allocator, "FPS: {d}", .{raylib.getFPS()}) catch "FPS: --";
        defer if (!std.mem.eql(u8, fps_text, "FPS: --")) self.allocator.free(fps_text);

        const fps_width = raylib.measureText(fps_text, 14);
        raylib.drawText(fps_text, @intFromFloat(self.screen_width - @as(f32, @floatFromInt(fps_width)) - 10), @intFromFloat(status_y + 4), 14, raylib.Color.gray);
    }

    /// Update geometry node editor (placeholder).
    fn updateGeometryNodeEditor(self: *MainEditor, dt: f32) void {
        _ = dt;
        self.geometry_node_editor.update();
    }

    /// Render geometry node editor.
    fn renderGeometryNodeEditor(self: *MainEditor, content_rect: raylib.Rectangle) void {
        // Render preview panel
        const preview_rect = raylib.Rectangle{
            .x = content_rect.x + content_rect.width - 300,
            .y = content_rect.y,
            .width = 300,
            .height = content_rect.height,
        };
        self.renderGeometryPreviewPanel(preview_rect);

        // Render node graph panel
        const node_rect = raylib.Rectangle{
            .x = content_rect.x,
            .y = content_rect.y,
            .width = content_rect.width - 300,
            .height = content_rect.height,
        };
        self.renderGeometryNodePanel(node_rect);
    }

    /// Render geometry preview panel.
    fn renderGeometryPreviewPanel(self: *MainEditor, panel_rect: raylib.Rectangle) void {
        _ = self;
        raylib.drawRectangleRec(panel_rect, raylib.Color{ .r = 35, .g = 35, .b = 45, .a = 255 });
        raylib.drawRectangleLinesEx(panel_rect, 1, raylib.Color{ .r = 60, .g = 60, .b = 70, .a = 255 });

        raylib.drawText("Geometry Preview", @intFromFloat(panel_rect.x + 10), @intFromFloat(panel_rect.y + 10), 16, raylib.Color.white);
        raylib.drawText("(Under Development)", @intFromFloat(panel_rect.x + 10), @intFromFloat(panel_rect.y + 35), 14, raylib.Color.gray);
    }

    /// Render geometry node panel.
    fn renderGeometryNodePanel(self: *MainEditor, panel_rect: raylib.Rectangle) void {
        _ = self;
        raylib.drawRectangleRec(panel_rect, raylib.Color{ .r = 30, .g = 30, .b = 40, .a = 255 });
        raylib.drawRectangleLinesEx(panel_rect, 1, raylib.Color{ .r = 60, .g = 60, .b = 70, .a = 255 });

        raylib.drawText("Node Graph", @intFromFloat(panel_rect.x + 10), @intFromFloat(panel_rect.y + 10), 16, raylib.Color.white);
        raylib.drawText("(Under Development)", @intFromFloat(panel_rect.x + 10), @intFromFloat(panel_rect.y + 35), 14, raylib.Color.gray);
    }

    /// Update material editor (placeholder).
    fn updateMaterialEditor(self: *MainEditor, dt: f32) void {
        _ = dt;
        self.material_node_editor.update();
    }

    /// Render material editor.
    fn renderMaterialEditor(self: *MainEditor, content_rect: raylib.Rectangle) void {
        self.material_node_editor.render(content_rect.width, content_rect.height);
    }

    /// Update animation editor.
    fn updateAnimationEditor(self: *MainEditor, dt: f32) !void {
        // Animation editor update logic would go here
        _ = self;
        _ = dt;
    }

    /// Render animation editor.
    fn renderAnimationEditor(self: *MainEditor, content_rect: raylib.Rectangle) !void {
        raylib.drawRectangleRec(content_rect, raylib.Color{ .r = 30, .g = 30, .b = 40, .a = 255 });

        if (self.animation_timeline_visible) {
            const timeline_height = 100.0;
            const timeline_rect = raylib.Rectangle{
                .x = content_rect.x,
                .y = content_rect.y + content_rect.height - timeline_height,
                .width = content_rect.width,
                .height = timeline_height,
            };
            self.renderAnimationTimeline(timeline_rect.width, timeline_rect.height);
        }

        raylib.drawText("Animation Editor", @intFromFloat(content_rect.x + 10), @intFromFloat(content_rect.y + 10), 20, raylib.Color.white);
        raylib.drawText("(Under Development)", @intFromFloat(content_rect.x + 10), @intFromFloat(content_rect.y + 35), 16, raylib.Color.gray);
    }

    /// Render animation timeline.
    fn renderAnimationTimeline(self: *MainEditor, width: f32, height: f32) void {
        const timeline_y = self.screen_height - self.status_bar_height - height;
        raylib.drawRectangle(0, @intFromFloat(timeline_y), @intFromFloat(width), @intFromFloat(height), raylib.Color{ .r = 40, .g = 40, .b = 50, .a = 255 });
        raylib.drawLine(0, @intFromFloat(timeline_y), @intFromFloat(width), @intFromFloat(timeline_y), raylib.Color{ .r = 60, .g = 60, .b = 70, .a = 255 });

        raylib.drawText("Timeline", 10, @intFromFloat(timeline_y + 10), 16, raylib.Color.white);
    }

    /// Render performance overlay.
    fn renderPerformanceOverlay(self: *MainEditor) void {
        const overlay_width = 200.0;
        const overlay_height = 120.0;
        const overlay_x = self.screen_width - overlay_width - 10;
        const overlay_y = self.tab_bar_height + self.toolbar_height + 10;

        raylib.drawRectangle(@intFromFloat(overlay_x), @intFromFloat(overlay_y), @intFromFloat(overlay_width), @intFromFloat(overlay_height), raylib.Color{ .r = 0, .g = 0, .b = 0, .a = 180 });
        raylib.drawRectangleLines(@intFromFloat(overlay_x), @intFromFloat(overlay_y), @intFromFloat(overlay_width), @intFromFloat(overlay_height), raylib.Color.white);

        raylib.drawText("Performance", @intFromFloat(overlay_x + 10), @intFromFloat(overlay_y + 10), 14, raylib.Color.white);

        const fps = raylib.getFPS();
        const fps_text = std.fmt.allocPrintZ(self.allocator, "FPS: {d}", .{fps}) catch "FPS: --";
        defer if (!std.mem.eql(u8, fps_text, "FPS: --")) self.allocator.free(fps_text);
        raylib.drawText(fps_text, @intFromFloat(overlay_x + 10), @intFromFloat(overlay_y + 30), 12, raylib.Color.gray);

        const frame_time = raylib.getFrameTime() * 1000.0;
        const frame_text = std.fmt.allocPrintZ(self.allocator, "Frame: {d:.2}ms", .{frame_time}) catch "Frame: --ms";
        defer if (!std.mem.eql(u8, frame_text, "Frame: --ms")) self.allocator.free(frame_text);
        raylib.drawText(frame_text, @intFromFloat(overlay_x + 10), @intFromFloat(overlay_y + 45), 12, raylib.Color.gray);
    }
};

// Material Node Editor (Simplified)
// ============================================================================

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
        _ = self;
    }

    pub fn render(width: f32, height: f32) void {
        raylib.drawRectangle(0, 0, @intFromFloat(width), @intFromFloat(height), raylib.Color{ .r = 30, .g = 30, .b = 40, .a = 255 });
        raylib.drawText("Material Node Editor", @intFromFloat(width / 2 - 100), @intFromFloat(height / 2 - 10), 20, raylib.Color.gray);
        raylib.drawText("(Under Development)", @intFromFloat(width / 2 - 80), @intFromFloat(height / 2 + 15), 16, raylib.Color.gray);
    }
};
