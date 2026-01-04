//! TUI mode helpers for the unified editor.
//!
//! Split from the main editor to keep TUI parsing and rendering isolated.
const std = @import("std");
const raylib = @import("raylib");

const undo_redo = @import("../undo_redo.zig");

/// TUI update hook (input is handled separately).
pub fn update(editor: anytype, _: f32) void {
    _ = editor;
}

/// Draws the terminal UI mode area, including command buffer and output scrollback.
pub fn render(editor: anytype, content_rect: raylib.Rectangle) void {
    raylib.beginScissorMode(
        @intFromFloat(content_rect.x),
        @intFromFloat(content_rect.y),
        @intFromFloat(content_rect.width),
        @intFromFloat(content_rect.height),
    );
    raylib.drawRectangleRec(content_rect, raylib.Color{ .r = 20, .g = 20, .b = 30, .a = 255 });
    const line_height: f32 = 20;
    const max_visible_lines = @as(usize, @intFromFloat(content_rect.height / line_height)) - 2;

    var y: f32 = content_rect.y + 10;
    const start_line = if (editor.tui_output_lines.items.len > max_visible_lines)
        editor.tui_output_lines.items.len - max_visible_lines
    else
        0;
    for (editor.tui_output_lines.items[start_line..]) |line| {
        raylib.drawText(line, @intFromFloat(content_rect.x + 10), @intFromFloat(y), 16, raylib.Color.white);
        y += line_height;
        if (y > content_rect.y + content_rect.height - 60) break;
    }
    // Draw the command prompt and cursor.
    const prompt_y = content_rect.y + content_rect.height - 40;
    raylib.drawText(">", @intFromFloat(content_rect.x + 10), @intFromFloat(prompt_y), 16, raylib.Color.green);
    const command_text = editor.tui_command_buffer.items;
    raylib.drawText(command_text, @intFromFloat(content_rect.x + 25), @intFromFloat(prompt_y), 16, raylib.Color.white);
    if (raylib.getTime() - @floor(raylib.getTime()) < 0.5) {
        const cursor_x = content_rect.x + 25 + @as(f32, @floatFromInt(editor.tui_cursor_pos)) * 8.5;
        raylib.drawLine(@intFromFloat(cursor_x), @intFromFloat(prompt_y), @intFromFloat(cursor_x), @intFromFloat(prompt_y + 16), raylib.Color.white);
    }
    raylib.endScissorMode();
}

/// TUI mode input processing (ASCII only).
pub fn handleInput(editor: anytype) void {
    const char = raylib.getCharPressed();
    if (char != 0) {
        if (editor.tui_cursor_pos < editor.tui_command_buffer.items.len)
            editor.tui_command_buffer.insert(editor.tui_cursor_pos, @as(u8, @intCast(char))) catch return
        else
            editor.tui_command_buffer.append(@as(u8, @intCast(char))) catch return;
        editor.tui_cursor_pos += 1;
    }
    if (raylib.isKeyPressed(.backspace)) {
        if (editor.tui_cursor_pos > 0) {
            _ = editor.tui_command_buffer.orderedRemove(editor.tui_cursor_pos - 1);
            editor.tui_cursor_pos -= 1;
        }
    }
    if (raylib.isKeyPressed(.enter)) executeCommand(editor);

    // Command history navigation/up/down.
    if (raylib.isKeyPressed(.up)) {
        if (editor.tui_history_index < @as(i32, @intCast(editor.tui_command_history.items.len)) - 1) {
            editor.tui_history_index += 1;
            const history_cmd = editor.tui_command_history.items[editor.tui_command_history.items.len - 1 - @as(usize, @intCast(editor.tui_history_index))];
            editor.tui_command_buffer.clearRetainingCapacity();
            editor.tui_command_buffer.appendSlice(history_cmd) catch return;
            editor.tui_cursor_pos = history_cmd.len;
        }
    }
    if (raylib.isKeyPressed(.down)) {
        if (editor.tui_history_index > 0) {
            editor.tui_history_index -= 1;
            const history_cmd = editor.tui_command_history.items[editor.tui_command_history.items.len - 1 - @as(usize, @intCast(editor.tui_history_index))];
            editor.tui_command_buffer.clearRetainingCapacity();
            editor.tui_command_buffer.appendSlice(history_cmd) catch return;
            editor.tui_cursor_pos = history_cmd.len;
        } else if (editor.tui_history_index == 0) {
            editor.tui_history_index = -1;
            editor.tui_command_buffer.clearRetainingCapacity();
            editor.tui_cursor_pos = 0;
        }
    }
    // Buffer editing.
    if (raylib.isKeyPressed(.left)) {
        if (editor.tui_cursor_pos > 0) editor.tui_cursor_pos -= 1;
    }
    if (raylib.isKeyPressed(.right)) {
        if (editor.tui_cursor_pos < editor.tui_command_buffer.items.len) editor.tui_cursor_pos += 1;
    }
}

