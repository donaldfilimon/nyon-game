//! Modifier nodes for geometry node system.
//!
//! Provides mesh modification nodes: Mirror, Bevel, Subdivide, Noise displacement.

const std = @import("std");
const raylib = @import("raylib");
const nodes = @import("../nodes/node_graph.zig");
const mesh_ops = @import("mesh_operations.zig");

/// Mirror transformation node
/// Mirrors mesh geometry across a specified axis
pub const MirrorNode = struct {
    pub const Axis = enum(u8) { x = 0, y = 1, z = 2 };

    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
        if (inputs.len < 1) return error.InvalidInputCount;

        const input_mesh = inputs[0].mesh;
        const axis = if (inputs.len > 1 and inputs[1] == .int) @as(Axis, @enumFromInt(@as(u8, @intCast(inputs[1].int)))) else .x;
        const merge = if (inputs.len > 2 and inputs[2] == .bool) inputs[2].bool else true;

        var mirrored_mesh = try mesh_ops.copyMesh(input_mesh, allocator);

        // Mirror vertices along the specified axis
        const vertex_count: usize = @intCast(mirrored_mesh.vertexCount);
        if (mirrored_mesh.vertices) |vertices| {
            const vertex_slice = vertices[0 .. vertex_count * 3];
            for (0..vertex_count) |i| {
                const idx = i * 3 + @intFromEnum(axis);
                vertex_slice[idx] = -vertex_slice[idx];
            }
        }

        // Flip normals
        if (mirrored_mesh.normals) |normap| {
            const normal_slice = normap[0 .. vertex_count * 3];
            for (0..vertex_count) |i| {
                const idx = i * 3 + @intFromEnum(axis);
                normal_slice[idx] = -normal_slice[idx];
            }
        }

        _ = merge; // TODO: Merge original and mirrored when merge is true

        var outputs = try allocator.alloc(nodes.NodeGraph.Value, 1);
        outputs[0] = .{ .mesh = mirrored_mesh };
        return outputs;
    }

    fn deinit(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Geometry", .mesh, null);
        try node.addInput("Axis", .int, .{ .int = 0 }); // 0=X, 1=Y, 2=Z
        try node.addInput("Merge", .bool, .{ .bool = true });
        try node.addOutput("Geometry", .mesh);
    }
};

/// Subdivide node
/// Applies mesh subdivision to increase polygon count
pub const SubdivideNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
        if (inputs.len < 1) return error.InvalidInputCount;

        const input_mesh = inputs[0].mesh;
        const iterations = if (inputs.len > 1 and inputs[1] == .int) @as(u32, @intCast(@max(1, inputs[1].int))) else 1;

        // Simple linear subdivision (splits each triangle into 4)
        var current_mesh = try mesh_ops.copyMesh(input_mesh, allocator);

        for (0..iterations) |_| {
            current_mesh = try subdivideOnce(current_mesh, allocator);
        }

        var outputs = try allocator.alloc(nodes.NodeGraph.Value, 1);
        outputs[0] = .{ .mesh = current_mesh };
        return outputs;
    }

    fn subdivideOnce(mesh: raylib.Mesh, allocator: std.mem.Allocator) !raylib.Mesh {
        // Basic midpoint subdivision - each triangle becomes 4
        const old_tri_count: usize = @intCast(mesh.triangleCount);
        const new_tri_count = old_tri_count * 4;
        const new_vertex_count = old_tri_count * 3 + old_tri_count * 3; // Original + midpoints

        const vertices = try allocator.alloc(f32, new_vertex_count * 3);
        const normals = try allocator.alloc(f32, new_vertex_count * 3);
        const indices = try allocator.alloc(u16, new_tri_count * 3);

        // Copy existing vertices
        if (mesh.vertices) |src_verts| {
            const src_count: usize = @intCast(mesh.vertexCount * 3);
            @memcpy(vertices[0..src_count], src_verts[0..src_count]);
        }
        if (mesh.normals) |src_norms| {
            const src_count: usize = @intCast(mesh.vertexCount * 3);
            @memcpy(normals[0..src_count], src_norms[0..src_count]);
        }

        // For simplicity, just copy the input mesh (full subdivision is complex)
        // This is a placeholder - real implementation would compute midpoints
        var new_mesh = raylib.Mesh{
            .vertexCount = @intCast(new_vertex_count),
            .triangleCount = @intCast(new_tri_count),
            .vertices = vertices.ptr,
            .normals = normals.ptr,
            .texcoords = null,
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

        raylib.uploadMesh(&new_mesh, false);
        return new_mesh;
    }

    fn deinit(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Geometry", .mesh, null);
        try node.addInput("Iterations", .int, .{ .int = 1 });
        try node.addOutput("Geometry", .mesh);
    }
};

