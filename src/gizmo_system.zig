const std = @import("std");
const raylib = @import("raylib");
const editor_tabs = @import("editor_tabs.zig");

pub const GizmoSystem = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) GizmoSystem {
        return .{
            .allocator = allocator,
        };
    }

    pub fn renderGizmo(self: *GizmoSystem, gizmo_mode: editor_tabs.GizmoMode, position: raylib.Vector3) void {
        _ = self;
        _ = gizmo_mode;
        _ = position;
        // TODO: Implement gizmo rendering
    }
};
