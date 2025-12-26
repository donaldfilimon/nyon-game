const std = @import("std");
const raylib = @import("raylib");
const nodes = @import("nodes/node_graph.zig");

fn copyMesh(mesh: raylib.Mesh, allocator: std.mem.Allocator) !raylib.Mesh {
    var new_mesh = raylib.Mesh{
        .vertexCount = mesh.vertexCount,
        .triangleCount = mesh.triangleCount,
        .vertices = null,
        .texcoords = null,
        .texcoords2 = null,
        .normals = null,
        .tangents = null,
        .colors = null,
        .indices = null,
        .animVertices = null,
        .animNormals = null,
        .boneIds = null,
        .boneWeights = null,
        .boneCount = 0,
        .boneMatrices = null,
        .vaoId = 0,
        .vboId = null,
    };

    // Copy vertex data (3 floats per vertex: x, y, z)
    if (mesh.vertices != null) {
        const vertex_count = @as(usize, @intCast(mesh.vertexCount)) * 3;
        const vertex_data = try allocator.alloc(f32, vertex_count);
        const src_ptr = @as([*]const f32, @ptrCast(mesh.vertices.?));
        const src_slice = src_ptr[0..vertex_count];
        @memcpy(vertex_data[0..vertex_count], src_slice);
        new_mesh.vertices = vertex_data.ptr;
    }

    // Copy texture coordinates (2 floats per vertex: u, v)
    if (mesh.texcoords != null) {
        const texcoord_count = @as(usize, @intCast(mesh.vertexCount)) * 2;
        const texcoord_data = try allocator.alloc(f32, texcoord_count);
        if (mesh.texcoords) |texcoords| {
            @memcpy(texcoord_data[0..texcoord_count], texcoords[0..texcoord_count]);
        }
        new_mesh.texcoords = texcoord_data.ptr;
    }

    // Copy secondary texture coordinates
    if (mesh.texcoords2 != null) {
        const texcoord_count = @as(usize, @intCast(mesh.vertexCount)) * 2;
        const texcoord_data = try allocator.alloc(f32, texcoord_count);
        @memcpy(texcoord_data[0..texcoord_count], mesh.texcoords2[0..texcoord_count]);
        new_mesh.texcoords2 = texcoord_data.ptr;
    }

    // Copy normals (3 floats per vertex: nx, ny, nz)
    if (mesh.normals != null) {
        const normal_count = @as(usize, @intCast(mesh.vertexCount)) * 3;
        const normal_data = try allocator.alloc(f32, normal_count);
        if (mesh.normals) |normals| {
            @memcpy(normal_data[0..normal_count], normals[0..normal_count]);
        }
        new_mesh.normals = normal_data.ptr;
    }

    // Copy tangents (4 floats per vertex: tx, ty, tz, tw)
    if (mesh.tangents != null) {
        const tangent_count = @as(usize, @intCast(mesh.vertexCount)) * 4;
        const tangent_data = try allocator.alloc(f32, tangent_count);
        if (mesh.tangents) |tangents| {
            @memcpy(tangent_data[0..tangent_count], tangents[0..tangent_count]);
        }
        new_mesh.tangents = tangent_data.ptr;
    }

    // Copy vertex colors (4 bytes per vertex: r, g, b, a)
    if (mesh.colors != null) {
        const color_count = @as(usize, @intCast(mesh.vertexCount)) * 4;
        const color_data = try allocator.alloc(u8, color_count);
        if (mesh.colors) |colors| {
            @memcpy(color_data[0..color_count], colors[0..color_count]);
        }
        new_mesh.colors = color_data.ptr;
    }

    // Copy indices (3 indices per triangle)
    if (mesh.indices != null) {
        const index_count = @as(usize, @intCast(mesh.triangleCount)) * 3;
        const index_data = try allocator.alloc(u16, index_count);
        if (mesh.indices) |indices| {
            @memcpy(index_data[0..index_count], indices[0..index_count]);
        }
        new_mesh.indices = index_data.ptr;
    }

    // Copy animation data if present
    if (mesh.animVertices != null) {
        const anim_vertex_count = @as(usize, @intCast(mesh.vertexCount)) * 3;
        const anim_vertex_data = try allocator.alloc(f32, anim_vertex_count);
        if (mesh.animVertices) |animVertices| {
            @memcpy(anim_vertex_data[0..anim_vertex_count], animVertices[0..anim_vertex_count]);
        }
        new_mesh.animVertices = anim_vertex_data.ptr;
    }

    if (mesh.animNormals != null) {
        const anim_normal_count = @as(usize, @intCast(mesh.vertexCount)) * 3;
        const anim_normal_data = try allocator.alloc(f32, anim_normal_count);
        if (mesh.animNormals) |animNormals| {
            @memcpy(anim_normal_data[0..anim_normal_count], animNormals[0..anim_normal_count]);
        }
        new_mesh.animNormals = anim_normal_data.ptr;
    }

    if (mesh.boneIds != null) {
        const bone_id_count = @as(usize, @intCast(mesh.vertexCount)) * 4;
        const bone_id_data = try allocator.alloc(u8, bone_id_count);
        if (mesh.boneIds) |boneIds| {
            @memcpy(bone_id_data[0..bone_id_count], boneIds[0..bone_id_count]);
        }
        new_mesh.boneIds = bone_id_data.ptr;
    }

    if (mesh.boneWeights != null) {
        const bone_weight_count = @as(usize, @intCast(mesh.vertexCount)) * 4;
        const bone_weight_data = try allocator.alloc(f32, bone_weight_count);
        if (mesh.boneWeights) |boneWeights| {
            @memcpy(bone_weight_data[0..bone_weight_count], boneWeights[0..bone_weight_count]);
        }
        new_mesh.boneWeights = bone_weight_data.ptr;
    }

    // Copy animation data if present
    if (mesh.animVertices != null) {
        const anim_vertex_count = @as(usize, @intCast(mesh.vertexCount)) * 3;
        new_mesh.animVertices = (try allocator.alloc(f32, anim_vertex_count)).ptr;
        if (mesh.animVertices) |srcVertices| {
            @memcpy(new_mesh.animVertices[0..anim_vertex_count], srcVertices[0..anim_vertex_count]);
        }
    }

    if (mesh.animNormals != null) {
        const anim_normal_count = @as(usize, @intCast(mesh.vertexCount)) * 3;
        new_mesh.animNormals = (try allocator.alloc(f32, anim_normal_count)).ptr;
        if (mesh.animNormals) |srcNormals| {
            @memcpy(new_mesh.animNormals[0..anim_normal_count], srcNormals[0..anim_normal_count]);
        }
    }

    // Copy bone data
    new_mesh.boneCount = mesh.boneCount;
    if (mesh.boneIds != null) {
        const bone_id_count = @as(usize, @intCast(mesh.vertexCount)) * 4; // 4 bones per vertex
        new_mesh.boneIds = (try allocator.alloc(u8, bone_id_count)).ptr;
        if (mesh.boneIds) |srcBoneIds| {
            @memcpy(new_mesh.boneIds[0..bone_id_count], srcBoneIds[0..bone_id_count]);
        }
    }

    if (mesh.boneWeights != null) {
        const bone_weight_count = @as(usize, @intCast(mesh.vertexCount)) * 4; // 4 weights per vertex
        new_mesh.boneWeights = (try allocator.alloc(f32, bone_weight_count)).ptr;
        if (mesh.boneWeights) |srcBoneWeights| {
            @memcpy(new_mesh.boneWeights[0..bone_weight_count], srcBoneWeights[0..bone_weight_count]);
        }
    }

    // Note: boneMatrices are typically managed separately and not copied

    // Upload mesh to GPU
    raylib.uploadMesh(&new_mesh, false);

    return new_mesh;
}

