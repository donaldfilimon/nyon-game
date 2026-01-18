//! Software Renderer with GPU Compute Acceleration

const std = @import("std");
const math = @import("../math/math.zig");
const gpu = @import("../gpu/gpu.zig");
const ecs = @import("../ecs/ecs.zig");
const window = @import("../platform/window.zig");

pub const Color = @import("color.zig").Color;
pub const Texture = @import("texture.zig").Texture;
pub const Mesh = @import("mesh.zig").Mesh;
pub const Skybox = @import("skybox.zig").Skybox;
pub const lighting = @import("lighting.zig");
pub const LightingSystem = lighting.LightingSystem;
pub const water = @import("water.zig");
pub const Water = water.Water;
pub const WaterRenderer = water.WaterRenderer;
pub const UnderwaterEffects = water.UnderwaterEffects;
pub const particles = @import("particles.zig");
pub const ParticleSystem = particles.ParticleSystem;
pub const Particle = particles.Particle;
pub const ParticlePreset = particles.ParticlePreset;
pub const ParticleEmitter = particles.ParticleEmitter;
pub const culling = @import("culling.zig");
pub const Frustum = culling.Frustum;
pub const Plane = culling.Plane;
pub const FrustumPlane = culling.FrustumPlane;
pub const IntersectionResult = culling.IntersectionResult;
pub const CullingStats = culling.CullingStats;

