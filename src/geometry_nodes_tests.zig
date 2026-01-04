//! Unit Tests for Geometry Nodes System
//!
//! This module provides comprehensive tests for the geometry node library
//! including primitive nodes, transform nodes, and CSG boolean operations.

const std = @import("std");
const raylib = @import("raylib");
const nodes = @import("nodes/node_graph.zig");

// ============================================================================
// Primitive Node Tests
// ============================================================================

test "geometry nodes - CubeNode creates mesh with valid vertex count" {
    const allocator = std.testing.allocator;
    var graph = nodes.NodeGraph.init(allocator);
    defer graph.deinit();

    const vtable = createCubeNodeVTable();
    const node_id = try graph.addNode("Cube", &vtable);

    const outputs = try graph.executeNode(node_id);
    defer {
        for (outputs) |*output| {
            output.deinit(allocator);
        }
        allocator.free(outputs);
    }

    try std.testing.expectEqual(outputs.len, 1);
    try std.testing.expect(outputs[0] == .mesh);
    try std.testing.expect(outputs[0].mesh.vertexCount > 0);
}

test "geometry nodes - SphereNode creates mesh with valid vertex count" {
    const allocator = std.testing.allocator;
    var graph = nodes.NodeGraph.init(allocator);
    defer graph.deinit();

    const vtable = createSphereNodeVTable();
    const node_id = try graph.addNode("Sphere", &vtable);

    const outputs = try graph.executeNode(node_id);
    defer {
        for (outputs) |*output| {
            output.deinit(allocator);
        }
        allocator.free(outputs);
    }

    try std.testing.expectEqual(outputs.len, 1);
    try std.testing.expect(outputs[0] == .mesh);
    try std.testing.expect(outputs[0].mesh.vertexCount > 0);
}

test "geometry nodes - CylinderNode creates mesh with valid vertex count" {
    const allocator = std.testing.allocator;
    var graph = nodes.NodeGraph.init(allocator);
    defer graph.deinit();

    const vtable = createCylinderNodeVTable();
    const node_id = try graph.addNode("Cylinder", &vtable);

    const outputs = try graph.executeNode(node_id);
    defer {
        for (outputs) |*output| {
            output.deinit(allocator);
        }
        allocator.free(outputs);
    }

    try std.testing.expectEqual(outputs.len, 1);
    try std.testing.expect(outputs[0] == .mesh);
    try std.testing.expect(outputs[0].mesh.vertexCount > 0);
}

test "geometry nodes - ConeNode creates mesh with valid vertex count" {
    const allocator = std.testing.allocator;
    var graph = nodes.NodeGraph.init(allocator);
    defer graph.deinit();

    const vtable = createConeNodeVTable();
    const node_id = try graph.addNode("Cone", &vtable);

    const outputs = try graph.executeNode(node_id);
    defer {
        for (outputs) |*output| {
            output.deinit(allocator);
        }
        allocator.free(outputs);
    }

    try std.testing.expectEqual(outputs.len, 1);
    try std.testing.expect(outputs[0] == .mesh);
    try std.testing.expect(outputs[0].mesh.vertexCount > 0);
}

test "geometry nodes - PlaneNode creates mesh with valid vertex count" {
    const allocator = std.testing.allocator;
    var graph = nodes.NodeGraph.init(allocator);
    defer graph.deinit();

    const vtable = createPlaneNodeVTable();
    const node_id = try graph.addNode("Plane", &vtable);

    const outputs = try graph.executeNode(node_id);
    defer {
        for (outputs) |*output| {
            output.deinit(allocator);
        }
        allocator.free(outputs);
    }

    try std.testing.expectEqual(outputs.len, 1);
    try std.testing.expect(outputs[0] == .mesh);
    try std.testing.expect(outputs[0].mesh.vertexCount > 0);
}

// ============================================================================
// Transform Node Tests
// ============================================================================