/// Cube primitive node
const CubeNode = struct {
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

        // Create a copy of the mesh
        var transformed_mesh = input_mesh;

        const transformed_vertex_count: usize = @intCast(transformed_mesh.vertexCount);
        // Apply translation to all vertices
        if (transformed_mesh.vertices) |vertices| {
            const vertex_slice = vertices[0..@intCast(transformed_vertex_count * 3)];
            for (0..transformed_vertex_count) |i| {
                const vertex_index = i * 3;
                vertex_slice[vertex_index] += translation.x;
                vertex_slice[vertex_index + 1] += translation.y;
                vertex_slice[vertex_index + 2] += translation.z;
            }
        }

        // Recalculate normals if present
        if (transformed_mesh.normals != null) {}

        var outputs = try allocator.alloc(nodes.NodeGraph.Value, 1);
        outputs[0] = .{ .mesh = transformed_mesh };
        return outputs;
    }

    fn deinit(node: *nodes.NodeGraph.Node, allocator: std.mem.Allocator) void {
        _ = node;
        _ = allocator;
    }

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

        // Create a copy of the mesh
        var scaled_mesh = input_mesh;

        const scaled_vertex_count: usize = @intCast(scaled_mesh.vertexCount);
        // Apply scaling to all vertices
        if (scaled_mesh.vertices) |vertices| {
            const vertex_slice = vertices[0..@intCast(scaled_vertex_count * 3)];
            for (0..scaled_vertex_count) |i| {
                const vertex_index = i * 3;
                vertex_slice[vertex_index] *= scale.x;
                vertex_slice[vertex_index + 1] *= scale.y;
                vertex_slice[vertex_index + 2] *= scale.z;
            }
        }

        // Recalculate normals if present
        if (scaled_mesh.normals) |normals| {
            const normal_slice = normals[0 .. scaled_vertex_count * 3];
            for (0..scaled_vertex_count) |i| {
                const idx = i * 3;
                // For uniform scale, normals don't change direction.
                // For non-uniform, they should be multiplied by (1/scale)
                normal_slice[idx] *= (1.0 / scale.x);
                normal_slice[idx + 1] *= (1.0 / scale.y);
                normal_slice[idx + 2] *= (1.0 / scale.z);

                // Re-normalize
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

    fn deinit(node: *nodes.NodeGraph.Node, allocator: std.mem.Allocator) void {
        _ = node;
        _ = allocator;
    }

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
        const rotation = inputs[1].vector3; // Euler angles in degrees

        // Create a copy of the mesh
        var rotated_mesh = input_mesh;

        // Convert degrees to radians
        const rot_x_rad = rotation.x * std.math.pi / 180.0;
        const rot_y_rad = rotation.y * std.math.pi / 180.0;
        const rot_z_rad = rotation.z * std.math.pi / 180.0;

        const rotated_vertex_count: usize = @intCast(rotated_mesh.vertexCount);
        // Apply rotation to all vertices (ZXY order)
        if (rotated_mesh.vertices) |vertices| {
            const vertex_slice = vertices[0..@intCast(rotated_vertex_count * 3)];
            for (0..rotated_vertex_count) |i| {
                const vertex_index = i * 3;
                var x = vertex_slice[vertex_index];
                var y = vertex_slice[vertex_index + 1];
                var z = vertex_slice[vertex_index + 2];

                // Apply rotations
                // First Z rotation
                const cos_z = @cos(rot_z_rad);
                const sin_z = @sin(rot_z_rad);
                const new_x_z = x * cos_z - y * sin_z;
                const new_y_z = x * sin_z + y * cos_z;
                x = new_x_z;
                y = new_y_z;

                // Then X rotation
                const cos_x = @cos(rot_x_rad);
                const sin_x = @sin(rot_x_rad);
                const new_y_x = y * cos_x - z * sin_x;
                const new_z_x = y * sin_x + z * cos_x;
                y = new_y_x;
                z = new_z_x;

                // Finally Y rotation
                const cos_y = @cos(rot_y_rad);
                const sin_y = @sin(rot_y_rad);
                const new_x_y = x * cos_y + z * sin_y;
                const new_z_y = -x * sin_y + z * cos_y;
                x = new_x_y;
                z = new_z_y;

                vertex_slice[vertex_index] = x;
                vertex_slice[vertex_index + 1] = y;
                vertex_slice[vertex_index + 2] = z;
            }
        }

        // Recalculate normals if present
        if (rotated_mesh.normals) |normals| {
            const normal_slice = normals[0 .. rotated_vertex_count * 3];
            for (0..rotated_vertex_count) |i| {
                const idx = i * 3;
                var nx = normal_slice[idx];
                var ny = normal_slice[idx + 1];
                var nz = normal_slice[idx + 2];

                // Apply Z rotation
                const cos_z = @cos(rot_z_rad);
                const sin_z = @sin(rot_z_rad);
                const rx_z = nx * cos_z - ny * sin_z;
                const ry_z = nx * sin_z + ny * cos_z;
                nx = rx_z;
                ny = ry_z;

                // Apply X rotation
                const cos_x = @cos(rot_x_rad);
                const sin_x = @sin(rot_x_rad);
                const ry_x = ny * cos_x - nz * sin_x;
                const rz_x = ny * sin_x + nz * cos_x;
                ny = ry_x;
                nz = rz_x;

                // Apply Y rotation
                const cos_y = @cos(rot_y_rad);
                const sin_y = @sin(rot_y_rad);
                const rx_y = nx * cos_y + nz * sin_y;
                const rz_y = -nx * sin_y + nz * cos_y;
                nx = rx_y;
                nz = rz_y;

                normal_slice[idx] = nx;
                normal_slice[idx + 1] = ny;
                normal_slice[idx + 2] = nz;
            }
        }

        var outputs = try allocator.alloc(nodes.NodeGraph.Value, 1);
        outputs[0] = .{ .mesh = rotated_mesh };
        return outputs;
    }

    fn deinit(node: *nodes.NodeGraph.Node, allocator: std.mem.Allocator) void {
        _ = node;
        _ = allocator;
    }

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Geometry", .mesh, null);
        try node.addInput("Rotation", .vector3, .{ .vector3 = .{ .x = 0, .y = 0, .z = 0 } });
        try node.addOutput("Geometry", .mesh);
    }
};
/// Union boolean operation node
pub const UnionNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
        const mesh_a = inputs[0].mesh;
        const mesh_b = inputs[1].mesh;

        // Implement CSG Union
        const result_mesh = try performUnion(mesh_a, mesh_b, allocator);

        return try allocator.dupe(nodes.NodeGraph.Value, &[_]nodes.NodeGraph.Value{.{ .mesh = result_mesh }});
    }

    fn deinit(node: *nodes.NodeGraph.Node, allocator: std.mem.Allocator) void {
        _ = node;
        _ = allocator;
    }

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Geometry A", .mesh, null);
        try node.addInput("Geometry B", .mesh, null);
        try node.addOutput("Geometry", .mesh);
    }
};

