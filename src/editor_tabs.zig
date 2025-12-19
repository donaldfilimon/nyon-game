const std = @import("std");
const raylib = @import("raylib");

pub const TabType = enum {
    scene_2d,
    scene_3d,
    geometry_nodes,
};

pub const TabSystem = struct {
    allocator: std.mem.Allocator,
    tabs: std.ArrayList(Tab),

    pub const Tab = struct {
        id: usize,
        tab_type: TabType,
        title: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator) TabSystem {
        return .{
            .allocator = allocator,
            .tabs = std.ArrayList(Tab).init(allocator),
        };
    }

    pub fn deinit(self: *TabSystem) void {
        self.tabs.deinit();
    }
};
