//! Transformation nodes for geometry node system.
//!
//! Provides transformation nodes for translating, scaling, and rotating meshes.

const std = @import("std");
const raylib = @import("raylib");
const nodes = @import("nodes/node_graph.zig");

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

        var transformed_mesh = input_mesh;

        const transformed_vertex_count: usize = @intCast(transformed_mesh.vertexCount);
        if (transformed_mesh.vertices) |vertices| {
            const vertex_slice = vertices[0..@intCast(transformed_vertex_count * 3)];
            for (0..transformed_vertex_count) |i| {
                const vertex_index = i * 3;
                vertex_slice[vertex_index] += translation.x;
                vertex_slice[vertex_index + 1] += translation.y;
                vertex_slice[vertex_index + 2] += translation.z;
            }
        }

        var outputs = try allocator.alloc(nodes.NodeGraph.Value, 1);
        outputs[0] = .{ .mesh = transformed_mesh };
        return outputs;
    }

    fn deinit(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}

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

        var scaled_mesh = input_mesh;

        const scaled_vertex_count: usize = @intCast(scaled_mesh.vertexCount);
        if (scaled_mesh.vertices) |vertices| {
            const vertex_slice = vertices[0..@intCast(scaled_vertex_count * 3)];
            for (0..scaled_vertex_count) |i| {
                const vertex_index = i * 3;
                vertex_slice[vertex_index] *= scale.x;
                vertex_slice[vertex_index + 1] *= scale.y;
                vertex_slice[vertex_index + 2] *= scale.z;
            }
        }

        if (scaled_mesh.normals) |normals| {
            const normal_slice = normals[0 .. scaled_vertex_count * 3];
            for (0..scaled_vertex_count) |i| {
                const idx = i * 3;
                normal_slice[idx] *= (1.0 / scale.x);
                normal_slice[idx + 1] *= (1.0 / scale.y);
                normal_slice[idx + 2] *= (1.0 / scale.z);

                const len = @sqrt(normal_slice[idx] * normal_slice[idx] + normal_slice[idx + 1] * normal_slice[idx + 1] + normal_slice[idx + 2] * normal_slice[idx + 2]);
                if (len > 0.00001) {
                    normal_slice[idx] /= len;
                    normal_slice[idx + 1] /= len;
                    normal_slice[idx + 2] /= len;
                }
            }
        }

        var outputs = try allocator.alloc(nodes.NodeGraph.Value, 1);
        outputs[0] = .{ .mesh = scaled_mesh };
        return outputs;
    }

    fn deinit(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}

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
        const rotation = inputs[1].vector3;

        var rotated_mesh = input_mesh;

        const rot_x_rad = rotation.x * std.math.pi / 180.0;
        const rot_y_rad = rotation.y * std.math.pi / 180.0;
        const rot_z_rad = rotation.z * std.math.pi / 180.0;

        const rotated_vertex_count: usize = @intCast(rotated_mesh.vertexCount);
        if (rotated_mesh.vertices) |vertices| {
            const vertex_slice = vertices[0..@intCast(rotated_vertex_count * 3)];
            for (0..rotated_vertex_count) |i| {
                const vertex_index = i * 3;
                const x = vertex_slice[vertex_index];
                const y = vertex_slice[vertex_index + 1];
                const z = vertex_slice[vertex_index + 2];

                const cos_x = @cos(rot_x_rad);
                const sin_x = @sin(rot_x_rad);
                const cos_y = @cos(rot_y_rad);
                const sin_y = @sin(rot_y_rad);
                const cos_z = @cos(rot_z_rad);
                const sin_z = @sin(rot_z_rad);

                const y1 = y * cos_x - z * sin_x;
                const z1 = y * sin_x + z * cos_x;

                const x2 = x * cos_y + z1 * sin_y;
                const z2 = -x * sin_y + z1 * cos_y;

                const x3 = x2 * cos_z - y1 * sin_z;
                const y3 = x2 * sin_z + y1 * cos_z;

                vertex_slice[vertex_index] = x3;
                vertex_slice[vertex_index + 1] = y3;
                vertex_slice[vertex_index + 2] = z2;
            }
        }

        var outputs = try allocator.alloc(nodes.NodeGraph.Value, 1);
        outputs[0] = .{ .mesh = rotated_mesh };
        return outputs;
    }

    fn deinit(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Geometry", .mesh, null);
        try node.addInput("Rotation", .vector3, .{ .vector3 = .{ .x = 0, .y = 0, .z = 0 } });
        try node.addOutput("Geometry", .mesh);
    }
};