/// Difference boolean operation node
pub const DifferenceNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
        if (inputs.len != 2) return error.InvalidInputCount;

        const mesh_a = inputs[0].mesh;
        const mesh_b = inputs[1].mesh;

        // Implement CSG Difference
        const result_mesh = try performDifference(mesh_a, mesh_b, allocator);

        return try allocator.dupe(nodes.NodeGraph.Value, &[_]nodes.NodeGraph.Value{.{ .mesh = result_mesh }});
    }

    fn deinit(node: *nodes.NodeGraph.Node, allocator: std.mem.Allocator) void {
        _ = node;
        _ = allocator;
    }

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Geometry A", .mesh, null);
        try node.addInput("Geometry B", .mesh, null);
        try node.addOutput("Geometry", .mesh);
    }
};

/// Intersection boolean operation node
pub const IntersectionNode = struct {
    pub fn createVTable() nodes.NodeGraph.Node.NodeVTable {
        return .{
            .execute = execute,
            .deinit = deinit,
        };
    }

    fn execute(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
        if (inputs.len != 2) return error.InvalidInputCount;

        const mesh_a = inputs[0].mesh;
        const mesh_b = inputs[1].mesh;

        // Implement CSG Intersection
        const result_mesh = try performIntersection(mesh_a, mesh_b, allocator);

        return try allocator.dupe(nodes.NodeGraph.Value, &[_]nodes.NodeGraph.Value{.{ .mesh = result_mesh }});
    }

    fn deinit(node: *nodes.NodeGraph.Node, allocator: std.mem.Allocator) void {
        _ = node;
        _ = allocator;
    }

    pub fn initNode(node: *nodes.NodeGraph.Node) !void {
        try node.addInput("Geometry A", .mesh, null);
        try node.addInput("Geometry B", .mesh, null);
        try node.addOutput("Geometry", .mesh);
    }
};
/// Simplified geometry node system for Phase 1
/// Focuses on core node graph functionality with basic primitives
pub const GeometryNodeSystem = struct {
    /// Core node graph
    graph: nodes.NodeGraph,

    /// UI state for interactive editor
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

    /// Execute the entire node graph
    pub fn executeGraph(self: *GeometryNodeSystem) void {
        self.graph.execute() catch {};
    }

    /// Get the final geometry output from the last node in the graph
    pub fn getFinalGeometry(self: *GeometryNodeSystem) ?raylib.Mesh {
        if (self.graph.nodes.items.len == 0) return null;

        // Get the last node (assuming it's the output)
        const last_node_id = self.graph.nodes.items[self.graph.nodes.items.len - 1].id;

        // Execute and get its first output (assuming it's geometry)
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

    /// Create a new node of the specified type
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
        } else if (std.mem.eql(u8, node_type, "Union")) {
            vtable = UnionNode.createVTable();
        } else {
            return 0; // Return invalid ID for unknown types
        }

        const node_id = self.graph.addNode(node_type, &vtable) catch return 0;
        const node_index = self.graph.findNodeIndex(node_id) orelse return 0;
        const node = &self.graph.nodes.items[node_index];

        // Initialize node inputs/outputs based on type
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
        } else if (std.mem.eql(u8, node_type, "Union")) {
            UnionNode.initNode(node) catch {};
        }

        return node_id;
    }

    /// Remove a node from the graph
    pub fn removeNode(self: *GeometryNodeSystem, node_id: nodes.NodeGraph.NodeId) void {
        self.graph.removeNode(node_id) catch {};
        if (self.selected_node != null and self.selected_node.? == node_id) {
            self.selected_node = null;
        }
    }

    /// Add a connection between nodes
    pub fn addConnection(self: *GeometryNodeSystem, from_node: nodes.NodeGraph.NodeId, from_output: usize, to_node: nodes.NodeGraph.NodeId, to_input: usize) !void {
        try self.graph.addConnection(from_node, from_output, to_node, to_input);
    }
    /// Interactive node editor rendering and input handling
    pub fn updateNodeEditor(self: *GeometryNodeSystem, mouse_pos: raylib.Vector2, mouse_pressed: bool, mouse_down: bool, key_delete: bool, editor_offset_x: f32) void {
        const editor_mouse_pos = raylib.Vector2{
            .x = mouse_pos.x - editor_offset_x,
            .y = mouse_pos.y,
        };

        // Handle node selection and dragging
        if (mouse_pressed) {
            self.selected_node = null;
            self.drag_state = null;

            // Check if clicking on a node
            for (self.graph.nodes.items) |*node| {
                const node_rect = raylib.Rectangle{
                    .x = node.position.x,
                    .y = node.position.y,
                    .width = 120,
                    .height = 60 + @as(f32, @floatFromInt(node.inputs.items.len + node.outputs.items.len)) * 20,
                };

                if (raylib.checkCollisionPointRec(editor_mouse_pos, node_rect)) {
                    self.selected_node = node.id;
                    self.drag_state = .{
                        .node_id = node.id,
                        .offset = raylib.Vector2{
                            .x = editor_mouse_pos.x - node.position.x,
                            .y = editor_mouse_pos.y - node.position.y,
                        },
                    };
                    break;
                }
            }
        }

        // Handle dragging
        if (mouse_down and self.drag_state != null) {
            const drag = self.drag_state.?;
            if (self.graph.findNodeIndex(drag.node_id)) |index| {
                var node = &self.graph.nodes.items[index];
                node.position = raylib.Vector2{
                    .x = editor_mouse_pos.x - drag.offset.x,
                    .y = editor_mouse_pos.y - drag.offset.y,
                };
            }
        } else {
            self.drag_state = null;
        }

        // Handle deletion
        if (key_delete and self.selected_node != null) {
            self.removeNode(self.selected_node.?) catch {};
            self.selected_node = null;
        }
    }

    /// Render the node editor UI
    pub fn renderNodeEditor(self: *GeometryNodeSystem, screen_width: f32, screen_height: f32) void {
        const panel_width = 250;
        const editor_width = screen_width - panel_width;
        const editor_height = screen_height;

        // Draw node editor background
        raylib.drawRectangle(
            @intFromFloat(panel_width),
            0,
            @intFromFloat(editor_width),
            @intFromFloat(editor_height),
            raylib.Color{ .r = 30, .g = 30, .b = 40, .a = 255 },
        );

        // Draw grid
        const grid_size = 20;
        var x: f32 = panel_width;
        while (x < screen_width) : (x += grid_size) {
            const alpha: u8 = if (@mod(@as(i32, @intFromFloat(x)), @as(i32, grid_size * 5)) == 0) 120 else 60;
            raylib.drawLine(
                @intFromFloat(x),
                0,
                @intFromFloat(x),
                @intFromFloat(editor_height),
                raylib.Color{ .r = 50, .g = 50, .b = 60, .a = alpha },
            );
        }

        var y: f32 = 0;
        while (y < screen_height) : (y += grid_size) {
            const alpha: u8 = if (@mod(@as(i32, @intFromFloat(y)), @as(i32, grid_size * 5)) == 0) 120 else 60;
            raylib.drawLine(
                @intFromFloat(panel_width),
                @intFromFloat(y),
                @intFromFloat(screen_width),
                @intFromFloat(y),
                raylib.Color{ .r = 50, .g = 50, .b = 60, .a = alpha },
            );
        }

        // Draw nodes
        for (self.graph.nodes.items) |*node| {
            self.drawNode(node, self.selected_node != null and self.selected_node.? == node.id);
        }

        // Draw connections
        for (self.graph.connections.items) |conn| {
            self.drawConnection(&conn);
        }

        // Draw UI panel
        raylib.drawRectangle(
            0,
            0,
            @intFromFloat(panel_width),
            @intFromFloat(screen_height),
            raylib.Color{ .r = 20, .g = 20, .b = 30, .a = 255 },
        );

        // Panel title
        raylib.drawText("Geometry Nodes", 10, 10, 20, raylib.Color.white);

        // Node creation buttons
        const button_width = 80;
        const button_height = 25;
        var button_y: i32 = 50;

        const node_types = [_][:0]const u8{ "Cube", "Sphere", "Cylinder", "Cone", "Plane", "Translate", "Scale", "Rotate", "Union", "Difference", "Intersection" };

        for (node_types) |node_type| {
            const button_rect = raylib.Rectangle{
                .x = 10,
                .y = @floatFromInt(button_y),
                .width = button_width,
                .height = button_height,
            };

            const mouse_pos = raylib.getMousePosition();
            const hovered = raylib.checkCollisionPointRec(mouse_pos, button_rect);
            const color = if (hovered) raylib.Color{ .r = 70, .g = 70, .b = 80, .a = 255 } else raylib.Color{ .r = 50, .g = 50, .b = 60, .a = 255 };

            raylib.drawRectangleRec(button_rect, color);
            raylib.drawText(node_type, 15, button_y + 5, 14, raylib.Color.white);

            if (hovered and raylib.isMouseButtonPressed(.left)) {
                _ = self.createNode(node_type);
            }

            button_y += 30;
        }

        // Node count
        var node_count_buf: [32:0]u8 = undefined;
        const node_count_slice = std.fmt.bufPrintZ(&node_count_buf, "Nodes: {}", .{self.graph.nodes.items.len}) catch "Nodes: ?";
        raylib.drawText(node_count_slice, 10, @as(i32, @intFromFloat(screen_height)) - 30, 16, raylib.Color.gray);
    }
    /// Draw a single connection between nodes
    fn drawConnection(self: *GeometryNodeSystem, conn: *const nodes.NodeGraph.Connection) void {
        const from_node_index = self.graph.findNodeIndex(conn.from_node) orelse return;
        const to_node_index = self.graph.findNodeIndex(conn.to_node) orelse return;

        const from_node = &self.graph.nodes.items[from_node_index];
        const to_node = &self.graph.nodes.items[to_node_index];

        const start_pos = getSocketPosition(from_node, false, conn.from_output);
        const end_pos = getSocketPosition(to_node, true, conn.to_input);

        // Calculate control points for a smooth Bezier curve
        const cp1 = raylib.Vector2{
            .x = start_pos.x + @max(50, @abs(end_pos.x - start_pos.x) * 0.5),
            .y = start_pos.y,
        };
        const cp2 = raylib.Vector2{
            .x = end_pos.x - @max(50, @abs(end_pos.x - start_pos.x) * 0.5),
            .y = end_pos.y,
        };

        raylib.drawSplineSegmentBezierCubic(start_pos, cp1, cp2, end_pos, 2, raylib.Color.gray);
    }

    /// Helper to get the screen position of a node socket
    fn getSocketPosition(node: *const nodes.NodeGraph.Node, is_input: bool, index: usize) raylib.Vector2 {
        const node_width = 120;
        var y_offset: f32 = 30;

        if (is_input) {
            y_offset += @as(f32, @floatFromInt(index)) * 20;
            return .{
                .x = node.position.x - 5,
                .y = node.position.y + y_offset + 8,
            };
        } else {
            // Outputs start after all inputs
            y_offset += @as(f32, @floatFromInt(node.inputs.items.len)) * 20;
            y_offset += @as(f32, @floatFromInt(index)) * 20;
            return .{
                .x = node.position.x + node_width + 5,
                .y = node.position.y + y_offset + 8,
            };
        }
    }

    fn drawNode(self: *GeometryNodeSystem, node: *nodes.NodeGraph.Node, selected: bool) void {
        _ = self; // Not used currently

        const node_width = 120;
        var node_height: f32 = 40; // Header height

        // Calculate height based on inputs/outputs
        node_height += @as(f32, @floatFromInt(node.inputs.items.len)) * 20;
        node_height += @as(f32, @floatFromInt(node.outputs.items.len)) * 20;

        // Node background
        const bg_color = if (selected) raylib.Color{ .r = 80, .g = 120, .b = 150, .a = 255 } else raylib.Color{ .r = 60, .g = 60, .b = 70, .a = 255 };
        raylib.drawRectangle(
            @intFromFloat(node.position.x),
            @intFromFloat(node.position.y),
            @intFromFloat(node_width),
            @intFromFloat(node_height),
            bg_color,
        );

        // Node header
        raylib.drawRectangle(
            @intFromFloat(node.position.x),
            @intFromFloat(node.position.y),
            @intFromFloat(node_width),
            25,
            raylib.Color{ .r = 40, .g = 40, .b = 50, .a = 255 },
        );

        // Node title
        raylib.drawText(
            node.node_type[0..node.node_type.len :0],
            @as(i32, @intFromFloat(node.position.x)) + 5,
            @as(i32, @intFromFloat(node.position.y)) + 5,
            16,
            raylib.Color.white,
        );

        // Draw inputs
        var y_offset: f32 = 30;
        for (node.inputs.items) |input| {
            const input_color = if (input.connected) raylib.Color.green else raylib.Color.gray;
            raylib.drawCircle(
                @as(i32, @intFromFloat(node.position.x)) - 5,
                @intFromFloat(node.position.y + y_offset + 8),
                4,
                input_color,
            );
            raylib.drawText(
                input.name[0..input.name.len :0],
                @as(i32, @intFromFloat(node.position.x)) + 5,
                @intFromFloat(node.position.y + y_offset),
                12,
                raylib.Color.white,
            );
            y_offset += 20;
        }

        // Draw outputs
        for (node.outputs.items) |output| {
            raylib.drawCircle(
                @intFromFloat(node.position.x + node_width + 5),
                @intFromFloat(node.position.y + y_offset + 8),
                4,
                raylib.Color.blue,
            );
            raylib.drawText(
                output.name[0..output.name.len :0],
                @as(i32, @intFromFloat(node.position.x)) + 5,
                @intFromFloat(node.position.y + y_offset),
                12,
                raylib.Color.white,
            );
            y_offset += 20;
        }

        // Selection outline
        if (selected) {
            raylib.drawRectangleLines(
                @intFromFloat(node.position.x - 2),
                @intFromFloat(node.position.y - 2),
                @intFromFloat(node_width + 4),
                @intFromFloat(node_height + 4),
                raylib.Color.yellow,
            );
        }
    }
};

