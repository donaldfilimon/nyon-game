//! Inventory System
//!
//! Player inventory management with hotbar, armor, and crafting grid support.

const std = @import("std");
const items_mod = @import("items.zig");
const Item = items_mod.Item;
const ITEMS = items_mod.ITEMS;

/// Inventory dimensions
pub const INVENTORY_SIZE: usize = 36; // 4 rows of 9 slots
pub const HOTBAR_SIZE: usize = 9;
pub const ARMOR_SIZE: usize = 4;
pub const CRAFTING_GRID_SIZE: usize = 4; // 2x2 grid

/// Stack of items with count and durability tracking
pub const ItemStack = struct {
    item_id: u16,
    count: u32,
    durability: ?u32, // Current durability (null for non-tool items)

    const Self = @This();

    /// Create a new item stack
    pub fn init(item_id: u16, count: u32) Self {
        const item = items_mod.getItem(item_id);
        return .{
            .item_id = item_id,
            .count = count,
            .durability = if (item) |i| i.durability else null,
        };
    }

    /// Create a single item stack
    pub fn single(item_id: u16) Self {
        return init(item_id, 1);
    }

    /// Get the item definition
    pub fn getItem(self: Self) ?*const Item {
        return items_mod.getItem(self.item_id);
    }

    /// Get maximum stack size for this item
    pub fn getMaxStack(self: Self) u32 {
        const item = self.getItem() orelse return 1;
        return item.max_stack;
    }

    /// Check if this stack can be merged with another
    pub fn canStack(self: Self, other: Self) bool {
        // Can't stack different items
        if (self.item_id != other.item_id) return false;

        // Can't stack items with durability (tools/weapons/armor)
        if (self.durability != null) return false;

        // Check if we have room
        const max = self.getMaxStack();
        return self.count < max;
    }

    /// Merge another stack into this one
    /// Returns the leftover count that couldn't be merged
    pub fn merge(self: *Self, other: *Self) u32 {
        if (!self.canStack(other.*)) return other.count;

        const max = self.getMaxStack();
        const space = max - self.count;
        const to_add = @min(space, other.count);

        self.count += to_add;
        other.count -= to_add;

        return other.count;
    }

    /// Split this stack, removing the specified amount
    /// Returns the split stack, or null if not enough items
    pub fn split(self: *Self, amount: u32) ?Self {
        if (amount == 0 or amount > self.count) return null;

        const new_stack = Self{
            .item_id = self.item_id,
            .count = amount,
            .durability = self.durability,
        };

        self.count -= amount;
        return new_stack;
    }

    /// Use durability (for tools)
    /// Returns true if the item broke
    pub fn useDurability(self: *Self, amount: u32) bool {
        if (self.durability) |*dur| {
            if (dur.* <= amount) {
                dur.* = 0;
                return true; // Item broke
            }
            dur.* -= amount;
        }
        return false;
    }

    /// Check if stack is empty
    pub fn isEmpty(self: Self) bool {
        return self.count == 0;
    }

    /// Get remaining durability as a percentage (0.0 - 1.0)
    pub fn getDurabilityPercent(self: Self) f32 {
        const current = self.durability orelse return 1.0;
        const item = self.getItem() orelse return 1.0;
        const max = item.durability orelse return 1.0;
        if (max == 0) return 1.0;
        return @as(f32, @floatFromInt(current)) / @as(f32, @floatFromInt(max));
    }
};

