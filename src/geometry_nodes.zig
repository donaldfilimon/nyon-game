const std = @import("std");
const raylib = @import("raylib");
const nodes = @import("nodes/node_graph.zig");

fn copyMesh(mesh: raylib.Mesh, allocator: std.mem.Allocator) raylib.Mesh {
    _ = allocator;
    return mesh;
}

/// Cube primitive node
const CubeNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
        const width = if (inputs.len > 0 and inputs[0] == .float) inputs[0].float else 2.0;
        const height = if (inputs.len > 1 and inputs[1] == .float) inputs[1].float else 2.0;
        const depth = if (inputs.len > 2 and inputs[2] == .float) inputs[2].float else 2.0;

        const mesh = raylib.genMeshCube(width, height, depth);
        return try allocator.dupe(nodes.NodeGraph.Value, &[_]nodes.NodeGraph.Value{.{ .mesh = mesh }});
    }

    fn deinit(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Width", .float, .{ .float = 2.0 });
        try node.addInput("Height", .float, .{ .float = 2.0 });
        try node.addInput("Depth", .float, .{ .float = 2.0 });
        try node.addOutput("Geometry", .mesh);
    }
};

/// Sphere primitive node
pub const SphereNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
        const radius = if (inputs.len > 0 and inputs[0] == .float) inputs[0].float else 1.0;
        const rings = if (inputs.len > 1 and inputs[1] == .int) @as(i32, inputs[1].int) else 16;
        const slices = if (inputs.len > 2 and inputs[2] == .int) @as(i32, inputs[2].int) else 16;

        const mesh = raylib.genMeshSphere(radius, rings, slices);
        return try allocator.dupe(nodes.NodeGraph.Value, &[_]nodes.NodeGraph.Value{.{ .mesh = mesh }});
    }

    fn deinit(node: *nodes.NodeGraph.Node, allocator: std.mem.Allocator) void {
        _ = node;
        _ = allocator;
    }

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Radius", .float, .{ .float = 1.0 });
        try node.addInput("Rings", .int, .{ .int = 16 });
        try node.addInput("Slices", .int, .{ .int = 16 });
        try node.addOutput("Geometry", .mesh);
    }
};

/// Translation transformation node
pub const TranslateNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
        if (inputs.len != 2) return error.InvalidInputCount;

        const input_mesh = inputs[0].mesh;
        const translation = inputs[1].vector3;

        // Create a copy of the mesh
        var transformed_mesh = input_mesh;

        const transformed_vertex_count: usize = @intCast(transformed_mesh.vertexCount);
        // Apply translation to all vertices
        for (0..transformed_vertex_count) |i| {
            const vertex_index = i * 3;
            transformed_mesh.vertices[vertex_index] += translation.x;
            transformed_mesh.vertices[vertex_index + 1] += translation.y;
            transformed_mesh.vertices[vertex_index + 2] += translation.z;
        }

        // Recalculate normals if present
        if (transformed_mesh.normals != null) {}

        var outputs = try allocator.alloc(nodes.NodeGraph.Value, 1);
        outputs[0] = .{ .mesh = transformed_mesh };
        return outputs;
    }

    fn deinit(node: *nodes.NodeGraph.Node, allocator: std.mem.Allocator) void {
        _ = node;
        _ = allocator;
    }

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Geometry", .mesh, null);
        try node.addInput("Offset", .vector3, .{ .vector3 = .{ .x = 0, .y = 0, .z = 0 } });
        try node.addOutput("Geometry", .mesh);
    }
};

/// Scale transformation node
pub const ScaleNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
        if (inputs.len != 2) return error.InvalidInputCount;

        const input_mesh = inputs[0].mesh;
        const scale = inputs[1].vector3;

        // Create a copy of the mesh
        var scaled_mesh = input_mesh;

        const scaled_vertex_count: usize = @intCast(scaled_mesh.vertexCount);
        // Apply scaling to all vertices
        for (0..scaled_vertex_count) |i| {
            const vertex_index = i * 3;
            scaled_mesh.vertices[vertex_index] *= scale.x;
            scaled_mesh.vertices[vertex_index + 1] *= scale.y;
            scaled_mesh.vertices[vertex_index + 2] *= scale.z;
        }

        // Recalculate normals if present
        if (scaled_mesh.normals != null) {}

        var outputs = try allocator.alloc(nodes.NodeGraph.Value, 1);
        outputs[0] = .{ .mesh = scaled_mesh };
        return outputs;
    }

    fn deinit(node: *nodes.NodeGraph.Node, allocator: std.mem.Allocator) void {
        _ = node;
        _ = allocator;
    }

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Geometry", .mesh, null);
        try node.addInput("Scale", .vector3, .{ .vector3 = .{ .x = 1, .y = 1, .z = 1 } });
        try node.addOutput("Geometry", .mesh);
    }
};