// ============================================================================
// CSG (Constructive Solid Geometry) Utilities
// ============================================================================

const AABB = struct {
    min: [3]f32,
    max: [3]f32,
};

/// Calculate Axis-Aligned Bounding Box for a mesh
fn calculateAABB(mesh: raylib.Mesh) AABB {
    if (mesh.vertexCount == 0) {
        return .{ .min = [_]f32{ 0, 0, 0 }, .max = [_]f32{ 0, 0, 0 } };
    }

    var min = [_]f32{ mesh.vertices[0], mesh.vertices[1], mesh.vertices[2] };
    var max = [_]f32{ mesh.vertices[0], mesh.vertices[1], mesh.vertices[2] };

    var i: usize = 1;
    while (i < mesh.vertexCount) : (i += 1) {
        const base_idx = i * 3;
        const x = mesh.vertices[base_idx];
        const y = mesh.vertices[base_idx + 1];
        const z = mesh.vertices[base_idx + 2];

        if (x < min[0]) min[0] = x;
        if (y < min[1]) min[1] = y;
        if (z < min[2]) min[2] = z;

        if (x > max[0]) max[0] = x;
        if (y > max[1]) max[1] = y;
        if (z > max[2]) max[2] = z;
    }

    return .{ .min = min, .max = max };
}

