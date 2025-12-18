const std = @import("std");
const engine_mod = @import("engine.zig");
const Engine = engine_mod.Engine;
const Audio = engine_mod.Audio;
const Input = engine_mod.Input;
const Shapes = engine_mod.Shapes;
const Text = engine_mod.Text;
const KeyboardKey = engine_mod.KeyboardKey;

// Game state
const GameState = struct {
    player_x: f32 = 400.0,
    player_y: f32 = 300.0,
    player_speed: f32 = 200.0,
    player_size: f32 = 30.0,

    // Collectible items
    items: [5]struct { x: f32, y: f32, collected: bool } = .{
        .{ .x = 100, .y = 100, .collected = false },
        .{ .x = 200, .y = 150, .collected = false },
        .{ .x = 300, .y = 200, .collected = false },
        .{ .x = 500, .y = 250, .collected = false },
        .{ .x = 700, .y = 400, .collected = false },
    },

    score: u32 = 0,
    game_time: f32 = 0.0,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize engine with raylib backend
    var engine = try Engine.init(allocator, .{
        .backend = .raylib,
        .width = 800,
        .height = 600,
        .title = "Nyon Game - Collect Items!",
        .target_fps = 60,
        .resizable = false,
        .vsync = true,
    });
    defer engine.deinit();

    var game_state = GameState{};
    const window_size = engine.getWindowSize();
    const screen_width = @as(f32, @floatFromInt(window_size.width));
    const screen_height = @as(f32, @floatFromInt(window_size.height));

    // Initialize audio device (optional - comment out if not needed)
    Audio.initDevice();

    // Main game loop
    while (!engine.shouldClose()) {
        engine.pollEvents();
        engine.beginDrawing();

        // Update game time
        game_state.game_time += engine.getFrameTime();

        // Handle input
        const delta_time = engine.getFrameTime();
        var moved = false;

        if (Input.Keyboard.isDown(KeyboardKey.w) or
            Input.Keyboard.isDown(KeyboardKey.up))
        {
            game_state.player_y -= game_state.player_speed * delta_time;
            moved = true;
        }
        if (Input.Keyboard.isDown(KeyboardKey.s) or
            Input.Keyboard.isDown(KeyboardKey.down))
        {
            game_state.player_y += game_state.player_speed * delta_time;
            moved = true;
        }
        if (Input.Keyboard.isDown(KeyboardKey.a) or
            Input.Keyboard.isDown(KeyboardKey.left))
        {
            game_state.player_x -= game_state.player_speed * delta_time;
            moved = true;
        }
        if (Input.Keyboard.isDown(KeyboardKey.d) or
            Input.Keyboard.isDown(KeyboardKey.right))
        {
            game_state.player_x += game_state.player_speed * delta_time;
            moved = true;
        }

        // Keep player in bounds
        game_state.player_x = @max(game_state.player_size, @min(screen_width - game_state.player_size, game_state.player_x));
        game_state.player_y = @max(game_state.player_size, @min(screen_height - game_state.player_size, game_state.player_y));

        // Check collisions with collectible items
        for (&game_state.items) |*item| {
            if (!item.collected) {
                const dx = game_state.player_x - item.x;
                const dy = game_state.player_y - item.y;
                const distance = @sqrt(dx * dx + dy * dy);

                if (distance < game_state.player_size + 15.0) {
                    item.collected = true;
                    game_state.score += 10;
                }
            }
        }

        // Clear background
        engine.clearBackground(engine_mod.Color{ .r = 30, .g = 30, .b = 50, .a = 255 });

        // Draw grid background
        const grid_size: f32 = 50.0;
        var x: f32 = 0;
        while (x < screen_width) : (x += grid_size) {
            Shapes.drawLine(
                @intFromFloat(x),
                0,
                @intFromFloat(x),
                @intFromFloat(screen_height),
                engine_mod.Color{ .r = 40, .g = 40, .b = 60, .a = 255 },
            );
        }
        var y: f32 = 0;
        while (y < screen_height) : (y += grid_size) {
            Shapes.drawLine(
                0,
                @intFromFloat(y),
                @intFromFloat(screen_width),
                @intFromFloat(y),
                engine_mod.Color{ .r = 40, .g = 40, .b = 60, .a = 255 },
            );
        }

        // Draw collectible items
        for (game_state.items) |item| {
            if (!item.collected) {
                // Pulsing animation
                const pulse = @sin(game_state.game_time * 3.0) * 0.2 + 1.0;
                const size: f32 = 15.0 * pulse;
                
                Shapes.drawCircle(
                    @intFromFloat(item.x),
                    @intFromFloat(item.y),
                    size,
                    engine_mod.Color{ .r = 255, .g = 215, .b = 0, .a = 255 },
                );
                Shapes.drawCircleLines(
                    @intFromFloat(item.x),
                    @intFromFloat(item.y),
                    size,
                    engine_mod.Color{ .r = 255, .g = 255, .b = 100, .a = 255 },
                );
            }
        }

        // Draw player (with rotation based on movement)
        const player_color = if (moved)
            engine_mod.Color{ .r = 100, .g = 200, .b = 255, .a = 255 }
        else
            engine_mod.Color{ .r = 150, .g = 150, .b = 255, .a = 255 };

        Shapes.drawCircle(
            @intFromFloat(game_state.player_x),
            @intFromFloat(game_state.player_y),
            game_state.player_size,
            player_color,
        );
        Shapes.drawCircleLines(
            @intFromFloat(game_state.player_x),
            @intFromFloat(game_state.player_y),
            game_state.player_size,
            engine_mod.Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
        );

        // Draw UI
        const ui_bg = engine_mod.Rectangle{
            .x = 10,
            .y = 10,
            .width = 200,
            .height = 100,
        };
        Shapes.drawRectangleRec(ui_bg, engine_mod.Color{ .r = 0, .g = 0, .b = 0, .a = 180 });
        Shapes.drawRectangleLinesEx(ui_bg, 2, engine_mod.Color{ .r = 255, .g = 255, .b = 255, .a = 255 });

        // Draw score
        var score_text: [32:0]u8 = undefined;
        const score_str = try std.fmt.bufPrintZ(&score_text, "Score: {}", .{game_state.score});
        Text.draw(score_str, 20, 20, 20, engine_mod.Color{ .r = 255, .g = 255, .b = 255, .a = 255 });

        // Draw time
        var time_text: [32:0]u8 = undefined;
        const time_str = try std.fmt.bufPrintZ(&time_text, "Time: {d:.1}s", .{game_state.game_time});
        Text.draw(time_str, 20, 45, 20, engine_mod.Color{ .r = 200, .g = 200, .b = 255, .a = 255 });

        // Draw FPS
        Text.drawFPS(20, 70);

        // Draw instructions
        const instructions = "WASD or Arrow Keys to move";
        const text_width = Text.measure(instructions, 16);
        Text.draw(
            instructions,
            @intFromFloat((screen_width - @as(f32, @floatFromInt(text_width))) / 2.0),
            @intFromFloat(screen_height - 30),
            16,
            engine_mod.Color{ .r = 200, .g = 200, .b = 200, .a = 255 },
        );

        // Check win condition
        var all_collected = true;
        for (game_state.items) |item| {
            if (!item.collected) {
                all_collected = false;
                break;
            }
        }

        if (all_collected) {
            const win_text = "YOU WIN!";
            const win_width = Text.measure(win_text, 40);
            Text.draw(
                win_text,
                @intFromFloat((screen_width - @as(f32, @floatFromInt(win_width))) / 2.0),
                @intFromFloat(screen_height / 2.0 - 20),
                40,
                engine_mod.Color{ .r = 0, .g = 255, .b = 0, .a = 255 },
            );
        }

        engine.endDrawing();
    }

    // Cleanup
    Audio.closeDevice();
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
