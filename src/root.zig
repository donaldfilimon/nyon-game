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
pub const sounds = audio.sounds;
pub const ui = @import("ui/ui.zig");
pub const scene = @import("scene/scene.zig");
pub const assets = @import("assets/assets.zig");

// Game modules
pub const physics = @import("physics/physics.zig");
pub const game = @import("game/sandbox.zig");
pub const block_renderer = @import("render/block_renderer.zig");
pub const hud = @import("ui/hud.zig");
pub const inventory_ui = @import("ui/inventory_ui.zig");

// Item and inventory systems
pub const items = @import("game/items.zig");
pub const inventory = @import("game/inventory.zig");
pub const crafting = @import("game/crafting.zig");
pub const save = @import("game/save.zig");
pub const game_config = @import("game/config.zig");

// Entity system for mobs and NPCs
pub const entity = @import("entity/entity.zig");

// World generation modules
pub const world_gen = @import("world/world.zig");
pub const noise = world_gen.noise;
pub const biome = world_gen.biome;
pub const terrain = world_gen.terrain;
pub const weather = world_gen.weather;
pub const chunk_lod = world_gen.chunk_lod;
pub const chunk_manager = world_gen.chunk_manager;

// Weather system types
pub const Weather = world_gen.Weather;
pub const WeatherType = world_gen.WeatherType;
pub const BiomeWeather = world_gen.BiomeWeather;
pub const WeatherAudio = world_gen.WeatherAudio;

// Chunk LOD and streaming types
pub const LODLevel = world_gen.LODLevel;
pub const ChunkLOD = world_gen.ChunkLOD;
pub const RenderDistance = world_gen.RenderDistance;
pub const LODStats = world_gen.LODStats;
pub const ChunkCoord = world_gen.ChunkCoord;
pub const ChunkManager = world_gen.ChunkManager;
pub const ChunkState = world_gen.ChunkState;
pub const ChunkPool = world_gen.ChunkPool;
pub const GreedyMesher = world_gen.GreedyMesher;
pub const OcclusionCuller = world_gen.OcclusionCuller;

// Frustum culling types
pub const Frustum = render.Frustum;
pub const Plane = render.Plane;
pub const FrustumPlane = render.FrustumPlane;
pub const IntersectionResult = render.IntersectionResult;
pub const CullingStats = render.CullingStats;

// Re-export common types
pub const Vec2 = math.Vec2;
pub const Vec3 = math.Vec3;
pub const Vec4 = math.Vec4;
pub const Mat4 = math.Mat4;
pub const Quat = math.Quat;
pub const Color = render.Color;
pub const Entity = ecs.Entity;

// Audio system types
pub const SoundManager = sounds.SoundManager;
pub const SoundEvent = sounds.SoundEvent;
pub const VolumeSettings = sounds.VolumeSettings;

// Entity system types for mobs/NPCs
pub const EntityWorld = entity.EntityWorld;
pub const MobType = entity.MobType;
pub const MobSpawner = entity.MobSpawner;

// Particle system types
pub const ParticleSystem = render.ParticleSystem;
pub const Particle = render.Particle;
pub const ParticlePreset = render.ParticlePreset;
pub const ParticleEmitter = render.ParticleEmitter;

// Water rendering types
pub const Water = render.Water;
pub const WaterRenderer = render.WaterRenderer;
pub const UnderwaterEffects = render.UnderwaterEffects;

// Save system types
pub const SaveSystem = save.SaveSystem;
pub const SaveInfo = save.SaveInfo;
pub const LoadedWorld = save.LoadedWorld;
pub const GameMode = save.GameMode;

// Save menu UI
pub const SaveMenu = ui.SaveMenu;
pub const SaveMenuState = ui.SaveMenuState;

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
        // Connect renderer to window for framebuffer presentation
        self.renderer.setWindowHandle(win);
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

            // Update particles
            self.renderer.updateParticles(@floatCast(self.delta_time));

            // Render frame
            self.renderer.beginFrame();
            self.renderer.renderWorld(&self.world);
            self.renderer.renderParticles();
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