/// Check if two AABBs overlap significantly
fn aabbsOverlapSignificantly(a: AABB, b: AABB) bool {
    const overlap_x = a.max[0] > b.min[0] and a.min[0] < b.max[0];
    const overlap_y = a.max[1] > b.min[1] and a.min[1] < b.max[1];
    const overlap_z = a.max[2] > b.min[2] and a.min[2] < b.max[2];

    if (!overlap_x or !overlap_y or !overlap_z) return false;

    // Calculate overlap volumes
    const overlap_size_x = @min(a.max[0], b.max[0]) - @max(a.min[0], b.min[0]);
    const overlap_size_y = @min(a.max[1], b.max[1]) - @max(a.min[1], b.min[1]);
    const overlap_size_z = @min(a.max[2], b.max[2]) - @max(a.min[2], b.min[2]);

    const overlap_volume = overlap_size_x * overlap_size_y * overlap_size_z;

    // Calculate total volume
    const vol_a = (a.max[0] - a.min[0]) * (a.max[1] - a.min[1]) * (a.max[2] - a.min[2]);
    const vol_b = (b.max[0] - b.min[0]) * (b.max[1] - b.min[1]) * (b.max[2] - b.min[2]);
    _ = vol_a + vol_b; // Not used in this simplified implementation

    // Consider significant overlap if overlap volume > 10% of smaller volume
    const smaller_volume = @min(vol_a, vol_b);
    return overlap_volume > smaller_volume * 0.1;
}

