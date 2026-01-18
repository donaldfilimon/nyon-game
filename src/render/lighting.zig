//! 3D Lighting and Shading System
//!
//! Implements Blinn-Phong shading with support for multiple light types:
//! - Directional lights (sun, moon)
//! - Point lights (torches, lamps)
//! - Ambient lighting
//!
//! Also includes basic ambient occlusion for block corners.

const std = @import("std");
const math = @import("../math/math.zig");
const Color = @import("color.zig").Color;

/// Directional light (e.g., sun, moon)
/// Light direction should point FROM the light source.
pub const DirectionalLight = struct {
    /// Direction the light travels (normalized)
    direction: math.Vec3,
    /// Light color (RGB, 0-1 range)
    color: math.Vec3,
    /// Light intensity multiplier
    intensity: f32,

    /// Create a directional light
    pub fn init(direction: math.Vec3, color: math.Vec3, intensity: f32) DirectionalLight {
        return .{
            .direction = math.Vec3.normalize(direction),
            .color = color,
            .intensity = intensity,
        };
    }

    /// Create a sun light from angle (radians above horizon)
    pub fn fromSunAngle(angle: f32, color: math.Vec3, intensity: f32) DirectionalLight {
        // Sun direction points down from sky
        const sun_dir = math.Vec3.init(
            0.3, // Slight east offset
            -@sin(@max(angle, 0.05)), // Down from sky (negative Y)
            -@cos(@max(angle, 0.05)), // Forward component
        );
        return init(sun_dir, color, intensity);
    }
};

/// Point light (e.g., torch, lamp)
pub const PointLight = struct {
    /// World position
    position: math.Vec3,
    /// Light color (RGB, 0-1 range)
    color: math.Vec3,
    /// Light intensity at source
    intensity: f32,
    /// Maximum range of light effect
    radius: f32,
    /// Attenuation factors (constant, linear, quadratic)
    attenuation: [3]f32,

    /// Create a point light with default attenuation
    pub fn init(position: math.Vec3, color: math.Vec3, intensity: f32, radius: f32) PointLight {
        return .{
            .position = position,
            .color = color,
            .intensity = intensity,
            .radius = radius,
            // Default attenuation: 1.0, 0.09, 0.032 (good for radius ~50)
            .attenuation = .{ 1.0, 4.5 / radius, 75.0 / (radius * radius) },
        };
    }

    /// Create a point light with custom attenuation
    pub fn initWithAttenuation(
        position: math.Vec3,
        color: math.Vec3,
        intensity: f32,
        radius: f32,
        constant: f32,
        linear: f32,
        quadratic: f32,
    ) PointLight {
        return .{
            .position = position,
            .color = color,
            .intensity = intensity,
            .radius = radius,
            .attenuation = .{ constant, linear, quadratic },
        };
    }

    /// Calculate attenuation factor at a given distance
    pub fn getAttenuation(self: *const PointLight, distance: f32) f32 {
        if (distance >= self.radius) return 0;
        const d = distance;
        const atten = self.attenuation[0] +
            self.attenuation[1] * d +
            self.attenuation[2] * d * d;
        return 1.0 / @max(atten, 0.001);
    }
};

/// Ambient light (global illumination approximation)
pub const AmbientLight = struct {
    /// Ambient color (RGB, 0-1 range)
    color: math.Vec3,
    /// Intensity multiplier
    intensity: f32,

    pub fn init(color: math.Vec3, intensity: f32) AmbientLight {
        return .{
            .color = color,
            .intensity = intensity,
        };
    }

    /// Create ambient light from day/night cycle color
    pub fn fromDayNight(ambient_color: [3]f32) AmbientLight {
        return .{
            .color = math.Vec3.init(ambient_color[0], ambient_color[1], ambient_color[2]),
            .intensity = 1.0,
        };
    }
};

