//! Rendering Resources - GPU resource management
//!
//! This module provides high-level resource management for textures,
//! buffers, shaders, and other GPU resources used in rendering.

const std = @import("std");
const nyon = @import("nyon_game");
const render_graph = @import("../render_graph.zig");

// ============================================================================
// Texture Resources
// ============================================================================

/// Managed texture resource
pub const Texture = struct {
    handle: render_graph.ResourceHandle,
    desc: render_graph.ResourceDesc,
    // In full implementation, would contain GPU texture handle

    /// Create a texture from an image file
    pub fn fromFile(
        graph: *render_graph.RenderGraph,
        file_path: []const u8,
        generate_mipmaps: bool,
    ) !Texture {
        // Load image data (would use raylib or custom loader)
        _ = file_path;

        const desc = render_graph.ResourceDesc{
            .texture_2d = .{
                .width = 512, // Would get from loaded image
                .height = 512,
                .format = .rgba8,
                .mip_levels = if (generate_mipmaps) 4 else 1,
            },
        };

        const handle = try graph.createResource(desc);

        return Texture{
            .handle = handle,
            .desc = desc,
        };
    }

    /// Create a render target texture
    pub fn renderTarget(
        graph: *render_graph.RenderGraph,
        width: u32,
        height: u32,
        format: render_graph.TextureFormat,
    ) !Texture {
        const desc = render_graph.ResourceDesc{
            .render_target = .{
                .width = width,
                .height = height,
                .format = format,
            },
        };

        const handle = try graph.createResource(desc);

        return Texture{
            .handle = handle,
            .desc = desc,
        };
    }

    /// Get texture dimensions
    pub fn getSize(self: *const Texture) struct { width: u32, height: u32 } {
        return switch (self.desc) {
            .texture_2d => |tex| .{ .width = tex.width, .height = tex.height },
            .render_target => |rt| .{ .width = rt.width, .height = rt.height },
            else => .{ .width = 0, .height = 0 },
        };
    }
};

/// Cubemap texture for environment mapping
pub const Cubemap = struct {
    handle: render_graph.ResourceHandle,
    size: u32,

    /// Create a cubemap from 6 faces
    pub fn fromFiles(
        graph: *render_graph.RenderGraph,
        face_files: [6][]const u8,
    ) !Cubemap {
        _ = face_files; // Would load 6 images

        const desc = render_graph.ResourceDesc{
            .texture_cube = .{
                .size = 512, // Would get from loaded images
                .format = .rgba8,
            },
        };

        const handle = try graph.createResource(desc);

        return Cubemap{
            .handle = handle,
            .size = 512,
        };
    }
};

// ============================================================================
// Buffer Resources
// ============================================================================

/// GPU buffer for vertex data, indices, uniforms, etc.
pub const Buffer = struct {
    handle: render_graph.ResourceHandle,
    desc: render_graph.ResourceDesc,
    size: usize,

    /// Create a vertex buffer
    pub fn vertex(graph: *render_graph.RenderGraph, data: []const f32) !Buffer {
        const desc = render_graph.ResourceDesc{
            .buffer = .{
                .size = data.len * @sizeOf(f32),
                .usage = .vertex,
            },
        };

        const handle = try graph.createResource(desc);

        return Buffer{
            .handle = handle,
            .desc = desc,
            .size = data.len * @sizeOf(f32),
        };
    }

    /// Create an index buffer
    pub fn index(graph: *render_graph.RenderGraph, data: []const u32) !Buffer {
        const desc = render_graph.ResourceDesc{
            .buffer = .{
                .size = data.len * @sizeOf(u32),
                .usage = .index,
            },
        };

        const handle = try graph.createResource(desc);

        return Buffer{
            .handle = handle,
            .desc = desc,
            .size = data.len * @sizeOf(u32),
        };
    }

    /// Create a uniform buffer
    pub fn uniform(graph: *render_graph.RenderGraph, size: usize) !Buffer {
        const desc = render_graph.ResourceDesc{
            .uniform_buffer = .{ .size = size },
        };

        const handle = try graph.createResource(desc);

        return Buffer{
            .handle = handle,
            .desc = desc,
            .size = size,
        };
    }

    /// Update buffer data
    pub fn update(self: *Buffer, data: []const u8) void {
        _ = self;
        _ = data;
        // In full implementation, this would upload data to GPU
    }
};

// ============================================================================
// Shader Resources
// ============================================================================

