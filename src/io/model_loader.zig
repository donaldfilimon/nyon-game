//! Model loader for Nyon Game Engine.
//!
//! Provides OBJ and basic glTF model file loading.

const std = @import("std");
const raylib = @import("raylib");

/// Model asset representing a loaded 3D model
pub const ModelAsset = struct {
    name: []const u8,
    meshes: []raylib.Mesh,
    materials: []MaterialData,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !ModelAsset {
        return .{
            .name = try allocator.dupe(u8, name),
            .meshes = &.{},
            .materials = &.{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ModelAsset) void {
        self.allocator.free(self.name);
        for (self.meshes) |*mesh| {
            raylib.unloadMesh(mesh.*);
        }
        if (self.meshes.len > 0) {
            self.allocator.free(self.meshes);
        }
        for (self.materials) |*mat| {
            mat.deinit(self.allocator);
        }
        if (self.materials.len > 0) {
            self.allocator.free(self.materials);
        }
    }
};

/// Material data from model files
pub const MaterialData = struct {
    name: []const u8,
    diffuse_color: raylib.Color,
    diffuse_texture: ?[]const u8,
    specular_color: raylib.Color,
    shininess: f32,

    pub fn deinit(self: *MaterialData, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        if (self.diffuse_texture) |tex| {
            allocator.free(tex);
        }
    }
};

/// OBJ file parser
pub const ObjLoader = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ObjLoader {
        return .{ .allocator = allocator };
    }

    /// Load an OBJ file from disk
    pub fn load(self: *ObjLoader, path: []const u8) !ModelAsset {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            std.debug.print("Failed to open OBJ file: {s} - {}\n", .{ path, err });
            return error.FileNotFound;
        };
        defer file.close();

        var model = try ModelAsset.init(self.allocator, std.fs.path.basename(path));
        errdefer model.deinit();

        var vertices = std.ArrayList(f32).init(self.allocator);
        defer vertices.deinit();
        var normals = std.ArrayList(f32).init(self.allocator);
        defer normals.deinit();
        var texcoords = std.ArrayList(f32).init(self.allocator);
        defer texcoords.deinit();
        var indices = std.ArrayList(u16).init(self.allocator);
        defer indices.deinit();

        // Temporary storage for parsed data
        var temp_positions = std.ArrayList([3]f32).init(self.allocator);
        defer temp_positions.deinit();
        var temp_normals = std.ArrayList([3]f32).init(self.allocator);
        defer temp_normals.deinit();
        var temp_texcoords = std.ArrayList([2]f32).init(self.allocator);
        defer temp_texcoords.deinit();

        var reader = file.reader();
        var buf: [1024]u8 = undefined;

        while (reader.readUntilDelimiterOrEof(&buf, '\n')) |maybe_line| {
            const line = maybe_line orelse break;
            const trimmed = std.mem.trim(u8, line, " \t\r");

            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            if (std.mem.startsWith(u8, trimmed, "v ")) {
                // Vertex position
                const pos = try parseVec3(trimmed[2..]);
                try temp_positions.append(pos);
            } else if (std.mem.startsWith(u8, trimmed, "vn ")) {
                // Vertex normal
                const norm = try parseVec3(trimmed[3..]);
                try temp_normals.append(norm);
            } else if (std.mem.startsWith(u8, trimmed, "vt ")) {
                // Texture coordinate
                const uv = try parseVec2(trimmed[3..]);
                try temp_texcoords.append(uv);
            } else if (std.mem.startsWith(u8, trimmed, "f ")) {
                // Face
                try parseFace(trimmed[2..], &vertices, &normals, &texcoords, &indices, temp_positions.items, temp_normals.items, temp_texcoords.items);
            }
        } else |err| {
            std.debug.print("Error reading OBJ file: {}\n", .{err});
            return err;
        }

        // Create mesh from parsed data
        if (vertices.items.len > 0) {
            const mesh = try createMeshFromArrays(self.allocator, vertices.items, normals.items, texcoords.items, indices.items);

            model.meshes = try self.allocator.alloc(raylib.Mesh, 1);
            model.meshes[0] = mesh;
        }

        return model;
    }

    fn parseVec3(str: []const u8) ![3]f32 {
        var it = std.mem.splitSequence(u8, str, " ");
        var result: [3]f32 = .{ 0, 0, 0 };
        var i: usize = 0;
        while (it.next()) |part| {
            if (part.len == 0) continue;
            if (i >= 3) break;
            result[i] = std.fmt.parseFloat(f32, part) catch 0;
            i += 1;
        }
        return result;
    }

    fn parseVec2(str: []const u8) ![2]f32 {
        var it = std.mem.splitSequence(u8, str, " ");
        var result: [2]f32 = .{ 0, 0 };
        var i: usize = 0;
        while (it.next()) |part| {
            if (part.len == 0) continue;
            if (i >= 2) break;
            result[i] = std.fmt.parseFloat(f32, part) catch 0;
            i += 1;
        }
        return result;
    }

    fn parseFace(
        str: []const u8,
        vertices: *std.ArrayList(f32),
        normals: *std.ArrayList(f32),
        texcoords: *std.ArrayList(f32),
        indices: *std.ArrayList(u16),
        temp_pos: [][3]f32,
        temp_norm: [][3]f32,
        temp_uv: [][2]f32,
    ) !void {
        var it = std.mem.splitSequence(u8, str, " ");
        var face_vertices: [4]struct { v: usize, vt: ?usize, vn: ?usize } = undefined;
        var count: usize = 0;

        while (it.next()) |part| {
            if (part.len == 0) continue;
            if (count >= 4) break;

            var indices_it = std.mem.splitSequence(u8, part, "/");
            var v_idx: usize = 0;
            var vt_idx: ?usize = null;
            var vn_idx: ?usize = null;

            if (indices_it.next()) |v_str| {
                v_idx = (std.fmt.parseInt(usize, v_str, 10) catch 1) - 1;
            }
            if (indices_it.next()) |vt_str| {
                if (vt_str.len > 0) {
                    vt_idx = (std.fmt.parseInt(usize, vt_str, 10) catch null) orelse null;
                    if (vt_idx) |*vti| vti.* -= 1;
                }
            }
            if (indices_it.next()) |vn_str| {
                vn_idx = (std.fmt.parseInt(usize, vn_str, 10) catch null) orelse null;
                if (vn_idx) |*vni| vni.* -= 1;
            }

            face_vertices[count] = .{ .v = v_idx, .vt = vt_idx, .vn = vn_idx };
            count += 1;
        }

        // Triangulate face (assumes convex polygon)
        if (count >= 3) {
            const base_idx = @as(u16, @intCast(vertices.items.len / 3));

            // Add vertices
            for (face_vertices[0..count]) |fv| {
                if (fv.v < temp_pos.len) {
                    const pos = temp_pos[fv.v];
                    try vertices.appendSlice(&pos);
                }

                if (fv.vn) |vn| {
                    if (vn < temp_norm.len) {
                        const norm = temp_norm[vn];
                        try normals.appendSlice(&norm);
                    }
                } else {
                    try normals.appendSlice(&.{ 0, 1, 0 });
                }

                if (fv.vt) |vt| {
                    if (vt < temp_uv.len) {
                        const uv = temp_uv[vt];
                        try texcoords.appendSlice(&uv);
                    }
                } else {
                    try texcoords.appendSlice(&.{ 0, 0 });
                }
            }

            // Triangle fan for face
            for (1..count - 1) |i| {
                try indices.append(base_idx);
                try indices.append(base_idx + @as(u16, @intCast(i)));
                try indices.append(base_idx + @as(u16, @intCast(i + 1)));
            }
        }
    }

    fn createMeshFromArrays(
        allocator: std.mem.Allocator,
        vertices: []const f32,
        normals: []const f32,
        texcoords: []const f32,
        indices: []const u16,
    ) !raylib.Mesh {
        const vertex_count = vertices.len / 3;
        const triangle_count = indices.len / 3;

        const verts = try allocator.alloc(f32, vertices.len);
        @memcpy(verts, vertices);

        const norms = try allocator.alloc(f32, normals.len);
        @memcpy(norms, normals);

        var uvs: ?[*]f32 = null;
        if (texcoords.len > 0) {
            const uv_slice = try allocator.alloc(f32, texcoords.len);
            @memcpy(uv_slice, texcoords);
            uvs = uv_slice.ptr;
        }

        const idx = try allocator.alloc(u16, indices.len);
        @memcpy(idx, indices);

        var mesh = raylib.Mesh{
            .vertexCount = @intCast(vertex_count),
            .triangleCount = @intCast(triangle_count),
            .vertices = verts.ptr,
            .normals = norms.ptr,
            .texcoords = uvs,
            .texcoords2 = null,
            .colors = null,
            .indices = idx.ptr,
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
};

/// Convenience function to load a model file
pub fn loadModel(allocator: std.mem.Allocator, path: []const u8) !ModelAsset {
    const ext = std.fs.path.extension(path);
    if (std.mem.eql(u8, ext, ".obj")) {
        var loader = ObjLoader.init(allocator);
        return loader.load(path);
    }
    return error.UnsupportedFormat;
}

test "ObjLoader parses vec3" {
    const result = try ObjLoader.parseVec3("1.0 2.0 3.0");
    try std.testing.expectApproxEqAbs(result[0], 1.0, 0.001);
    try std.testing.expectApproxEqAbs(result[1], 2.0, 0.001);
    try std.testing.expectApproxEqAbs(result[2], 3.0, 0.001);
}