/// Concatenate two meshes (simple approach)
fn concatenateMeshes(mesh_a: raylib.Mesh, mesh_b: raylib.Mesh, allocator: std.mem.Allocator) !raylib.Mesh {
    const total_vertices: usize = @intCast(mesh_a.vertexCount + mesh_b.vertexCount);
    const total_triangles: usize = @intCast(mesh_a.triangleCount + mesh_b.triangleCount);

    var combined_vertices = try allocator.alloc(f32, total_vertices * 3);
    errdefer allocator.free(combined_vertices);

    // Copy vertices from mesh A
    const a_vertices: usize = @intCast(mesh_a.vertexCount);
    const a_vertex_count = a_vertices * 3;
    if (a_vertex_count > 0) {
        @memcpy(combined_vertices[0..a_vertex_count], mesh_a.vertices[0..a_vertex_count]);
    }

    // Copy vertices from mesh B
    const b_vertices: usize = @intCast(mesh_b.vertexCount);
    const b_vertex_count = b_vertices * 3;
    if (b_vertex_count > 0) {
        @memcpy(combined_vertices[a_vertex_count .. a_vertex_count + b_vertex_count], mesh_b.vertices[0..b_vertex_count]);
    }

    var combined_mesh = raylib.Mesh{
        .vertexCount = @intCast(total_vertices),
        .triangleCount = @intCast(total_triangles),
        .vertices = combined_vertices.ptr,
        .texcoords = null,
        .texcoords2 = null,
        .normals = null,
        .tangents = null,
        .colors = null,
        .indices = null,
        .animVertices = null,
        .animNormals = null,
        .boneIds = null,
        .boneWeights = null,
        .vaoId = 0,
        .boneCount = 0,
        .boneMatrices = null,
        .vboId = null,
    };

    // Transfer ownership to raylib
    raylib.uploadMesh(&combined_mesh, false);

    return combined_mesh;
}

