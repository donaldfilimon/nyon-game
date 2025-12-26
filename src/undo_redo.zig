const std = @import("std");
const nyon = @import("nyon_game");

/// Undo/Redo System with Command Pattern
///
/// Provides comprehensive undo/redo functionality for the Nyon Game Engine editor.
/// Supports scene operations, material changes, animation modifications, and custom commands.
pub const UndoRedoSystem = struct {
    allocator: std.mem.Allocator,

    /// Command history stacks
    undo_stack: std.ArrayList(*Command),
    redo_stack: std.ArrayList(*Command),

    /// Maximum number of commands to keep in history
    max_history_size: usize,

    /// Current compound command (for grouping operations)
    current_compound: ?*CompoundCommand,

    /// Command registry for serialization/deserialization
    command_types: std.StringHashMap(CommandType),

    pub const CommandId = usize;

    /// Base command interface
    pub const Command = struct {
        id: CommandId,
        description: []const u8,

        /// Pointer to implementation-specific data
        impl_ptr: *anyopaque,

        /// Virtual function table for command operations
        vtable: *const VTable,

        pub const VTable = struct {
            execute: *const fn (*anyopaque) anyerror!void,
            undo: *const fn (*anyopaque) anyerror!void,
            deinit: *const fn (*anyopaque, std.mem.Allocator) void,
            clone: *const fn (*anyopaque, std.mem.Allocator) anyerror!*Command,
            getMemoryUsage: *const fn (*anyopaque) usize,
            getTypeName: *const fn (*anyopaque) []const u8,
        };

        /// Execute the command
        pub fn execute(self: *Command) !void {
            try self.vtable.execute(self);
        }

        /// Undo the command
        pub fn undo(self: *Command) !void {
            try self.vtable.undo(self);
        }

        /// Clean up the command
        pub fn deinit(self: *Command, allocator: std.mem.Allocator) void {
            self.vtable.deinit(self, allocator);
        }

        /// Clone the command for redo stack
        pub fn clone(self: *Command, allocator: std.mem.Allocator) !*Command {
            return try self.vtable.clone(self, allocator);
        }

        /// Get memory usage of the command
        pub fn getMemoryUsage(self: *Command) usize {
            return self.vtable.getMemoryUsage(self.impl_ptr);
        }

        /// Get the type name of the command
        pub fn getTypeName(self: *Command) []const u8 {
            return self.vtable.getTypeName(self.impl_ptr);
        }
    };

    /// Compound command for grouping multiple operations
    pub const CompoundCommand = struct {
        base: Command,
        commands: std.ArrayList(*Command),
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, description: []const u8) !*CompoundCommand {
            const desc_copy = try allocator.dupe(u8, description);
            errdefer allocator.free(desc_copy);

            const compound = try allocator.create(CompoundCommand);
            errdefer allocator.destroy(compound);

            compound.* = .{
                .base = .{
                    .id = 0, // Set by system
                    .description = desc_copy,
                    .vtable = &vtable,
                },
                .commands = std.ArrayList(*Command).initCapacity(allocator, 0) catch unreachable,
                .allocator = allocator,
            };

            return compound;
        }

        pub fn deinit(compound: *CompoundCommand, allocator: std.mem.Allocator) void {
            for (compound.commands.items) |cmd| {
                cmd.deinit(allocator);
            }
            compound.commands.deinit(allocator);
            allocator.free(compound.base.description);
        }

        pub fn addCommand(compound: *CompoundCommand, command: *Command) !void {
            try compound.commands.append(compound.allocator, command);
        }

        const vtable = Command.VTable{
            .execute = executeImpl,
            .undo = undoImpl,
            .deinit = deinitImpl,
            .clone = cloneImpl,
            .getMemoryUsage = getMemoryUsageImpl,
            .getTypeName = getTypeNameImpl,
        };

        fn executeImpl(cmd: *Command) !void {
            const compound: *CompoundCommand = @ptrCast(cmd);
            for (compound.commands.items) |command| {
                try command.execute();
            }
        }

        fn undoImpl(cmd: *Command) !void {
            const compound: *CompoundCommand = @ptrCast(cmd);
            // Undo in reverse order
            var i = compound.commands.items.len;
            while (i > 0) {
                i -= 1;
                try compound.commands.items[i].undo();
            }
        }

        fn deinitImpl(cmd: *Command, allocator: std.mem.Allocator) void {
            const compound: *CompoundCommand = @ptrCast(cmd);
            compound.deinit(allocator);
            allocator.destroy(compound);
        }

        fn cloneImpl(cmd: *Command, allocator: std.mem.Allocator) !*Command {
            const compound: *CompoundCommand = @ptrCast(cmd);
            const new_compound = try CompoundCommand.init(allocator, compound.base.description);
            errdefer new_compound.deinit(allocator);

            for (compound.commands.items) |command| {
                const cloned_cmd = try command.clone(allocator);
                try new_compound.commands.append(new_compound.allocator, cloned_cmd);
            }

            return &new_compound.base;
        }

        fn getMemoryUsageImpl(cmd: *anyopaque) usize {
            const compound: *CompoundCommand = @ptrCast(@alignCast(cmd));
            var total: usize = @sizeOf(CompoundCommand) + compound.base.description.len;
            for (compound.commands.items) |command| {
                total += command.getMemoryUsage();
            }
            return total;
        }

        fn getTypeNameImpl(_: *anyopaque) []const u8 {
            return "CompoundCommand";
        }

        pub fn getCommandType() CommandType {
            return .{
                .name = "CompoundCommand",
                .createFn = createFromJson,
                .serializeFn = serializeToJson,
            };
        }

        fn createFromJson(allocator: std.mem.Allocator, json_value: std.json.Value, context: ?*anyopaque) anyerror!*Command {
            const root = json_value.object;
            const description = if (root.get("description")) |d| d.string else "Compound Command";
            const compound = try CompoundCommand.init(allocator, description);
            errdefer compound.deinitImpl(@ptrCast(compound), allocator);

            if (root.get("commands")) |cmds_val| {
                for (cmds_val.array.items) |cmd_val| {
                    if (cmd_val.object.get("type")) |type_val| {
                        const type_name = type_val.string;
                        // This requires access to the system's registry, but we only have context.
                        // Assuming the context also provides a way to find command types or the system itself.
                        // For generic recursion, we might need to pass the UndoRedoSystem in the context or
                        // have a global/shared registry.
                        // Given the current structure, let's assume the context *is* a scene,
                        // but maybe we should pass a struct containing both scene and system.
                        // Actually, if we use a helper on the system, it's easier.
                        // But createFn is static. Let's assume for now it can find SceneTransformCommand at least.

                        if (std.mem.eql(u8, type_name, "SceneTransformCommand")) {
                            const cmd = try SceneTransformCommand.getCommandType().createFn(allocator, cmd_val, context);
                            try compound.addCommand(cmd);
                        } else if (std.mem.eql(u8, type_name, "CompoundCommand")) {
                            const cmd = try CompoundCommand.getCommandType().createFn(allocator, cmd_val, context);
                            try compound.addCommand(cmd);
                        }
                    }
                }
            }

            return &compound.base;
        }

        fn serializeToJson(cmd: *Command, allocator: std.mem.Allocator) anyerror!std.json.Value {
            const compound: *CompoundCommand = @ptrCast(cmd);
            var root = std.json.ObjectMap.init(allocator);

            try root.put("type", std.json.Value{ .string = "CompoundCommand" });
            try root.put("description", std.json.Value{ .string = compound.base.description });

            var cmds_array = std.json.Array.init(allocator);
            for (compound.commands.items) |child_cmd| {
                // Here we need the serializeFn from the registry.
                // We'll use a manual check for now or assume a way to get it.
                if (std.mem.eql(u8, child_cmd.getTypeName(), "SceneTransformCommand")) {
                    try cmds_array.append(try SceneTransformCommand.getCommandType().serializeFn(child_cmd, allocator));
                } else if (std.mem.eql(u8, child_cmd.getTypeName(), "CompoundCommand")) {
                    try cmds_array.append(try CompoundCommand.getCommandType().serializeFn(child_cmd, allocator));
                }
            }
            try root.put("commands", std.json.Value{ .array = cmds_array });

            return std.json.Value{ .object = root };
        }
    };

    /// Command type information for serialization
    pub const CommandType = struct {
        name: []const u8,
        createFn: *const fn (std.mem.Allocator, std.json.Value, ?*anyopaque) anyerror!*Command,
        serializeFn: *const fn (*Command, std.mem.Allocator) anyerror!std.json.Value,
    };

    /// Initialize the undo/redo system
    pub fn init(allocator: std.mem.Allocator) UndoRedoSystem {
        var self = UndoRedoSystem{
            .allocator = allocator,
            .undo_stack = std.ArrayList(*Command).initCapacity(allocator, 0) catch unreachable,
            .redo_stack = std.ArrayList(*Command).initCapacity(allocator, 0) catch unreachable,
            .max_history_size = 100,
            .current_compound = null,
            .command_types = std.StringHashMap(CommandType).init(allocator),
        };

        // Register default command types
        self.registerCommandType("SceneTransformCommand", SceneTransformCommand.getCommandType()) catch {};
        self.registerCommandType("CompoundCommand", CompoundCommand.getCommandType()) catch {};
        self.registerCommandType("AddObjectCommand", AddObjectCommand.getCommandType()) catch {};
        self.registerCommandType("RemoveObjectCommand", RemoveObjectCommand.getCommandType()) catch {};

        return self;
    }

    /// Deinitialize the undo/redo system
    pub fn deinit(self: *UndoRedoSystem) void {
        // Clean up all commands in stacks
        for (self.undo_stack.items) |cmd| {
            cmd.deinit(self.allocator);
        }
        self.undo_stack.deinit(self.allocator);

        for (self.redo_stack.items) |cmd| {
            cmd.deinit(self.allocator);
        }
        self.redo_stack.deinit(self.allocator);

        // Clean up compound command if active
        if (self.current_compound) |compound| {
            compound.deinit(self.allocator);
        }

        self.command_types.deinit();
    }

    /// Execute and store a command
    pub fn execute(self: *UndoRedoSystem, command: *Command) !void {
        // Set command ID
        command.id = self.undo_stack.items.len;

        // Execute the command
        try command.execute();

        // Add to undo stack
        try self.undo_stack.append(self.allocator, command);

        // Clear redo stack
        for (self.redo_stack.items) |cmd| {
            cmd.deinit(self.allocator);
        }
        self.redo_stack.clearRetainingCapacity();

        // Enforce history size limit
        while (self.undo_stack.items.len > self.max_history_size) {
            const old_cmd = self.undo_stack.orderedRemove(0);
            old_cmd.deinit(self.allocator);
        }
    }

    /// Undo the last command
    pub fn undo(self: *UndoRedoSystem) !bool {
        if (self.undo_stack.items.len == 0) return false;

        const command = self.undo_stack.pop();
        try command.undo();

        // Move to redo stack
        try self.redo_stack.append(self.allocator, command);

        return true;
    }

    /// Redo the last undone command
    pub fn redo(self: *UndoRedoSystem) !bool {
        if (self.redo_stack.items.len == 0) return false;

        const command = self.redo_stack.pop();
        try command.execute();

        // Move back to undo stack
        try self.undo_stack.append(self.allocator, command);

        return true;
    }

    /// Start a compound command (group multiple operations)
    pub fn beginCompound(self: *UndoRedoSystem, description: []const u8) !void {
        if (self.current_compound != null) {
            return error.CompoundAlreadyActive;
        }

        self.current_compound = try CompoundCommand.init(self.allocator, description);
    }

    /// End the current compound command
    pub fn endCompound(self: *UndoRedoSystem) !void {
        if (self.current_compound) |compound| {
            if (compound.commands.items.len > 0) {
                try self.execute(&compound.base);
            } else {
                compound.deinit(self.allocator);
            }
            self.current_compound = null;
        }
    }

    /// Add a command to the current compound (if active)
    pub fn addToCompound(self: *UndoRedoSystem, command: *Command) !void {
        if (self.current_compound) |compound| {
            try compound.addCommand(command);
        } else {
            try self.execute(command);
        }
    }

    /// Check if undo is available
    pub fn canUndo(self: *const UndoRedoSystem) bool {
        return self.undo_stack.items.len > 0;
    }

    /// Check if redo is available
    pub fn canRedo(self: *const UndoRedoSystem) bool {
        return self.redo_stack.items.len > 0;
    }

    /// Get the description of the next undo command
    pub fn getUndoDescription(self: *const UndoRedoSystem) ?[]const u8 {
        if (self.undo_stack.items.len > 0) {
            return self.undo_stack.items[self.undo_stack.items.len - 1].description;
        }
        return null;
    }

    /// Get the description of the next redo command
    pub fn getRedoDescription(self: *const UndoRedoSystem) ?[]const u8 {
        if (self.redo_stack.items.len > 0) {
            return self.redo_stack.items[self.redo_stack.items.len - 1].description;
        }
        return null;
    }

    /// Clear all history
    pub fn clearHistory(self: *UndoRedoSystem) void {
        for (self.undo_stack.items) |cmd| {
            cmd.deinit(self.allocator);
        }
        self.undo_stack.clearRetainingCapacity();

        for (self.redo_stack.items) |cmd| {
            cmd.deinit(self.allocator);
        }
        self.redo_stack.clearRetainingCapacity();
    }

    /// Get memory usage statistics
    pub fn getMemoryStats(self: *const UndoRedoSystem) struct {
        undo_commands: usize,
        redo_commands: usize,
        total_memory: usize,
    } {
        var total_memory: usize = 0;

        for (self.undo_stack.items) |cmd| {
            total_memory += cmd.getMemoryUsage();
        }

        for (self.redo_stack.items) |cmd| {
            total_memory += cmd.getMemoryUsage();
        }

        return .{
            .undo_commands = self.undo_stack.items.len,
            .redo_commands = self.redo_stack.items.len,
            .total_memory = total_memory,
        };
    }

    /// Register a command type for serialization
    pub fn registerCommandType(self: *UndoRedoSystem, name: []const u8, command_type: CommandType) !void {
        try self.command_types.put(name, command_type);
    }

    /// Serialize command history to JSON
    pub fn serializeHistory(self: *const UndoRedoSystem, allocator: std.mem.Allocator) !std.json.Value {
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        var undo_array = std.ArrayList(std.json.Value).initCapacity(arena_allocator, 0) catch unreachable;
        for (self.undo_stack.items) |cmd| {
            if (self.getCommandType(cmd)) |cmd_type| {
                const serialized = try cmd_type.serializeFn(cmd, arena_allocator);
                try undo_array.append(arena_allocator, serialized);
            }
        }

        var root = std.json.ObjectMap.init(arena_allocator);
        try root.put("undo_stack", std.json.Value{ .array = undo_array });
        try root.put("max_history_size", std.json.Value{ .integer = @intCast(self.max_history_size) });

        return std.json.Value{ .object = root };
    }

    /// Deserialize command history from JSON
    pub fn deserializeHistory(self: *UndoRedoSystem, json_value: std.json.Value, context: ?*anyopaque) !void {
        const root = json_value.object;

        // Clear current history
        self.clearHistory();

        // Load max history size
        if (root.get("max_history_size")) |size_val| {
            self.max_history_size = @intCast(size_val.integer);
        }

        // Load undo stack
        if (root.get("undo_stack")) |undo_val| {
            for (undo_val.array.items) |cmd_val| {
                if (cmd_val.object.get("type")) |type_val| {
                    const type_name = type_val.string;
                    if (self.command_types.get(type_name)) |cmd_type| {
                        const command = try cmd_type.createFn(self.allocator, cmd_val, context);
                        try self.undo_stack.append(self.allocator, command);
                    }
                }
            }
        }
    }

    /// Helper to get command type from command instance
    fn getCommandType(self: *const UndoRedoSystem, command: *Command) ?CommandType {
        const type_name = command.getTypeName();
        return self.command_types.get(type_name);
    }
};

