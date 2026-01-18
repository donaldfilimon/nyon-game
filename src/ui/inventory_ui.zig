//! Inventory UI
//!
//! Renders the player inventory, crafting grid, and handles mouse interaction.

const std = @import("std");
const render_mod = @import("../render/render.zig");
const text = @import("text.zig");
const ui_mod = @import("ui.zig");
const inventory_mod = @import("../game/inventory.zig");
const items_mod = @import("../game/items.zig");
const crafting_mod = @import("../game/crafting.zig");
const input = @import("../platform/input.zig");

const Inventory = inventory_mod.Inventory;
const ItemStack = inventory_mod.ItemStack;
const CraftingSystem = crafting_mod.CraftingSystem;
const Renderer = render_mod.Renderer;
const Color = render_mod.Color;

/// Slot size in pixels
const SLOT_SIZE: i32 = 36;
/// Padding between slots
const SLOT_PADDING: i32 = 4;
/// Inner padding for item icon
const ICON_PADDING: i32 = 4;
/// Inventory panel background color
const PANEL_BG = Color.fromRgba(40, 40, 50, 230);
/// Slot background color
const SLOT_BG = Color.fromRgba(60, 60, 70, 200);
/// Slot hover color
const SLOT_HOVER = Color.fromRgba(80, 80, 100, 220);
/// Slot selected color
const SLOT_SELECTED = Color.fromRgba(100, 100, 140, 240);
/// Text color
const TEXT_COLOR = Color.WHITE;
/// Item count color
const COUNT_COLOR = Color.fromRgb(255, 255, 200);

