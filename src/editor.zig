const std = @import("std");
const rl = @import("raylib");
const nyon = @import("nyon_game");

/// Nyon Game Editor with Node-Based Geometry System
///
/// * Opens a raylib window with split view (3D scene + node editor)
/// * Node-based geometry creation with real-time preview
/// * Interactive 3D scene editing
/// * Camera controls and object manipulation
pub fn main() !void {
    const screenWidth = 1600;
    const screenHeight = 900;

    // Initialise raylib window
    rl.initWindow(screenWidth, screenHeight, "Nyon Game Editor");
    defer rl.closeWindow();

    // Disable raylib logging to avoid error union compatibility issues
    rl.setTraceLogLevel(rl.TraceLogLevel.none);

    // Initialize geometry node system
    var geometry_system = try nyon.geometry_nodes.GeometryNodeSystem.init(std.heap.page_allocator);
    defer geometry_system.deinit();

    // Enable 3D mode
    var camera = rl.Camera3D{
        .position = rl.Vector3{ .x = 0, .y = 5, .z = 10 },
        .target = rl.Vector3{ .x = 0, .y = 0, .z = 0 },
        .up = rl.Vector3{ .x = 0, .y = 1, .z = 0 },
        .fovy = 45.0,
        .projection = .perspective,
    };

    // Create 3D scene for preview
    var scene = nyon.Scene.init(std.heap.page_allocator);
    defer scene.deinit();

    // UI state
    var selected_node: ?usize = null;
    // var selected_entity: ?usize = null; // For 3D scene objects - unused for now
    var drag_offset = rl.Vector2{ .x = 0, .y = 0 };
    var is_dragging = false;

    // Camera control variables
    var camera_angle = rl.Vector2{ .x = 0, .y = 0 };
    var camera_distance: f32 = 10.0;

    while (!rl.windowShouldClose()) {
        // Calculate screen dimensions for layout
        const screen_width = @as(f32, @floatFromInt(rl.getScreenWidth()));
        const screen_height = @as(f32, @floatFromInt(rl.getScreenHeight()));

        // Split screen: left side 3D view, right side node editor
        const view_split_ratio = 0.6; // 60% for 3D view, 40% for node editor
        const view_width = screen_width * view_split_ratio;

        // Handle camera controls
        handleCameraControls(&camera_angle, &camera_distance);

        // Update camera position based on spherical coordinates
        camera.position.x = camera_distance * @cos(camera_angle.x) * @cos(camera_angle.y);
        camera.position.y = camera_distance * @sin(camera_angle.y);
        camera.position.z = camera_distance * @sin(camera_angle.x) * @cos(camera_angle.y);

        // Node editor shortcuts
        if (rl.isKeyPressed(.space)) {
            // Execute geometry nodes
            geometry_system.executeGraph();
        }
        if (rl.isKeyPressed(.c) and rl.isKeyDown(.left_control)) {
            // Add cube node
            _ = geometry_system.createNode("Cube");
        }
        if (rl.isKeyPressed(.s) and rl.isKeyDown(.left_control)) {
            // Add sphere node
            _ = geometry_system.createNode("Sphere");
        }

        // Handle node interaction
        handleNodeInteraction(&geometry_system, &selected_node, &is_dragging, &drag_offset, view_width);

        // --- UI Layout ---------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.ray_white);

        // Split screen: left side 3D view, right side node editor
        const editor_width = screen_width * (1.0 - view_split_ratio);

        // 3D scene render (left side)
        rl.beginScissorMode(0, 0, @intFromFloat(view_width), @intFromFloat(screen_height));
        rl.beginMode3D(camera);

        // Clear background for 3D view
        rl.clearBackground(rl.Color{ .r = 40, .g = 40, .b = 50, .a = 255 });

        // Render geometry nodes preview if available
        if (geometry_system.getFinalGeometry()) |mesh| {
            const model = rl.loadModelFromMesh(mesh) catch continue;
            defer rl.unloadModel(model);
            rl.drawModel(model, rl.Vector3{ .x = 0, .y = 0, .z = 0 }, 1.0, rl.Color.white);
            rl.drawModelWires(model, rl.Vector3{ .x = 0, .y = 0, .z = 0 }, 1.0, rl.Color.gray);
        }

        // Draw coordinate axes
        const axis_length = 5.0;
        rl.drawLine3D(rl.Vector3{ .x = 0, .y = 0, .z = 0 }, rl.Vector3{ .x = axis_length, .y = 0, .z = 0 }, rl.Color.red);
        rl.drawLine3D(rl.Vector3{ .x = 0, .y = 0, .z = 0 }, rl.Vector3{ .x = 0, .y = axis_length, .z = 0 }, rl.Color.green);
        rl.drawLine3D(rl.Vector3{ .x = 0, .y = 0, .z = 0 }, rl.Vector3{ .x = 0, .y = 0, .z = axis_length }, rl.Color.blue);

        rl.endMode3D();
        rl.endScissorMode();

        // Node editor render (right side)
        rl.beginScissorMode(@intFromFloat(view_width), 0, @intFromFloat(editor_width), @intFromFloat(screen_height));
        geometry_system.renderNodeEditor(editor_width, screen_height);
        rl.endScissorMode();

        // UI overlay
        var ui_y: i32 = 10;
        const ui_font_size = 20;

        // Node count
        var node_count_buf: [32]u8 = undefined;
        const node_count_slice = std.fmt.bufPrint(&node_count_buf, "Nodes: {}", .{geometry_system.graph.nodes.items.len}) catch "Nodes: ?";
        rl.drawText(node_count_slice[0..node_count_slice.len :0], 10, ui_y, ui_font_size, rl.Color.white);
        ui_y += 25;

        // Selected node
        if (selected_node) |node_id| {
            var selected_buf: [32]u8 = undefined;
            const selected_slice = std.fmt.bufPrint(&selected_buf, "Selected: Node {}", .{node_id}) catch "Selected: Node ?";
            rl.drawText(selected_slice[0..selected_slice.len :0], 10, ui_y, ui_font_size, rl.Color.yellow);
        } else {
            rl.drawText("Selected: None", 10, ui_y, ui_font_size, rl.Color.gray);
        }
        ui_y += 30;

        // Instructions
        const instructions = [_][:0]const u8{
            "Ctrl+C: Add Cube Node",
            "Ctrl+S: Add Sphere Node",
            "SPACE: Execute Graph",
            "DEL: Delete Selected Node",
            "L-Click: Select Node",
            "Drag: Move Node",
            "R-Click: Node Menu",
            "Right Panel: Node Editor",
        };

        for (instructions) |instruction| {
            rl.drawText(instruction, 10, ui_y, ui_font_size - 2, rl.Color.gray);
            ui_y += 18;
        }
    }
}

