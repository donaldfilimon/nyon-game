const std = @import("std");
const raylib = @import("raylib");
const nodes = @import("nodes/node_graph.zig");

/// PBR Output Node - The final sink for material properties
pub const PBREutputNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Albedo", .color, .{ .color = raylib.Color.white });
        try node.addInput("Normal", .texture, null);
        try node.addInput("Metalness", .float, .{ .float = 0.0 });
        try node.addInput("Roughness", .float, .{ .float = 0.5 });
        try node.addInput("Emission", .color, .{ .color = raylib.Color.black });
        try node.addInput("Occlusion", .float, .{ .float = 1.0 });
    }

    fn execute(node: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, _: std.mem.Allocator) nodes.NodeGraph.GraphError![]nodes.NodeGraph.Value {
        _ = node;
        _ = inputs;
        // Output node doesn't produce values for other nodes, it's a final sink.
        return &.{};
    }

    fn deinit(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}
};

/// Color constant node
pub const ColorNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Value", .color, .{ .color = raylib.Color.white });
        try node.addOutput("Color", .color);
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) nodes.NodeGraph.GraphError![]nodes.NodeGraph.Value {
        const outputs = try allocator.alloc(nodes.NodeGraph.Value, 1);
        outputs[0] = inputs[0];
        return outputs;
    }

    fn deinit(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}
};

/// Texture sampler node
pub const TextureNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Texture", .texture, null);
        try node.addOutput("Color", .color);
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) nodes.NodeGraph.GraphError![]nodes.NodeGraph.Value {
        const outputs = try allocator.alloc(nodes.NodeGraph.Value, 1);
        // In a real execution, we might return a sample.
        // For node graph evaluation, we just pass the default color if no texture.
        outputs[0] = .{ .color = raylib.Color.white };
        _ = inputs;
        return outputs;
    }

    fn deinit(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}
};

/// Mix/Lerp node for colors
pub const MixNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("A", .color, .{ .color = raylib.Color.black });
        try node.addInput("B", .color, .{ .color = raylib.Color.white });
        try node.addInput("Factor", .float, .{ .float = 0.5 });
        try node.addOutput("Result", .color);
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) nodes.NodeGraph.GraphError![]nodes.NodeGraph.Value {
        const a = inputs[0].color;
        const b = inputs[1].color;
        const factor = inputs[2].float;

        const result = raylib.Color{
            .r = @intFromFloat(@as(f32, @floatFromInt(a.r)) * (1.0 - factor) + @as(f32, @floatFromInt(b.r)) * factor),
            .g = @intFromFloat(@as(f32, @floatFromInt(a.g)) * (1.0 - factor) + @as(f32, @floatFromInt(b.g)) * factor),
            .b = @intFromFloat(@as(f32, @floatFromInt(a.b)) * (1.0 - factor) + @as(f32, @floatFromInt(b.b)) * factor),
            .a = @intFromFloat(@as(f32, @floatFromInt(a.a)) * (1.0 - factor) + @as(f32, @floatFromInt(b.a)) * factor),
        };

        const outputs = try allocator.alloc(nodes.NodeGraph.Value, 1);
        outputs[0] = .{ .color = result };
        return outputs;
    }

    fn deinit(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}
};