/// Main inventory container
pub const Inventory = struct {
    /// Main inventory slots (36 slots: 4 rows x 9 columns)
    slots: [INVENTORY_SIZE]?ItemStack = [_]?ItemStack{null} ** INVENTORY_SIZE,
    /// Armor slots (head, chest, legs, feet)
    armor: [ARMOR_SIZE]?ItemStack = [_]?ItemStack{null} ** ARMOR_SIZE,
    /// 2x2 crafting grid
    crafting: [CRAFTING_GRID_SIZE]?ItemStack = [_]?ItemStack{null} ** CRAFTING_GRID_SIZE,
    /// Crafting result slot
    crafting_result: ?ItemStack = null,
    /// Item held by mouse cursor
    held_item: ?ItemStack = null,
    /// Currently selected hotbar slot (0-8)
    selected_slot: u8 = 0,

    const Self = @This();

    /// Initialize an empty inventory
    pub fn init() Self {
        return Self{};
    }

    /// Get hotbar slots (first 9 inventory slots)
    pub fn getHotbar(self: *Self) *[HOTBAR_SIZE]?ItemStack {
        return self.slots[0..HOTBAR_SIZE];
    }

    /// Get hotbar slots (const version)
    pub fn getHotbarConst(self: *const Self) *const [HOTBAR_SIZE]?ItemStack {
        return self.slots[0..HOTBAR_SIZE];
    }

    /// Add an item to the inventory
    /// Returns the leftover count that couldn't be added
    pub fn addItem(self: *Self, item_id: u16, count: u32) u32 {
        var remaining = count;

        // First, try to merge with existing stacks
        for (&self.slots) |*slot| {
            if (remaining == 0) break;

            if (slot.*) |*stack| {
                if (stack.item_id == item_id and stack.durability == null) {
                    var new_stack = ItemStack.init(item_id, remaining);
                    remaining = stack.merge(&new_stack);
                }
            }
        }

        // Then, find empty slots
        for (&self.slots) |*slot| {
            if (remaining == 0) break;

            if (slot.* == null) {
                const item = items_mod.getItem(item_id) orelse continue;
                const to_add = @min(remaining, item.max_stack);
                slot.* = ItemStack.init(item_id, to_add);
                remaining -= to_add;
            }
        }

        return remaining;
    }

    /// Add an item stack to the inventory
    /// Returns the leftover count that couldn't be added
    pub fn addItemStack(self: *Self, stack: ItemStack) u32 {
        return self.addItem(stack.item_id, stack.count);
    }

    /// Remove items from the inventory
    /// Returns true if the full amount was removed
    pub fn removeItem(self: *Self, item_id: u16, count: u32) bool {
        if (!self.hasItem(item_id, count)) return false;

        var remaining = count;

        for (&self.slots) |*slot| {
            if (remaining == 0) break;

            if (slot.*) |*stack| {
                if (stack.item_id == item_id) {
                    const to_remove = @min(remaining, stack.count);
                    stack.count -= to_remove;
                    remaining -= to_remove;

                    if (stack.count == 0) {
                        slot.* = null;
                    }
                }
            }
        }

        return remaining == 0;
    }

    /// Check if the inventory contains at least the specified count of an item
    pub fn hasItem(self: *const Self, item_id: u16, count: u32) bool {
        var total: u32 = 0;

        for (self.slots) |slot| {
            if (slot) |stack| {
                if (stack.item_id == item_id) {
                    total += stack.count;
                    if (total >= count) return true;
                }
            }
        }

        return total >= count;
    }

    /// Count total items of a type in inventory
    pub fn countItem(self: *const Self, item_id: u16) u32 {
        var total: u32 = 0;

        for (self.slots) |slot| {
            if (slot) |stack| {
                if (stack.item_id == item_id) {
                    total += stack.count;
                }
            }
        }

        return total;
    }

    /// Get the currently selected hotbar item
    pub fn getSelectedItem(self: *const Self) ?ItemStack {
        if (self.selected_slot >= HOTBAR_SIZE) return null;
        return self.slots[self.selected_slot];
    }

    /// Get a mutable reference to the selected item
    pub fn getSelectedItemPtr(self: *Self) ?*ItemStack {
        if (self.selected_slot >= HOTBAR_SIZE) return null;
        if (self.slots[self.selected_slot]) |*stack| {
            return stack;
        }
        return null;
    }

    /// Set the selected hotbar slot
    pub fn setSelectedSlot(self: *Self, slot: u8) void {
        if (slot < HOTBAR_SIZE) {
            self.selected_slot = slot;
        }
    }

    /// Swap two slots
    pub fn swapSlots(self: *Self, a: u8, b: u8) void {
        if (a >= INVENTORY_SIZE or b >= INVENTORY_SIZE) return;
        const temp = self.slots[a];
        self.slots[a] = self.slots[b];
        self.slots[b] = temp;
    }

    /// Move items from one slot to another
    /// If amount is 0, moves the entire stack
    pub fn moveToSlot(self: *Self, from: u8, to: u8, amount: u32) void {
        if (from >= INVENTORY_SIZE or to >= INVENTORY_SIZE) return;
        if (from == to) return;

        const from_stack = self.slots[from] orelse return;

        if (self.slots[to]) |*to_stack| {
            // Try to merge
            if (to_stack.item_id == from_stack.item_id and to_stack.durability == null) {
                var from_copy = from_stack;
                if (amount > 0 and amount < from_copy.count) {
                    from_copy.count = amount;
                }
                const leftover = to_stack.merge(&from_copy);

                // Update source slot
                if (self.slots[from]) |*s| {
                    const moved = from_copy.count + (from_stack.count - amount) - leftover;
                    _ = moved;
                    if (amount == 0 or amount >= from_stack.count) {
                        s.count = leftover;
                    } else {
                        s.count = from_stack.count - (amount - leftover);
                    }
                    if (s.count == 0) {
                        self.slots[from] = null;
                    }
                }
            } else {
                // Different items - swap if moving entire stack
                if (amount == 0 or amount >= from_stack.count) {
                    self.swapSlots(from, to);
                }
            }
        } else {
            // Empty destination - move items
            if (amount == 0 or amount >= from_stack.count) {
                self.slots[to] = from_stack;
                self.slots[from] = null;
            } else {
                if (self.slots[from]) |*s| {
                    self.slots[to] = s.split(amount);
                    if (s.count == 0) {
                        self.slots[from] = null;
                    }
                }
            }
        }
    }

    /// Pick up item with cursor (or swap if already holding)
    pub fn pickUpFromSlot(self: *Self, slot_index: u8) void {
        if (slot_index >= INVENTORY_SIZE) return;

        if (self.held_item) |held| {
            // Already holding something - try to place or swap
            if (self.slots[slot_index]) |*slot_stack| {
                if (slot_stack.item_id == held.item_id and slot_stack.durability == null) {
                    // Merge into slot
                    var held_copy = held;
                    const leftover = slot_stack.merge(&held_copy);
                    if (leftover == 0) {
                        self.held_item = null;
                    } else {
                        self.held_item = ItemStack.init(held.item_id, leftover);
                    }
                } else {
                    // Swap
                    const temp = slot_stack.*;
                    self.slots[slot_index] = held;
                    self.held_item = temp;
                }
            } else {
                // Place into empty slot
                self.slots[slot_index] = held;
                self.held_item = null;
            }
        } else {
            // Pick up from slot
            self.held_item = self.slots[slot_index];
            self.slots[slot_index] = null;
        }
    }

    /// Place one item from cursor into slot
    pub fn placeOneInSlot(self: *Self, slot_index: u8) void {
        if (slot_index >= INVENTORY_SIZE) return;

        const held = self.held_item orelse return;

        if (self.slots[slot_index]) |*slot_stack| {
            if (slot_stack.item_id == held.item_id and slot_stack.durability == null) {
                // Add one to existing stack
                if (slot_stack.count < slot_stack.getMaxStack()) {
                    slot_stack.count += 1;
                    if (held.count <= 1) {
                        self.held_item = null;
                    } else {
                        self.held_item = ItemStack.init(held.item_id, held.count - 1);
                    }
                }
            }
        } else {
            // Place one into empty slot
            self.slots[slot_index] = ItemStack.single(held.item_id);
            if (held.count <= 1) {
                self.held_item = null;
            } else {
                self.held_item = ItemStack.init(held.item_id, held.count - 1);
            }
        }
    }

    /// Quick-move item from slot (shift-click behavior)
    /// Moves items between main inventory and hotbar, or auto-equips armor
    pub fn quickMove(self: *Self, slot_index: u8) void {
        if (slot_index >= INVENTORY_SIZE) return;

        const stack = self.slots[slot_index] orelse return;

        // Try to auto-equip if it's armor
        if (stack.getItem()) |item| {
            if (item.armor_slot) |armor_slot| {
                const armor_index = armor_slot.toIndex();
                if (self.armor[armor_index] == null) {
                    // Equip armor to empty slot
                    self.armor[armor_index] = stack;
                    self.slots[slot_index] = null;
                    return;
                } else {
                    // Swap with existing armor
                    const existing = self.armor[armor_index];
                    self.armor[armor_index] = stack;
                    self.slots[slot_index] = existing;
                    return;
                }
            }
        }

        if (slot_index < HOTBAR_SIZE) {
            // From hotbar -> try to move to main inventory
            for (HOTBAR_SIZE..INVENTORY_SIZE) |i| {
                if (self.slots[i]) |*s| {
                    if (s.item_id == stack.item_id and s.durability == null) {
                        var from_stack = stack;
                        const leftover = s.merge(&from_stack);
                        if (leftover == 0) {
                            self.slots[slot_index] = null;
                            return;
                        }
                        self.slots[slot_index] = ItemStack.init(stack.item_id, leftover);
                    }
                }
            }
            // Find empty slot in main inventory
            for (HOTBAR_SIZE..INVENTORY_SIZE) |i| {
                if (self.slots[i] == null) {
                    self.slots[i] = self.slots[slot_index];
                    self.slots[slot_index] = null;
                    return;
                }
            }
        } else {
            // From main inventory -> try to move to hotbar
            for (0..HOTBAR_SIZE) |i| {
                if (self.slots[i]) |*s| {
                    if (s.item_id == stack.item_id and s.durability == null) {
                        var from_stack = stack;
                        const leftover = s.merge(&from_stack);
                        if (leftover == 0) {
                            self.slots[slot_index] = null;
                            return;
                        }
                        self.slots[slot_index] = ItemStack.init(stack.item_id, leftover);
                    }
                }
            }
            // Find empty slot in hotbar
            for (0..HOTBAR_SIZE) |i| {
                if (self.slots[i] == null) {
                    self.slots[i] = self.slots[slot_index];
                    self.slots[slot_index] = null;
                    return;
                }
            }
        }
    }

    /// Get slot from armor index
    pub fn getArmorSlot(self: *Self, index: u8) ?*ItemStack {
        if (index >= ARMOR_SIZE) return null;
        if (self.armor[index]) |*stack| {
            return stack;
        }
        return null;
    }

    /// Equip armor to the appropriate slot
    pub fn equipArmor(self: *Self, stack: ItemStack) bool {
        const item = stack.getItem() orelse return false;
        const slot = item.armor_slot orelse return false;
        const index = slot.toIndex();

        if (self.armor[index] != null) return false; // Slot occupied

        self.armor[index] = stack;
        return true;
    }

    /// Calculate total armor points from equipped armor
    pub fn getTotalArmor(self: *const Self) f32 {
        var total: f32 = 0;
        for (self.armor) |slot| {
            if (slot) |stack| {
                if (stack.getItem()) |item| {
                    total += item.armor_points;
                }
            }
        }
        return total;
    }

    /// Clear the crafting grid and return items to inventory
    pub fn clearCraftingGrid(self: *Self) void {
        for (&self.crafting) |*slot| {
            if (slot.*) |stack| {
                _ = self.addItemStack(stack);
                slot.* = null;
            }
        }
        self.crafting_result = null;
    }

    /// Get the 3x3 crafting pattern (2x2 grid in top-left)
    pub fn getCraftingPattern(self: *const Self) [9]?u16 {
        var pattern: [9]?u16 = [_]?u16{null} ** 9;

        // Map 2x2 to top-left of 3x3
        if (self.crafting[0]) |s| pattern[0] = s.item_id;
        if (self.crafting[1]) |s| pattern[1] = s.item_id;
        if (self.crafting[2]) |s| pattern[3] = s.item_id;
        if (self.crafting[3]) |s| pattern[4] = s.item_id;

        return pattern;
    }

    /// Check if inventory is full
    pub fn isFull(self: *const Self) bool {
        for (self.slots) |slot| {
            if (slot == null) return false;
        }
        return true;
    }

    /// Count empty slots
    pub fn emptySlotCount(self: *const Self) u32 {
        var count: u32 = 0;
        for (self.slots) |slot| {
            if (slot == null) count += 1;
        }
        return count;
    }

    /// Drop held item (returns it and clears)
    pub fn dropHeldItem(self: *Self) ?ItemStack {
        const held = self.held_item;
        self.held_item = null;
        return held;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "inventory initialization" {
    var inv = Inventory.init();

    try std.testing.expectEqual(@as(u8, 0), inv.selected_slot);
    try std.testing.expect(inv.getSelectedItem() == null);
    try std.testing.expectEqual(@as(u32, INVENTORY_SIZE), inv.emptySlotCount());
}

test "add and remove items" {
    var inv = Inventory.init();

    // Add 10 stone (item ID 1)
    const leftover = inv.addItem(1, 10);
    try std.testing.expectEqual(@as(u32, 0), leftover);
    try std.testing.expect(inv.hasItem(1, 10));
    try std.testing.expectEqual(@as(u32, 10), inv.countItem(1));

    // Remove 5 stone
    try std.testing.expect(inv.removeItem(1, 5));
    try std.testing.expectEqual(@as(u32, 5), inv.countItem(1));

    // Try to remove more than we have
    try std.testing.expect(!inv.removeItem(1, 10));
}

test "item stack merging" {
    var stack1 = ItemStack.init(1, 32);
    var stack2 = ItemStack.init(1, 48);

    // 32 + 48 = 80, max is 64, so 16 leftover
    const leftover = stack1.merge(&stack2);
    try std.testing.expectEqual(@as(u32, 64), stack1.count);
    try std.testing.expectEqual(@as(u32, 16), leftover);
}

test "item stack splitting" {
    var stack = ItemStack.init(1, 64);

    const split = stack.split(32);
    try std.testing.expect(split != null);
    try std.testing.expectEqual(@as(u32, 32), split.?.count);
    try std.testing.expectEqual(@as(u32, 32), stack.count);
}

test "hotbar selection" {
    var inv = Inventory.init();

    _ = inv.addItem(1, 10); // Add stone to first slot

    try std.testing.expect(inv.getSelectedItem() != null);

    inv.setSelectedSlot(5);
    try std.testing.expect(inv.getSelectedItem() == null);
}

test "slot swapping" {
    var inv = Inventory.init();

    _ = inv.addItem(1, 10); // Stone in slot 0
    _ = inv.addItem(2, 10); // Dirt in slot 1

    inv.swapSlots(0, 1);

    const slot0 = inv.slots[0].?;
    const slot1 = inv.slots[1].?;

    try std.testing.expectEqual(@as(u16, 2), slot0.item_id);
    try std.testing.expectEqual(@as(u16, 1), slot1.item_id);
}

test "quick move" {
    var inv = Inventory.init();

    // Add item to hotbar
    inv.slots[0] = ItemStack.init(1, 10);

    // Quick move to main inventory
    inv.quickMove(0);

    try std.testing.expect(inv.slots[0] == null);
    try std.testing.expect(inv.slots[HOTBAR_SIZE] != null);
}

test "tool durability" {
    var stack = ItemStack.init(100, 1); // Wooden pickaxe

    try std.testing.expect(stack.durability != null);

    const broke = stack.useDurability(10);
    try std.testing.expect(!broke);
    try std.testing.expect(stack.getDurabilityPercent() < 1.0);
}