/// Rotation transformation node
pub const RotateNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
        if (inputs.len != 2) return error.InvalidInputCount;

        const input_mesh = inputs[0].mesh;
        const rotation = inputs[1].vector3; // Euler angles in degrees

        // Create a copy of the mesh
        var rotated_mesh = input_mesh;

        // Convert degrees to radians
        const rot_x_rad = rotation.x * std.math.pi / 180.0;
        const rot_y_rad = rotation.y * std.math.pi / 180.0;
        const rot_z_rad = rotation.z * std.math.pi / 180.0;

        const rotated_vertex_count: usize = @intCast(rotated_mesh.vertexCount);
        // Apply rotation to all vertices (ZXY order)
        for (0..rotated_vertex_count) |i| {
            const vertex_index = i * 3;
            var x = rotated_mesh.vertices[vertex_index];
            var y = rotated_mesh.vertices[vertex_index + 1];
            var z = rotated_mesh.vertices[vertex_index + 2];

            // Apply rotations
            // First Z rotation
            const cos_z = @cos(rot_z_rad);
            const sin_z = @sin(rot_z_rad);
            const new_x_z = x * cos_z - y * sin_z;
            const new_y_z = x * sin_z + y * cos_z;
            x = new_x_z;
            y = new_y_z;

            // Then X rotation
            const cos_x = @cos(rot_x_rad);
            const sin_x = @sin(rot_x_rad);
            const new_y_x = y * cos_x - z * sin_x;
            const new_z_x = y * sin_x + z * cos_x;
            y = new_y_x;
            z = new_z_x;

            // Finally Y rotation
            const cos_y = @cos(rot_y_rad);
            const sin_y = @sin(rot_y_rad);
            const new_x_y = x * cos_y + z * sin_y;
            const new_z_y = -x * sin_y + z * cos_y;
            x = new_x_y;
            z = new_z_y;

            rotated_mesh.vertices[vertex_index] = x;
            rotated_mesh.vertices[vertex_index + 1] = y;
            rotated_mesh.vertices[vertex_index + 2] = z;
        }

        // Recalculate normals if present
        if (rotated_mesh.normals != null) {}

        var outputs = try allocator.alloc(nodes.NodeGraph.Value, 1);
        outputs[0] = .{ .mesh = rotated_mesh };
        return outputs;
    }

    fn deinit(node: *nodes.NodeGraph.Node, allocator: std.mem.Allocator) void {
        _ = node;
        _ = allocator;
    }

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Geometry", .mesh, null);
        try node.addInput("Rotation", .vector3, .{ .vector3 = .{ .x = 0, .y = 0, .z = 0 } });
        try node.addOutput("Geometry", .mesh);
    }
};
/// Union boolean operation node
pub const UnionNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
        if (inputs.len != 2) return error.InvalidInputCount;

        const mesh_a = inputs[0].mesh;
        const mesh_b = inputs[1].mesh;

        // For Phase 1, implement simple mesh merging
        // In a full implementation, this would do proper boolean union
        const total_vertices: usize = @intCast(mesh_a.vertexCount + mesh_b.vertexCount);
        const total_triangles: usize = @intCast(mesh_a.triangleCount + mesh_b.triangleCount);

        var combined_vertices = try allocator.alloc(f32, total_vertices * 3);
        defer allocator.free(combined_vertices);

        // Copy vertices from mesh A
        const a_vertices: usize = @intCast(mesh_a.vertexCount);
        const a_vertex_count = a_vertices * 3;
        @memcpy(combined_vertices[0..a_vertex_count], mesh_a.vertices[0..a_vertex_count]);

        // Copy vertices from mesh B
        const b_vertices: usize = @intCast(mesh_b.vertexCount);
        const b_vertex_count = b_vertices * 3;
        @memcpy(combined_vertices[a_vertex_count .. a_vertex_count + b_vertex_count], mesh_b.vertices[0..b_vertex_count]);

        // Create combined mesh
        var combined_mesh = raylib.Mesh{
            .vertexCount = @intCast(total_vertices),
            .triangleCount = @intCast(total_triangles),
            .vertices = combined_vertices.ptr,
            .texcoords = null,
            .texcoords2 = null,
            .normals = null,
            .tangents = null,
            .colors = null,
            .indices = null,
            .animVertices = null,
            .animNormals = null,
            .boneIds = null,
            .boneWeights = null,
            .vaoId = 0,
            .boneCount = 0,
            .boneMatrices = null,
            .vboId = null,
        };

        // Transfer ownership to raylib
        raylib.uploadMesh(&combined_mesh, false);

        var outputs = try allocator.alloc(nodes.NodeGraph.Value, 1);
        outputs[0] = .{ .mesh = combined_mesh };
        return outputs;
    }

    fn deinit(node: *nodes.NodeGraph.Node, allocator: std.mem.Allocator) void {
        _ = node;
        _ = allocator;
    }

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Geometry A", .mesh, null);
        try node.addInput("Geometry B", .mesh, null);
        try node.addOutput("Geometry", .mesh);
    }
};