fn executeCommand(editor: anytype) void {
    const command = editor.tui_command_buffer.items;
    if (command.len == 0) return;
    const cmd_copy = editor.allocator.dupe(u8, command) catch return;
    editor.tui_command_history.append(cmd_copy) catch {
        editor.allocator.free(cmd_copy);
        return;
    };

    var output_line = std.ArrayList(u8).initCapacity(editor.allocator, command.len + 3) catch return;
    defer output_line.deinit();
    output_line.appendSlice("> ") catch return;
    output_line.appendSlice(command) catch return;
    const output_cmd = output_line.toOwnedSlice() catch return;
    editor.tui_output_lines.append(output_cmd) catch {
        editor.allocator.free(output_cmd);
    };

    // Built-in TUI command set: @Definitions.
    if (std.mem.eql(u8, command, "help")) {
        addOutput(editor, "Available commands:");
        addOutput(editor, "  help          - Show this help");
        addOutput(editor, "  clear         - Clear terminal");
        addOutput(editor, "  mode scene    - Switch to scene editor");
        addOutput(editor, "  mode geometry - Switch to geometry nodes");
        addOutput(editor, "  mode material - Switch to material editor");
        addOutput(editor, "  mode animation- Switch to animation editor");
        addOutput(editor, "  mode tui      - Stay in TUI mode");
        addOutput(editor, "  panels        - List dock panel names and ids");
        addOutput(editor, "  exit          - Exit application");
    } else if (std.mem.eql(u8, command, "clear")) {
        for (editor.tui_output_lines.items) |line| editor.allocator.free(line);
        editor.tui_output_lines.clearRetainingCapacity();
        addOutput(editor, "Terminal cleared");
    } else if (std.mem.eql(u8, command, "undo")) {
        editor.undo_redo_system.undo() catch |err| {
            var buf: [64]u8 = undefined;
            addOutput(editor, std.fmt.bufPrint(&buf, "Undo failed: {any}", .{err}) catch "Undo failed");
            return;
        };
        addOutput(editor, "Undone successfully");
    } else if (std.mem.eql(u8, command, "redo")) {
        editor.undo_redo_system.redo() catch |err| {
            var buf: [64]u8 = undefined;
            addOutput(editor, std.fmt.bufPrint(&buf, "Redo failed: {any}", .{err}) catch "Redo failed");
            return;
        };
        addOutput(editor, "Redone successfully");
    } else if (std.mem.startsWith(u8, command, "add ")) {
        const model_path = command[4..];
        const cmd = undo_redo.AddObjectCommand.create(
            editor.allocator,
            &editor.scene_system,
            &editor.asset_manager,
            &editor.world,
            &editor.physics_system,
            model_path,
            .{ .x = 0, .y = 0, .z = 0 },
            "Add object through TUI",
        ) catch |err| {
            var buf: [64]u8 = undefined;
            addOutput(editor, std.fmt.bufPrint(&buf, "Failed to create add command: {any}", .{err}) catch "Add failed");
            return;
        };
        editor.undo_redo_system.executeCommand(&cmd.base) catch |err| {
            var buf: [64]u8 = undefined;
            addOutput(editor, std.fmt.bufPrint(&buf, "Failed to execute add command: {any}", .{err}) catch "Add execution failed");
            return;
        };
        addOutput(editor, "Object added");
        editor.rebuildSceneEntityMapping();
    } else if (std.mem.startsWith(u8, command, "remove ")) {
        const index_str = command[7..];
        const index = std.fmt.parseInt(usize, index_str, 10) catch {
            addOutput(editor, "Invalid index");
            return;
        };
        const cmd = undo_redo.RemoveObjectCommand.create(
            editor.allocator,
            &editor.scene_system,
            &editor.asset_manager,
            &editor.world,
            &editor.physics_system,
            index,
            "Remove object through TUI",
        ) catch |err| {
            var buf: [64]u8 = undefined;
            addOutput(editor, std.fmt.bufPrint(&buf, "Failed to create remove command: {any}", .{err}) catch "Remove failed");
            return;
        };
        editor.undo_redo_system.executeCommand(&cmd.base) catch |err| {
            var buf: [64]u8 = undefined;
            addOutput(editor, std.fmt.bufPrint(&buf, "Failed to execute remove command: {any}", .{err}) catch "Remove execution failed");
            return;
        };
        addOutput(editor, "Object removed");
        editor.rebuildSceneEntityMapping();
    } else if (std.mem.startsWith(u8, command, "mode ")) {
        const mode_arg = command[5..];
        if (std.mem.eql(u8, mode_arg, "scene")) {
            editor.current_mode = .scene_editor;
            addOutput(editor, "Switched to Scene Editor");
        } else if (std.mem.eql(u8, mode_arg, "geometry")) {
            editor.current_mode = .geometry_nodes;
            addOutput(editor, "Switched to Geometry Nodes");
        } else if (std.mem.eql(u8, mode_arg, "material")) {
            editor.current_mode = .material_editor;
            addOutput(editor, "Switched to Material Editor");
        } else if (std.mem.eql(u8, mode_arg, "animation")) {
            editor.current_mode = .animation_editor;
            addOutput(editor, "Switched to Animation Editor");
        } else if (std.mem.eql(u8, mode_arg, "tui")) {
            addOutput(editor, "Already in TUI mode");
        } else {
            addOutput(editor, "Unknown mode. Use: scene, geometry, material, animation, tui");
        }
    } else if (std.mem.eql(u8, command, "panels")) {
        for (editor.docking_system.panels.items, 0..) |*panel, idx| {
            var buf: [128]u8 = undefined;
            const panel_str = std.fmt.bufPrint(&buf, "#{d} {s} @ [{d},{d},{d},{d}]", .{
                idx,
                panel.title,
                @intFromFloat(panel.rect.x),
                @intFromFloat(panel.rect.y),
                @intFromFloat(panel.rect.width),
                @intFromFloat(panel.rect.height),
            }) catch continue;
            addOutput(editor, panel_str);
        }
        if (editor.docking_system.panels.items.len == 0)
            addOutput(editor, "No panels defined.");
    } else if (std.mem.eql(u8, command, "exit")) {
        addOutput(editor, "Use Ctrl+C or close window to exit");
    } else {
        var unknown_msg = std.ArrayList(u8).initCapacity(editor.allocator, command.len + 20) catch return;
        defer unknown_msg.deinit();
        unknown_msg.appendSlice("Unknown command: ") catch return;
        unknown_msg.appendSlice(command) catch return;
        const unknown_str = unknown_msg.toOwnedSlice() catch return;
        editor.tui_output_lines.append(unknown_str) catch {
            editor.allocator.free(unknown_str);
        };
    }

    editor.tui_command_buffer.clearRetainingCapacity();
    editor.tui_cursor_pos = 0;
    editor.tui_history_index = -1;
}

fn addOutput(editor: anytype, text: []const u8) void {
    const output_line = editor.allocator.dupe(u8, text) catch return;
    editor.tui_output_lines.append(output_line) catch {
        editor.allocator.free(output_line);
    };
}
