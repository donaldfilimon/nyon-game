//! Item System
//!
//! Defines all item types, properties, and item-related functionality.

const std = @import("std");
const world = @import("world.zig");
const Block = world.Block;

/// Tool types for mining and combat
pub const ToolType = enum {
    none,
    pickaxe,
    axe,
    shovel,
    hoe,
    sword,

    /// Get mining speed multiplier for block type
    pub fn getMiningMultiplier(self: ToolType, block: Block) f32 {
        return switch (self) {
            .pickaxe => switch (block) {
                .stone, .cobblestone, .coal, .iron, .gold, .obsidian => 4.0,
                else => 1.0,
            },
            .axe => switch (block) {
                .wood, .planks, .leaves => 4.0,
                else => 1.0,
            },
            .shovel => switch (block) {
                .dirt, .grass, .sand, .gravel, .snow, .clay => 4.0,
                else => 1.0,
            },
            else => 1.0,
        };
    }
};

/// Tool material tiers
pub const ToolMaterial = enum {
    wood,
    stone,
    iron,
    gold,
    diamond,

    /// Get base durability for material
    pub fn getDurability(self: ToolMaterial) u32 {
        return switch (self) {
            .wood => 60,
            .stone => 132,
            .iron => 251,
            .gold => 33,
            .diamond => 1562,
        };
    }

    /// Get mining speed multiplier for material
    pub fn getSpeedMultiplier(self: ToolMaterial) f32 {
        return switch (self) {
            .wood => 1.0,
            .stone => 1.5,
            .iron => 2.0,
            .gold => 3.0,
            .diamond => 2.5,
        };
    }

    /// Get attack damage bonus for material
    pub fn getDamageBonus(self: ToolMaterial) f32 {
        return switch (self) {
            .wood => 0.0,
            .stone => 1.0,
            .iron => 2.0,
            .gold => 0.0,
            .diamond => 3.0,
        };
    }
};

/// Armor slot types
pub const ArmorSlot = enum {
    head,
    chest,
    legs,
    feet,

    /// Get armor slot index (0-3)
    pub fn toIndex(self: ArmorSlot) u8 {
        return @intFromEnum(self);
    }
};

/// Item category types
pub const ItemType = enum {
    block,
    tool,
    weapon,
    armor,
    food,
    material,
    special,
};