/// Material properties for shading
pub const Material = struct {
    /// Ambient reflectivity (0-1)
    ambient: f32 = 0.3,
    /// Diffuse reflectivity (0-1)
    diffuse: f32 = 0.7,
    /// Specular reflectivity (0-1)
    specular: f32 = 0.2,
    /// Specular shininess exponent
    shininess: f32 = 16.0,

    pub const DEFAULT = Material{};
    pub const MATTE = Material{ .ambient = 0.4, .diffuse = 0.8, .specular = 0.0, .shininess = 1.0 };
    pub const SHINY = Material{ .ambient = 0.2, .diffuse = 0.5, .specular = 0.8, .shininess = 64.0 };
};

/// Maximum lights the system can handle
pub const MAX_DIRECTIONAL_LIGHTS: usize = 4;
pub const MAX_POINT_LIGHTS: usize = 64;

/// Complete lighting system manager
pub const LightingSystem = struct {
    /// Active directional lights
    directional_lights: [MAX_DIRECTIONAL_LIGHTS]DirectionalLight,
    directional_count: usize,

    /// Active point lights
    point_lights: [MAX_POINT_LIGHTS]PointLight,
    point_count: usize,

    /// Global ambient light
    ambient: AmbientLight,

    /// Sun light (managed separately for day/night cycle)
    sun: DirectionalLight,
    sun_enabled: bool,

    /// Camera position for specular calculations
    camera_position: math.Vec3,

    /// Initialize the lighting system
    pub fn init() LightingSystem {
        return .{
            .directional_lights = undefined,
            .directional_count = 0,
            .point_lights = undefined,
            .point_count = 0,
            .ambient = AmbientLight.init(math.Vec3.init(0.2, 0.2, 0.25), 1.0),
            .sun = DirectionalLight.init(
                math.Vec3.init(0.3, -0.8, -0.5),
                math.Vec3.init(1.0, 0.95, 0.8),
                1.0,
            ),
            .sun_enabled = true,
            .camera_position = math.Vec3.ZERO,
        };
    }

    /// Clear all dynamic lights
    pub fn clear(self: *LightingSystem) void {
        self.directional_count = 0;
        self.point_count = 0;
    }

    /// Set camera position for specular calculations
    pub fn setCameraPosition(self: *LightingSystem, pos: math.Vec3) void {
        self.camera_position = pos;
    }

    /// Update sun from day/night cycle
    pub fn updateSunFromDayNight(self: *LightingSystem, sun_angle: f32, ambient_color: [3]f32) void {
        // Sun brightness based on angle
        const sun_intensity = if (sun_angle > 0)
            @min(sun_angle / (std.math.pi / 4.0), 1.0)
        else
            0.0;

        // Sun color: warmer at horizon, whiter at noon
        const sun_color = if (sun_angle > 0 and sun_angle < 0.3)
            math.Vec3.init(1.0, 0.7, 0.4) // Orange at sunrise/sunset
        else
            math.Vec3.init(1.0, 0.98, 0.9); // Slightly warm white

        self.sun = DirectionalLight.fromSunAngle(sun_angle, sun_color, sun_intensity);
        self.sun_enabled = sun_angle > 0;

        // Update ambient from day/night cycle
        self.ambient = AmbientLight.fromDayNight(ambient_color);
    }

    /// Add a directional light
    pub fn addDirectionalLight(self: *LightingSystem, light: DirectionalLight) bool {
        if (self.directional_count >= MAX_DIRECTIONAL_LIGHTS) return false;
        self.directional_lights[self.directional_count] = light;
        self.directional_count += 1;
        return true;
    }

    /// Add a point light
    pub fn addPointLight(self: *LightingSystem, light: PointLight) bool {
        if (self.point_count >= MAX_POINT_LIGHTS) return false;
        self.point_lights[self.point_count] = light;
        self.point_count += 1;
        return true;
    }

    /// Calculate final lighting for a surface using Blinn-Phong shading
    pub fn calculateLighting(
        self: *const LightingSystem,
        surface_pos: math.Vec3,
        surface_normal: math.Vec3,
        surface_color: Color,
        material: Material,
    ) Color {
        const color_f = surface_color.toFloat();
        const base_color = math.Vec3.init(color_f[0], color_f[1], color_f[2]);
        const normal = math.Vec3.normalize(surface_normal);

        // Start with ambient contribution
        var result = math.Vec3.init(
            base_color.x() * self.ambient.color.x() * self.ambient.intensity * material.ambient,
            base_color.y() * self.ambient.color.y() * self.ambient.intensity * material.ambient,
            base_color.z() * self.ambient.color.z() * self.ambient.intensity * material.ambient,
        );

        // View direction for specular (from surface to camera)
        const view_dir = math.Vec3.normalize(math.Vec3.sub(self.camera_position, surface_pos));

        // Add sun contribution
        if (self.sun_enabled and self.sun.intensity > 0) {
            const sun_contrib = self.calculateDirectionalContribution(
                &self.sun,
                normal,
                view_dir,
                base_color,
                material,
            );
            result = math.Vec3.add(result, sun_contrib);
        }

        // Add other directional lights
        for (self.directional_lights[0..self.directional_count]) |*light| {
            const contrib = self.calculateDirectionalContribution(
                light,
                normal,
                view_dir,
                base_color,
                material,
            );
            result = math.Vec3.add(result, contrib);
        }

        // Add point lights
        for (self.point_lights[0..self.point_count]) |*light| {
            const contrib = self.calculatePointContribution(
                light,
                surface_pos,
                normal,
                view_dir,
                base_color,
                material,
            );
            result = math.Vec3.add(result, contrib);
        }

        // Clamp and convert back to Color
        return Color.fromFloat(
            math.clamp(result.x(), 0, 1),
            math.clamp(result.y(), 0, 1),
            math.clamp(result.z(), 0, 1),
            color_f[3],
        );
    }

    /// Calculate contribution from a directional light
    fn calculateDirectionalContribution(
        self: *const LightingSystem,
        light: *const DirectionalLight,
        normal: math.Vec3,
        view_dir: math.Vec3,
        base_color: math.Vec3,
        material: Material,
    ) math.Vec3 {
        _ = self;

        // Light direction (from surface to light, so negate)
        const light_dir = math.Vec3.negate(light.direction);

        // Diffuse (Lambert)
        const n_dot_l = @max(math.Vec3.dot(normal, light_dir), 0.0);
        const diffuse = math.Vec3.init(
            base_color.x() * light.color.x() * n_dot_l * light.intensity * material.diffuse,
            base_color.y() * light.color.y() * n_dot_l * light.intensity * material.diffuse,
            base_color.z() * light.color.z() * n_dot_l * light.intensity * material.diffuse,
        );

        // Specular (Blinn-Phong)
        var specular = math.Vec3.ZERO;
        if (n_dot_l > 0 and material.specular > 0) {
            const half_dir = math.Vec3.normalize(math.Vec3.add(light_dir, view_dir));
            const n_dot_h = @max(math.Vec3.dot(normal, half_dir), 0.0);
            const spec_factor = std.math.pow(f32, n_dot_h, material.shininess) * material.specular;
            specular = math.Vec3.init(
                light.color.x() * spec_factor * light.intensity,
                light.color.y() * spec_factor * light.intensity,
                light.color.z() * spec_factor * light.intensity,
            );
        }

        return math.Vec3.add(diffuse, specular);
    }

    /// Calculate contribution from a point light
    fn calculatePointContribution(
        self: *const LightingSystem,
        light: *const PointLight,
        surface_pos: math.Vec3,
        normal: math.Vec3,
        view_dir: math.Vec3,
        base_color: math.Vec3,
        material: Material,
    ) math.Vec3 {
        _ = self;

        // Vector from surface to light
        const to_light = math.Vec3.sub(light.position, surface_pos);
        const distance = math.Vec3.length(to_light);

        // Early out if beyond radius
        if (distance >= light.radius) return math.Vec3.ZERO;

        const light_dir = math.Vec3.scale(to_light, 1.0 / distance);
        const attenuation = light.getAttenuation(distance);

        // Diffuse (Lambert)
        const n_dot_l = @max(math.Vec3.dot(normal, light_dir), 0.0);
        const diffuse = math.Vec3.init(
            base_color.x() * light.color.x() * n_dot_l * light.intensity * attenuation * material.diffuse,
            base_color.y() * light.color.y() * n_dot_l * light.intensity * attenuation * material.diffuse,
            base_color.z() * light.color.z() * n_dot_l * light.intensity * attenuation * material.diffuse,
        );

        // Specular (Blinn-Phong)
        var specular = math.Vec3.ZERO;
        if (n_dot_l > 0 and material.specular > 0) {
            const half_dir = math.Vec3.normalize(math.Vec3.add(light_dir, view_dir));
            const n_dot_h = @max(math.Vec3.dot(normal, half_dir), 0.0);
            const spec_factor = std.math.pow(f32, n_dot_h, material.shininess) * material.specular * attenuation;
            specular = math.Vec3.init(
                light.color.x() * spec_factor * light.intensity,
                light.color.y() * spec_factor * light.intensity,
                light.color.z() * spec_factor * light.intensity,
            );
        }

        return math.Vec3.add(diffuse, specular);
    }

    /// Calculate ambient occlusion factor for a block corner
    /// Returns a value between 0 (fully occluded) and 1 (no occlusion)
    pub fn calculateAmbientOcclusion(
        side1_solid: bool,
        side2_solid: bool,
        corner_solid: bool,
    ) f32 {
        // AO lookup table based on Minecraft-style voxel AO
        // See: https://0fps.net/2013/07/03/ambient-occlusion-for-minecraft-like-worlds/
        const s1: u8 = if (side1_solid) 1 else 0;
        const s2: u8 = if (side2_solid) 1 else 0;
        const c: u8 = if (corner_solid) 1 else 0;

        // If both sides are solid, corner doesn't matter
        if (s1 == 1 and s2 == 1) {
            return 0.5;
        }

        const total = s1 + s2 + c;
        return switch (total) {
            0 => 1.0, // No occlusion
            1 => 0.85, // Light occlusion
            2 => 0.7, // Medium occlusion
            3 => 0.5, // Heavy occlusion (shouldn't happen due to above check)
            else => 1.0,
        };
    }

    /// Calculate vertex AO for all 4 corners of a face
    /// corner_occluders is [4][3]bool: for each corner, [side1_solid, side2_solid, corner_solid]
    pub fn calculateFaceAO(corner_occluders: [4][3]bool) [4]f32 {
        var ao: [4]f32 = undefined;
        for (0..4) |i| {
            ao[i] = calculateAmbientOcclusion(
                corner_occluders[i][0],
                corner_occluders[i][1],
                corner_occluders[i][2],
            );
        }
        return ao;
    }

    /// Calculate lighting with ambient occlusion applied
    pub fn calculateLightingWithAO(
        self: *const LightingSystem,
        surface_pos: math.Vec3,
        surface_normal: math.Vec3,
        surface_color: Color,
        material: Material,
        ao_factor: f32,
    ) Color {
        // First calculate standard lighting
        var lit_color = self.calculateLighting(surface_pos, surface_normal, surface_color, material);

        // Apply AO as a multiplier
        const color_f = lit_color.toFloat();
        return Color.fromFloat(
            color_f[0] * ao_factor,
            color_f[1] * ao_factor,
            color_f[2] * ao_factor,
            color_f[3],
        );
    }
};

