const std = @import("std");
const engine = @import("engine.zig");
const raylib = @import("raylib");
const config = @import("config/constants.zig");

/// Simple texture wrapper used by materials.
pub const Texture = struct {
    id: u32,
    width: u32,
    height: u32,
};

/// Physically Based Rendering material properties.
pub const PBRProperties = struct {
    albedo: raylib.Color = raylib.Color.white,
    metallic: f32 = 0.0, // 0.0 = dielectric, 1.0 = metallic
    roughness: f32 = 0.5, // 0.0 = smooth, 1.0 = rough
    ao: f32 = 1.0, // ambient occlusion
    emissive: raylib.Color = raylib.Color.black,
};

/// Shader program for materials.
pub const ShaderProgram = struct {
    id: u32,
    vertex_loc: i32,
    fragment_loc: i32,

    /// Load shader from files.
    pub fn load(vertex_path: ?[:0]const u8, fragment_path: ?[:0]const u8) !ShaderProgram {
        const shader = raylib.loadShader(vertex_path, fragment_path) catch return error.ShaderLoadFailed;
        if (shader.id == 0) return error.ShaderLoadFailed;

        return ShaderProgram{
            .id = shader.id,
            .vertex_loc = raylib.getShaderLocation(shader, "vertexPosition"),
            .fragment_loc = raylib.getShaderLocation(shader, "fragmentColor"),
        };
    }

    /// Load default PBR shader.
    pub fn loadDefaultPBR() !ShaderProgram {
        // For now, use raylib's default shader
        // TODO: Implement custom PBR shader
        return ShaderProgram{
            .id = 0, // Use default shader
            .vertex_loc = -1,
            .fragment_loc = -1,
        };
    }

    /// Free shader resources.
    pub fn deinit(self: *ShaderProgram) void {
        if (self.id != 0) {
            raylib.unloadShader(raylib.Shader{ .id = self.id });
        }
    }
};