/// Inventory UI state
pub const InventoryUI = struct {
    /// Is the inventory currently open
    is_open: bool = false,
    /// Currently hovered slot (-1 for none)
    hovered_slot: i32 = -1,
    /// Hovered slot type
    hovered_type: SlotType = .inventory,
    /// Tooltip text buffers (separate for each stat line)
    tooltip_buf: [32]u8 = undefined,
    tooltip_buf2: [32]u8 = undefined,
    tooltip_buf3: [32]u8 = undefined,
    tooltip_buf4: [32]u8 = undefined,
    tooltip_buf5: [32]u8 = undefined,
    /// Mouse position
    mouse_x: i32 = 0,
    mouse_y: i32 = 0,

    const Self = @This();

    /// Slot types for tracking which section is being interacted with
    pub const SlotType = enum {
        inventory,
        hotbar,
        armor,
        crafting,
        crafting_result,
    };

    /// Toggle inventory open/closed
    pub fn toggle(self: *Self) void {
        self.is_open = !self.is_open;
        self.hovered_slot = -1;
    }

    /// Close the inventory
    pub fn close(self: *Self) void {
        self.is_open = false;
        self.hovered_slot = -1;
    }

    /// Update inventory UI with input
    pub fn update(
        self: *Self,
        inv: *Inventory,
        crafting: *CraftingSystem,
        input_state: *const input.State,
    ) void {
        if (!self.is_open) return;

        // Get mouse position
        const pos = input_state.getMousePosition();
        self.mouse_x = pos.x;
        self.mouse_y = pos.y;

        // Update crafting result
        crafting.updateCraftingResult(inv);

        // Handle left click
        if (input_state.isMouseButtonDown(.left)) {
            self.handleClick(inv, crafting, false, input_state.isKeyDown(.left_shift));
        }

        // Handle right click (place one item)
        if (input_state.isMouseButtonDown(.right)) {
            self.handleClick(inv, crafting, true, false);
        }
    }

    /// Handle mouse click on inventory
    fn handleClick(
        self: *Self,
        inv: *Inventory,
        crafting: *CraftingSystem,
        right_click: bool,
        shift_click: bool,
    ) void {
        if (self.hovered_slot < 0) return;

        const slot: u8 = @intCast(self.hovered_slot);

        switch (self.hovered_type) {
            .inventory, .hotbar => {
                if (shift_click) {
                    inv.quickMove(slot);
                } else if (right_click) {
                    inv.placeOneInSlot(slot);
                } else {
                    inv.pickUpFromSlot(slot);
                }
            },
            .crafting => {
                const crafting_slot: u8 = slot;
                if (crafting_slot < 4) {
                    // Map to crafting grid position
                    if (right_click) {
                        if (inv.held_item) |held| {
                            if (inv.crafting[crafting_slot]) |*stack| {
                                if (stack.item_id == held.item_id and stack.count < stack.getMaxStack()) {
                                    stack.count += 1;
                                    if (held.count <= 1) {
                                        inv.held_item = null;
                                    } else {
                                        inv.held_item = ItemStack.init(held.item_id, held.count - 1);
                                    }
                                }
                            } else {
                                inv.crafting[crafting_slot] = ItemStack.single(held.item_id);
                                if (held.count <= 1) {
                                    inv.held_item = null;
                                } else {
                                    inv.held_item = ItemStack.init(held.item_id, held.count - 1);
                                }
                            }
                        }
                    } else {
                        // Pick up or swap
                        if (inv.held_item) |held| {
                            const temp = inv.crafting[crafting_slot];
                            inv.crafting[crafting_slot] = held;
                            inv.held_item = temp;
                        } else {
                            inv.held_item = inv.crafting[crafting_slot];
                            inv.crafting[crafting_slot] = null;
                        }
                    }
                    crafting.updateCraftingResult(inv);
                }
            },
            .crafting_result => {
                // Take crafting result
                if (inv.crafting_result) |result| {
                    if (inv.held_item == null) {
                        inv.held_item = crafting.takeCraftingResult(inv);
                    } else if (inv.held_item.?.item_id == result.item_id) {
                        if (crafting.takeCraftingResult(inv)) |taken| {
                            inv.held_item.?.count += taken.count;
                        }
                    }
                }
            },
            .armor => {
                // Handle armor slot interaction
                const armor_index: u8 = slot;
                if (armor_index >= inventory_mod.ARMOR_SIZE) return;

                if (shift_click) {
                    // Shift-click: move armor to inventory
                    if (inv.armor[armor_index]) |armor_stack| {
                        const leftover = inv.addItemStack(armor_stack);
                        if (leftover == 0) {
                            inv.armor[armor_index] = null;
                        }
                    }
                } else if (inv.held_item) |held| {
                    // Check if held item is armor that fits this slot
                    const item = held.getItem() orelse return;
                    if (item.armor_slot) |armor_slot| {
                        if (armor_slot.toIndex() == armor_index) {
                            // Correct armor type for this slot - swap or place
                            if (inv.armor[armor_index]) |existing| {
                                // Swap armor
                                inv.armor[armor_index] = held;
                                inv.held_item = existing;
                            } else {
                                // Place armor in empty slot
                                inv.armor[armor_index] = held;
                                inv.held_item = null;
                            }
                        }
                        // Wrong slot type - do nothing
                    }
                    // Not armor - do nothing
                } else {
                    // Pick up armor from slot
                    inv.held_item = inv.armor[armor_index];
                    inv.armor[armor_index] = null;
                }
            },
        }
    }

    /// Render the inventory UI
    pub fn draw(
        self: *Self,
        renderer: *Renderer,
        inv: *const Inventory,
        screen_width: u32,
        screen_height: u32,
    ) void {
        if (!self.is_open) return;

        // Calculate panel dimensions (extra width for armor slots on left)
        const armor_section_width: i32 = SLOT_SIZE + SLOT_PADDING + 10;
        const panel_width: i32 = armor_section_width + 9 * (SLOT_SIZE + SLOT_PADDING) + SLOT_PADDING + 20;
        const panel_height: i32 = 6 * (SLOT_SIZE + SLOT_PADDING) + SLOT_PADDING + 80;

        // Center the panel
        const panel_x = @as(i32, @intCast(screen_width / 2)) - panel_width / 2;
        const panel_y = @as(i32, @intCast(screen_height / 2)) - panel_height / 2;

        // Draw panel background
        self.drawFilledRect(renderer, panel_x, panel_y, panel_width, panel_height, PANEL_BG);
        self.drawRectOutline(renderer, panel_x, panel_y, panel_width, panel_height, Color.fromRgb(80, 80, 100));

        // Reset hovered slot
        self.hovered_slot = -1;

        // Title
        text.drawText(renderer, &text.default_font, "Inventory", panel_x + 10, panel_y + 8, .{
            .color = TEXT_COLOR,
        });

        // Draw crafting section
        const craft_x = panel_x + panel_width - 120;
        const craft_y = panel_y + 30;

        text.drawText(renderer, &text.default_font, "Crafting", craft_x, craft_y - 20, .{
            .color = Color.fromRgb(180, 180, 180),
        });

        // 2x2 crafting grid
        for (0..4) |i| {
            const cx = craft_x + @as(i32, @intCast(i % 2)) * (SLOT_SIZE + SLOT_PADDING);
            const cy = craft_y + @as(i32, @intCast(i / 2)) * (SLOT_SIZE + SLOT_PADDING);
            const stack = inv.crafting[i];
            const is_hovered = self.isPointInRect(self.mouse_x, self.mouse_y, cx, cy, SLOT_SIZE, SLOT_SIZE);

            if (is_hovered) {
                self.hovered_slot = @intCast(i);
                self.hovered_type = .crafting;
            }

            self.renderSlot(renderer, cx, cy, stack, is_hovered, false);
        }

        // Crafting result (arrow and result slot)
        const result_x = craft_x + 2 * (SLOT_SIZE + SLOT_PADDING) + 20;
        const result_y = craft_y + (SLOT_SIZE + SLOT_PADDING) / 2;

        // Draw arrow
        text.drawText(renderer, &text.default_font, "->", result_x - 15, result_y + 10, .{
            .color = Color.fromRgb(150, 150, 150),
        });

        // Result slot
        const result_hovered = self.isPointInRect(self.mouse_x, self.mouse_y, result_x, result_y, SLOT_SIZE, SLOT_SIZE);
        if (result_hovered) {
            self.hovered_slot = 0;
            self.hovered_type = .crafting_result;
        }
        self.renderSlot(renderer, result_x, result_y, inv.crafting_result, result_hovered, false);

        // Draw armor section (vertical column on left side)
        const armor_x = panel_x + 10;
        const armor_y = panel_y + 30;
        const armor_labels = [_][]const u8{ "Head", "Body", "Legs", "Feet" };

        text.drawText(renderer, &text.default_font, "Armor", armor_x, armor_y - 20, .{
            .color = Color.fromRgb(180, 180, 180),
        });

        for (0..inventory_mod.ARMOR_SIZE) |i| {
            const ay = armor_y + @as(i32, @intCast(i)) * (SLOT_SIZE + SLOT_PADDING);
            const stack = inv.armor[i];
            const is_hovered = self.isPointInRect(self.mouse_x, self.mouse_y, armor_x, ay, SLOT_SIZE, SLOT_SIZE);

            if (is_hovered) {
                self.hovered_slot = @intCast(i);
                self.hovered_type = .armor;
            }

            // Draw slot with armor icon background hint
            self.renderArmorSlot(renderer, armor_x, ay, stack, is_hovered, armor_labels[i]);
        }

        // Main inventory grid (4 rows x 9 columns, but row 0 is hotbar)
        // Position after armor section
        const inv_x = panel_x + armor_section_width + 10;
        const inv_y = panel_y + 100;

        // Upper inventory (3 rows)
        for (inventory_mod.HOTBAR_SIZE..inventory_mod.INVENTORY_SIZE) |i| {
            const row = (i - inventory_mod.HOTBAR_SIZE) / 9;
            const col = (i - inventory_mod.HOTBAR_SIZE) % 9;
            const sx = inv_x + @as(i32, @intCast(col)) * (SLOT_SIZE + SLOT_PADDING);
            const sy = inv_y + @as(i32, @intCast(row)) * (SLOT_SIZE + SLOT_PADDING);
            const stack = inv.slots[i];
            const is_hovered = self.isPointInRect(self.mouse_x, self.mouse_y, sx, sy, SLOT_SIZE, SLOT_SIZE);

            if (is_hovered) {
                self.hovered_slot = @intCast(i);
                self.hovered_type = .inventory;
            }

            self.renderSlot(renderer, sx, sy, stack, is_hovered, false);
        }

        // Hotbar (with separator)
        const hotbar_y = inv_y + 3 * (SLOT_SIZE + SLOT_PADDING) + 10;

        // Separator line
        self.drawFilledRect(renderer, inv_x, hotbar_y - 5, 9 * (SLOT_SIZE + SLOT_PADDING) - SLOT_PADDING, 2, Color.fromRgb(80, 80, 100));

        for (0..inventory_mod.HOTBAR_SIZE) |i| {
            const sx = inv_x + @as(i32, @intCast(i)) * (SLOT_SIZE + SLOT_PADDING);
            const stack = inv.slots[i];
            const is_selected = i == inv.selected_slot;
            const is_hovered = self.isPointInRect(self.mouse_x, self.mouse_y, sx, hotbar_y, SLOT_SIZE, SLOT_SIZE);

            if (is_hovered) {
                self.hovered_slot = @intCast(i);
                self.hovered_type = .hotbar;
            }

            self.renderSlot(renderer, sx, hotbar_y, stack, is_hovered, is_selected);
        }

        // Draw held item following cursor
        if (inv.held_item) |held| {
            self.renderItemStack(renderer, self.mouse_x - SLOT_SIZE / 2, self.mouse_y - SLOT_SIZE / 2, held);
        }

        // Draw tooltip for hovered item
        if (self.hovered_slot >= 0) {
            self.renderTooltip(renderer, inv);
        }

        // Instructions
        const help_y = panel_y + panel_height - 20;
        text.drawText(renderer, &text.default_font, "LClick: Pick/Place  RClick: Place 1  Shift+Click: Quick Move", inv_x, help_y, .{
            .color = Color.fromRgb(120, 120, 120),
        });
    }

    /// Render a single inventory slot
    fn renderSlot(
        self: *Self,
        renderer: *Renderer,
        x: i32,
        y: i32,
        stack: ?ItemStack,
        is_hovered: bool,
        is_selected: bool,
    ) void {
        // Slot background
        const bg_color = if (is_selected)
            SLOT_SELECTED
        else if (is_hovered)
            SLOT_HOVER
        else
            SLOT_BG;

        self.drawFilledRect(renderer, x, y, SLOT_SIZE, SLOT_SIZE, bg_color);

        // Selection border
        if (is_selected) {
            self.drawRectOutline(renderer, x, y, SLOT_SIZE, SLOT_SIZE, Color.WHITE);
        }

        // Item
        if (stack) |s| {
            self.renderItemStack(renderer, x, y, s);
        }
    }

    /// Armor slot background color (slightly different to indicate special slot)
    const ARMOR_SLOT_BG = Color.fromRgba(70, 50, 60, 200);
    const ARMOR_SLOT_HOVER = Color.fromRgba(90, 70, 90, 220);

    /// Render an armor slot with label hint
    fn renderArmorSlot(
        self: *Self,
        renderer: *Renderer,
        x: i32,
        y: i32,
        stack: ?ItemStack,
        is_hovered: bool,
        label: []const u8,
    ) void {
        // Slot background (darker/different color for armor slots)
        const bg_color = if (is_hovered) ARMOR_SLOT_HOVER else ARMOR_SLOT_BG;
        self.drawFilledRect(renderer, x, y, SLOT_SIZE, SLOT_SIZE, bg_color);

        // Draw armor slot type hint if empty
        if (stack == null) {
            // Draw a subtle icon/text hint for the armor type
            const hint_color = Color.fromRgba(100, 100, 100, 150);
            // Draw first letter of armor type as hint
            text.drawText(renderer, &text.default_font, label[0..1], x + SLOT_SIZE / 2 - 4, y + SLOT_SIZE / 2 - 6, .{
                .color = hint_color,
            });
        } else {
            self.renderItemStack(renderer, x, y, stack.?);
        }

        // Hover highlight border
        if (is_hovered) {
            self.drawRectOutline(renderer, x, y, SLOT_SIZE, SLOT_SIZE, Color.fromRgb(150, 100, 150));
        }
    }

    /// Render an item stack
    fn renderItemStack(
        self: *Self,
        renderer: *Renderer,
        x: i32,
        y: i32,
        stack: ItemStack,
    ) void {
        _ = self;
        const item = stack.getItem() orelse return;

        // Item icon (colored square based on item type)
        const icon_size = SLOT_SIZE - ICON_PADDING * 2;
        const ix = x + ICON_PADDING;
        const iy = y + ICON_PADDING;

        const color = getItemColor(item);
        drawFilledRectStatic(renderer, ix, iy, icon_size, icon_size, color);

        // Durability bar (for tools)
        if (stack.durability != null) {
            const dur_percent = stack.getDurabilityPercent();
            const bar_width: i32 = @intFromFloat(@as(f32, @floatFromInt(icon_size)) * dur_percent);
            const bar_y = y + SLOT_SIZE - 6;

            // Background
            drawFilledRectStatic(renderer, ix, bar_y, icon_size, 3, Color.fromRgb(40, 40, 40));

            // Fill (green to red)
            const r: u8 = @intFromFloat(255.0 * (1.0 - dur_percent));
            const g: u8 = @intFromFloat(255.0 * dur_percent);
            drawFilledRectStatic(renderer, ix, bar_y, bar_width, 3, Color.fromRgb(r, g, 0));
        }

        // Stack count (only if more than 1)
        if (stack.count > 1) {
            var buf: [4]u8 = undefined;
            const len = formatNumber(stack.count, &buf);
            text.drawText(renderer, &text.default_font, buf[0..len], x + SLOT_SIZE - 8 * @as(i32, @intCast(len)), y + SLOT_SIZE - 12, .{
                .color = COUNT_COLOR,
            });
        }
    }

    /// Render tooltip for hovered item
    fn renderTooltip(self: *Self, renderer: *Renderer, inv: *const Inventory) void {
        const stack: ?ItemStack = switch (self.hovered_type) {
            .inventory, .hotbar => if (self.hovered_slot >= 0 and self.hovered_slot < inventory_mod.INVENTORY_SIZE)
                inv.slots[@intCast(self.hovered_slot)]
            else
                null,
            .crafting => if (self.hovered_slot >= 0 and self.hovered_slot < 4)
                inv.crafting[@intCast(self.hovered_slot)]
            else
                null,
            .crafting_result => inv.crafting_result,
            .armor => if (self.hovered_slot >= 0 and self.hovered_slot < inventory_mod.ARMOR_SIZE)
                inv.armor[@intCast(self.hovered_slot)]
            else
                null,
        };

        const s = stack orelse return;
        const item = s.getItem() orelse return;

        // Calculate tooltip dimensions based on content
        var lines: [8]TooltipLine = undefined;
        var line_count: usize = 0;

        // Line 1: Item name
        lines[line_count] = .{ .text = item.name, .color = getItemRarityColor(item) };
        line_count += 1;

        // Line 2: Item type
        const type_text = switch (item.item_type) {
            .tool => "Tool",
            .weapon => "Weapon",
            .armor => "Armor",
            .food => "Food",
            .material => "Material",
            .block => "Block",
            .special => "Special",
        };
        lines[line_count] = .{ .text = type_text, .color = Color.fromRgb(128, 128, 128) };
        line_count += 1;

        // Stat lines based on item type (use separate buffers)
        if (item.damage > 1.0) {
            lines[line_count] = .{
                .text = formatStat("Damage: ", item.damage, &self.tooltip_buf),
                .color = Color.fromRgb(255, 100, 100),
            };
            line_count += 1;
        }

        if (item.armor_points > 0) {
            lines[line_count] = .{
                .text = formatStat("Armor: +", item.armor_points, &self.tooltip_buf2),
                .color = Color.fromRgb(100, 150, 255),
            };
            line_count += 1;
        }

        // Show mining speed for tools
        if (item.tool_material != null) {
            const speed = item.tool_material.?.getSpeedMultiplier();
            if (speed > 1.0) {
                lines[line_count] = .{
                    .text = formatStat("Mining Speed: x", speed, &self.tooltip_buf3),
                    .color = Color.fromRgb(255, 200, 100),
                };
                line_count += 1;
            }
        }

        if (item.hunger_restore > 0) {
            lines[line_count] = .{
                .text = formatStat("Hunger: +", item.hunger_restore, &self.tooltip_buf4),
                .color = Color.fromRgb(180, 120, 80),
            };
            line_count += 1;
        }

        // Durability line
        if (s.durability != null) {
            const dur = s.durability.?;
            const max_dur = if (item.durability) |d| d else dur;
            lines[line_count] = .{
                .text = formatDurability(dur, max_dur, &self.tooltip_buf5),
                .color = getDurabilityColor(s.getDurabilityPercent()),
            };
            line_count += 1;
        }

        // Calculate dimensions
        var max_width: i32 = 0;
        for (0..line_count) |i| {
            const w: i32 = @as(i32, @intCast(lines[i].text.len)) * 8;
            if (w > max_width) max_width = w;
        }

        const tooltip_x = self.mouse_x + 15;
        const tooltip_y = self.mouse_y + 15;
        const tooltip_w = max_width + 16;
        const tooltip_h: i32 = @as(i32, @intCast(line_count)) * 14 + 10;

        // Draw tooltip box
        self.drawFilledRect(renderer, tooltip_x, tooltip_y, tooltip_w, tooltip_h, Color.fromRgba(20, 20, 30, 240));
        self.drawRectOutline(renderer, tooltip_x, tooltip_y, tooltip_w, tooltip_h, Color.fromRgb(100, 100, 120));

        // Draw lines
        for (0..line_count) |i| {
            text.drawText(renderer, &text.default_font, lines[i].text, tooltip_x + 8, tooltip_y + 5 + @as(i32, @intCast(i)) * 14, .{
                .color = lines[i].color,
            });
        }
    }

    /// Tooltip line data
    const TooltipLine = struct {
        text: []const u8,
        color: Color,
    };

    /// Check if a point is inside a rectangle
    fn isPointInRect(self: *Self, px: i32, py: i32, rx: i32, ry: i32, rw: i32, rh: i32) bool {
        _ = self;
        return px >= rx and px < rx + rw and py >= ry and py < ry + rh;
    }

    /// Draw a filled rectangle
    fn drawFilledRect(self: *Self, renderer: *Renderer, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        _ = self;
        drawFilledRectStatic(renderer, x, y, w, h, color);
    }

    /// Draw a rectangle outline
    fn drawRectOutline(self: *Self, renderer: *Renderer, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        _ = self;
        // Top and bottom
        var px = x;
        while (px < x + w) : (px += 1) {
            renderer.drawPixel(px, y, 0, color);
            renderer.drawPixel(px, y + h - 1, 0, color);
        }
        // Left and right
        var py = y;
        while (py < y + h) : (py += 1) {
            renderer.drawPixel(x, py, 0, color);
            renderer.drawPixel(x + w - 1, py, 0, color);
        }
    }
};