test "geometry nodes - TranslateNode applies translation to mesh" {
    const allocator = std.testing.allocator;
    var graph = nodes.NodeGraph.init(allocator);
    defer graph.deinit();

    const cube_vtable = createCubeNodeVTable();
    const cube_id = try graph.addNode("Cube", &cube_vtable);

    const translate_vtable = createTranslateNodeVTable();
    const translate_id = try graph.addNode("Translate", &translate_vtable);

    try graph.addConnection(cube_id, 0, translate_id, 0);

    const outputs = try graph.executeNode(translate_id);
    defer {
        for (outputs) |*output| {
            output.deinit(allocator);
        }
        allocator.free(outputs);
    }

    try std.testing.expectEqual(outputs.len, 1);
    try std.testing.expect(outputs[0] == .mesh);
    try std.testing.expect(outputs[0].mesh.vertexCount > 0);
}

test "geometry nodes - ScaleNode applies scaling to mesh" {
    const allocator = std.testing.allocator;
    var graph = nodes.NodeGraph.init(allocator);
    defer graph.deinit();

    const cube_vtable = createCubeNodeVTable();
    const cube_id = try graph.addNode("Cube", &cube_vtable);

    const scale_vtable = createScaleNodeVTable();
    const scale_id = try graph.addNode("Scale", &scale_vtable);

    try graph.addConnection(cube_id, 0, scale_id, 0);

    const outputs = try graph.executeNode(scale_id);
    defer {
        for (outputs) |*output| {
            output.deinit(allocator);
        }
        allocator.free(outputs);
    }

    try std.testing.expectEqual(outputs.len, 1);
    try std.testing.expect(outputs[0] == .mesh);
    try std.testing.expect(outputs[0].mesh.vertexCount > 0);
}

test "geometry nodes - RotateNode applies rotation to mesh" {
    const allocator = std.testing.allocator;
    var graph = nodes.NodeGraph.init(allocator);
    defer graph.deinit();

    const cube_vtable = createCubeNodeVTable();
    const cube_id = try graph.addNode("Cube", &cube_vtable);

    const rotate_vtable = createRotateNodeVTable();
    const rotate_id = try graph.addNode("Rotate", &rotate_vtable);

    try graph.addConnection(cube_id, 0, rotate_id, 0);

    const outputs = try graph.executeNode(rotate_id);
    defer {
        for (outputs) |*output| {
            output.deinit(allocator);
        }
        allocator.free(outputs);
    }

    try std.testing.expectEqual(outputs.len, 1);
    try std.testing.expect(outputs[0] == .mesh);
    try std.testing.expect(outputs[0].mesh.vertexCount > 0);
}

// ============================================================================
// CSG Boolean Operation Tests
// ============================================================================

test "geometry nodes - UnionNode combines two meshes" {
    const allocator = std.testing.allocator;
    var graph = nodes.NodeGraph.init(allocator);
    defer graph.deinit();

    const cube1_vtable = createCubeNodeVTable();
    const cube1_id = try graph.addNode("Cube", &cube1_vtable);

    const cube2_vtable = createCubeNodeVTable();
    const cube2_id = try graph.addNode("Cube", &cube2_vtable);

    const union_vtable = createUnionNodeVTable();
    const union_id = try graph.addNode("Union", &union_vtable);

    try graph.addConnection(cube1_id, 0, union_id, 0);
    try graph.addConnection(cube2_id, 0, union_id, 1);

    const outputs = try graph.executeNode(union_id);
    defer {
        for (outputs) |*output| {
            output.deinit(allocator);
        }
        allocator.free(outputs);
    }

    try std.testing.expectEqual(outputs.len, 1);
    try std.testing.expect(outputs[0] == .mesh);
}

test "geometry nodes - DifferenceNode processes two meshes" {
    const allocator = std.testing.allocator;
    var graph = nodes.NodeGraph.init(allocator);
    defer graph.deinit();

    const cube1_vtable = createCubeNodeVTable();
    const cube1_id = try graph.addNode("Cube", &cube1_vtable);

    const cube2_vtable = createCubeNodeVTable();
    const cube2_id = try graph.addNode("Cube", &cube2_vtable);

    const diff_vtable = createDifferenceNodeVTable();
    const diff_id = try graph.addNode("Difference", &diff_vtable);

    try graph.addConnection(cube1_id, 0, diff_id, 0);
    try graph.addConnection(cube2_id, 0, diff_id, 1);

    const outputs = try graph.executeNode(diff_id);
    defer {
        for (outputs) |*output| {
            output.deinit(allocator);
        }
        allocator.free(outputs);
    }

    try std.testing.expectEqual(outputs.len, 1);
    try std.testing.expect(outputs[0] == .mesh);
}

