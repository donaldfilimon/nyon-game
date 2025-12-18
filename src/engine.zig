const std = @import("std");
const raylib = @import("raylib");
const gpu = std.gpu;

pub const Engine = struct {
    width: u32,
    height: u32,
    title: [:0]const u8,
    graphics_ctx: gpu.GraphicsContext,

    /// Initialize the engine with universal std.gpu support for all platforms including browsers.
    /// This automatically selects the appropriate GPU backend based on the target platform:
    /// - WebGPU for browsers (wasm32)
    /// - Native backends (Vulkan, Metal, DirectX, etc.) for desktop platforms
    pub fn init(engine: *Engine, width: u32, height: u32, title: [:0]const u8) !void {
        engine.width = width;
        engine.height = height;
        engine.title = title;

        // Universal initialization that works across all platforms
        // std.gpu automatically selects the appropriate backend based on the target:
        // - WebGPU for wasm32 (browser targets) - uses browser's canvas context
        // - Native backends (Vulkan/Metal/DirectX) for desktop platforms
        // - OpenGL/ES fallback where available
        //
        // For browser targets, window_handle is not needed as WebGPU uses the
        // browser's canvas context. For native platforms, null can be used for
        // headless rendering, or a valid window handle can be provided if available.
        engine.graphics_ctx = try gpu.GraphicsContext.init(.{
            .window_handle = null, // Universal: works for browsers and headless native
        });
    }

    /// Deinitialize the engine and clean up GPU resources
    pub fn deinit(engine: *Engine) void {
        engine.graphics_ctx.deinit();
    }
};