/// Shader program resource
pub const Shader = struct {
    handle: render_graph.ResourceHandle,
    vertex_source: ?[]const u8,
    fragment_source: ?[]const u8,
    // In full implementation, would contain compiled shader handle

    /// Create a shader from source
    pub fn fromSource(
        graph: *render_graph.RenderGraph,
        vertex_src: ?[]const u8,
        fragment_src: ?[]const u8,
    ) !Shader {
        // In full implementation, would compile shaders
        _ = graph;

        return Shader{
            .handle = render_graph.ResourceHandle.init(0, 0), // Placeholder
            .vertex_source = vertex_src,
            .fragment_source = fragment_src,
        };
    }

    /// Create a shader from files
    pub fn fromFiles(
        graph: *render_graph.RenderGraph,
        vertex_file: []const u8,
        fragment_file: []const u8,
    ) !Shader {
        // Would load shader source from files
        _ = graph;
        _ = vertex_file;
        _ = fragment_file;

        return Shader{
            .handle = render_graph.ResourceHandle.init(0, 0), // Placeholder
            .vertex_source = null,
            .fragment_source = null,
        };
    }
};

// ============================================================================
// Material System
// ============================================================================

/// Material definition for rendering objects
pub const Material = struct {
    name: []const u8,
    shader: Shader,
    textures: std.StringHashMap(Texture),
    uniforms: std.StringHashMap(UniformValue),

    pub const UniformValue = union(enum) {
        float: f32,
        vec2: [2]f32,
        vec3: [3]f32,
        vec4: [4]f32,
        mat4: [16]f32,
        int: i32,
        texture: Texture,
    };

    /// Create a new material
    pub fn init(allocator: std.mem.Allocator, name: []const u8, shader: Shader) !Material {
        return .{
            .name = try allocator.dupe(u8, name),
            .shader = shader,
            .textures = std.StringHashMap(Texture).init(allocator),
            .uniforms = std.StringHashMap(UniformValue).init(allocator),
        };
    }

    pub fn deinit(self: *Material, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        self.textures.deinit();
        self.uniforms.deinit();
    }

    /// Set a texture parameter
    pub fn setTexture(self: *Material, name: []const u8, texture: Texture) !void {
        try self.textures.put(name, texture);
    }

    /// Set a uniform parameter
    pub fn setUniform(self: *Material, name: []const u8, value: UniformValue) !void {
        try self.uniforms.put(name, value);
    }

    /// Get a texture parameter
    pub fn getTexture(self: *const Material, name: []const u8) ?Texture {
        return self.textures.get(name);
    }

    /// Get a uniform parameter
    pub fn getUniform(self: *const Material, name: []const u8) ?UniformValue {
        return self.uniforms.get(name);
    }
};

// ============================================================================
// Mesh Resources
// ============================================================================

/// 3D mesh resource
pub const Mesh = struct {
    name: []const u8,
    vertex_buffer: Buffer,
    index_buffer: ?Buffer,
    vertex_count: u32,
    index_count: u32,

    /// Create a mesh from vertex data
    pub fn init(
        graph: *render_graph.RenderGraph,
        allocator: std.mem.Allocator,
        name: []const u8,
        vertices: []const f32,
        indices: ?[]const u32,
    ) !Mesh {
        const vertex_buf = try Buffer.vertex(graph, vertices);
        const index_buf = if (indices) |idx| try Buffer.index(graph, idx) else null;

        return .{
            .name = try allocator.dupe(u8, name),
            .vertex_buffer = vertex_buf,
            .index_buffer = index_buf,
            .vertex_count = @intCast(vertices.len / 3), // Assuming 3 components per vertex
            .index_count = if (indices) |idx| @intCast(idx.len) else 0,
        };
    }

    pub fn deinit(self: *Mesh, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }

    /// Get the primitive type for rendering
    pub fn getPrimitiveType(self: *const Mesh) enum { triangles, lines, points } {
        if (self.index_buffer != null) {
            return .triangles;
        }
        return .triangles; // Default
    }
};

// ============================================================================
// Pipeline State
// ============================================================================

/// Graphics pipeline state description
pub const PipelineState = struct {
    shader: Shader,
    vertex_layout: VertexLayout,
    primitive_type: enum { triangles, lines, points } = .triangles,
    depth_test: bool = true,
    depth_write: bool = true,
    cull_mode: enum { none, front, back } = .back,
    blend_enabled: bool = false,
    // In full implementation, would include more state

    pub const VertexLayout = struct {
        attributes: []const VertexAttribute,

        pub const VertexAttribute = struct {
            name: []const u8,
            format: enum { float, float2, float3, float4 },
            offset: usize,
        };
    };
};