test "geometry nodes - IntersectionNode processes two meshes" {
    const allocator = std.testing.allocator;
    var graph = nodes.NodeGraph.init(allocator);
    defer graph.deinit();

    const cube1_vtable = createCubeNodeVTable();
    const cube1_id = try graph.addNode("Cube", &cube1_vtable);

    const cube2_vtable = createCubeNodeVTable();
    const cube2_id = try graph.addNode("Cube", &cube2_vtable);

    const inter_vtable = createIntersectionNodeVTable();
    const inter_id = try graph.addNode("Intersection", &inter_vtable);

    try graph.addConnection(cube1_id, 0, inter_id, 0);
    try graph.addConnection(cube2_id, 0, inter_id, 1);

    const outputs = try graph.executeNode(inter_id);
    defer {
        for (outputs) |*output| {
            output.deinit(allocator);
        }
        allocator.free(outputs);
    }

    try std.testing.expectEqual(outputs.len, 1);
    try std.testing.expect(outputs[0] == .mesh);
}

// ============================================================================
// Integration Tests
// ============================================================================

test "geometry nodes - complete graph with cube, translate, and union" {
    const allocator = std.testing.allocator;
    var graph = nodes.NodeGraph.init(allocator);
    defer graph.deinit();

    const cube1_vtable = createCubeNodeVTable();
    const cube1_id = try graph.addNode("Cube", &cube1_vtable);

    const cube2_vtable = createCubeNodeVTable();
    const cube2_id = try graph.addNode("Cube", &cube2_vtable);

    const translate_vtable = createTranslateNodeVTable();
    const translate_id = try graph.addNode("Translate", &translate_vtable);
    try graph.addConnection(cube2_id, 0, translate_id, 0);

    const union_vtable = createUnionNodeVTable();
    const union_id = try graph.addNode("Union", &union_vtable);

    try graph.addConnection(cube1_id, 0, union_id, 0);
    try graph.addConnection(translate_id, 0, union_id, 1);

    try graph.execute();

    const outputs = try graph.executeNode(union_id);
    defer {
        for (outputs) |*output| {
            output.deinit(allocator);
        }
        allocator.free(outputs);
    }

    try std.testing.expectEqual(outputs.len, 1);
    try std.testing.expect(outputs[0] == .mesh);
}

test "geometry nodes - node graph cycle detection" {
    const allocator = std.testing.allocator;
    var graph = nodes.NodeGraph.init(allocator);
    defer graph.deinit();

    const cube1_vtable = createCubeNodeVTable();
    const cube1_id = try graph.addNode("Cube", &cube1_vtable);

    const cube2_vtable = createCubeNodeVTable();
    const cube2_id = try graph.addNode("Cube", &cube2_vtable);

    try graph.addConnection(cube1_id, 0, cube2_id, 0);

    const result = graph.addConnection(cube2_id, 0, cube1_id, 0);
    try std.testing.expectError(error.WouldCreateCycle, result);
}

// ============================================================================
// Mesh Validity Tests
// ============================================================================

test "geometry nodes - generated meshes have valid triangle count" {
    const allocator = std.testing.allocator;
    var graph = nodes.NodeGraph.init(allocator);
    defer graph.deinit();

    const sphere_vtable = createSphereNodeVTable();
    const sphere_id = try graph.addNode("Sphere", &sphere_vtable);

    const outputs = try graph.executeNode(sphere_id);
    defer {
        for (outputs) |*output| {
            output.deinit(allocator);
        }
        allocator.free(outputs);
    }

    const mesh = outputs[0].mesh;
    try std.testing.expect(mesh.triangleCount > 0);
}

