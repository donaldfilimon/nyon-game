const std = @import("std");
const nodes = @import("nodes/node_graph.zig");

pub const MaterialShaderGen = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) MaterialShaderGen {
        return .{ .allocator = allocator };
    }

    pub fn generateShader(self: *MaterialShaderGen, graph: *nodes.NodeGraph) ![]const u8 {
        var code = std.ArrayList(u8).init(self.allocator);
        errdefer code.deinit();

        const writer = code.writer();

        // Header
        try writer.writeAll("#version 330\n");
        try writer.writeAll("in vec2 fragTexCoord;\n");
        try writer.writeAll("in vec4 fragColor;\n");
        try writer.writeAll("out vec4 finalColor;\n\n");

        // Uniforms
        // TODO: Dynamically gather used textures and constant values
        try writer.writeAll("uniform sampler2D texture0;\n");
        try writer.writeAll("uniform vec4 baseColor;\n\n");

        try writer.writeAll("void main() {\n");

        // Traverse graph and generate local variables for each node's outputs
        const order = try graph.getTopologicalOrder(self.allocator);
        defer self.allocator.free(order);

        for (order) |node_id| {
            const node_index = graph.findNodeIndex(node_id).?;
            const node = &graph.nodes.items[node_index];

            if (std.mem.eql(u8, node.node_type, "PBR Output")) {
                // Final assignment
                // For now, just handle Albedo
                try writer.print("    finalColor = var_{d}_out_0;\n", .{node_id});
            } else if (std.mem.eql(u8, node.node_type, "Color")) {
                const color = node.inputs.items[0].constant_value.?.color;
                try writer.print("    vec4 var_{d}_out_0 = vec4({d}, {d}, {d}, {d});\n", .{
                    node_id,
                    @as(f32, @floatFromInt(color.r)) / 255.0,
                    @as(f32, @floatFromInt(color.g)) / 255.0,
                    @as(f32, @floatFromInt(color.b)) / 255.0,
                    @as(f32, @floatFromInt(color.a)) / 255.0,
                });
            } else if (std.mem.eql(u8, node.node_type, "Mix")) {
                // Get input names/ids
                // This part needs a way to look up which node output is connected to which input
                // For simplicity in this first version, we'll assume the graph is evaluated and
                // we use the variable names var_{id}_out_{output_idx}

                // Find connection for input 0
                const a_src = self.getConnectedVar(graph, node_id, 0) orelse "vec4(0,0,0,1)";
                const b_src = self.getConnectedVar(graph, node_id, 1) orelse "vec4(1,1,1,1)";
                const factor_src = self.getConnectedVar(graph, node_id, 2) orelse "0.5";

                try writer.print("    vec4 var_{d}_out_0 = mix({s}, {s}, {s});\n", .{ node_id, a_src, b_src, factor_src });
            }
        }

        try writer.writeAll("}\n");

        return code.toOwnedSlice();
    }

    fn getConnectedVar(self: *MaterialShaderGen, graph: *nodes.NodeGraph, to_node: usize, to_input: usize) ?[]const u8 {
        for (graph.connections.items) |conn| {
            if (conn.to_node == to_node and conn.to_input == to_input) {
                return std.fmt.allocPrint(self.allocator, "var_{d}_out_{d}", .{ conn.from_node, conn.from_output }) catch null;
            }
        }
        return null;
    }
};