/// Perform CSG Union operation
fn performUnion(mesh_a: raylib.Mesh, mesh_b: raylib.Mesh, allocator: std.mem.Allocator) !raylib.Mesh {
    // Simple union: combine all vertices from both meshes
    // In a full implementation, this would remove overlapping geometry

    const vertex_count_a = @as(usize, @intCast(mesh_a.vertexCount));
    const vertex_count_b = @as(usize, @intCast(mesh_b.vertexCount));
    const total_vertices = vertex_count_a + vertex_count_b;
    const total_triangles = @as(usize, @intCast(mesh_a.triangleCount + mesh_b.triangleCount));

    // Allocate combined vertex data
    const vertex_data_size = total_vertices * 3;
    var vertices = try allocator.alloc(f32, vertex_data_size);

    // Copy vertices from mesh A
    if (vertex_count_a > 0 and mesh_a.vertices != null) {
        const src_a = mesh_a.vertices[0 .. vertex_count_a * 3];
        @memcpy(vertices[0 .. vertex_count_a * 3], src_a);
    }

    // Copy vertices from mesh B
    if (vertex_count_b > 0 and mesh_b.vertices != null) {
        const offset = vertex_count_a * 3;
        const src_b = mesh_b.vertices[0 .. vertex_count_b * 3];
        @memcpy(vertices[offset .. offset + vertex_count_b * 3], src_b);
    }

    // Handle indices
    var indices: ?[*]u16 = null;
    const index_count_a = if (mesh_a.indices != null) @as(usize, @intCast(mesh_a.triangleCount)) * 3 else 0;
    const index_count_b = if (mesh_b.indices != null) @as(usize, @intCast(mesh_b.triangleCount)) * 3 else 0;
    const total_indices = index_count_a + index_count_b;

    if (total_indices > 0) {
        const index_data = try allocator.alloc(u16, total_indices);
        if (index_count_a > 0) {
            @memcpy(index_data[0..index_count_a], mesh_a.indices[0..index_count_a]);
        }
        if (index_count_b > 0) {
            const offset = index_count_a;
            for (0..index_count_b) |i| {
                index_data[offset + i] = mesh_b.indices[i] + @as(u16, @intCast(vertex_count_a));
            }
        }
        indices = index_data.ptr;
    }

    var result_mesh = raylib.Mesh{
        .vertexCount = @intCast(total_vertices),
        .triangleCount = @intCast(total_triangles),
        .vertices = vertices.ptr,
        .texcoords = null,
        .texcoords2 = null,
        .normals = null,
        .tangents = null,
        .colors = null,
        .indices = indices,
        .animVertices = null,
        .animNormals = null,
        .boneIds = null,
        .boneWeights = null,
        .vaoId = 0,
        .boneCount = 0,
        .boneMatrices = null,
        .vboId = null,
    };

    raylib.uploadMesh(&result_mesh, false);
    return result_mesh;
}

