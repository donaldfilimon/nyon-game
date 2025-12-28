const std = @import("std");
const raylib = @import("raylib");

/// Advanced Rendering System with Lighting and Cameras
///
/// Provides high-level rendering features including dynamic lighting,
/// advanced camera controls, and rendering pipelines for the Nyon Game Engine.
/// Now supports Raylib 5.x features like custom shaders and advanced materials.
/// Light types supported by the system
pub const LightType = enum {
    directional,
    point,
    spot,
};

/// High-level light representation
pub const Light = struct {
    id: usize,
    light_type: LightType,
    position: raylib.Vector3,
    target: raylib.Vector3, // For directional and spot lights
    color: raylib.Color,
    intensity: f32,
    range: f32, // For point and spot lights
    inner_angle: f32, // For spot lights
    outer_angle: f32, // For spot lights
    enabled: bool,

    /// Create a directional light
    pub fn createDirectional(position: raylib.Vector3, direction: raylib.Vector3, color: raylib.Color, intensity: f32) Light {
        return .{
            .id = 0,
            .light_type = .directional,
            .position = position,
            .target = raylib.Vector3{
                .x = position.x + direction.x,
                .y = position.y + direction.y,
                .z = position.z + direction.z,
            },
            .color = color,
            .intensity = intensity,
            .range = 0,
            .inner_angle = 0,
            .outer_angle = 0,
            .enabled = true,
        };
    }

    /// Create a point light
    pub fn createPoint(position: raylib.Vector3, color: raylib.Color, intensity: f32, range: f32) Light {
        return .{
            .id = 0,
            .light_type = .point,
            .position = position,
            .target = raylib.Vector3{ .x = 0, .y = 0, .z = 0 },
            .color = color,
            .intensity = intensity,
            .range = range,
            .inner_angle = 0,
            .outer_angle = 0,
            .enabled = true,
        };
    }

    /// Create a spot light
    pub fn createSpot(position: raylib.Vector3, direction: raylib.Vector3, color: raylib.Color, intensity: f32, range: f32, inner_angle: f32, outer_angle: f32) Light {
        return .{
            .id = 0,
            .light_type = .spot,
            .position = position,
            .target = raylib.Vector3{
                .x = position.x + direction.x,
                .y = position.y + direction.y,
                .z = position.z + direction.z,
            },
            .color = color,
            .intensity = intensity,
            .range = range,
            .inner_angle = inner_angle,
            .outer_angle = outer_angle,
            .enabled = true,
        };
    }

    pub fn getDirection(self: Light) raylib.Vector3 {
        switch (self.light_type) {
            .directional, .spot => return raylib.Vector3{
                .x = self.target.x - self.position.x,
                .y = self.target.y - self.position.y,
                .z = self.target.z - self.position.z,
            },
            .point => return raylib.Vector3{ .x = 0, .y = 0, .z = 0 },
        }
    }

    pub fn setDirection(self: *Light, direction: raylib.Vector3) void {
        switch (self.light_type) {
            .directional, .spot => {
                self.target = raylib.Vector3{
                    .x = self.position.x + direction.x,
                    .y = self.position.y + direction.y,
                    .z = self.position.z + direction.z,
                };
            },
            .point => {},
        }
    }
};

/// Custom material with Raylib 5.x advanced features
pub const CustomMaterial = struct {
    base_material: raylib.Material,
    shader: raylib.Shader,
    uniforms: std.StringHashMap(f32),

    pub fn init(allocator: std.mem.Allocator, shader: raylib.Shader) !CustomMaterial {
        var material = try raylib.loadMaterialDefault();
        material.shader = shader;
        return CustomMaterial{
            .base_material = material,
            .shader = shader,
            .uniforms = std.StringHashMap(f32).init(allocator),
        };
    }

    pub fn deinit(self: *CustomMaterial) void {
        raylib.unloadMaterial(self.base_material);
        self.uniforms.deinit();
    }

    pub fn setUniform(self: *CustomMaterial, name: [:0]const u8, value: f32) !void {
        const location = raylib.getShaderLocation(self.shader, name);
        if (location == -1) return error.InvalidUniformName;
        raylib.setShaderValue(self.shader, location, &value, raylib.ShaderUniformDataType.float);
        try self.uniforms.put(name, value);
    }
};

