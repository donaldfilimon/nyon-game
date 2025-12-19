//! Raylib demonstration that visualizes files dropped into the window.
const std = @import("std");
const raylib = @import("raylib");
const fs = std.fs;
const Color = raylib.Color;
const KeyboardKey = raylib.KeyboardKey;

const WINDOW_WIDTH: i32 = 780;
const WINDOW_HEIGHT: i32 = 520;
const HEADER_Y: i32 = 20;
const CONTENT_X: i32 = 20;
const CONTENT_Y: i32 = 80;
const LINE_HEIGHT: i32 = 28;

const BACKGROUND = Color{ .r = 18, .g = 24, .b = 32, .a = 255 };
const TEXT = Color{ .r = 236, .g = 236, .b = 236, .a = 255 };
const WARNING = Color{ .r = 236, .g = 132, .b = 60, .a = 255 };

const DroppedFile = struct {
    path: []const u8,
    size: usize,
};

pub fn main() !void {
    raylib.initWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Drag & Drop Tracker");
    defer raylib.closeWindow();
    raylib.setTargetFPS(60);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var cwd = fs.cwd();
    defer cwd.close();

    var dropped = try std.ArrayList(DroppedFile).initCapacity(allocator, 0);
    defer {
        for (dropped.items) |entry| {
            allocator.free(entry.path);
        }
        dropped.deinit(allocator);
    }

    while (!raylib.windowShouldClose()) {
        if (raylib.isFileDropped()) {
            const list = raylib.loadDroppedFiles();
            defer raylib.unloadDroppedFiles(list);
            const count = @as(usize, list.count);
            for (list.paths[0..count]) |c_path| {
                const actual = std.mem.span(c_path);
                const actual_slice = actual[0..actual.len];
                const dup = try allocator.dupe(u8, actual_slice);
                const size = readFileSize(&cwd, actual);
                try dropped.append(allocator, DroppedFile{ .path = dup, .size = size });
            }
        }

        if (raylib.isKeyPressed(KeyboardKey.c)) {
            for (dropped.items) |entry| allocator.free(entry.path);
            dropped.clearRetainingCapacity();
        }

        raylib.beginDrawing();
        raylib.clearBackground(BACKGROUND);

        raylib.drawText("Drop files onto this window to capture metadata.", CONTENT_X, HEADER_Y, 20, TEXT);
        raylib.drawText("Press C to clear the list.", CONTENT_X, HEADER_Y + 26, 18, WARNING);

        var draw_y = CONTENT_Y;
        const available = @as(usize, (WINDOW_HEIGHT - CONTENT_Y) / LINE_HEIGHT);
        const limit = if (dropped.items.len < available) dropped.items.len else available;
        for (dropped.items[0..limit]) |entry| {
            var entry_buf: [256:0]u8 = undefined;
            const entry_text = try std.fmt.bufPrintZ(
                &entry_buf,
                "{s} ({d} bytes)",
                .{ entry.path, entry.size },
            );
            raylib.drawText(entry_text, CONTENT_X, draw_y, 18, TEXT);
            draw_y += LINE_HEIGHT;
        }

        if (dropped.items.len == 0) {
            raylib.drawText("Waiting for files...", CONTENT_X, draw_y, 18, TEXT);
        }

        raylib.endDrawing();
    }
}

fn readFileSize(cwd: *fs.Dir, path: []const u8) usize {
    if (cwd.statFile(path) catch null) |info| {
        return @as(usize, info.size);
    }
    return 0;
}