/// Difference boolean operation node
pub const DifferenceNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
        if (inputs.len != 2) return error.InvalidInputCount;

        // For Phase 1, just return the first mesh (placeholder for proper CSG)
        const mesh_a = inputs[0].mesh;
        const result_mesh = copyMesh(mesh_a, allocator);

        var outputs = try allocator.alloc(nodes.NodeGraph.Value, 1);
        outputs[0] = .{ .mesh = result_mesh };
        return outputs;
    }

    fn deinit(node: *nodes.NodeGraph.Node, allocator: std.mem.Allocator) void {
        _ = node;
        _ = allocator;
    }

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Geometry A", .mesh, null);
        try node.addInput("Geometry B", .mesh, null);
        try node.addOutput("Geometry", .mesh);
    }
};

/// Intersection boolean operation node
pub const IntersectionNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
        if (inputs.len != 2) return error.InvalidInputCount;

        // For Phase 1, just return an empty mesh (placeholder for proper CSG)
        const mesh = raylib.genMeshCube(0.1, 0.1, 0.1); // Very small cube as placeholder
        return try allocator.dupe(nodes.NodeGraph.Value, &[_]nodes.NodeGraph.Value{.{ .mesh = mesh }});
    }

    fn deinit(node: *nodes.NodeGraph.Node, allocator: std.mem.Allocator) void {
        _ = node;
        _ = allocator;
    }

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Geometry A", .mesh, null);
        try node.addInput("Geometry B", .mesh, null);
        try node.addOutput("Geometry", .mesh);
    }
};
/// Simplified geometry node system for Phase 1
/// Focuses on core node graph functionality with basic primitives
pub const GeometryNodeSystem = struct {
    /// Core node graph
    graph: nodes.NodeGraph,

    /// UI state for interactive editor
    selected_node: ?nodes.NodeGraph.NodeId,
    drag_state: ?struct {
        node_id: nodes.NodeGraph.NodeId,
        offset: raylib.Vector2,
    },

    pub fn init(allocator: std.mem.Allocator) !GeometryNodeSystem {
        const graph = nodes.NodeGraph.init(allocator);
        return .{
            .graph = graph,
            .selected_node = null,
            .drag_state = null,
        };
    }

    pub fn deinit(self: *GeometryNodeSystem) void {
        self.graph.deinit();
    }

    /// Execute the entire node graph
    pub fn executeGraph(self: *GeometryNodeSystem) void {
        self.graph.execute() catch {};
    }

    /// Get the final geometry output from the last node in the graph
    pub fn getFinalGeometry(self: *GeometryNodeSystem) ?raylib.Mesh {
        if (self.graph.nodes.items.len == 0) return null;

        // Get the last node (assuming it's the output)
        const last_node_id = self.graph.nodes.items[self.graph.nodes.items.len - 1].id;

        // Execute and get its first output (assuming it's geometry)
        const outputs = self.graph.executeNode(last_node_id) catch return null;
        defer {
            for (outputs) |*output| {
                output.deinit(self.graph.allocator);
            }
            self.graph.allocator.free(outputs);
        }

        if (outputs.len > 0 and outputs[0] == .mesh) {
            return outputs[0].mesh;
        }

        return null;
    }

    /// Create a new node of the specified type
    pub fn createNode(self: *GeometryNodeSystem, node_type: []const u8) nodes.NodeGraph.NodeId {
        var vtable: nodes.NodeGraph.Node.NodeVTable = undefined;

        if (std.mem.eql(u8, node_type, "Cube")) {
            vtable = CubeNode.createVTable();
        } else if (std.mem.eql(u8, node_type, "Sphere")) {
            vtable = SphereNode.createVTable();
        } else if (std.mem.eql(u8, node_type, "Translate")) {
            vtable = TranslateNode.createVTable();
        } else if (std.mem.eql(u8, node_type, "Scale")) {
            vtable = ScaleNode.createVTable();
        } else if (std.mem.eql(u8, node_type, "Union")) {
            vtable = UnionNode.createVTable();
        } else {
            return 0; // Return invalid ID for unknown types
        }

        const node_id = self.graph.addNode(node_type, &vtable) catch return 0;
        const node_index = self.graph.findNodeIndex(node_id) orelse return 0;
        const node = &self.graph.nodes.items[node_index];

        // Initialize node inputs/outputs based on type
        if (std.mem.eql(u8, node_type, "Cube")) {
            CubeNode.initNode(node) catch {};
        } else if (std.mem.eql(u8, node_type, "Sphere")) {
            SphereNode.initNode(node) catch {};
        } else if (std.mem.eql(u8, node_type, "Translate")) {
            TranslateNode.initNode(node) catch {};
        } else if (std.mem.eql(u8, node_type, "Scale")) {
            ScaleNode.initNode(node) catch {};
        } else if (std.mem.eql(u8, node_type, "Union")) {
            UnionNode.initNode(node) catch {};
        }

        return node_id;
    }

    /// Remove a node from the graph
    pub fn removeNode(self: *GeometryNodeSystem, node_id: nodes.NodeGraph.NodeId) void {
        self.graph.removeNode(node_id) catch {};
        if (self.selected_node != null and self.selected_node.? == node_id) {
            self.selected_node = null;
        }
    }

    /// Add a connection between nodes
    pub fn addConnection(self: *GeometryNodeSystem, from_node: nodes.NodeGraph.NodeId, from_output: usize, to_node: nodes.NodeGraph.NodeId, to_input: usize) !void {
        try self.graph.addConnection(from_node, from_output, to_node, to_input);
    }
    /// Interactive node editor rendering and input handling
    pub fn updateNodeEditor(self: *GeometryNodeSystem, mouse_pos: raylib.Vector2, mouse_pressed: bool, mouse_down: bool, key_delete: bool, editor_offset_x: f32) void {
        const editor_mouse_pos = raylib.Vector2{
            .x = mouse_pos.x - editor_offset_x,
            .y = mouse_pos.y,
        };

        // Handle node selection and dragging
        if (mouse_pressed) {
            self.selected_node = null;
            self.drag_state = null;

            // Check if clicking on a node
            for (self.graph.nodes.items) |*node| {
                const node_rect = raylib.Rectangle{
                    .x = node.position.x,
                    .y = node.position.y,
                    .width = 120,
                    .height = 60 + @as(f32, @floatFromInt(node.inputs.items.len + node.outputs.items.len)) * 20,
                };

                if (raylib.checkCollisionPointRec(editor_mouse_pos, node_rect)) {
                    self.selected_node = node.id;
                    self.drag_state = .{
                        .node_id = node.id,
                        .offset = raylib.Vector2{
                            .x = editor_mouse_pos.x - node.position.x,
                            .y = editor_mouse_pos.y - node.position.y,
                        },
                    };
                    break;
                }
            }
        }

        // Handle dragging
        if (mouse_down and self.drag_state != null) {
            const drag = self.drag_state.?;
            if (self.graph.findNodeIndex(drag.node_id)) |index| {
                var node = &self.graph.nodes.items[index];
                node.position = raylib.Vector2{
                    .x = editor_mouse_pos.x - drag.offset.x,
                    .y = editor_mouse_pos.y - drag.offset.y,
                };
            }
        } else {
            self.drag_state = null;
        }

        // Handle deletion
        if (key_delete and self.selected_node != null) {
            self.removeNode(self.selected_node.?) catch {};
            self.selected_node = null;
        }
    }

    /// Render the node editor UI
    pub fn renderNodeEditor(self: *GeometryNodeSystem, screen_width: f32, screen_height: f32) void {
        const panel_width = 250;
        const editor_width = screen_width - panel_width;
        const editor_height = screen_height;

        // Draw node editor background
        raylib.drawRectangle(
            @intFromFloat(panel_width),
            0,
            @intFromFloat(editor_width),
            @intFromFloat(editor_height),
            raylib.Color{ .r = 30, .g = 30, .b = 40, .a = 255 },
        );

        // Draw grid
        const grid_size = 20;
        var x: f32 = panel_width;
        while (x < screen_width) : (x += grid_size) {
            const alpha: u8 = if (@mod(@as(i32, @intFromFloat(x)), @as(i32, grid_size * 5)) == 0) 120 else 60;
            raylib.drawLine(
                @intFromFloat(x),
                0,
                @intFromFloat(x),
                @intFromFloat(editor_height),
                raylib.Color{ .r = 50, .g = 50, .b = 60, .a = alpha },
            );
        }

        var y: f32 = 0;
        while (y < screen_height) : (y += grid_size) {
            const alpha: u8 = if (@mod(@as(i32, @intFromFloat(y)), @as(i32, grid_size * 5)) == 0) 120 else 60;
            raylib.drawLine(
                @intFromFloat(panel_width),
                @intFromFloat(y),
                @intFromFloat(screen_width),
                @intFromFloat(y),
                raylib.Color{ .r = 50, .g = 50, .b = 60, .a = alpha },
            );
        }

        // Draw nodes
        for (self.graph.nodes.items) |*node| {
            self.drawNode(node, self.selected_node != null and self.selected_node.? == node.id);
        }

        // Draw connections
        for (self.graph.connections.items) |conn| {
            self.drawConnection(conn);
        }

        // Draw UI panel
        raylib.drawRectangle(
            0,
            0,
            @intFromFloat(panel_width),
            @intFromFloat(screen_height),
            raylib.Color{ .r = 20, .g = 20, .b = 30, .a = 255 },
        );

        // Panel title
        raylib.drawText("Geometry Nodes", 10, 10, 20, raylib.Color.white);

        // Node creation buttons
        const button_width = 80;
        const button_height = 25;
        var button_y: i32 = 50;

        const node_types = [_][:0]const u8{ "Cube", "Sphere", "Translate", "Scale", "Rotate", "Union", "Difference", "Intersection" };

        for (node_types) |node_type| {
            const button_rect = raylib.Rectangle{
                .x = 10,
                .y = @floatFromInt(button_y),
                .width = button_width,
                .height = button_height,
            };

            const mouse_pos = raylib.getMousePosition();
            const hovered = raylib.checkCollisionPointRec(mouse_pos, button_rect);
            const color = if (hovered) raylib.Color{ .r = 70, .g = 70, .b = 80, .a = 255 } else raylib.Color{ .r = 50, .g = 50, .b = 60, .a = 255 };

            raylib.drawRectangleRec(button_rect, color);
            raylib.drawText(node_type, 15, button_y + 5, 14, raylib.Color.white);

            if (hovered and raylib.isMouseButtonPressed(.left)) {
                _ = self.createNode(node_type);
            }

            button_y += 30;
        }

        // Node count
        var node_count_buf: [32]u8 = undefined;
        const node_count_slice = std.fmt.bufPrint(&node_count_buf, "Nodes: {}", .{self.graph.nodes.items.len}) catch "Nodes: ?";
        const node_count_text = node_count_slice[0..node_count_slice.len :0];
        raylib.drawText(node_count_text[0..node_count_text.len :0], 10, @as(i32, @intFromFloat(screen_height)) - 30, 16, raylib.Color.gray);
    }
    /// Draw a single node
    fn drawNode(self: *GeometryNodeSystem, node: *nodes.NodeGraph.Node, selected: bool) void {
        _ = self; // Not used currently

        const node_width = 120;
        var node_height: f32 = 40; // Header height

        // Calculate height based on inputs/outputs
        node_height += @as(f32, @floatFromInt(node.inputs.items.len)) * 20;
        node_height += @as(f32, @floatFromInt(node.outputs.items.len)) * 20;

        // Node background
        const bg_color = if (selected) raylib.Color{ .r = 80, .g = 120, .b = 150, .a = 255 } else raylib.Color{ .r = 60, .g = 60, .b = 70, .a = 255 };
        raylib.drawRectangle(
            @intFromFloat(node.position.x),
            @intFromFloat(node.position.y),
            @intFromFloat(node_width),
            @intFromFloat(node_height),
            bg_color,
        );

        // Node header
        raylib.drawRectangle(
            @intFromFloat(node.position.x),
            @intFromFloat(node.position.y),
            @intFromFloat(node_width),
            25,
            raylib.Color{ .r = 40, .g = 40, .b = 50, .a = 255 },
        );

        // Node title
        raylib.drawText(
            node.node_type[0..node.node_type.len :0],
            @as(i32, @intFromFloat(node.position.x)) + 5,
            @as(i32, @intFromFloat(node.position.y)) + 5,
            16,
            raylib.Color.white,
        );

        // Draw inputs
        var y_offset: f32 = 30;
        for (node.inputs.items) |input| {
            const input_color = if (input.connected) raylib.Color.green else raylib.Color.gray;
            raylib.drawCircle(
                @as(i32, @intFromFloat(node.position.x)) - 5,
                @intFromFloat(node.position.y + y_offset + 8),
                4,
                input_color,
            );
            raylib.drawText(
                input.name[0..input.name.len :0],
                @as(i32, @intFromFloat(node.position.x)) + 5,
                @intFromFloat(node.position.y + y_offset),
                12,
                raylib.Color.white,
            );
            y_offset += 20;
        }

        // Draw outputs
        for (node.outputs.items) |output| {
            raylib.drawCircle(
                @intFromFloat(node.position.x + node_width + 5),
                @intFromFloat(node.position.y + y_offset + 8),
                4,
                raylib.Color.blue,
            );
            raylib.drawText(
                output.name[0..output.name.len :0],
                @as(i32, @intFromFloat(node.position.x)) + 5,
                @intFromFloat(node.position.y + y_offset),
                12,
                raylib.Color.white,
            );
            y_offset += 20;
        }

        // Selection outline
        if (selected) {
            raylib.drawRectangleLines(
                @intFromFloat(node.position.x - 2),
                @intFromFloat(node.position.y - 2),
                @intFromFloat(node_width + 4),
                @intFromFloat(node_height + 4),
                raylib.Color.yellow,
            );
        }
    }

    /// Draw a connection between nodes
    fn drawConnection(self: *GeometryNodeSystem, conn: nodes.NodeGraph.Connection) void {
        const from_node_index = self.graph.findNodeIndex(conn.from_node) orelse return;
        const to_node_index = self.graph.findNodeIndex(conn.to_node) orelse return;

        const from_node = &self.graph.nodes.items[from_node_index];
        const to_node = &self.graph.nodes.items[to_node_index];

        // Calculate output position
        const from_y = from_node.position.y + 30 + @as(f32, @floatFromInt(conn.from_output)) * 20 + 8;
        const from_pos = raylib.Vector2{
            .x = from_node.position.x + 120 + 5,
            .y = from_y,
        };

        // Calculate input position
        var to_y = to_node.position.y + 30;
        for (0..conn.to_input) |_| {
            to_y += 20;
        }
        to_y += 8;
        const to_pos = raylib.Vector2{
            .x = to_node.position.x - 5,
            .y = to_y,
        };

        // Draw bezier curve
        raylib.drawLineBezier(from_pos, to_pos, 2.0, raylib.Color.white);
    }

    /// Get node under mouse for property inspection
    pub fn getNodeAtPosition(self: *const GeometryNodeSystem, pos: raylib.Vector2) ?nodes.NodeGraph.NodeId {
        for (self.graph.nodes.items) |node| {
            const node_rect = raylib.Rectangle{
                .x = node.position.x,
                .y = node.position.y,
                .width = 120,
                .height = 60 + @as(f32, @floatFromInt(node.inputs.items.len + node.outputs.items.len)) * 20,
            };

            if (raylib.checkCollisionPointRec(pos, node_rect)) {
                return node.id;
            }
        }
        return null;
    }
};