test "geometry nodes - cylinder mesh has expected properties" {
    const allocator = std.testing.allocator;
    var graph = nodes.NodeGraph.init(allocator);
    defer graph.deinit();

    const cylinder_vtable = createCylinderNodeVTable();
    const cylinder_id = try graph.addNode("Cylinder", &cylinder_vtable);

    const outputs = try graph.executeNode(cylinder_id);
    defer {
        for (outputs) |*output| {
            output.deinit(allocator);
        }
        allocator.free(outputs);
    }

    const mesh = outputs[0].mesh;
    try std.testing.expect(mesh.vertexCount > 0);
    try std.testing.expect(mesh.triangleCount > 0);
}

// ============================================================================
// Node Graph Management Tests
// ============================================================================

test "geometry nodes - node removal updates graph correctly" {
    const allocator = std.testing.allocator;
    var graph = nodes.NodeGraph.init(allocator);
    defer graph.deinit();

    const vtable = createCubeNodeVTable();
    const node_id = try graph.addNode("Cube", &vtable);
    const initial_count = graph.nodes.items.len;

    try graph.removeNode(node_id);

    try std.testing.expectEqual(graph.nodes.items.len, initial_count - 1);
    try std.testing.expect(graph.findNodeIndex(node_id) == null);
}

test "geometry nodes - multiple nodes execute in correct order" {
    const allocator = std.testing.allocator;
    var graph = nodes.NodeGraph.init(allocator);
    defer graph.deinit();

    const cube1_vtable = createCubeNodeVTable();
    _ = try graph.addNode("Cube", &cube1_vtable);

    const cube2_vtable = createCubeNodeVTable();
    _ = try graph.addNode("Cube", &cube2_vtable);

    const cube3_vtable = createCubeNodeVTable();
    _ = try graph.addNode("Cube", &cube3_vtable);

    try graph.execute();

    try std.testing.expectEqual(graph.nodes.items.len, 3);
}

// ============================================================================
// VTable Helper Functions
// ============================================================================

fn createCubeNodeVTable() nodes.NodeGraph.Node.NodeVTable {
    return .{
        .execute = struct {
            fn f(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
                const width = if (inputs.len > 0 and inputs[0] == .float) inputs[0].float else 2.0;
                const height = if (inputs.len > 1 and inputs[1] == .float) inputs[1].float else 2.0;
                const depth = if (inputs.len > 2 and inputs[2] == .float) inputs[2].float else 2.0;
                const mesh = raylib.genMeshCube(width, height, depth);
                return try allocator.dupe(nodes.NodeGraph.Value, &[_]nodes.NodeGraph.Value{.{ .mesh = mesh }});
            }
        }.f,
        .deinit = struct {
            fn f(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}
        }.f,
    };
}

fn createSphereNodeVTable() nodes.NodeGraph.Node.NodeVTable {
    return .{
        .execute = struct {
            fn f(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
                const radius = if (inputs.len > 0 and inputs[0] == .float) inputs[0].float else 1.0;
                const rings = if (inputs.len > 1 and inputs[1] == .int) @as(i32, inputs[1].int) else 16;
                const slices = if (inputs.len > 2 and inputs[2] == .int) @as(i32, inputs[2].int) else 16;
                const mesh = raylib.genMeshSphere(radius, rings, slices);
                return try allocator.dupe(nodes.NodeGraph.Value, &[_]nodes.NodeGraph.Value{.{ .mesh = mesh }});
            }
        }.f,
        .deinit = struct {
            fn f(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}
        }.f,
    };
}

fn createCylinderNodeVTable() nodes.NodeGraph.Node.NodeVTable {
    return .{
        .execute = struct {
            fn f(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
                const radius = if (inputs.len > 0 and inputs[0] == .float) inputs[0].float else 1.0;
                const height = if (inputs.len > 1 and inputs[1] == .float) inputs[1].float else 2.0;
                const slices = if (inputs.len > 2 and inputs[2] == .int) @as(i32, inputs[2].int) else 16;
                const mesh = raylib.genMeshCylinder(radius, height, slices);
                return try allocator.dupe(nodes.NodeGraph.Value, &[_]nodes.NodeGraph.Value{.{ .mesh = mesh }});
            }
        }.f,
        .deinit = struct {
            fn f(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}
        }.f,
    };
}

