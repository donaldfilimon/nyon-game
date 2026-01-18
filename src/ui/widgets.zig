//! UI Widgets
//!
//! Advanced UI widgets for the Nyon Game Engine immediate mode UI system.
//! Provides interactive controls including text input, draggable panels,
//! scrollable lists, and expandable tree views.

const std = @import("std");
const ui = @import("ui.zig");
const render = @import("../render/render.zig");
const text_module = @import("text.zig");

// =============================================================================
// TextInput - Editable text field with cursor and input handling
// =============================================================================

/// Text input widget state
pub const TextInput = struct {
    const Self = @This();

    buffer: [256]u8 = undefined,
    len: usize = 0,
    cursor: usize = 0,
    focused: bool = false,
    cursor_blink_timer: f32 = 0,
    cursor_visible: bool = true,

    /// Blink interval in seconds
    pub const BLINK_INTERVAL: f32 = 0.5;

    pub fn getText(self: *const Self) []const u8 {
        return self.buffer[0..self.len];
    }

    pub fn setText(self: *Self, new_text: []const u8) void {
        if (new_text.len > self.buffer.len) {
            std.log.warn("TextInput truncated: '{s}' exceeds buffer size {}", .{ new_text, self.buffer.len });
        }
        const copy_len = @min(new_text.len, self.buffer.len);
        @memcpy(self.buffer[0..copy_len], new_text[0..copy_len]);
        self.len = copy_len;
        self.cursor = copy_len;
    }

    /// Clear all text from the input
    pub fn clear(self: *Self) void {
        self.len = 0;
        self.cursor = 0;
    }

    /// Update cursor blink animation
    pub fn updateBlink(self: *Self, delta_time: f32) void {
        if (!self.focused) {
            self.cursor_visible = false;
            self.cursor_blink_timer = 0;
            return;
        }
        self.cursor_blink_timer += delta_time;
        if (self.cursor_blink_timer >= BLINK_INTERVAL) {
            self.cursor_blink_timer -= BLINK_INTERVAL;
            self.cursor_visible = !self.cursor_visible;
        }
    }

    /// Reset cursor blink (call after any input to show cursor immediately)
    pub fn resetBlink(self: *Self) void {
        self.cursor_blink_timer = 0;
        self.cursor_visible = true;
    }

    /// Handle character input (A-Z, a-z, 0-9, space, common punctuation)
    /// Returns true if the character was accepted
    pub fn handleCharInput(self: *Self, char: u8) bool {
        // Accept printable ASCII characters (space through tilde)
        if (char < 0x20 or char > 0x7E) return false;
        if (self.len >= self.buffer.len) return false;

        // Insert at cursor position
        if (self.cursor < self.len) {
            // Shift characters right to make room
            var i = self.len;
            while (i > self.cursor) : (i -= 1) {
                self.buffer[i] = self.buffer[i - 1];
            }
        }
        self.buffer[self.cursor] = char;
        self.cursor += 1;
        self.len += 1;
        self.resetBlink();
        return true;
    }

    /// Handle backspace key - delete character before cursor
    /// Returns true if a character was deleted
    pub fn handleBackspace(self: *Self) bool {
        if (self.cursor == 0 or self.len == 0) return false;

        // Shift characters left
        var i = self.cursor - 1;
        while (i < self.len - 1) : (i += 1) {
            self.buffer[i] = self.buffer[i + 1];
        }
        self.cursor -= 1;
        self.len -= 1;
        self.resetBlink();
        return true;
    }

    /// Handle delete key - delete character at cursor
    /// Returns true if a character was deleted
    pub fn handleDelete(self: *Self) bool {
        if (self.cursor >= self.len) return false;

        // Shift characters left
        var i = self.cursor;
        while (i < self.len - 1) : (i += 1) {
            self.buffer[i] = self.buffer[i + 1];
        }
        self.len -= 1;
        self.resetBlink();
        return true;
    }

    /// Move cursor left
    pub fn moveCursorLeft(self: *Self) void {
        if (self.cursor > 0) {
            self.cursor -= 1;
            self.resetBlink();
        }
    }

    /// Move cursor right
    pub fn moveCursorRight(self: *Self) void {
        if (self.cursor < self.len) {
            self.cursor += 1;
            self.resetBlink();
        }
    }

    /// Move cursor to beginning
    pub fn moveCursorHome(self: *Self) void {
        self.cursor = 0;
        self.resetBlink();
    }

    /// Move cursor to end
    pub fn moveCursorEnd(self: *Self) void {
        self.cursor = self.len;
        self.resetBlink();
    }

    /// Calculate cursor X position in pixels for rendering
    pub fn getCursorPixelX(self: *const Self, font: *const text_module.Font, scale: u8) i32 {
        var x: i32 = 0;
        const text_before_cursor = self.buffer[0..self.cursor];
        for (text_before_cursor) |char| {
            const glyph = font.getGlyph(char);
            x += @as(i32, glyph.advance) * @as(i32, scale);
        }
        return x;
    }
};

