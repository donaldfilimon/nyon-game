//! Scene Management

const std = @import("std");
const ecs = @import("../ecs/ecs.zig");
const math = @import("../math/math.zig");

/// Scene graph node
pub const Node = struct {
    entity: ecs.Entity,
    local_transform: math.Mat4,
    world_transform: math.Mat4,
    parent: ?*Node,
    children: std.ArrayListUnmanaged(*Node),
    name: [64]u8,
    name_len: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, entity: ecs.Entity) !*Node {
        const node = try allocator.create(Node);
        node.* = .{
            .entity = entity,
            .local_transform = math.Mat4.IDENTITY,
            .world_transform = math.Mat4.IDENTITY,
            .parent = null,
            .children = .{},
            .name = undefined,
            .name_len = 0,
            .allocator = allocator,
        };
        return node;
    }

    pub fn deinit(self: *Node) void {
        self.children.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn setName(self: *Node, name: []const u8) void {
        const len = @min(name.len, 64);
        @memcpy(self.name[0..len], name[0..len]);
        self.name_len = len;
    }

    pub fn getName(self: *const Node) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn addChild(self: *Node, child: *Node) !void {
        child.parent = self;
        try self.children.append(self.allocator, child);
    }

    pub fn removeChild(self: *Node, child: *Node) void {
        for (self.children.items, 0..) |c, i| {
            if (c == child) {
                _ = self.children.swapRemove(i);
                child.parent = null;
                break;
            }
        }
    }

    pub fn updateWorldTransform(self: *Node) void {
        if (self.parent) |p| {
            self.world_transform = math.Mat4.mul(p.world_transform, self.local_transform);
        } else {
            self.world_transform = self.local_transform;
        }
        for (self.children.items) |child| {
            child.updateWorldTransform();
        }
    }
};

/// Scene container
pub const Scene = struct {
    allocator: std.mem.Allocator,
    world: *ecs.World,
    root: *Node,
    nodes: std.AutoHashMap(u64, *Node),
    name: [128]u8,
    name_len: usize,

    pub fn init(allocator: std.mem.Allocator, world: *ecs.World) !Scene {
        const root_entity = try world.spawn();
        const root = try Node.init(allocator, root_entity);
        root.setName("Root");

        var nodes = std.AutoHashMap(u64, *Node).init(allocator);
        try nodes.put(root_entity.hash(), root);

        return .{
            .allocator = allocator,
            .world = world,
            .root = root,
            .nodes = nodes,
            .name = undefined,
            .name_len = 0,
        };
    }

    pub fn deinit(self: *Scene) void {
        var iter = self.nodes.valueIterator();
        while (iter.next()) |node| {
            node.*.deinit();
        }
        self.nodes.deinit();
    }

    pub fn createNode(self: *Scene, name: []const u8, parent: ?*Node) !*Node {
        const entity = try self.world.spawn();
        const node = try Node.init(self.allocator, entity);
        node.setName(name);

        try self.nodes.put(entity.hash(), node);

        const p = parent orelse self.root;
        try p.addChild(node);

        return node;
    }

    pub fn destroyNode(self: *Scene, node: *Node) void {
        if (node.parent) |p| {
            p.removeChild(node);
        }
        self.world.despawn(node.entity);
        _ = self.nodes.remove(node.entity.hash());
        node.deinit();
    }

    pub fn findNode(self: *Scene, entity: ecs.Entity) ?*Node {
        return self.nodes.get(entity.hash());
    }

    pub fn update(self: *Scene) void {
        self.root.updateWorldTransform();
    }

    pub fn setName(self: *Scene, name: []const u8) void {
        const len = @min(name.len, 128);
        @memcpy(self.name[0..len], name[0..len]);
        self.name_len = len;
    }

    pub fn getName(self: *const Scene) []const u8 {
        return self.name[0..self.name_len];
    }
};

test "scene hierarchy" {
    const allocator = std.testing.allocator;
    var world = try ecs.World.init(allocator);
    defer world.deinit();

    var scene = try Scene.init(allocator, &world);
    defer scene.deinit();

    const child = try scene.createNode("Child", null);
    try std.testing.expectEqualStrings("Child", child.getName());
    try std.testing.expectEqual(scene.root, child.parent.?);
}