/// Main renderer
pub const Renderer = struct {
    allocator: std.mem.Allocator,
    gpu_ctx: ?gpu.Context,
    width: u32,
    height: u32,
    framebuffer: []Color,
    depth_buffer: []f32,
    bgra_buffer: []u32,
    window_handle: ?window.Handle,
    view_matrix: math.Mat4,
    projection_matrix: math.Mat4,
    meshes: std.ArrayListUnmanaged(Mesh),
    textures: std.ArrayListUnmanaged(Texture),
    skybox: Skybox,
    lighting_system: LightingSystem,
    particle_system: ParticleSystem,

    pub fn init(
        allocator: std.mem.Allocator,
        gpu_ctx: ?gpu.Context,
        width: u32,
        height: u32,
    ) !Renderer {
        const pixel_count = width * height;
        const framebuffer = try allocator.alloc(Color, pixel_count);
        @memset(framebuffer, Color.BLACK);

        const depth_buffer = try allocator.alloc(f32, pixel_count);
        @memset(depth_buffer, 1.0);

        const bgra_buffer = try allocator.alloc(u32, pixel_count);
        @memset(bgra_buffer, 0);

        return Renderer{
            .allocator = allocator,
            .gpu_ctx = gpu_ctx,
            .width = width,
            .height = height,
            .framebuffer = framebuffer,
            .depth_buffer = depth_buffer,
            .bgra_buffer = bgra_buffer,
            .window_handle = null,
            .view_matrix = math.Mat4.IDENTITY,
            .projection_matrix = math.Mat4.perspective(
                math.radians(60.0),
                @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height)),
                0.1,
                1000.0,
            ),
            .meshes = .{},
            .textures = .{},
            .skybox = Skybox.init(42), // Fixed seed for consistent star/cloud patterns
            .lighting_system = LightingSystem.init(),
            .particle_system = ParticleSystem.initWithSeed(42),
        };
    }

    pub fn deinit(self: *Renderer) void {
        self.allocator.free(self.framebuffer);
        self.allocator.free(self.depth_buffer);
        self.allocator.free(self.bgra_buffer);
        for (self.meshes.items) |*mesh| mesh.deinit();
        self.meshes.deinit(self.allocator);
        for (self.textures.items) |*tex| tex.deinit();
        self.textures.deinit(self.allocator);
    }

    /// Set the window handle for framebuffer presentation
    pub fn setWindowHandle(self: *Renderer, handle: ?window.Handle) void {
        self.window_handle = handle;
    }

    pub fn beginFrame(self: *Renderer) void {
        self.clear(Color.fromRgb(30, 30, 40));
    }

    pub fn endFrame(self: *Renderer) void {
        // Convert RGBA framebuffer to BGRA format for Windows GDI
        for (self.framebuffer, 0..) |color, i| {
            self.bgra_buffer[i] = color.toBgra();
        }

        // Present framebuffer to window
        if (self.window_handle) |handle| {
            const pixels = std.mem.sliceAsBytes(self.bgra_buffer);
            window.presentFramebuffer(handle, pixels, self.width, self.height);
        }
    }

    pub fn clear(self: *Renderer, color: Color) void {
        @memset(self.framebuffer, color);
        @memset(self.depth_buffer, 1.0);
    }

    /// Update skybox animation (cloud drift, star twinkle)
    pub fn updateSkybox(self: *Renderer, dt: f32) void {
        self.skybox.update(dt);
    }

    /// Render skybox background (call before rendering world geometry)
    /// time_of_day: 0.0 = midnight, 0.5 = noon, 1.0 = midnight
    pub fn renderSkybox(self: *Renderer, time_of_day: f32) void {
        self.skybox.renderBackground(self.framebuffer, self.width, self.height, time_of_day);
        // Reset depth buffer since skybox is infinitely far
        @memset(self.depth_buffer, 1.0);
    }

    /// Begin frame with skybox rendering
    pub fn beginFrameWithSky(self: *Renderer, time_of_day: f32) void {
        self.renderSkybox(time_of_day);
    }

    /// Apply underwater visual effects to the entire framebuffer
    /// Call this after all rendering but before endFrame when camera is underwater
    pub fn applyUnderwaterEffect(self: *Renderer, effects: *const UnderwaterEffects) void {
        for (self.framebuffer, 0..) |*pixel, i| {
            // Calculate approximate distance from center for vignette/distortion
            const px = i % self.width;
            const py = i / self.width;
            const nx = @as(f32, @floatFromInt(px)) / @as(f32, @floatFromInt(self.width));
            const ny = @as(f32, @floatFromInt(py)) / @as(f32, @floatFromInt(self.height));

            // Apply distortion (sample from slightly offset position)
            const distortion = effects.getDistortion(nx, ny);
            _ = distortion; // For now, skip actual distortion (would require extra buffer)

            // Apply tint and fog based on depth
            const depth_estimate = self.depth_buffer[i];
            const distance = if (depth_estimate < 1.0) depth_estimate * 20.0 else 100.0;

            pixel.* = effects.applyEffect(pixel.*, distance);
        }
    }

    /// Apply a simple blue tint overlay (lighter weight than full underwater effect)
    pub fn applyScreenTint(self: *Renderer, tint: Color, intensity: f32) void {
        const clamped = std.math.clamp(intensity, 0.0, 1.0);
        for (self.framebuffer) |*pixel| {
            pixel.* = Color.lerp(pixel.*, tint, clamped);
        }
    }

    pub fn setCamera(self: *Renderer, view: math.Mat4, projection: math.Mat4) void {
        self.view_matrix = view;
        self.projection_matrix = projection;
    }

    /// Update the lighting system from day/night cycle parameters
    pub fn updateLighting(self: *Renderer, sun_angle: f32, ambient_color: [3]f32, camera_pos: math.Vec3) void {
        self.lighting_system.updateSunFromDayNight(sun_angle, ambient_color);
        self.lighting_system.setCameraPosition(camera_pos);
    }

    /// Get the lighting system for advanced configuration
    pub fn getLightingSystem(self: *Renderer) *LightingSystem {
        return &self.lighting_system;
    }

    pub fn renderWorld(self: *Renderer, world: *ecs.World) void {
        // Find active camera
        var active_camera: ?*ecs.Camera = null;
        var camera_transform: math.Mat4 = math.Mat4.IDENTITY;

        var camera_query = ecs.Query(&[_]type{ ecs.Camera, ecs.Transform }).init(world);
        var camera_iter = camera_query.iter();
        while (camera_iter.next()) |res| {
            var res_copy = res;
            const cam = res_copy.get(ecs.Camera);
            if (cam.is_active) {
                active_camera = cam;
                camera_transform = res_copy.get(ecs.Transform).matrix();
                break;
            }
        }

        if (active_camera) |cam| {
            const pos_vec = camera_transform.cols[3];
            const fwd_vec = camera_transform.cols[2];

            const eye = math.Vec3{ .data = pos_vec };
            const back = math.Vec3{ .data = fwd_vec };
            const cam_forward = back.negate();

            const target = eye.add(cam_forward);

            self.view_matrix = math.Mat4.lookAt(
                eye,
                target,
                math.Vec3.UP,
            );
            self.projection_matrix = cam.projectionMatrix(@as(f32, @floatFromInt(self.width)) / @as(f32, @floatFromInt(self.height)));
        }

        // Render all renderables
        var render_query = ecs.Query(&[_]type{ ecs.Renderable, ecs.Transform }).init(world);
        var render_iter = render_query.iter();
        while (render_iter.next()) |res| {
            var res_copy = res;
            _ = res_copy.get(ecs.Renderable);
            const transform = res_copy.get(ecs.Transform);

            // Basic visualization: draw mesh vertices as points or wireframe (stub)
            // For now, let's just draw a wireframe cube if it's the default mesh
            self.drawWireframeCube(transform.matrix(), Color.WHITE);
        }
    }

    pub fn drawWireframeCube(self: *Renderer, model: math.Mat4, color: Color) void {
        const mvp = math.Mat4.mul(math.Mat4.mul(self.projection_matrix, self.view_matrix), model);

        const corners = [_]math.Vec3{
            .{ .data = .{ -0.5, -0.5, -0.5, 0 } }, .{ .data = .{ 0.5, -0.5, -0.5, 0 } },
            .{ .data = .{ 0.5, 0.5, -0.5, 0 } },   .{ .data = .{ -0.5, 0.5, -0.5, 0 } },
            .{ .data = .{ -0.5, -0.5, 0.5, 0 } },  .{ .data = .{ 0.5, -0.5, 0.5, 0 } },
            .{ .data = .{ 0.5, 0.5, 0.5, 0 } },    .{ .data = .{ -0.5, 0.5, 0.5, 0 } },
        };

        var projected = [_]math.Vec4{undefined} ** 8;
        for (corners, 0..) |c, i| {
            projected[i] = self.projectToScreen(math.Mat4.mulVec4(mvp, math.Vec4.fromVec3(c, 1.0)));
        }

        const indices = [_][2]u8{
            .{ 0, 1 }, .{ 1, 2 }, .{ 2, 3 }, .{ 3, 0 }, // Back
            .{ 4, 5 }, .{ 5, 6 }, .{ 6, 7 }, .{ 7, 4 }, // Front
            .{ 0, 4 }, .{ 1, 5 }, .{ 2, 6 }, .{ 3, 7 }, // Connections
        };

        for (indices) |edge| {
            const p1 = projected[edge[0]];
            const p2 = projected[edge[1]];
            // Simple clipping: only draw if both points are in front of near plane
            if (p1.w() > 0 and p2.w() > 0) {
                self.drawLine(@intFromFloat(p1.x()), @intFromFloat(p1.y()), @intFromFloat(p2.x()), @intFromFloat(p2.y()), color);
            }
        }
    }

    pub fn drawPixel(self: *Renderer, x: i32, y: i32, z: f32, color: Color) void {
        if (x < 0 or y < 0) return;
        const ux: u32 = @intCast(x);
        const uy: u32 = @intCast(y);
        if (ux >= self.width or uy >= self.height) return;

        const idx = uy * self.width + ux;
        if (z < self.depth_buffer[idx]) {
            self.depth_buffer[idx] = z;
            self.framebuffer[idx] = color;
        }
    }

    pub fn drawLine(self: *Renderer, x0: i32, y0: i32, x1: i32, y1: i32, color: Color) void {
        var x = x0;
        var y = y0;
        const dx = @abs(x1 - x0);
        const dy = @abs(y1 - y0);
        const sx: i32 = if (x0 < x1) 1 else -1;
        const sy: i32 = if (y0 < y1) 1 else -1;
        var err: i32 = @as(i32, @intCast(dx)) - @as(i32, @intCast(dy));

        while (true) {
            self.drawPixel(x, y, 0, color);
            if (x == x1 and y == y1) break;
            const e2 = err * 2;
            if (e2 > -@as(i32, @intCast(dy))) {
                err -= @intCast(dy);
                x += sx;
            }
            if (e2 < @as(i32, @intCast(dx))) {
                err += @intCast(dx);
                y += sy;
            }
        }
    }

    pub fn drawTriangle(self: *Renderer, p0: math.Vec3, p1: math.Vec3, p2: math.Vec3, color: Color) void {
        const mvp = math.Mat4.mul(self.projection_matrix, self.view_matrix);
        const sp0 = self.projectToScreen(math.Mat4.mulVec4(mvp, math.Vec4.fromVec3(p0, 1)));
        const sp1 = self.projectToScreen(math.Mat4.mulVec4(mvp, math.Vec4.fromVec3(p1, 1)));
        const sp2 = self.projectToScreen(math.Mat4.mulVec4(mvp, math.Vec4.fromVec3(p2, 1)));
        self.rasterizeTriangle(sp0, sp1, sp2, color);
    }

    /// Draw a triangle with per-vertex colors (Gouraud shading)
    pub fn drawTriangleShaded(
        self: *Renderer,
        p0: math.Vec3,
        p1: math.Vec3,
        p2: math.Vec3,
        c0: Color,
        c1: Color,
        c2: Color,
    ) void {
        const mvp = math.Mat4.mul(self.projection_matrix, self.view_matrix);
        const sp0 = self.projectToScreen(math.Mat4.mulVec4(mvp, math.Vec4.fromVec3(p0, 1)));
        const sp1 = self.projectToScreen(math.Mat4.mulVec4(mvp, math.Vec4.fromVec3(p1, 1)));
        const sp2 = self.projectToScreen(math.Mat4.mulVec4(mvp, math.Vec4.fromVec3(p2, 1)));
        self.rasterizeTriangleShaded(sp0, sp1, sp2, c0, c1, c2);
    }

    /// Draw a triangle with per-vertex colors and alpha blending (for transparent surfaces)
    pub fn drawTriangleShadedAlpha(
        self: *Renderer,
        p0: math.Vec3,
        p1: math.Vec3,
        p2: math.Vec3,
        c0: Color,
        c1: Color,
        c2: Color,
    ) void {
        const mvp = math.Mat4.mul(self.projection_matrix, self.view_matrix);
        const sp0 = self.projectToScreen(math.Mat4.mulVec4(mvp, math.Vec4.fromVec3(p0, 1)));
        const sp1 = self.projectToScreen(math.Mat4.mulVec4(mvp, math.Vec4.fromVec3(p1, 1)));
        const sp2 = self.projectToScreen(math.Mat4.mulVec4(mvp, math.Vec4.fromVec3(p2, 1)));
        self.rasterizeTriangleShadedAlpha(sp0, sp1, sp2, c0, c1, c2);
    }

    /// Draw a pixel with alpha blending (blends with existing framebuffer content)
    pub fn drawPixelAlpha(self: *Renderer, x: i32, y: i32, z: f32, color: Color) void {
        if (x < 0 or y < 0) return;
        const ux: u32 = @intCast(x);
        const uy: u32 = @intCast(y);
        if (ux >= self.width or uy >= self.height) return;

        const idx = uy * self.width + ux;

        // For transparent pixels, we do alpha blending instead of depth replacement
        // This allows seeing through water to blocks behind it
        if (z <= self.depth_buffer[idx] + 0.001) {
            // Alpha blend the new color over the existing pixel
            const src_alpha = @as(f32, @floatFromInt(color.a)) / 255.0;
            if (src_alpha >= 0.99) {
                // Fully opaque, just overwrite
                self.depth_buffer[idx] = z;
                self.framebuffer[idx] = color;
            } else if (src_alpha > 0.01) {
                // Blend with existing color
                self.framebuffer[idx] = Color.blend(self.framebuffer[idx], color);
                // Don't update depth buffer for transparent pixels
                // so objects behind can still be seen
            }
        }
    }

    fn projectToScreen(self: *const Renderer, clip: math.Vec4) math.Vec4 {
        if (clip.w() == 0) return math.Vec4.ZERO;
        const ndc = math.Vec4.init(clip.x() / clip.w(), clip.y() / clip.w(), clip.z() / clip.w(), 1.0 / clip.w());
        return math.Vec4.init(
            (ndc.x() + 1.0) * 0.5 * @as(f32, @floatFromInt(self.width)),
            (1.0 - ndc.y()) * 0.5 * @as(f32, @floatFromInt(self.height)),
            ndc.z(),
            ndc.w(),
        );
    }

    fn rasterizeTriangle(self: *Renderer, p0: math.Vec4, p1: math.Vec4, p2: math.Vec4, color: Color) void {
        const min_x = @max(0, @as(i32, @intFromFloat(@min(@min(p0.x(), p1.x()), p2.x()))));
        const max_x = @min(@as(i32, @intCast(self.width - 1)), @as(i32, @intFromFloat(@max(@max(p0.x(), p1.x()), p2.x()))));
        const min_y = @max(0, @as(i32, @intFromFloat(@min(@min(p0.y(), p1.y()), p2.y()))));
        const max_y = @min(@as(i32, @intCast(self.height - 1)), @as(i32, @intFromFloat(@max(@max(p0.y(), p1.y()), p2.y()))));

        const area = edgeFunction(p0.x(), p0.y(), p1.x(), p1.y(), p2.x(), p2.y());
        if (@abs(area) < 0.0001) return;

        var y = min_y;
        while (y <= max_y) : (y += 1) {
            var x = min_x;
            while (x <= max_x) : (x += 1) {
                const px = @as(f32, @floatFromInt(x)) + 0.5;
                const py = @as(f32, @floatFromInt(y)) + 0.5;

                const w0 = edgeFunction(p1.x(), p1.y(), p2.x(), p2.y(), px, py);
                const w1 = edgeFunction(p2.x(), p2.y(), p0.x(), p0.y(), px, py);
                const w2 = edgeFunction(p0.x(), p0.y(), p1.x(), p1.y(), px, py);

                if ((w0 >= 0 and w1 >= 0 and w2 >= 0) or (w0 <= 0 and w1 <= 0 and w2 <= 0)) {
                    const inv_area = 1.0 / area;
                    const b0 = w0 * inv_area;
                    const b1 = w1 * inv_area;
                    const b2 = w2 * inv_area;
                    const z = b0 * p0.z() + b1 * p1.z() + b2 * p2.z();
                    self.drawPixel(x, y, z, color);
                }
            }
        }
    }

    /// Rasterize triangle with per-vertex colors (Gouraud shading)
    fn rasterizeTriangleShaded(
        self: *Renderer,
        p0: math.Vec4,
        p1: math.Vec4,
        p2: math.Vec4,
        c0: Color,
        c1: Color,
        c2: Color,
    ) void {
        const min_x = @max(0, @as(i32, @intFromFloat(@min(@min(p0.x(), p1.x()), p2.x()))));
        const max_x = @min(@as(i32, @intCast(self.width - 1)), @as(i32, @intFromFloat(@max(@max(p0.x(), p1.x()), p2.x()))));
        const min_y = @max(0, @as(i32, @intFromFloat(@min(@min(p0.y(), p1.y()), p2.y()))));
        const max_y = @min(@as(i32, @intCast(self.height - 1)), @as(i32, @intFromFloat(@max(@max(p0.y(), p1.y()), p2.y()))));

        const area = edgeFunction(p0.x(), p0.y(), p1.x(), p1.y(), p2.x(), p2.y());
        if (@abs(area) < 0.0001) return;

        // Pre-convert colors to float for interpolation
        const cf0 = c0.toFloat();
        const cf1 = c1.toFloat();
        const cf2 = c2.toFloat();

        var y = min_y;
        while (y <= max_y) : (y += 1) {
            var x = min_x;
            while (x <= max_x) : (x += 1) {
                const px = @as(f32, @floatFromInt(x)) + 0.5;
                const py = @as(f32, @floatFromInt(y)) + 0.5;

                const w0 = edgeFunction(p1.x(), p1.y(), p2.x(), p2.y(), px, py);
                const w1 = edgeFunction(p2.x(), p2.y(), p0.x(), p0.y(), px, py);
                const w2 = edgeFunction(p0.x(), p0.y(), p1.x(), p1.y(), px, py);

                if ((w0 >= 0 and w1 >= 0 and w2 >= 0) or (w0 <= 0 and w1 <= 0 and w2 <= 0)) {
                    const inv_area = 1.0 / area;
                    const b0 = w0 * inv_area;
                    const b1 = w1 * inv_area;
                    const b2 = w2 * inv_area;
                    const z = b0 * p0.z() + b1 * p1.z() + b2 * p2.z();

                    // Interpolate color using barycentric coordinates
                    const interp_color = Color.fromFloat(
                        b0 * cf0[0] + b1 * cf1[0] + b2 * cf2[0],
                        b0 * cf0[1] + b1 * cf1[1] + b2 * cf2[1],
                        b0 * cf0[2] + b1 * cf1[2] + b2 * cf2[2],
                        b0 * cf0[3] + b1 * cf1[3] + b2 * cf2[3],
                    );

                    self.drawPixel(x, y, z, interp_color);
                }
            }
        }
    }

    /// Rasterize triangle with per-vertex colors and alpha blending
    fn rasterizeTriangleShadedAlpha(
        self: *Renderer,
        p0: math.Vec4,
        p1: math.Vec4,
        p2: math.Vec4,
        c0: Color,
        c1: Color,
        c2: Color,
    ) void {
        const min_x = @max(0, @as(i32, @intFromFloat(@min(@min(p0.x(), p1.x()), p2.x()))));
        const max_x = @min(@as(i32, @intCast(self.width - 1)), @as(i32, @intFromFloat(@max(@max(p0.x(), p1.x()), p2.x()))));
        const min_y = @max(0, @as(i32, @intFromFloat(@min(@min(p0.y(), p1.y()), p2.y()))));
        const max_y = @min(@as(i32, @intCast(self.height - 1)), @as(i32, @intFromFloat(@max(@max(p0.y(), p1.y()), p2.y()))));

        const area = edgeFunction(p0.x(), p0.y(), p1.x(), p1.y(), p2.x(), p2.y());
        if (@abs(area) < 0.0001) return;

        // Pre-convert colors to float for interpolation
        const cf0 = c0.toFloat();
        const cf1 = c1.toFloat();
        const cf2 = c2.toFloat();

        var y = min_y;
        while (y <= max_y) : (y += 1) {
            var x = min_x;
            while (x <= max_x) : (x += 1) {
                const px = @as(f32, @floatFromInt(x)) + 0.5;
                const py = @as(f32, @floatFromInt(y)) + 0.5;

                const w0 = edgeFunction(p1.x(), p1.y(), p2.x(), p2.y(), px, py);
                const w1 = edgeFunction(p2.x(), p2.y(), p0.x(), p0.y(), px, py);
                const w2 = edgeFunction(p0.x(), p0.y(), p1.x(), p1.y(), px, py);

                if ((w0 >= 0 and w1 >= 0 and w2 >= 0) or (w0 <= 0 and w1 <= 0 and w2 <= 0)) {
                    const inv_area = 1.0 / area;
                    const b0 = w0 * inv_area;
                    const b1 = w1 * inv_area;
                    const b2 = w2 * inv_area;
                    const z = b0 * p0.z() + b1 * p1.z() + b2 * p2.z();

                    // Interpolate color using barycentric coordinates
                    const interp_color = Color.fromFloat(
                        b0 * cf0[0] + b1 * cf1[0] + b2 * cf2[0],
                        b0 * cf0[1] + b1 * cf1[1] + b2 * cf2[1],
                        b0 * cf0[2] + b1 * cf1[2] + b2 * cf2[2],
                        b0 * cf0[3] + b1 * cf1[3] + b2 * cf2[3],
                    );

                    // Use alpha-blended pixel drawing
                    self.drawPixelAlpha(x, y, z, interp_color);
                }
            }
        }
    }

    pub fn getFramebuffer(self: *const Renderer) []const Color {
        return self.framebuffer;
    }

    // ========================================================================
    // Particle System Methods
    // ========================================================================

    /// Update the particle system
    pub fn updateParticles(self: *Renderer, dt: f32) void {
        self.particle_system.update(dt);
    }

    /// Render all active particles
    /// Should be called after world rendering but before UI
    pub fn renderParticles(self: *Renderer) void {
        const mvp = math.Mat4.mul(self.projection_matrix, self.view_matrix);

        var iter = self.particle_system.getActiveParticles();
        while (iter.next()) |particle| {
            self.renderParticle(particle, mvp);
        }
    }

    /// Render a single particle
    fn renderParticle(self: *Renderer, particle: *const Particle, mvp: math.Mat4) void {
        // Transform particle position to clip space
        const clip = math.Mat4.mulVec4(mvp, math.Vec4.fromVec3(particle.position, 1.0));

        // Skip if behind camera
        if (clip.w() <= 0) return;

        // Project to screen
        const screen = self.projectToScreen(clip);
        const sx = screen.x();
        const sy = screen.y();
        const sz = screen.z();

        // Skip if outside screen bounds (with some margin)
        const margin: f32 = 50;
        const fw: f32 = @floatFromInt(self.width);
        const fh: f32 = @floatFromInt(self.height);
        if (sx < -margin or sx > fw + margin or sy < -margin or sy > fh + margin) return;

        // Calculate particle size based on distance (perspective scaling)
        const base_size = particle.size;
        const perspective_size = base_size * (100.0 / clip.w());
        const final_size = @max(1.0, @min(perspective_size, 20.0)); // Clamp size

        // Get current color (with fade applied)
        const color = particle.getCurrentColor();

        // Render as a small square
        const half_size: i32 = @intFromFloat(final_size / 2.0);
        const cx: i32 = @intFromFloat(sx);
        const cy: i32 = @intFromFloat(sy);

        // Draw filled square
        var dy: i32 = -half_size;
        while (dy <= half_size) : (dy += 1) {
            var dx: i32 = -half_size;
            while (dx <= half_size) : (dx += 1) {
                const px = cx + dx;
                const py = cy + dy;

                if (particle.additive) {
                    self.drawPixelAdditive(px, py, sz, color);
                } else {
                    self.drawPixelBlended(px, py, sz, color);
                }
            }
        }
    }

    /// Draw a pixel with alpha blending
    pub fn drawPixelBlended(self: *Renderer, x: i32, y: i32, z: f32, color: Color) void {
        if (x < 0 or y < 0) return;
        const ux: u32 = @intCast(x);
        const uy: u32 = @intCast(y);
        if (ux >= self.width or uy >= self.height) return;

        const idx = uy * self.width + ux;

        // Only draw if in front of existing geometry (or close to it for particles)
        if (z < self.depth_buffer[idx] + 0.001) {
            if (color.a == 255) {
                self.framebuffer[idx] = color;
            } else {
                self.framebuffer[idx] = Color.blend(self.framebuffer[idx], color);
            }
        }
    }

    /// Draw a pixel with additive blending (for fire/sparkles)
    pub fn drawPixelAdditive(self: *Renderer, x: i32, y: i32, z: f32, color: Color) void {
        if (x < 0 or y < 0) return;
        const ux: u32 = @intCast(x);
        const uy: u32 = @intCast(y);
        if (ux >= self.width or uy >= self.height) return;

        const idx = uy * self.width + ux;

        // Only draw if in front of existing geometry
        if (z < self.depth_buffer[idx] + 0.001) {
            const dst = self.framebuffer[idx];
            const alpha = @as(f32, @floatFromInt(color.a)) / 255.0;

            // Additive blend: dst + src * alpha
            self.framebuffer[idx] = Color.fromRgba(
                @intCast(@min(255, @as(u16, dst.r) + @as(u16, @intFromFloat(@as(f32, @floatFromInt(color.r)) * alpha)))),
                @intCast(@min(255, @as(u16, dst.g) + @as(u16, @intFromFloat(@as(f32, @floatFromInt(color.g)) * alpha)))),
                @intCast(@min(255, @as(u16, dst.b) + @as(u16, @intFromFloat(@as(f32, @floatFromInt(color.b)) * alpha)))),
                dst.a,
            );
        }
    }

    /// Spawn particles at a position using a preset
    pub fn spawnParticles(self: *Renderer, position: math.Vec3, preset: ParticlePreset, count: u32) void {
        self.particle_system.spawnParticles(position, preset, count);
    }

    /// Spawn particles with a custom base color
    pub fn spawnParticlesWithColor(
        self: *Renderer,
        position: math.Vec3,
        preset: ParticlePreset,
        count: u32,
        color: Color,
    ) void {
        self.particle_system.spawnParticlesWithColor(position, preset, count, color);
    }

    /// Get the particle system for advanced control
    pub fn getParticleSystem(self: *Renderer) *ParticleSystem {
        return &self.particle_system;
    }
};

fn edgeFunction(ax: f32, ay: f32, bx: f32, by: f32, cx: f32, cy: f32) f32 {
    return (cx - ax) * (by - ay) - (cy - ay) * (bx - ax);
}

test "renderer init" {
    const allocator = std.testing.allocator;
    var renderer = try Renderer.init(allocator, null, 320, 240);
    defer renderer.deinit();

    try std.testing.expectEqual(@as(u32, 320), renderer.width);
    try std.testing.expectEqual(@as(u32, 240), renderer.height);
}