/// Handle camera orbit controls
fn handleCameraControls(camera_angle: *rl.Vector2, camera_distance: *f32) void {
    // Mouse right button for camera rotation
    if (rl.isMouseButtonDown(.right)) {
        const delta = rl.getMouseDelta();
        camera_angle.x += delta.x * 0.005;
        camera_angle.y = @max(-std.math.pi / 2.1, @min(std.math.pi / 2.1, camera_angle.y + delta.y * 0.005));
    }

    // Mouse wheel for zoom
    const wheel = rl.getMouseWheelMove();
    if (wheel != 0) {
        camera_distance.* = @max(1.0, @min(50.0, camera_distance.* - wheel * 2.0));
    }
}

/// Handle node interaction in the node editor
fn handleNodeInteraction(geometry_system: *nyon.geometry_nodes.GeometryNodeSystem, selected_node: *?usize, is_dragging: *bool, drag_offset: *rl.Vector2, editor_offset_x: f32) void {
    const mouse_pos = rl.getMousePosition();

    // Convert screen coordinates to node editor coordinates
    const node_editor_pos = rl.Vector2{
        .x = mouse_pos.x - editor_offset_x,
        .y = mouse_pos.y,
    };

    // Left click to select/deselect nodes
    if (rl.isMouseButtonPressed(.left)) {
        selected_node.* = null;

        // Check if clicking on a node
        for (geometry_system.graph.nodes.items) |node| {
            const node_rect = rl.Rectangle{
                .x = node.position.x,
                .y = node.position.y,
                .width = 120,
                .height = 80,
            };

            if (rl.checkCollisionPointRec(node_editor_pos, node_rect)) {
                selected_node.* = node.id;
                is_dragging.* = true;
                drag_offset.* = rl.Vector2{
                    .x = node_editor_pos.x - node.position.x,
                    .y = node_editor_pos.y - node.position.y,
                };
                break;
            }
        }
    }

    // Handle dragging
    if (is_dragging.* and rl.isMouseButtonDown(.left)) {
        if (selected_node.*) |node_id| {
            if (geometry_system.graph.findNodeIndex(node_id)) |index| {
                var node = &geometry_system.graph.nodes.items[index];
                node.position = rl.Vector2{
                    .x = node_editor_pos.x - drag_offset.*.x,
                    .y = node_editor_pos.y - drag_offset.*.y,
                };
            }
        }
    } else {
        is_dragging.* = false;
    }

    // Delete selected node
    if (rl.isKeyPressed(.delete) or rl.isKeyPressed(.backspace)) {
        if (selected_node.*) |node_id| {
            geometry_system.removeNode(node_id);
            selected_node.* = null;
        }
    }
}

/// Draw a 3D grid
fn drawGrid() void {
    const grid_size = 20;
    const half_size = grid_size / 2;
    const color = rl.Color{ .r = 100, .g = 100, .b = 100, .a = 100 };

    var i: i32 = -half_size;
    while (i <= half_size) : (i += 1) {
        // X lines
        rl.drawLine3D(
            rl.Vector3{ .x = @as(f32, @floatFromInt(i)), .y = 0, .z = @as(f32, @floatFromInt(-half_size)) },
            rl.Vector3{ .x = @as(f32, @floatFromInt(i)), .y = 0, .z = @as(f32, @floatFromInt(half_size)) },
            color,
        );
        // Z lines
        rl.drawLine3D(
            rl.Vector3{ .x = @as(f32, @floatFromInt(-half_size)), .y = 0, .z = @as(f32, @floatFromInt(i)) },
            rl.Vector3{ .x = @as(f32, @floatFromInt(half_size)), .y = 0, .z = @as(f32, @floatFromInt(i)) },
            color,
        );
    }

    // Draw thicker center lines
    const center_color = rl.Color{ .r = 150, .g = 150, .b = 150, .a = 150 };
    rl.drawLine3D(
        rl.Vector3{ .x = -@as(f32, @floatFromInt(half_size)), .y = 0, .z = 0 },
        rl.Vector3{ .x = @as(f32, @floatFromInt(half_size)), .y = 0, .z = 0 },
        center_color,
    );
    rl.drawLine3D(
        rl.Vector3{ .x = 0, .y = 0, .z = -@as(f32, @floatFromInt(half_size)) },
        rl.Vector3{ .x = 0, .y = 0, .z = @as(f32, @floatFromInt(half_size)) },
        center_color,
    );
}