// ============================================================================
// Resource Cache
// ============================================================================

/// Resource cache for managing loaded assets
pub const ResourceCache = struct {
    allocator: std.mem.Allocator,
    textures: std.StringHashMap(Texture),
    shaders: std.StringHashMap(Shader),
    materials: std.StringHashMap(Material),
    meshes: std.StringHashMap(Mesh),

    pub fn init(allocator: std.mem.Allocator) ResourceCache {
        return .{
            .allocator = allocator,
            .textures = std.StringHashMap(Texture).init(allocator),
            .shaders = std.StringHashMap(Shader).init(allocator),
            .materials = std.StringHashMap(Material).init(allocator),
            .meshes = std.StringHashMap(Mesh).init(allocator),
        };
    }

    pub fn deinit(self: *ResourceCache) void {
        // Clean up resources
        var tex_iter = self.textures.iterator();
        while (tex_iter.next()) |entry| {
            _ = entry; // Would release GPU resources
        }
        self.textures.deinit();

        var shader_iter = self.shaders.iterator();
        while (shader_iter.next()) |entry| {
            _ = entry; // Would release shader resources
        }
        self.shaders.deinit();

        var mat_iter = self.materials.iterator();
        while (mat_iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.materials.deinit();

        var mesh_iter = self.meshes.iterator();
        while (mesh_iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.meshes.deinit();
    }

    /// Load or get a cached texture
    pub fn getTexture(self: *ResourceCache, graph: *render_graph.RenderGraph, path: []const u8) !Texture {
        if (self.textures.get(path)) |texture| {
            return texture;
        }

        const texture = try Texture.fromFile(graph, path, true);
        try self.textures.put(try self.allocator.dupe(u8, path), texture);
        return texture;
    }

    /// Load or get a cached shader
    pub fn getShader(self: *ResourceCache, graph: *render_graph.RenderGraph, vertex_path: []const u8, fragment_path: []const u8) !Shader {
        const key = try std.fmt.allocPrint(self.allocator, "{s}:{s}", .{ vertex_path, fragment_path });
        defer self.allocator.free(key);

        if (self.shaders.get(key)) |shader| {
            return shader;
        }

        const shader = try Shader.fromFiles(graph, vertex_path, fragment_path);
        try self.shaders.put(try self.allocator.dupe(u8, key), shader);
        return shader;
    }

    /// Create or get a cached material
    pub fn getMaterial(self: *ResourceCache, name: []const u8, shader: Shader) !Material {
        if (self.materials.get(name)) |material| {
            return material;
        }

        const material = try Material.init(self.allocator, name, shader);
        try self.materials.put(try self.allocator.dupe(u8, name), material);
        return material;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "texture creation" {
    var graph = render_graph.RenderGraph.init(std.testing.allocator);
    defer graph.deinit();

    const texture = try Texture.renderTarget(&graph, 512, 512, .rgba8);
    const size = texture.getSize();

    try std.testing.expect(size.width == 512);
    try std.testing.expect(size.height == 512);
}

test "buffer creation" {
    var graph = render_graph.RenderGraph.init(std.testing.allocator);
    defer graph.deinit();

    const vertices = [_]f32{ 0, 0, 0, 1, 1, 1 };
    const buffer = try Buffer.vertex(&graph, &vertices);

    try std.testing.expect(buffer.size == vertices.len * @sizeOf(f32));
}

test "material system" {
    var cache = ResourceCache.init(std.testing.allocator);
    defer cache.deinit();

    var graph = render_graph.RenderGraph.init(std.testing.allocator);
    defer graph.deinit();

    // Create a dummy shader
    const shader = try Shader.fromSource(&graph, null, null);

    // Create a material
    var material = try cache.getMaterial("test_material", shader);
    defer material.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.eql(u8, material.name, "test_material"));

    // Set some uniforms
    try material.setUniform("color", .{ .vec3 = [_]f32{ 1, 0, 0 } });
    try material.setUniform("intensity", .{ .float = 2.0 });

    // Check uniforms
    if (material.getUniform("color")) |color| {
        try std.testing.expect(color.vec3[0] == 1);
        try std.testing.expect(color.vec3[1] == 0);
        try std.testing.expect(color.vec3[2] == 0);
    } else {
        try std.testing.expect(false);
    }
}
