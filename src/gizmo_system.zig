const std = @import("std");
const raylib = @import("raylib");
const editor_tabs = @import("editor_tabs.zig");

pub const GizmoSystem = struct {
    allocator: std.mem.Allocator,
    active_mode: editor_tabs.GizmoMode = .translate,
    gizmo_size: f32 = 50.0,
    hover_axis: ?Axis = null,
    selected_axis: ?Axis = null,
    axis_colors: [3]raylib.Color = .{
        raylib.Color.red, // X axis
        raylib.Color.green, // Y axis
        raylib.Color.blue, // Z axis
    },

    pub const Axis = enum {
        x,
        y,
        z,
    };

    pub fn init(allocator: std.mem.Allocator) GizmoSystem {
        return .{
            .allocator = allocator,
        };
    }

    pub fn setMode(self: *GizmoSystem, mode: editor_tabs.GizmoMode) void {
        self.active_mode = mode;
        self.selected_axis = null;
    }

    pub fn handleInput(self: *GizmoSystem, camera: raylib.Camera3D, position: raylib.Vector3, mouse_delta: raylib.Vector2) bool {
        const mouse_pos = raylib.getMousePosition();
        const ray = raylib.getMouseRay(mouse_pos, camera);

        self.hover_axis = null;

        switch (self.active_mode) {
            .translate => {
                if (self.selected_axis) |axis| {
                    const axis_vector = self.getAxisVector(axis);
                    _ = self.projectMouseToAxis(ray, axis_vector, position, mouse_delta);
                    return true;
                } else {
                    self.hover_axis = self.checkAxisHover(ray, position);
                }
            },
            .rotate => {
                if (self.selected_axis) |axis| {
                    _ = self.calculateRotationDelta(ray, axis, position, mouse_delta);
                    return true;
                } else {
                    self.hover_axis = self.checkAxisHover(ray, position);
                }
            },
            .scale => {
                if (self.selected_axis) |axis| {
                    _ = self.calculateScaleFactor(ray, axis, position, mouse_delta);
                    return true;
                } else {
                    self.hover_axis = self.checkAxisHover(ray, position);
                }
            },
        }

        return false;
    }

    pub fn renderGizmo(self: *GizmoSystem, position: raylib.Vector3) void {
        const size = self.gizmo_size;

        switch (self.active_mode) {
            .translate => self.renderTranslateGizmo(position, size),
            .rotate => self.renderRotateGizmo(position, size),
            .scale => self.renderScaleGizmo(position, size),
        }
    }

    fn renderTranslateGizmo(self: *GizmoSystem, position: raylib.Vector3, size: f32) void {
        const axis_vectors = [3]raylib.Vector3{
            raylib.Vector3{ .x = size, .y = 0, .z = 0 },
            raylib.Vector3{ .x = 0, .y = size, .z = 0 },
            raylib.Vector3{ .x = 0, .y = 0, .z = size },
        };

        for (axis_vectors, 0..) |axis_vec, i| {
            const axis: Axis = @enumFromInt(i);
            const end_pos = raylib.Vector3{
                .x = position.x + axis_vec.x,
                .y = position.y + axis_vec.y,
                .z = position.z + axis_vec.z,
            };

            const color = if (self.hover_axis == axis or self.selected_axis == axis)
                self.brightenColor(self.axis_colors[i])
            else
                self.axis_colors[i];

            raylib.drawLine3D(position, end_pos, color);
            raylib.drawCube(end_pos, size * 0.15, size * 0.15, size * 0.15, color);
        }
    }

    fn renderRotateGizmo(self: *GizmoSystem, position: raylib.Vector3, size: f32) void {
        const segments = 32;

        for (0..3) |i| {
            const axis: Axis = @enumFromInt(i);
            const color = if (self.hover_axis == axis or self.selected_axis == axis)
                self.brightenColor(self.axis_colors[i])
            else
                self.axis_colors[i];

            const axis_vec = self.getAxisVector(axis);
            const perpendicular1 = self.getPerpendicularVector(axis_vec, 1);
            const perpendicular2 = self.getPerpendicularVector(axis_vec, 2);

            var j: usize = 0;
            while (j < segments) : (j += 1) {
                const angle1 = @as(f32, @floatFromInt(j)) / @as(f32, @floatFromInt(segments)) * 2.0 * std.math.pi;
                const angle2 = @as(f32, @floatFromInt(j + 1)) / @as(f32, @floatFromInt(segments)) * 2.0 * std.math.pi;

                const point1 = raylib.Vector3{
                    .x = position.x + (perpendicular1.x * @cos(angle1) + perpendicular2.x * @sin(angle1)) * size,
                    .y = position.y + (perpendicular1.y * @cos(angle1) + perpendicular2.y * @sin(angle1)) * size,
                    .z = position.z + (perpendicular1.z * @cos(angle1) + perpendicular2.z * @sin(angle1)) * size,
                };

                const point2 = raylib.Vector3{
                    .x = position.x + (perpendicular1.x * @cos(angle2) + perpendicular2.x * @sin(angle2)) * size,
                    .y = position.y + (perpendicular1.y * @cos(angle2) + perpendicular2.y * @sin(angle2)) * size,
                    .z = position.z + (perpendicular1.z * @cos(angle2) + perpendicular2.z * @sin(angle2)) * size,
                };

                raylib.drawLine3D(point1, point2, color);
            }
        }
    }

    fn renderScaleGizmo(self: *GizmoSystem, position: raylib.Vector3, size: f32) void {
        const axis_vectors = [3]raylib.Vector3{
            raylib.Vector3{ .x = size, .y = 0, .z = 0 },
            raylib.Vector3{ .x = 0, .y = size, .z = 0 },
            raylib.Vector3{ .x = 0, .y = 0, .z = size },
        };

        for (axis_vectors, 0..) |axis_vec, i| {
            const axis: Axis = @enumFromInt(i);
            const end_pos = raylib.Vector3{
                .x = position.x + axis_vec.x,
                .y = position.y + axis_vec.y,
                .z = position.z + axis_vec.z,
            };

            const color = if (self.hover_axis == axis or self.selected_axis == axis)
                self.brightenColor(self.axis_colors[i])
            else
                self.axis_colors[i];

            raylib.drawLine3D(position, end_pos, color);

            const box_size = size * 0.2;
            const box_pos = raylib.Vector3{
                .x = position.x + axis_vec.x - box_size / 2,
                .y = position.y + axis_vec.y - box_size / 2,
                .z = position.z + axis_vec.z - box_size / 2,
            };

            raylib.drawCubeWires(box_pos, box_size, box_size, box_size, color);
        }
    }

    fn checkAxisHover(self: *GizmoSystem, ray: raylib.Ray, position: raylib.Vector3) ?Axis {
        const threshold = 10.0;

        for (0..3) |i| {
            const axis: Axis = @enumFromInt(i);
            const axis_vec = self.getAxisVector(axis);
            const end_pos = raylib.Vector3{
                .x = position.x + axis_vec.x * self.gizmo_size,
                .y = position.y + axis_vec.y * self.gizmo_size,
                .z = position.z + axis_vec.z * self.gizmo_size,
            };

            const distance = self.rayToLineDistance(ray, position, end_pos);
            if (distance < threshold) {
                return axis;
            }
        }

        return null;
    }

    fn rayToLineDistance(ray: raylib.Ray, line_start: raylib.Vector3, line_end: raylib.Vector3) f32 {
        const line_vec = raylib.Vector3{
            .x = line_end.x - line_start.x,
            .y = line_end.y - line_start.y,
            .z = line_end.z - line_start.z,
        };

        const line_length = std.math.sqrt(line_vec.x * line_vec.x + line_vec.y * line_vec.y + line_vec.z * line_vec.z);
        if (line_length < 0.0001) return 9999.0;

        const t = ((ray.position.x - line_start.x) * line_vec.x +
            (ray.position.y - line_start.y) * line_vec.y +
            (ray.position.z - line_start.z) * line_vec.z) /
            (line_length * line_length);

        const clamped_t = @max(0.0, @min(1.0, t));
        const closest = raylib.Vector3{
            .x = line_start.x + line_vec.x * clamped_t,
            .y = line_start.y + line_vec.y * clamped_t,
            .z = line_start.z + line_vec.z * clamped_t,
        };

        const distance = std.math.sqrt(std.math.pow(f32, ray.position.x - closest.x, 2) +
            std.math.pow(f32, ray.position.y - closest.y, 2) +
            std.math.pow(f32, ray.position.z - closest.z, 2));

        return distance;
    }

    fn projectMouseToAxis(self: *GizmoSystem, ray: raylib.Ray, axis_vector: raylib.Vector3, position: raylib.Vector3, mouse_delta: raylib.Vector2) f32 {
        _ = self;
        _ = ray;
        _ = axis_vector;
        _ = position;
        _ = mouse_delta;
        return 0.0;
    }

    fn calculateRotationDelta(self: *GizmoSystem, ray: raylib.Ray, axis: Axis, position: raylib.Vector3, mouse_delta: raylib.Vector2) f32 {
        _ = self;
        _ = ray;
        _ = axis;
        _ = position;
        _ = mouse_delta;
        return 0.0;
    }

    fn calculateScaleFactor(self: *GizmoSystem, ray: raylib.Ray, axis: Axis, position: raylib.Vector3, mouse_delta: raylib.Vector2) f32 {
        _ = self;
        _ = ray;
        _ = axis;
        _ = position;
        _ = mouse_delta;
        return 0.0;
    }

    fn getAxisVector(self: *GizmoSystem, axis: Axis) raylib.Vector3 {
        _ = self;
        return switch (axis) {
            .x => raylib.Vector3{ .x = 1, .y = 0, .z = 0 },
            .y => raylib.Vector3{ .x = 0, .y = 1, .z = 0 },
            .z => raylib.Vector3{ .x = 0, .y = 0, .z = 1 },
        };
    }

    fn getPerpendicularVector(self: *GizmoSystem, axis_vector: raylib.Vector3, index: usize) raylib.Vector3 {
        _ = self;
        return if (index == 1)
            raylib.Vector3{ .x = axis_vector.z, .y = 0, .z = -axis_vector.x }
        else
            raylib.Vector3{ .x = 0, .y = axis_vector.z, .z = -axis_vector.y };
    }

    fn brightenColor(self: *GizmoSystem, color: raylib.Color) raylib.Color {
        _ = self;
        return raylib.Color{
            .r = @min(255, color.r + 50),
            .g = @min(255, color.g + 50),
            .b = @min(255, color.b + 50),
            .a = color.a,
        };
    }
};
