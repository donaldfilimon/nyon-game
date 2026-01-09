//! Software Renderer with GPU Compute Acceleration

const std = @import("std");
const math = @import("../math/math.zig");
const gpu = @import("../gpu/gpu.zig");
const ecs = @import("../ecs/ecs.zig");

pub const Color = @import("color.zig").Color;
pub const Texture = @import("texture.zig").Texture;
pub const Mesh = @import("mesh.zig").Mesh;

/// Main renderer
pub const Renderer = struct {
    allocator: std.mem.Allocator,
    gpu_ctx: ?gpu.Context,
    width: u32,
    height: u32,
    framebuffer: []Color,
    depth_buffer: []f32,
    view_matrix: math.Mat4,
    projection_matrix: math.Mat4,
    meshes: std.ArrayListUnmanaged(Mesh),
    textures: std.ArrayListUnmanaged(Texture),

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

        return Renderer{
            .allocator = allocator,
            .gpu_ctx = gpu_ctx,
            .width = width,
            .height = height,
            .framebuffer = framebuffer,
            .depth_buffer = depth_buffer,
            .view_matrix = math.Mat4.IDENTITY,
            .projection_matrix = math.Mat4.perspective(
                math.radians(60.0),
                @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height)),
                0.1,
                1000.0,
            ),
            .meshes = .{},
            .textures = .{},
        };
    }

    pub fn deinit(self: *Renderer) void {
        self.allocator.free(self.framebuffer);
        self.allocator.free(self.depth_buffer);
        for (self.meshes.items) |*mesh| mesh.deinit();
        self.meshes.deinit(self.allocator);
        for (self.textures.items) |*tex| tex.deinit();
        self.textures.deinit(self.allocator);
    }

    pub fn beginFrame(self: *Renderer) void {
        self.clear(Color.fromRgb(30, 30, 40));
    }

    pub fn endFrame(_: *Renderer) void {
        // Framebuffer is ready for display
    }

    pub fn clear(self: *Renderer, color: Color) void {
        @memset(self.framebuffer, color);
        @memset(self.depth_buffer, 1.0);
    }

    pub fn setCamera(self: *Renderer, view: math.Mat4, projection: math.Mat4) void {
        self.view_matrix = view;
        self.projection_matrix = projection;
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

    fn drawWireframeCube(self: *Renderer, model: math.Mat4, color: Color) void {
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

    pub fn getFramebuffer(self: *const Renderer) []const Color {
        return self.framebuffer;
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
