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

    // Initialise borderless raylib window
    rl.initWindow(screenWidth, screenHeight, "Nyon Game Editor");
    defer rl.closeWindow();

    // Position window
    rl.setWindowPosition(100, 100); // Center-ish position

    // Disable raylib logging to avoid error union compatibility issues
    rl.setTraceLogLevel(rl.TraceLogLevel.none);

    // Use default font for now (font loading has API issues)

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

    // Custom window management
    var window_drag_offset = rl.Vector2{ .x = 0, .y = 0 };
    var is_window_dragging = false;
    const title_bar_height: f32 = 32.0;

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
        const content_y = title_bar_height;
        const content_height = screen_height - title_bar_height;

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
        // Ctrl+S: print node graph for debugging
        if (rl.isKeyPressed(.s) and rl.isKeyDown(.left_control)) {
            geometry_system.graph.debugPrint();
        }
        // Ctrl+D: also print node graph
        if (rl.isKeyPressed(.d) and rl.isKeyDown(.left_control)) {
            geometry_system.graph.debugPrint();
        }

        // Handle node interaction
        handleNodeInteraction(&geometry_system, &selected_node, &is_dragging, &drag_offset, view_width);

        // Handle custom window dragging
        const mouse_pos = rl.getMousePosition();
        if (rl.isMouseButtonPressed(.left) and mouse_pos.y <= title_bar_height) {
            window_drag_offset = mouse_pos;
            is_window_dragging = true;
        }
        if (rl.isMouseButtonReleased(.left)) {
            is_window_dragging = false;
        }
        if (is_window_dragging) {
            const current_pos = rl.getWindowPosition();
            const delta = rl.Vector2{
                .x = mouse_pos.x - window_drag_offset.x,
                .y = mouse_pos.y - window_drag_offset.y,
            };
            rl.setWindowPosition(@intFromFloat(current_pos.x + delta.x), @intFromFloat(current_pos.y + delta.y));
        }

        // --- UI Layout ---------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.ray_white);

        // Custom title bar
        rl.drawRectangle(0, 0, @intFromFloat(screen_width), @intFromFloat(title_bar_height), rl.Color{ .r = 45, .g = 45, .b = 55, .a = 255 });
        rl.drawText("Nyon Game Editor", 10, 8, 18, rl.Color.white);

        // Close button
        const close_button_rect = rl.Rectangle{
            .x = screen_width - 40,
            .y = 4,
            .width = 32,
            .height = 24,
        };
        const close_hover = rl.checkCollisionPointRec(mouse_pos, close_button_rect);
        const close_color = if (close_hover) rl.Color{ .r = 200, .g = 50, .b = 50, .a = 255 } else rl.Color{ .r = 150, .g = 50, .b = 50, .a = 255 };
        rl.drawRectangleRec(close_button_rect, close_color);
        rl.drawText("×", @intFromFloat(close_button_rect.x + 10), @intFromFloat(close_button_rect.y + 2), 18, rl.Color.white);

        if (close_hover and rl.isMouseButtonPressed(.left)) {
            break; // Exit the application
        }

        // Split screen: left side 3D view, right side node editor
        const editor_width = screen_width * (1.0 - view_split_ratio);

        // 3D scene render (left side)
        rl.beginScissorMode(0, @intFromFloat(content_y), @intFromFloat(view_width), @intFromFloat(content_height));
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
        rl.beginScissorMode(@intFromFloat(view_width), @intFromFloat(content_y), @intFromFloat(editor_width), @intFromFloat(content_height));
        geometry_system.renderNodeEditor(editor_width, screen_height);
        rl.endScissorMode();

        // UI overlay
        var ui_y: i32 = 10;

        // Node count
        var node_count_buf: [32:0]u8 = undefined;
        const node_count_slice = std.fmt.bufPrintZ(&node_count_buf, "Nodes: {}", .{geometry_system.graph.nodes.items.len}) catch "Nodes: ?";
        rl.drawText(node_count_slice, 10, ui_y, 16, rl.Color.white);
        ui_y += 25;

        // Selected node
        if (selected_node) |node_id| {
            var selected_buf: [32:0]u8 = undefined;
            const selected_slice = std.fmt.bufPrintZ(&selected_buf, "Selected: Node {}", .{node_id}) catch "Selected: Node ?";
            rl.drawText(selected_slice, 10, ui_y, 16, rl.Color.yellow);
        } else {
            rl.drawText("Selected: None", 10, ui_y, 16, rl.Color.gray);
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
            rl.drawText(instruction, 10, ui_y, 14, rl.Color.gray);
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
