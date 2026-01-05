//! Primitive shape nodes for geometry node system.
//!
//! Provides basic geometric primitive nodes (cube, sphere, cylinder, cone, plane)
//! that generate raylib meshes with configurable parameters.

const std = @import("std");
const raylib = @import("raylib");
const nodes = @import("../nodes/node_graph.zig");

/// Cube primitive node
pub const CubeNode = struct {
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

/// Cylinder primitive node
pub const CylinderNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
        const radius = if (inputs.len > 0 and inputs[0] == .float) inputs[0].float else 1.0;
        const height = if (inputs.len > 1 and inputs[1] == .float) inputs[1].float else 2.0;
        const slices = if (inputs.len > 2 and inputs[2] == .int) @as(i32, inputs[2].int) else 16;

        const mesh = raylib.genMeshCylinder(radius, height, slices);
        return try allocator.dupe(nodes.NodeGraph.Value, &[_]nodes.NodeGraph.Value{.{ .mesh = mesh }});
    }

    fn deinit(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Radius", .float, .{ .float = 1.0 });
        try node.addInput("Height", .float, .{ .float = 2.0 });
        try node.addInput("Slices", .int, .{ .int = 16 });
        try node.addOutput("Geometry", .mesh);
    }
};

/// Cone primitive node
pub const ConeNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
        const radius = if (inputs.len > 0 and inputs[0] == .float) inputs[0].float else 1.0;
        const height = if (inputs.len > 1 and inputs[1] == .float) inputs[1].float else 2.0;
        const slices = if (inputs.len > 2 and inputs[2] == .int) @as(i32, inputs[2].int) else 16;

        const mesh = raylib.genMeshCone(radius, height, slices);
        return try allocator.dupe(nodes.NodeGraph.Value, &[_]nodes.NodeGraph.Value{.{ .mesh = mesh }});
    }

    fn deinit(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Radius", .float, .{ .float = 1.0 });
        try node.addInput("Height", .float, .{ .float = 2.0 });
        try node.addInput("Slices", .int, .{ .int = 16 });
        try node.addOutput("Geometry", .mesh);
    }
};

/// Plane primitive node
pub const PlaneNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
        const width = if (inputs.len > 0 and inputs[0] == .float) inputs[0].float else 10.0;
        const length = if (inputs.len > 1 and inputs[1] == .float) inputs[1].float else 10.0;
        const res_x = if (inputs.len > 2 and inputs[2] == .int) @as(i32, inputs[2].int) else 10;
        const res_y = if (inputs.len > 3 and inputs[3] == .int) @as(i32, inputs[3].int) else 10;

        const mesh = raylib.genMeshPlane(width, length, res_x, res_y);
        return try allocator.dupe(nodes.NodeGraph.Value, &[_]nodes.NodeGraph.Value{.{ .mesh = mesh }});
    }

    fn deinit(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Width", .float, .{ .float = 10.0 });
        try node.addInput("Length", .float, .{ .float = 10.0 });
        try node.addInput("Res X", .int, .{ .int = 10 });
        try node.addInput("Res Y", .int, .{ .int = 10 });
        try node.addOutput("Geometry", .mesh);
    }
};