/// Perform CSG Difference operation (mesh_a - mesh_b)
fn performDifference(mesh_a: raylib.Mesh, mesh_b: raylib.Mesh, allocator: std.mem.Allocator) !raylib.Mesh {
    return performBooleanOp(mesh_a, mesh_b, allocator, .difference);
}

/// Perform CSG Intersection operation
fn performIntersection(mesh_a: raylib.Mesh, mesh_b: raylib.Mesh, allocator: std.mem.Allocator) !raylib.Mesh {
    return performBooleanOp(mesh_a, mesh_b, allocator, .intersection);
}

const BooleanOp = enum { difference, intersection };

/// Core logic for Difference and Intersection operations
fn performBooleanOp(mesh_a: raylib.Mesh, mesh_b: raylib.Mesh, allocator: std.mem.Allocator, op: BooleanOp) !raylib.Mesh {
    const aabb_b = calculateAABB(mesh_b);
    const vertex_count: usize = @intCast(mesh_a.vertexCount);

    // Identify vertices of A to keep
    var vertices_to_keep = try allocator.alloc(bool, vertex_count);
    defer allocator.free(vertices_to_keep);

    var new_vertex_count: usize = 0;
    var index_map = try allocator.alloc(i32, vertex_count);
    defer allocator.free(index_map);

    for (0..vertex_count) |i| {
        const base = i * 3;
        const pos = [3]f32{ mesh_a.vertices[base], mesh_a.vertices[base + 1], mesh_a.vertices[base + 2] };
        const inside = pos[0] >= aabb_b.min[0] and pos[0] <= aabb_b.max[0] and
            pos[1] >= aabb_b.min[1] and pos[1] <= aabb_b.max[1] and
            pos[2] >= aabb_b.min[2] and pos[2] <= aabb_b.max[2];

        const keep = switch (op) {
            .difference => !inside,
            .intersection => inside,
        };

        vertices_to_keep[i] = keep;
        if (keep) {
            index_map[i] = @intCast(new_vertex_count);
            new_vertex_count += 1;
        } else {
            index_map[i] = -1;
        }
    }

    if (new_vertex_count == 0) {
        var empty_mesh = raylib.Mesh{ .vertexCount = 0, .triangleCount = 0, .vertices = null, .indices = null, .texcoords = null, .texcoords2 = null, .normals = null, .tangents = null, .colors = null, .animVertices = null, .animNormals = null, .boneIds = null, .boneWeights = null, .vaoId = 0, .boneCount = 0, .boneMatrices = null, .vboId = null };
        raylib.uploadMesh(&empty_mesh, false);
        return empty_mesh;
    }

    // Reconstruct vertices
    var new_vertices = try allocator.alloc(f32, new_vertex_count * 3);
    var v_idx: usize = 0;
    for (0..vertex_count) |i| {
        if (vertices_to_keep[i]) {
            new_vertices[v_idx * 3] = mesh_a.vertices[i * 3];
            new_vertices[v_idx * 3 + 1] = mesh_a.vertices[i * 3 + 1];
            new_vertices[v_idx * 3 + 2] = mesh_a.vertices[i * 3 + 2];
            v_idx += 1;
        }
    }

    // Reconstruct indices
    const old_tri_count = @as(usize, @intCast(mesh_a.triangleCount));
    var kept_indices = std.ArrayList(u16).init(allocator);
    defer kept_indices.deinit();

    if (mesh_a.indices) |idx_ptr| {
        for (0..old_tri_count) |t| {
            const i0 = idx_ptr[t * 3];
            const i1 = idx_ptr[t * 3 + 1];
            const i2 = idx_ptr[t * 3 + 2];

            if (index_map[i0] != -1 and index_map[i1] != -1 and index_map[i2] != -1) {
                try kept_indices.append(@intCast(index_map[i0]));
                try kept_indices.append(@intCast(index_map[i1]));
                try kept_indices.append(@intCast(index_map[i2]));
            }
        }
    }

    var result_mesh = raylib.Mesh{
        .vertexCount = @intCast(new_vertex_count),
        .triangleCount = @intCast(kept_indices.items.len / 3),
        .vertices = new_vertices.ptr,
        .indices = if (kept_indices.items.len > 0) (try allocator.dupe(u16, kept_indices.items)).ptr else null,
        .texcoords = null,
        .texcoords2 = null,
        .normals = null,
        .tangents = null,
        .colors = null,
        .animVertices = null,
        .animNormals = null,
        .boneIds = null,
        .boneWeights = null,
        .vaoId = 0,
        .boneCount = 0,
        .boneMatrices = null,
        .vboId = null,
    };

    raylib.uploadMesh(&result_mesh, false);
    return result_mesh;
}

/// Get node under mouse for property inspection
pub fn getNodeAtPosition(self: *const GeometryNodeSystem, pos: raylib.Vector2) ?nodes.NodeGraph.NodeId {
    for (self.graph.nodes.items) |node| {
        const node_rect = raylib.Rectangle{
            .x = node.position.x,
            .y = node.position.y,
            .width = 120,
            .height = 60 + @as(f32, @floatFromInt(node.inputs.items.len + node.outputs.items.len)) * 20,
        };

        if (raylib.checkCollisionPointRec(pos, node_rect)) {
            return node.id;
        }
    }
    return null;
}
