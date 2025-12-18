const std = @import("std");
const nyon_game = @import("nyon_game");
const Engine = @import("engine.zig").Engine;

pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    try nyon_game.bufferedPrint();

    // Example: Initialize the engine with different backends
    std.debug.print("\n=== Engine Backend Examples ===\n", .{});

    // Example 1: GPU-only backend (universal, works on browsers)
    std.debug.print("1. GPU Backend (Universal): std.gpu with WebGPU/browser support\n", .{});

    // Example 2: GLFW backend for low-level control
    std.debug.print("2. GLFW Backend: Full low-level window/input control\n", .{});

    // Example 3: Raylib backend for high-level game features
    std.debug.print("3. Raylib Backend: High-level 2D/3D game development\n", .{});

    // Example usage:
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create engine with raylib backend
    var engine = try Engine.init(allocator, .{
        .backend = .raylib, // Raylib backend for comprehensive game development
        .width = 800,
        .height = 600,
        .title = "Nyon Game Engine Demo",
        .target_fps = 60,
    });
    defer engine.deinit();

    std.debug.print("Engine initialized successfully!\n", .{});
    std.debug.print("Window size: {}x{}\n", .{ engine.getWindowSize().width, engine.getWindowSize().height });

    // Access all raylib functions through the engine
    const rl = @import("engine.zig").rl;
    _ = rl; // Direct raylib access available

    // Note: GLFW support is not currently implemented
    // The engine focuses on raylib for comprehensive game development

    // Example game loop structure
    std.debug.print("\nExample game loop:\n", .{});
    std.debug.print("while (!engine.shouldClose()) {{\n", .{});
    std.debug.print("    engine.pollEvents(); // For GLFW backend\n", .{});
    std.debug.print("    engine.beginDrawing(); // For raylib-style API\n", .{});
    std.debug.print("    engine.clearBackground(Engine.Color.ray_white);\n", .{});
    std.debug.print("    // Your game logic here...\n", .{});
    std.debug.print("    Engine.Text.draw(\"Hello World!\", 10, 10, 20, Engine.Color.black);\n", .{});
    std.debug.print("    engine.endDrawing();\n", .{});
    std.debug.print("}}\n", .{});
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