// =============================================================================
// Panel - Draggable and resizable container for grouping widgets
// =============================================================================

/// Panel drag/resize state
pub const PanelDragState = struct {
    is_dragging: bool = false,
    is_resizing: bool = false,
    resize_edge: ResizeEdge = .none,
    drag_offset_x: i32 = 0,
    drag_offset_y: i32 = 0,

    pub const ResizeEdge = enum {
        none,
        right,
        bottom,
        bottom_right,
    };
};

/// Panel for grouping widgets
pub const Panel = struct {
    const Self = @This();

    x: i32,
    y: i32,
    width: i32,
    height: i32,
    title: []const u8,
    collapsed: bool,
    draggable: bool,
    resizable: bool,

    /// Title bar height in pixels
    pub const TITLE_BAR_HEIGHT: i32 = 24;
    /// Resize handle size in pixels
    pub const RESIZE_HANDLE_SIZE: i32 = 8;
    /// Minimum panel dimensions
    pub const MIN_WIDTH: i32 = 100;
    pub const MIN_HEIGHT: i32 = 50;

    pub fn init(x: i32, y: i32, w: i32, h: i32, title: []const u8) Panel {
        return .{
            .x = x,
            .y = y,
            .width = w,
            .height = h,
            .title = title,
            .collapsed = false,
            .draggable = true,
            .resizable = true,
        };
    }

    /// Get the title bar bounding rectangle
    pub fn getTitleBarRect(self: *const Self) struct { x: i32, y: i32, w: i32, h: i32 } {
        return .{
            .x = self.x,
            .y = self.y,
            .w = self.width,
            .h = TITLE_BAR_HEIGHT,
        };
    }

    /// Get the content area rectangle (excluding title bar)
    pub fn getContentRect(self: *const Self) struct { x: i32, y: i32, w: i32, h: i32 } {
        if (self.collapsed) {
            return .{ .x = self.x, .y = self.y + TITLE_BAR_HEIGHT, .w = self.width, .h = 0 };
        }
        return .{
            .x = self.x,
            .y = self.y + TITLE_BAR_HEIGHT,
            .w = self.width,
            .h = self.height - TITLE_BAR_HEIGHT,
        };
    }

    /// Check if a point is within the title bar (for dragging)
    pub fn isInTitleBar(self: *const Self, px: i32, py: i32) bool {
        const rect = self.getTitleBarRect();
        return px >= rect.x and px < rect.x + rect.w and
            py >= rect.y and py < rect.y + rect.h;
    }

    /// Check if a point is within a resize handle
    pub fn getResizeEdge(self: *const Self, px: i32, py: i32) PanelDragState.ResizeEdge {
        if (!self.resizable or self.collapsed) return .none;

        const right_edge = px >= self.x + self.width - RESIZE_HANDLE_SIZE and px < self.x + self.width;
        const bottom_edge = py >= self.y + self.height - RESIZE_HANDLE_SIZE and py < self.y + self.height;

        if (right_edge and bottom_edge) return .bottom_right;
        if (right_edge) return .right;
        if (bottom_edge) return .bottom;
        return .none;
    }

    /// Begin dragging the panel
    pub fn beginDrag(self: *const Self, mouse_x: i32, mouse_y: i32, state: *PanelDragState) void {
        state.is_dragging = true;
        state.drag_offset_x = mouse_x - self.x;
        state.drag_offset_y = mouse_y - self.y;
    }

    /// Begin resizing the panel
    pub fn beginResize(self: *const Self, mouse_x: i32, mouse_y: i32, edge: PanelDragState.ResizeEdge, state: *PanelDragState) void {
        state.is_resizing = true;
        state.resize_edge = edge;
        state.drag_offset_x = mouse_x;
        state.drag_offset_y = mouse_y;
        _ = self;
    }

    /// Update panel position while dragging
    pub fn updateDrag(self: *Self, mouse_x: i32, mouse_y: i32, state: *const PanelDragState) void {
        if (!state.is_dragging) return;
        self.x = mouse_x - state.drag_offset_x;
        self.y = mouse_y - state.drag_offset_y;
    }

    /// Update panel size while resizing
    pub fn updateResize(self: *Self, mouse_x: i32, mouse_y: i32, state: *PanelDragState) void {
        if (!state.is_resizing) return;

        switch (state.resize_edge) {
            .right => {
                self.width = @max(MIN_WIDTH, mouse_x - self.x);
            },
            .bottom => {
                self.height = @max(MIN_HEIGHT, mouse_y - self.y);
            },
            .bottom_right => {
                self.width = @max(MIN_WIDTH, mouse_x - self.x);
                self.height = @max(MIN_HEIGHT, mouse_y - self.y);
            },
            .none => {},
        }
    }

    /// End drag or resize operation
    pub fn endDragResize(state: *PanelDragState) void {
        state.is_dragging = false;
        state.is_resizing = false;
        state.resize_edge = .none;
    }

    /// Toggle collapsed state
    pub fn toggleCollapse(self: *Self) void {
        self.collapsed = !self.collapsed;
    }

    /// Get the full panel height (respects collapsed state)
    pub fn getEffectiveHeight(self: *const Self) i32 {
        if (self.collapsed) return TITLE_BAR_HEIGHT;
        return self.height;
    }
};

