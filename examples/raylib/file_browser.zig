//! Simple Raylib example that lists files from the current directory and shows metadata.
const std = @import("std");
const raylib = @import("raylib");
const FilePathList = raylib.FilePathList;
const fs = std.fs;
const Color = raylib.Color;
const Rectangle = raylib.Rectangle;
const KeyboardKey = raylib.KeyboardKey;
const MouseButton = raylib.MouseButton;

const WINDOW_WIDTH: i32 = 960;
const WINDOW_HEIGHT: i32 = 600;
const LIST_X: i32 = 20;
const LIST_Y: i32 = 80;
const LIST_WIDTH: i32 = 360;
const LIST_LINE_HEIGHT: i32 = 28;
const MAX_VISIBLE: usize = 16;

const PANEL_COLOR = Color{ .r = 14, .g = 16, .b = 24, .a = 255 };
const TEXT_COLOR = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
const SELECT_COLOR = Color{ .r = 40, .g = 80, .b = 140, .a = 200 };

pub fn main() !void {
    raylib.initWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Nyon File Browser");
    defer raylib.closeWindow();
    raylib.setTargetFPS(60);

    var cwd = fs.cwd();
    defer cwd.close();

    var file_list = raylib.loadDirectoryFilesEx(".", "*.*", true);
    defer raylib.unloadDirectoryFiles(file_list);

    var selection: ?usize = null;

    while (!raylib.windowShouldClose()) {
        if (raylib.isKeyPressed(KeyboardKey.r)) {
            raylib.unloadDirectoryFiles(file_list);
            file_list = raylib.loadDirectoryFilesEx(".", "*.*", true);
            selection = null;
        }

        const mouse = raylib.getMousePosition();
        const file_count = @as(usize, file_list.count);
        const visible_count = if (file_count < MAX_VISIBLE) file_count else MAX_VISIBLE;

        if (raylib.isMouseButtonPressed(MouseButton.left)) {
            for (0..visible_count) |idx| {
                const idx_i32: i32 = @intCast(idx);
                const entry_y = LIST_Y + idx_i32 * LIST_LINE_HEIGHT;
                const entry_y_f32: f32 = @floatFromInt(entry_y);
                const entry_rect = Rectangle{
                    .x = LIST_X,
                    .y = entry_y_f32,
                    .width = @floatFromInt(LIST_WIDTH),
                    .height = @floatFromInt(LIST_LINE_HEIGHT),
                };
                if (raylib.checkCollisionPointRec(mouse, entry_rect)) {
                    selection = idx;
                    break;
                }
            }
        }

        raylib.beginDrawing();
        raylib.clearBackground(PANEL_COLOR);

        raylib.drawText("Press R to refresh the directory listing.", LIST_X, 20, 18, TEXT_COLOR);
        raylib.drawText("Click a file to show metadata.", LIST_X, 44, 18, TEXT_COLOR);

        for (0..visible_count) |idx| {
            const idx_i32: i32 = @intCast(idx);
            const entry_y = LIST_Y + idx_i32 * LIST_LINE_HEIGHT;
            const entry_y_f32: f32 = @floatFromInt(entry_y);
            const rec = Rectangle{
                .x = LIST_X,
                .y = entry_y_f32,
                .width = @floatFromInt(LIST_WIDTH),
                .height = @floatFromInt(LIST_LINE_HEIGHT),
            };
            if (selection == idx) {
                raylib.drawRectangleRec(rec, SELECT_COLOR);
            }
            const path_slice = pathSlice(file_list, idx);
            raylib.drawText(path_slice, LIST_X + 8, entry_y + 6, 16, TEXT_COLOR);
        }

        const detail_x = LIST_X + LIST_WIDTH + 36;
        const detail_y = LIST_Y;
        var info_y = detail_y;

        if (selection) |sel| {
            const sel_path = pathSlice(file_list, sel);
            var title_buf: [160:0]u8 = undefined;
            const title = try std.fmt.bufPrintZ(&title_buf, "Selected: {s}", .{sel_path});
            raylib.drawText(title, detail_x, info_y, 20, TEXT_COLOR);
            info_y += 34;

            const stat = cwd.statFile(sel_path[0..sel_path.len]) catch null;
            if (stat) |info| {
                var info_buf: [96:0]u8 = undefined;
                const size_value: usize = @intCast(info.size);
                const info_text = try std.fmt.bufPrintZ(&info_buf, "Size: {d} bytes", .{size_value});
                raylib.drawText(info_text, detail_x, info_y, 18, TEXT_COLOR);
                info_y += 28;
                var mod_buf: [96:0]u8 = undefined;
                const modified_seconds: i64 = @intCast(@divTrunc(info.mtime.nanoseconds, std.time.ns_per_s));
                const mod_text = try std.fmt.bufPrintZ(&mod_buf, "Modified: {d}", .{modified_seconds});
                raylib.drawText(mod_text, detail_x, info_y, 18, TEXT_COLOR);
            } else {
                raylib.drawText("Metadata unavailable", detail_x, info_y, 18, TEXT_COLOR);
            }
        } else {
            raylib.drawText("Select a file in the list to inspect it.", detail_x, info_y, 20, TEXT_COLOR);
        }

        const status_y = WINDOW_HEIGHT - 36;
        raylib.drawText("Example: raylib.File + std.fs", LIST_X, status_y, 16, TEXT_COLOR);
        raylib.endDrawing();
    }
}

fn pathSlice(paths: FilePathList, index: usize) [:0]const u8 {
    const ptr: [*c]const u8 = @constCast(paths.paths[index]);
    return std.mem.span(ptr);
}
