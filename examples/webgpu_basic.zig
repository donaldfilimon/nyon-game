//! Basic WebGPU example demonstrating the WebGPU backend
//! This example shows how to initialize and use the WebGPU backend

const std = @import("std");
const nyon_game = @import("nyon_game");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize engine with WebGPU backend
    var engine = try nyon_game.Engine.init(allocator, .{
        .backend = .webgpu,
        .width = 800,
        .height = 600,
        .title = "Nyon Game - WebGPU Backend",
        .target_fps = 60,
        .webgpu = .{
            .debug_mode = true,
            .power_preference = .high_performance,
        },
    });
    defer engine.deinit();

    // Print WebGPU device information
    const device_info = try engine.getWebGpuDeviceInfo();
    std.debug.print("WebGPU Device: {s}\n", .{device_info.device_name});
    std.debug.print("WebGPU Adapter: {s}\n", .{device_info.adapter_name});
    std.debug.print("Backend: {s}\n", .{@tagName(device_info.backend)});
    std.debug.print("Features supported: {d}\n", .{device_info.features.len});

    // Check for specific features
    if (engine.webGpuSupportsFeature(.shader_float16)) {
        std.debug.print("Shader float16 supported\n", .{});
    } else {
        std.debug.print("Shader float16 not supported\n", .{});
    }

    std.debug.print("WebGPU backend initialized successfully!\n", .{});
    std.debug.print("Press Ctrl+C to exit\n", .{});

    // Main loop (placeholder - WebGPU rendering not fully implemented yet)
    while (!engine.shouldClose()) {
        engine.pollEvents();

        // WebGPU rendering would go here
        // For now, just demonstrate the backend is working
        engine.beginDrawing();
        engine.clearBackground(nyon_game.Color{ .r = 50, .g = 50, .b = 100, .a = 255 });
        engine.endDrawing();

        // Exit after a few frames for testing
        if (engine.getTime() catch 0.0 > 2.0) {
            break;
        }
    }

    std.debug.print("WebGPU example completed\n", .{});
}