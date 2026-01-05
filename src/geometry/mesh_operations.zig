//! Mesh operations for geometry node system.
//!
//! Provides utilities for copying and manipulating raylib meshes with proper memory management.

const std = @import("std");
const raylib = @import("raylib");

/// Create a deep copy of a raylib mesh with allocator-managed memory.
/// This function copies all mesh data (vertices, texcoords, normals, colors, indices)
/// and allocates new memory for each array to ensure the copy is independent.
pub fn copyMesh(mesh: raylib.Mesh, allocator: std.mem.Allocator) !raylib.Mesh {
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

    if (mesh.vertices != null) {
        const vertex_count = @as(usize, @intCast(mesh.vertexCount)) * 3;
        const vertex_data = try allocator.alloc(f32, vertex_count);
        const src_ptr = @as([*]const f32, @ptrCast(mesh.vertices.?));
        const src_slice = src_ptr[0..vertex_count];
        @memcpy(vertex_data[0..vertex_count], src_slice);
        new_mesh.vertices = vertex_data.ptr;
    }

    if (mesh.texcoords != null) {
        const texcoord_count = @as(usize, @intCast(mesh.vertexCount)) * 2;
        const texcoord_data = try allocator.alloc(f32, texcoord_count);
        if (mesh.texcoords) |texcoords| {
            @memcpy(texcoord_data[0..texcoord_count], texcoords[0..texcoord_count]);
        }
        new_mesh.texcoords = texcoord_data.ptr;
    }

    if (mesh.texcoords2 != null) {
        const texcoord_count = @as(usize, @intCast(mesh.vertexCount)) * 2;
        const texcoord_data = try allocator.alloc(f32, texcoord_count);
        @memcpy(texcoord_data[0..texcoord_count], mesh.texcoords2[0..texcoord_count]);
        new_mesh.texcoords2 = texcoord_data.ptr;
    }

    if (mesh.normals != null) {
        const normal_count = @as(usize, @intCast(mesh.vertexCount)) * 3;
        const normal_data = try allocator.alloc(f32, normal_count);
        if (mesh.normals) |normals| {
            @memcpy(normal_data[0..normal_count], normals[0..normal_count]);
        }
        new_mesh.normals = normal_data.ptr;
    }

    if (mesh.tangents != null) {
        const tangent_count = @as(usize, @intCast(mesh.vertexCount)) * 4;
        const tangent_data = try allocator.alloc(f32, tangent_count);
        if (mesh.tangents) |tangents| {
            @memcpy(tangent_data[0..tangent_count], tangents[0..tangent_count]);
        }
        new_mesh.tangents = tangent_data.ptr;
    }

    if (mesh.colors != null) {
        const color_count = @as(usize, @intCast(mesh.vertexCount)) * 4;
        const color_data = try allocator.alloc(u8, color_count);
        if (mesh.colors) |colors| {
            @memcpy(color_data[0..color_count], colors[0..color_count]);
        }
        new_mesh.colors = color_data.ptr;
    }

    if (mesh.indices != null) {
        const index_count = @as(usize, @intCast(mesh.triangleCount)) * 3;
        const index_data = try allocator.alloc(u16, index_count);
        if (mesh.indices) |indices| {
            @memcpy(index_data[0..index_count], indices[0..index_count]);
        }
        new_mesh.indices = index_data.ptr;
    }

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

    new_mesh.boneCount = mesh.boneCount;
    if (mesh.boneIds != null) {
        const bone_id_count = @as(usize, @intCast(mesh.vertexCount)) * 4;
        new_mesh.boneIds = (try allocator.alloc(u8, bone_id_count)).ptr;
        if (mesh.boneIds) |srcBoneIds| {
            @memcpy(new_mesh.boneIds[0..bone_id_count], srcBoneIds[0..bone_id_count]);
        }
    }

    if (mesh.boneWeights != null) {
        const bone_weight_count = @as(usize, @intCast(mesh.vertexCount)) * 4;
        new_mesh.boneWeights = (try allocator.alloc(f32, bone_weight_count)).ptr;
        if (mesh.boneWeights) |srcBoneWeights| {
            @memcpy(new_mesh.boneWeights[0..bone_weight_count], srcBoneWeights[0..bone_weight_count]);
        }
    }

    raylib.uploadMesh(&new_mesh, false);

    return new_mesh;
}

/// Free mesh data that was allocated by copyMesh.
/// Note: This does not call raylib.unloadMesh as the mesh may still be in use.
pub fn freeMesh(mesh: *raylib.Mesh, allocator: std.mem.Allocator) void {
    if (mesh.vertices != null) {
        const vertex_count = @as(usize, @intCast(mesh.vertexCount)) * 3;
        allocator.free(mesh.vertices[0..vertex_count]);
        mesh.vertices = null;
    }

    if (mesh.texcoords != null) {
        const texcoord_count = @as(usize, @intCast(mesh.vertexCount)) * 2;
        allocator.free(mesh.texcoords[0..texcoord_count]);
        mesh.texcoords = null;
    }

    if (mesh.texcoords2 != null) {
        const texcoord_count = @as(usize, @intCast(mesh.vertexCount)) * 2;
        allocator.free(mesh.texcoords2[0..texcoord_count]);
        mesh.texcoords2 = null;
    }

    if (mesh.normals != null) {
        const normal_count = @as(usize, @intCast(mesh.vertexCount)) * 3;
        allocator.free(mesh.normals[0..normal_count]);
        mesh.normals = null;
    }

    if (mesh.tangents != null) {
        const tangent_count = @as(usize, @intCast(mesh.vertexCount)) * 4;
        allocator.free(mesh.tangents[0..tangent_count]);
        mesh.tangents = null;
    }

    if (mesh.colors != null) {
        const color_count = @as(usize, @intCast(mesh.vertexCount)) * 4;
        allocator.free(mesh.colors[0..color_count]);
        mesh.colors = null;
    }

    if (mesh.indices != null) {
        const index_count = @as(usize, @intCast(mesh.triangleCount)) * 3;
        allocator.free(mesh.indices[0..index_count]);
        mesh.indices = null;
    }

    if (mesh.animVertices != null) {
        const anim_vertex_count = @as(usize, @intCast(mesh.vertexCount)) * 3;
        allocator.free(mesh.animVertices[0..anim_vertex_count]);
        mesh.animVertices = null;
    }

    if (mesh.animNormals != null) {
        const anim_normal_count = @as(usize, @intCast(mesh.vertexCount)) * 3;
        allocator.free(mesh.animNormals[0..anim_normal_count]);
        mesh.animNormals = null;
    }

    if (mesh.boneIds != null) {
        const bone_id_count = @as(usize, @intCast(mesh.vertexCount)) * 4;
        allocator.free(mesh.boneIds[0..bone_id_count]);
        mesh.boneIds = null;
    }

    if (mesh.boneWeights != null) {
        const bone_weight_count = @as(usize, @intCast(mesh.vertexCount)) * 4;
        allocator.free(mesh.boneWeights[0..bone_weight_count]);
        mesh.boneWeights = null;
    }
}