// =============================================================================
// ScrollList - Scrollable list with item selection
// =============================================================================

/// Scrollable list
pub const ScrollList = struct {
    const Self = @This();

    scroll_offset: f32 = 0,
    item_height: i32 = 24,
    selected_index: ?usize = null,
    max_scroll: f32 = 0,

    /// Mouse wheel scroll speed multiplier
    pub const SCROLL_SPEED: f32 = 3.0;

    /// Initialize scroll list with item height
    pub fn init(item_height: i32) Self {
        return .{
            .scroll_offset = 0,
            .item_height = item_height,
            .selected_index = null,
            .max_scroll = 0,
        };
    }

    /// Update max scroll based on content and view height
    pub fn updateMaxScroll(self: *Self, item_count: usize, view_height: i32) void {
        const content_height: f32 = @floatFromInt(@as(i32, @intCast(item_count)) * self.item_height);
        const view_h: f32 = @floatFromInt(view_height);
        self.max_scroll = @max(0, content_height - view_h);
    }

    /// Handle mouse wheel scrolling
    /// wheel_delta: positive = scroll up, negative = scroll down
    pub fn handleMouseWheel(self: *Self, wheel_delta: f32) void {
        self.scroll_offset -= wheel_delta * @as(f32, @floatFromInt(self.item_height)) * SCROLL_SPEED;
        self.clampScroll();
    }

    /// Clamp scroll offset to valid range
    pub fn clampScroll(self: *Self) void {
        self.scroll_offset = std.math.clamp(self.scroll_offset, 0, self.max_scroll);
    }

    /// Scroll to ensure an item is visible
    pub fn scrollToItem(self: *Self, index: usize, view_height: i32) void {
        const item_top: f32 = @floatFromInt(@as(i32, @intCast(index)) * self.item_height);
        const item_bottom = item_top + @as(f32, @floatFromInt(self.item_height));
        const view_h: f32 = @floatFromInt(view_height);

        if (item_top < self.scroll_offset) {
            self.scroll_offset = item_top;
        } else if (item_bottom > self.scroll_offset + view_h) {
            self.scroll_offset = item_bottom - view_h;
        }
        self.clampScroll();
    }

    /// Get the index of the first visible item
    pub fn getFirstVisibleIndex(self: *const Self) usize {
        const idx: i32 = @intFromFloat(self.scroll_offset / @as(f32, @floatFromInt(self.item_height)));
        return @intCast(@max(0, idx));
    }

    /// Get the number of visible items (ceiling)
    pub fn getVisibleItemCount(self: *const Self, view_height: i32) usize {
        const count = @divFloor(view_height, self.item_height) + 2; // +2 for partial items
        return @intCast(@max(0, count));
    }

    /// Check if an item at given index is visible
    pub fn isItemVisible(self: *const Self, index: usize, view_height: i32) bool {
        const item_top: f32 = @floatFromInt(@as(i32, @intCast(index)) * self.item_height);
        const item_bottom = item_top + @as(f32, @floatFromInt(self.item_height));
        const view_h: f32 = @floatFromInt(view_height);

        return item_bottom > self.scroll_offset and item_top < self.scroll_offset + view_h;
    }

    /// Get the Y offset for rendering an item (relative to list top)
    pub fn getItemRenderY(self: *const Self, index: usize) i32 {
        const base_y: i32 = @as(i32, @intCast(index)) * self.item_height;
        return base_y - @as(i32, @intFromFloat(self.scroll_offset));
    }

    /// Handle item click - returns the clicked item index or null
    pub fn handleClick(self: *Self, click_y: i32, item_count: usize) ?usize {
        const adjusted_y = click_y + @as(i32, @intFromFloat(self.scroll_offset));
        if (adjusted_y < 0) return null;

        const index: usize = @intCast(@divFloor(adjusted_y, self.item_height));
        if (index < item_count) {
            self.selected_index = index;
            return index;
        }
        return null;
    }

    /// Select next item
    pub fn selectNext(self: *Self, item_count: usize, view_height: i32) void {
        if (item_count == 0) return;
        if (self.selected_index) |idx| {
            if (idx + 1 < item_count) {
                self.selected_index = idx + 1;
                self.scrollToItem(idx + 1, view_height);
            }
        } else {
            self.selected_index = 0;
            self.scrollToItem(0, view_height);
        }
    }

    /// Select previous item
    pub fn selectPrevious(self: *Self, view_height: i32) void {
        if (self.selected_index) |idx| {
            if (idx > 0) {
                self.selected_index = idx - 1;
                self.scrollToItem(idx - 1, view_height);
            }
        }
    }
};

// =============================================================================
// TreeNode - Expandable tree view node with indentation
// =============================================================================