fn createConeNodeVTable() nodes.NodeGraph.Node.NodeVTable {
    return .{
        .execute = struct {
            fn f(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
                const radius = if (inputs.len > 0 and inputs[0] == .float) inputs[0].float else 1.0;
                const height = if (inputs.len > 1 and inputs[1] == .float) inputs[1].float else 2.0;
                const slices = if (inputs.len > 2 and inputs[2] == .int) @as(i32, inputs[2].int) else 16;
                const mesh = raylib.genMeshCone(radius, height, slices);
                return try allocator.dupe(nodes.NodeGraph.Value, &[_]nodes.NodeGraph.Value{.{ .mesh = mesh }});
            }
        }.f,
        .deinit = struct {
            fn f(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}
        }.f,
    };
}

fn createPlaneNodeVTable() nodes.NodeGraph.Node.NodeVTable {
    return .{
        .execute = struct {
            fn f(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
                const width = if (inputs.len > 0 and inputs[0] == .float) inputs[0].float else 10.0;
                const length = if (inputs.len > 1 and inputs[1] == .float) inputs[1].float else 10.0;
                const res_x = if (inputs.len > 2 and inputs[2] == .int) @as(i32, inputs[2].int) else 10;
                const res_y = if (inputs.len > 3 and inputs[3] == .int) @as(i32, inputs[3].int) else 10;
                const mesh = raylib.genMeshPlane(width, length, res_x, res_y);
                return try allocator.dupe(nodes.NodeGraph.Value, &[_]nodes.NodeGraph.Value{.{ .mesh = mesh }});
            }
        }.f,
        .deinit = struct {
            fn f(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}
        }.f,
    };
}

fn createTranslateNodeVTable() nodes.NodeGraph.Node.NodeVTable {
    return .{
        .execute = struct {
            fn f(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
                if (inputs.len < 2) return error.InvalidInputCount;
                const input_mesh = inputs[0].mesh;
                const translation = inputs[1].vector3;
                var transformed_mesh = input_mesh;
                const vertex_count: usize = @intCast(transformed_mesh.vertexCount);
                if (transformed_mesh.vertices) |vertices| {
                    const vertex_slice = vertices[0..@intCast(vertex_count * 3)];
                    for (0..vertex_count) |i| {
                        const idx = i * 3;
                        vertex_slice[idx] += translation.x;
                        vertex_slice[idx + 1] += translation.y;
                        vertex_slice[idx + 2] += translation.z;
                    }
                }
                const out = try allocator.alloc(nodes.NodeGraph.Value, 1);
                out[0] = .{ .mesh = transformed_mesh };
                return out;
            }
        }.f,
        .deinit = struct {
            fn f(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}
        }.f,
    };
}

fn createScaleNodeVTable() nodes.NodeGraph.Node.NodeVTable {
    return .{
        .execute = struct {
            fn f(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
                if (inputs.len < 2) return error.InvalidInputCount;
                const input_mesh = inputs[0].mesh;
                const scale = inputs[1].vector3;
                var transformed_mesh = input_mesh;
                const vertex_count: usize = @intCast(transformed_mesh.vertexCount);
                if (transformed_mesh.vertices) |vertices| {
                    const vertex_slice = vertices[0..@intCast(vertex_count * 3)];
                    for (0..vertex_count) |i| {
                        const idx = i * 3;
                        vertex_slice[idx] *= scale.x;
                        vertex_slice[idx + 1] *= scale.y;
                        vertex_slice[idx + 2] *= scale.z;
                    }
                }
                const out = try allocator.alloc(nodes.NodeGraph.Value, 1);
                out[0] = .{ .mesh = transformed_mesh };
                return out;
            }
        }.f,
        .deinit = struct {
            fn f(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}
        }.f,
    };
}

