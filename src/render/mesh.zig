//! 3D Mesh data structure

const std = @import("std");
const math = @import("../math/math.zig");

/// Vertex format
pub const Vertex = struct {
    position: math.Vec3,
    normal: math.Vec3,
    uv: math.Vec2,
    color: [4]u8 = .{ 255, 255, 255, 255 },
};

/// 3D Mesh
pub const Mesh = struct {
    vertices: []Vertex,
    indices: []u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, vertex_count: usize, index_count: usize) !Mesh {
        return .{
            .vertices = try allocator.alloc(Vertex, vertex_count),
            .indices = try allocator.alloc(u32, index_count),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Mesh) void {
        self.allocator.free(self.vertices);
        self.allocator.free(self.indices);
    }

    /// Create a unit cube
    pub fn cube(allocator: std.mem.Allocator) !Mesh {
        var mesh = try init(allocator, 24, 36);

        const positions = [_][3]f32{
            .{ -1, -1, 1 }, .{ 1, -1, 1 }, .{ 1, 1, 1 }, .{ -1, 1, 1 }, // front
            .{ -1, -1, -1 }, .{ -1, 1, -1 }, .{ 1, 1, -1 }, .{ 1, -1, -1 }, // back
            .{ -1, 1, -1 }, .{ -1, 1, 1 }, .{ 1, 1, 1 }, .{ 1, 1, -1 }, // top
            .{ -1, -1, -1 }, .{ 1, -1, -1 }, .{ 1, -1, 1 }, .{ -1, -1, 1 }, // bottom
            .{ 1, -1, -1 }, .{ 1, 1, -1 }, .{ 1, 1, 1 }, .{ 1, -1, 1 }, // right
            .{ -1, -1, -1 }, .{ -1, -1, 1 }, .{ -1, 1, 1 }, .{ -1, 1, -1 }, // left
        };

        const normals = [_][3]f32{
            .{ 0, 0, 1 },  .{ 0, 0, 1 },  .{ 0, 0, 1 },  .{ 0, 0, 1 },
            .{ 0, 0, -1 }, .{ 0, 0, -1 }, .{ 0, 0, -1 }, .{ 0, 0, -1 },
            .{ 0, 1, 0 },  .{ 0, 1, 0 },  .{ 0, 1, 0 },  .{ 0, 1, 0 },
            .{ 0, -1, 0 }, .{ 0, -1, 0 }, .{ 0, -1, 0 }, .{ 0, -1, 0 },
            .{ 1, 0, 0 },  .{ 1, 0, 0 },  .{ 1, 0, 0 },  .{ 1, 0, 0 },
            .{ -1, 0, 0 }, .{ -1, 0, 0 }, .{ -1, 0, 0 }, .{ -1, 0, 0 },
        };

        const uvs = [_][2]f32{
            .{ 0, 0 }, .{ 1, 0 }, .{ 1, 1 }, .{ 0, 1 },
            .{ 1, 0 }, .{ 1, 1 }, .{ 0, 1 }, .{ 0, 0 },
            .{ 0, 1 }, .{ 0, 0 }, .{ 1, 0 }, .{ 1, 1 },
            .{ 1, 1 }, .{ 0, 1 }, .{ 0, 0 }, .{ 1, 0 },
            .{ 1, 0 }, .{ 1, 1 }, .{ 0, 1 }, .{ 0, 0 },
            .{ 0, 0 }, .{ 1, 0 }, .{ 1, 1 }, .{ 0, 1 },
        };

        for (0..24) |i| {
            mesh.vertices[i] = .{
                .position = math.Vec3.init(positions[i][0], positions[i][1], positions[i][2]),
                .normal = math.Vec3.init(normals[i][0], normals[i][1], normals[i][2]),
                .uv = math.Vec2.init(uvs[i][0], uvs[i][1]),
            };
        }

        const indices = [_]u32{
            0, 1, 2, 0, 2, 3, // front
            4, 5, 6, 4, 6, 7, // back
            8, 9, 10, 8, 10, 11, // top
            12, 13, 14, 12, 14, 15, // bottom
            16, 17, 18, 16, 18, 19, // right
            20, 21, 22, 20, 22, 23, // left
        };
        @memcpy(mesh.indices, &indices);

        return mesh;
    }

    /// Create a plane
    pub fn plane(allocator: std.mem.Allocator, subdivisions: u32) !Mesh {
        const verts_per_side = subdivisions + 1;
        const vert_count = verts_per_side * verts_per_side;
        const tri_count = subdivisions * subdivisions * 2;

        var mesh = try init(allocator, vert_count, tri_count * 3);

        var vi: usize = 0;
        for (0..verts_per_side) |z| {
            for (0..verts_per_side) |x| {
                const u = @as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(subdivisions));
                const v = @as(f32, @floatFromInt(z)) / @as(f32, @floatFromInt(subdivisions));
                mesh.vertices[vi] = .{
                    .position = math.Vec3.init(u - 0.5, 0, v - 0.5),
                    .normal = math.Vec3.Y,
                    .uv = math.Vec2.init(u, v),
                };
                vi += 1;
            }
        }

        var ii: usize = 0;
        for (0..subdivisions) |z| {
            for (0..subdivisions) |x| {
                const tl = @as(u32, @intCast(z * verts_per_side + x));
                const tr = tl + 1;
                const bl = tl + @as(u32, @intCast(verts_per_side));
                const br = bl + 1;

                mesh.indices[ii] = tl;
                mesh.indices[ii + 1] = bl;
                mesh.indices[ii + 2] = tr;
                mesh.indices[ii + 3] = tr;
                mesh.indices[ii + 4] = bl;
                mesh.indices[ii + 5] = br;
                ii += 6;
            }
        }

        return mesh;
    }
};

test "mesh cube" {
    const allocator = std.testing.allocator;
    var mesh = try Mesh.cube(allocator);
    defer mesh.deinit();

    try std.testing.expectEqual(@as(usize, 24), mesh.vertices.len);
    try std.testing.expectEqual(@as(usize, 36), mesh.indices.len);
}