/// Tree view node (simplified - no ArrayList)
pub const TreeNode = struct {
    const Self = @This();

    label: []const u8,
    expanded: bool = false,
    depth: u8 = 0,
    has_children: bool = false,
    user_data: ?*anyopaque = null,

    /// Indentation per depth level in pixels
    pub const INDENT_WIDTH: i32 = 20;
    /// Expand/collapse indicator size
    pub const INDICATOR_SIZE: i32 = 12;

    /// Initialize a tree node
    pub fn init(label: []const u8) Self {
        return .{
            .label = label,
            .expanded = false,
            .depth = 0,
            .has_children = false,
            .user_data = null,
        };
    }

    /// Initialize a tree node with depth
    pub fn initWithDepth(label: []const u8, depth: u8, has_children: bool) Self {
        return .{
            .label = label,
            .expanded = false,
            .depth = depth,
            .has_children = has_children,
            .user_data = null,
        };
    }

    /// Toggle expanded state (only if node has children)
    pub fn toggle(self: *Self) void {
        if (self.has_children) {
            self.expanded = !self.expanded;
        }
    }

    /// Set expanded state
    pub fn setExpanded(self: *Self, exp: bool) void {
        self.expanded = exp and self.has_children;
    }

    /// Get the X offset for this node's content (based on depth)
    pub fn getIndentX(self: *const Self) i32 {
        return @as(i32, self.depth) * INDENT_WIDTH;
    }

    /// Get the expand/collapse indicator character
    pub fn getIndicator(self: *const Self) u8 {
        if (!self.has_children) return ' ';
        return if (self.expanded) '-' else '+';
    }

    /// Check if a click is on the expand/collapse indicator
    pub fn isClickOnIndicator(self: *const Self, click_x: i32, node_x: i32) bool {
        if (!self.has_children) return false;
        const indicator_x = node_x + self.getIndentX();
        return click_x >= indicator_x and click_x < indicator_x + INDICATOR_SIZE;
    }

    /// Handle click on node - returns true if expanded state changed
    pub fn handleClick(self: *Self, click_x: i32, node_x: i32) bool {
        if (self.isClickOnIndicator(click_x, node_x)) {
            self.toggle();
            return true;
        }
        return false;
    }
};

// =============================================================================
// TreeView - Helper for managing a flat list of tree nodes
// =============================================================================

/// Helper struct for iterating visible tree nodes
pub const TreeViewIterator = struct {
    nodes: []TreeNode,
    index: usize = 0,
    skip_depth: ?u8 = null,

    pub fn next(self: *TreeViewIterator) ?*TreeNode {
        while (self.index < self.nodes.len) {
            const node = &self.nodes[self.index];
            self.index += 1;

            // Skip nodes that are children of collapsed parents
            if (self.skip_depth) |sd| {
                if (node.depth > sd) continue;
                self.skip_depth = null;
            }

            // If this node has children but is collapsed, skip its children
            if (node.has_children and !node.expanded) {
                self.skip_depth = node.depth;
            }

            return node;
        }
        return null;
    }

    /// Reset iterator to beginning
    pub fn reset(self: *TreeViewIterator) void {
        self.index = 0;
        self.skip_depth = null;
    }
};

/// Create an iterator over visible tree nodes
pub fn iterateVisibleNodes(nodes: []TreeNode) TreeViewIterator {
    return .{ .nodes = nodes };
}

// =============================================================================
// Dropdown - Select menu with options
// =============================================================================

/// Dropdown/select menu state
pub const Dropdown = struct {
    const Self = @This();

    selected_index: usize = 0,
    is_open: bool = false,
    scroll_offset: f32 = 0,
    max_visible_items: usize = 6,

    pub fn init() Self {
        return .{};
    }

    /// Get the currently selected index
    pub fn getSelected(self: *const Self) usize {
        return self.selected_index;
    }

    /// Set the selected index
    pub fn setSelected(self: *Self, index: usize) void {
        self.selected_index = index;
    }

    /// Toggle open/closed state
    pub fn toggle(self: *Self) void {
        self.is_open = !self.is_open;
        if (self.is_open) {
            self.scroll_offset = 0;
        }
    }

    /// Close the dropdown
    pub fn close(self: *Self) void {
        self.is_open = false;
    }

    /// Open the dropdown
    pub fn open(self: *Self) void {
        self.is_open = true;
        self.scroll_offset = 0;
    }

    /// Handle item selection, returns true if selection changed
    pub fn selectItem(self: *Self, index: usize, item_count: usize) bool {
        if (index >= item_count) return false;
        if (self.selected_index == index) {
            self.close();
            return false;
        }
        self.selected_index = index;
        self.close();
        return true;
    }

    /// Calculate dropdown height based on item count
    pub fn getDropdownHeight(self: *const Self, item_count: usize, item_height: i32) i32 {
        const visible_count = @min(item_count, self.max_visible_items);
        return @as(i32, @intCast(visible_count)) * item_height;
    }
};

// =============================================================================
// TabBar - Tab navigation
// =============================================================================

