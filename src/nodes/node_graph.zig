const std = @import("std");

const raylib = @import("raylib");

const GraphError = error{
    NodeNotFound,
    MissingInputValue,
    InputNotFound,
    InvalidOutputIndex,
    NoConnectionFound,
    InvalidInputCount,
    CycleDetected,
} || std.mem.Allocator.Error;

/// Core node graph system with topological sorting and evaluation
///
/// This provides the foundation for any node-based system (geometry, materials, etc.)
/// with proper dependency resolution and execution ordering.
pub const NodeGraph = struct {
    allocator: std.mem.Allocator,

    /// All nodes in the graph
    nodes: std.ArrayList(Node),

    /// Connections between nodes
    connections: std.ArrayList(Connection),

    /// Execution cache to avoid redundant computations
    execution_cache: std.AutoHashMap(usize, CacheEntry),

    /// Next available node ID
    next_node_id: usize,

    /// Cache timestamp counter
    cache_counter: usize,

    pub const NodeId = usize;

    pub const Connection = struct {
        from_node: NodeId,
        from_output: usize,
        to_node: NodeId,
        to_input: usize,

        pub fn hash(self: Connection) u64 {
            var hasher = std.hash.Wyhash.init(0);
            std.hash.autoHash(&hasher, self.from_node);
            std.hash.autoHash(&hasher, self.from_output);
            std.hash.autoHash(&hasher, self.to_node);
            std.hash.autoHash(&hasher, self.to_input);
            return hasher.final();
        }

        pub fn eql(self: Connection, other: Connection) bool {
            return self.from_node == other.from_node and
                self.from_output == other.from_output and
                self.to_node == other.to_node and
                self.to_input == other.to_input;
        }
    };

    pub const CacheEntry = struct {
        last_modified: i64,
        outputs: std.ArrayList(Value),
    };

    /// Generic value type for node data flow
    pub const Value = union(enum) {
        mesh: raylib.Mesh,
        vector3: raylib.Vector3,
        vector2: raylib.Vector2,
        float: f32,
        int: i32,
        bool: bool,
        string: []const u8,

        pub fn deinit(self: *Value, allocator: std.mem.Allocator) void {
            switch (self.*) {
                .string => |s| allocator.free(s),
                else => {},
            }
        }

        pub fn clone(self: Value, allocator: std.mem.Allocator) !Value {
            return switch (self) {
                .mesh => |m| .{ .mesh = m }, // Meshes are reference counted by raylib
                .vector3 => |v| .{ .vector3 = v },
                .vector2 => |v| .{ .vector2 = v },
                .float => |f| .{ .float = f },
                .int => |i| .{ .int = i },
                .bool => |b| .{ .bool = b },
                .string => |s| .{ .string = try allocator.dupe(u8, s) },
            };
        }
    };

    /// Abstract node interface
    pub const Node = struct {
        id: NodeId,
        node_type: []const u8,
        position: raylib.Vector2,

        /// Input values (can be connected or constant)
        inputs: std.ArrayList(InputSlot),

        /// Output definitions
        outputs: std.ArrayList(OutputSlot),

        /// Custom data for node-specific state
        user_data: ?*anyopaque,

        /// Node interface functions (to be implemented by concrete nodes)
        vtable: *const NodeVTable,

        /// Allocator for this node
        allocator: std.mem.Allocator,

        pub const InputSlot = struct {
            name: []const u8,
            value_type: ValueType,
            connected: bool,
            constant_value: ?Value,
        };

        pub const OutputSlot = struct {
            name: []const u8,
            value_type: ValueType,
        };

        pub const ValueType = enum {
            mesh,
            vector3,
            vector2,
            float,
            int,
            bool,
            string,
            any,
        };

        pub const NodeVTable = struct {
            execute: *const fn (node: *Node, inputs: []const Value, allocator: std.mem.Allocator) GraphError![]Value,
            deinit: *const fn (node: *Node, allocator: std.mem.Allocator) void,
        };

        pub fn init(allocator: std.mem.Allocator, id: NodeId, node_type: []const u8, vtable: *const NodeVTable) !Node {
            return .{
                .id = id,
                .node_type = try allocator.dupe(u8, node_type),
                .position = .{ .x = 0, .y = 0 },
                .inputs = std.ArrayList(Node.InputSlot).initCapacity(allocator, 0) catch unreachable,
                .outputs = std.ArrayList(Node.OutputSlot).initCapacity(allocator, 0) catch unreachable,
                .user_data = null,
                .vtable = vtable,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Node, allocator: std.mem.Allocator) void {
            allocator.free(self.node_type);
            for (self.inputs.items) |*input| {
                if (input.constant_value) |*val| {
                    val.deinit(allocator);
                }
                allocator.free(input.name);
            }
            self.inputs.deinit(self.allocator);

            for (self.outputs.items) |*output| {
                allocator.free(output.name);
            }
            self.outputs.deinit(self.allocator);

            self.vtable.deinit(self, allocator);
        }

        pub fn addInput(self: *Node, name: []const u8, value_type: ValueType, default_value: ?Value) !void {
            const input_name = try self.allocator.dupe(u8, name);
            errdefer self.allocator.free(input_name);

            var constant_value: ?Value = null;
            if (default_value) |val| {
                constant_value = try val.clone(self.allocator);
            }

            try self.inputs.append(self.allocator, .{
                .name = input_name,
                .value_type = value_type,
                .connected = false,
                .constant_value = constant_value,
            });
        }

        pub fn addOutput(self: *Node, name: []const u8, value_type: ValueType) !void {
            const output_name = try self.allocator.dupe(u8, name);
            try self.outputs.append(self.allocator, .{
                .name = output_name,
                .value_type = value_type,
            });
        }

        pub fn execute(self: *Node, inputs: []const Value, allocator: std.mem.Allocator) ![]Value {
            return self.vtable.execute(self, inputs, allocator);
        }
    };

    pub fn init(allocator: std.mem.Allocator) NodeGraph {
        return .{
            .allocator = allocator,
            .nodes = std.ArrayList(Node).initCapacity(allocator, 0) catch unreachable,
            .connections = std.ArrayList(Connection).initCapacity(allocator, 0) catch unreachable,
            .execution_cache = std.AutoHashMap(usize, CacheEntry).init(allocator),
            .next_node_id = 0,
            .cache_counter = 0,
        };
    }

    pub fn deinit(self: *NodeGraph) void {
        // Clear execution cache
        var cache_iter = self.execution_cache.iterator();
        while (cache_iter.next()) |entry| {
            for (entry.value_ptr.outputs.items) |*val| {
                val.deinit(self.allocator);
            }
            entry.value_ptr.outputs.deinit(self.allocator);
        }
        self.execution_cache.deinit();

        // Deinit nodes
        for (self.nodes.items) |*node| {
            node.deinit(self.allocator);
        }
        self.nodes.deinit(self.allocator);

        self.connections.deinit(self.allocator);
    }

    pub fn addNode(self: *NodeGraph, node_type: []const u8, vtable: *const Node.NodeVTable) !NodeId {
        const id = self.next_node_id;
        self.next_node_id += 1;

        const node = try Node.init(self.allocator, id, node_type, vtable);
        try self.nodes.append(self.allocator, node);

        return id;
    }

    pub fn removeNode(self: *NodeGraph, node_id: NodeId) !void {
        // Find and remove the node
        const node_index = self.findNodeIndex(node_id) orelse return error.NodeNotFound;

        var node = self.nodes.orderedRemove(node_index);
        node.deinit(self.allocator);

        // Update IDs of remaining nodes
        for (self.nodes.items[node_index..]) |*n| {
            if (n.id > node_id) {
                n.id -= 1;
            }
        }

        // Remove connections involving this node
        var i: usize = 0;
        while (i < self.connections.items.len) {
            const conn = self.connections.items[i];
            if (conn.from_node == node_id or conn.to_node == node_id) {
                _ = self.connections.orderedRemove(i);
            } else {
                // Update connection indices
                if (conn.from_node > node_id) {
                    self.connections.items[i].from_node -= 1;
                }
                if (conn.to_node > node_id) {
                    self.connections.items[i].to_node -= 1;
                }
                i += 1;
            }
        }

        // Clear cache for affected nodes
        self.execution_cache.clearRetainingCapacity();

        // Update next_node_id if necessary
        if (node_id < self.next_node_id - 1) {
            self.next_node_id -= 1;
        }
    }

    pub fn addConnection(self: *NodeGraph, from_node: NodeId, from_output: usize, to_node: NodeId, to_input: usize) !void {
        // Validate nodes exist
        const from_index = self.findNodeIndex(from_node) orelse return error.FromNodeNotFound;
        const to_index = self.findNodeIndex(to_node) orelse return error.ToNodeNotFound;

        const from_node_ref = &self.nodes.items[from_index];
        const to_node_ref = &self.nodes.items[to_index];

        // Validate output/input indices
        if (from_output >= from_node_ref.outputs.items.len) return error.InvalidOutputIndex;
        if (to_input >= to_node_ref.inputs.items.len) return error.InvalidInputIndex;

        // Check for cycles
        if (self.wouldCreateCycle(from_node, to_node)) return error.WouldCreateCycle;

        // Remove existing connection to this input
        var i: usize = 0;
        while (i < self.connections.items.len) {
            if (self.connections.items[i].to_node == to_node and self.connections.items[i].to_input == to_input) {
                _ = self.connections.orderedRemove(i);
            } else {
                i += 1;
            }
        }

        // Add new connection
        try self.connections.append(self.connections.allocator, .{
            .from_node = from_node,
            .from_output = from_output,
            .to_node = to_node,
            .to_input = to_input,
        });

        // Mark input as connected
        to_node_ref.inputs.items[to_input].connected = true;

        // Clear execution cache
        self.invalidateCache();
    }

    pub fn removeConnection(self: *NodeGraph, from_node: NodeId, from_output: usize, to_node: NodeId, to_input: usize) !void {
        const index = self.findConnectionIndex(from_node, from_output, to_node, to_input) orelse return error.ConnectionNotFound;
        _ = self.connections.orderedRemove(index);

        // Mark input as disconnected
        if (self.findNodeIndex(to_node)) |node_index| {
            self.nodes.items[node_index].inputs.items[to_input].connected = false;
        }

        // Clear execution cache
        self.invalidateCache();
    }

    /// Execute the entire graph in topological order
    pub fn execute(self: *NodeGraph) GraphError!void {
        const execution_order = try self.getTopologicalOrder(self.allocator);
        defer self.allocator.free(execution_order);

        for (execution_order) |node_id| {
            _ = try self.executeNode(node_id);
        }
    }

    /// Execute a specific node and get its outputs
    pub fn executeNode(self: *NodeGraph, node_id: NodeId) GraphError![]Value {
        const node_index = self.findNodeIndex(node_id) orelse return error.NodeNotFound;
        const node = &self.nodes.items[node_index];

        // Check cache first
        self.cache_counter += 1;
        if (self.execution_cache.get(node_id)) |*cache_entry| {
            if (cache_entry.last_modified >= self.cache_counter - 10) { // Cache for 10 executions
                return try self.duplicateValues(cache_entry.outputs.items, self.allocator);
            }
        }

        // Gather inputs
        var inputs = std.ArrayList(Value).initCapacity(self.allocator, 0) catch unreachable;
        defer inputs.deinit(self.allocator);

        for (node.inputs.items) |input| {
            if (input.connected) {
                // Find connected output
                const input_value = try self.getConnectedValue(node_id, &input);
                try inputs.append(self.allocator, input_value);
            } else if (input.constant_value) |val| {
                try inputs.append(self.allocator, try val.clone(self.allocator));
            } else {
                return error.MissingInputValue;
            }
        }

        // Execute node
        const outputs = try node.execute(inputs.items, self.allocator);

        // Cache the result
        var cached_outputs = std.ArrayList(Value).initCapacity(self.allocator, 0) catch unreachable;
        for (outputs) |output| {
            try cached_outputs.append(self.allocator, try output.clone(self.allocator));
        }

        const cache_counter_i64: i64 = @intCast(self.cache_counter);
        try self.execution_cache.put(node_id, .{
            .last_modified = cache_counter_i64,
            .outputs = cached_outputs,
        });

        return outputs;
    }

    /// Get the value flowing into a node's input
    fn getConnectedValue(self: *NodeGraph, to_node_id: NodeId, input: *const Node.InputSlot) GraphError!Value {
        // Find the connection
        for (self.connections.items) |conn| {
            if (conn.to_node == to_node_id and conn.to_input == blk: {
                // Find input index
                const node_index = self.findNodeIndex(to_node_id) orelse return error.NodeNotFound;
                const node = &self.nodes.items[node_index];
                for (node.inputs.items, 0..) |inp, idx| {
                    if (std.mem.eql(u8, inp.name, input.name)) {
                        break :blk idx;
                    }
                }
                return error.InputNotFound;
            }) {
                // Execute the connected node and get its output
                const connected_outputs = try self.executeNode(conn.from_node);
                if (conn.from_output >= connected_outputs.len) return error.InvalidOutputIndex;
                return connected_outputs[conn.from_output];
            }
        }
        return error.NoConnectionFound;
    }

    /// Get topological execution order using Kahn's algorithm
    fn getTopologicalOrder(self: *NodeGraph, allocator: std.mem.Allocator) ![]NodeId {
        var result = std.ArrayList(NodeId).initCapacity(allocator, 0) catch unreachable;
        errdefer result.deinit(allocator);

        var in_degree = std.AutoHashMap(NodeId, usize).init(allocator);
        defer in_degree.deinit();

        var queue = std.ArrayList(NodeId).initCapacity(allocator, 0) catch unreachable;
        defer queue.deinit(allocator);

        // Initialize in-degrees
        for (self.nodes.items) |*node| {
            try in_degree.put(node.id, 0);
        }

        // Calculate in-degrees based on connections
        for (self.connections.items) |conn| {
            if (in_degree.getPtr(conn.to_node)) |degree| {
                degree.* += 1;
            }
        }

        // Find nodes with no incoming edges
        var degree_iter = in_degree.iterator();
        while (degree_iter.next()) |entry| {
            if (entry.value_ptr.* == 0) {
                try queue.append(allocator, entry.key_ptr.*);
            }
        }

        // Process queue
        while (queue.items.len > 0) {
            const node_id = queue.orderedRemove(0);
            try result.append(allocator, node_id);

            // Find all nodes that this node connects to
            for (self.connections.items) |conn| {
                if (conn.from_node == node_id) {
                    if (in_degree.getPtr(conn.to_node)) |degree| {
                        degree.* -= 1;
                        if (degree.* == 0) {
                            try queue.append(allocator, conn.to_node);
                        }
                    }
                }
            }
        }

        // Check for cycles
        if (result.items.len != self.nodes.items.len) {
            return error.CycleDetected;
        }

        return result.toOwnedSlice(allocator);
    }

    fn wouldCreateCycle(self: *const NodeGraph, from_node: NodeId, to_node: NodeId) bool {
        // Simple cycle detection - check if to_node can reach from_node
        return self.canReach(to_node, from_node);
    }

    fn canReach(self: *const NodeGraph, start: NodeId, target: NodeId) bool {
        if (start == target) return true;

        for (self.connections.items) |conn| {
            if (conn.from_node == start) {
                if (self.canReach(conn.to_node, target)) return true;
            }
        }
        return false;
    }

    pub fn findNodeIndex(self: *const NodeGraph, node_id: NodeId) ?usize {
        for (self.nodes.items, 0..) |node, index| {
            if (node.id == node_id) return index;
        }
        return null;
    }

    fn findConnectionIndex(self: *const NodeGraph, from_node: NodeId, from_output: usize, to_node: NodeId, to_input: usize) ?usize {
        for (self.connections.items, 0..) |conn, index| {
            if (conn.from_node == from_node and
                conn.from_output == from_output and
                conn.to_node == to_node and
                conn.to_input == to_input)
            {
                return index;
            }
        }
        return null;
    }

    fn invalidateCache(self: *NodeGraph) void {
        self.execution_cache.clearRetainingCapacity();
    }

    /// Mark the graph as dirty, clearing any cached execution results.
    pub fn markDirty(self: *NodeGraph) void {
        self.invalidateCache();
    }

    /// Pretty‑print the node graph for debugging purposes.
    pub fn debugPrint(self: *const NodeGraph) void {
        std.debug.print("NodeGraph with {d} nodes\n", .{self.nodes.items.len});
        for (self.nodes.items, 0..) |node, i| {
            std.debug.print("  {d}: {s} at ({d:.1},{d:.1})\n", .{
                i,
                node.node_type,
                node.position.x,
                node.position.y,
            });
        }
    }

    fn duplicateValues(_: *const NodeGraph, values: []const Value, allocator: std.mem.Allocator) ![]Value {
        var result = try allocator.alloc(Value, values.len);
        for (values, 0..) |val, i| {
            result[i] = try val.clone(allocator);
        }
        return result;
    }
};
