const std = @import("std");
const editor_tabs = @import("editor_tabs.zig");

pub const ToolSystem = struct {
    allocator: std.mem.Allocator,
    active_tool_2d: editor_tabs.ToolMode2D = .select,
    active_tool_3d: editor_tabs.ToolMode3D = .select,

    pub fn init(allocator: std.mem.Allocator) ToolSystem {
        return .{
            .allocator = allocator,
        };
    }
};
