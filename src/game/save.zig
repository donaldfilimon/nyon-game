//! Save/Load World System
//!
//! Binary save format for persisting game state including world chunks,
//! player data, and game statistics. Supports auto-save, quick save,
//! and background saving for smooth gameplay.

const std = @import("std");
const math = @import("../math/math.zig");
const world_mod = @import("world.zig");
const inventory_mod = @import("inventory.zig");
const items_mod = @import("items.zig");
const player_mod = @import("player.zig");

const BlockWorld = world_mod.BlockWorld;
const Block = world_mod.Block;
const Chunk = world_mod.Chunk;
const CHUNK_SIZE = world_mod.CHUNK_SIZE;
const CHUNK_VOLUME = world_mod.CHUNK_VOLUME;
const Inventory = inventory_mod.Inventory;
const ItemStack = inventory_mod.ItemStack;
const INVENTORY_SIZE = inventory_mod.INVENTORY_SIZE;
const HOTBAR_SIZE = inventory_mod.HOTBAR_SIZE;
const ARMOR_SIZE = inventory_mod.ARMOR_SIZE;
const PlayerController = player_mod.PlayerController;
const Vec3 = math.Vec3;

// ============================================================================
// Save Format Constants
// ============================================================================

/// Magic bytes identifying Nyon save files
pub const SAVE_MAGIC: [4]u8 = .{ 'N', 'Y', 'O', 'N' };

/// Current save format version
pub const SAVE_VERSION: u32 = 1;

/// Auto-save interval in seconds (5 minutes)
pub const AUTO_SAVE_INTERVAL: f32 = 300.0;

/// Maximum world name length
pub const MAX_WORLD_NAME: usize = 64;

// ============================================================================
// Save Data Structures
// ============================================================================

/// Game mode enum
pub const GameMode = enum(u8) {
    survival = 0,
    creative = 1,
    adventure = 2,
    spectator = 3,
};

/// Header for save files
pub const SaveHeader = struct {
    magic: [4]u8 = SAVE_MAGIC,
    version: u32 = SAVE_VERSION,
    world_seed: u64,
    player_position: [3]f32,
    player_rotation: [2]f32, // yaw, pitch
    time_of_day: f32,
    game_time: f64, // Total time played in seconds
    chunk_count: u32,
    world_name_len: u8,
    // world_name follows (variable length)
    created_timestamp: i64,
    modified_timestamp: i64,
    flags: u32, // Reserved for future use
};

/// Player data for serialization
pub const PlayerData = struct {
    position: [3]f32,
    rotation: [2]f32, // yaw, pitch
    velocity: [3]f32,
    health: f32,
    max_health: f32,
    hunger: f32,
    max_hunger: f32,
    saturation: f32,
    is_flying: bool,
    game_mode: GameMode,
    hotbar_selection: u8,
};

/// Serializable item stack
pub const SerializedItemStack = struct {
    item_id: u16,
    count: u32,
    durability: u32, // 0xFFFFFFFF = null durability

    pub fn fromItemStack(stack: ?ItemStack) SerializedItemStack {
        if (stack) |s| {
            return .{
                .item_id = s.item_id,
                .count = s.count,
                .durability = s.durability orelse 0xFFFFFFFF,
            };
        }
        return .{
            .item_id = 0,
            .count = 0,
            .durability = 0xFFFFFFFF,
        };
    }

    pub fn toItemStack(self: SerializedItemStack) ?ItemStack {
        if (self.count == 0) return null;
        var stack = ItemStack.init(self.item_id, self.count);
        if (self.durability != 0xFFFFFFFF) {
            stack.durability = self.durability;
        }
        return stack;
    }
};

/// Chunk header for save files
pub const ChunkHeader = struct {
    x: i32,
    y: i32,
    z: i32,
    compressed_size: u32, // 0 = uncompressed
    flags: u8, // Bit 0: modified by player
};

