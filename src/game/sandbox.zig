//! Sandbox Game
//!
//! Main game logic for the sandbox experience.

const std = @import("std");
const math = @import("../math/math.zig");
const player_mod = @import("player.zig");
const world_mod = @import("world.zig");
const physics = @import("../physics/physics.zig");
const input = @import("../platform/input.zig");
const inventory_mod = @import("inventory.zig");
const items_mod = @import("items.zig");
const crafting_mod = @import("crafting.zig");
const save_mod = @import("save.zig");

pub const PlayerController = player_mod.PlayerController;
pub const BlockWorld = world_mod.BlockWorld;
pub const Block = world_mod.Block;
pub const Chunk = world_mod.Chunk;
pub const CHUNK_SIZE = world_mod.CHUNK_SIZE;
pub const Biome = world_mod.Biome;
pub const BiomeType = world_mod.BiomeType;
pub const SEA_LEVEL = world_mod.SEA_LEVEL;

// Re-export inventory and crafting types
pub const Inventory = inventory_mod.Inventory;
pub const ItemStack = inventory_mod.ItemStack;
pub const Item = items_mod.Item;
pub const ITEMS = items_mod.ITEMS;
pub const CraftingSystem = crafting_mod.CraftingSystem;

// Re-export save system types
pub const SaveSystem = save_mod.SaveSystem;
pub const SaveInfo = save_mod.SaveInfo;
pub const LoadedWorld = save_mod.LoadedWorld;
pub const GameMode = save_mod.GameMode;

/// Day/night cycle state
pub const DayNightCycle = struct {
    /// Current time of day (0.0 = midnight, 0.5 = noon, 1.0 = midnight)
    time: f32 = 0.25, // Start at sunrise
    /// Day length in seconds
    day_length: f32 = 600.0, // 10 minutes real time = 1 day
    /// Whether the cycle is paused
    paused: bool = false,

    /// Update the day/night cycle
    pub fn update(self: *DayNightCycle, dt: f32) void {
        if (self.paused) return;
        self.time += dt / self.day_length;
        if (self.time >= 1.0) self.time -= 1.0;
    }

    /// Get sun angle in radians (0 = horizon, pi/2 = zenith)
    pub fn getSunAngle(self: *const DayNightCycle) f32 {
        // Sun rises at 0.25, sets at 0.75
        const angle = (self.time - 0.25) * std.math.pi * 2.0;
        return @sin(angle) * std.math.pi / 2.0;
    }

    /// Get sky brightness (0.0 = night, 1.0 = noon)
    pub fn getSkyBrightness(self: *const DayNightCycle) f32 {
        const sun_angle = self.getSunAngle();
        if (sun_angle < 0) {
            // Night time - minimum brightness
            return 0.15;
        }
        // Daytime - varies from 0.3 (horizon) to 1.0 (noon)
        return 0.3 + 0.7 * @sin(sun_angle);
    }

    /// Get ambient light color based on time of day
    pub fn getAmbientColor(self: *const DayNightCycle) [3]f32 {
        const brightness = self.getSkyBrightness();
        const sun_angle = self.getSunAngle();

        if (sun_angle < 0) {
            // Night - blue tint
            return .{ brightness * 0.6, brightness * 0.7, brightness * 1.2 };
        } else if (sun_angle < 0.3) {
            // Sunrise/sunset - orange tint
            const t = sun_angle / 0.3;
            return .{
                brightness * (1.0 + (1 - t) * 0.3),
                brightness * (0.7 + t * 0.3),
                brightness * (0.5 + t * 0.5),
            };
        } else {
            // Daytime - neutral
            return .{ brightness, brightness, brightness };
        }
    }

    /// Check if it's currently night
    pub fn isNight(self: *const DayNightCycle) bool {
        return self.time < 0.25 or self.time > 0.75;
    }

    /// Get time as a string representation
    pub fn getTimeString(self: *const DayNightCycle) [5]u8 {
        const hours: u32 = @intFromFloat(self.time * 24.0);
        const minutes: u32 = @intFromFloat(@mod(self.time * 24.0 * 60.0, 60.0));
        var buf: [5]u8 = undefined;
        buf[0] = '0' + @as(u8, @intCast(hours / 10));
        buf[1] = '0' + @as(u8, @intCast(hours % 10));
        buf[2] = ':';
        buf[3] = '0' + @as(u8, @intCast(minutes / 10));
        buf[4] = '0' + @as(u8, @intCast(minutes % 10));
        return buf;
    }
};

