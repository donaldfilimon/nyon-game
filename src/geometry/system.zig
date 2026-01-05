//! Geometry node system for the Nyon Game Engine.
//!
//! Main system that manages the geometry node graph, including node creation,
//! execution, and output retrieval.

const std = @import("std");
const raylib = @import("raylib");
const nodes = @import("nodes/node_graph.zig");

const primitives = @import("primitives.zig");
const transformations = @import("transformations.zig");

pub const CubeNode = primitives.CubeNode;
pub const SphereNode = primitives.SphereNode;
pub const CylinderNode = primitives.CylinderNode;
pub const ConeNode = primitives.ConeNode;
pub const PlaneNode = primitives.PlaneNode;
pub const TranslateNode = transformations.TranslateNode;
pub const ScaleNode = transformations.ScaleNode;
pub const RotateNode = transformations.RotateNode;

/// Simplified geometry node system for Phase 1
/// Focuses on core node graph functionality with basic primitives
pub const GeometryNodeSystem = struct {
    graph: nodes.NodeGraph,
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

    pub fn executeGraph(self: *GeometryNodeSystem) void {
        self.graph.execute() catch {};
    }

    pub fn getFinalGeometry(self: *GeometryNodeSystem) ?raylib.Mesh {
        if (self.graph.nodes.items.len == 0) return null;

        const last_node_id = self.graph.nodes.items[self.graph.nodes.items.len - 1].id;
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

    pub fn createNode(self: *GeometryNodeSystem, node_type: []const u8) nodes.NodeGraph.NodeId {
        var vtable: nodes.NodeGraph.Node.NodeVTable = undefined;

        if (std.mem.eql(u8, node_type, "Cube")) {
            vtable = CubeNode.createVTable();
        } else if (std.mem.eql(u8, node_type, "Sphere")) {
            vtable = SphereNode.createVTable();
        } else if (std.mem.eql(u8, node_type, "Cylinder")) {
            vtable = CylinderNode.createVTable();
        } else if (std.mem.eql(u8, node_type, "Cone")) {
            vtable = ConeNode.createVTable();
        } else if (std.mem.eql(u8, node_type, "Plane")) {
            vtable = PlaneNode.createVTable();
        } else if (std.mem.eql(u8, node_type, "Translate")) {
            vtable = TranslateNode.createVTable();
        } else if (std.mem.eql(u8, node_type, "Scale")) {
            vtable = ScaleNode.createVTable();
        } else if (std.mem.eql(u8, node_type, "Rotate")) {
            vtable = RotateNode.createVTable();
        } else {
            return 0;
        }

        const node_id = self.graph.addNode(node_type, &vtable) catch return 0;
        const node_index = self.graph.findNodeIndex(node_id) orelse return 0;
        const node = &self.graph.nodes.items[node_index];

        if (std.mem.eql(u8, node_type, "Cube")) {
            CubeNode.initNode(node) catch {};
        } else if (std.mem.eql(u8, node_type, "Sphere")) {
            SphereNode.initNode(node) catch {};
        } else if (std.mem.eql(u8, node_type, "Cylinder")) {
            CylinderNode.initNode(node) catch {};
        } else if (std.mem.eql(u8, node_type, "Cone")) {
            ConeNode.initNode(node) catch {};
        } else if (std.mem.eql(u8, node_type, "Plane")) {
            PlaneNode.initNode(node) catch {};
        } else if (std.mem.eql(u8, node_type, "Translate")) {
            TranslateNode.initNode(node) catch {};
        } else if (std.mem.eql(u8, node_type, "Scale")) {
            ScaleNode.initNode(node) catch {};
        } else if (std.mem.eql(u8, node_type, "Rotate")) {
            RotateNode.initNode(node) catch {};
        }

        return node_id;
    }

    pub fn deleteNode(self: *GeometryNodeSystem, node_id: nodes.NodeGraph.NodeId) void {
        self.graph.removeNode(node_id) catch {};
    }

    pub fn connectNodes(self: *GeometryNodeSystem, from_node: nodes.NodeGraph.NodeId, from_output: usize, to_node: nodes.NodeGraph.NodeId, to_input: usize) !void {
        try self.graph.connectNodes(from_node, from_output, to_node, to_input);
    }

    pub fn disconnectNodes(self: *GeometryNodeSystem, from_node: nodes.NodeGraph.NodeId, from_output: usize, to_node: nodes.NodeGraph.NodeId, to_input: usize) void {
        self.graph.disconnectNodes(from_node, from_output, to_node, to_input) catch {};
    }

    pub fn getNodeCount(self: *const GeometryNodeSystem) usize {
        return self.graph.nodes.items.len;
    }

    pub fn getNodes(self: *const GeometryNodeSystem) []const nodes.NodeGraph.Node {
        return self.graph.nodes.items;
    }

    pub fn selectNode(self: *GeometryNodeSystem, node_id: ?nodes.NodeGraph.NodeId) void {
        self.selected_node = node_id;
    }

    pub fn getSelectedNode(self: *const GeometryNodeSystem) ?nodes.NodeGraph.NodeId {
        return self.selected_node;
    }
};
