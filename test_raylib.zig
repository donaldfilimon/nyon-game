//! Test simple raylib functionality with stub replacements
const std = @import("std");
const raylib = @import("raylib");

pub fn main() !void {
    const screenWidth = 800;
    const screenHeight = 450;

    // Test basic window creation (this should work with stubs)
    raylib.initWindow(screenWidth, screenHeight, "Nyon Game Engine - Raylib Test");
    defer raylib.closeWindow();

    raylib.setTargetFPS(60);

    while (!raylib.windowShouldClose()) {
        raylib.beginDrawing();
        defer raylib.endDrawing();

        raylib.clearBackground(raylib.Color.ray_white);

        // Test basic drawing
        raylib.drawText("Testing raylib integration!", 190, 200, 20, raylib.Color.light_gray);
        raylib.drawCircle(400, 300, 50, raylib.Color.blue);
        raylib.drawRectangle(100, 100, 80, 60, raylib.Color.red);
    }
}