/// Tab bar state
pub const TabBar = struct {
    const Self = @This();

    active_index: usize = 0,
    tab_count: usize = 0,

    pub fn init(tab_count: usize) Self {
        return .{
            .active_index = 0,
            .tab_count = tab_count,
        };
    }

    /// Get the active tab index
    pub fn getActive(self: *const Self) usize {
        return self.active_index;
    }

    /// Set the active tab
    pub fn setActive(self: *Self, index: usize) void {
        if (index < self.tab_count) {
            self.active_index = index;
        }
    }

    /// Move to next tab
    pub fn nextTab(self: *Self) void {
        if (self.tab_count == 0) return;
        self.active_index = (self.active_index + 1) % self.tab_count;
    }

    /// Move to previous tab
    pub fn prevTab(self: *Self) void {
        if (self.tab_count == 0) return;
        if (self.active_index == 0) {
            self.active_index = self.tab_count - 1;
        } else {
            self.active_index -= 1;
        }
    }

    /// Check if a tab is active
    pub fn isActive(self: *const Self, index: usize) bool {
        return self.active_index == index;
    }
};

// =============================================================================
// Modal - Dialog overlay
// =============================================================================

/// Modal dialog state
pub const Modal = struct {
    const Self = @This();

    is_visible: bool = false,
    x: i32 = 0,
    y: i32 = 0,
    width: i32 = 300,
    height: i32 = 200,
    title: []const u8 = "",

    /// Default modal dimensions
    pub const DEFAULT_WIDTH: i32 = 300;
    pub const DEFAULT_HEIGHT: i32 = 200;

    pub fn init(title: []const u8, width: i32, height: i32) Self {
        return .{
            .is_visible = false,
            .x = 0,
            .y = 0,
            .width = width,
            .height = height,
            .title = title,
        };
    }

    /// Show the modal, centered on screen
    pub fn show(self: *Self, screen_width: i32, screen_height: i32) void {
        self.is_visible = true;
        self.x = @divFloor(screen_width - self.width, 2);
        self.y = @divFloor(screen_height - self.height, 2);
    }

    /// Hide the modal
    pub fn hide(self: *Self) void {
        self.is_visible = false;
    }

    /// Toggle visibility
    pub fn toggle(self: *Self, screen_width: i32, screen_height: i32) void {
        if (self.is_visible) {
            self.hide();
        } else {
            self.show(screen_width, screen_height);
        }
    }

    /// Check if a point is inside the modal
    pub fn contains(self: *const Self, px: i32, py: i32) bool {
        return px >= self.x and px < self.x + self.width and
            py >= self.y and py < self.y + self.height;
    }

    /// Get content area (excluding title bar)
    pub fn getContentRect(self: *const Self, title_bar_height: i32) struct { x: i32, y: i32, w: i32, h: i32 } {
        return .{
            .x = self.x,
            .y = self.y + title_bar_height,
            .w = self.width,
            .h = self.height - title_bar_height,
        };
    }
};

// =============================================================================
// Toast - Notification messages
// =============================================================================

/// Toast notification type
pub const ToastType = enum {
    info,
    success,
    warning,
    err,
};

/// Single toast notification
pub const Toast = struct {
    const Self = @This();

    message: [128]u8 = undefined,
    message_len: usize = 0,
    toast_type: ToastType = .info,
    duration: f32 = 3.0,
    elapsed: f32 = 0,
    is_active: bool = false,

    /// Default toast duration in seconds
    pub const DEFAULT_DURATION: f32 = 3.0;

    pub fn init() Self {
        return .{};
    }

    /// Show a toast message
    pub fn show(self: *Self, message: []const u8, toast_type: ToastType, duration: f32) void {
        const copy_len = @min(message.len, self.message.len);
        @memcpy(self.message[0..copy_len], message[0..copy_len]);
        self.message_len = copy_len;
        self.toast_type = toast_type;
        self.duration = duration;
        self.elapsed = 0;
        self.is_active = true;
    }

    /// Update toast timer, returns true if toast is still visible
    pub fn update(self: *Self, delta_time: f32) bool {
        if (!self.is_active) return false;

        self.elapsed += delta_time;
        if (self.elapsed >= self.duration) {
            self.is_active = false;
            return false;
        }
        return true;
    }

    /// Get remaining time ratio (1.0 = just shown, 0.0 = about to hide)
    pub fn getRemainingRatio(self: *const Self) f32 {
        if (!self.is_active or self.duration == 0) return 0;
        return 1.0 - (self.elapsed / self.duration);
    }

    /// Get the message text
    pub fn getMessage(self: *const Self) []const u8 {
        return self.message[0..self.message_len];
    }

    /// Dismiss the toast early
    pub fn dismiss(self: *Self) void {
        self.is_active = false;
    }
};