/// PBR Material system with metallic/roughness workflow
pub const PBRMaterialSystem = struct {
    allocator: std.mem.Allocator,
    materials: std.ArrayList(PBRMaterial),

    pub const PBRMaterial = struct {
        base_color: raylib.Color = raylib.Color.white,
        metallic: f32 = 0.0,
        roughness: f32 = 0.5,
        emissive: raylib.Color = raylib.Color.black,
        albedo_texture: ?raylib.Texture = null,
        normal_texture: ?raylib.Texture = null,
        metallic_roughness_texture: ?raylib.Texture = null,
        emissive_texture: ?raylib.Texture = null,
        ao_texture: ?raylib.Texture = null,

        pub fn loadFromFiles(
            allocator: std.mem.Allocator,
            albedo_path: ?[:0]const u8,
            normal_path: ?[:0]const u8,
            metallic_roughness_path: ?[:0]const u8,
            emissive_path: ?[:0]const u8,
            ao_path: ?[:0]const u8,
        ) !PBRMaterial {
            _ = allocator;
            var material = PBRMaterial{};
            if (albedo_path) |p| material.albedo_texture = raylib.loadTexture(p) catch null;
            if (normal_path) |p| material.normal_texture = raylib.loadTexture(p) catch null;
            if (metallic_roughness_path) |p| material.metallic_roughness_texture = raylib.loadTexture(p) catch null;
            if (emissive_path) |p| material.emissive_texture = raylib.loadTexture(p) catch null;
            if (ao_path) |p| material.ao_texture = raylib.loadTexture(p) catch null;
            return material;
        }

        pub fn toRaylibMaterial(self: PBRMaterial) raylib.Material {
            var material = raylib.loadMaterialDefault() catch std.mem.zeroes(raylib.Material);
            if (self.albedo_texture) |tex| material.maps[raylib.MATERIAL_MAP_ALBEDO].texture = tex;
            if (self.normal_texture) |tex| material.maps[raylib.MATERIAL_MAP_NORMAL].texture = tex;
            if (self.metallic_roughness_texture) |tex| material.maps[raylib.MATERIAL_MAP_METALLIC].texture = tex;
            if (self.emissive_texture) |tex| material.maps[raylib.MATERIAL_MAP_EMISSION].texture = tex;
            if (self.ao_texture) |tex| material.maps[raylib.MATERIAL_MAP_ROUGHNESS].texture = tex;
            return material;
        }

        pub fn unload(self: PBRMaterial) void {
            if (self.albedo_texture) |tex| raylib.unloadTexture(tex);
            if (self.normal_texture) |tex| raylib.unloadTexture(tex);
            if (self.metallic_roughness_texture) |tex| raylib.unloadTexture(tex);
            if (self.emissive_texture) |tex| raylib.unloadTexture(tex);
            if (self.ao_texture) |tex| raylib.unloadTexture(tex);
        }
    };

    pub fn init(allocator: std.mem.Allocator) PBRMaterialSystem {
        return PBRMaterialSystem{
            .allocator = allocator,
            .materials = std.ArrayList(PBRMaterial).initCapacity(allocator, 0) catch unreachable,
        };
    }

    pub fn deinit(self: *PBRMaterialSystem) void {
        for (self.materials.items) |mat| mat.unload();
        self.materials.deinit(self.allocator);
    }

    pub fn addMaterial(self: *PBRMaterialSystem, material: PBRMaterial) !usize {
        try self.materials.append(self.allocator, material);
        return self.materials.items.len - 1;
    }
};

/// Advanced camera with smooth controls and features
pub const Camera = struct {
    id: usize,
    name: []const u8,
    camera: raylib.Camera3D,
    target_position: raylib.Vector3,
    target_look_at: raylib.Vector3,
    smooth_speed: f32,
    use_smoothing: bool,

    pub fn create(allocator: std.mem.Allocator, name: []const u8, position: raylib.Vector3, target: raylib.Vector3, fovy: f32) !Camera {
        const name_copy = try allocator.dupe(u8, name);
        return .{
            .id = 0,
            .name = name_copy,
            .camera = .{
                .position = position,
                .target = target,
                .up = .{ .x = 0, .y = 1, .z = 0 },
                .fovy = fovy,
                .projection = .perspective,
            },
            .target_position = position,
            .target_look_at = target,
            .smooth_speed = 5.0,
            .use_smoothing = true,
        };
    }

    pub fn update(self: *Camera, dt: f32) void {
        if (self.use_smoothing) {
            const pos_diff = raylib.Vector3{
                .x = self.target_position.x - self.camera.position.x,
                .y = self.target_position.y - self.camera.position.y,
                .z = self.target_position.z - self.camera.position.z,
            };
            const lerp_factor = 1.0 - std.math.exp(-self.smooth_speed * dt);
            self.camera.position = raylib.Vector3{
                .x = self.camera.position.x + pos_diff.x * lerp_factor,
                .y = self.camera.position.y + pos_diff.y * lerp_factor,
                .z = self.camera.position.z + pos_diff.z * lerp_factor,
            };
            const look_diff = raylib.Vector3{
                .x = self.target_look_at.x - self.camera.target.x,
                .y = self.target_look_at.y - self.camera.target.y,
                .z = self.target_look_at.z - self.camera.target.z,
            };
            self.camera.target = raylib.Vector3{
                .x = self.camera.target.x + look_diff.x * lerp_factor,
                .y = self.camera.target.y + look_diff.y * lerp_factor,
                .z = self.camera.target.z + look_diff.z * lerp_factor,
            };
        }
    }

    pub fn deactivateSmoothing(self: *Camera) void {
        self.camera.position = self.target_position;
        self.camera.target = self.target_look_at;
    }
};

