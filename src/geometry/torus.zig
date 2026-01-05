//! Torus primitive node for geometry node system.
//!
//! Generates a torus (donut shape) mesh with configurable major/minor radii and segments.

const std = @import("std");
const raylib = @import("raylib");
const nodes = @import("../nodes/node_graph.zig");

/// Torus primitive node
/// Generates a torus mesh with configurable parameters:
/// - Major radius: distance from center to tube center
/// - Minor radius: radius of the tube
/// - Ring segments: divisions around the major axis
/// - Tube segments: divisions around the tube
pub const TorusNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
        const major_radius = if (inputs.len > 0 and inputs[0] == .float) inputs[0].float else 1.0;
        const minor_radius = if (inputs.len > 1 and inputs[1] == .float) inputs[1].float else 0.3;
        const ring_segments = if (inputs.len > 2 and inputs[2] == .int) @as(u32, @intCast(inputs[2].int)) else 32;
        const tube_segments = if (inputs.len > 3 and inputs[3] == .int) @as(u32, @intCast(inputs[3].int)) else 16;

        const mesh = generateTorusMesh(allocator, major_radius, minor_radius, ring_segments, tube_segments) catch |err| {
            std.debug.print("Failed to generate torus mesh: {}\n", .{err});
            return error.MeshGenerationFailed;
        };

        return try allocator.dupe(nodes.NodeGraph.Value, &[_]nodes.NodeGraph.Value{.{ .mesh = mesh }});
    }

    fn deinit(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Major Radius", .float, .{ .float = 1.0 });
        try node.addInput("Minor Radius", .float, .{ .float = 0.3 });
        try node.addInput("Ring Segments", .int, .{ .int = 32 });
        try node.addInput("Tube Segments", .int, .{ .int = 16 });
        try node.addOutput("Geometry", .mesh);
    }
};

/// Generate a torus mesh with the given parameters
fn generateTorusMesh(
    allocator: std.mem.Allocator,
    major_radius: f32,
    minor_radius: f32,
    ring_segments: u32,
    tube_segments: u32,
) !raylib.Mesh {
    const vertex_count = (ring_segments + 1) * (tube_segments + 1);
    const triangle_count = ring_segments * tube_segments * 2;

    // Allocate vertex data
    const vertices = try allocator.alloc(f32, vertex_count * 3);
    const normals = try allocator.alloc(f32, vertex_count * 3);
    const texcoords = try allocator.alloc(f32, vertex_count * 2);
    const indices = try allocator.alloc(u16, triangle_count * 3);

    // Generate vertices
    var vertex_idx: usize = 0;
    for (0..ring_segments + 1) |i| {
        const theta = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(ring_segments)) * std.math.pi * 2.0;
        const cos_theta = @cos(theta);
        const sin_theta = @sin(theta);

        for (0..tube_segments + 1) |j| {
            const phi = @as(f32, @floatFromInt(j)) / @as(f32, @floatFromInt(tube_segments)) * std.math.pi * 2.0;
            const cos_phi = @cos(phi);
            const sin_phi = @sin(phi);

            // Position
            const x = (major_radius + minor_radius * cos_phi) * cos_theta;
            const y = minor_radius * sin_phi;
            const z = (major_radius + minor_radius * cos_phi) * sin_theta;

            vertices[vertex_idx * 3 + 0] = x;
            vertices[vertex_idx * 3 + 1] = y;
            vertices[vertex_idx * 3 + 2] = z;

            // Normal
            const nx = cos_phi * cos_theta;
            const ny = sin_phi;
            const nz = cos_phi * sin_theta;

            normals[vertex_idx * 3 + 0] = nx;
            normals[vertex_idx * 3 + 1] = ny;
            normals[vertex_idx * 3 + 2] = nz;

            // Texture coordinates
            texcoords[vertex_idx * 2 + 0] = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(ring_segments));
            texcoords[vertex_idx * 2 + 1] = @as(f32, @floatFromInt(j)) / @as(f32, @floatFromInt(tube_segments));

            vertex_idx += 1;
        }
    }

    // Generate indices
    var index_idx: usize = 0;
    for (0..ring_segments) |i| {
        for (0..tube_segments) |j| {
            const current = @as(u16, @intCast(i * (tube_segments + 1) + j));
            const next = @as(u16, @intCast((i + 1) * (tube_segments + 1) + j));

            // First triangle
            indices[index_idx + 0] = current;
            indices[index_idx + 1] = next;
            indices[index_idx + 2] = current + 1;

            // Second triangle
            indices[index_idx + 3] = current + 1;
            indices[index_idx + 4] = next;
            indices[index_idx + 5] = next + 1;

            index_idx += 6;
        }
    }

    // Create raylib mesh
    var mesh = raylib.Mesh{
        .vertexCount = @intCast(vertex_count),
        .triangleCount = @intCast(triangle_count),
        .vertices = vertices.ptr,
        .normals = normals.ptr,
        .texcoords = texcoords.ptr,
        .texcoords2 = null,
        .colors = null,
        .indices = indices.ptr,
        .animVertices = null,
        .animNormals = null,
        .boneIds = null,
        .boneWeights = null,
        .boneMatrices = null,
        .boneCount = 0,
        .vaoId = 0,
        .vboId = null,
        .tangents = null,
    };

    raylib.uploadMesh(&mesh, false);
    return mesh;
}

test "torus node generates valid mesh" {
    const allocator = std.testing.allocator;
    const mesh = try generateTorusMesh(allocator, 1.0, 0.3, 16, 8);
    defer {
        allocator.free(mesh.vertices[0..@intCast(mesh.vertexCount * 3)]);
        allocator.free(mesh.normals[0..@intCast(mesh.vertexCount * 3)]);
        allocator.free(mesh.texcoords[0..@intCast(mesh.vertexCount * 2)]);
        allocator.free(mesh.indices[0..@intCast(mesh.triangleCount * 3)]);
    }

    try std.testing.expect(mesh.vertexCount > 0);
    try std.testing.expect(mesh.triangleCount > 0);
}