/// Get color for an item based on type
fn getItemColor(item: *const items_mod.Item) Color {
    // For block items, use block color
    if (item.block_type) |block| {
        const c = block.getColor();
        return Color{ .r = c[0], .g = c[1], .b = c[2], .a = c[3] };
    }

    // For other items, use type-based colors
    return switch (item.item_type) {
        .tool => Color.fromRgb(160, 120, 80),
        .weapon => Color.fromRgb(180, 80, 80),
        .armor => Color.fromRgb(100, 100, 140),
        .food => Color.fromRgb(200, 150, 100),
        .material => Color.fromRgb(140, 140, 100),
        .special => Color.fromRgb(200, 180, 255),
        .block => Color.fromRgb(100, 100, 100),
    };
}

/// Get rarity color for tooltip
fn getItemRarityColor(item: *const items_mod.Item) Color {
    // Basic rarity based on item type
    return switch (item.item_type) {
        .special => Color.fromRgb(255, 200, 255), // Purple
        .tool, .weapon, .armor => if (item.tool_material) |mat| switch (mat) {
            .diamond => Color.fromRgb(100, 255, 255), // Cyan
            .gold => Color.fromRgb(255, 215, 0), // Gold
            .iron => Color.WHITE,
            else => Color.WHITE,
        } else Color.WHITE,
        else => Color.WHITE,
    };
}