// ============================================================================
// Pre-built Command Types
// ============================================================================

/// Scene transform command (move, rotate, scale entities)
pub const SceneTransformCommand = struct {
    base: UndoRedoSystem.Command,
    scene: *nyon.Scene,
    entity_id: usize,
    old_position: nyon.Vector3,
    old_rotation: nyon.Vector3,
    old_scale: nyon.Vector3,
    new_position: nyon.Vector3,
    new_rotation: nyon.Vector3,
    new_scale: nyon.Vector3,

    pub fn create(allocator: std.mem.Allocator, scene: *nyon.Scene, entity_id: usize, description: []const u8) !*SceneTransformCommand {
        const desc_copy = try allocator.dupe(u8, description);
        errdefer allocator.free(desc_copy);

        // Get current transform
        var old_pos = nyon.Vector3{ .x = 0, .y = 0, .z = 0 };
        var old_rot = nyon.Vector3{ .x = 0, .y = 0, .z = 0 };
        var old_scl = nyon.Vector3{ .x = 1, .y = 1, .z = 1 };

        if (scene.getModelInfo(entity_id)) |info| {
            old_pos = info.position;
            old_rot = info.rotation;
            old_scl = info.scale;
        }

        const command = try allocator.create(SceneTransformCommand);
        errdefer allocator.destroy(command);

        command.* = .{
            .base = .{
                .id = 0,
                .description = desc_copy,
                .vtable = &vtable,
            },
            .scene = scene,
            .entity_id = entity_id,
            .old_position = old_pos,
            .old_rotation = old_rot,
            .old_scale = old_scl,
            .new_position = old_pos,
            .new_rotation = old_rot,
            .new_scale = old_scl,
        };

        return command;
    }

    pub fn setNewTransform(cmd: *SceneTransformCommand, position: nyon.Vector3, rotation: nyon.Vector3, scale: nyon.Vector3) void {
        cmd.new_position = position;
        cmd.new_rotation = rotation;
        cmd.new_scale = scale;
    }

    const vtable = UndoRedoSystem.Command.VTable{
        .execute = executeImpl,
        .undo = undoImpl,
        .deinit = deinitImpl,
        .clone = cloneImpl,
        .getMemoryUsage = getMemoryUsageImpl,
        .getTypeName = getTypeNameImpl,
    };

    pub fn getCommandType() UndoRedoSystem.CommandType {
        return .{
            .name = "SceneTransformCommand",
            .createFn = createFromJson,
            .serializeFn = serializeToJson,
        };
    }

    fn createFromJson(allocator: std.mem.Allocator, json_value: std.json.Value, context: ?*anyopaque) anyerror!*UndoRedoSystem.Command {
        const root = json_value.object;
        const description = if (root.get("description")) |d| d.string else "Scene Transform";
        const entity_id = if (root.get("entity_id")) |id| @as(usize, @intCast(id.integer)) else 0;

        if (context == null) return error.SceneReferenceMissing;
        const scene_ptr: *nyon.Scene = @ptrCast(@alignCast(context.?));

        const command = try SceneTransformCommand.create(allocator, scene_ptr, entity_id, description);
        errdefer command.deinitImpl(@ptrCast(command), allocator);

        // helper to parse Vector3
        const parseVec3 = struct {
            fn parse(val: ?std.json.Value) nyon.Vector3 {
                if (val) |v| {
                    const obj = v.object;
                    return .{
                        .x = @floatCast(if (obj.get("x")) |x| x.float else 0),
                        .y = @floatCast(if (obj.get("y")) |y| y.float else 0),
                        .z = @floatCast(if (obj.get("z")) |z| z.float else 0),
                    };
                }
                return .{ .x = 0, .y = 0, .z = 0 };
            }
        }.parse;

        command.old_position = parseVec3(root.get("old_position"));
        command.old_rotation = parseVec3(root.get("old_rotation"));
        command.old_scale = parseVec3(root.get("old_scale"));
        command.new_position = parseVec3(root.get("new_position"));
        command.new_rotation = parseVec3(root.get("new_rotation"));
        command.new_scale = parseVec3(root.get("new_scale"));

        return &command.base;
    }

    fn serializeToJson(cmd: *UndoRedoSystem.Command, allocator: std.mem.Allocator) anyerror!std.json.Value {
        const self: *SceneTransformCommand = @ptrCast(@alignCast(cmd.impl_ptr));
        var root = std.json.ObjectMap.init(allocator);

        try root.put("type", std.json.Value{ .string = "SceneTransformCommand" });
        try root.put("description", std.json.Value{ .string = self.base.description });
        try root.put("entity_id", std.json.Value{ .integer = @intCast(self.entity_id) });

        // helper to serialize Vector3
        const serializeVec3 = struct {
            fn serialize(a: std.mem.Allocator, vec: nyon.Vector3) !std.json.Value {
                var obj = std.json.ObjectMap.init(a);
                try obj.put("x", std.json.Value{ .float = vec.x });
                try obj.put("y", std.json.Value{ .float = vec.y });
                try obj.put("z", std.json.Value{ .float = vec.z });
                return std.json.Value{ .object = obj };
            }
        }.serialize;

        try root.put("old_position", try serializeVec3(allocator, self.old_position));
        try root.put("old_rotation", try serializeVec3(allocator, self.old_rotation));
        try root.put("old_scale", try serializeVec3(allocator, self.old_scale));
        try root.put("new_position", try serializeVec3(allocator, self.new_position));
        try root.put("new_rotation", try serializeVec3(allocator, self.new_rotation));
        try root.put("new_scale", try serializeVec3(allocator, self.new_scale));

        return std.json.Value{ .object = root };
    }

    fn executeImpl(cmd: *anyopaque) !void {
        const self: *SceneTransformCommand = @ptrCast(@alignCast(cmd));
        self.scene.setPosition(self.entity_id, self.new_position);
        self.scene.setRotation(self.entity_id, self.new_rotation);
        self.scene.setScale(self.entity_id, self.new_scale);
    }

    fn undoImpl(cmd: *anyopaque) !void {
        const self: *SceneTransformCommand = @ptrCast(@alignCast(cmd));
        self.scene.setPosition(self.entity_id, self.old_position);
        self.scene.setRotation(self.entity_id, self.old_rotation);
        self.scene.setScale(self.entity_id, self.old_scale);
    }

    fn deinitImpl(cmd: *anyopaque, allocator: std.mem.Allocator) void {
        const self: *SceneTransformCommand = @ptrCast(@alignCast(cmd));
        allocator.free(self.base.description);
        allocator.destroy(self);
    }

    fn cloneImpl(cmd: *anyopaque, allocator: std.mem.Allocator) !*UndoRedoSystem.Command {
        const self: *SceneTransformCommand = @ptrCast(@alignCast(cmd));
        const cloned = try SceneTransformCommand.create(allocator, self.scene, self.entity_id, self.base.description);
        cloned.new_position = self.new_position;
        cloned.new_rotation = self.new_rotation;
        cloned.new_scale = self.new_scale;
        return &cloned.base;
    }

    fn getMemoryUsageImpl(cmd: *anyopaque) usize {
        const self: *SceneTransformCommand = @ptrCast(@alignCast(cmd));
        return @sizeOf(SceneTransformCommand) + self.base.description.len;
    }

    fn getTypeNameImpl(_: *anyopaque) []const u8 {
        return "SceneTransformCommand";
    }
};