/// Simplified lighting calculation for block faces without full shading
/// More performant for large numbers of blocks
pub fn calculateSimpleLighting(
    face_normal: math.Vec3,
    sun_direction: math.Vec3,
    sun_intensity: f32,
    ambient_intensity: f32,
    base_color: Color,
) Color {
    // Simple directional lighting (N dot L)
    const light_dir = math.Vec3.negate(sun_direction);
    const n_dot_l = @max(math.Vec3.dot(face_normal, light_dir), 0.0);

    // Combine ambient and diffuse
    const total_light = ambient_intensity + n_dot_l * sun_intensity * 0.7;
    const clamped_light = math.clamp(total_light, 0, 1);

    const color_f = base_color.toFloat();
    return Color.fromFloat(
        color_f[0] * clamped_light,
        color_f[1] * clamped_light,
        color_f[2] * clamped_light,
        color_f[3],
    );
}

// ============================================================================
// Face Normal Constants
// ============================================================================

/// Standard face normals for block rendering
pub const FaceNormals = struct {
    pub const TOP = math.Vec3.init(0, 1, 0); // +Y
    pub const BOTTOM = math.Vec3.init(0, -1, 0); // -Y
    pub const NORTH = math.Vec3.init(0, 0, 1); // +Z
    pub const SOUTH = math.Vec3.init(0, 0, -1); // -Z
    pub const EAST = math.Vec3.init(1, 0, 0); // +X
    pub const WEST = math.Vec3.init(-1, 0, 0); // -X

    /// Get normal for face index (matches block_renderer.Face enum order)
    pub fn fromIndex(index: usize) math.Vec3 {
        return switch (index) {
            0 => TOP,
            1 => BOTTOM,
            2 => NORTH,
            3 => SOUTH,
            4 => EAST,
            5 => WEST,
            else => TOP,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "directional light creation" {
    const light = DirectionalLight.init(
        math.Vec3.init(0, -1, 0),
        math.Vec3.init(1, 1, 1),
        1.0,
    );
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), light.direction.y(), 0.001);
}

test "point light attenuation" {
    const light = PointLight.init(
        math.Vec3.ZERO,
        math.Vec3.init(1, 1, 1),
        1.0,
        10.0,
    );

    // At distance 0, attenuation should be ~1
    try std.testing.expect(light.getAttenuation(0) > 0.9);

    // At max radius, attenuation should be 0
    try std.testing.expectApproxEqAbs(@as(f32, 0), light.getAttenuation(10), 0.001);

    // Attenuation decreases with distance
    try std.testing.expect(light.getAttenuation(2) > light.getAttenuation(5));
}

test "ambient occlusion calculation" {
    // No neighbors = full brightness
    try std.testing.expectApproxEqAbs(
        @as(f32, 1.0),
        LightingSystem.calculateAmbientOcclusion(false, false, false),
        0.001,
    );

    // Both sides solid = darkest
    try std.testing.expectApproxEqAbs(
        @as(f32, 0.5),
        LightingSystem.calculateAmbientOcclusion(true, true, false),
        0.001,
    );

    // One neighbor = slight darkening
    try std.testing.expectApproxEqAbs(
        @as(f32, 0.85),
        LightingSystem.calculateAmbientOcclusion(true, false, false),
        0.001,
    );
}

test "lighting system basic" {
    var lighting = LightingSystem.init();
    lighting.setCameraPosition(math.Vec3.init(0, 5, 10));

    const color = lighting.calculateLighting(
        math.Vec3.ZERO,
        math.Vec3.init(0, 1, 0), // Up-facing normal
        Color.WHITE,
        Material.DEFAULT,
    );

    // Should produce a valid color
    try std.testing.expect(color.r > 0);
    try std.testing.expect(color.g > 0);
    try std.testing.expect(color.b > 0);
}

test "sun angle light" {
    // Noon sun (high in sky)
    const noon_sun = DirectionalLight.fromSunAngle(std.math.pi / 2.0, math.Vec3.ONE, 1.0);
    try std.testing.expect(noon_sun.direction.y() < -0.5); // Should point downward

    // Sunrise sun (near horizon)
    const sunrise_sun = DirectionalLight.fromSunAngle(0.1, math.Vec3.ONE, 1.0);
    try std.testing.expect(@abs(sunrise_sun.direction.y()) < @abs(noon_sun.direction.y()));
}

test "face normals" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), FaceNormals.TOP.y(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), FaceNormals.BOTTOM.y(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), FaceNormals.EAST.x(), 0.001);
}