/// Format a number to string
fn formatNumber(n: u32, buf: []u8) usize {
    if (n >= 100) {
        buf[0] = '0' + @as(u8, @intCast((n / 100) % 10));
        buf[1] = '0' + @as(u8, @intCast((n / 10) % 10));
        buf[2] = '0' + @as(u8, @intCast(n % 10));
        return 3;
    } else if (n >= 10) {
        buf[0] = '0' + @as(u8, @intCast((n / 10) % 10));
        buf[1] = '0' + @as(u8, @intCast(n % 10));
        return 2;
    } else {
        buf[0] = '0' + @as(u8, @intCast(n % 10));
        return 1;
    }
}

/// Static helper for drawing filled rect
fn drawFilledRectStatic(renderer: *Renderer, x: i32, y: i32, w: i32, h: i32, color: Color) void {
    var py = y;
    while (py < y + h) : (py += 1) {
        var px = x;
        while (px < x + w) : (px += 1) {
            renderer.drawPixel(px, py, 0, color);
        }
    }
}

/// Format a stat value for tooltip display (float)
fn formatStat(prefix: []const u8, value: f32, buf: []u8) []const u8 {
    // Copy prefix
    var i: usize = 0;
    for (prefix) |c| {
        if (i >= buf.len) break;
        buf[i] = c;
        i += 1;
    }

    // Format the float value (simple int + decimal)
    const int_part: u32 = @intFromFloat(value);
    const frac_part: u32 = @intFromFloat((value - @as(f32, @floatFromInt(int_part))) * 10);

    // Integer part
    if (int_part >= 100) {
        if (i < buf.len) buf[i] = '0' + @as(u8, @intCast((int_part / 100) % 10));
        i += 1;
    }
    if (int_part >= 10) {
        if (i < buf.len) buf[i] = '0' + @as(u8, @intCast((int_part / 10) % 10));
        i += 1;
    }
    if (i < buf.len) buf[i] = '0' + @as(u8, @intCast(int_part % 10));
    i += 1;

    // Decimal part if non-zero
    if (frac_part > 0) {
        if (i < buf.len) buf[i] = '.';
        i += 1;
        if (i < buf.len) buf[i] = '0' + @as(u8, @intCast(frac_part));
        i += 1;
    }

    return buf[0..i];
}