/// Main item definition
pub const Item = struct {
    id: u16,
    name: []const u8,
    item_type: ItemType,
    max_stack: u32,
    durability: ?u32,
    // Tool properties
    tool_type: ?ToolType,
    tool_material: ?ToolMaterial,
    // Weapon properties
    damage: f32,
    attack_speed: f32,
    // Food properties
    hunger_restore: f32,
    saturation: f32,
    // Armor properties
    armor_slot: ?ArmorSlot,
    armor_points: f32,
    // Block properties
    block_type: ?Block,

    /// Create a basic block item
    pub fn block(id: u16, name: []const u8, block_type: Block) Item {
        return .{
            .id = id,
            .name = name,
            .item_type = .block,
            .max_stack = 64,
            .durability = null,
            .tool_type = null,
            .tool_material = null,
            .damage = 1.0,
            .attack_speed = 1.0,
            .hunger_restore = 0,
            .saturation = 0,
            .armor_slot = null,
            .armor_points = 0,
            .block_type = block_type,
        };
    }

    /// Create a tool item
    pub fn tool(id: u16, name: []const u8, tool_t: ToolType, mat: ToolMaterial) Item {
        return .{
            .id = id,
            .name = name,
            .item_type = .tool,
            .max_stack = 1,
            .durability = mat.getDurability(),
            .tool_type = tool_t,
            .tool_material = mat,
            .damage = 1.0 + mat.getDamageBonus(),
            .attack_speed = 1.0,
            .hunger_restore = 0,
            .saturation = 0,
            .armor_slot = null,
            .armor_points = 0,
            .block_type = null,
        };
    }

    /// Create a weapon item
    pub fn weapon(id: u16, name: []const u8, mat: ToolMaterial) Item {
        const base_damage: f32 = 4.0;
        return .{
            .id = id,
            .name = name,
            .item_type = .weapon,
            .max_stack = 1,
            .durability = mat.getDurability(),
            .tool_type = .sword,
            .tool_material = mat,
            .damage = base_damage + mat.getDamageBonus(),
            .attack_speed = 1.6,
            .hunger_restore = 0,
            .saturation = 0,
            .armor_slot = null,
            .armor_points = 0,
            .block_type = null,
        };
    }

    /// Create a food item
    pub fn food(id: u16, name: []const u8, hunger: f32, sat: f32) Item {
        return .{
            .id = id,
            .name = name,
            .item_type = .food,
            .max_stack = 64,
            .durability = null,
            .tool_type = null,
            .tool_material = null,
            .damage = 1.0,
            .attack_speed = 1.0,
            .hunger_restore = hunger,
            .saturation = sat,
            .armor_slot = null,
            .armor_points = 0,
            .block_type = null,
        };
    }

    /// Create a material item
    pub fn material(id: u16, name: []const u8, stack: u32) Item {
        return .{
            .id = id,
            .name = name,
            .item_type = .material,
            .max_stack = stack,
            .durability = null,
            .tool_type = null,
            .tool_material = null,
            .damage = 1.0,
            .attack_speed = 1.0,
            .hunger_restore = 0,
            .saturation = 0,
            .armor_slot = null,
            .armor_points = 0,
            .block_type = null,
        };
    }

    /// Create an armor item
    pub fn armor(id: u16, name: []const u8, slot: ArmorSlot, points: f32, dur: u32) Item {
        return .{
            .id = id,
            .name = name,
            .item_type = .armor,
            .max_stack = 1,
            .durability = dur,
            .tool_type = null,
            .tool_material = null,
            .damage = 1.0,
            .attack_speed = 1.0,
            .hunger_restore = 0,
            .saturation = 0,
            .armor_slot = slot,
            .armor_points = points,
            .block_type = null,
        };
    }

    /// Get the mining speed for this item against a block
    pub fn getMiningSpeed(self: Item, target_block: Block) f32 {
        var speed: f32 = 1.0;

        if (self.tool_type) |tt| {
            speed *= tt.getMiningMultiplier(target_block);
        }

        if (self.tool_material) |tm| {
            speed *= tm.getSpeedMultiplier();
        }

        return speed;
    }

    /// Check if items are the same type (ignoring durability)
    pub fn isSameType(self: Item, other: Item) bool {
        return self.id == other.id;
    }
};