/// Noise displacement node
/// Applies Perlin noise displacement to mesh vertices
pub const NoiseNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
        if (inputs.len < 1) return error.InvalidInputCount;

        const input_mesh = inputs[0].mesh;
        const strength = if (inputs.len > 1 and inputs[1] == .float) inputs[1].float else 0.1;
        const scale = if (inputs.len > 2 and inputs[2] == .float) inputs[2].float else 1.0;
        const seed = if (inputs.len > 3 and inputs[3] == .int) @as(u64, @intCast(inputs[3].int)) else 0;

        var displaced_mesh = try mesh_ops.copyMesh(input_mesh, allocator);

        const vertex_count: usize = @intCast(displaced_mesh.vertexCount);
        if (displaced_mesh.vertices) |vertices| {
            const vertex_slice = vertices[0 .. vertex_count * 3];
            if (displaced_mesh.normals) |normap| {
                const normal_slice = normap[0 .. vertex_count * 3];

                for (0..vertex_count) |i| {
                    const vx = vertex_slice[i * 3];
                    const vy = vertex_slice[i * 3 + 1];
                    const vz = vertex_slice[i * 3 + 2];

                    // Simple pseudo-noise based on position and seed
                    const noise = pseudoNoise3D(vx * scale, vy * scale, vz * scale, seed);

                    // Displace along normal
                    vertex_slice[i * 3] += normal_slice[i * 3] * noise * strength;
                    vertex_slice[i * 3 + 1] += normal_slice[i * 3 + 1] * noise * strength;
                    vertex_slice[i * 3 + 2] += normal_slice[i * 3 + 2] * noise * strength;
                }
            }
        }

        var outputs = try allocator.alloc(nodes.NodeGraph.Value, 1);
        outputs[0] = .{ .mesh = displaced_mesh };
        return outputs;
    }

    /// Simple pseudo-random noise function (placeholder for proper Perlin noise)
    fn pseudoNoise3D(x: f32, y: f32, z: f32, seed: u64) f32 {
        const ix: i32 = @intFromFloat(@floor(x));
        const iy: i32 = @intFromFloat(@floor(y));
        const iz: i32 = @intFromFloat(@floor(z));

        var h = seed;
        h ^= @as(u64, @bitCast(@as(i64, ix)));
        h ^= @as(u64, @bitCast(@as(i64, iy))) << 13;
        h ^= @as(u64, @bitCast(@as(i64, iz))) << 26;
        h ^= h >> 17;
        h *%= 0x5851f42d4c957f2d;
        h ^= h >> 47;

        return @as(f32, @floatFromInt(@as(i32, @truncate(h)))) / @as(f32, @floatFromInt(@as(i32, std.math.maxInt(i32))));
    }

    fn deinit(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Geometry", .mesh, null);
        try node.addInput("Strength", .float, .{ .float = 0.1 });
        try node.addInput("Scale", .float, .{ .float = 1.0 });
        try node.addInput("Seed", .int, .{ .int = 0 });
        try node.addOutput("Geometry", .mesh);
    }
};

/// Bevel node
/// Applies edge beveling to mesh
pub const BevelNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
        if (inputs.len < 1) return error.InvalidInputCount;

        const input_mesh = inputs[0].mesh;
        const width = if (inputs.len > 1 and inputs[1] == .float) inputs[1].float else 0.1;
        const segments = if (inputs.len > 2 and inputs[2] == .int) @as(u32, @intCast(@max(1, inputs[2].int))) else 1;

        _ = width;
        _ = segments;

        // Bevel is complex - for now, pass through the mesh
        // Full implementation would identify edges and create bevel geometry
        var beveled_mesh = try mesh_ops.copyMesh(input_mesh, allocator);

        var outputs = try allocator.alloc(nodes.NodeGraph.Value, 1);
        outputs[0] = .{ .mesh = beveled_mesh };
        return outputs;
    }

    fn deinit(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Geometry", .mesh, null);
        try node.addInput("Width", .float, .{ .float = 0.1 });
        try node.addInput("Segments", .int, .{ .int = 1 });
        try node.addOutput("Geometry", .mesh);
    }
};
