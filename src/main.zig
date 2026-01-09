//! Nyon Game Engine - Sandbox Game Entry Point
//!
//! A first-person sandbox game with block placement and destruction.
//! Controls:
//!   - WASD: Move
//!   - Mouse: Look around
//!   - Left Click: Place block
//!   - Right Click / Ctrl+Click: Remove block
//!   - 1-9: Select block type
//!   - Scroll: Cycle hotbar
//!   - Shift: Sprint
//!   - Ctrl: Crouch
//!   - Space: Jump
//!   - F3: Toggle debug overlay
//!   - Escape: Quit

const std = @import("std");
const nyon = @import("nyon_game");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.log.info("Nyon Sandbox v{s} starting...", .{nyon.VERSION.string});

    // Initialize engine
    var engine = try nyon.Engine.init(allocator, .{
        .window_width = 1280,
        .window_height = 720,
        .window_title = "Nyon Sandbox",
        .gpu_backend = .software, // Use software renderer for now
    });
    defer engine.deinit();

    // Log GPU info
    if (engine.gpu_context) |ctx| {
        std.log.info("GPU: {s}", .{ctx.device_info.getName()});
    } else {
        std.log.info("Running in software mode", .{});
    }

    // Initialize sandbox game
    var sandbox = try nyon.game.SandboxGame.init(allocator);
    defer sandbox.deinit();

    std.log.info("World generated: {} chunks loaded", .{sandbox.world.chunks.count()});

    // Run game loop
    var timer = std.time.Timer.start() catch {
        std.log.err("Failed to start timer", .{});
        return;
    };

    while (engine.running) {
        const frame_start = timer.read();

        // Poll input
        engine.input_state.poll(engine.window_handle);

        // Check for quit
        if (engine.input_state.shouldQuit() or nyon.window.shouldClose(engine.window_handle)) {
            engine.running = false;
            break;
        }

        // Update sandbox game
        sandbox.update(&engine.input_state, @floatCast(engine.delta_time)) catch |err| {
            std.log.warn("Game update error: {}", .{err});
        };

        // Set camera from player
        const view = sandbox.getViewMatrix();
        const aspect = @as(f32, @floatFromInt(engine.config.window_width)) /
            @as(f32, @floatFromInt(engine.config.window_height));
        const projection = nyon.math.Mat4.perspective(
            nyon.math.radians(70.0),
            aspect,
            0.1,
            1000.0,
        );
        engine.renderer.setCamera(view, projection);

        // Begin frame
        engine.renderer.beginFrame();

        // Render block world
        nyon.block_renderer.renderBlockWorld(
            &engine.renderer,
            &sandbox.world,
            sandbox.player.getEyePosition(),
            4, // Render distance in chunks
        );

        // Render block selection highlight
        if (sandbox.target_block) |target| {
            nyon.block_renderer.renderBlockHighlight(
                &engine.renderer,
                target.pos,
                nyon.render.Color.fromRgba(255, 255, 255, 150),
            );
        }

        // Begin UI frame
        engine.ui_context.beginFrame(
            engine.input_state.mouse_x,
            engine.input_state.mouse_y,
            engine.input_state.mouse_buttons[0],
        );

        // Draw HUD
        nyon.hud.drawHUD(
            &engine.ui_context,
            &sandbox,
            engine.config.window_width,
            engine.config.window_height,
        );

        // End frames
        engine.ui_context.endFrame();
        engine.renderer.endFrame();

        // Calculate delta time
        const frame_end = timer.read();
        engine.delta_time = @as(f64, @floatFromInt(frame_end - frame_start)) / std.time.ns_per_s;
        engine.total_time += engine.delta_time;
        engine.frame_count += 1;
    }

    std.log.info("Game ended. Frames: {}, Avg FPS: {d:.1}", .{
        engine.frame_count,
        if (engine.total_time > 0) @as(f64, @floatFromInt(engine.frame_count)) / engine.total_time else 0,
    });
}

test {
    std.testing.refAllDecls(@This());
}