/// Advanced material representation with PBR support.
/// Supports diffuse/normal/metallic/roughness textures and custom shaders.
pub const Material = struct {
    // Basic textures
    diffuse: ?Texture = null,
    normal: ?Texture = null,
    metallic: ?Texture = null, // R channel = metallic, G channel = roughness
    roughness: ?Texture = null,
    ao: ?Texture = null, // ambient occlusion
    emissive: ?Texture = null,

    // PBR properties (used when textures are null)
    pbr_props: PBRProperties = .{},

    // Shader
    shader: ShaderProgram,

    // Material name for identification
    name: []const u8,

    /// Load a texture from a file. Returns a `Texture` struct.
    pub fn loadTexture(_: *std.mem.Allocator, path: [:0]const u8) !Texture {
        const result = raylib.loadTexture(path) catch return error.TextureLoadFailed;
        if (result.id == 0) return error.TextureLoadFailed;
        return Texture{ .id = result.id, .width = result.width, .height = result.height };
    }

    /// Create a new PBR material with default shader.
    pub fn initPBR(alloc: *std.mem.Allocator, name: []const u8) !Material {
        const shader = try ShaderProgram.loadDefaultPBR();
        const name_copy = try alloc.dupe(u8, name);

        return Material{
            .shader = shader,
            .name = name_copy,
        };
    }

    /// Create a new material with a diffuse texture.
    pub fn initBasic(alloc: *std.mem.Allocator, name: []const u8, diffuse_path: [:0]const u8) !Material {
        const shader = try ShaderProgram.loadDefaultPBR();
        const tex = try loadTexture(alloc, diffuse_path);
        const name_copy = try alloc.dupe(u8, name);

        return Material{
            .diffuse = tex,
            .shader = shader,
            .name = name_copy,
        };
    }

    /// Set PBR properties.
    pub fn setPBRProperties(self: *Material, props: PBRProperties) void {
        self.pbr_props = props;
    }

    /// Load and set diffuse texture.
    pub fn setDiffuseTexture(self: *Material, alloc: *std.mem.Allocator, path: [:0]const u8) !void {
        if (self.diffuse) |old_tex| {
            raylib.unloadTexture(raylib.Texture{ .id = old_tex.id });
        }
        self.diffuse = try loadTexture(alloc, path);
    }

    /// Load and set normal texture.
    pub fn setNormalTexture(self: *Material, alloc: *std.mem.Allocator, path: [:0]const u8) !void {
        if (self.normal) |old_tex| {
            raylib.unloadTexture(raylib.Texture{ .id = old_tex.id });
        }
        self.normal = try loadTexture(alloc, path);
    }

    /// Convert to raylib material for rendering.
    pub fn toRaylibMaterial(self: *const Material) raylib.Material {
        var rl_material = raylib.loadMaterialDefault() catch std.mem.zeroes(raylib.Material);

        // Set shader
        if (self.shader.id != 0) {
            rl_material.shader = raylib.Shader{ .id = self.shader.id };
        }

        // Set textures
        if (self.diffuse) |tex| {
            rl_material.maps[raylib.MATERIAL_MAP_DIFFUSE].texture = raylib.Texture{ .id = tex.id };
        }
        if (self.normal) |tex| {
            rl_material.maps[raylib.MATERIAL_MAP_NORMAL].texture = raylib.Texture{ .id = tex.id };
        }
        if (self.metallic) |tex| {
            rl_material.maps[raylib.MATERIAL_MAP_METALLIC].texture = raylib.Texture{ .id = tex.id };
        }
        if (self.roughness) |tex| {
            rl_material.maps[raylib.MATERIAL_MAP_ROUGHNESS].texture = raylib.Texture{ .id = tex.id };
        }
        if (self.ao) |tex| {
            rl_material.maps[raylib.MATERIAL_MAP_OCCLUSION].texture = raylib.Texture{ .id = tex.id };
        }
        if (self.emissive) |tex| {
            rl_material.maps[raylib.MATERIAL_MAP_EMISSION].texture = raylib.Texture{ .id = tex.id };
        }

        return rl_material;
    }

    /// Free owned resources.
    pub fn deinit(self: *Material, alloc: *std.mem.Allocator) void {
        self.shader.deinit();

        if (self.diffuse) |tex| {
            raylib.unloadTexture(raylib.Texture{ .id = tex.id });
        }
        if (self.normal) |tex| {
            raylib.unloadTexture(raylib.Texture{ .id = tex.id });
        }
        if (self.metallic) |tex| {
            raylib.unloadTexture(raylib.Texture{ .id = tex.id });
        }
        if (self.roughness) |tex| {
            raylib.unloadTexture(raylib.Texture{ .id = tex.id });
        }
        if (self.ao) |tex| {
            raylib.unloadTexture(raylib.Texture{ .id = tex.id });
        }
        if (self.emissive) |tex| {
            raylib.unloadTexture(raylib.Texture{ .id = tex.id });
        }

        alloc.free(self.name);
    }
};

// ============================================================================
// Material Library
// ============================================================================

/// Material library for managing multiple materials.
pub const MaterialLibrary = struct {
    allocator: *std.mem.Allocator,
    materials: std.ArrayList(*Material),

    pub fn init(alloc: *std.mem.Allocator) MaterialLibrary {
        return MaterialLibrary{
            .allocator = alloc,
            .materials = std.ArrayList(*Material).initCapacity(alloc.*, config.Rendering.MAX_MATERIALS) catch unreachable,
        };
    }

    pub fn deinit(self: *MaterialLibrary) void {
        for (self.materials.items) |material| {
            material.deinit(self.allocator);
            self.allocator.destroy(material);
        }
        self.materials.deinit(self.allocator.*);
    }

    /// Create and add a new PBR material.
    pub fn createPBRMaterial(self: *MaterialLibrary, name: []const u8) !*Material {
        const material = try self.allocator.create(Material);
        material.* = try Material.initPBR(self.allocator, name);
        try self.materials.append(self.allocator.*, material);
        return material;
    }

    /// Find material by name.
    pub fn findMaterial(self: *const MaterialLibrary, name: []const u8) ?*Material {
        for (self.materials.items) |material| {
            if (std.mem.eql(u8, material.name, name)) {
                return material;
            }
        }
        return null;
    }
};

test "texture load" {
    const a = std.testing.allocator;
    const t = try Material.loadTexture(a, "assets/small.png");
    defer t;
    std.testing.expect(t.id != 0);
}

test "PBR material creation" {
    const a = std.testing.allocator;
    var mat = try Material.initPBR(a, "test_material");
    defer mat.deinit(a);

    std.testing.expectEqualStrings("test_material", mat.name);
    std.testing.expect(mat.diffuse == null);
    std.testing.expect(mat.pbr_props.metallic == 0.0);
}