/// Game state pointers for loading world data
pub const GameStatePointers = struct {
    health: *f32,
    max_health: *f32,
    hunger: *f32,
    max_hunger: *f32,
    saturation: *f32,
    game_mode: *GameMode,
    time_of_day: *f32,
    play_time: *f64,
};

/// Information about a saved world
pub const SaveInfo = struct {
    name: []const u8,
    path: []const u8,
    last_played: i64,
    play_time: f64,
    world_seed: u64,
    file_size: u64,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *SaveInfo) void {
        self.allocator.free(self.name);
        self.allocator.free(self.path);
    }
};

/// Loaded world data
pub const LoadedWorld = struct {
    header: SaveHeader,
    world_name: []const u8,
    player: PlayerData,
    inventory_slots: [INVENTORY_SIZE]?ItemStack,
    armor_slots: [ARMOR_SIZE]?ItemStack,
    chunks: std.ArrayList(LoadedChunk),
    allocator: std.mem.Allocator,

    pub fn deinit(self: *LoadedWorld) void {
        self.allocator.free(self.world_name);
        for (self.chunks.items) |*chunk| {
            chunk.deinit(self.allocator);
        }
        self.chunks.deinit(self.allocator);
    }
};

/// Loaded chunk data
pub const LoadedChunk = struct {
    x: i32,
    y: i32,
    z: i32,
    blocks: []u8,
    modified: bool,

    pub fn deinit(self: *LoadedChunk, allocator: std.mem.Allocator) void {
        allocator.free(self.blocks);
    }
};

// ============================================================================
// Run-Length Encoding for Block Data Compression
// ============================================================================

/// Compress block data using run-length encoding
/// Returns compressed data or null if compression doesn't help
pub fn compressBlocks(allocator: std.mem.Allocator, blocks: []const Block) !?[]u8 {
    var result = std.ArrayList(u8).initCapacity(allocator, blocks.len) catch return null;
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < blocks.len) {
        const current = @intFromEnum(blocks[i]);
        var run_length: u8 = 1;

        // Count consecutive identical blocks (max 255)
        while (i + run_length < blocks.len and
            run_length < 255 and
            @intFromEnum(blocks[i + run_length]) == current)
        {
            run_length += 1;
        }

        // Write: block_type, run_length
        try result.append(allocator, current);
        try result.append(allocator, run_length);

        i += run_length;
    }

    // Only use compression if it actually reduces size
    if (result.items.len < blocks.len) {
        return try result.toOwnedSlice(allocator);
    }

    result.deinit(allocator);
    return null;
}

/// Decompress RLE-encoded block data
pub fn decompressBlocks(allocator: std.mem.Allocator, compressed: []const u8, expected_size: usize) ![]Block {
    var result = try allocator.alloc(Block, expected_size);
    errdefer allocator.free(result);

    var read_pos: usize = 0;
    var write_pos: usize = 0;

    while (read_pos + 1 < compressed.len and write_pos < expected_size) {
        const block_type: Block = @enumFromInt(compressed[read_pos]);
        const run_length = compressed[read_pos + 1];
        read_pos += 2;

        var j: usize = 0;
        while (j < run_length and write_pos < expected_size) : (j += 1) {
            result[write_pos] = block_type;
            write_pos += 1;
        }
    }

    // Fill remaining with air if decompression is short
    while (write_pos < expected_size) : (write_pos += 1) {
        result[write_pos] = .air;
    }

    return result;
}

// ============================================================================
// Save System
// ============================================================================

