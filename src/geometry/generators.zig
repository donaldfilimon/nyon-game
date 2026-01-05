//! Generator nodes for geometry node system.
//!
//! Provides procedural geometry generators: Heightfield terrain, Array instancing.

const std = @import("std");
const raylib = @import("raylib");
const nodes = @import("../nodes/node_graph.zig");

/// Heightfield terrain generator node
/// Generates a terrain mesh from noise or input heightmap
pub const HeightfieldNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
        const width = if (inputs.len > 0 and inputs[0] == .float) inputs[0].float else 10.0;
        const depth = if (inputs.len > 1 and inputs[1] == .float) inputs[1].float else 10.0;
        const height_scale = if (inputs.len > 2 and inputs[2] == .float) inputs[2].float else 2.0;
        const resolution = if (inputs.len > 3 and inputs[3] == .int) @as(u32, @intCast(@max(2, inputs[3].int))) else 32;
        const seed = if (inputs.len > 4 and inputs[4] == .int) @as(u64, @intCast(inputs[4].int)) else 42;

        const mesh = try generateHeightfield(allocator, width, depth, height_scale, resolution, seed);

        return try allocator.dupe(nodes.NodeGraph.Value, &[_]nodes.NodeGraph.Value{.{ .mesh = mesh }});
    }

    fn deinit(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Width", .float, .{ .float = 10.0 });
        try node.addInput("Depth", .float, .{ .float = 10.0 });
        try node.addInput("Height Scale", .float, .{ .float = 2.0 });
        try node.addInput("Resolution", .int, .{ .int = 32 });
        try node.addInput("Seed", .int, .{ .int = 42 });
        try node.addOutput("Geometry", .mesh);
    }
};

/// Generate a heightfield mesh using procedural noise
fn generateHeightfield(
    allocator: std.mem.Allocator,
    width: f32,
    depth: f32,
    height_scale: f32,
    resolution: u32,
    seed: u64,
) !raylib.Mesh {
    const vertex_count = resolution * resolution;
    const triangle_count = (resolution - 1) * (resolution - 1) * 2;

    const vertices = try allocator.alloc(f32, vertex_count * 3);
    const normals = try allocator.alloc(f32, vertex_count * 3);
    const texcoords = try allocator.alloc(f32, vertex_count * 2);
    const indices = try allocator.alloc(u16, triangle_count * 3);

    // Generate height values and vertices
    for (0..resolution) |z| {
        for (0..resolution) |x| {
            const idx = z * resolution + x;
            const fx = @as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(resolution - 1));
            const fz = @as(f32, @floatFromInt(z)) / @as(f32, @floatFromInt(resolution - 1));

            const world_x = (fx - 0.5) * width;
            const world_z = (fz - 0.5) * depth;

            // Multi-octave noise for terrain
            const height = fractalNoise(world_x, world_z, seed, 4) * height_scale;

            vertices[idx * 3 + 0] = world_x;
            vertices[idx * 3 + 1] = height;
            vertices[idx * 3 + 2] = world_z;

            texcoords[idx * 2 + 0] = fx;
            texcoords[idx * 2 + 1] = fz;

            // Initialize normals (will be computed after)
            normals[idx * 3 + 0] = 0;
            normals[idx * 3 + 1] = 1;
            normals[idx * 3 + 2] = 0;
        }
    }

    // Calculate normals from neighboring vertices
    for (1..resolution - 1) |z| {
        for (1..resolution - 1) |x| {
            const idx = z * resolution + x;
            const left_idx = z * resolution + (x - 1);
            const right_idx = z * resolution + (x + 1);
            const up_idx = (z - 1) * resolution + x;
            const down_idx = (z + 1) * resolution + x;

            const left_h = vertices[left_idx * 3 + 1];
            const right_h = vertices[right_idx * 3 + 1];
            const up_h = vertices[up_idx * 3 + 1];
            const down_h = vertices[down_idx * 3 + 1];

            const dx = right_h - left_h;
            const dz = down_h - up_h;

            // Cross product of tangent vectors
            const nx = -dx;
            const ny: f32 = 2.0;
            const nz = -dz;

            const len = @sqrt(nx * nx + ny * ny + nz * nz);
            normals[idx * 3 + 0] = nx / len;
            normals[idx * 3 + 1] = ny / len;
            normals[idx * 3 + 2] = nz / len;
        }
    }

    // Generate indices
    var tri_idx: usize = 0;
    for (0..resolution - 1) |z| {
        for (0..resolution - 1) |x| {
            const top_left = @as(u16, @intCast(z * resolution + x));
            const top_right = top_left + 1;
            const bottom_left = @as(u16, @intCast((z + 1) * resolution + x));
            const bottom_right = bottom_left + 1;

            // First triangle
            indices[tri_idx * 3 + 0] = top_left;
            indices[tri_idx * 3 + 1] = bottom_left;
            indices[tri_idx * 3 + 2] = top_right;
            tri_idx += 1;

            // Second triangle
            indices[tri_idx * 3 + 0] = top_right;
            indices[tri_idx * 3 + 1] = bottom_left;
            indices[tri_idx * 3 + 2] = bottom_right;
            tri_idx += 1;
        }
    }

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

