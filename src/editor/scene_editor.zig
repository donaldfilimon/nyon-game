//! Scene Editor Mode for Nyon Game Engine
//!
//! This module handles the 3D scene editing functionality,
//! including camera controls, object selection, and gizmo manipulation.

const std = @import("std");
const raylib = @import("../raylib");

const editor_mod = @import("editor.zig");

// ============================================================================
// Scene Editor State
// ============================================================================

pub const SceneEditor = struct {
    /// Camera controller for 3D navigation
    camera_position: raylib.Vector3 = raylib.Vector3{ .x = 0, .y = 5, .z = 10 },
    camera_target: raylib.Vector3 = raylib.Vector3{ .x = 0, .y = 0, .z = 0 },
    camera_up: raylib.Vector3 = raylib.Vector3{ .x = 0, .y = 1, .z = 0 },
    camera_fov: f32 = 45.0,

    /// Camera control state
    is_dragging: bool = false,
    last_mouse_pos: raylib.Vector2 = raylib.Vector2{ .x = 0, .y = 0 },

    /// Grid settings
    grid_size: f32 = 10.0,
    grid_divisions: i32 = 20,

    pub fn init(allocator: std.mem.Allocator) !SceneEditor {
        _ = allocator;
        return SceneEditor{};
    }

    pub fn deinit(self: *SceneEditor) void {
        _ = self;
    }

    pub fn update(self: *SceneEditor, editor: *editor_mod.MainEditor, dt: f32) !void {
        _ = dt;
        self.handleCameraControls();
        self.handleObjectSelection(editor);
    }

    pub fn render(self: *SceneEditor, editor: *editor_mod.MainEditor, content_rect: raylib.Rectangle) !void {
        // Set up 3D camera
        const camera = raylib.Camera3D{
            .position = self.camera_position,
            .target = self.camera_target,
            .up = self.camera_up,
            .fovy = self.camera_fov,
            .projection = raylib.CameraProjection.perspective,
        };

        // Begin 3D mode
        raylib.beginMode3D(camera);

        // Draw grid
        self.drawGrid();

        // Draw scene objects
        self.drawSceneObjects(editor);

        // Draw gizmos for selected object
        if (editor.selected_scene_object) |_| {
            self.drawGizmos();
        }

        raylib.endMode3D();

        // Draw 2D UI overlay
        self.drawSceneUI(editor, content_rect);
    }

    fn handleCameraControls(self: *SceneEditor) void {
        const mouse_pos = raylib.getMousePosition();

        // Orbit camera with right mouse button
        if (raylib.isMouseButtonPressed(raylib.MouseButton.right)) {
            self.is_dragging = true;
            self.last_mouse_pos = mouse_pos;
        }

        if (raylib.isMouseButtonDown(raylib.MouseButton.right) and self.is_dragging) {
            const delta_x = mouse_pos.x - self.last_mouse_pos.x;
            const delta_y = mouse_pos.y - self.last_mouse_pos.y;

            // Simple orbit (would be more sophisticated in a real implementation)
            const orbit_speed = 0.01;
            const distance = self.camera_position.distance(self.camera_target);

            self.camera_position.x = self.camera_target.x + distance * @cos(delta_x * orbit_speed);
            self.camera_position.z = self.camera_target.z + distance * @sin(delta_x * orbit_speed);
            self.camera_position.y += delta_y * 0.1;

            self.last_mouse_pos = mouse_pos;
        }

        if (raylib.isMouseButtonReleased(raylib.MouseButton.right)) {
            self.is_dragging = false;
        }

        // Zoom with mouse wheel
        const wheel = raylib.getMouseWheelMove();
        if (wheel != 0) {
            const zoom_speed = 2.0;
            const direction = self.camera_position.subtract(self.camera_target).normalize();
            const zoom_delta = direction.scale(wheel * zoom_speed);
            self.camera_position = self.camera_position.add(zoom_delta);
        }
    }

    fn handleObjectSelection(self: *SceneEditor, editor: *editor_mod.MainEditor) void {
        _ = self;
        _ = editor;
        // Object selection logic would go here
        // This would raycast into the scene to find selectable objects
    }

    fn drawGrid(self: *SceneEditor) void {
        const grid_color = raylib.Color{ .r = 100, .g = 100, .b = 100, .a = 100 };

        // Draw grid lines
        const half_size = self.grid_size / 2.0;
        const step = self.grid_size / @as(f32, @floatFromInt(self.grid_divisions));

        var i: f32 = -half_size;
        while (i <= half_size) : (i += step) {
            // X lines
            raylib.drawLine3D(
                raylib.Vector3{ .x = i, .y = 0, .z = -half_size },
                raylib.Vector3{ .x = i, .y = 0, .z = half_size },
                grid_color,
            );
            // Z lines
            raylib.drawLine3D(
                raylib.Vector3{ .x = -half_size, .y = 0, .z = i },
                raylib.Vector3{ .x = half_size, .y = 0, .z = i },
                grid_color,
            );
        }

        // Draw axes
        raylib.drawLine3D(
            raylib.Vector3{ .x = 0, .y = 0, .z = 0 },
            raylib.Vector3{ .x = half_size, .y = 0, .z = 0 },
            raylib.Color.red,
        );
        raylib.drawLine3D(
            raylib.Vector3{ .x = 0, .y = 0, .z = 0 },
            raylib.Vector3{ .x = 0, .y = half_size, .z = 0 },
            raylib.Color.green,
        );
        raylib.drawLine3D(
            raylib.Vector3{ .x = 0, .y = 0, .z = 0 },
            raylib.Vector3{ .x = 0, .y = 0, .z = half_size },
            raylib.Color.blue,
        );
    }

    fn drawSceneObjects(self: *SceneEditor, editor: *editor_mod.MainEditor) void {
        _ = self;
        _ = editor;
        // Draw cubes as placeholders for scene objects
        raylib.drawCube(raylib.Vector3{ .x = 0, .y = 1, .z = 0 }, 2, 2, 2, raylib.Color.blue);
        raylib.drawCube(raylib.Vector3{ .x = 3, .y = 1, .z = 0 }, 2, 2, 2, raylib.Color.red);
        raylib.drawCube(raylib.Vector3{ .x = -3, .y = 1, .z = 0 }, 2, 2, 2, raylib.Color.green);
    }

    fn drawGizmos(self: *SceneEditor) void {
        _ = self;
        // Simple translation gizmos (would be more sophisticated)
        const gizmo_size = 1.0;
        raylib.drawLine3D(
            raylib.Vector3{ .x = 0, .y = 0, .z = 0 },
            raylib.Vector3{ .x = gizmo_size, .y = 0, .z = 0 },
            raylib.Color.red,
        );
        raylib.drawLine3D(
            raylib.Vector3{ .x = 0, .y = 0, .z = 0 },
            raylib.Vector3{ .x = 0, .y = gizmo_size, .z = 0 },
            raylib.Color.green,
        );
        raylib.drawLine3D(
            raylib.Vector3{ .x = 0, .y = 0, .z = 0 },
            raylib.Vector3{ .x = 0, .y = 0, .z = gizmo_size },
            raylib.Color.blue,
        );
    }

    fn drawSceneUI(self: *SceneEditor, editor: *editor_mod.MainEditor, content_rect: raylib.Rectangle) void {
        _ = self;
        _ = editor;

        // Draw viewport info
        raylib.drawText("Scene Editor", @intFromFloat(content_rect.x + 10), @intFromFloat(content_rect.y + 10), 20, raylib.Color.white);
        raylib.drawText("Right-click + drag to orbit", @intFromFloat(content_rect.x + 10), @intFromFloat(content_rect.y + 35), 14, raylib.Color.gray);
        raylib.drawText("Mouse wheel to zoom", @intFromFloat(content_rect.x + 10), @intFromFloat(content_rect.y + 50), 14, raylib.Color.gray);
    }
};
