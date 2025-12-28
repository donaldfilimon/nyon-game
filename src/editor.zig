const std = @import("std");
const rl = @import("raylib");
const nyon_game = @import("nyon_game");
const MainEditor = nyon_game.main_editor.MainEditor;

/// Unified Editor Entry Point
///
/// This entry point uses the unified MainEditor system (`src/main_editor.zig`)
/// which consolidates all editor sub-systems (Scene, Geometry Nodes, Materials, etc.)
/// into a single cohesive interface.
pub fn main() !void {
    const screenWidth = 1600;
    const screenHeight = 900;

    // Initialize Raylib with configuration flags
    rl.setConfigFlags(rl.ConfigFlags{
        .window_resizable = true,
        .msaa_4x_hint = true,
        .vsync_hint = true,
    });

    rl.initWindow(screenWidth, screenHeight, "Nyon Game Editor");
    defer rl.closeWindow();

    rl.setTargetFPS(60);
    rl.setExitKey(.null); // Disable ESC to exit

    // Initialize Audio Device
    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    // Use General Purpose Allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize the Main Editor System
    var editor = try MainEditor.init(allocator, @floatFromInt(screenWidth), @floatFromInt(screenHeight));
    defer editor.deinit();

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();

        // Handle Window Resizing
        if (rl.isWindowResized()) {
            editor.screen_width = @floatFromInt(rl.getScreenWidth());
            editor.screen_height = @floatFromInt(rl.getScreenHeight());

            // TODO: Recreate viewport render texture in MainEditor to match new resolution
            // editor.resize(editor.screen_width, editor.screen_height);
        }

        // Update Editor State
        try editor.handleInput();
        try editor.update(dt);

        // Render Frame
        rl.beginDrawing();
        rl.clearBackground(rl.Color{ .r = 30, .g = 30, .b = 40, .a = 255 }); // Dark background

        try editor.render();

        rl.endDrawing();
    }
}