/// Multi-octave fractal noise
fn fractalNoise(x: f32, z: f32, seed: u64, octaves: u32) f32 {
    var value: f32 = 0.0;
    var amplitude: f32 = 1.0;
    var frequency: f32 = 1.0;
    var max_value: f32 = 0.0;

    for (0..octaves) |i| {
        value += simpleNoise(x * frequency, z * frequency, seed +% i) * amplitude;
        max_value += amplitude;
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return value / max_value;
}

/// Simple value noise
fn simpleNoise(x: f32, z: f32, seed: u64) f32 {
    const ix: i32 = @intFromFloat(@floor(x));
    const iz: i32 = @intFromFloat(@floor(z));

    const fx = x - @floor(x);
    const fz = z - @floor(z);

    // Smooth interpolation
    const sx = fx * fx * (3.0 - 2.0 * fx);
    const sz = fz * fz * (3.0 - 2.0 * fz);

    // Corner values
    const n00 = hashNoise(ix, iz, seed);
    const n10 = hashNoise(ix + 1, iz, seed);
    const n01 = hashNoise(ix, iz + 1, seed);
    const n11 = hashNoise(ix + 1, iz + 1, seed);

    // Bilinear interpolation
    const nx0 = n00 * (1.0 - sx) + n10 * sx;
    const nx1 = n01 * (1.0 - sx) + n11 * sx;

    return nx0 * (1.0 - sz) + nx1 * sz;
}

fn hashNoise(x: i32, z: i32, seed: u64) f32 {
    var h = seed;
    h ^= @as(u64, @bitCast(@as(i64, x))) *% 0x85ebca6b;
    h ^= @as(u64, @bitCast(@as(i64, z))) *% 0xc2b2ae35;
    h ^= h >> 16;
    h *%= 0x85ebca6b;
    h ^= h >> 13;
    return @as(f32, @floatFromInt(h & 0xFFFF)) / 65535.0;
}

/// Array instancing node
/// Creates multiple copies of geometry in a pattern
pub const ArrayNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
        if (inputs.len < 1) return error.InvalidInputCount;

        const input_mesh = inputs[0].mesh;
        const count_x = if (inputs.len > 1 and inputs[1] == .int) @as(u32, @intCast(@max(1, inputs[1].int))) else 3;
        const count_y = if (inputs.len > 2 and inputs[2] == .int) @as(u32, @intCast(@max(1, inputs[2].int))) else 1;
        const count_z = if (inputs.len > 3 and inputs[3] == .int) @as(u32, @intCast(@max(1, inputs[3].int))) else 1;
        const offset = if (inputs.len > 4 and inputs[4] == .vector3) inputs[4].vector3 else raylib.Vector3{ .x = 2.0, .y = 2.0, .z = 2.0 };

        const total_instances = count_x * count_y * count_z;
        const src_vertex_count: usize = @intCast(input_mesh.vertexCount);
        const src_tri_count: usize = @intCast(input_mesh.triangleCount);

        const new_vertex_count = src_vertex_count * total_instances;
        const new_tri_count = src_tri_count * total_instances;

        const vertices = try allocator.alloc(f32, new_vertex_count * 3);
        const normals = try allocator.alloc(f32, new_vertex_count * 3);
        const indices = try allocator.alloc(u16, new_tri_count * 3);

        var instance_idx: usize = 0;
        for (0..count_z) |iz| {
            for (0..count_y) |iy| {
                for (0..count_x) |ix| {
                    const offset_x = @as(f32, @floatFromInt(ix)) * offset.x;
                    const offset_y = @as(f32, @floatFromInt(iy)) * offset.y;
                    const offset_z = @as(f32, @floatFromInt(iz)) * offset.z;

                    const vert_offset = instance_idx * src_vertex_count;
                    const tri_offset = instance_idx * src_tri_count;

                    // Copy and offset vertices
                    if (input_mesh.vertices) |src_verts| {
                        for (0..src_vertex_count) |v| {
                            vertices[(vert_offset + v) * 3 + 0] = src_verts[v * 3 + 0] + offset_x;
                            vertices[(vert_offset + v) * 3 + 1] = src_verts[v * 3 + 1] + offset_y;
                            vertices[(vert_offset + v) * 3 + 2] = src_verts[v * 3 + 2] + offset_z;
                        }
                    }

                    // Copy normals
                    if (input_mesh.normals) |src_norms| {
                        @memcpy(normals[vert_offset * 3 .. (vert_offset + src_vertex_count) * 3], src_norms[0 .. src_vertex_count * 3]);
                    }

                    // Copy and offset indices
                    if (input_mesh.indices) |src_indices| {
                        for (0..src_tri_count * 3) |i| {
                            indices[tri_offset * 3 + i] = src_indices[i] + @as(u16, @intCast(vert_offset));
                        }
                    }

                    instance_idx += 1;
                }
            }
        }

        var mesh = raylib.Mesh{
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

        raylib.uploadMesh(&mesh, false);

        var outputs = try allocator.alloc(nodes.NodeGraph.Value, 1);
        outputs[0] = .{ .mesh = mesh };
        return outputs;
    }

    fn deinit(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Geometry", .mesh, null);
        try node.addInput("Count X", .int, .{ .int = 3 });
        try node.addInput("Count Y", .int, .{ .int = 1 });
        try node.addInput("Count Z", .int, .{ .int = 1 });
        try node.addInput("Offset", .vector3, .{ .vector3 = .{ .x = 2.0, .y = 2.0, .z = 2.0 } });
        try node.addOutput("Geometry", .mesh);
    }
};

test "heightfield generates valid mesh" {
    const allocator = std.testing.allocator;
    const mesh = try generateHeightfield(allocator, 10.0, 10.0, 2.0, 8, 42);
    defer {
        allocator.free(mesh.vertices[0..@intCast(mesh.vertexCount * 3)]);
        allocator.free(mesh.normals[0..@intCast(mesh.vertexCount * 3)]);
        allocator.free(mesh.texcoords[0..@intCast(mesh.vertexCount * 2)]);
        allocator.free(mesh.indices[0..@intCast(mesh.triangleCount * 3)]);
    }

    try std.testing.expect(mesh.vertexCount == 64); // 8x8
    try std.testing.expect(mesh.triangleCount == 98); // (8-1)*(8-1)*2
}