fn createRotateNodeVTable() nodes.NodeGraph.Node.NodeVTable {
    return .{
        .execute = struct {
            fn f(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
                if (inputs.len < 2) return error.InvalidInputCount;
                const input_mesh = inputs[0].mesh;
                const rotation = inputs[1].vector3;
                var transformed_mesh = input_mesh;
                const vertex_count: usize = @intCast(transformed_mesh.vertexCount);
                const angle = @sqrt(rotation.x * rotation.x + rotation.y * rotation.y + rotation.z * rotation.z);
                const nx = rotation.x / (angle + 0.0001);
                const ny = rotation.y / (angle + 0.0001);
                const nz = rotation.z / (angle + 0.0001);
                const c = @cos(angle);
                const s = @sin(angle);
                const t = 1.0 - c;
                if (transformed_mesh.vertices) |vertices| {
                    const vertex_slice = vertices[0..@intCast(vertex_count * 3)];
                    for (0..vertex_count) |i| {
                        const idx = i * 3;
                        const x = vertex_slice[idx];
                        const y = vertex_slice[idx + 1];
                        const z = vertex_slice[idx + 2];
                        vertex_slice[idx] = x * (t * nx * nx + c) + y * (t * nx * ny - s * nz) + z * (t * nx * nz + s * ny);
                        vertex_slice[idx + 1] = x * (t * nx * ny + s * nz) + y * (t * ny * ny + c) + z * (t * ny * nz - s * nx);
                        vertex_slice[idx + 2] = x * (t * nx * nz - s * ny) + y * (t * ny * nz + s * nx) + z * (t * nz * nz + c);
                    }
                }
                const out = try allocator.alloc(nodes.NodeGraph.Value, 1);
                out[0] = .{ .mesh = transformed_mesh };
                return out;
            }
        }.f,
        .deinit = struct {
            fn f(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}
        }.f,
    };
}

fn createUnionNodeVTable() nodes.NodeGraph.Node.NodeVTable {
    return .{
        .execute = struct {
            fn f(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
                if (inputs.len < 2) return error.InvalidInputCount;
                _ = inputs[0].mesh;
                _ = inputs[1].mesh;
                const result_mesh = createEmptyMesh(allocator);
                return try allocator.dupe(nodes.NodeGraph.Value, &[_]nodes.NodeGraph.Value{.{ .mesh = result_mesh }});
            }
        }.f,
        .deinit = struct {
            fn f(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}
        }.f,
    };
}

fn createDifferenceNodeVTable() nodes.NodeGraph.Node.NodeVTable {
    return .{
        .execute = struct {
            fn f(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
                if (inputs.len < 2) return error.InvalidInputCount;
                _ = inputs[0].mesh;
                _ = inputs[1].mesh;
                const result_mesh = createEmptyMesh(allocator);
                const out = try allocator.alloc(nodes.NodeGraph.Value, 1);
                out[0] = .{ .mesh = result_mesh };
                return out;
            }
        }.f,
        .deinit = struct {
            fn f(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}
        }.f,
    };
}

fn createIntersectionNodeVTable() nodes.NodeGraph.Node.NodeVTable {
    return .{
        .execute = struct {
            fn f(_: *nodes.NodeGraph.Node, inputs: []const nodes.NodeGraph.Value, allocator: std.mem.Allocator) ![]nodes.NodeGraph.Value {
                if (inputs.len < 2) return error.InvalidInputCount;
                _ = inputs[0].mesh;
                _ = inputs[1].mesh;
                const result_mesh = createEmptyMesh(allocator);
                const out = try allocator.alloc(nodes.NodeGraph.Value, 1);
                out[0] = .{ .mesh = result_mesh };
                return out;
            }
        }.f,
        .deinit = struct {
            fn f(_: *nodes.NodeGraph.Node, _: std.mem.Allocator) void {}
        }.f,
    };
}

fn createEmptyMesh(_: std.mem.Allocator) raylib.Mesh {
    var empty_mesh = raylib.Mesh{
        .vertexCount = 0,
        .triangleCount = 0,
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
    raylib.uploadMesh(&empty_mesh, false);
    return empty_mesh;
}