/// Format a stat value for tooltip display (integer)
fn formatStatInt(prefix: []const u8, value: u8, buf: []u8) []const u8 {
    var i: usize = 0;
    for (prefix) |c| {
        if (i >= buf.len) break;
        buf[i] = c;
        i += 1;
    }

    if (value >= 100) {
        if (i < buf.len) buf[i] = '0' + @as(u8, @intCast((value / 100) % 10));
        i += 1;
    }
    if (value >= 10) {
        if (i < buf.len) buf[i] = '0' + @as(u8, @intCast((value / 10) % 10));
        i += 1;
    }
    if (i < buf.len) buf[i] = '0' + @as(u8, @intCast(value % 10));
    i += 1;

    return buf[0..i];
}

/// Format durability for tooltip
fn formatDurability(current: u32, max: u32, buf: []u8) []const u8 {
    const prefix = "Durability: ";
    var i: usize = 0;

    for (prefix) |c| {
        if (i >= buf.len) break;
        buf[i] = c;
        i += 1;
    }

    // Current value
    i = writeNumber(current, buf, i);

    // Separator
    if (i < buf.len) buf[i] = '/';
    i += 1;

    // Max value
    i = writeNumber(max, buf, i);

    return buf[0..i];
}

/// Write a number to buffer, return new index
fn writeNumber(n: u32, buf: []u8, start: usize) usize {
    var i = start;
    if (n >= 1000) {
        if (i < buf.len) buf[i] = '0' + @as(u8, @intCast((n / 1000) % 10));
        i += 1;
    }
    if (n >= 100) {
        if (i < buf.len) buf[i] = '0' + @as(u8, @intCast((n / 100) % 10));
        i += 1;
    }
    if (n >= 10) {
        if (i < buf.len) buf[i] = '0' + @as(u8, @intCast((n / 10) % 10));
        i += 1;
    }
    if (i < buf.len) buf[i] = '0' + @as(u8, @intCast(n % 10));
    i += 1;
    return i;
}

