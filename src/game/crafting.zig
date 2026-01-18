//! Crafting System
//!
//! Recipe matching and crafting functionality.

const std = @import("std");
const items_mod = @import("items.zig");
const inventory_mod = @import("inventory.zig");
const Item = items_mod.Item;
const ITEMS = items_mod.ITEMS;
const ItemStack = inventory_mod.ItemStack;
const Inventory = inventory_mod.Inventory;

/// A crafting recipe
pub const Recipe = struct {
    /// 3x3 grid of item IDs (null = empty slot)
    /// Layout: [0][1][2]
    ///         [3][4][5]
    ///         [6][7][8]
    pattern: [9]?u16,
    /// Result item stack
    result_id: u16,
    result_count: u32,
    /// If true, pattern shape doesn't matter (only ingredients)
    shapeless: bool,
    /// Minimum grid size required (2 for 2x2, 3 for 3x3)
    min_size: u8,

    const Self = @This();

    /// Create a shaped recipe
    pub fn shaped(pattern: [9]?u16, result_id: u16, result_count: u32) Self {
        return .{
            .pattern = pattern,
            .result_id = result_id,
            .result_count = result_count,
            .shapeless = false,
            .min_size = calculateMinSize(pattern),
        };
    }

    /// Create a shapeless recipe
    pub fn shapeless_recipe(ingredients: []const u16, result_id: u16, result_count: u32) Self {
        var pattern: [9]?u16 = [_]?u16{null} ** 9;
        for (ingredients, 0..) |ing, i| {
            if (i < 9) pattern[i] = ing;
        }
        return .{
            .pattern = pattern,
            .result_id = result_id,
            .result_count = result_count,
            .shapeless = true,
            .min_size = 1,
        };
    }

    /// Get the result as an ItemStack
    pub fn getResult(self: Self) ItemStack {
        return ItemStack.init(self.result_id, self.result_count);
    }

    /// Check if a grid pattern matches this recipe
    pub fn matches(self: Self, grid: [9]?u16) bool {
        if (self.shapeless) {
            return self.matchesShapeless(grid);
        } else {
            return self.matchesShaped(grid);
        }
    }

    /// Check shaped recipe match (pattern must match exactly, but can be offset)
    fn matchesShaped(self: Self, grid: [9]?u16) bool {
        // Try all possible offsets within the 3x3 grid
        const offsets = [_][2]i8{
            .{ 0, 0 },
            .{ 1, 0 },
            .{ 2, 0 },
            .{ 0, 1 },
            .{ 1, 1 },
            .{ 2, 1 },
            .{ 0, 2 },
            .{ 1, 2 },
            .{ 2, 2 },
        };

        for (offsets) |offset| {
            if (self.matchesAtOffset(grid, offset[0], offset[1])) {
                return true;
            }
        }
        return false;
    }

    /// Check if pattern matches at a specific offset
    fn matchesAtOffset(self: Self, grid: [9]?u16, ox: i8, oy: i8) bool {
        // First, find the bounds of the pattern
        var min_x: i8 = 3;
        var min_y: i8 = 3;
        var max_x: i8 = -1;
        var max_y: i8 = -1;

        for (0..9) |i| {
            if (self.pattern[i] != null) {
                const x: i8 = @intCast(i % 3);
                const y: i8 = @intCast(i / 3);
                min_x = @min(min_x, x);
                min_y = @min(min_y, y);
                max_x = @max(max_x, x);
                max_y = @max(max_y, y);
            }
        }

        if (max_x < 0) return false; // Empty pattern

        // Check bounds after offset
        if (min_x + ox < 0 or max_x + ox > 2) return false;
        if (min_y + oy < 0 or max_y + oy > 2) return false;

        // Check each cell
        for (0..9) |grid_idx| {
            const gx: i8 = @intCast(grid_idx % 3);
            const gy: i8 = @intCast(grid_idx / 3);

            // Calculate corresponding pattern position
            const px = gx - ox;
            const py = gy - oy;

            const grid_item = grid[grid_idx];

            if (px >= 0 and px < 3 and py >= 0 and py < 3) {
                const pattern_idx: usize = @intCast(px + py * 3);
                const pattern_item = self.pattern[pattern_idx];

                if (grid_item != pattern_item) return false;
            } else {
                // Outside pattern bounds - must be empty
                if (grid_item != null) return false;
            }
        }

        return true;
    }

    /// Check shapeless recipe match (ingredients only, order doesn't matter)
    fn matchesShapeless(self: Self, grid: [9]?u16) bool {
        // Count ingredients in pattern
        var pattern_counts: [600]u32 = [_]u32{0} ** 600;
        var pattern_total: u32 = 0;
        for (self.pattern) |item_id| {
            if (item_id) |id| {
                if (id < 600) {
                    pattern_counts[id] += 1;
                    pattern_total += 1;
                }
            }
        }

        // Count items in grid
        var grid_counts: [600]u32 = [_]u32{0} ** 600;
        var grid_total: u32 = 0;
        for (grid) |item_id| {
            if (item_id) |id| {
                if (id < 600) {
                    grid_counts[id] += 1;
                    grid_total += 1;
                }
            }
        }

        // Must have same total items
        if (pattern_total != grid_total) return false;

        // Check counts match
        for (0..600) |i| {
            if (pattern_counts[i] != grid_counts[i]) return false;
        }

        return true;
    }
};