pub const RenderingSystem = struct {
    allocator: std.mem.Allocator,
    lights: std.ArrayList(Light),
    cameras: std.ArrayList(Camera),
    active_camera: ?usize,
    shaders: std.StringHashMap(raylib.Shader),
    custom_materials: std.ArrayList(CustomMaterial),

    pub fn init(allocator: std.mem.Allocator) RenderingSystem {
        return .{
            .allocator = allocator,
            .lights = std.ArrayList(Light).initCapacity(allocator, 0) catch unreachable,
            .cameras = std.ArrayList(Camera).initCapacity(allocator, 0) catch unreachable,
            .active_camera = null,
            .shaders = std.StringHashMap(raylib.Shader).init(allocator),
            .custom_materials = std.ArrayList(CustomMaterial).initCapacity(allocator, 0) catch unreachable,
        };
    }

    pub fn deinit(self: *RenderingSystem) void {
        self.lights.deinit(self.allocator);
        for (self.cameras.items) |*cam| self.allocator.free(cam.name);
        self.cameras.deinit(self.allocator);
        var it = self.shaders.iterator();
        while (it.next()) |entry| {
            raylib.unloadShader(entry.value_ptr.*);
            self.allocator.free(entry.key_ptr.*);
        }
        self.shaders.deinit();
        for (self.custom_materials.items) |*mat| mat.deinit();
        self.custom_materials.deinit(self.allocator);
    }

    pub fn addLight(self: *RenderingSystem, light: Light) !usize {
        var l = light;
        l.id = self.lights.items.len;
        try self.lights.append(self.allocator, l);
        return l.id;
    }

    pub fn addCamera(self: *RenderingSystem, camera: Camera) !usize {
        const id = self.cameras.items.len;
        try self.cameras.append(self.allocator, camera);
        self.cameras.items[id].id = id;
        if (self.active_camera == null) self.active_camera = id;
        return id;
    }

    pub fn setActiveCamera(self: *RenderingSystem, id: usize) void {
        if (id < self.cameras.items.len) {
            self.active_camera = id;
        }
    }

    pub fn getActiveCamera(self: *RenderingSystem) ?*Camera {
        if (self.active_camera) |id| return &self.cameras.items[id];
        return null;
    }

    pub fn update(self: *RenderingSystem, dt: f32) void {
        for (self.cameras.items) |*cam| cam.update(dt);
    }

    pub fn beginRender(self: *RenderingSystem) void {
        if (self.getActiveCamera()) |cam| raylib.beginMode3D(cam.camera);
    }

    pub fn endRender(self: *RenderingSystem) void {
        _ = self;
        raylib.endMode3D();
    }

    pub fn loadShader(self: *RenderingSystem, name: []const u8, vs_path: ?[:0]const u8, fs_path: ?[:0]const u8) !void {
        const shader = try raylib.loadShader(vs_path, fs_path);
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);
        try self.shaders.put(name_copy, shader);
    }

    pub fn getShader(self: *const RenderingSystem, name: []const u8) ?raylib.Shader {
        return self.shaders.get(name);
    }

    pub fn createCustomMaterial(self: *RenderingSystem, shader_name: []const u8) !usize {
        const shader = self.getShader(shader_name) orelse return error.ShaderNotFound;
        const material = try CustomMaterial.init(self.allocator, shader);
        const index = self.custom_materials.items.len;
        try self.custom_materials.append(self.allocator, material);
        return index;
    }

    pub fn getCustomMaterial(self: *RenderingSystem, index: usize) ?*CustomMaterial {
        if (index < self.custom_materials.items.len) return &self.custom_materials.items[index];
        return null;
    }
};

/// Temporary frame data buffer using FixedBufferAllocator for shader uniforms
/// Optimized for performance-critical rendering operations
pub const FrameDataBuffer = struct {
    const UNIFORM_BUFFER_SIZE = 4096;

    buffer: [UNIFORM_BUFFER_SIZE]u8,
    fba: std.heap.FixedBufferAllocator,

    pub fn init() FrameDataBuffer {
        var buf: [UNIFORM_BUFFER_SIZE]u8 = undefined;
        return .{
            .buffer = buf,
            .fba = std.heap.FixedBufferAllocator.init(&buf),
        };
    }

    pub fn allocator(self: *FrameDataBuffer) std.mem.Allocator {
        return self.fba.allocator();
    }

    pub fn reset(self: *FrameDataBuffer) void {
        self.fba.reset();
    }

    /// Helper to create temporary uniform data
    pub fn allocUniform(self: *FrameDataBuffer, comptime T: type, value: T) !*const T {
        const ptr = try self.allocator().create(T);
        ptr.* = value;
        return ptr;
    }
};