/// Command to add an object to the scene
pub const AddObjectCommand = struct {
    base: UndoRedoSystem.Command,
    scene: *nyon.Scene,
    asset_mgr: *nyon.AssetManager,
    ecs_world: *nyon.ecs.World,
    physics_system: *nyon.ecs.PhysicsSystem,
    model_path: []const u8,
    position: nyon.Vector3,
    added_index: ?usize,
    entity: ?nyon.ecs.EntityId,

    pub fn create(allocator: std.mem.Allocator, scene: *nyon.Scene, asset_mgr: *nyon.AssetManager, ecs_world: *nyon.ecs.World, physics_system: *nyon.ecs.PhysicsSystem, model_path: []const u8, position: nyon.Vector3, description: []const u8) !*AddObjectCommand {
        const self = try allocator.create(AddObjectCommand);
        self.* = .{
            .base = .{
                .vtable = &UndoRedoSystem.Command.VTable{
                    .execute = executeImpl,
                    .undo = undoImpl,
                    .deinit = deinitImpl,
                    .clone = cloneImpl,
                    .getMemoryUsage = getMemoryUsageImpl,
                    .getTypeName = getTypeNameImpl,
                },
                .description = try allocator.dupe(u8, description),
            },
            .scene = scene,
            .asset_mgr = asset_mgr,
            .ecs_world = ecs_world,
            .physics_system = physics_system,
            .model_path = try allocator.dupe(u8, model_path),
            .position = position,
            .added_index = null,
            .entity = null,
        };
        return self;
    }

    pub fn createFromJson(allocator: std.mem.Allocator, json_value: std.json.Value, context: ?*anyopaque) !*UndoRedoSystem.Command {
        const ctx = context orelse return error.MissingContext;
        // In this implementation, context should be a pointer to a struct containing scene and asset_mgr
        const EditorContext = struct {
            scene: *nyon.Scene,
            asset_mgr: *nyon.AssetManager,
            ecs_world: *nyon.ecs.World,
            physics_system: *nyon.ecs.PhysicsSystem,
        };
        const editor_ctx: *const EditorContext = @ptrCast(@alignCast(ctx));

        const obj = json_value.object;
        const description = obj.get("description").?.string;
        const model_path = obj.get("model_path").?.string;

        const pos_obj = obj.get("position").?.object;
        const position = nyon.Vector3{
            .x = @floatCast(pos_obj.get("x").?.float),
            .y = @floatCast(pos_obj.get("y").?.float),
            .z = @floatCast(pos_obj.get("z").?.float),
        };

        const cmd = try create(allocator, editor_ctx.scene, editor_ctx.asset_mgr, editor_ctx.ecs_world, editor_ctx.physics_system, model_path, position, description);
        return &cmd.base;
    }

    pub fn serialize(cmd: *UndoRedoSystem.Command, allocator: std.mem.Allocator) !std.json.Value {
        const self: *AddObjectCommand = @ptrCast(@alignCast(cmd));
        var root = std.json.ObjectMap.init(allocator);
        try root.put("type", std.json.Value{ .string = "AddObjectCommand" });
        try root.put("description", std.json.Value{ .string = self.base.description });
        try root.put("model_path", std.json.Value{ .string = self.model_path });

        var pos_obj = std.json.ObjectMap.init(allocator);
        try pos_obj.put("x", std.json.Value{ .float = self.position.x });
        try pos_obj.put("y", std.json.Value{ .float = self.position.y });
        try pos_obj.put("z", std.json.Value{ .float = self.position.z });
        try root.put("position", std.json.Value{ .object = pos_obj });

        return std.json.Value{ .object = root };
    }

    fn executeImpl(cmd: *anyopaque) !void {
        const self: *AddObjectCommand = @ptrCast(@alignCast(cmd));
        // Use a default LoadOptions
        const model = try self.asset_mgr.loadModel(self.model_path, .{});
        // We need to convert nyon.Vector3 to raylib.Vector3
        const rl_pos = nyon.raylib.Vector3{ .x = self.position.x, .y = self.position.y, .z = self.position.z };
        self.added_index = try self.scene.addModel(model, rl_pos);

        // ECS and Physics integration
        const entity = try self.ecs_world.createEntity();
        self.entity = entity;
        try self.ecs_world.addComponent(entity, nyon.ecs.Transform{
            .position = self.position,
            .rotation = .{ .x = 0, .y = 0, .z = 0, .w = 1 },
            .scale = .{ .x = 1, .y = 1, .z = 1 },
        });

        // Add default physics components
        // Simplified dynamic body for visual objects
        const rigid_body = nyon.ecs.RigidBody{
            .mass = 1.0,
            .inverse_mass = 1.0,
            .is_static = false,
            .is_kinematic = false,
            .linear_velocity = .{ .x = 0, .y = 0, .z = 0 },
            .angular_velocity = .{ .x = 0, .y = 0, .z = 0 },
            .linear_damping = 0.1,
            .angular_damping = 0.1,
            .gravity_scale = 1.0,
            .restitution = 0.5,
            .friction = 0.5,
        };
        try self.ecs_world.addComponent(entity, rigid_body);

        // Add a default sphere collider (approximate)
        const collider = nyon.ecs.Collider{
            .shape = .sphere,
            .offset = .{ .x = 0, .y = 0, .z = 0 },
            .sphere_radius = 1.0, // Default radius
            .is_trigger = false,
        };
        try self.ecs_world.addComponent(entity, collider);

        // Register with physics system
        // Note: We need some way to convert nyon.ecs.RigidBody/Collider to physics equivalents if names don't match
        // Assuming they match for now or PhysicsSystem handles them
        _ = self.physics_system; // Will implement properly in PhysicsSystem.addEntityPhysics
    }

    fn undoImpl(cmd: *anyopaque) !void {
        const self: *AddObjectCommand = @ptrCast(@alignCast(cmd));
        if (self.added_index) |idx| {
            self.scene.removeModel(idx);
            self.added_index = null;
        }
        if (self.entity) |entity| {
            self.physics_system.removeRigidBody(entity);
            self.ecs_world.destroyEntity(entity);
            self.entity = null;
        }
    }

    fn deinitImpl(cmd: *anyopaque, allocator: std.mem.Allocator) void {
        const self: *AddObjectCommand = @ptrCast(@alignCast(cmd));
        allocator.free(self.base.description);
        allocator.free(self.model_path);
        allocator.destroy(self);
    }

    fn cloneImpl(cmd: *anyopaque, allocator: std.mem.Allocator) !*UndoRedoSystem.Command {
        const self: *AddObjectCommand = @ptrCast(@alignCast(cmd));
        const cloned = try create(allocator, self.scene, self.asset_mgr, self.ecs_world, self.physics_system, self.model_path, self.position, self.base.description);
        return &cloned.base;
    }

    fn getMemoryUsageImpl(cmd: *anyopaque) usize {
        const self: *AddObjectCommand = @ptrCast(@alignCast(cmd));
        return @sizeOf(AddObjectCommand) + self.base.description.len + self.model_path.len;
    }

    fn getTypeNameImpl(_: *anyopaque) []const u8 {
        return "AddObjectCommand";
    }

    pub fn getCommandType() UndoRedoSystem.CommandType {
        return .{
            .name = "AddObjectCommand",
            .createFn = createFromJson,
            .serializeFn = serialize,
        };
    }
};