/// Main save system for managing world persistence
pub const SaveSystem = struct {
    allocator: std.mem.Allocator,
    save_directory: []const u8,
    auto_save_timer: f32,
    auto_save_enabled: bool,
    is_saving: bool,
    last_save_result: ?SaveError,

    const Self = @This();
    const Io = std.Io;
    const Dir = Io.Dir;
    const File = Io.File;
    const Permissions = Dir.Permissions;

    pub const SaveError = error{
        InvalidPath,
        FileWriteError,
        FileReadError,
        InvalidSaveFormat,
        VersionMismatch,
        CorruptedData,
        OutOfMemory,
        AccessDenied,
    };

    /// Get the IO instance for file operations
    fn getIo() Io {
        return std.Io.Threaded.global_single_threaded.io();
    }

    /// Initialize the save system
    pub fn init(allocator: std.mem.Allocator, save_dir: ?[]const u8) Self {
        return .{
            .allocator = allocator,
            .save_directory = save_dir orelse "saves",
            .auto_save_timer = 0,
            .auto_save_enabled = true,
            .is_saving = false,
            .last_save_result = null,
        };
    }

    /// Update auto-save timer
    pub fn update(self: *Self, dt: f32) void {
        if (!self.auto_save_enabled or self.is_saving) return;

        self.auto_save_timer += dt;
    }

    /// Check if auto-save should trigger
    pub fn shouldAutoSave(self: *const Self) bool {
        return self.auto_save_enabled and
            self.auto_save_timer >= AUTO_SAVE_INTERVAL and
            !self.is_saving;
    }

    /// Reset auto-save timer (call after saving)
    pub fn resetAutoSaveTimer(self: *Self) void {
        self.auto_save_timer = 0;
    }

    /// Ensure save directory exists
    pub fn ensureSaveDirectory(self: *Self) !void {
        const io = getIo();
        const cwd = Dir.cwd();
        cwd.createDir(io, self.save_directory, Permissions.default_dir) catch |err| {
            if (err != error.PathAlreadyExists) {
                return SaveError.InvalidPath;
            }
        };
    }

    /// Save the world to a file
    /// If original_created_timestamp is provided (from a loaded world), it will be preserved.
    /// Otherwise, the current time will be used as the creation timestamp.
    pub fn saveWorld(
        self: *Self,
        world: *BlockWorld,
        player: *const PlayerController,
        inventory: *const Inventory,
        game_state: struct {
            health: f32,
            max_health: f32,
            hunger: f32,
            max_hunger: f32,
            saturation: f32,
            game_mode: GameMode,
            time_of_day: f32,
            play_time: f64,
            original_created_timestamp: ?i64 = null,
        },
        world_name: []const u8,
    ) SaveError!void {
        self.is_saving = true;
        defer self.is_saving = false;

        // Ensure save directory exists
        self.ensureSaveDirectory() catch return SaveError.InvalidPath;

        // Build file path
        var path_buf: [512]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "{s}/{s}.nyon", .{ self.save_directory, world_name }) catch {
            return SaveError.InvalidPath;
        };

        // Open file for writing
        const io = getIo();
        var file = Dir.cwd().createFile(io, path, .{}) catch {
            return SaveError.FileWriteError;
        };
        defer file.close(io);

        var write_buf: [4096]u8 = undefined;
        var file_writer = file.writer(io, &write_buf);

        // Write header
        // Get current timestamp using Timer (monotonic time since boot)
        // This gives a consistent ordering for save files within a session
        const now: i64 = blk: {
            var timer = std.time.Timer.start() catch break :blk 0;
            break :blk @intCast(timer.read() / std.time.ns_per_ms);
        };
        const name_len: u8 = @min(@as(u8, @intCast(world_name.len)), MAX_WORLD_NAME);

        const header = SaveHeader{
            .magic = SAVE_MAGIC,
            .version = SAVE_VERSION,
            .world_seed = world.seed,
            .player_position = .{ player.position.x(), player.position.y(), player.position.z() },
            .player_rotation = .{ player.yaw, player.pitch },
            .time_of_day = game_state.time_of_day,
            .game_time = game_state.play_time,
            .chunk_count = @intCast(world.chunks.count()),
            .world_name_len = name_len,
            .created_timestamp = game_state.original_created_timestamp orelse now,
            .modified_timestamp = now,
            .flags = 0,
        };

        // Write header struct
        file_writer.interface.writeAll(std.mem.asBytes(&header)) catch return SaveError.FileWriteError;

        // Write world name
        file_writer.interface.writeAll(world_name[0..name_len]) catch return SaveError.FileWriteError;

        // Write player data
        const player_data = PlayerData{
            .position = .{ player.position.x(), player.position.y(), player.position.z() },
            .rotation = .{ player.yaw, player.pitch },
            .velocity = .{ player.velocity.x(), player.velocity.y(), player.velocity.z() },
            .health = game_state.health,
            .max_health = game_state.max_health,
            .hunger = game_state.hunger,
            .max_hunger = game_state.max_hunger,
            .saturation = game_state.saturation,
            .is_flying = player.is_flying,
            .game_mode = game_state.game_mode,
            .hotbar_selection = inventory.selected_slot,
        };
        file_writer.interface.writeAll(std.mem.asBytes(&player_data)) catch return SaveError.FileWriteError;

        // Write inventory
        for (inventory.slots) |slot| {
            const serialized = SerializedItemStack.fromItemStack(slot);
            file_writer.interface.writeAll(std.mem.asBytes(&serialized)) catch return SaveError.FileWriteError;
        }

        // Write armor
        for (inventory.armor) |slot| {
            const serialized = SerializedItemStack.fromItemStack(slot);
            file_writer.interface.writeAll(std.mem.asBytes(&serialized)) catch return SaveError.FileWriteError;
        }

        // Write chunks
        var chunk_iter = world.chunks.valueIterator();
        while (chunk_iter.next()) |chunk_ptr| {
            const chunk = chunk_ptr.*;

            // Try to compress the chunk data
            const compressed = compressBlocks(self.allocator, &chunk.blocks) catch null;
            defer if (compressed) |c| self.allocator.free(c);

            const chunk_header = ChunkHeader{
                .x = chunk.position[0],
                .y = chunk.position[1],
                .z = chunk.position[2],
                .compressed_size = if (compressed) |c| @intCast(c.len) else 0,
                .flags = if (chunk.is_dirty) 1 else 0,
            };

            file_writer.interface.writeAll(std.mem.asBytes(&chunk_header)) catch return SaveError.FileWriteError;

            if (compressed) |c| {
                // Write compressed data
                file_writer.interface.writeAll(c) catch return SaveError.FileWriteError;
            } else {
                // Write raw block data
                const block_bytes = std.mem.sliceAsBytes(&chunk.blocks);
                file_writer.interface.writeAll(block_bytes) catch return SaveError.FileWriteError;
            }
        }

        // Flush writer to ensure all data is written
        file_writer.flush() catch return SaveError.FileWriteError;

        self.resetAutoSaveTimer();
    }

    /// Load a world from a file
    pub fn loadWorld(self: *Self, world_name: []const u8) SaveError!LoadedWorld {
        // Build file path
        var path_buf: [512]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "{s}/{s}.nyon", .{ self.save_directory, world_name }) catch {
            return SaveError.InvalidPath;
        };

        return self.loadWorldFromPath(path);
    }

    /// Load a world from a specific path
    pub fn loadWorldFromPath(self: *Self, path: []const u8) SaveError!LoadedWorld {
        const io = getIo();
        const cwd = Dir.cwd();
        var file = cwd.openFile(io, path, .{}) catch {
            return SaveError.FileReadError;
        };
        defer file.close(io);

        var read_buf: [4096]u8 = undefined;
        var file_reader = file.reader(io, &read_buf);

        // Read header
        var header: SaveHeader = undefined;
        file_reader.interface.readSliceAll(std.mem.asBytes(&header)) catch return SaveError.FileReadError;

        // Validate magic
        if (!std.mem.eql(u8, &header.magic, &SAVE_MAGIC)) {
            return SaveError.InvalidSaveFormat;
        }

        // Check version
        if (header.version > SAVE_VERSION) {
            return SaveError.VersionMismatch;
        }

        // Read world name
        var name_buf: [MAX_WORLD_NAME]u8 = undefined;
        file_reader.interface.readSliceAll(name_buf[0..header.world_name_len]) catch return SaveError.FileReadError;
        const world_name = self.allocator.dupe(u8, name_buf[0..header.world_name_len]) catch return SaveError.OutOfMemory;
        errdefer self.allocator.free(world_name);

        // Read player data
        var player_data: PlayerData = undefined;
        file_reader.interface.readSliceAll(std.mem.asBytes(&player_data)) catch return SaveError.FileReadError;

        // Read inventory
        var inventory_slots: [INVENTORY_SIZE]?ItemStack = undefined;
        for (&inventory_slots) |*slot| {
            var serialized: SerializedItemStack = undefined;
            file_reader.interface.readSliceAll(std.mem.asBytes(&serialized)) catch return SaveError.FileReadError;
            slot.* = serialized.toItemStack();
        }

        // Read armor
        var armor_slots: [ARMOR_SIZE]?ItemStack = undefined;
        for (&armor_slots) |*slot| {
            var serialized: SerializedItemStack = undefined;
            file_reader.interface.readSliceAll(std.mem.asBytes(&serialized)) catch return SaveError.FileReadError;
            slot.* = serialized.toItemStack();
        }

        // Read chunks
        var chunks = std.ArrayList(LoadedChunk).initCapacity(self.allocator, @intCast(header.chunk_count)) catch return SaveError.OutOfMemory;
        errdefer {
            for (chunks.items) |*chunk| chunk.deinit(self.allocator);
            chunks.deinit(self.allocator);
        }

        var i: u32 = 0;
        while (i < header.chunk_count) : (i += 1) {
            var chunk_header: ChunkHeader = undefined;
            file_reader.interface.readSliceAll(std.mem.asBytes(&chunk_header)) catch return SaveError.FileReadError;

            var blocks: []u8 = undefined;
            if (chunk_header.compressed_size > 0) {
                // Read compressed data
                const compressed = self.allocator.alloc(u8, chunk_header.compressed_size) catch return SaveError.OutOfMemory;
                defer self.allocator.free(compressed);
                file_reader.interface.readSliceAll(compressed) catch return SaveError.FileReadError;

                // Decompress
                const decompressed = decompressBlocks(self.allocator, compressed, CHUNK_VOLUME) catch return SaveError.CorruptedData;
                blocks = std.mem.sliceAsBytes(decompressed);
            } else {
                // Read raw data
                blocks = self.allocator.alloc(u8, CHUNK_VOLUME) catch return SaveError.OutOfMemory;
                file_reader.interface.readSliceAll(blocks) catch {
                    self.allocator.free(blocks);
                    return SaveError.FileReadError;
                };
            }

            chunks.append(self.allocator, .{
                .x = chunk_header.x,
                .y = chunk_header.y,
                .z = chunk_header.z,
                .blocks = blocks,
                .modified = (chunk_header.flags & 1) != 0,
            }) catch return SaveError.OutOfMemory;
        }

        return LoadedWorld{
            .header = header,
            .world_name = world_name,
            .player = player_data,
            .inventory_slots = inventory_slots,
            .armor_slots = armor_slots,
            .chunks = chunks,
            .allocator = self.allocator,
        };
    }

    /// Apply loaded world data to game state
    pub fn applyLoadedWorld(
        self: *Self,
        loaded: *LoadedWorld,
        world: *BlockWorld,
        player: *PlayerController,
        inventory: *Inventory,
        game_state: anytype,
    ) SaveError!void {
        _ = self;

        // Clear existing world chunks
        var iter = world.chunks.valueIterator();
        while (iter.next()) |chunk_ptr| {
            world.allocator.destroy(chunk_ptr.*);
        }
        world.chunks.clearRetainingCapacity();

        // Set world seed
        world.seed = loaded.header.world_seed;

        // Reinitialize terrain generator with loaded seed
        if (world.terrain_gen != null) {
            world.terrain_gen = world_mod.TerrainGenerator.init(world.allocator, loaded.header.world_seed);
        }

        // Load chunks
        for (loaded.chunks.items) |loaded_chunk| {
            const chunk = world.allocator.create(Chunk) catch return SaveError.OutOfMemory;
            chunk.* = Chunk.init(loaded_chunk.x, loaded_chunk.y, loaded_chunk.z);

            // Copy block data
            for (loaded_chunk.blocks, 0..) |block_byte, j| {
                chunk.blocks[j] = @enumFromInt(block_byte);
            }
            chunk.is_dirty = loaded_chunk.modified;

            // Add to world
            const key = chunkKey(loaded_chunk.x, loaded_chunk.y, loaded_chunk.z);
            world.chunks.put(key, chunk) catch return SaveError.OutOfMemory;
        }

        // Apply player state
        player.position = Vec3.init(
            loaded.player.position[0],
            loaded.player.position[1],
            loaded.player.position[2],
        );
        player.yaw = loaded.player.rotation[0];
        player.pitch = loaded.player.rotation[1];
        player.velocity = Vec3.init(
            loaded.player.velocity[0],
            loaded.player.velocity[1],
            loaded.player.velocity[2],
        );
        player.is_flying = loaded.player.is_flying;

        // Apply inventory
        for (loaded.inventory_slots, 0..) |slot, i| {
            inventory.slots[i] = slot;
        }
        for (loaded.armor_slots, 0..) |slot, i| {
            inventory.armor[i] = slot;
        }
        inventory.selected_slot = loaded.player.hotbar_selection;

        // Apply game state
        game_state.health.* = loaded.player.health;
        game_state.max_health.* = loaded.player.max_health;
        game_state.hunger.* = loaded.player.hunger;
        game_state.max_hunger.* = loaded.player.max_hunger;
        game_state.saturation.* = loaded.player.saturation;
        game_state.game_mode.* = loaded.player.game_mode;
        game_state.time_of_day.* = loaded.header.time_of_day;
        game_state.play_time.* = loaded.header.game_time;
    }

    /// List all saved worlds
    pub fn listSaves(self: *Self) ![]SaveInfo {
        var saves = std.ArrayList(SaveInfo).init(self.allocator);
        errdefer {
            for (saves.items) |*s| s.deinit();
            saves.deinit(self.allocator);
        }

        const io = getIo();
        const cwd = Dir.cwd();
        var dir = cwd.openDir(io, self.save_directory, .{ .iterate = true }) catch {
            // Directory doesn't exist, return empty list
            return saves.toOwnedSlice(self.allocator);
        };
        defer dir.close(io);

        var iter = dir.iterate();
        while (iter.next(io) catch null) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".nyon")) continue;

            // Get save info
            var path_buf: [512]u8 = undefined;
            const full_path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ self.save_directory, entry.name }) catch continue;

            const info = self.getSaveInfo(full_path) catch continue;
            saves.append(self.allocator, info) catch continue;
        }

        return saves.toOwnedSlice(self.allocator);
    }

    /// Get info about a specific save file
    pub fn getSaveInfo(self: *Self, path: []const u8) !SaveInfo {
        const io = getIo();
        const cwd = Dir.cwd();
        var file = cwd.openFile(io, path, .{}) catch {
            return SaveError.FileReadError;
        };
        defer file.close(io);

        const stat = file.stat(io) catch return SaveError.FileReadError;
        var read_buf: [4096]u8 = undefined;
        var file_reader = file.reader(io, &read_buf);

        // Read just the header
        var header: SaveHeader = undefined;
        file_reader.interface.readSliceAll(std.mem.asBytes(&header)) catch return SaveError.FileReadError;

        // Validate
        if (!std.mem.eql(u8, &header.magic, &SAVE_MAGIC)) {
            return SaveError.InvalidSaveFormat;
        }

        // Read world name
        var name_buf: [MAX_WORLD_NAME]u8 = undefined;
        file_reader.interface.readSliceAll(name_buf[0..header.world_name_len]) catch return SaveError.FileReadError;

        return SaveInfo{
            .name = try self.allocator.dupe(u8, name_buf[0..header.world_name_len]),
            .path = try self.allocator.dupe(u8, path),
            .last_played = header.modified_timestamp,
            .play_time = header.game_time,
            .world_seed = header.world_seed,
            .file_size = stat.size,
            .allocator = self.allocator,
        };
    }

    /// Delete a save file
    pub fn deleteSave(self: *Self, world_name: []const u8) !void {
        var path_buf: [512]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "{s}/{s}.nyon", .{ self.save_directory, world_name }) catch {
            return SaveError.InvalidPath;
        };

        const io = getIo();
        const cwd = Dir.cwd();
        cwd.deleteFile(io, path) catch {
            return SaveError.FileWriteError;
        };
    }

    /// Check if a save exists
    pub fn saveExists(self: *Self, world_name: []const u8) bool {
        var path_buf: [512]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "{s}/{s}.nyon", .{ self.save_directory, world_name }) catch {
            return false;
        };

        const io = getIo();
        const cwd = Dir.cwd();
        cwd.access(io, path, .{}) catch {
            return false;
        };
        return true;
    }
};