/// Toast manager for multiple toasts
pub const ToastManager = struct {
    const Self = @This();
    const MAX_TOASTS = 5;

    toasts: [MAX_TOASTS]Toast = undefined,
    count: usize = 0,

    pub fn init() Self {
        var manager = Self{};
        for (&manager.toasts) |*t| {
            t.* = Toast.init();
        }
        return manager;
    }

    /// Push a new toast
    pub fn push(self: *Self, message: []const u8, toast_type: ToastType, duration: f32) void {
        // Find an inactive slot or use the oldest
        var slot: usize = 0;
        var oldest_elapsed: f32 = -1;
        for (self.toasts, 0..) |t, i| {
            if (!t.is_active) {
                slot = i;
                break;
            }
            if (t.elapsed > oldest_elapsed) {
                oldest_elapsed = t.elapsed;
                slot = i;
            }
        }

        self.toasts[slot].show(message, toast_type, duration);
        self.count = @min(self.count + 1, MAX_TOASTS);
    }

    /// Update all toasts
    pub fn update(self: *Self, delta_time: f32) void {
        for (&self.toasts) |*t| {
            _ = t.update(delta_time);
        }
    }

    /// Get active toast count
    pub fn activeCount(self: *const Self) usize {
        var count: usize = 0;
        for (self.toasts) |t| {
            if (t.is_active) count += 1;
        }
        return count;
    }

    /// Dismiss all toasts
    pub fn dismissAll(self: *Self) void {
        for (&self.toasts) |*t| {
            t.dismiss();
        }
        self.count = 0;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "TextInput basic operations" {
    var input = TextInput{};

    // Test setText
    input.setText("Hello");
    try std.testing.expectEqualStrings("Hello", input.getText());
    try std.testing.expectEqual(@as(usize, 5), input.cursor);

    // Test handleCharInput
    _ = input.handleCharInput(' ');
    _ = input.handleCharInput('W');
    _ = input.handleCharInput('o');
    _ = input.handleCharInput('r');
    _ = input.handleCharInput('l');
    _ = input.handleCharInput('d');
    try std.testing.expectEqualStrings("Hello World", input.getText());

    // Test handleBackspace
    _ = input.handleBackspace();
    try std.testing.expectEqualStrings("Hello Worl", input.getText());

    // Test clear
    input.clear();
    try std.testing.expectEqualStrings("", input.getText());
    try std.testing.expectEqual(@as(usize, 0), input.cursor);
}

test "TextInput cursor movement" {
    var input = TextInput{};
    input.setText("Test");

    // Cursor should be at end
    try std.testing.expectEqual(@as(usize, 4), input.cursor);

    // Move left
    input.moveCursorLeft();
    try std.testing.expectEqual(@as(usize, 3), input.cursor);

    // Move home
    input.moveCursorHome();
    try std.testing.expectEqual(@as(usize, 0), input.cursor);

    // Move right
    input.moveCursorRight();
    try std.testing.expectEqual(@as(usize, 1), input.cursor);

    // Move end
    input.moveCursorEnd();
    try std.testing.expectEqual(@as(usize, 4), input.cursor);
}

test "TextInput insert at cursor" {
    var input = TextInput{};
    input.setText("AC");
    input.cursor = 1; // Position between A and C

    _ = input.handleCharInput('B');
    try std.testing.expectEqualStrings("ABC", input.getText());
    try std.testing.expectEqual(@as(usize, 2), input.cursor);
}

test "TextInput delete at cursor" {
    var input = TextInput{};
    input.setText("ABCD");
    input.cursor = 1;

    _ = input.handleDelete();
    try std.testing.expectEqualStrings("ACD", input.getText());
    try std.testing.expectEqual(@as(usize, 1), input.cursor);
}

test "TextInput blink update" {
    var input = TextInput{};
    input.focused = true;
    input.cursor_visible = true;

    // Update with time less than blink interval
    input.updateBlink(0.3);
    try std.testing.expect(input.cursor_visible);

    // Update past blink interval
    input.updateBlink(0.3);
    try std.testing.expect(!input.cursor_visible);

    // Toggle again
    input.updateBlink(0.5);
    try std.testing.expect(input.cursor_visible);
}

test "Panel init and title bar" {
    const panel = Panel.init(100, 50, 200, 150, "Test Panel");

    try std.testing.expectEqual(@as(i32, 100), panel.x);
    try std.testing.expectEqual(@as(i32, 50), panel.y);
    try std.testing.expectEqual(@as(i32, 200), panel.width);
    try std.testing.expectEqual(@as(i32, 150), panel.height);

    const title_rect = panel.getTitleBarRect();
    try std.testing.expectEqual(@as(i32, 100), title_rect.x);
    try std.testing.expectEqual(@as(i32, 50), title_rect.y);
    try std.testing.expectEqual(@as(i32, 200), title_rect.w);
    try std.testing.expectEqual(Panel.TITLE_BAR_HEIGHT, title_rect.h);
}

test "Panel dragging" {
    var panel = Panel.init(100, 50, 200, 150, "Test");
    var drag_state = PanelDragState{};

    // Start dragging at (110, 60)
    panel.beginDrag(110, 60, &drag_state);
    try std.testing.expect(drag_state.is_dragging);

    // Drag to new position
    panel.updateDrag(210, 160, &drag_state);
    try std.testing.expectEqual(@as(i32, 200), panel.x);
    try std.testing.expectEqual(@as(i32, 150), panel.y);

    // End drag
    Panel.endDragResize(&drag_state);
    try std.testing.expect(!drag_state.is_dragging);
}

test "Panel resize" {
    var panel = Panel.init(100, 50, 200, 150, "Test");
    var drag_state = PanelDragState{};

    // Check resize edge detection
    const edge = panel.getResizeEdge(295, 195);
    try std.testing.expectEqual(PanelDragState.ResizeEdge.bottom_right, edge);

    // Start resizing
    panel.beginResize(295, 195, .bottom_right, &drag_state);
    try std.testing.expect(drag_state.is_resizing);

    // Resize to larger
    panel.updateResize(350, 250, &drag_state);
    try std.testing.expectEqual(@as(i32, 250), panel.width);
    try std.testing.expectEqual(@as(i32, 200), panel.height);
}

test "Panel collapse" {
    var panel = Panel.init(100, 50, 200, 150, "Test");

    try std.testing.expectEqual(@as(i32, 150), panel.getEffectiveHeight());

    panel.toggleCollapse();
    try std.testing.expect(panel.collapsed);
    try std.testing.expectEqual(Panel.TITLE_BAR_HEIGHT, panel.getEffectiveHeight());

    panel.toggleCollapse();
    try std.testing.expect(!panel.collapsed);
}

test "ScrollList scroll handling" {
    var list = ScrollList.init(24);
    list.updateMaxScroll(20, 100); // 20 items * 24px = 480px content, 100px view

    try std.testing.expectEqual(@as(f32, 380), list.max_scroll);

    // Scroll down
    list.handleMouseWheel(-1);
    try std.testing.expect(list.scroll_offset > 0);

    // Scroll past max
    list.scroll_offset = 500;
    list.clampScroll();
    try std.testing.expectEqual(@as(f32, 380), list.scroll_offset);

    // Scroll past min
    list.scroll_offset = -50;
    list.clampScroll();
    try std.testing.expectEqual(@as(f32, 0), list.scroll_offset);
}

test "ScrollList item visibility" {
    var list = ScrollList.init(24);
    list.updateMaxScroll(20, 100);

    // First items should be visible
    try std.testing.expect(list.isItemVisible(0, 100));
    try std.testing.expect(list.isItemVisible(3, 100));

    // Items far down should not be visible initially
    try std.testing.expect(!list.isItemVisible(15, 100));

    // Scroll down and check again
    list.scroll_offset = 300;
    try std.testing.expect(!list.isItemVisible(0, 100));
    try std.testing.expect(list.isItemVisible(15, 100));
}

test "ScrollList item selection" {
    var list = ScrollList.init(24);
    list.updateMaxScroll(10, 200);

    // Click on first item
    const clicked = list.handleClick(10, 10);
    try std.testing.expectEqual(@as(?usize, 0), clicked);
    try std.testing.expectEqual(@as(?usize, 0), list.selected_index);

    // Click on third item
    _ = list.handleClick(60, 10);
    try std.testing.expectEqual(@as(?usize, 2), list.selected_index);
}

test "ScrollList keyboard navigation" {
    var list = ScrollList.init(24);
    list.updateMaxScroll(10, 200);

    // Select next from nothing
    list.selectNext(10, 200);
    try std.testing.expectEqual(@as(?usize, 0), list.selected_index);

    // Select next
    list.selectNext(10, 200);
    try std.testing.expectEqual(@as(?usize, 1), list.selected_index);

    // Select previous
    list.selectPrevious(200);
    try std.testing.expectEqual(@as(?usize, 0), list.selected_index);
}

test "TreeNode basic operations" {
    var node = TreeNode.init("Root");
    try std.testing.expectEqualStrings("Root", node.label);
    try std.testing.expect(!node.expanded);
    try std.testing.expect(!node.has_children);

    // Toggle should do nothing without children
    node.toggle();
    try std.testing.expect(!node.expanded);

    // With children, toggle should work
    node.has_children = true;
    node.toggle();
    try std.testing.expect(node.expanded);
    node.toggle();
    try std.testing.expect(!node.expanded);
}

test "TreeNode indentation" {
    const root = TreeNode.initWithDepth("Root", 0, true);
    const child = TreeNode.initWithDepth("Child", 1, false);
    const grandchild = TreeNode.initWithDepth("Grandchild", 2, false);

    try std.testing.expectEqual(@as(i32, 0), root.getIndentX());
    try std.testing.expectEqual(@as(i32, 20), child.getIndentX());
    try std.testing.expectEqual(@as(i32, 40), grandchild.getIndentX());
}

test "TreeNode indicator" {
    var node = TreeNode.initWithDepth("Node", 0, true);
    try std.testing.expectEqual(@as(u8, '+'), node.getIndicator());

    node.expanded = true;
    try std.testing.expectEqual(@as(u8, '-'), node.getIndicator());

    node.has_children = false;
    try std.testing.expectEqual(@as(u8, ' '), node.getIndicator());
}

test "TreeNode click handling" {
    var node = TreeNode.initWithDepth("Node", 1, true);
    const node_x: i32 = 10;

    // Click on indicator area (indent + indicator)
    const indicator_x = node_x + node.getIndentX();
    const changed = node.handleClick(indicator_x + 5, node_x);
    try std.testing.expect(changed);
    try std.testing.expect(node.expanded);

    // Click outside indicator
    const changed2 = node.handleClick(node_x + 100, node_x);
    try std.testing.expect(!changed2);
}

test "TreeView iterator" {
    var nodes = [_]TreeNode{
        TreeNode.initWithDepth("Root1", 0, true),
        TreeNode.initWithDepth("Child1", 1, false),
        TreeNode.initWithDepth("Child2", 1, false),
        TreeNode.initWithDepth("Root2", 0, false),
    };

    // With Root1 collapsed, should only see Root1 and Root2
    var iter = iterateVisibleNodes(&nodes);

    var count: usize = 0;
    while (iter.next()) |_| {
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, 2), count);

    // Expand Root1 and iterate again
    nodes[0].expanded = true;
    iter.reset();

    count = 0;
    while (iter.next()) |_| {
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, 4), count);
}