/// Sandbox game state
pub const SandboxGame = struct {
    allocator: std.mem.Allocator,
    world: BlockWorld,
    player: PlayerController,
    selected_block: Block,
    hotbar: [9]Block,
    hotbar_index: usize,
    show_debug: bool,
    block_reach: f32,

    // Block interaction
    target_block: ?struct {
        pos: [3]i32,
        face: [3]i32,
    },

    // Interaction cooldowns (prevent rapid placement/breaking)
    place_cooldown: f32 = 0,
    break_cooldown: f32 = 0,
    attack_cooldown: f32 = 0,
    cooldown_time: f32 = 0.15, // 150ms between actions
    attack_cooldown_time: f32 = 0.5, // 500ms between attacks

    // Mining progress tracking
    mining_block: ?[3]i32 = null, // Currently mining block position
    mining_progress: f32 = 0, // Progress 0.0 to 1.0
    mining_time: f32 = 0, // Total time needed to break current block

    // Day/night cycle
    day_night: DayNightCycle = .{},

    // Statistics
    blocks_placed: u32 = 0,
    blocks_broken: u32 = 0,
    play_time: f64 = 0,

    // Current biome info (cached)
    current_biome: BiomeType = .plains,

    // Inventory and crafting systems
    inventory: Inventory = Inventory.init(),
    crafting: CraftingSystem = CraftingSystem.init(),
    inventory_open: bool = false,

    // Player stats
    health: f32 = 20.0,
    max_health: f32 = 20.0,
    hunger: f32 = 20.0,
    max_hunger: f32 = 20.0,
    saturation: f32 = 5.0,
    respawn_timer: f32 = 0,

    // Experience system
    experience: u32 = 0,
    experience_level: u32 = 0,

    // Game mode
    game_mode: GameMode = .survival,

    // Save system
    save_system: SaveSystem,
    world_name: [64]u8 = [_]u8{0} ** 64,
    world_name_len: usize = 0,
    /// Original world creation timestamp (preserved across saves)
    original_created_timestamp: ?i64 = null,

    // Save/load status messages
    save_message: ?[]const u8 = null,
    save_message_timer: f32 = 0,

    /// Initialize with default seed (0)
    pub fn init(allocator: std.mem.Allocator) !SandboxGame {
        return initWithSeed(allocator, 0);
    }

    /// Initialize with a specific world seed
    pub fn initWithSeed(allocator: std.mem.Allocator, seed: u64) !SandboxGame {
        var game = SandboxGame{
            .allocator = allocator,
            .world = BlockWorld.initWithSeed(allocator, seed),
            .player = PlayerController{},
            .selected_block = .stone,
            .hotbar = .{
                .grass,
                .dirt,
                .stone,
                .brick,
                .wood,
                .sand,
                .glass,
                .leaves,
                .water,
            },
            .hotbar_index = 0,
            .show_debug = false,
            .block_reach = 5.0,
            .target_block = null,
            .current_biome = .plains,
            .save_system = SaveSystem.init(allocator, null),
        };

        // Set default world name
        const default_name = "World";
        @memcpy(game.world_name[0..default_name.len], default_name);
        game.world_name_len = default_name.len;

        // Generate initial terrain with biomes
        try game.world.generateTerrain(4);

        // Find spawn height at world origin
        const spawn_height = game.world.getTerrainHeight(0, 0);
        game.player.position = math.Vec3.init(0, @as(f32, @floatFromInt(spawn_height + 3)), 0);

        // Update current biome
        game.current_biome = game.world.getBiome(0, 0).biome_type;

        // Give player some starter items
        _ = game.inventory.addItem(6, 16); // 16 wood
        _ = game.inventory.addItem(1, 32); // 32 stone
        _ = game.inventory.addItem(2, 32); // 32 dirt
        _ = game.inventory.addItem(100, 1); // 1 wooden pickaxe

        return game;
    }

    /// Initialize with random seed
    pub fn initRandom(allocator: std.mem.Allocator) !SandboxGame {
        const seed = @as(u64, @intCast(std.time.timestamp())) ^ @as(u64, @intCast(std.time.milliTimestamp()));
        return initWithSeed(allocator, seed);
    }

    /// Initialize with a specific world name (for loading)
    pub fn initWithName(allocator: std.mem.Allocator, seed: u64, name: []const u8) !SandboxGame {
        var game = try initWithSeed(allocator, seed);
        game.setWorldName(name);
        return game;
    }

    /// Set the world name
    pub fn setWorldName(self: *SandboxGame, name: []const u8) void {
        const len = @min(name.len, self.world_name.len);
        @memcpy(self.world_name[0..len], name[0..len]);
        self.world_name_len = len;
    }

    /// Get the world name
    pub fn getWorldName(self: *const SandboxGame) []const u8 {
        return self.world_name[0..self.world_name_len];
    }

    /// Get the world seed
    pub fn getSeed(self: *const SandboxGame) u64 {
        return self.world.getSeed();
    }

    pub fn deinit(self: *SandboxGame) void {
        self.world.deinit();
    }

    /// Main update function
    pub fn update(self: *SandboxGame, input_state: *const input.State, dt: f32) !void {
        // Update play time
        self.play_time += dt;

        // Update day/night cycle
        self.day_night.update(dt);

        // Update save system
        self.save_system.update(dt);

        // Update save message timer
        if (self.save_message_timer > 0) {
            self.save_message_timer -= dt;
            if (self.save_message_timer <= 0) {
                self.save_message = null;
            }
        }

        // Check for auto-save
        if (self.save_system.shouldAutoSave()) {
            self.quickSave();
        }

        // Toggle debug
        if (input_state.isKeyPressed(.f3)) {
            self.show_debug = !self.show_debug;
        }

        // Quick save with F5
        if (input_state.isKeyPressed(.f5)) {
            self.quickSave();
        }

        // Quick load with F9
        if (input_state.isKeyPressed(.f9)) {
            self.quickLoad();
        }

        // Toggle day/night cycle pause with F6
        if (input_state.isKeyPressed(.f6)) {
            self.day_night.paused = !self.day_night.paused;
        }

        // Toggle flight mode with F4 (double-tap Space also works via player controller)
        if (input_state.isKeyPressed(.f4)) {
            self.player.toggleFlight();
        }

        // Toggle inventory with E or Tab
        if (input_state.isKeyPressed(.e) or input_state.isKeyPressed(.tab)) {
            self.inventory_open = !self.inventory_open;
        }

        // Close inventory with Escape
        if (input_state.isKeyPressed(.escape) and self.inventory_open) {
            self.inventory_open = false;
            // Return held item to inventory
            if (self.inventory.held_item) |held| {
                _ = self.inventory.addItemStack(held);
                self.inventory.held_item = null;
            }
            // Clear crafting grid
            self.inventory.clearCraftingGrid();
        }

        // Update cooldowns
        if (self.place_cooldown > 0) self.place_cooldown -= dt;
        if (self.break_cooldown > 0) self.break_cooldown -= dt;
        if (self.attack_cooldown > 0) self.attack_cooldown -= dt;

        // Update hunger over time
        self.updateHunger(dt);

        // Handle respawn timer
        if (self.respawn_timer > 0) {
            self.respawn_timer -= dt;
            if (self.respawn_timer <= 0) {
                self.respawn();
            }
            return; // Skip game controls while dead
        }

        // If inventory is open, skip game controls
        if (self.inventory_open) {
            return;
        }

        // Hotbar selection with number keys
        inline for (0..9) |i| {
            const key: input.Key = @enumFromInt(0x31 + i); // '1' to '9'
            if (input_state.isKeyPressed(key)) {
                self.hotbar_index = i;
                self.inventory.setSelectedSlot(@intCast(i));
                self.selected_block = self.hotbar[i];
            }
        }

        // Scroll wheel for hotbar
        if (input_state.scroll_y != 0) {
            if (input_state.scroll_y > 0) {
                self.hotbar_index = (self.hotbar_index + 8) % 9;
            } else {
                self.hotbar_index = (self.hotbar_index + 1) % 9;
            }
            self.inventory.setSelectedSlot(@intCast(self.hotbar_index));
            self.selected_block = self.hotbar[self.hotbar_index];
        }

        // Process player input
        const delta = input_state.getMouseDelta();
        self.player.processInput(input_state, delta.dx, delta.dy);

        // Update physics colliders near player
        try self.world.updatePhysicsNear(self.player.position, 3);

        // Update player physics
        self.player.update(&self.world.physics_world, dt);

        // Raycast for block targeting
        const eye = self.player.getEyePosition();
        const look_dir = self.player.getLookDirection();

        if (self.world.raycastBlock(eye, look_dir, self.block_reach)) |hit| {
            self.target_block = .{
                .pos = hit.block_pos,
                .face = hit.face_normal,
            };
        } else {
            self.target_block = null;

            // Eat food when right-clicking with food and not targeting a block
            if (input_state.isMouseButtonDown(.right) and self.place_cooldown <= 0) {
                if (self.eatFood()) {
                    self.place_cooldown = 0.5; // Eating cooldown
                }
            }
        }

        // Block placement (left click) - with cooldown
        if (input_state.isMouseButtonDown(.left) and self.target_block != null and self.place_cooldown <= 0) {
            const target = self.target_block.?;
            const place_pos = [3]i32{
                target.pos[0] + target.face[0],
                target.pos[1] + target.face[1],
                target.pos[2] + target.face[2],
            };

            // Don't place block inside player
            const player_aabb = self.player.collider.getAABB(self.player.position);
            const block_aabb = physics.AABB.unitCube(math.Vec3.init(
                @floatFromInt(place_pos[0]),
                @floatFromInt(place_pos[1]),
                @floatFromInt(place_pos[2]),
            ));

            if (!player_aabb.intersects(block_aabb)) {
                // Try to use item from inventory for block placement
                if (self.tryPlaceBlockFromInventory(place_pos)) {
                    self.place_cooldown = self.cooldown_time;
                    self.blocks_placed += 1;
                } else {
                    // Fallback to legacy hotbar
                    try self.world.setBlock(place_pos[0], place_pos[1], place_pos[2], self.selected_block);
                    self.place_cooldown = self.cooldown_time;
                    self.blocks_placed += 1;
                }
            }
        }

        // Block removal (right click or Ctrl+left click) - with mining progress
        const removing = input_state.isMouseButtonDown(.right) or
            (input_state.isKeyDown(.left_ctrl) and input_state.isMouseButtonDown(.left));

        if (removing and self.target_block != null) {
            const target = self.target_block.?;
            const target_block = self.world.getBlock(target.pos[0], target.pos[1], target.pos[2]);

            // Check if we're mining a different block
            if (self.mining_block) |mb| {
                if (mb[0] != target.pos[0] or mb[1] != target.pos[1] or mb[2] != target.pos[2]) {
                    // Changed target - reset progress
                    self.mining_block = target.pos;
                    self.mining_progress = 0;
                    self.mining_time = self.getBlockBreakTime(target_block);
                }
            } else {
                // Start mining new block
                self.mining_block = target.pos;
                self.mining_progress = 0;
                self.mining_time = self.getBlockBreakTime(target_block);
            }

            // Progress mining
            if (self.mining_time > 0) {
                self.mining_progress += dt / self.mining_time;
            } else {
                self.mining_progress = 1.0; // Instant break
            }

            // Check if mining complete
            if (self.mining_progress >= 1.0) {
                const broken_block = self.world.getBlock(target.pos[0], target.pos[1], target.pos[2]);

                // Break the block
                try self.world.setBlock(target.pos[0], target.pos[1], target.pos[2], .air);
                self.blocks_broken += 1;

                // Add block to inventory
                if (broken_block != .air) {
                    const item_id = items_mod.getBlockItemId(broken_block);
                    _ = self.inventory.addItem(item_id, 1);

                    // Use durability on held tool
                    if (self.inventory.getSelectedItemPtr()) |stack| {
                        if (stack.durability != null) {
                            if (stack.useDurability(1)) {
                                // Tool broke
                                self.inventory.slots[self.inventory.selected_slot] = null;
                            }
                        }
                    }
                }

                // Reset mining state
                self.mining_block = null;
                self.mining_progress = 0;
                self.break_cooldown = self.cooldown_time;
            }
        } else {
            // Not mining - reset progress
            if (self.mining_block != null) {
                self.mining_block = null;
                self.mining_progress = 0;
            }
        }
    }

    /// Try to place a block from inventory
    fn tryPlaceBlockFromInventory(self: *SandboxGame, pos: [3]i32) bool {
        const selected = self.inventory.getSelectedItem() orelse return false;
        const item = selected.getItem() orelse return false;
        const block_type = item.block_type orelse return false;

        // Remove item from inventory
        if (!self.inventory.removeItem(selected.item_id, 1)) return false;

        // Place the block
        self.world.setBlock(pos[0], pos[1], pos[2], block_type) catch return false;
        return true;
    }

    /// Update hunger and apply effects
    fn updateHunger(self: *SandboxGame, dt: f32) void {
        // Hunger drains slowly over time
        const hunger_drain = 0.01 * dt; // Slow drain

        // Running/jumping drains more
        if (self.player.is_running) {
            self.hunger -= hunger_drain * 3;
        } else if (!self.player.is_grounded and !self.player.is_flying) {
            self.hunger -= hunger_drain * 2;
        }

        // Saturation buffers hunger
        if (self.saturation > 0) {
            self.saturation -= hunger_drain;
            if (self.saturation < 0) self.saturation = 0;
        } else {
            self.hunger -= hunger_drain;
            if (self.hunger < 0) self.hunger = 0;
        }

        // Regenerate health if hunger is high
        if (self.hunger >= 18.0 and self.health < self.max_health) {
            self.health += 0.5 * dt;
            if (self.health > self.max_health) self.health = self.max_health;
            // Health regen costs hunger
            self.hunger -= 0.1 * dt;
        }

        // Take damage if hunger is 0
        if (self.hunger <= 0 and self.health > 1.0) {
            self.health -= 0.5 * dt;
        }
    }

    /// Apply damage to player with armor reduction and optional knockback
    pub fn takeDamage(self: *SandboxGame, damage: f32) void {
        self.takeDamageWithKnockback(damage, null);
    }

    /// Apply damage to player with armor reduction and knockback from source position
    pub fn takeDamageWithKnockback(self: *SandboxGame, damage: f32, source_pos: ?math.Vec3) void {
        // Calculate armor protection
        const armor_points = self.inventory.getTotalArmor();
        // Each armor point reduces damage by 4% (max 80% at 20 armor)
        const reduction = @min(0.8, armor_points * 0.04);
        const actual_damage = damage * (1.0 - reduction);

        self.health -= actual_damage;

        // Apply knockback from source
        if (source_pos) |pos| {
            self.applyKnockback(pos, 8.0);
        }

        // Damage armor durability
        if (armor_points > 0) {
            self.damageArmorPieces(damage);
        }

        // Check for death
        if (self.health <= 0) {
            self.onPlayerDeath();
        }
    }

    /// Apply knockback to the player from a source position
    pub fn applyKnockback(self: *SandboxGame, source_pos: math.Vec3, strength: f32) void {
        // Calculate direction away from source (horizontal only)
        const dx = self.player.position.x() - source_pos.x();
        const dz = self.player.position.z() - source_pos.z();
        const dist = @sqrt(dx * dx + dz * dz);

        if (dist > 0.001) {
            // Normalize and apply horizontal knockback
            const knockback_x = (dx / dist) * strength;
            const knockback_z = (dz / dist) * strength;

            self.player.velocity = math.Vec3.init(
                self.player.velocity.x() + knockback_x,
                self.player.velocity.y() + 4.0, // Upward knockback component
                self.player.velocity.z() + knockback_z,
            );

            // Take player off ground for knockback to work
            self.player.is_grounded = false;
        }
    }

    /// Damage equipped armor pieces
    fn damageArmorPieces(self: *SandboxGame, damage: f32) void {
        const durability_damage: u32 = @max(1, @as(u32, @intFromFloat(damage / 4.0)));

        // Damage each armor slot
        for (&self.inventory.armor) |*slot| {
            if (slot.*) |*stack| {
                if (stack.useDurability(durability_damage)) {
                    // Armor piece broke
                    slot.* = null;
                }
            }
        }
    }

    /// Handle player death
    fn onPlayerDeath(self: *SandboxGame) void {
        self.health = 0;
        // Respawn after a delay (handled in update)
        self.respawn_timer = 3.0; // 3 second respawn delay
    }

    /// Respawn the player
    pub fn respawn(self: *SandboxGame) void {
        // Reset health and hunger
        self.health = self.max_health;
        self.hunger = self.max_hunger;
        self.saturation = 5.0;

        // Lose experience on death (keep levels, lose progress to next)
        self.experience = self.getExperienceForLevel(self.experience_level);

        // Move to spawn point
        const spawn_height = self.world.getTerrainHeight(0, 0);
        self.player.position = math.Vec3.init(0, @as(f32, @floatFromInt(spawn_height + 3)), 0);
        self.player.velocity = math.Vec3.ZERO;

        // Reset respawn timer
        self.respawn_timer = 0;
    }

    /// Add experience points to the player
    pub fn addExperience(self: *SandboxGame, amount: u32) void {
        self.experience += amount;
        // Check for level up
        while (self.experience >= self.getExperienceForLevel(self.experience_level + 1)) {
            self.experience_level += 1;
        }
    }

    /// Get total experience needed to reach a level
    pub fn getExperienceForLevel(self: *const SandboxGame, level: u32) u32 {
        _ = self;
        if (level == 0) return 0;
        if (level <= 16) {
            // Levels 1-16: 2*level^2 + 7*level
            return 2 * level * level + 7 * level;
        } else if (level <= 31) {
            // Levels 17-31: 5*level^2 - 38*level + 360
            return 5 * level * level - 38 * level + 360;
        } else {
            // Levels 32+: 9*level^2 - 158*level + 2220
            return 9 * level * level - 158 * level + 2220;
        }
    }

    /// Get experience progress to next level (0.0 to 1.0)
    pub fn getExperienceProgress(self: *const SandboxGame) f32 {
        const current_level_xp = self.getExperienceForLevel(self.experience_level);
        const next_level_xp = self.getExperienceForLevel(self.experience_level + 1);
        const xp_in_level = self.experience - current_level_xp;
        const xp_needed = next_level_xp - current_level_xp;
        if (xp_needed == 0) return 0;
        return @as(f32, @floatFromInt(xp_in_level)) / @as(f32, @floatFromInt(xp_needed));
    }

    /// Eat food from held item
    pub fn eatFood(self: *SandboxGame) bool {
        const selected = self.inventory.getSelectedItem() orelse return false;
        const item = selected.getItem() orelse return false;

        if (item.item_type != .food) return false;
        if (self.hunger >= self.max_hunger) return false;

        // Consume food
        if (!self.inventory.removeItem(selected.item_id, 1)) return false;

        // Restore hunger and saturation
        self.hunger = @min(self.max_hunger, self.hunger + item.hunger_restore);
        self.saturation = @min(self.hunger, self.saturation + item.saturation);

        return true;
    }

    /// Get mining speed for current tool vs target block
    pub fn getMiningSpeed(self: *const SandboxGame) f32 {
        const target = self.target_block orelse return 1.0;
        const block = self.world.getBlock(target.pos[0], target.pos[1], target.pos[2]);

        const selected = self.inventory.getSelectedItem() orelse return 1.0;
        const item = selected.getItem() orelse return 1.0;

        return item.getMiningSpeed(block);
    }

    /// Get base hardness for a block type
    fn getBlockHardness(block: Block) f32 {
        return switch (block) {
            .air => 0,
            .grass, .dirt => 0.5,
            .sand, .gravel => 0.5,
            .leaves => 0.2,
            .snow => 0.2,
            .clay => 0.6,
            .wood, .planks => 2.0,
            .stone, .cobblestone => 1.5,
            .brick => 2.0,
            .glass, .ice => 0.3,
            .coal, .iron => 3.0,
            .gold => 3.0,
            .obsidian => 50.0,
            .water => 100.0, // Can't mine water
            .crafting_table => 2.5,
            .furnace => 3.5,
            .chest => 2.5,
            .torch => 0.0, // Instant break
            .diamond_ore => 3.0, // Same as other ores
        };
    }

    /// Calculate time to break a block with current tool
    fn getBlockBreakTime(self: *const SandboxGame, block: Block) f32 {
        const hardness = getBlockHardness(block);
        if (hardness <= 0) return 0; // Instant break

        // Get tool mining speed
        var speed: f32 = 1.0;
        if (self.inventory.getSelectedItem()) |selected| {
            if (selected.getItem()) |item| {
                speed = item.getMiningSpeed(block);
            }
        }

        // Base time = hardness * 1.5 / speed
        // With no tool: hardness * 5 seconds
        // With correct tool: hardness * 1.5 / tool_speed seconds
        const base_time = if (speed > 1.0)
            hardness * 1.5 / speed
        else
            hardness * 5.0;

        return @max(0.05, base_time); // Minimum 50ms
    }

    /// Get current mining progress (0.0 to 1.0)
    pub fn getMiningProgress(self: *const SandboxGame) f32 {
        return self.mining_progress;
    }

    /// Get current view matrix
    pub fn getViewMatrix(self: *const SandboxGame) math.Mat4 {
        return self.player.getViewMatrix();
    }

    /// Get debug info string
    pub fn getDebugInfo(self: *const SandboxGame) DebugInfo {
        // Get current biome based on player position
        const px: i32 = @intFromFloat(@floor(self.player.position.x()));
        const pz: i32 = @intFromFloat(@floor(self.player.position.z()));
        const current_biome = self.world.getBiome(px, pz).biome_type;

        return .{
            .position = self.player.position,
            .yaw = self.player.yaw,
            .pitch = self.player.pitch,
            .grounded = self.player.is_grounded,
            .is_flying = self.player.is_flying,
            .velocity = self.player.velocity,
            .chunk_count = @intCast(self.world.chunks.count()),
            .selected_block = self.selected_block,
            .day_time = self.day_night.time,
            .is_night = self.day_night.isNight(),
            .time_string = self.day_night.getTimeString(),
            .sky_brightness = self.day_night.getSkyBrightness(),
            .blocks_placed = self.blocks_placed,
            .blocks_broken = self.blocks_broken,
            .play_time = self.play_time,
            .biome = current_biome,
            .world_seed = self.world.getSeed(),
            .auto_save_enabled = self.save_system.auto_save_enabled,
            .save_message = self.save_message,
        };
    }

    /// Get the ambient light color for rendering
    pub fn getAmbientLight(self: *const SandboxGame) [3]f32 {
        return self.day_night.getAmbientColor();
    }

    /// Get current biome at player location
    pub fn getCurrentBiome(self: *const SandboxGame) Biome {
        const px: i32 = @intFromFloat(@floor(self.player.position.x()));
        const pz: i32 = @intFromFloat(@floor(self.player.position.z()));
        return self.world.getBiome(px, pz);
    }

    // =========================================================================
    // Save/Load System Integration
    // =========================================================================

    /// Quick save the current world
    pub fn quickSave(self: *SandboxGame) void {
        self.saveWorld(self.getWorldName()) catch |err| {
            std.log.err("Quick save failed: {}", .{err});
            self.showSaveMessage("Save failed!");
            return;
        };
        self.showSaveMessage("Game saved!");
    }

    /// Quick load the current world
    pub fn quickLoad(self: *SandboxGame) void {
        self.loadWorldByName(self.getWorldName()) catch |err| {
            std.log.err("Quick load failed: {}", .{err});
            self.showSaveMessage("Load failed!");
            return;
        };
        self.showSaveMessage("Game loaded!");
    }

    /// Save the world to a file
    pub fn saveWorld(self: *SandboxGame, name: []const u8) !void {
        try self.save_system.saveWorld(
            &self.world,
            &self.player,
            &self.inventory,
            .{
                .health = self.health,
                .max_health = self.max_health,
                .hunger = self.hunger,
                .max_hunger = self.max_hunger,
                .saturation = self.saturation,
                .game_mode = self.game_mode,
                .time_of_day = self.day_night.time,
                .play_time = self.play_time,
                .original_created_timestamp = self.original_created_timestamp,
            },
            name,
        );
    }

    /// Load a world by name
    pub fn loadWorldByName(self: *SandboxGame, name: []const u8) !void {
        var loaded = try self.save_system.loadWorld(name);
        defer loaded.deinit();

        try self.applyLoadedWorld(&loaded);
        self.setWorldName(loaded.world_name);
    }

    /// Load a world from a specific path
    pub fn loadWorldFromPath(self: *SandboxGame, path: []const u8) !void {
        var loaded = try self.save_system.loadWorldFromPath(path);
        defer loaded.deinit();

        try self.applyLoadedWorld(&loaded);
        self.setWorldName(loaded.world_name);
    }

    /// Apply loaded world data to the game state
    fn applyLoadedWorld(self: *SandboxGame, loaded: *LoadedWorld) !void {
        // Clear existing world chunks
        var iter = self.world.chunks.valueIterator();
        while (iter.next()) |chunk_ptr| {
            self.allocator.destroy(chunk_ptr.*);
        }
        self.world.chunks.clearRetainingCapacity();

        // Set world seed
        self.world.seed = loaded.header.world_seed;

        // Reinitialize terrain generator with loaded seed
        if (self.world.terrain_gen != null) {
            self.world.terrain_gen = world_mod.TerrainGenerator.init(self.allocator, loaded.header.world_seed);
        }

        // Load chunks
        for (loaded.chunks.items) |loaded_chunk| {
            const chunk = self.allocator.create(world_mod.Chunk) catch return error.OutOfMemory;
            chunk.* = world_mod.Chunk.init(loaded_chunk.x, loaded_chunk.y, loaded_chunk.z);

            // Copy block data
            for (loaded_chunk.blocks, 0..) |block_byte, j| {
                chunk.blocks[j] = @enumFromInt(block_byte);
            }
            chunk.is_dirty = loaded_chunk.modified;

            // Add to world using chunk key
            const key = chunkKey(loaded_chunk.x, loaded_chunk.y, loaded_chunk.z);
            self.world.chunks.put(key, chunk) catch return error.OutOfMemory;
        }

        // Apply player state
        self.player.position = math.Vec3.init(
            loaded.player.position[0],
            loaded.player.position[1],
            loaded.player.position[2],
        );
        self.player.yaw = loaded.player.rotation[0];
        self.player.pitch = loaded.player.rotation[1];
        self.player.velocity = math.Vec3.init(
            loaded.player.velocity[0],
            loaded.player.velocity[1],
            loaded.player.velocity[2],
        );
        self.player.is_flying = loaded.player.is_flying;

        // Apply inventory
        for (loaded.inventory_slots, 0..) |slot, i| {
            self.inventory.slots[i] = slot;
        }
        for (loaded.armor_slots, 0..) |slot, i| {
            self.inventory.armor[i] = slot;
        }
        self.inventory.selected_slot = loaded.player.hotbar_selection;

        // Apply game state
        self.health = loaded.player.health;
        self.max_health = loaded.player.max_health;
        self.hunger = loaded.player.hunger;
        self.max_hunger = loaded.player.max_hunger;
        self.saturation = loaded.player.saturation;
        self.game_mode = loaded.player.game_mode;
        self.day_night.time = loaded.header.time_of_day;
        self.play_time = loaded.header.game_time;

        // Preserve original world creation timestamp
        self.original_created_timestamp = loaded.header.created_timestamp;
    }

    // Helper function to generate chunk key
    fn chunkKey(cx: i32, cy: i32, cz: i32) i64 {
        const x: i64 = @intCast(cx);
        const y: i64 = @intCast(cy);
        const z: i64 = @intCast(cz);
        return x + y * 0x100000 + z * 0x10000000000;
    }

    /// Check if a save exists for the given name
    pub fn saveExists(self: *SandboxGame, name: []const u8) bool {
        return self.save_system.saveExists(name);
    }

    /// List all available saves
    pub fn listSaves(self: *SandboxGame) ![]SaveInfo {
        return self.save_system.listSaves();
    }

    /// Delete a save by name
    pub fn deleteSave(self: *SandboxGame, name: []const u8) !void {
        return self.save_system.deleteSave(name);
    }

    /// Show a save/load status message
    fn showSaveMessage(self: *SandboxGame, message: []const u8) void {
        self.save_message = message;
        self.save_message_timer = 3.0; // Show for 3 seconds
    }

    /// Get current save message (if any)
    pub fn getSaveMessage(self: *const SandboxGame) ?[]const u8 {
        return self.save_message;
    }

    /// Enable or disable auto-save
    pub fn setAutoSaveEnabled(self: *SandboxGame, enabled: bool) void {
        self.save_system.auto_save_enabled = enabled;
    }

    /// Check if auto-save is enabled
    pub fn isAutoSaveEnabled(self: *const SandboxGame) bool {
        return self.save_system.auto_save_enabled;
    }

    pub const DebugInfo = struct {
        position: math.Vec3,
        yaw: f32,
        pitch: f32,
        grounded: bool,
        is_flying: bool,
        velocity: math.Vec3,
        chunk_count: u32,
        selected_block: Block,
        // Day/night info
        day_time: f32,
        is_night: bool,
        time_string: [5]u8,
        sky_brightness: f32,
        // Statistics
        blocks_placed: u32,
        blocks_broken: u32,
        play_time: f64,
        // Biome info
        biome: BiomeType,
        world_seed: u64,
        // Save info
        auto_save_enabled: bool,
        save_message: ?[]const u8,
    };
};