// Helper function to generate chunk key (copied from world.zig)
fn chunkKey(cx: i32, cy: i32, cz: i32) i64 {
    const x: i64 = @intCast(cx);
    const y: i64 = @intCast(cy);
    const z: i64 = @intCast(cz);
    return x + y * 0x100000 + z * 0x10000000000;
}

// ============================================================================
// Tests
// ============================================================================

test "serialized item stack conversion" {
    // Test null conversion
    const null_serialized = SerializedItemStack.fromItemStack(null);
    try std.testing.expectEqual(@as(u32, 0), null_serialized.count);
    try std.testing.expect(null_serialized.toItemStack() == null);

    // Test valid stack conversion
    const stack = ItemStack.init(1, 32);
    const serialized = SerializedItemStack.fromItemStack(stack);
    try std.testing.expectEqual(@as(u16, 1), serialized.item_id);
    try std.testing.expectEqual(@as(u32, 32), serialized.count);

    const restored = serialized.toItemStack();
    try std.testing.expect(restored != null);
    try std.testing.expectEqual(@as(u16, 1), restored.?.item_id);
    try std.testing.expectEqual(@as(u32, 32), restored.?.count);
}

test "block compression roundtrip" {
    const allocator = std.testing.allocator;

    // Create test data with runs
    var blocks: [64]Block = undefined;
    for (&blocks, 0..) |*b, i| {
        if (i < 32) {
            b.* = .stone;
        } else {
            b.* = .air;
        }
    }

    // Compress
    const compressed = try compressBlocks(allocator, &blocks);
    if (compressed) |c| {
        defer allocator.free(c);

        // Decompress
        const decompressed = try decompressBlocks(allocator, c, 64);
        defer allocator.free(decompressed);

        // Verify
        for (blocks, 0..) |expected, i| {
            try std.testing.expectEqual(expected, decompressed[i]);
        }
    }
}

test "save system init" {
    const allocator = std.testing.allocator;
    var save_system = SaveSystem.init(allocator, null);

    try std.testing.expectEqual(@as(f32, 0), save_system.auto_save_timer);
    try std.testing.expect(save_system.auto_save_enabled);
    try std.testing.expect(!save_system.is_saving);
}

test "auto save timing" {
    const allocator = std.testing.allocator;
    var save_system = SaveSystem.init(allocator, null);

    // Should not trigger initially
    try std.testing.expect(!save_system.shouldAutoSave());

    // Update past threshold
    save_system.update(AUTO_SAVE_INTERVAL + 1);
    try std.testing.expect(save_system.shouldAutoSave());

    // Reset timer
    save_system.resetAutoSaveTimer();
    try std.testing.expect(!save_system.shouldAutoSave());
}
