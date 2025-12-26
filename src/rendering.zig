const std = @import("std");
const raylib = @import("raylib");

/// Advanced Rendering System with Lighting and Cameras
///
/// Provides high-level rendering features including dynamic lighting,
/// advanced camera controls, and rendering pipelines for the Nyon Game Engine.
/// Now supports Raylib 5.x features like custom shaders and advanced materials.
pub const RenderingSystem = struct {
    allocator: std.mem.Allocator,
    lights: std.ArrayList(Light),
    cameras: std.ArrayList(Camera),
    active_camera: ?usize,
    shaders: std.StringHashMap(raylib.Shader), // Raylib 5.x shader management
    custom_materials: std.ArrayList(CustomMaterial), // Advanced materials

    /// Light types supported by the system
    pub const LightType = enum {
        directional,
        point,
        spot,
    };

    /// Custom material with Raylib 5.x advanced features
    pub const CustomMaterial = struct {
        base_material: raylib.Material,
        shader: raylib.Shader,
        uniforms: std.StringHashMap(f32), // Custom uniform values

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

        /// Set a uniform value (Raylib 5.x enhanced shader support)
        pub fn setUniform(self: *CustomMaterial, name: [:0]const u8, value: f32) !void {
            const location = raylib.getShaderLocation(self.shader, name);
            if (location == -1) return error.InvalidUniformName;

            raylib.setShaderValue(self.shader, location, &value, raylib.ShaderUniformDataType.float);
            try self.uniforms.put(name, value);
        }

        /// Get uniform value
        pub fn getUniform(self: *const CustomMaterial, name: []const u8) ?f32 {
            return self.uniforms.get(name);
        }
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

        /// GPU Instancing renderer for efficient rendering of many similar objects
        pub const InstancingRenderer = struct {
            allocator: std.mem.Allocator,
            mesh: raylib.Mesh,
            material: raylib.Material,
            instances: std.ArrayList(InstanceData),
            max_instances: usize = 1000,

            pub const InstanceData = struct {
                transform: raylib.Matrix,
                color: raylib.Color,
                padding: [12]u8 = [_]u8{0} ** 12, // Ensure 16-byte alignment
            };

            pub fn init(allocator: std.mem.Allocator, mesh: raylib.Mesh, material: raylib.Material) !InstancingRenderer {
                return InstancingRenderer{
                    .allocator = allocator,
                    .mesh = mesh,
                    .material = material,
                    .instances = std.ArrayList(InstanceData).initCapacity(allocator, 100) catch return error.OutOfMemory,
                };
            }

            pub fn deinit(self: *InstancingRenderer) void {
                self.instances.deinit();
            }

            pub fn addInstance(self: *InstancingRenderer, transform: raylib.Matrix, color: raylib.Color) !void {
                if (self.instances.items.len >= self.max_instances) {
                    return error.TooManyInstances;
                }

                const instance = InstanceData{
                    .transform = transform,
                    .color = color,
                };

                self.instances.append(instance) catch return error.OutOfMemory;
            }

            pub fn clearInstances(self: *InstancingRenderer) void {
                self.instances.clearRetainingCapacity();
            }

            pub fn render(self: *InstancingRenderer) void {
                if (self.instances.items.len == 0) return;

                // For now, render each instance individually
                // TODO: Implement true GPU instancing with custom shaders
                for (self.instances.items) |instance| {
                    raylib.beginMode3D(raylib.Camera3D{
                        .position = raylib.Vector3{ .x = 0, .y = 5, .z = 10 },
                        .target = raylib.Vector3{ .x = 0, .y = 0, .z = 0 },
                        .up = raylib.Vector3{ .x = 0, .y = 1, .z = 0 },
                        .fovy = 45.0,
                        .projection = .perspective,
                    });
                    defer raylib.endMode3D();

                    // Apply transform
                    raylib.rlPushMatrix();
                    raylib.rlMultMatrixf(@ptrCast(&instance.transform));

                    // Draw mesh with material
                    raylib.drawMesh(self.mesh, self.material, raylib.Matrix.identity());

                    raylib.rlPopMatrix();
                }
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
                    _ = allocator; // Currently not used for allocations in this context
                    var material = PBRMaterial{};

                    if (albedo_path) |path| {
                        material.albedo_texture = try raylib.loadTexture(path);
                    }

                    if (normal_path) |path| {
                        material.normal_texture = try raylib.loadTexture(path);
                    }

                    if (metallic_roughness_path) |path| {
                        material.metallic_roughness_texture = try raylib.loadTexture(path);
                    }

                    if (emissive_path) |path| {
                        material.emissive_texture = try raylib.loadTexture(path);
                    }

                    if (ao_path) |path| {
                        material.ao_texture = try raylib.loadTexture(path);
                    }

                    return material;
                }

                pub fn toRaylibMaterial(self: PBRMaterial) raylib.Material {
                    var material = raylib.loadMaterialDefault() catch std.mem.zeroes(raylib.Material);

                    // Set PBR properties
                    if (self.albedo_texture) |tex| {
                        material.maps[raylib.MATERIAL_MAP_ALBEDO].texture = tex;
                    }

                    if (self.normal_texture) |tex| {
                        material.maps[raylib.MATERIAL_MAP_NORMAL].texture = tex;
                    }

                    if (self.metallic_roughness_texture) |tex| {
                        material.maps[raylib.MATERIAL_MAP_METALLIC].texture = tex;
                    }

                    if (self.emissive_texture) |tex| {
                        material.maps[raylib.MATERIAL_MAP_EMISSION].texture = tex;
                    }

                    if (self.ao_texture) |tex| {
                        // Raylib doesn't have a dedicated AO map, use ROUGHNESS
                        material.maps[raylib.MATERIAL_MAP_ROUGHNESS].texture = tex;
                    }

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
                    .materials = std.ArrayList(PBRMaterial).init(allocator),
                };
            }

            pub fn deinit(self: *PBRMaterialSystem) void {
                for (self.materials.items) |material| {
                    material.unload();
                }
                self.materials.deinit();
            }

            pub fn createMaterial(self: *PBRMaterialSystem, material: PBRMaterial) !usize {
                try self.materials.append(material);
                return self.materials.items.len - 1;
            }

            pub fn getMaterial(self: *PBRMaterialSystem, index: usize) ?PBRMaterial {
                if (index >= self.materials.items.len) return null;
                return self.materials.items[index];
            }
        };

        /// Create a directional light
        pub fn createDirectional(position: raylib.Vector3, direction: raylib.Vector3, color: raylib.Color, intensity: f32) Light {
            return .{
                .id = 0, // Set by system
                .light_type = .directional,
                .position = position,
                .target = raylib.Vector3{
                    .x = position.x + direction.x,
                    .y = position.y + direction.y,
                    .z = position.z + direction.z,
                },
                .color = color,
                .intensity = intensity,
                .range = 0, // Not used for directional
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
                .target = position, // Not used for point
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

        /// Get the direction of this light
        pub fn getDirection(self: *const Light) raylib.Vector3 {
            switch (self.light_type) {
                .directional, .spot => {
                    return raylib.Vector3{
                        .x = self.target.x - self.position.x,
                        .y = self.target.y - self.position.y,
                        .z = self.target.z - self.position.z,
                    };
                },
                .point => return raylib.Vector3{ .x = 0, .y = 0, .z = 0 }, // Point lights don't have direction
            }
        }

        /// Set the direction of this light (for directional and spot lights)
        pub fn setDirection(self: *Light, direction: raylib.Vector3) void {
            switch (self.light_type) {
                .directional, .spot => {
                    self.target = raylib.Vector3{
                        .x = self.position.x + direction.x,
                        .y = self.position.y + direction.y,
                        .z = self.position.z + direction.z,
                    };
                },
                .point => {}, // Point lights don't use direction
            }
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

        /// Create a new camera
        pub fn create(allocator: std.mem.Allocator, name: []const u8, position: raylib.Vector3, target: raylib.Vector3, fovy: f32) !Camera {
            const name_copy = try allocator.dupe(u8, name);

            return .{
                .id = 0, // Set by system
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

        /// Update camera smoothing
        pub fn update(self: *Camera, dt: f32) void {
            if (self.use_smoothing) {
                // Smooth position interpolation
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

                // Smooth look-at interpolation
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
            } else {
                // Instant update
                self.camera.position = self.target_position;
                self.camera.target = self.target_look_at;
            }
        }

        /// Set target position (with optional smoothing)
        pub fn setPosition(self: *Camera, position: raylib.Vector3) void {
            self.target_position = position;
        }

        /// Set target look-at point (with optional smoothing)
        pub fn setLookAt(self: *Camera, target: raylib.Vector3) void {
            self.target_look_at = target;
        }

        /// Orbit camera around a point
        pub fn orbit(self: *Camera, center: raylib.Vector3, distance: f32, yaw: f32, pitch: f32) void {
            const pitch_clamped = std.math.clamp(pitch, -std.math.pi / 2.1, std.math.pi / 2.1);

            self.target_position = raylib.Vector3{
                .x = center.x + distance * @cos(yaw) * @cos(pitch_clamped),
                .y = center.y + distance * @sin(pitch_clamped),
                .z = center.z + distance * @sin(yaw) * @cos(pitch_clamped),
            };

            self.target_look_at = center;
        }

        /// Pan camera
        pub fn pan(self: *Camera, delta: raylib.Vector2, distance: f32) void {
            const forward = self.target_look_at.subtract(self.target_position).normalize();
            const right = forward.crossProduct(self.camera.up).normalize();

            const pan_vector = right.scale(-delta.x * distance).add(self.camera.up.scale(delta.y * distance));

            self.target_position = self.target_position.add(pan_vector);
            self.target_look_at = self.target_look_at.add(pan_vector);
        }

        /// Zoom camera
        pub fn zoom(self: *Camera, factor: f32) void {
            const forward = self.target_look_at.subtract(self.target_position).normalize();
            const zoom_vector = forward.scale(factor);

            self.target_position = self.target_position.add(zoom_vector);
        }

        pub fn deinit(self: *Camera, allocator: std.mem.Allocator) void {
            allocator.free(self.name);
        }
    };

    /// Initialize the rendering system
    pub fn init(allocator: std.mem.Allocator) RenderingSystem {
        return .{
            .allocator = allocator,
            .lights = std.ArrayList(Light).init(allocator),
            .cameras = std.ArrayList(Camera).init(allocator),
            .active_camera = null,
            .shaders = std.StringHashMap(raylib.Shader).init(allocator),
            .custom_materials = std.ArrayList(CustomMaterial).init(allocator),
        };
    }

    /// Deinitialize the rendering system
    pub fn deinit(self: *RenderingSystem) void {
        for (self.lights.items) |_| {
            // Lights don't need cleanup
        }
        self.lights.deinit();

        for (self.cameras.items) |*camera| {
            camera.deinit(self.allocator);
        }
        self.cameras.deinit();

        // Clean up Raylib 5.x features
        var shader_iter = self.shaders.iterator();
        while (shader_iter.next()) |entry| {
            raylib.unloadShader(entry.value_ptr.*);
        }
        self.shaders.deinit();

        for (self.custom_materials.items) |*material| {
            material.deinit();
        }
        self.custom_materials.deinit();
    }

    /// Add a light to the system
    pub fn addLight(self: *RenderingSystem, light: Light) !usize {
        var light_copy = light;
        light_copy.id = self.lights.items.len;

        try self.lights.append(light_copy);
        return light_copy.id;
    }

    /// Add a camera to the system
    pub fn addCamera(self: *RenderingSystem, camera: Camera) !usize {
        var camera_copy = camera;
        camera_copy.id = self.cameras.items.len;

        try self.cameras.append(camera_copy);
        return camera_copy.id;
    }

    /// Set the active camera
    pub fn setActiveCamera(self: *RenderingSystem, camera_id: usize) void {
        if (camera_id < self.cameras.items.len) {
            self.active_camera = camera_id;
        }
    }

    /// Get the active camera
    pub fn getActiveCamera(self: *const RenderingSystem) ?*Camera {
        if (self.active_camera) |id| {
            if (id < self.cameras.items.len) {
                return &self.cameras.items[id];
            }
        }
        return null;
    }

    /// Get a camera by ID
    pub fn getCamera(self: *RenderingSystem, id: usize) ?*Camera {
        if (id < self.cameras.items.len) {
            return &self.cameras.items[id];
        }
        return null;
    }

    /// Get a light by ID
    pub fn getLight(self: *RenderingSystem, id: usize) ?*Light {
        if (id < self.lights.items.len) {
            return &self.lights.items[id];
        }
        return null;
    }

    /// Update all cameras
    pub fn updateCameras(self: *RenderingSystem, dt: f32) void {
        for (self.cameras.items) |*camera| {
            camera.update(dt);
        }
    }

    /// Begin rendering with the active camera
    pub fn beginRendering(self: *const RenderingSystem) void {
        if (self.getActiveCamera()) |camera| {
            raylib.beginMode3D(camera.camera);
        }
    }

    /// End rendering
    pub fn endRendering(self: *const RenderingSystem) void {
        _ = self; // unused
        raylib.endMode3D();
    }

    /// Render all lights (for debugging/visualization)
    pub fn renderLights(self: *const RenderingSystem) void {
        for (self.lights.items) |light| {
            if (!light.enabled) continue;

            switch (light.light_type) {
                .directional => {
                    // Draw directional light indicator (arrow from position to target)
                    raylib.drawLine3D(light.position, light.target, light.color);
                    // Draw arrow head
                    const direction = light.getDirection();
                    const normalized_dir = direction.normalize();
                    const arrow_pos = raylib.Vector3{
                        .x = light.target.x - normalized_dir.x * 0.5,
                        .y = light.target.y - normalized_dir.y * 0.5,
                        .z = light.target.z - normalized_dir.z * 0.5,
                    };
                    raylib.drawCone(arrow_pos, 0.2, 0.4, 8, light.color);
                },
                .point => {
                    // Draw point light as a sphere
                    raylib.drawSphere(light.position, 0.2, light.color);
                    // Draw range indicator
                    raylib.drawSphereWires(light.position, light.range, 8, 6, raylib.Color{ .r = light.color.r, .g = light.color.g, .b = light.color.b, .a = 100 });
                },
                .spot => {
                    // Draw spot light as a cone
                    const direction = light.getDirection();
                    const normalized_dir = direction.normalize();
                    const cone_pos = raylib.Vector3{
                        .x = light.position.x + normalized_dir.x * light.range,
                        .y = light.position.y + normalized_dir.y * light.range,
                        .z = light.position.z + normalized_dir.z * light.range,
                    };
                    raylib.drawCone(cone_pos, light.range * @tan(light.outer_angle), light.range, 8, light.color);
                },
            }
        }
    }

    /// Get light count
    pub fn lightCount(self: *const RenderingSystem) usize {
        return self.lights.items.len;
    }

    /// Get camera count
    pub fn cameraCount(self: *const RenderingSystem) usize {
        return self.cameras.items.len;
    }

    /// Load and cache a shader (Raylib 5.x feature)
    pub fn loadShader(self: *RenderingSystem, name: []const u8, vs_path: ?[:0]const u8, fs_path: ?[:0]const u8) !void {
        const shader = try raylib.loadShader(vs_path, fs_path);
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);

        try self.shaders.put(name_copy, shader);
    }

    /// Get a cached shader
    pub fn getShader(self: *const RenderingSystem, name: []const u8) ?raylib.Shader {
        return self.shaders.get(name);
    }

    /// Create a custom material with shader (Raylib 5.x feature)
    pub fn createCustomMaterial(self: *RenderingSystem, shader_name: []const u8) !usize {
        const shader = self.getShader(shader_name) orelse return error.ShaderNotFound;
        const material = try CustomMaterial.init(self.allocator, shader);

        const index = self.custom_materials.items.len;
        try self.custom_materials.append(material);
        return index;
    }

    /// Get a custom material by index
    pub fn getCustomMaterial(self: *RenderingSystem, index: usize) ?*CustomMaterial {
        if (index < self.custom_materials.items.len) {
            return &self.custom_materials.items[index];
        }
        return null;
    }

    /// Render with custom material (Raylib 5.x enhanced rendering)
    pub fn renderWithCustomMaterial(self: *const RenderingSystem, model: raylib.Model, material_index: usize, position: raylib.Vector3, scale: f32, tint: raylib.Color) void {
        if (self.getCustomMaterial(material_index)) |_| {
            raylib.drawModelEx(model, position, .{ .x = 0, .y = 1, .z = 0 }, 0, .{ .x = scale, .y = scale, .z = scale }, tint);
        }
    }
};