/// Calculate minimum grid size for a pattern
fn calculateMinSize(pattern: [9]?u16) u8 {
    var max_x: usize = 0;
    var max_y: usize = 0;

    for (0..9) |i| {
        if (pattern[i] != null) {
            const x = i % 3;
            const y = i / 3;
            max_x = @max(max_x, x + 1);
            max_y = @max(max_y, y + 1);
        }
    }

    return @intCast(@max(max_x, max_y));
}

/// All recipes in the game
pub const RECIPES = [_]Recipe{
    // Wood -> Planks (shapeless, 1 log = 4 planks)
    Recipe.shapeless_recipe(&[_]u16{6}, 11, 4), // Wood -> Planks

    // Planks -> Sticks (2 planks = 4 sticks)
    Recipe.shaped(
        [9]?u16{ 11, null, null, 11, null, null, null, null, null },
        300,
        4,
    ),

    // Crafting table (2x2 planks)
    Recipe.shaped(
        [9]?u16{ 11, 11, null, 11, 11, null, null, null, null },
        20, // Crafting table block
        1,
    ),

    // Wooden Pickaxe
    Recipe.shaped(
        [9]?u16{ 11, 11, 11, null, 300, null, null, 300, null },
        100,
        1,
    ),

    // Wooden Axe
    Recipe.shaped(
        [9]?u16{ 11, 11, null, 11, 300, null, null, 300, null },
        101,
        1,
    ),

    // Wooden Shovel
    Recipe.shaped(
        [9]?u16{ 11, null, null, 300, null, null, 300, null, null },
        102,
        1,
    ),

    // Wooden Sword
    Recipe.shaped(
        [9]?u16{ 11, null, null, 11, null, null, 300, null, null },
        200,
        1,
    ),

    // Stone Pickaxe
    Recipe.shaped(
        [9]?u16{ 10, 10, 10, null, 300, null, null, 300, null },
        110,
        1,
    ),

    // Stone Axe
    Recipe.shaped(
        [9]?u16{ 10, 10, null, 10, 300, null, null, 300, null },
        111,
        1,
    ),

    // Stone Shovel
    Recipe.shaped(
        [9]?u16{ 10, null, null, 300, null, null, 300, null, null },
        112,
        1,
    ),

    // Stone Sword
    Recipe.shaped(
        [9]?u16{ 10, null, null, 10, null, null, 300, null, null },
        201,
        1,
    ),

    // Iron Pickaxe
    Recipe.shaped(
        [9]?u16{ 302, 302, 302, null, 300, null, null, 300, null },
        120,
        1,
    ),

    // Iron Axe
    Recipe.shaped(
        [9]?u16{ 302, 302, null, 302, 300, null, null, 300, null },
        121,
        1,
    ),

    // Iron Shovel
    Recipe.shaped(
        [9]?u16{ 302, null, null, 300, null, null, 300, null, null },
        122,
        1,
    ),

    // Iron Sword
    Recipe.shaped(
        [9]?u16{ 302, null, null, 302, null, null, 300, null, null },
        202,
        1,
    ),

    // Gold Pickaxe
    Recipe.shaped(
        [9]?u16{ 303, 303, 303, null, 300, null, null, 300, null },
        130,
        1,
    ),

    // Gold Sword
    Recipe.shaped(
        [9]?u16{ 303, null, null, 303, null, null, 300, null, null },
        203,
        1,
    ),

    // Diamond Pickaxe
    Recipe.shaped(
        [9]?u16{ 304, 304, 304, null, 300, null, null, 300, null },
        140,
        1,
    ),

    // Diamond Sword
    Recipe.shaped(
        [9]?u16{ 304, null, null, 304, null, null, 300, null, null },
        204,
        1,
    ),

    // Bread (3 wheat)
    Recipe.shaped(
        [9]?u16{ 309, 309, 309, null, null, null, null, null, null },
        401,
        1,
    ),

    // Glass from sand (smelting substitute - 1 sand = 1 glass)
    Recipe.shapeless_recipe(&[_]u16{4}, 9, 1),

    // Brick block from clay
    Recipe.shaped(
        [9]?u16{ 18, 18, null, 18, 18, null, null, null, null },
        8,
        1,
    ),

    // Cobblestone -> Stone (smelting substitute)
    Recipe.shapeless_recipe(&[_]u16{10}, 1, 1),

    // =========================================================================
    // Missing Gold Tools
    // =========================================================================

    // Gold Axe
    Recipe.shaped(
        [9]?u16{ 303, 303, null, 303, 300, null, null, 300, null },
        131,
        1,
    ),

    // Gold Shovel
    Recipe.shaped(
        [9]?u16{ 303, null, null, 300, null, null, 300, null, null },
        132,
        1,
    ),

    // Gold Hoe
    Recipe.shaped(
        [9]?u16{ 303, 303, null, null, 300, null, null, 300, null },
        133,
        1,
    ),

    // =========================================================================
    // Missing Diamond Tools
    // =========================================================================

    // Diamond Axe
    Recipe.shaped(
        [9]?u16{ 304, 304, null, 304, 300, null, null, 300, null },
        141,
        1,
    ),

    // Diamond Shovel
    Recipe.shaped(
        [9]?u16{ 304, null, null, 300, null, null, 300, null, null },
        142,
        1,
    ),

    // Diamond Hoe
    Recipe.shaped(
        [9]?u16{ 304, 304, null, null, 300, null, null, 300, null },
        143,
        1,
    ),

    // =========================================================================
    // Missing Wooden/Stone Hoes
    // =========================================================================

    // Wooden Hoe
    Recipe.shaped(
        [9]?u16{ 11, 11, null, null, 300, null, null, 300, null },
        103,
        1,
    ),

    // Stone Hoe
    Recipe.shaped(
        [9]?u16{ 10, 10, null, null, 300, null, null, 300, null },
        113,
        1,
    ),

    // Iron Hoe
    Recipe.shaped(
        [9]?u16{ 302, 302, null, null, 300, null, null, 300, null },
        123,
        1,
    ),

    // =========================================================================
    // Leather Armor
    // =========================================================================

    // Leather Helmet (306 = leather)
    Recipe.shaped(
        [9]?u16{ 306, 306, 306, 306, null, 306, null, null, null },
        500,
        1,
    ),

    // Leather Chestplate
    Recipe.shaped(
        [9]?u16{ 306, null, 306, 306, 306, 306, 306, 306, 306 },
        501,
        1,
    ),

    // Leather Leggings
    Recipe.shaped(
        [9]?u16{ 306, 306, 306, 306, null, 306, 306, null, 306 },
        502,
        1,
    ),

    // Leather Boots
    Recipe.shaped(
        [9]?u16{ null, null, null, 306, null, 306, 306, null, 306 },
        503,
        1,
    ),

    // =========================================================================
    // Iron Armor
    // =========================================================================

    // Iron Helmet
    Recipe.shaped(
        [9]?u16{ 302, 302, 302, 302, null, 302, null, null, null },
        510,
        1,
    ),

    // Iron Chestplate
    Recipe.shaped(
        [9]?u16{ 302, null, 302, 302, 302, 302, 302, 302, 302 },
        511,
        1,
    ),

    // Iron Leggings
    Recipe.shaped(
        [9]?u16{ 302, 302, 302, 302, null, 302, 302, null, 302 },
        512,
        1,
    ),

    // Iron Boots
    Recipe.shaped(
        [9]?u16{ null, null, null, 302, null, 302, 302, null, 302 },
        513,
        1,
    ),

    // =========================================================================
    // Gold Armor
    // =========================================================================

    // Gold Helmet
    Recipe.shaped(
        [9]?u16{ 303, 303, 303, 303, null, 303, null, null, null },
        520,
        1,
    ),

    // Gold Chestplate
    Recipe.shaped(
        [9]?u16{ 303, null, 303, 303, 303, 303, 303, 303, 303 },
        521,
        1,
    ),

    // Gold Leggings
    Recipe.shaped(
        [9]?u16{ 303, 303, 303, 303, null, 303, 303, null, 303 },
        522,
        1,
    ),

    // Gold Boots
    Recipe.shaped(
        [9]?u16{ null, null, null, 303, null, 303, 303, null, 303 },
        523,
        1,
    ),

    // =========================================================================
    // Diamond Armor
    // =========================================================================

    // Diamond Helmet
    Recipe.shaped(
        [9]?u16{ 304, 304, 304, 304, null, 304, null, null, null },
        530,
        1,
    ),

    // Diamond Chestplate
    Recipe.shaped(
        [9]?u16{ 304, null, 304, 304, 304, 304, 304, 304, 304 },
        531,
        1,
    ),

    // Diamond Leggings
    Recipe.shaped(
        [9]?u16{ 304, 304, 304, 304, null, 304, 304, null, 304 },
        532,
        1,
    ),

    // Diamond Boots
    Recipe.shaped(
        [9]?u16{ null, null, null, 304, null, 304, 304, null, 304 },
        533,
        1,
    ),

    // =========================================================================
    // Essentials
    // =========================================================================

    // Furnace (8 cobblestone in ring)
    Recipe.shaped(
        [9]?u16{ 10, 10, 10, 10, null, 10, 10, 10, 10 },
        21, // Furnace block
        1,
    ),

    // Chest (8 planks in ring)
    Recipe.shaped(
        [9]?u16{ 11, 11, 11, 11, null, 11, 11, 11, 11 },
        22, // Chest block
        1,
    ),

    // Torch (coal + stick)
    Recipe.shaped(
        [9]?u16{ 301, null, null, 300, null, null, null, null, null },
        23, // Torch block
        4,
    ),
};

