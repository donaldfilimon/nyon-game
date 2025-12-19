const std = @import("std");
const raylib = @import("raylib");

/// Advanced Rendering System with Lighting and Cameras
///
/// Provides high-level rendering features including dynamic lighting,
/// advanced camera controls, and rendering pipelines for the Nyon Game Engine.
pub const RenderingSystem = struct {
    allocator: std.mem.Allocator,
    lights: std.ArrayList(Light),
    cameras: std.ArrayList(Camera),
    active_camera: ?usize,

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
            const forward = raylib.vector3Normalize(raylib.vector3Subtract(self.target_look_at, self.target_position));
            const right = raylib.vector3Normalize(raylib.vector3CrossProduct(forward, self.camera.up));

            const pan_vector = raylib.vector3Add(
                raylib.vector3Scale(right, -delta.x * distance),
                raylib.vector3Scale(self.camera.up, delta.y * distance),
            );

            self.target_position = raylib.vector3Add(self.target_position, pan_vector);
            self.target_look_at = raylib.vector3Add(self.target_look_at, pan_vector);
        }

        /// Zoom camera
        pub fn zoom(self: *Camera, factor: f32) void {
            const forward = raylib.vector3Normalize(raylib.vector3Subtract(self.target_look_at, self.target_position));
            const zoom_vector = raylib.vector3Scale(forward, factor);

            self.target_position = raylib.vector3Add(self.target_position, zoom_vector);
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
                    const normalized_dir = raylib.vector3Normalize(direction);
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
                    const normalized_dir = raylib.vector3Normalize(direction);
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
};
