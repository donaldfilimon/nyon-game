//! Terminal UI Mode for Nyon Game Engine Editor
//!
//! This module provides a terminal-like command line interface
//! within the editor for advanced operations and debugging.

const std = @import("std");
const raylib = @import("raylib");
const config = @import("../config/constants.zig");

const editor_mod = @import("editor.zig");

// ============================================================================
// TUI Mode State
// ============================================================================

pub const TUIMode = struct {
    allocator: std.mem.Allocator,
    /// Command input buffer
    command_buffer: std.ArrayList(u8),
    /// Command history
    command_history: std.ArrayList([]const u8),
    /// Output lines
    output_lines: std.ArrayList([]const u8),
    /// Cursor position in command buffer
    cursor_pos: usize = 0,
    /// History index for navigation
    history_index: i32 = -1,
    /// Scroll position for output
    scroll_offset: f32 = 0,

    pub fn init(allocator: std.mem.Allocator) !TUIMode {
        var command_buffer = std.ArrayList(u8).initCapacity(allocator, config.Memory.COMMAND_BUFFER) catch unreachable;
        errdefer command_buffer.deinit(allocator);

        var command_history = std.ArrayList([]const u8).initCapacity(allocator, config.Performance.MAX_HISTORY) catch unreachable;
        errdefer command_history.deinit(allocator);

        var output_lines = std.ArrayList([]const u8).initCapacity(allocator, config.Performance.MAX_HISTORY) catch unreachable;
        errdefer output_lines.deinit(allocator);

        // Add welcome messages
        try output_lines.append(allocator, try allocator.dupe(u8, "Nyon Game Engine TUI v1.0"));
        try output_lines.append(allocator, try allocator.dupe(u8, "Type 'help' for available commands"));
        try output_lines.append(allocator, try allocator.dupe(u8, ""));

        return TUIMode{
            .allocator = allocator,
            .command_buffer = command_buffer,
            .command_history = command_history,
            .output_lines = output_lines,
        };
    }

    pub fn deinit(self: *TUIMode) void {
        self.command_buffer.deinit(self.allocator);
        for (self.command_history.items) |cmd| {
            self.allocator.free(cmd);
        }
        self.command_history.deinit(self.allocator);
        for (self.output_lines.items) |line| {
            self.allocator.free(line);
        }
        self.output_lines.deinit(self.allocator);
    }

    pub fn update(self: *TUIMode, editor: *editor_mod.MainEditor, dt: f32) void {
        _ = editor;
        _ = dt;

        self.handleInput();
    }

    pub fn render(self: *TUIMode, editor: *editor_mod.MainEditor, content_rect: raylib.Rectangle) void {
        _ = editor;

        // Background
        raylib.drawRectangleRec(content_rect, raylib.Color{ .r = 20, .g = 20, .b = 30, .a = 255 });

        // Output area
        const output_height = content_rect.height - 40;
        const output_rect = raylib.Rectangle{
            .x = content_rect.x,
            .y = content_rect.y,
            .width = content_rect.width,
            .height = output_height,
        };

        self.renderOutputArea(output_rect);

        // Command input area
        const input_rect = raylib.Rectangle{
            .x = content_rect.x,
            .y = content_rect.y + output_height,
            .width = content_rect.width,
            .height = 40,
        };

        self.renderCommandInput(input_rect);
    }

    fn handleInput(self: *TUIMode) void {
        // Handle character input
        var char_code = raylib.getCharPressed();
        while (char_code != 0) {
            if (char_code >= 32 and char_code <= 126) { // Printable ASCII
                self.insertChar(@intCast(char_code));
            }
            char_code = raylib.getCharPressed();
        }

        // Handle special keys
        if (raylib.isKeyPressed(raylib.KeyboardKey.backspace)) {
            self.deleteChar();
        }

        if (raylib.isKeyPressed(raylib.KeyboardKey.enter)) {
            self.executeCommand();
        }

        if (raylib.isKeyPressed(raylib.KeyboardKey.up)) {
            self.navigateHistory(-1);
        }

        if (raylib.isKeyPressed(raylib.KeyboardKey.down)) {
            self.navigateHistory(1);
        }

        if (raylib.isKeyPressed(raylib.KeyboardKey.left)) {
            if (self.cursor_pos > 0) {
                self.cursor_pos -= 1;
            }
        }

        if (raylib.isKeyPressed(raylib.KeyboardKey.right)) {
            if (self.cursor_pos < self.command_buffer.items.len) {
                self.cursor_pos += 1;
            }
        }
    }

    fn insertChar(self: *TUIMode, c: u8) void {
        if (self.cursor_pos >= self.command_buffer.items.len) {
            self.command_buffer.append(self.allocator, c) catch return;
        } else {
            self.command_buffer.insert(self.cursor_pos, c) catch return;
        }
        self.cursor_pos += 1;
    }

    fn deleteChar(self: *TUIMode) void {
        if (self.cursor_pos > 0 and self.command_buffer.items.len > 0) {
            _ = self.command_buffer.orderedRemove(self.cursor_pos - 1);
            self.cursor_pos -= 1;
        }
    }

    fn executeCommand(self: *TUIMode) void {
        if (self.command_buffer.items.len == 0) return;

        // Convert command buffer to string
        const command = std.mem.trim(u8, self.command_buffer.items[0..self.command_buffer.items.len], " \t");

        // Add to history
        if (command.len > 0) {
            const cmd_copy = self.command_buffer.allocator.dupe(u8, command) catch return;
            self.command_history.append(self.allocator, cmd_copy) catch {
                self.command_buffer.allocator.free(cmd_copy);
                return;
            };
        }

        // Add command to output
        const prompt = std.fmt.allocPrint(self.command_buffer.allocator, "> {s}", .{command}) catch "> ?";
        defer self.command_buffer.allocator.free(prompt);
        self.output_lines.append(self.allocator, prompt) catch {};

        // Execute command
        self.executeCommandLogic(command);

        // Clear command buffer and reset cursor
        self.command_buffer.clearRetainingCapacity();
        self.cursor_pos = 0;
        self.history_index = -1;
    }

    fn executeCommandLogic(self: *TUIMode, command: []const u8) void {
        if (std.mem.eql(u8, command, "help")) {
            self.addOutputLine("Available commands:");
            self.addOutputLine("  help     - Show this help");
            self.addOutputLine("  clear    - Clear output");
            self.addOutputLine("  version  - Show version info");
            self.addOutputLine("  fps      - Show current FPS");
            self.addOutputLine("  echo     - Echo text");
        } else if (std.mem.eql(u8, command, "clear")) {
            // Clear all output lines
            for (self.output_lines.items) |line| {
                self.command_buffer.allocator.free(line);
            }
            self.output_lines.clearRetainingCapacity();
            self.addOutputLine("Nyon Game Engine TUI v1.0");
            self.addOutputLine("Type 'help' for available commands");
            self.addOutputLine("");
        } else if (std.mem.eql(u8, command, "version")) {
            self.addOutputLine("Nyon Game Engine v1.0");
            self.addOutputLine("Built with Zig and raylib");
        } else if (std.mem.eql(u8, command, "fps")) {
            const fps = raylib.getFPS();
            const fps_str = std.fmt.allocPrint(self.command_buffer.allocator, "Current FPS: {d}", .{fps}) catch "FPS: ?";
            defer self.command_buffer.allocator.free(fps_str);
            self.addOutputLine(fps_str);
        } else if (std.mem.startsWith(u8, command, "echo ")) {
            const text = std.mem.trim(u8, command[5..], " ");
            if (text.len > 0) {
                self.addOutputLine(text);
            }
        } else if (command.len > 0) {
            const error_msg = std.fmt.allocPrint(self.command_buffer.allocator, "Unknown command: {s}", .{command}) catch "Unknown command";
            defer self.command_buffer.allocator.free(error_msg);
            self.addOutputLine(error_msg);
            self.addOutputLine("Type 'help' for available commands");
        }
    }

    fn navigateHistory(self: *TUIMode, direction: i32) void {
        if (self.command_history.items.len == 0) return;

        self.history_index += direction;

        if (self.history_index < 0) {
            self.history_index = -1;
            self.command_buffer.clearRetainingCapacity();
            self.cursor_pos = 0;
            return;
        }

        if (self.history_index >= @as(i32, @intCast(self.command_history.items.len))) {
            self.history_index = @intCast(self.command_history.items.len - 1);
        }

        const history_item = self.command_history.items[@intCast(self.history_index)];
        self.command_buffer.clearRetainingCapacity();
        self.command_buffer.appendSlice(history_item) catch return;
        self.cursor_pos = self.command_buffer.items.len;
    }

    fn addOutputLine(self: *TUIMode, line: []const u8) void {
        const line_copy = self.command_buffer.allocator.dupe(u8, line) catch return;
        self.output_lines.append(self.allocator, line_copy) catch {
            self.command_buffer.allocator.free(line_copy);
        };
    }

    fn renderOutputArea(self: *TUIMode, rect: raylib.Rectangle) void {
        // Border
        raylib.drawRectangleLinesEx(rect, 1, raylib.Color{ .r = 60, .g = 60, .b = 70, .a = 255 });

        // Output text
        const line_height = 16;
        const max_visible_lines = @as(usize, @intFromFloat(rect.height / @as(f32, @floatFromInt(line_height))));
        const start_line = if (self.output_lines.items.len > max_visible_lines)
            self.output_lines.items.len - max_visible_lines
        else
            0;

        var y: f32 = rect.y + 5;
        var line_idx = start_line;
        while (line_idx < self.output_lines.items.len and y < rect.y + rect.height - line_height) : (line_idx += 1) {
            const line = self.output_lines.items[line_idx];
            raylib.drawText(line, @intFromFloat(rect.x + 5), @intFromFloat(y), 14, raylib.Color{ .r = 200, .g = 200, .b = 200, .a = 255 });
            y += line_height;
        }
    }

    fn renderCommandInput(self: *TUIMode, rect: raylib.Rectangle) void {
        // Background
        raylib.drawRectangleRec(rect, raylib.Color{ .r = 40, .g = 40, .b = 50, .a = 255 });

        // Border
        raylib.drawRectangleLinesEx(rect, 1, raylib.Color{ .r = 100, .g = 100, .b = 110, .a = 255 });

        // Prompt
        raylib.drawText("> ", @intFromFloat(rect.x + 5), @intFromFloat(rect.y + 10), 16, raylib.Color.white);

        // Command text
        const command_x = rect.x + 25;
        const command_text = self.command_buffer.items;
        if (command_text.len > 0) {
            raylib.drawText(@ptrCast(command_text), @intFromFloat(command_x), @intFromFloat(rect.y + 10), 16, raylib.Color{ .r = 220, .g = 220, .b = 220, .a = 255 });
        }

        // Cursor
        const cursor_x = command_x + @as(f32, @floatFromInt(raylib.measureText(@ptrCast(command_text[0..self.cursor_pos]), 16)));
        raylib.drawLine(
            @intFromFloat(cursor_x),
            @intFromFloat(rect.y + 8),
            @intFromFloat(cursor_x),
            @intFromFloat(rect.y + 24),
            raylib.Color.white,
        );
    }
};
