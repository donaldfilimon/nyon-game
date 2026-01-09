//! Nyon Game Engine - GPU-Accelerated Game Engine
//!
//! A cutting-edge game engine built on Zig's experimental SPIR-V/PTX backend
//! for native GPU compute shader support. This engine leverages Zig 0.16's
//! std library extensively and compiles shaders directly to GPU bytecode.
//!
//! ## Architecture
//!
//! - **GPU Backend**: SPIR-V for Vulkan, PTX for NVIDIA CUDA
//! - **Compute Shaders**: Written in Zig, compiled to GPU bytecode
//! - **Rendering**: Software rasterizer with GPU compute acceleration
//! - **ECS**: Cache-friendly entity-component-system
//! - **Math**: SIMD-optimized vector/matrix operations
//! - **Memory**: Arena allocators, GPU buffer management

const std = @import("std");

// Core modules
pub const math = @import("math/math.zig");
pub const gpu = @import("gpu/gpu.zig");
pub const ecs = @import("ecs/ecs.zig");
pub const render = @import("render/render.zig");
pub const window = @import("platform/window.zig");
pub const input = @import("platform/input.zig");
pub const audio = @import("audio/audio.zig");
pub const ui = @import("ui/ui.zig");
pub const scene = @import("scene/scene.zig");
pub const assets = @import("assets/assets.zig");

// Game modules
pub const physics = @import("physics/physics.zig");
pub const game = @import("game/sandbox.zig");
pub const block_renderer = @import("render/block_renderer.zig");
pub const hud = @import("ui/hud.zig");

// Re-export common types
pub const Vec2 = math.Vec2;
pub const Vec3 = math.Vec3;
pub const Vec4 = math.Vec4;
pub const Mat4 = math.Mat4;
pub const Quat = math.Quat;
pub const Color = render.Color;
pub const Entity = ecs.Entity;

/// Engine configuration
pub const Config = struct {
    window_width: u32 = 1280,
    window_height: u32 = 720,
    window_title: []const u8 = "Nyon Engine",
    vsync: bool = true,
    gpu_backend: gpu.Backend = .spirv_vulkan,
    target_fps: u32 = 60,
    enable_debug: bool = false,
};

/// Main engine instance
pub const Engine = struct {
    allocator: std.mem.Allocator,
    config: Config,
    gpu_context: ?gpu.Context,
    world: ecs.World,
    renderer: render.Renderer,
    window_handle: ?window.Handle,
    input_state: input.State,
    audio_engine: ?audio.Engine,
    ui_context: ui.Context,
    running: bool,
    delta_time: f64,
    total_time: f64,
    frame_count: u64,

    const Self = @This();

    /// Initialize the engine with the given configuration
    pub fn init(allocator: std.mem.Allocator, config: Config) !Self {
        // Initialize GPU context
        const gpu_ctx = gpu.Context.init(allocator, config.gpu_backend) catch |err| blk: {
            std.log.warn("GPU init failed: {}, falling back to software", .{err});
            break :blk null;
        };

        // Create window
        const win = try window.create(config.window_width, config.window_height, config.window_title);

        // Initialize renderer
        const renderer = try render.Renderer.init(allocator, gpu_ctx, config.window_width, config.window_height);

        // Initialize ECS world
        const world = try ecs.World.init(allocator);

        // Initialize audio (optional)
        const audio_eng = audio.Engine.init(allocator) catch |err| blk: {
            std.log.warn("Audio init failed: {}", .{err});
            break :blk null;
        };

        var self = Self{
            .allocator = allocator,
            .config = config,
            .gpu_context = gpu_ctx,
            .world = world,
            .renderer = renderer,
            .window_handle = win,
            .input_state = input.State.init(),
            .audio_engine = audio_eng,
            .ui_context = undefined,
            .running = true,
            .delta_time = 0,
            .total_time = 0,
            .frame_count = 0,
        };
        self.ui_context = ui.Context.init(allocator, &self.renderer);
        return self;
    }

    /// Deinitialize and clean up all engine resources
    pub fn deinit(self: *Self) void {
        if (self.audio_engine) |*ae| ae.deinit();
        self.renderer.deinit();
        self.world.deinit();
        if (self.gpu_context) |*ctx| ctx.deinit();
        if (self.window_handle) |h| window.destroy(h);
    }

    /// Run the main game loop
    pub fn run(self: *Self, update_fn: ?*const fn (*Self) void) void {
        // Bind input state to window for event handling
        if (self.window_handle) |h| {
            window.setUserPointer(h, &self.input_state);
        }

        var timer = std.time.Timer.start() catch return;

        while (self.running) {
            const frame_start = timer.read();

            // Poll input
            self.input_state.poll(self.window_handle);

            // Check for quit
            if (self.input_state.shouldQuit() or window.shouldClose(self.window_handle)) {
                self.running = false;
                break;
            }

            // User update callback
            self.ui_context.beginFrame(self.input_state.mouse_x, self.input_state.mouse_y, self.input_state.mouse_buttons[0]);
            if (update_fn) |f| f(self);

            // Update ECS systems
            self.world.update(self.delta_time);

            // Render frame
            self.renderer.beginFrame();
            self.renderer.renderWorld(&self.world);
            self.ui_context.endFrame();
            self.renderer.endFrame();

            // Calculate delta time
            const frame_end = timer.read();
            self.delta_time = @as(f64, @floatFromInt(frame_end - frame_start)) / std.time.ns_per_s;
            self.total_time += self.delta_time;
            self.frame_count += 1;
        }
    }

    /// Get frames per second
    pub fn getFPS(self: *const Self) f64 {
        if (self.delta_time > 0) {
            return 1.0 / self.delta_time;
        }
        return 0;
    }
};

/// Engine version
pub const VERSION = struct {
    pub const major: u32 = 2;
    pub const minor: u32 = 0;
    pub const patch: u32 = 0;
    pub const string: []const u8 = "2.0.0-gpu";
};

test "engine initialization" {
    const allocator = std.testing.allocator;
    var engine = try Engine.init(allocator, .{});
    defer engine.deinit();

    try std.testing.expect(engine.running);
    try std.testing.expectEqual(@as(u64, 0), engine.frame_count);
}
