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
            return self.vtable.getMemoryUsage(self);
        }
    };

    /// Compound command for grouping multiple operations
    pub const CompoundCommand = struct {
        base: Command,
        commands: std.ArrayList(*Command),

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
                .commands = std.ArrayList(*Command).init(allocator),
            };

            return compound;
        }

        pub fn deinit(compound: *CompoundCommand, allocator: std.mem.Allocator) void {
            for (compound.commands.items) |cmd| {
                cmd.deinit(allocator);
            }
            compound.commands.deinit();
            allocator.free(compound.base.description);
        }

        pub fn addCommand(compound: *CompoundCommand, command: *Command) !void {
            try compound.commands.append(command);
        }

        const vtable = Command.VTable{
            .execute = executeImpl,
            .undo = undoImpl,
            .deinit = deinitImpl,
            .clone = cloneImpl,
            .getMemoryUsage = getMemoryUsageImpl,
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
                try new_compound.commands.append(cloned_cmd);
            }

            return &new_compound.base;
        }

        fn getMemoryUsageImpl(cmd: *Command) usize {
            const compound: *CompoundCommand = @ptrCast(cmd);
            var total: usize = @sizeOf(CompoundCommand) + compound.base.description.len;
            for (compound.commands.items) |command| {
                total += command.getMemoryUsage();
            }
            return total;
        }
    };

    /// Command type information for serialization
    pub const CommandType = struct {
        name: []const u8,
        createFn: *const fn (std.mem.Allocator, std.json.Value) anyerror!*Command,
        serializeFn: *const fn (*Command, std.mem.Allocator) anyerror!std.json.Value,
    };

    /// Initialize the undo/redo system
    pub fn init(allocator: std.mem.Allocator) UndoRedoSystem {
        return .{
            .allocator = allocator,
            .undo_stack = std.ArrayList(*Command).init(allocator),
            .redo_stack = std.ArrayList(*Command).init(allocator),
            .max_history_size = 100,
            .current_compound = null,
            .command_types = std.StringHashMap(CommandType).init(allocator),
        };
    }

    /// Deinitialize the undo/redo system
    pub fn deinit(self: *UndoRedoSystem) void {
        // Clean up all commands in stacks
        for (self.undo_stack.items) |cmd| {
            cmd.deinit(self.allocator);
        }
        self.undo_stack.deinit();

        for (self.redo_stack.items) |cmd| {
            cmd.deinit(self.allocator);
        }
        self.redo_stack.deinit();

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
        try self.undo_stack.append(command);

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
        try self.redo_stack.append(command);

        return true;
    }

    /// Redo the last undone command
    pub fn redo(self: *UndoRedoSystem) !bool {
        if (self.redo_stack.items.len == 0) return false;

        const command = self.redo_stack.pop();
        try command.execute();

        // Move back to undo stack
        try self.undo_stack.append(command);

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

        var undo_array = std.ArrayList(std.json.Value).init(arena_allocator);
        for (self.undo_stack.items) |cmd| {
            if (self.getCommandType(cmd)) |cmd_type| {
                const serialized = try cmd_type.serializeFn(cmd, arena_allocator);
                try undo_array.append(serialized);
            }
        }

        var root = std.json.ObjectMap.init(arena_allocator);
        try root.put("undo_stack", std.json.Value{ .array = undo_array });
        try root.put("max_history_size", std.json.Value{ .integer = @intCast(self.max_history_size) });

        return std.json.Value{ .object = root };
    }

    /// Deserialize command history from JSON
    pub fn deserializeHistory(self: *UndoRedoSystem, json_value: std.json.Value) !void {
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
                        const command = try cmd_type.createFn(self.allocator, cmd_val);
                        try self.undo_stack.append(command);
                    }
                }
            }
        }
    }

    /// Helper to get command type from command instance
    fn getCommandType(self: *const UndoRedoSystem, command: *Command) ?CommandType {
        _ = self;
        _ = command;
        // This would need to be implemented based on command type identification
        // For now, return null (serialization not fully implemented)
        return null;
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
    };

    fn executeImpl(cmd: *UndoRedoSystem.Command) !void {
        const self: *SceneTransformCommand = @ptrCast(cmd);
        self.scene.setPosition(self.entity_id, self.new_position);
        self.scene.setRotation(self.entity_id, self.new_rotation);
        self.scene.setScale(self.entity_id, self.new_scale);
    }

    fn undoImpl(cmd: *UndoRedoSystem.Command) !void {
        const self: *SceneTransformCommand = @ptrCast(cmd);
        self.scene.setPosition(self.entity_id, self.old_position);
        self.scene.setRotation(self.entity_id, self.old_rotation);
        self.scene.setScale(self.entity_id, self.old_scale);
    }

    fn deinitImpl(cmd: *UndoRedoSystem.Command, allocator: std.mem.Allocator) void {
        const self: *SceneTransformCommand = @ptrCast(cmd);
        allocator.free(self.base.description);
        allocator.destroy(self);
    }

    fn cloneImpl(cmd: *UndoRedoSystem.Command, allocator: std.mem.Allocator) !*UndoRedoSystem.Command {
        const self: *SceneTransformCommand = @ptrCast(cmd);
        const cloned = try SceneTransformCommand.create(allocator, self.scene, self.entity_id, self.base.description);
        cloned.new_position = self.new_position;
        cloned.new_rotation = self.new_rotation;
        cloned.new_scale = self.new_scale;
        return &cloned.base;
    }

    fn getMemoryUsageImpl(cmd: *UndoRedoSystem.Command) usize {
        const self: *SceneTransformCommand = @ptrCast(cmd);
        return @sizeOf(SceneTransformCommand) + self.base.description.len;
    }
};