/// All items in the game - lookup table by ID
/// IDs 0-99: Blocks
/// IDs 100-199: Tools
/// IDs 200-299: Weapons
/// IDs 300-399: Materials
/// IDs 400-499: Food
/// IDs 500-599: Armor
pub const ITEMS = blk: {
    @setEvalBranchQuota(10000);

    var items: [600]Item = undefined;

    // Initialize with empty items
    for (&items) |*item| {
        item.* = Item.material(0, "Empty", 0);
    }

    // Block items (0-99)
    items[0] = Item.block(0, "Air", .air);
    items[1] = Item.block(1, "Stone", .stone);
    items[2] = Item.block(2, "Dirt", .dirt);
    items[3] = Item.block(3, "Grass", .grass);
    items[4] = Item.block(4, "Sand", .sand);
    items[5] = Item.block(5, "Water", .water);
    items[6] = Item.block(6, "Wood", .wood);
    items[7] = Item.block(7, "Leaves", .leaves);
    items[8] = Item.block(8, "Brick", .brick);
    items[9] = Item.block(9, "Glass", .glass);
    items[10] = Item.block(10, "Cobblestone", .cobblestone);
    items[11] = Item.block(11, "Planks", .planks);
    items[12] = Item.block(12, "Gravel", .gravel);
    items[13] = Item.block(13, "Gold Ore", .gold);
    items[14] = Item.block(14, "Iron Ore", .iron);
    items[15] = Item.block(15, "Coal Ore", .coal);
    items[16] = Item.block(16, "Snow", .snow);
    items[17] = Item.block(17, "Ice", .ice);
    items[18] = Item.block(18, "Clay", .clay);
    items[19] = Item.block(19, "Obsidian", .obsidian);
    items[20] = Item.block(20, "Crafting Table", .crafting_table);
    items[21] = Item.block(21, "Furnace", .furnace);
    items[22] = Item.block(22, "Chest", .chest);
    items[23] = Item.block(23, "Torch", .torch);
    items[24] = Item.block(24, "Diamond Ore", .diamond_ore);

    // Wooden tools (100-109)
    items[100] = Item.tool(100, "Wooden Pickaxe", .pickaxe, .wood);
    items[101] = Item.tool(101, "Wooden Axe", .axe, .wood);
    items[102] = Item.tool(102, "Wooden Shovel", .shovel, .wood);
    items[103] = Item.tool(103, "Wooden Hoe", .hoe, .wood);

    // Stone tools (110-119)
    items[110] = Item.tool(110, "Stone Pickaxe", .pickaxe, .stone);
    items[111] = Item.tool(111, "Stone Axe", .axe, .stone);
    items[112] = Item.tool(112, "Stone Shovel", .shovel, .stone);
    items[113] = Item.tool(113, "Stone Hoe", .hoe, .stone);

    // Iron tools (120-129)
    items[120] = Item.tool(120, "Iron Pickaxe", .pickaxe, .iron);
    items[121] = Item.tool(121, "Iron Axe", .axe, .iron);
    items[122] = Item.tool(122, "Iron Shovel", .shovel, .iron);
    items[123] = Item.tool(123, "Iron Hoe", .hoe, .iron);

    // Gold tools (130-139)
    items[130] = Item.tool(130, "Gold Pickaxe", .pickaxe, .gold);
    items[131] = Item.tool(131, "Gold Axe", .axe, .gold);
    items[132] = Item.tool(132, "Gold Shovel", .shovel, .gold);
    items[133] = Item.tool(133, "Gold Hoe", .hoe, .gold);

    // Diamond tools (140-149)
    items[140] = Item.tool(140, "Diamond Pickaxe", .pickaxe, .diamond);
    items[141] = Item.tool(141, "Diamond Axe", .axe, .diamond);
    items[142] = Item.tool(142, "Diamond Shovel", .shovel, .diamond);
    items[143] = Item.tool(143, "Diamond Hoe", .hoe, .diamond);

    // Swords (200-209)
    items[200] = Item.weapon(200, "Wooden Sword", .wood);
    items[201] = Item.weapon(201, "Stone Sword", .stone);
    items[202] = Item.weapon(202, "Iron Sword", .iron);
    items[203] = Item.weapon(203, "Gold Sword", .gold);
    items[204] = Item.weapon(204, "Diamond Sword", .diamond);

    // Materials (300-399)
    items[300] = Item.material(300, "Stick", 64);
    items[301] = Item.material(301, "Coal", 64);
    items[302] = Item.material(302, "Iron Ingot", 64);
    items[303] = Item.material(303, "Gold Ingot", 64);
    items[304] = Item.material(304, "Diamond", 64);
    items[305] = Item.material(305, "String", 64);
    items[306] = Item.material(306, "Leather", 64);
    items[307] = Item.material(307, "Feather", 64);
    items[308] = Item.material(308, "Flint", 64);
    items[309] = Item.material(309, "Wheat", 64);

    // Food (400-449)
    items[400] = Item.food(400, "Apple", 4.0, 2.4);
    items[401] = Item.food(401, "Bread", 5.0, 6.0);
    items[402] = Item.food(402, "Cooked Pork", 8.0, 12.8);
    items[403] = Item.food(403, "Raw Pork", 3.0, 1.8);
    items[404] = Item.food(404, "Cooked Beef", 8.0, 12.8);
    items[405] = Item.food(405, "Raw Beef", 3.0, 1.8);
    items[406] = Item.food(406, "Cooked Chicken", 6.0, 7.2);
    items[407] = Item.food(407, "Raw Chicken", 2.0, 1.2);
    items[408] = Item.food(408, "Golden Apple", 4.0, 9.6);

    // Leather Armor (500-503)
    items[500] = Item.armor(500, "Leather Helmet", .head, 1.0, 56);
    items[501] = Item.armor(501, "Leather Chestplate", .chest, 3.0, 81);
    items[502] = Item.armor(502, "Leather Leggings", .legs, 2.0, 76);
    items[503] = Item.armor(503, "Leather Boots", .feet, 1.0, 66);

    // Iron Armor (510-513)
    items[510] = Item.armor(510, "Iron Helmet", .head, 2.0, 166);
    items[511] = Item.armor(511, "Iron Chestplate", .chest, 6.0, 241);
    items[512] = Item.armor(512, "Iron Leggings", .legs, 5.0, 226);
    items[513] = Item.armor(513, "Iron Boots", .feet, 2.0, 196);

    // Gold Armor (520-523)
    items[520] = Item.armor(520, "Gold Helmet", .head, 2.0, 78);
    items[521] = Item.armor(521, "Gold Chestplate", .chest, 5.0, 113);
    items[522] = Item.armor(522, "Gold Leggings", .legs, 3.0, 106);
    items[523] = Item.armor(523, "Gold Boots", .feet, 1.0, 92);

    // Diamond Armor (530-533)
    items[530] = Item.armor(530, "Diamond Helmet", .head, 3.0, 364);
    items[531] = Item.armor(531, "Diamond Chestplate", .chest, 8.0, 529);
    items[532] = Item.armor(532, "Diamond Leggings", .legs, 6.0, 496);
    items[533] = Item.armor(533, "Diamond Boots", .feet, 3.0, 430);

    break :blk items;
};