/// Crafting system manager
pub const CraftingSystem = struct {
    /// Reference to extra recipes (for extensibility)
    extra_recipes: ?[]const Recipe,

    const Self = @This();

    /// Initialize the crafting system
    pub fn init() Self {
        return .{
            .extra_recipes = null,
        };
    }

    /// Find a matching recipe for the given grid pattern
    pub fn findRecipe(self: Self, grid: [9]?u16) ?*const Recipe {
        // Check built-in recipes
        for (&RECIPES) |*recipe| {
            if (recipe.matches(grid)) {
                return recipe;
            }
        }

        // Check extra recipes
        if (self.extra_recipes) |extras| {
            for (extras) |*recipe| {
                if (recipe.matches(grid)) {
                    return recipe;
                }
            }
        }

        return null;
    }

    /// Check if the player can craft a recipe with their current inventory
    pub fn canCraft(self: Self, inv: *const Inventory, recipe: *const Recipe) bool {
        _ = self;

        // Check if player has all required ingredients
        var required: [600]u32 = [_]u32{0} ** 600;

        for (recipe.pattern) |item_id| {
            if (item_id) |id| {
                if (id < 600) {
                    required[id] += 1;
                }
            }
        }

        for (0..600) |i| {
            if (required[i] > 0) {
                if (!inv.hasItem(@intCast(i), required[i])) {
                    return false;
                }
            }
        }

        return true;
    }

    /// Perform crafting - consume ingredients and give result
    pub fn craft(self: Self, inv: *Inventory, recipe: *const Recipe) bool {
        if (!self.canCraft(inv, recipe)) return false;

        // Consume ingredients from crafting grid
        for (&inv.crafting) |*slot| {
            if (slot.*) |*stack| {
                stack.count -= 1;
                if (stack.count == 0) {
                    slot.* = null;
                }
            }
        }

        // Give result (or add to held item if compatible)
        const result = recipe.getResult();

        if (inv.held_item) |*held| {
            if (held.item_id == result.item_id and held.durability == null) {
                held.count += result.count;
                return true;
            }
        }

        // Try to add to inventory
        const leftover = inv.addItemStack(result);
        if (leftover > 0) {
            // If inventory is full, put in crafting result or held
            if (inv.held_item == null) {
                inv.held_item = ItemStack.init(result.item_id, leftover);
            } else {
                inv.crafting_result = ItemStack.init(result.item_id, leftover);
            }
        }

        return true;
    }

    /// Update crafting result based on current grid contents
    pub fn updateCraftingResult(self: Self, inv: *Inventory) void {
        const pattern = inv.getCraftingPattern();
        if (self.findRecipe(pattern)) |recipe| {
            inv.crafting_result = recipe.getResult();
        } else {
            inv.crafting_result = null;
        }
    }

    /// Take the crafting result and consume ingredients
    pub fn takeCraftingResult(self: Self, inv: *Inventory) ?ItemStack {
        const result = inv.crafting_result orelse return null;

        // Consume ingredients
        for (&inv.crafting) |*slot| {
            if (slot.*) |*stack| {
                stack.count -= 1;
                if (stack.count == 0) {
                    slot.* = null;
                }
            }
        }

        // Update for next craft
        self.updateCraftingResult(inv);

        return result;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "recipe matching - shaped" {
    // Wooden pickaxe recipe
    const recipe = Recipe.shaped(
        [9]?u16{ 11, 11, 11, null, 300, null, null, 300, null },
        100,
        1,
    );

    // Exact match
    try std.testing.expect(recipe.matches([9]?u16{ 11, 11, 11, null, 300, null, null, 300, null }));

    // Wrong pattern
    try std.testing.expect(!recipe.matches([9]?u16{ 11, 11, null, null, 300, null, null, 300, null }));
}

test "recipe matching - shapeless" {
    const recipe = Recipe.shapeless_recipe(&[_]u16{6}, 11, 4);

    // Wood anywhere in grid
    try std.testing.expect(recipe.matches([9]?u16{ 6, null, null, null, null, null, null, null, null }));
    try std.testing.expect(recipe.matches([9]?u16{ null, null, null, null, 6, null, null, null, null }));
    try std.testing.expect(recipe.matches([9]?u16{ null, null, null, null, null, null, null, null, 6 }));

    // Wrong item
    try std.testing.expect(!recipe.matches([9]?u16{ 1, null, null, null, null, null, null, null, null }));

    // Extra items
    try std.testing.expect(!recipe.matches([9]?u16{ 6, 6, null, null, null, null, null, null, null }));
}

test "crafting system find recipe" {
    const system = CraftingSystem.init();

    // Wood to planks
    const pattern = [9]?u16{ 6, null, null, null, null, null, null, null, null };
    const recipe = system.findRecipe(pattern);

    try std.testing.expect(recipe != null);
    try std.testing.expectEqual(@as(u16, 11), recipe.?.result_id);
    try std.testing.expectEqual(@as(u32, 4), recipe.?.result_count);
}

test "crafting system with inventory" {
    var inv = Inventory.init();
    const system = CraftingSystem.init();

    // Add wood to crafting grid
    inv.crafting[0] = ItemStack.init(6, 1);

    // Update crafting result
    system.updateCraftingResult(&inv);

    try std.testing.expect(inv.crafting_result != null);
    try std.testing.expectEqual(@as(u16, 11), inv.crafting_result.?.item_id);
    try std.testing.expectEqual(@as(u32, 4), inv.crafting_result.?.count);

    // Take the result
    const result = system.takeCraftingResult(&inv);
    try std.testing.expect(result != null);
    try std.testing.expect(inv.crafting[0] == null); // Consumed
}

test "recipe minimum size calculation" {
    // 2x2 pattern
    const pattern_2x2 = [9]?u16{ 11, 11, null, 11, 11, null, null, null, null };
    try std.testing.expectEqual(@as(u8, 2), calculateMinSize(pattern_2x2));

    // 3x3 pattern
    const pattern_3x3 = [9]?u16{ 11, 11, 11, null, 300, null, null, 300, null };
    try std.testing.expectEqual(@as(u8, 3), calculateMinSize(pattern_3x3));

    // 1x1 pattern
    const pattern_1x1 = [9]?u16{ 6, null, null, null, null, null, null, null, null };
    try std.testing.expectEqual(@as(u8, 1), calculateMinSize(pattern_1x1));
}