/// Get color based on durability percentage
fn getDurabilityColor(percent: f32) Color {
    if (percent > 0.5) {
        return Color.fromRgb(100, 255, 100); // Green
    } else if (percent > 0.25) {
        return Color.fromRgb(255, 255, 100); // Yellow
    } else {
        return Color.fromRgb(255, 100, 100); // Red
    }
}

// ============================================================================
// Tests
// ============================================================================

test "inventory ui initialization" {
    var ui = InventoryUI{};
    try std.testing.expect(!ui.is_open);
    try std.testing.expectEqual(@as(i32, -1), ui.hovered_slot);
}

test "inventory ui toggle" {
    var ui = InventoryUI{};
    ui.toggle();
    try std.testing.expect(ui.is_open);
    ui.toggle();
    try std.testing.expect(!ui.is_open);
}

test "number formatting" {
    var buf: [4]u8 = undefined;

    try std.testing.expectEqual(@as(usize, 1), formatNumber(5, &buf));
    try std.testing.expectEqual(@as(u8, '5'), buf[0]);

    try std.testing.expectEqual(@as(usize, 2), formatNumber(42, &buf));
    try std.testing.expectEqual(@as(u8, '4'), buf[0]);
    try std.testing.expectEqual(@as(u8, '2'), buf[1]);

    try std.testing.expectEqual(@as(usize, 3), formatNumber(128, &buf));
}