// ============================================================================
// Tests
// ============================================================================

test "sandbox init and cleanup" {
    const allocator = std.testing.allocator;
    var game = try SandboxGame.init(allocator);
    defer game.deinit();

    try std.testing.expect(game.world.chunks.count() > 0);
}

test "sandbox init with seed" {
    const allocator = std.testing.allocator;
    var game = try SandboxGame.initWithSeed(allocator, 12345);
    defer game.deinit();

    try std.testing.expectEqual(@as(u64, 12345), game.getSeed());
    try std.testing.expect(game.world.chunks.count() > 0);
}

test "sandbox seed determinism" {
    const allocator = std.testing.allocator;

    var game1 = try SandboxGame.initWithSeed(allocator, 42);
    defer game1.deinit();

    var game2 = try SandboxGame.initWithSeed(allocator, 42);
    defer game2.deinit();

    // Same seed should produce same terrain height at same location
    const h1 = game1.world.getTerrainHeight(100, 100);
    const h2 = game2.world.getTerrainHeight(100, 100);

    try std.testing.expectEqual(h1, h2);
}

test "biome retrieval" {
    const allocator = std.testing.allocator;
    var game = try SandboxGame.initWithSeed(allocator, 999);
    defer game.deinit();

    const biome = game.getCurrentBiome();
    // Just check that we can get a biome
    _ = biome.biome_type.getName();
}