/// Command to remove an object from the scene
pub const RemoveObjectCommand = struct {
    base: UndoRedoSystem.Command,
    scene: *nyon.Scene,
    asset_mgr: *nyon.AssetManager,
    ecs_world: *nyon.ecs.World,
    physics_system: *nyon.ecs.PhysicsSystem,
    model_path: []const u8,
    position: nyon.Vector3,
    index: usize,
    removed_model: ?nyon.raylib.Model,
    entity: ?nyon.ecs.EntityId,

    pub fn create(allocator: std.mem.Allocator, scene: *nyon.Scene, asset_mgr: *nyon.AssetManager, ecs_world: *nyon.ecs.World, physics_system: *nyon.ecs.PhysicsSystem, index: usize, description: []const u8) !*RemoveObjectCommand {
        const info = scene.getModelInfo(index) orelse return error.IndexOutOfBounds;

        // We need to know where this model came from to restore it.
        // For now, we'll assume it's stored in metadata if not provided?
        // Actually, let's just use a placeholder path if unknown.
        const model_path = "assets/models/unknown.obj"; // Simplified

        const self = try allocator.create(RemoveObjectCommand);
        self.* = .{
            .base = .{
                .vtable = &UndoRedoSystem.Command.VTable{
                    .execute = executeImpl,
                    .undo = undoImpl,
                    .deinit = deinitImpl,
                    .clone = cloneImpl,
                    .getMemoryUsage = getMemoryUsageImpl,
                    .getTypeName = getTypeNameImpl,
                },
                .description = try allocator.dupe(u8, description),
            },
            .scene = scene,
            .asset_mgr = asset_mgr,
            .ecs_world = ecs_world,
            .physics_system = physics_system,
            .model_path = try allocator.dupe(u8, model_path),
            .position = nyon.Vector3{ .x = info.position.x, .y = info.position.y, .z = info.position.z },
            .index = index,
            .removed_model = null,
            .entity = null,
        };
        return self;
    }

    pub fn createFromJson(allocator: std.mem.Allocator, json_value: std.json.Value, context: ?*anyopaque) !*UndoRedoSystem.Command {
        const ctx = context orelse return error.MissingContext;
        const EditorContext = struct {
            scene: *nyon.Scene,
            asset_mgr: *nyon.AssetManager,
            ecs_world: *nyon.ecs.World,
            physics_system: *nyon.ecs.PhysicsSystem,
        };
        const editor_ctx: *const EditorContext = @ptrCast(@alignCast(ctx));

        const obj = json_value.object;
        const description = obj.get("description").?.string;
        const model_path = obj.get("model_path").?.string;
        const index = @as(usize, @intCast(obj.get("index").?.integer));

        const pos_obj = obj.get("position").?.object;
        const position = nyon.Vector3{
            .x = @floatCast(pos_obj.get("x").?.float),
            .y = @floatCast(pos_obj.get("y").?.float),
            .z = @floatCast(pos_obj.get("z").?.float),
        };

        const cmd = try allocator.create(RemoveObjectCommand);
        cmd.* = .{
            .base = .{
                .vtable = &UndoRedoSystem.Command.VTable{
                    .execute = executeImpl,
                    .undo = undoImpl,
                    .deinit = deinitImpl,
                    .clone = cloneImpl,
                    .getMemoryUsage = getMemoryUsageImpl,
                    .getTypeName = getTypeNameImpl,
                },
                .description = try allocator.dupe(u8, description),
            },
            .scene = editor_ctx.scene,
            .asset_mgr = editor_ctx.asset_mgr,
            .ecs_world = editor_ctx.ecs_world,
            .physics_system = editor_ctx.physics_system,
            .model_path = try allocator.dupe(u8, model_path),
            .position = position,
            .index = index,
            .removed_model = null,
            .entity = null,
        };
        return &cmd.base;
    }

    pub fn serialize(cmd: *UndoRedoSystem.Command, allocator: std.mem.Allocator) !std.json.Value {
        const self: *RemoveObjectCommand = @ptrCast(@alignCast(cmd));
        var root = std.json.ObjectMap.init(allocator);
        try root.put("type", std.json.Value{ .string = "RemoveObjectCommand" });
        try root.put("description", std.json.Value{ .string = self.base.description });
        try root.put("model_path", std.json.Value{ .string = self.model_path });
        try root.put("index", std.json.Value{ .integer = @intCast(self.index) });

        var pos_obj = std.json.ObjectMap.init(allocator);
        try pos_obj.put("x", std.json.Value{ .float = self.position.x });
        try pos_obj.put("y", std.json.Value{ .float = self.position.y });
        try pos_obj.put("z", std.json.Value{ .float = self.position.z });
        try root.put("position", std.json.Value{ .object = pos_obj });

        return std.json.Value{ .object = root };
    }

    fn executeImpl(cmd: *anyopaque) !void {
        const self: *RemoveObjectCommand = @ptrCast(@alignCast(cmd));
        self.scene.removeModel(self.index);

        // ECS and Physics integration
        var query = self.ecs_world.createQuery();
        defer query.deinit();
        var transform_query = try query.with(nyon.ecs.Transform).build();
        defer transform_query.deinit();
        transform_query.updateMatches(self.ecs_world.archetypes.items);
        var iter = transform_query.iter();
        while (iter.next()) |data| {
            if (data.get(nyon.ecs.Transform)) |transform| {
                if (std.meta.eql(transform.position, self.position)) {
                    self.entity = data.entity;
                    break;
                }
            }
        }

        if (self.entity) |entity| {
            self.physics_system.removeRigidBody(entity);
            self.ecs_world.destroyEntity(entity);
        }
    }

    fn undoImpl(cmd: *anyopaque) !void {
        const self: *RemoveObjectCommand = @ptrCast(@alignCast(cmd));
        const model = try self.asset_mgr.loadModel(self.model_path, .{});
        const rl_pos = nyon.raylib.Vector3{ .x = self.position.x, .y = self.position.y, .z = self.position.z };
        _ = try self.scene.addModel(model, rl_pos);

        // Restore ECS/Physics
        const entity = try self.ecs_world.createEntity();
        self.entity = entity;
        try self.ecs_world.addComponent(entity, nyon.ecs.Transform{
            .position = self.position,
            .rotation = .{ .x = 0, .y = 0, .z = 0, .w = 1 },
            .scale = .{ .x = 1, .y = 1, .z = 1 },
        });
        try self.ecs_world.addComponent(entity, nyon.ecs.RigidBody{ .mass = 1.0 });
        try self.ecs_world.addComponent(entity, nyon.ecs.Collider{ .shape = .sphere, .sphere_radius = 1.0 });
    }

    fn deinitImpl(cmd: *anyopaque, allocator: std.mem.Allocator) void {
        const self: *RemoveObjectCommand = @ptrCast(@alignCast(cmd));
        allocator.free(self.base.description);
        allocator.free(self.model_path);
        allocator.destroy(self);
    }

    fn cloneImpl(cmd: *anyopaque, allocator: std.mem.Allocator) !*UndoRedoSystem.Command {
        const self: *RemoveObjectCommand = @ptrCast(@alignCast(cmd));
        const cloned = try create(allocator, self.scene, self.asset_mgr, self.ecs_world, self.physics_system, self.index, self.base.description);
        return &cloned.base;
    }

    fn getMemoryUsageImpl(cmd: *anyopaque) usize {
        const self: *RemoveObjectCommand = @ptrCast(@alignCast(cmd));
        return @sizeOf(RemoveObjectCommand) + self.base.description.len + self.model_path.len;
    }

    fn getTypeNameImpl(_: *anyopaque) []const u8 {
        return "RemoveObjectCommand";
    }

    pub fn getCommandType() UndoRedoSystem.CommandType {
        return .{
            .name = "RemoveObjectCommand",
            .createFn = createFromJson,
            .serializeFn = serialize,
        };
    }
};
