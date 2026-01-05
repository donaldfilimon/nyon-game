//! Material node editor for the unified editor.
//!
//! Extracted from the main editor so the node graph logic lives in one place.
const std = @import("std");
const raylib = @import("raylib");

const material_nodes = @import("../material_nodes.zig");
const nodes = @import("../nodes/node_graph.zig");

/// Simplified material node editor used by the unified editor.
pub const MaterialNodeEditor = struct {
    allocator: std.mem.Allocator,
    graph: nodes.NodeGraph,
    selected_node: ?nodes.NodeGraph.NodeId = null,
    is_dragging: bool = false,
    drag_offset: raylib.Vector2 = .{ .x = 0, .y = 0 },
    menu_open: bool = false,
    menu_pos: raylib.Vector2 = .{ .x = 0, .y = 0 },

    /// Initialize the material node editor with a default output node.
    pub fn init(allocator: std.mem.Allocator) !MaterialNodeEditor {
        var editor = MaterialNodeEditor{
            .allocator = allocator,
            .graph = nodes.NodeGraph.init(allocator),
        };

        // Create default PBR output node.
        const vtable = material_nodes.PBREutputNode.createVTable();
        const node_id = try editor.graph.addNode("PBR Output", &vtable);
        if (editor.graph.findNodeIndex(node_id)) |idx| {
            try material_nodes.PBREutputNode.initNode(&editor.graph.nodes.items[idx]);
            editor.graph.nodes.items[idx].position = .{ .x = 400, .y = 300 };
        }

        return editor;
    }

    /// Release resources owned by the editor.
    pub fn deinit(self: *MaterialNodeEditor) void {
        self.graph.deinit();
    }

    /// Update interaction state for the node graph.
    pub fn update(self: *MaterialNodeEditor) void {
        const mouse_pos = raylib.getMousePosition();
        const mouse_pressed = raylib.isMouseButtonPressed(.left);
        const mouse_down = raylib.isMouseButtonDown(.left);
        const right_pressed = raylib.isMouseButtonPressed(.right);
        const key_delete = raylib.isKeyPressed(.delete);

        // Handle context menu.
        if (right_pressed) {
            self.menu_open = true;
            self.menu_pos = mouse_pos;
        }

        if (self.menu_open) {
            if (mouse_pressed and !self.isOverMenu(mouse_pos)) {
                self.menu_open = false;
            }
            return;
        }

        // Selection and dragging.
        if (mouse_pressed) {
            self.selected_node = null;
            self.is_dragging = false;

            var i: usize = self.graph.nodes.items.len;
            while (i > 0) {
                i -= 1;
                const node = &self.graph.nodes.items[i];
                const node_rect = raylib.Rectangle{ .x = node.position.x, .y = node.position.y, .width = 180, .height = 140 };
                if (raylib.checkCollisionPointRec(mouse_pos, node_rect)) {
                    self.selected_node = node.id;
                    self.is_dragging = true;
                    self.drag_offset = .{ .x = mouse_pos.x - node.position.x, .y = mouse_pos.y - node.position.y };
                    break;
                }
            }
        }

        if (self.is_dragging and mouse_down) {
            if (self.selected_node) |id| {
                if (self.graph.findNodeIndex(id)) |idx| {
                    self.graph.nodes.items[idx].position = .{
                        .x = mouse_pos.x - self.drag_offset.x,
                        .y = mouse_pos.y - self.drag_offset.y,
                    };
                }
            }
        } else {
            self.is_dragging = false;
        }

        // Deletion.
        if (key_delete) {
            if (self.selected_node) |id| {
                if (self.graph.findNodeIndex(id)) |idx| {
                    if (!std.mem.eql(u8, self.graph.nodes.items[idx].node_type, "PBR Output")) {
                        self.graph.removeNode(id) catch {};
                        self.selected_node = null;
                    }
                }
            }
        }
    }

    /// Render the material node editor UI.
    pub fn render(self: *MaterialNodeEditor, width: f32, height: f32) void {
        raylib.drawRectangle(0, 0, @intFromFloat(width), @intFromFloat(height), raylib.Color{ .r = 30, .g = 30, .b = 40, .a = 255 });

        // Draw grid.
        const grid_size = 50;
        var x: f32 = 0;
        while (x < width) : (x += grid_size) {
            raylib.drawLine(@intFromFloat(x), 0, @intFromFloat(x), @intFromFloat(height), raylib.Color{ .r = 45, .g = 45, .b = 55, .a = 255 });
        }
        var y: f32 = 0;
        while (y < height) : (y += grid_size) {
            raylib.drawLine(0, @intFromFloat(y), @intFromFloat(width), @intFromFloat(y), raylib.Color{ .r = 45, .g = 45, .b = 55, .a = 255 });
        }

        // Draw nodes.
        for (self.graph.nodes.items) |node| {
            const is_selected = self.selected_node != null and self.selected_node.? == node.id;
            const node_rect = raylib.Rectangle{ .x = node.position.x, .y = node.position.y, .width = 180, .height = 140 };

            // Node body.
            raylib.drawRectangleRec(node_rect, raylib.Color{ .r = 50, .g = 50, .b = 60, .a = 255 });
            const border_color = if (is_selected) raylib.Color.yellow else raylib.Color{ .r = 80, .g = 80, .b = 90, .a = 255 };
            raylib.drawRectangleLinesEx(node_rect, 2, border_color);

            // Header.
            const header_color = if (std.mem.eql(u8, node.node_type, "PBR Output"))
                raylib.Color{ .r = 180, .g = 70, .b = 70, .a = 255 }
            else
                raylib.Color{ .r = 70, .g = 70, .b = 180, .a = 255 };
            raylib.drawRectangle(@intFromFloat(node.position.x), @intFromFloat(node.position.y), 180, 25, header_color);
            var node_title_buf: [128:0]u8 = undefined;
            const node_title = std.fmt.bufPrintZ(&node_title_buf, "{s}", .{node.node_type}) catch "Node";
            raylib.drawText(node_title, @intFromFloat(node.position.x + 10), @intFromFloat(node.position.y + 5), 14, raylib.Color.white);

            // Inputs.
            for (node.inputs.items, 0..) |input, idx| {
                const input_y = node.position.y + 35 + @as(f32, @floatFromInt(idx)) * 18;
                raylib.drawCircle(@intFromFloat(node.position.x), @intFromFloat(input_y), 4, raylib.Color.yellow);
                var input_name_buf: [128:0]u8 = undefined;
                const input_name_z = std.fmt.bufPrintZ(&input_name_buf, "{s}", .{input.name}) catch "Param";
                raylib.drawText(input_name_z, @intFromFloat(node.position.x + 10), @intFromFloat(input_y - 6), 12, raylib.Color.light_gray);
            }

            // Outputs.
            for (node.outputs.items, 0..) |output, idx| {
                const output_y = node.position.y + 35 + @as(f32, @floatFromInt(idx)) * 18;
                raylib.drawCircle(@intFromFloat(node.position.x + 180), @intFromFloat(output_y), 4, raylib.Color.green);
                var out_name_buf: [128:0]u8 = undefined;
                const out_name_z = std.fmt.bufPrintZ(&out_name_buf, "{s}", .{output.name}) catch "Param";
                const text_width = raylib.measureText(out_name_z, 12);
                raylib.drawText(out_name_z, @intFromFloat(node.position.x + 170 - @as(f32, @floatFromInt(text_width))), @intFromFloat(output_y - 6), 12, raylib.Color.light_gray);
            }
        }

        // Draw context menu.
        if (self.menu_open) {
            const menu_rect = raylib.Rectangle{ .x = self.menu_pos.x, .y = self.menu_pos.y, .width = 150, .height = 100 };
            raylib.drawRectangleRec(menu_rect, raylib.Color{ .r = 45, .g = 45, .b = 55, .a = 255 });
            raylib.drawRectangleLinesEx(menu_rect, 1, raylib.Color.gray);

            const items = [_][]const u8{ "Color", "Texture", "Mix" };
            for (items, 0..) |item, i| {
                const item_rect = raylib.Rectangle{
                    .x = self.menu_pos.x,
                    .y = self.menu_pos.y + @as(f32, @floatFromInt(i)) * 25,
                    .width = 150,
                    .height = 25,
                };
                if (raylib.checkCollisionPointRec(raylib.getMousePosition(), item_rect)) {
                    raylib.drawRectangleRec(item_rect, raylib.Color{ .r = 70, .g = 70, .b = 180, .a = 255 });
                    if (raylib.isMouseButtonPressed(.left)) {
                        self.createNode(item, self.menu_pos);
                    }
                }
                raylib.drawText(item, @intFromFloat(item_rect.x + 10), @intFromFloat(item_rect.y + 5), 14, raylib.Color.white);
            }
        }

        raylib.drawText("Material Node Editor", 20, 20, 20, raylib.Color.gray);
    }

    fn isOverMenu(self: *const MaterialNodeEditor, pos: raylib.Vector2) bool {
        const menu_rect = raylib.Rectangle{ .x = self.menu_pos.x, .y = self.menu_pos.y, .width = 150, .height = 100 };
        return raylib.checkCollisionPointRec(pos, menu_rect);
    }

    fn createNode(self: *MaterialNodeEditor, node_type: []const u8, pos: raylib.Vector2) void {
        var vtable: nodes.NodeGraph.Node.NodeVTable = undefined;
        var initFn: ?*const fn (*nodes.NodeGraph.Node) anyerror!void = null;

        if (std.mem.eql(u8, node_type, "Color")) {
            vtable = material_nodes.ColorNode.createVTable();
            initFn = material_nodes.ColorNode.initNode;
        } else if (std.mem.eql(u8, node_type, "Texture")) {
            vtable = material_nodes.TextureNode.createVTable();
            initFn = material_nodes.TextureNode.initNode;
        } else if (std.mem.eql(u8, node_type, "Mix")) {
            vtable = material_nodes.MixNode.createVTable();
            initFn = material_nodes.MixNode.initNode;
        } else return;

        const id = self.graph.addNode(node_type, &vtable) catch return;
        if (self.graph.findNodeIndex(id)) |idx| {
            if (initFn) |f| f(&self.graph.nodes.items[idx]) catch {};
            self.graph.nodes.items[idx].position = pos;
        }
        self.menu_open = false;
    }
};