test "Dropdown basic operations" {
    var dropdown = Dropdown.init();

    try std.testing.expectEqual(@as(usize, 0), dropdown.getSelected());
    try std.testing.expect(!dropdown.is_open);

    dropdown.toggle();
    try std.testing.expect(dropdown.is_open);

    dropdown.setSelected(2);
    try std.testing.expectEqual(@as(usize, 2), dropdown.getSelected());

    dropdown.close();
    try std.testing.expect(!dropdown.is_open);
}

test "Dropdown selectItem" {
    var dropdown = Dropdown.init();
    dropdown.open();

    // Select item 3
    const changed = dropdown.selectItem(3, 5);
    try std.testing.expect(changed);
    try std.testing.expectEqual(@as(usize, 3), dropdown.getSelected());
    try std.testing.expect(!dropdown.is_open); // Should auto-close

    // Try to select same item again
    dropdown.open();
    const changed2 = dropdown.selectItem(3, 5);
    try std.testing.expect(!changed2);
}

test "TabBar navigation" {
    var tabs = TabBar.init(4);

    try std.testing.expectEqual(@as(usize, 0), tabs.getActive());
    try std.testing.expect(tabs.isActive(0));

    tabs.nextTab();
    try std.testing.expectEqual(@as(usize, 1), tabs.getActive());

    tabs.nextTab();
    tabs.nextTab();
    tabs.nextTab(); // Wrap around
    try std.testing.expectEqual(@as(usize, 0), tabs.getActive());

    tabs.prevTab(); // Wrap around backwards
    try std.testing.expectEqual(@as(usize, 3), tabs.getActive());

    tabs.setActive(2);
    try std.testing.expectEqual(@as(usize, 2), tabs.getActive());
}

