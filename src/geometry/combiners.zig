//! Combiner nodes for geometry node system.
//!
//! Provides mesh combining operations for merging multiple meshes.

const std = @import("std");
const raylib = @import("raylib");
const nodes = @import("../nodes/node_graph.zig");

/// Merge node
/// Combines multiple meshes into a single mesh without boolean operations
pub const MergeNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
        if (inputs.len < 2) return error.InvalidInputCount;

        const mesh_a = inputs[0].mesh;
        const mesh_b = inputs[1].mesh;

        const merged_mesh = try mergeTwoMeshes(mesh_a, mesh_b, allocator);

        var outputs = try allocator.alloc(nodes.NodeGraph.Value, 1);
        outputs[0] = .{ .mesh = merged_mesh };
        return outputs;
    }

    fn deinit(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Geometry A", .mesh, null);
        try node.addInput("Geometry B", .mesh, null);
        try node.addOutput("Geometry", .mesh);
    }
};

/// Merge two meshes into one
fn mergeTwoMeshes(mesh_a: raylib.Mesh, mesh_b: raylib.Mesh, allocator: std.mem.Allocator) !raylib.Mesh {
    const vert_count_a: usize = @intCast(mesh_a.vertexCount);
    const vert_count_b: usize = @intCast(mesh_b.vertexCount);
    const tri_count_a: usize = @intCast(mesh_a.triangleCount);
    const tri_count_b: usize = @intCast(mesh_b.triangleCount);

    const total_verts = vert_count_a + vert_count_b;
    const total_tris = tri_count_a + tri_count_b;

    // Allocate merged arrays
    const vertices = try allocator.alloc(f32, total_verts * 3);
    const normals = try allocator.alloc(f32, total_verts * 3);
    var texcoords: ?[]f32 = null;
    const indices = try allocator.alloc(u16, total_tris * 3);

    // Copy vertices from mesh A
    if (mesh_a.vertices) |verts| {
        @memcpy(vertices[0 .. vert_count_a * 3], verts[0 .. vert_count_a * 3]);
    }
    // Copy vertices from mesh B
    if (mesh_b.vertices) |verts| {
        @memcpy(vertices[vert_count_a * 3 ..], verts[0 .. vert_count_b * 3]);
    }

    // Copy normals from mesh A
    if (mesh_a.normals) |norms| {
        @memcpy(normals[0 .. vert_count_a * 3], norms[0 .. vert_count_a * 3]);
    } else {
        @memset(normals[0 .. vert_count_a * 3], 0);
    }
    // Copy normals from mesh B
    if (mesh_b.normals) |norms| {
        @memcpy(normals[vert_count_a * 3 ..], norms[0 .. vert_count_b * 3]);
    } else {
        @memset(normals[vert_count_a * 3 ..], 0);
    }

    // Copy texcoords if both meshes have them
    if (mesh_a.texcoords != null and mesh_b.texcoords != null) {
        texcoords = try allocator.alloc(f32, total_verts * 2);
        if (mesh_a.texcoords) |uvs| {
            @memcpy(texcoords.?[0 .. vert_count_a * 2], uvs[0 .. vert_count_a * 2]);
        }
        if (mesh_b.texcoords) |uvs| {
            @memcpy(texcoords.?[vert_count_a * 2 ..], uvs[0 .. vert_count_b * 2]);
        }
    }

    // Copy indices from mesh A
    if (mesh_a.indices) |idx| {
        @memcpy(indices[0 .. tri_count_a * 3], idx[0 .. tri_count_a * 3]);
    }
    // Copy indices from mesh B with offset
    if (mesh_b.indices) |idx| {
        for (0..tri_count_b * 3) |i| {
            indices[tri_count_a * 3 + i] = idx[i] + @as(u16, @intCast(vert_count_a));
        }
    }

    var mesh = raylib.Mesh{
        .vertexCount = @intCast(total_verts),
        .triangleCount = @intCast(total_tris),
        .vertices = vertices.ptr,
        .normals = normals.ptr,
        .texcoords = if (texcoords) |tc| tc.ptr else null,
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

/// Merge multiple meshes from a list
pub fn mergeMultipleMeshes(meshes: []const raylib.Mesh, allocator: std.mem.Allocator) !raylib.Mesh {
    if (meshes.len == 0) return error.EmptyMeshList;
    if (meshes.len == 1) return meshes[0];

    var result = try mergeTwoMeshes(meshes[0], meshes[1], allocator);
    for (meshes[2..]) |mesh| {
        result = try mergeTwoMeshes(result, mesh, allocator);
    }
    return result;
}

test "merge two meshes" {
    // Test would require raylib mesh generation, skip for unit testing
}