/// Get item by ID
pub fn getItem(id: u16) ?*const Item {
    if (id >= ITEMS.len) return null;
    if (ITEMS[id].max_stack == 0) return null; // Empty/invalid item
    return &ITEMS[id];
}

/// Get item ID for a block type
pub fn getBlockItemId(block_type: Block) u16 {
    return switch (block_type) {
        .air => 0,
        .stone => 1,
        .dirt => 2,
        .grass => 3,
        .sand => 4,
        .water => 5,
        .wood => 6,
        .leaves => 7,
        .brick => 8,
        .glass => 9,
        .cobblestone => 10,
        .planks => 11,
        .gravel => 12,
        .gold => 13,
        .iron => 14,
        .coal => 15,
        .snow => 16,
        .ice => 17,
        .clay => 18,
        .obsidian => 19,
        .crafting_table => 20,
        .furnace => 21,
        .chest => 22,
        .torch => 23,
        .diamond_ore => 24,
    };
}

/// Get block type from item ID (returns null if not a block item)
pub fn getBlockFromItemId(id: u16) ?Block {
    if (id >= 25) return null;
    const item = getItem(id) orelse return null;
    return item.block_type;
}

// ============================================================================
// Tests
// ============================================================================

test "item creation" {
    const stone = ITEMS[1];
    try std.testing.expectEqualStrings("Stone", stone.name);
    try std.testing.expectEqual(ItemType.block, stone.item_type);
    try std.testing.expectEqual(@as(u32, 64), stone.max_stack);
}

test "tool item properties" {
    const wooden_pickaxe = ITEMS[100];
    try std.testing.expectEqualStrings("Wooden Pickaxe", wooden_pickaxe.name);
    try std.testing.expectEqual(ItemType.tool, wooden_pickaxe.item_type);
    try std.testing.expectEqual(@as(u32, 1), wooden_pickaxe.max_stack);
    try std.testing.expectEqual(ToolType.pickaxe, wooden_pickaxe.tool_type.?);
    try std.testing.expectEqual(ToolMaterial.wood, wooden_pickaxe.tool_material.?);
}

test "mining speed calculation" {
    const wooden_pickaxe = ITEMS[100];
    const stone_pickaxe = ITEMS[110];

    // Pickaxe should be faster on stone
    const wood_speed = wooden_pickaxe.getMiningSpeed(.stone);
    const stone_speed = stone_pickaxe.getMiningSpeed(.stone);

    try std.testing.expect(wood_speed > 1.0);
    try std.testing.expect(stone_speed > wood_speed);
}

test "block item lookup" {
    const stone_id = getBlockItemId(.stone);
    try std.testing.expectEqual(@as(u16, 1), stone_id);

    const block = getBlockFromItemId(stone_id);
    try std.testing.expectEqual(Block.stone, block.?);
}

test "food item properties" {
    const apple = ITEMS[400];
    try std.testing.expectEqualStrings("Apple", apple.name);
    try std.testing.expectEqual(ItemType.food, apple.item_type);
    try std.testing.expect(apple.hunger_restore > 0);
}