test "Modal show and hide" {
    var modal = Modal.init("Test Modal", 300, 200);

    try std.testing.expect(!modal.is_visible);

    modal.show(800, 600);
    try std.testing.expect(modal.is_visible);
    try std.testing.expectEqual(@as(i32, 250), modal.x); // (800-300)/2
    try std.testing.expectEqual(@as(i32, 200), modal.y); // (600-200)/2

    try std.testing.expect(modal.contains(300, 300));
    try std.testing.expect(!modal.contains(0, 0));

    modal.hide();
    try std.testing.expect(!modal.is_visible);
}

test "Toast lifecycle" {
    var toast = Toast.init();

    try std.testing.expect(!toast.is_active);

    toast.show("Test message", .info, 2.0);
    try std.testing.expect(toast.is_active);
    try std.testing.expectEqualStrings("Test message", toast.getMessage());

    // Update partially
    const still_active = toast.update(1.0);
    try std.testing.expect(still_active);
    try std.testing.expect(toast.getRemainingRatio() > 0.4);
    try std.testing.expect(toast.getRemainingRatio() < 0.6);

    // Update to expire
    const expired = toast.update(1.5);
    try std.testing.expect(!expired);
    try std.testing.expect(!toast.is_active);
}

test "ToastManager multiple toasts" {
    var manager = ToastManager.init();

    try std.testing.expectEqual(@as(usize, 0), manager.activeCount());

    manager.push("Toast 1", .info, 3.0);
    manager.push("Toast 2", .success, 3.0);
    try std.testing.expectEqual(@as(usize, 2), manager.activeCount());

    manager.update(2.0);
    try std.testing.expectEqual(@as(usize, 2), manager.activeCount());

    manager.update(1.5);
    try std.testing.expectEqual(@as(usize, 0), manager.activeCount());
}

test "ToastManager dismiss all" {
    var manager = ToastManager.init();

    manager.push("Toast 1", .warning, 5.0);
    manager.push("Toast 2", .err, 5.0);
    try std.testing.expectEqual(@as(usize, 2), manager.activeCount());

    manager.dismissAll();
    try std.testing.expectEqual(@as(usize, 0), manager.activeCount());
}
