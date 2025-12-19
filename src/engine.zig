const std = @import("std");
const raylib = @import("raylib");
const builtin = @import("builtin");

// ============================================================================
// Platform Detection
// ============================================================================

const is_browser = builtin.target.os.tag == .freestanding or builtin.target.os.tag == .wasi;
const glfw_available = !is_browser;

// ============================================================================
// Error Types
// ============================================================================

/// Engine-specific error types
pub const EngineError = error{
    /// Backend is not initialized
    BackendNotInitialized,
    /// Backend is not available on this platform
    BackendNotAvailable,
    /// GLFW backend is not implemented yet
    GlfwBackendNotImplemented,
    /// GLFW is not available on this platform
    GlfwNotAvailable,
    /// Invalid configuration parameters
    InvalidConfig,
};

// ============================================================================
// Conditional Imports
// ============================================================================

// Conditionally import zglfw
const zglfw = if (glfw_available) @import("zglfw") else struct {
    pub const Window = opaque {};
    pub const Monitor = opaque {};
    pub const Cursor = opaque {};
    pub const Error = error{GlfwNotAvailable};
    pub const init = error.GlfwNotAvailable;
    pub const terminate = error.GlfwNotAvailable;
    pub const pollEvents = error.GlfwNotAvailable;
};

// ============================================================================
// Engine
// ============================================================================

/// Universal game engine integrating std.gpu, GLFW, and raylib functionality.
///
/// Supports all platforms including browsers via WebGPU, and native platforms
/// with full low-level control. The engine provides a unified API that abstracts
/// away backend-specific details while allowing access to backend-specific features
/// when needed.
///
/// Example usage:
/// ```zig
/// var engine = try Engine.init(allocator, .{
///     .backend = .raylib,
///     .width = 800,
///     .height = 600,
///     .title = "My Game",
/// });
/// defer engine.deinit();
/// ```
pub const Engine = struct {
    allocator: std.mem.Allocator,
    width: u32,
    height: u32,
    title: [:0]const u8,
    raylib_initialized: bool = false,
    glfw_window: ?*zglfw.Window = null,
    webgpu_initialized: bool = false, // WebGPU backend flag (std.gpu API is experimental)
    target_fps: ?u32 = null,

    // ========================================================================
    // Backend State Helpers
    // ========================================================================

    /// Check if the raylib backend is initialized.
    ///
    /// Returns `true` if raylib backend is active, `false` otherwise.
    pub fn isRaylibInitialized(engine: *const Engine) bool {
        return engine.raylib_initialized;
    }

    /// Check if the GLFW backend is initialized.
    ///
    /// Returns `true` if GLFW backend is active, `false` otherwise.
    pub fn isGlfwInitialized(engine: *const Engine) bool {
        return engine.glfw_window != null;
    }

    /// Check if the WebGPU backend is initialized.
    ///
    /// Returns `true` if WebGPU backend is active, `false` otherwise.
    pub fn isWebGpuInitialized(engine: *const Engine) bool {
        return engine.webgpu_initialized;
    }

    /// Check if any rendering backend is initialized.
    ///
    /// Returns `true` if at least one backend is active, `false` otherwise.
    pub fn isBackendInitialized(engine: *const Engine) bool {
        return engine.raylib_initialized or engine.glfw_window != null or engine.webgpu_initialized;
    }

    // ========================================================================
    // Backend Configuration
    // ========================================================================

    /// Backend type for the engine
    pub const Backend = enum {
        /// Auto-detect: prefer WebGPU on browsers, raylib on native
        auto,
        /// Use WebGPU backend (universal, works on browsers via WebGPU)
        webgpu,
        /// Use GLFW for low-level window/input control (native only)
        glfw,
        /// Use raylib for high-level game development features (native only)
        raylib,
    };

    /// Configuration for engine initialization.
    ///
    /// All fields have sensible defaults. The `backend` field determines which
    /// rendering backend to use. Use `.auto` to let the engine choose the best
    /// backend for the current platform.
    pub const Config = struct {
        /// Backend to use. `.auto` will select the best backend for the platform.
        backend: Backend = .auto,
        /// Window width in pixels. Must be > 0.
        width: u32 = 800,
        /// Window height in pixels. Must be > 0.
        height: u32 = 600,
        /// Window title. Must be a null-terminated string.
        title: [:0]const u8 = "Nyon Game",
        /// Target FPS. Set to `null` to disable FPS limiting.
        target_fps: ?u32 = 60,
        /// Whether the window can be resized by the user.
        resizable: bool = true,
        /// Whether to start in fullscreen mode.
        fullscreen: bool = false,
        /// Whether to enable VSYNC.
        vsync: bool = true,
        /// MSAA samples (0 = disabled, 4 = 4x MSAA, etc.)
        samples: u32 = 0,
    };

    /// Initialize the engine with the specified configuration.
    ///
    /// Validates the configuration and initializes the selected backend.
    /// Returns an error if the configuration is invalid or backend initialization fails.
    ///
    /// **Backend Requirements:**
    /// - `.raylib`: Available on native platforms only
    /// - `.glfw`: Available on native platforms only (not fully implemented)
    /// - `.webgpu`: Available on all platforms (not fully implemented)
    /// - `.auto`: Automatically selects the best available backend
    ///
    /// **Errors:**
    /// - `EngineError.InvalidConfig`: Configuration parameters are invalid
    /// - `EngineError.BackendNotAvailable`: Selected backend is not available
    /// - `EngineError.GlfwBackendNotImplemented`: GLFW backend is not implemented
    pub fn init(allocator: std.mem.Allocator, config: Config) EngineError!Engine {
        // Validate configuration
        if (config.width == 0 or config.height == 0) {
            return EngineError.InvalidConfig;
        }

        var engine = Engine{
            .allocator = allocator,
            .width = config.width,
            .height = config.height,
            .title = config.title,
            .target_fps = config.target_fps,
        };

        // Determine which backend to use
        const backend: Backend = switch (config.backend) {
            .auto => blk: {
                // Auto-detect: prefer WebGPU on browsers, raylib on native
                if (is_browser) {
                    break :blk .webgpu;
                } else {
                    break :blk .raylib;
                }
            },
            else => config.backend,
        };

        // Validate backend availability
        switch (backend) {
            .glfw => {
                if (!glfw_available) {
                    return EngineError.BackendNotAvailable;
                }
            },
            .raylib => {
                if (is_browser) {
                    return EngineError.BackendNotAvailable;
                }
            },
            .webgpu, .auto => {}, // WebGPU and auto are always available
        }

        // Initialize based on selected backend
        // Note: .auto case is already resolved above, so it won't appear here
        switch (backend) {
            .webgpu => try engine.initWebGpuBackend(config),
            .glfw => try engine.initGlfwBackend(config),
            .raylib => try engine.initRaylibBackend(config),
            .auto => unreachable,
        }

        return engine;
    }

    /// Initialize WebGPU backend for universal browser/native support.
    ///
    /// **Note:** std.gpu API is experimental and may change. This is a placeholder
    /// implementation that will be completed when the API stabilizes.
    ///
    /// **Backend Requirements:** Available on all platforms
    fn initWebGpuBackend(engine: *Engine, config: Config) EngineError!void {
        _ = config; // Config options may be used in future
        // TODO: Implement WebGPU backend when std.gpu API stabilizes
        // For now, mark as initialized but don't create context
        engine.webgpu_initialized = true;
        // engine.webgpu_ctx = try gpu.GraphicsContext.init(.{
        //     .window_handle = null, // Browser handles window, or null for headless
        // });
    }

    /// Initialize GLFW backend for low-level control.
    ///
    /// **Note:** zglfw API integration is a work in progress. The GLFW wrapper
    /// namespace provides full API access via `Engine.Glfw.*` for direct GLFW usage.
    ///
    /// **Backend Requirements:** Native platforms only
    ///
    /// **Errors:**
    /// - `EngineError.GlfwNotAvailable`: GLFW is not available on this platform
    /// - `EngineError.GlfwBackendNotImplemented`: GLFW backend is not fully implemented
    fn initGlfwBackend(engine: *Engine, config: Config) EngineError!void {
        if (!glfw_available) {
            return EngineError.GlfwNotAvailable;
        }

        // TODO: Implement full GLFW backend initialization
        // The zglfw API structure needs to be verified and integrated properly
        // For now, users can access GLFW directly via Engine.Glfw.* namespace
        _ = engine;
        _ = config;

        // Placeholder - actual implementation needed:
        // try zglfw.init();
        // const window = try zglfw.createWindow(...);
        // engine.glfw_window = window;
        return EngineError.GlfwBackendNotImplemented;
    }

    /// Initialize raylib backend for high-level game development features.
    ///
    /// **Backend Requirements:** Native platforms only
    ///
    /// This is the recommended backend for most game development tasks as it
    /// provides a complete, high-level API for graphics, audio, and input.
    fn initRaylibBackend(engine: *Engine, config: Config) EngineError!void {
        // Configure raylib flags
        const flags = raylib.ConfigFlags{
            .fullscreen_mode = config.fullscreen,
            .window_resizable = config.resizable,
            .vsync_hint = config.vsync,
            .msaa_4x_hint = config.samples > 0,
        };

        raylib.setConfigFlags(flags);
        raylib.initWindow(@intCast(config.width), @intCast(config.height), config.title);
        engine.raylib_initialized = true;

        if (config.target_fps) |fps| {
            raylib.setTargetFPS(@intCast(fps));
        }
    }

    /// Deinitialize the engine and clean up all resources.
    ///
    /// This function safely cleans up all initialized backends and releases
    /// any allocated resources. It is safe to call even if initialization failed.
    ///
    /// **Note:** This function should be called when the engine is no longer needed,
    /// typically using `defer` to ensure cleanup happens even if errors occur.
    pub fn deinit(engine: *Engine) void {
        // Clean up raylib if used
        if (engine.isRaylibInitialized()) {
            raylib.closeWindow();
            engine.raylib_initialized = false;
        }

        // Clean up GLFW if used
        if (engine.isGlfwInitialized()) {
            if (glfw_available) {
                // TODO: Implement proper GLFW window cleanup when backend is implemented
                // window.destroy();
                // zglfw.terminate();
            }
            engine.glfw_window = null;
        }

        // Clean up WebGPU if used
        if (engine.isWebGpuInitialized()) {
            // TODO: Deinitialize WebGPU context when API stabilizes
            // if (engine.webgpu_ctx) |ctx| {
            //     ctx.deinit();
            // }
            engine.webgpu_initialized = false;
        }
    }

    /// Check if the window should close.
    ///
    /// **Backend Requirements:** Requires an initialized window backend (raylib or GLFW)
    ///
    /// Returns `true` if the user has requested to close the window (e.g., clicked the X button).
    /// Returns `false` if no window backend is initialized or in headless mode.
    pub fn shouldClose(engine: *const Engine) bool {
        if (engine.isRaylibInitialized()) {
            return raylib.windowShouldClose();
        }
        if (engine.isGlfwInitialized()) {
            if (glfw_available) {
                // TODO: Implement GLFW shouldClose check when backend is implemented
                // return window.shouldClose();
                return false;
            }
        }
        // No window initialized or headless mode
        return false;
    }

    /// Poll for window and input events.
    ///
    /// **Backend Requirements:**
    /// - GLFW: Required to be called each frame
    /// - raylib: Events are handled automatically, but calling this is safe
    ///
    /// This function should be called once per frame before processing input
    /// or drawing. For raylib, this is optional as events are handled automatically.
    pub fn pollEvents(engine: *Engine) void {
        if (engine.isGlfwInitialized()) {
            if (glfw_available) {
                // TODO: Implement GLFW event polling when backend is implemented
                // zglfw.pollEvents();
            }
        }
        // Raylib handles events automatically in its drawing functions
    }

    /// Begin drawing a new frame.
    ///
    /// **Backend Requirements:** Requires raylib backend for full functionality
    ///
    /// This function must be called before any drawing operations. It prepares
    /// the rendering context for drawing. Must be paired with `endDrawing()`.
    ///
    /// **Note:** For GLFW/WebGPU backends, drawing is handled differently and
    /// this function may be a no-op.
    pub fn beginDrawing(engine: *Engine) void {
        if (engine.isRaylibInitialized()) {
            raylib.beginDrawing();
        }
        // For GLFW/GPU backends, drawing is handled differently
    }

    /// End drawing the current frame and present it.
    ///
    /// **Backend Requirements:** Requires an initialized rendering backend
    ///
    /// This function must be called after all drawing operations are complete.
    /// It presents the rendered frame to the screen. Must be paired with `beginDrawing()`.
    pub fn endDrawing(engine: *Engine) void {
        if (engine.isRaylibInitialized()) {
            raylib.endDrawing();
        } else if (engine.isGlfwInitialized()) {
            if (glfw_available) {
                // TODO: Implement GLFW buffer swap when backend is implemented
                // window.swapBuffers();
            }
        } else if (engine.isWebGpuInitialized()) {
            // TODO: Present WebGPU frame when API stabilizes
        }
    }

    /// Clear the background with the specified color.
    ///
    /// **Backend Requirements:** Requires raylib backend for full functionality
    ///
    /// Clears the entire screen with the given color. This should typically be
    /// called at the start of each frame before drawing.
    ///
    /// **Note:** For GLFW/WebGPU backends, this may be a no-op as clearing
    /// is handled differently.
    pub fn clearBackground(engine: *Engine, color: raylib.Color) void {
        if (engine.isRaylibInitialized()) {
            raylib.clearBackground(color);
        } else if (engine.isWebGpuInitialized()) {
            // TODO: Implement WebGPU clear when std.gpu API stabilizes
            // No operation needed for WebGPU backend
        } else {
            // GLFW backend requires manual OpenGL/Vulkan clearing
            // No operation needed for GLFW backend
        }
    }

    /// Get the current window size in pixels.
    ///
    /// **Backend Requirements:** Works with all backends
    ///
    /// Returns the current window dimensions. For raylib, this reflects the
    /// actual window size (which may differ from the initial size if resizable).
    /// For other backends, returns the configured size.
    pub fn getWindowSize(engine: *const Engine) struct { width: u32, height: u32 } {
        if (engine.isRaylibInitialized()) {
            return .{
                .width = @intCast(raylib.getScreenWidth()),
                .height = @intCast(raylib.getScreenHeight()),
            };
        }
        if (engine.isGlfwInitialized()) {
            if (glfw_available) {
                // TODO: Implement GLFW window size retrieval when backend is implemented
                // const size = window.getSize();
                // return .{ .width = @intCast(size[0]), .height = @intCast(size[1]) };
            }
        }
        // For WebGPU or uninitialized backends, return configured size
        return .{ .width = engine.width, .height = engine.height };
    }

    /// Set the target frames per second.
    ///
    /// **Backend Requirements:** Fully supported by raylib backend only
    ///
    /// Limits the frame rate to the specified FPS. Set to 0 to disable limiting.
    /// For GLFW/WebGPU backends, this is stored but not actively enforced.
    pub fn setTargetFPS(engine: *Engine, fps: u32) void {
        engine.target_fps = fps;
        if (engine.isRaylibInitialized()) {
            raylib.setTargetFPS(@intCast(fps));
        }
        // GLFW doesn't have built-in FPS limiting
    }

    /// Get the current frames per second.
    ///
    /// **Backend Requirements:** Requires raylib backend
    ///
    /// Returns the current FPS from the raylib backend.
    ///
    /// **Errors:**
    /// - `EngineError.BackendNotInitialized`: raylib backend is not initialized
    ///
    /// **Example:**
    /// ```zig
    /// const fps = try engine.getFPS();
    /// std.debug.print("Current FPS: {}\n", .{fps});
    /// ```
    pub fn getFPS(engine: *const Engine) EngineError!u32 {
        if (!engine.isRaylibInitialized()) {
            return EngineError.BackendNotInitialized;
        }
        return @intCast(raylib.getFPS());
    }

    /// Get the time elapsed since the last frame in seconds.
    ///
    /// **Backend Requirements:** Requires raylib backend
    ///
    /// Returns the delta time between frames. This is useful for frame-rate
    /// independent movement and animations.
    ///
    /// **Errors:**
    /// - `EngineError.BackendNotInitialized`: raylib backend is not initialized
    ///
    /// **Example:**
    /// ```zig
    /// const delta_time = try engine.getFrameTime();
    /// player.position += player.velocity * delta_time;
    /// ```
    pub fn getFrameTime(engine: *const Engine) EngineError!f32 {
        if (!engine.isRaylibInitialized()) {
            return EngineError.BackendNotInitialized;
        }
        return raylib.getFrameTime();
    }

    /// Get the time elapsed since engine initialization in seconds.
    ///
    /// **Backend Requirements:** Requires raylib backend
    ///
    /// Returns the total time since the engine was initialized. Useful for
    /// animations and game timing.
    ///
    /// **Errors:**
    /// - `EngineError.BackendNotInitialized`: raylib backend is not initialized
    ///
    /// **Example:**
    /// ```zig
    /// const elapsed = try engine.getTime();
    /// const animation_frame = @as(u32, @intFromFloat(elapsed * 10.0)) % 4;
    /// ```
    pub fn getTime(engine: *const Engine) EngineError!f64 {
        if (!engine.isRaylibInitialized()) {
            return EngineError.BackendNotInitialized;
        }
        return raylib.getTime();
    }
};

// ============================================================================
// Raylib API Re-exports
// ============================================================================
//
// All raylib types, constants, and functions are re-exported here for
// convenient access. They are organized into logical sections below.
//
// ============================================================================
// Raylib Types
// ============================================================================

pub const Color = raylib.Color;
pub const Vector2 = raylib.Vector2;
pub const Vector3 = raylib.Vector3;
pub const Vector4 = raylib.Vector4;
pub const Rectangle = raylib.Rectangle;
pub const Image = raylib.Image;
pub const Texture = raylib.Texture;
pub const Texture2D = raylib.Texture2D;
pub const RenderTexture = raylib.RenderTexture;
pub const RenderTexture2D = raylib.RenderTexture2D;
pub const NPatchInfo = raylib.NPatchInfo;
pub const GlyphInfo = raylib.GlyphInfo;
pub const Font = raylib.Font;
pub const Camera3D = raylib.Camera3D;
pub const Camera = raylib.Camera;
pub const Camera2D = raylib.Camera2D;
pub const Mesh = raylib.Mesh;
pub const Shader = raylib.Shader;
pub const MaterialMap = raylib.MaterialMap;
pub const Material = raylib.Material;
pub const Transform = raylib.Transform;
pub const BoneInfo = raylib.BoneInfo;
pub const Model = raylib.Model;
pub const ModelAnimation = raylib.ModelAnimation;
pub const Ray = raylib.Ray;
pub const RayCollision = raylib.RayCollision;
pub const BoundingBox = raylib.BoundingBox;
pub const Wave = raylib.Wave;
pub const AudioStream = raylib.AudioStream;
pub const Sound = raylib.Sound;
pub const Music = raylib.Music;
pub const VrDeviceInfo = raylib.VrDeviceInfo;
pub const VrStereoConfig = raylib.VrStereoConfig;
pub const FilePathList = raylib.FilePathList;
pub const AutomationEvent = raylib.AutomationEvent;
pub const AutomationEventList = raylib.AutomationEventList;
pub const ConfigFlags = raylib.ConfigFlags;
pub const TraceLogLevel = raylib.TraceLogLevel;
pub const KeyboardKey = raylib.KeyboardKey;
pub const MouseButton = raylib.MouseButton;
pub const MouseCursor = raylib.MouseCursor;
pub const GamepadButton = raylib.GamepadButton;
pub const GamepadAxis = raylib.GamepadAxis;
pub const MaterialMapIndex = raylib.MaterialMapIndex;
pub const ShaderLocationIndex = raylib.ShaderLocationIndex;
pub const ShaderUniformDataType = raylib.ShaderUniformDataType;
pub const ShaderAttribute = raylib.ShaderAttribute;
pub const PixelFormat = raylib.PixelFormat;
pub const TextureFilter = raylib.TextureFilter;
pub const TextureWrap = raylib.TextureWrap;
pub const CubemapLayout = raylib.CubemapLayout;
pub const FontType = raylib.FontType;
pub const BlendMode = raylib.BlendMode;
pub const Gesture = raylib.Gesture;
pub const CameraMode = raylib.CameraMode;
pub const CameraProjection = raylib.CameraProjection;
pub const NPatchType = raylib.NPatchType;
pub const Quaternion = raylib.Quaternion;
pub const Matrix = raylib.Matrix;
pub const RaylibError = raylib.RaylibError;

// Re-export raylib constants
pub const RAYLIB_VERSION_MAJOR = raylib.RAYLIB_VERSION_MAJOR;
pub const RAYLIB_VERSION_MINOR = raylib.RAYLIB_VERSION_MINOR;
pub const RAYLIB_VERSION_PATCH = raylib.RAYLIB_VERSION_PATCH;
pub const RAYLIB_VERSION = raylib.RAYLIB_VERSION;
pub const MAX_TOUCH_POINTS = raylib.MAX_TOUCH_POINTS;
pub const MAX_MATERIAL_MAPS = raylib.MAX_MATERIAL_MAPS;
pub const MAX_SHADER_LOCATIONS = raylib.MAX_SHADER_LOCATIONS;

// ============================================================================
// Raylib Function Namespaces
// ============================================================================
//
// Raylib functions are organized into logical namespaces for better
// discoverability and organization. Each namespace groups related functionality.
//

// ============================================================================
// Window Management
// ============================================================================

pub const Window = struct {
    pub const init = raylib.initWindow;
    pub const close = raylib.closeWindow;
    pub const shouldClose = raylib.windowShouldClose;
    pub const isReady = raylib.isWindowReady;
    pub const isFullscreen = raylib.isWindowFullscreen;
    pub const isHidden = raylib.isWindowHidden;
    pub const isMinimized = raylib.isWindowMinimized;
    pub const isMaximized = raylib.isWindowMaximized;
    pub const isFocused = raylib.isWindowFocused;
    pub const isResized = raylib.isWindowResized;
    pub const isState = raylib.isWindowState;
    pub const setState = raylib.setWindowState;
    pub const clearState = raylib.clearWindowState;
    pub const toggleFullscreen = raylib.toggleFullscreen;
    pub const toggleBorderlessWindowed = raylib.toggleBorderlessWindowed;
    pub const maximize = raylib.maximizeWindow;
    pub const minimize = raylib.minimizeWindow;
    pub const restore = raylib.restoreWindow;
    pub const setIcon = raylib.setWindowIcon;
    pub const setIcons = raylib.setWindowIcons;
    pub const setTitle = raylib.setWindowTitle;
    pub const setPosition = raylib.setWindowPosition;
    pub const setMonitor = raylib.setWindowMonitor;
    pub const setMinSize = raylib.setWindowMinSize;
    pub const setMaxSize = raylib.setWindowMaxSize;
    pub const setSize = raylib.setWindowSize;
    pub const setOpacity = raylib.setWindowOpacity;
    pub const setFocused = raylib.setWindowFocused;
    pub const getHandle = raylib.getWindowHandle;
    pub const getScreenWidth = raylib.getScreenWidth;
    pub const getScreenHeight = raylib.getScreenHeight;
    pub const getRenderWidth = raylib.getRenderWidth;
    pub const getRenderHeight = raylib.getRenderHeight;
    pub const getPosition = raylib.getWindowPosition;
    pub const getScaleDPI = raylib.getWindowScaleDPI;
};

// ============================================================================
// Monitor & Cursor Management
// ============================================================================

pub const Monitor = struct {
    pub const getCount = raylib.getMonitorCount;
    pub const getCurrent = raylib.getCurrentMonitor;
    pub const getPosition = raylib.getMonitorPosition;
    pub const getWidth = raylib.getMonitorWidth;
    pub const getHeight = raylib.getMonitorHeight;
    pub const getPhysicalWidth = raylib.getMonitorPhysicalWidth;
    pub const getPhysicalHeight = raylib.getMonitorPhysicalHeight;
    pub const getRefreshRate = raylib.getMonitorRefreshRate;
    pub const getName = raylib.getMonitorName;
};

pub const Cursor = struct {
    pub const show = raylib.showCursor;
    pub const hide = raylib.hideCursor;
    pub const isHidden = raylib.isCursorHidden;
    pub const enable = raylib.enableCursor;
    pub const disable = raylib.disableCursor;
    pub const isOnScreen = raylib.isCursorOnScreen;
    pub const set = raylib.setMouseCursor;
};

/// Drawing mode management functions.
///
/// **Backend Requirements:** Requires raylib backend
///
/// This namespace provides functions for managing different drawing modes such as
/// 2D mode, 3D mode, texture mode, shader mode, and blend modes.
pub const Drawing = struct {
    pub const begin = raylib.beginDrawing;
    pub const end = raylib.endDrawing;
    pub const clearBackground = raylib.clearBackground;
    pub const beginMode2D = raylib.beginMode2D;
    pub const endMode2D = raylib.endMode2D;
    pub const beginMode3D = raylib.beginMode3D;
    pub const endMode3D = raylib.endMode3D;
    pub const beginTextureMode = raylib.beginTextureMode;
    pub const endTextureMode = raylib.endTextureMode;
    pub const beginShaderMode = raylib.beginShaderMode;
    pub const endShaderMode = raylib.endShaderMode;
    pub const beginBlendMode = raylib.beginBlendMode;
    pub const endBlendMode = raylib.endBlendMode;
    pub const beginScissorMode = raylib.beginScissorMode;
    pub const endScissorMode = raylib.endScissorMode;
    pub const beginVrStereoMode = raylib.beginVrStereoMode;
    pub const endVrStereoMode = raylib.endVrStereoMode;
};

/// 2D and 3D shape drawing functions.
///
/// **Backend Requirements:** Requires raylib backend
///
/// This namespace provides functions for drawing various shapes including
/// circles, rectangles, lines, polygons, and 3D primitives. All drawing
/// functions should be called between `Engine.beginDrawing()` and `Engine.endDrawing()`.
pub const Shapes = struct {
    pub const drawPixel = raylib.drawPixel;
    pub const drawPixelV = raylib.drawPixelV;
    pub const drawLine = raylib.drawLine;
    pub const drawLineV = raylib.drawLineV;
    pub const drawLineEx = raylib.drawLineEx;
    pub const drawLineBezier = raylib.drawLineBezier;
    pub const drawLineDashed = raylib.drawLineDashed;
    pub const drawLineStrip = raylib.drawLineStrip;
    pub const drawCircle = raylib.drawCircle;
    pub const drawCircleSector = raylib.drawCircleSector;
    pub const drawCircleSectorLines = raylib.drawCircleSectorLines;
    pub const drawCircleGradient = raylib.drawCircleGradient;
    pub const drawCircleV = raylib.drawCircleV;
    pub const drawCircleLines = raylib.drawCircleLines;
    pub const drawCircleLinesV = raylib.drawCircleLinesV;
    pub const drawEllipse = raylib.drawEllipse;
    pub const drawEllipseV = raylib.drawEllipseV;
    pub const drawEllipseLines = raylib.drawEllipseLines;
    pub const drawEllipseLinesV = raylib.drawEllipseLinesV;
    pub const drawRing = raylib.drawRing;
    pub const drawRingLines = raylib.drawRingLines;
    pub const drawRectangle = raylib.drawRectangle;
    pub const drawRectangleV = raylib.drawRectangleV;
    pub const drawRectangleRec = raylib.drawRectangleRec;
    pub const drawRectanglePro = raylib.drawRectanglePro;
    pub const drawRectangleGradientV = raylib.drawRectangleGradientV;
    pub const drawRectangleGradientH = raylib.drawRectangleGradientH;
    pub const drawRectangleGradientEx = raylib.drawRectangleGradientEx;
    pub const drawRectangleLines = raylib.drawRectangleLines;
    pub const drawRectangleLinesEx = raylib.drawRectangleLinesEx;
    pub const drawRectangleRounded = raylib.drawRectangleRounded;
    pub const drawRectangleRoundedLines = raylib.drawRectangleRoundedLines;
    pub const drawRectangleRoundedLinesEx = raylib.drawRectangleRoundedLinesEx;
    pub const drawTriangle = raylib.drawTriangle;
    pub const drawTriangleLines = raylib.drawTriangleLines;
    pub const drawPoly = raylib.drawPoly;
    pub const drawPolyLines = raylib.drawPolyLines;
    pub const drawPolyLinesEx = raylib.drawPolyLinesEx;
    pub const drawSplineLinear = raylib.drawSplineLinear;
    pub const drawSplineBasis = raylib.drawSplineBasis;
    pub const drawSplineCatmullRom = raylib.drawSplineCatmullRom;
    pub const drawSplineBezierQuadratic = raylib.drawSplineBezierQuadratic;
    pub const drawSplineBezierCubic = raylib.drawSplineBezierCubic;
    pub const drawSplineSegmentLinear = raylib.drawSplineSegmentLinear;
    pub const drawSplineSegmentBasis = raylib.drawSplineSegmentBasis;
    pub const drawSplineSegmentCatmullRom = raylib.drawSplineSegmentCatmullRom;
    pub const drawSplineSegmentBezierQuadratic = raylib.drawSplineSegmentBezierQuadratic;
    pub const drawSplineSegmentBezierCubic = raylib.drawSplineSegmentBezierCubic;
    pub const drawLine3D = raylib.drawLine3D;
    pub const drawPoint3D = raylib.drawPoint3D;
    pub const drawCircle3D = raylib.drawCircle3D;
    pub const drawTriangle3D = raylib.drawTriangle3D;
    pub const drawTriangleStrip3D = raylib.drawTriangleStrip3D;
    pub const drawCube = raylib.drawCube;
    pub const drawCubeV = raylib.drawCubeV;
    pub const drawCubeWires = raylib.drawCubeWires;
    pub const drawCubeWiresV = raylib.drawCubeWiresV;
    pub const drawSphere = raylib.drawSphere;
    pub const drawSphereEx = raylib.drawSphereEx;
    pub const drawSphereWires = raylib.drawSphereWires;
    pub const drawCylinder = raylib.drawCylinder;
    pub const drawCylinderEx = raylib.drawCylinderEx;
    pub const drawCylinderWires = raylib.drawCylinderWires;
    pub const drawCylinderWiresEx = raylib.drawCylinderWiresEx;
    pub const drawCapsule = raylib.drawCapsule;
    pub const drawCapsuleWires = raylib.drawCapsuleWires;
    pub const drawPlane = raylib.drawPlane;
    pub const drawRay = raylib.drawRay;
    pub const drawGrid = raylib.drawGrid;
};

// ============================================================================
// Texture Management
// ============================================================================

pub const Textures = struct {
    pub const load = raylib.loadTexture;
    pub const loadFromImage = raylib.loadTextureFromImage;
    pub const loadCubemap = raylib.loadTextureCubemap;
    pub const unload = raylib.unloadTexture;
    pub const update = raylib.updateTexture;
    pub const updateRec = raylib.updateTextureRec;
    pub const genMipmaps = raylib.genTextureMipmaps;
    pub const setFilter = raylib.setTextureFilter;
    pub const setWrap = raylib.setTextureWrap;
    pub const draw = raylib.drawTexture;
    pub const drawV = raylib.drawTextureV;
    pub const drawEx = raylib.drawTextureEx;
    pub const drawRec = raylib.drawTextureRec;
    pub const drawPro = raylib.drawTexturePro;
    pub const drawNPatch = raylib.drawTextureNPatch;
};

// ============================================================================
// Image Processing
// ============================================================================

pub const Images = struct {
    pub const load = raylib.loadImage;
    pub const loadRaw = raylib.loadImageRaw;
    pub const loadAnim = raylib.loadImageAnim;
    pub const loadFromMemory = raylib.loadImageFromMemory;
    pub const loadFromTexture = raylib.loadImageFromTexture;
    pub const loadFromScreen = raylib.loadImageFromScreen;
    pub const unload = raylib.unloadImage;
    pub const exportImage = raylib.exportImage;
    pub const exportToMemory = raylib.exportImageToMemory;
    pub const exportAsCode = raylib.exportImageAsCode;
    pub const genColor = raylib.genImageColor;
    pub const genGradientLinear = raylib.genImageGradientLinear;
    pub const genGradientRadial = raylib.genImageGradientRadial;
    pub const genGradientSquare = raylib.genImageGradientSquare;
    pub const genChecked = raylib.genImageChecked;
    pub const genWhiteNoise = raylib.genImageWhiteNoise;
    pub const genPerlinNoise = raylib.genImagePerlinNoise;
    pub const genCellular = raylib.genImageCellular;
    pub const genText = raylib.genImageText;
    pub const copy = raylib.imageCopy;
    pub const copyRec = raylib.imageFromImage;
    pub const setFormat = raylib.imageFormat;
    pub const toPOT = raylib.imageToPOT;
    pub const crop = raylib.imageCrop;
    pub const alphaCrop = raylib.imageAlphaCrop;
    pub const alphaClear = raylib.imageAlphaClear;
    pub const alphaMask = raylib.imageAlphaMask;
    pub const alphaPremultiply = raylib.imageAlphaPremultiply;
    pub const blurGaussian = raylib.imageBlurGaussian;
    pub const resize = raylib.imageResize;
    pub const resizeNN = raylib.imageResizeNN;
    pub const resizeCanvas = raylib.imageResizeCanvas;
    pub const mipmaps = raylib.imageMipmaps;
    pub const dither = raylib.imageDither;
    pub const flipVertical = raylib.imageFlipVertical;
    pub const flipHorizontal = raylib.imageFlipHorizontal;
    pub const rotate = raylib.imageRotate;
    pub const rotateCW = raylib.imageRotateCW;
    pub const rotateCCW = raylib.imageRotateCCW;
    pub const tint = raylib.imageColorTint;
    pub const invert = raylib.imageColorInvert;
    pub const grayscale = raylib.imageColorGrayscale;
    pub const contrast = raylib.imageColorContrast;
    pub const brightness = raylib.imageColorBrightness;
    pub const replaceColor = raylib.imageColorReplace;
    pub const getAlphaBorder = raylib.getImageAlphaBorder;
    pub const getColor = raylib.getImageColor;
    pub const clearBackground = raylib.imageClearBackground;
    pub const drawPixel = raylib.imageDrawPixel;
    pub const drawPixelV = raylib.imageDrawPixelV;
    pub const drawLine = raylib.imageDrawLine;
    pub const drawLineV = raylib.imageDrawLineV;
    pub const drawCircle = raylib.imageDrawCircle;
    pub const drawCircleV = raylib.imageDrawCircleV;
    pub const drawCircleLines = raylib.imageDrawCircleLines;
    pub const drawCircleLinesV = raylib.imageDrawCircleLinesV;
    pub const drawRectangle = raylib.imageDrawRectangle;
    pub const drawRectangleV = raylib.imageDrawRectangleV;
    pub const drawRectangleRec = raylib.imageDrawRectangleRec;
    pub const drawRectangleLines = raylib.imageDrawRectangleLines;
    pub const drawTriangle = raylib.imageDrawTriangle;
    pub const drawTriangleEx = raylib.imageDrawTriangleEx;
    pub const drawTriangleLines = raylib.imageDrawTriangleLines;
    pub const drawTriangleFan = raylib.imageDrawTriangleFan;
    pub const drawTriangleStrip = raylib.imageDrawTriangleStrip;
    pub const draw = raylib.imageDraw;
    pub const drawText = raylib.imageDrawText;
    pub const drawTextEx = raylib.imageDrawTextEx;
    pub const loadColors = raylib.loadImageColors;
    pub const unloadColors = raylib.unloadImageColors;
    pub const loadPalette = raylib.loadImagePalette;
    pub const unloadPalette = raylib.unloadImagePalette;
};

/// Text rendering and manipulation functions.
///
/// **Backend Requirements:** Requires raylib backend
///
/// This namespace provides functions for drawing text, measuring text dimensions,
/// and manipulating text strings. Text drawing functions should be called between
/// `Engine.beginDrawing()` and `Engine.endDrawing()`.
pub const Text = struct {
    pub const draw = raylib.drawText;
    pub const drawEx = raylib.drawTextEx;
    pub const drawPro = raylib.drawTextPro;
    pub const drawCodepoint = raylib.drawTextCodepoint;
    pub const drawCodepoints = raylib.drawTextCodepoints;
    pub const drawFPS = raylib.drawFPS;
    pub const setLineSpacing = raylib.setTextLineSpacing;
    pub const measure = raylib.measureText;
    pub const measureEx = raylib.measureTextEx;
    pub const getGlyphIndex = raylib.getGlyphIndex;
    pub const getGlyphInfo = raylib.getGlyphInfo;
    pub const getGlyphAtlasRec = raylib.getGlyphAtlasRec;
    pub const format = raylib.textFormat;
    pub const join = raylib.textJoin;
    pub const split = raylib.textSplit;
    pub const append = raylib.textAppend;
    pub const findIndex = raylib.textFindIndex;
    pub const toUpper = raylib.textToUpper;
    pub const toLower = raylib.textToLower;
    pub const toPascal = raylib.textToPascal;
    pub const toSnake = raylib.textToSnake;
    pub const toCamel = raylib.textToCamel;
    pub const toInteger = raylib.textToInteger;
    pub const toFloat = raylib.textToFloat;
    pub const copy = raylib.textCopy;
    pub const isEqual = raylib.textIsEqual;
    pub const length = raylib.textLength;
    pub const subtext = raylib.textSubtext;
    pub const removeSpaces = raylib.textRemoveSpaces;
    pub const getBetween = raylib.getTextBetween;
    pub const replace = raylib.textReplace;
    pub const replaceBetween = raylib.textReplaceBetween;
    pub const insert = raylib.textInsert;
    pub const loadCodepoints = raylib.loadCodepoints;
    pub const unloadCodepoints = raylib.unloadCodepoints;
    pub const getCodepointCount = raylib.getCodepointCount;
    pub const getCodepoint = raylib.getCodepoint;
    pub const getCodepointNext = raylib.getCodepointNext;
    pub const getCodepointPrevious = raylib.getCodepointPrevious;
    pub const codepointToUTF8 = raylib.codepointToUTF8;
    pub const loadUTF8 = raylib.loadUTF8;
    pub const unloadUTF8 = raylib.unloadUTF8;
    pub const loadLines = raylib.loadTextLines;
    pub const unloadLines = raylib.unloadTextLines;
};

// ============================================================================
// 3D Models & Meshes
// ============================================================================

pub const Models = struct {
    pub const load = raylib.loadModel;
    pub const loadFromMesh = raylib.loadModelFromMesh;
    pub const unload = raylib.unloadModel;
    pub const getBoundingBox = raylib.getModelBoundingBox;
    pub const draw = raylib.drawModel;
    pub const drawEx = raylib.drawModelEx;
    pub const drawWires = raylib.drawModelWires;
    pub const drawWiresEx = raylib.drawModelWiresEx;
    pub const drawPoints = raylib.drawModelPoints;
    pub const drawPointsEx = raylib.drawModelPointsEx;
    pub const loadAnimations = raylib.loadModelAnimations;
    pub const updateAnimation = raylib.updateModelAnimation;
    pub const updateAnimationBones = raylib.updateModelAnimationBones;
    pub const unloadAnimation = raylib.unloadModelAnimation;
    pub const unloadAnimations = raylib.unloadModelAnimations;
    pub const isAnimationValid = raylib.isModelAnimationValid;

    /// Load a 3D model from .obj file
    /// Raylib automatically detects format from file extension
    pub fn loadObj(fileName: [:0]const u8) raylib.Model {
        return raylib.loadModel(fileName);
    }

    /// Load a 3D model from .gltf or .glb file
    /// Raylib automatically detects format from file extension
    pub fn loadGltf(fileName: [:0]const u8) raylib.Model {
        return raylib.loadModel(fileName);
    }

    /// Load model with materials and animations for advanced usage
    pub fn loadAdvanced(allocator: std.mem.Allocator, fileName: [:0]const u8) !struct { model: raylib.Model, materials: []raylib.Material, animations: []raylib.ModelAnimation } {
        var model = raylib.loadModel(fileName);
        errdefer raylib.unloadModel(model);

        // Load materials
        const materials = try allocator.alloc(raylib.Material, @intCast(raylib.getModelMaterialCount(model)));
        errdefer allocator.free(materials);

        // Copy materials from model
        for (materials, 0..) |*mat, i| {
            mat.* = model.materials[i];
        }

        // Load animations
        var anim_count: c_uint = 0;
        var animations: []raylib.ModelAnimation = &[_]raylib.ModelAnimation{};

        // Try to load animations (may fail if none exist)
        const temp_animations = raylib.loadModelAnimations(fileName, &anim_count) catch null;
        if (temp_animations != null) {
            animations = try allocator.alloc(raylib.ModelAnimation, @intCast(anim_count));
            errdefer allocator.free(animations);

            for (animations, 0..) |*anim, i| {
                anim.* = temp_animations[i];
            }
            raylib.unloadModelAnimations(temp_animations, anim_count);
        }

        return .{
            .model = model,
            .materials = materials,
            .animations = animations,
        };
    }

    /// Create a model from procedural geometry
    pub fn createProcedural(params: union(enum) {
        cube: struct { width: f32, height: f32, depth: f32 },
        sphere: struct { radius: f32, rings: i32 = 16, slices: i32 = 16 },
        cylinder: struct { radius: f32, height: f32, slices: i32 = 16 },
        plane: struct { width: f32, height: f32, res_x: i32 = 1, res_z: i32 = 1 },
        torus: struct { radius: f32, size: f32, rad_seg: i32 = 16, sides: i32 = 16 },
        knot: struct { radius: f32, size: f32, rad_seg: i32 = 16, sides: i32 = 16 },
        heightmap: struct { heightmap: raylib.Image, size: raylib.Vector3 },
    }) !raylib.Model {
        const mesh = switch (params) {
            .cube => |p| raylib.genMeshCube(p.width, p.height, p.depth),
            .sphere => |p| raylib.genMeshSphere(p.radius, p.rings, p.slices),
            .cylinder => |p| raylib.genMeshCylinder(p.radius, p.height, p.slices),
            .plane => |p| raylib.genMeshPlane(p.width, p.height, p.res_x, p.res_z),
            .torus => |p| raylib.genMeshTorus(p.radius, p.size, p.rad_seg, p.sides),
            .knot => |p| raylib.genMeshKnot(p.radius, p.size, p.rad_seg, p.sides),
            .heightmap => |p| raylib.genMeshHeightmap(p.heightmap, p.size),
        };

        return raylib.loadModelFromMesh(mesh);
    }
};

pub const Meshes = struct {
    pub const upload = raylib.uploadMesh;
    pub const updateBuffer = raylib.updateMeshBuffer;
    pub const unload = raylib.unloadMesh;
    pub const draw = raylib.drawMesh;
    pub const drawInstanced = raylib.drawMeshInstanced;
    pub const getBoundingBox = raylib.getMeshBoundingBox;
    pub const genTangents = raylib.genMeshTangents;
    pub const exportToFile = raylib.exportMesh;
    pub const exportAsCode = raylib.exportMeshAsCode;
    pub const genPoly = raylib.genMeshPoly;
    pub const genPlane = raylib.genMeshPlane;
    pub const genCube = raylib.genMeshCube;
    pub const genSphere = raylib.genMeshSphere;
    pub const genHemiSphere = raylib.genMeshHemiSphere;
    pub const genCylinder = raylib.genMeshCylinder;
    pub const genCone = raylib.genMeshCone;
    pub const genTorus = raylib.genMeshTorus;
    pub const genKnot = raylib.genMeshKnot;
    pub const genHeightmap = raylib.genMeshHeightmap;
    pub const genCubicmap = raylib.genMeshCubicmap;
};

// ============================================================================
// Material Management
// ============================================================================

pub const Materials = struct {
    pub const loadDefault = raylib.loadMaterialDefault;
    pub const load = raylib.loadMaterials;
    pub const unload = raylib.unloadMaterial;
    pub const setTexture = raylib.setMaterialTexture;
    pub const setMeshMaterial = raylib.setModelMeshMaterial;

    /// Load a material from file with texture support
    pub fn loadFromFile(fileName: [:0]const u8) raylib.Material {
        return raylib.loadModel(fileName).materials[0];
    }

    /// Create a basic material with diffuse texture
    pub fn createBasic(diffuse_texture: raylib.Texture) raylib.Material {
        var material = raylib.loadMaterialDefault();
        material.maps[raylib.MATERIAL_MAP_DIFFUSE].texture = diffuse_texture;
        return material;
    }

    /// Create a PBR material (Physically Based Rendering)
    pub fn createPBR(albedo: raylib.Texture, normal: ?raylib.Texture, metallic_roughness: ?raylib.Texture, emissive: ?raylib.Texture) raylib.Material {
        var material = raylib.loadMaterialDefault();

        // Albedo/Base color
        material.maps[raylib.MATERIAL_MAP_ALBEDO].texture = albedo;

        // Normal map
        if (normal) |tex| {
            material.maps[raylib.MATERIAL_MAP_NORMAL].texture = tex;
        }

        // Metallic/Roughness map
        if (metallic_roughness) |tex| {
            material.maps[raylib.MATERIAL_MAP_METALNESS].texture = tex;
            material.maps[raylib.MATERIAL_MAP_ROUGHNESS].texture = tex;
        }

        // Emissive map
        if (emissive) |tex| {
            material.maps[raylib.MATERIAL_MAP_EMISSION].texture = tex;
        }

        return material;
    }

    /// Set material color properties
    pub fn setColor(material: *raylib.Material, map_type: raylib.MaterialMapIndex, color: raylib.Color) void {
        material.maps[map_type].color = color;
    }

    /// Set material float properties
    pub fn setValue(material: *raylib.Material, map_type: raylib.MaterialMapIndex, value: f32) void {
        material.maps[map_type].value = value;
    }
};

// ============================================================================
// Shader Management
// ============================================================================

pub const Shaders = struct {
    pub const load = raylib.loadShader;
    pub const loadFromMemory = raylib.loadShaderFromMemory;
    pub const unload = raylib.unloadShader;
    pub const getLocation = raylib.getShaderLocation;
    pub const getLocationAttrib = raylib.getShaderLocationAttrib;
    pub const setValue = raylib.setShaderValue;
    pub const setValueV = raylib.setShaderValueV;
    pub const setValueMatrix = raylib.setShaderValueMatrix;
    pub const setValueTexture = raylib.setShaderValueTexture;
    pub const activate = raylib.beginShaderMode;
    pub const deactivate = raylib.endShaderMode;
};

// ============================================================================
// Font Management
// ============================================================================

pub const Fonts = struct {
    pub const getDefault = raylib.getFontDefault;
    pub const load = raylib.loadFont;
    pub const loadEx = raylib.loadFontEx;
    pub const loadFromMemory = raylib.loadFontFromMemory;
    pub const loadFromImage = raylib.loadFontFromImage;
    pub const loadData = raylib.loadFontData;
    pub const unload = raylib.unloadFont;
    pub const unloadData = raylib.unloadFontData;
    pub const exportAsCode = raylib.exportFontAsCode;
    pub const genAtlas = raylib.genImageFontAtlas;
    pub const isReady = raylib.isFontValid;
};

// ============================================================================
// Camera Management
// ============================================================================

pub const Cameras = struct {
    pub const update = raylib.updateCamera;
    pub const updatePro = raylib.updateCameraPro;
    pub const getMatrix = raylib.getCameraMatrix;
    pub const getMatrix2D = raylib.getCameraMatrix2D;
    pub const getScreenToWorldRay = raylib.getScreenToWorldRay;
    pub const getScreenToWorldRayEx = raylib.getScreenToWorldRayEx;
    pub const getWorldToScreen = raylib.getWorldToScreen;
    pub const getWorldToScreenEx = raylib.getWorldToScreenEx;
    pub const getWorldToScreen2D = raylib.getWorldToScreen2D;
    pub const getScreenToWorld2D = raylib.getScreenToWorld2D;
};

/// Audio device management functions.
///
/// **Backend Requirements:** Requires raylib backend
///
/// This namespace provides functions for initializing and managing the audio device.
/// The audio device must be initialized before loading or playing sounds.
pub const Audio = struct {
    pub const initDevice = raylib.initAudioDevice;
    pub const closeDevice = raylib.closeAudioDevice;
    pub const isDeviceReady = raylib.isAudioDeviceReady;
    pub const setMasterVolume = raylib.setMasterVolume;
    pub const getMasterVolume = raylib.getMasterVolume;
};

pub const Sounds = struct {
    pub const load = raylib.loadSound;
    pub const loadFromWave = raylib.loadSoundFromWave;
    pub const loadAlias = raylib.loadSoundAlias;
    pub const unload = raylib.unloadSound;
    pub const unloadAlias = raylib.unloadSoundAlias;
    pub const play = raylib.playSound;
    pub const stop = raylib.stopSound;
    pub const pause = raylib.pauseSound;
    pub const resumePlaying = raylib.resumeSound;
    pub const isPlaying = raylib.isSoundPlaying;
    pub const setVolume = raylib.setSoundVolume;
    pub const setPitch = raylib.setSoundPitch;
    pub const setPan = raylib.setSoundPan;
};

// ============================================================================
// Music Streaming
// ============================================================================

pub const MusicFunctions = struct {
    pub const load = raylib.loadMusicStream;
    pub const loadFromMemory = raylib.loadMusicStreamFromMemory;
    pub const unload = raylib.unloadMusicStream;
    pub const play = raylib.playMusicStream;
    pub const isPlaying = raylib.isMusicStreamPlaying;
    pub const update = raylib.updateMusicStream;
    pub const stop = raylib.stopMusicStream;
    pub const pause = raylib.pauseMusicStream;
    pub const resumePlaying = raylib.resumeMusicStream;
    pub const seek = raylib.seekMusicStream;
    pub const setVolume = raylib.setMusicVolume;
    pub const setPitch = raylib.setMusicPitch;
    pub const setPan = raylib.setMusicPan;
    pub const getTimeLength = raylib.getMusicTimeLength;
    pub const getTimePlayed = raylib.getMusicTimePlayed;
};

// ============================================================================
// Wave & Audio Stream Management
// ============================================================================

pub const Waves = struct {
    pub const load = raylib.loadWave;
    pub const loadFromMemory = raylib.loadWaveFromMemory;
    pub const unload = raylib.unloadWave;
    pub const exportToFile = raylib.exportWave;
    pub const exportAsCode = raylib.exportWaveAsCode;
    pub const copy = raylib.waveCopy;
    pub const crop = raylib.waveCrop;
    pub const format = raylib.waveFormat;
    pub const loadSamples = raylib.loadWaveSamples;
    pub const unloadSamples = raylib.unloadWaveSamples;
};

pub const AudioStreams = struct {
    pub const load = raylib.loadAudioStream;
    pub const unload = raylib.unloadAudioStream;
    pub const update = raylib.updateAudioStream;
    pub const isProcessed = raylib.isAudioStreamProcessed;
    pub const play = raylib.playAudioStream;
    pub const pause = raylib.pauseAudioStream;
    pub const resumePlaying = raylib.resumeAudioStream;
    pub const isPlaying = raylib.isAudioStreamPlaying;
    pub const stop = raylib.stopAudioStream;
    pub const setVolume = raylib.setAudioStreamVolume;
    pub const setPitch = raylib.setAudioStreamPitch;
    pub const setPan = raylib.setAudioStreamPan;
    pub const setBufferSizeDefault = raylib.setAudioStreamBufferSizeDefault;
    pub const setCallback = raylib.setAudioStreamCallback;
    pub const attachProcessor = raylib.attachAudioStreamProcessor;
    pub const detachProcessor = raylib.detachAudioStreamProcessor;
    pub const attachMixedProcessor = raylib.attachAudioMixedProcessor;
    pub const detachMixedProcessor = raylib.detachAudioMixedProcessor;
};

/// Input handling functions for keyboard, mouse, gamepad, touch, and gestures.
///
/// **Backend Requirements:** Requires raylib backend for full functionality
///
/// This namespace provides access to all input devices. Input state is updated
/// automatically each frame when using the raylib backend.
pub const Input = struct {
    pub const Keyboard = struct {
        pub const isPressed = raylib.isKeyPressed;
        pub const isPressedRepeat = raylib.isKeyPressedRepeat;
        pub const isDown = raylib.isKeyDown;
        pub const isReleased = raylib.isKeyReleased;
        pub const isUp = raylib.isKeyUp;
        pub const getPressed = raylib.getKeyPressed;
        pub const getCharPressed = raylib.getCharPressed;
        pub const getName = raylib.getKeyName;
        pub const setExitKey = raylib.setExitKey;
    };
    pub const Mouse = struct {
        pub const isButtonPressed = raylib.isMouseButtonPressed;
        pub const isButtonDown = raylib.isMouseButtonDown;
        pub const isButtonReleased = raylib.isMouseButtonReleased;
        pub const isButtonUp = raylib.isMouseButtonUp;
        pub const getX = raylib.getMouseX;
        pub const getY = raylib.getMouseY;
        pub const getPosition = raylib.getMousePosition;
        pub const getDelta = raylib.getMouseDelta;
        pub const setPosition = raylib.setMousePosition;
        pub const setOffset = raylib.setMouseOffset;
        pub const setScale = raylib.setMouseScale;
        pub const getWheelMove = raylib.getMouseWheelMove;
        pub const getWheelMoveV = raylib.getMouseWheelMoveV;
        pub const setCursor = raylib.setMouseCursor;
    };
    pub const Gamepad = struct {
        pub const isAvailable = raylib.isGamepadAvailable;
        pub const getName = raylib.getGamepadName;
        pub const isButtonPressed = raylib.isGamepadButtonPressed;
        pub const isButtonDown = raylib.isGamepadButtonDown;
        pub const isButtonReleased = raylib.isGamepadButtonReleased;
        pub const isButtonUp = raylib.isGamepadButtonUp;
        pub const getButtonPressed = raylib.getGamepadButtonPressed;
        pub const getAxisCount = raylib.getGamepadAxisCount;
        pub const getAxisMovement = raylib.getGamepadAxisMovement;
        pub const setMappings = raylib.setGamepadMappings;
        pub const setVibration = raylib.setGamepadVibration;
    };
    pub const Touch = struct {
        pub const getX = raylib.getTouchX;
        pub const getY = raylib.getTouchY;
        pub const getPosition = raylib.getTouchPosition;
        pub const getPointId = raylib.getTouchPointId;
        pub const getPointCount = raylib.getTouchPointCount;
    };
    pub const Gestures = struct {
        pub const setEnabled = raylib.setGesturesEnabled;
        pub const isDetected = raylib.isGestureDetected;
        pub const getDetected = raylib.getGestureDetected;
        pub const getHoldDuration = raylib.getGestureHoldDuration;
        pub const getDragVector = raylib.getGestureDragVector;
        pub const getDragAngle = raylib.getGestureDragAngle;
        pub const getPinchVector = raylib.getGesturePinchVector;
        pub const getPinchAngle = raylib.getGesturePinchAngle;
    };
};

// ============================================================================
// Collision Detection
// ============================================================================

pub const Collision = struct {
    pub const checkRecs = raylib.checkCollisionRecs;
    pub const checkCircles = raylib.checkCollisionCircles;
    pub const checkCircleRec = raylib.checkCollisionCircleRec;
    pub const checkCircleLine = raylib.checkCollisionCircleLine;
    pub const checkPointRec = raylib.checkCollisionPointRec;
    pub const checkPointCircle = raylib.checkCollisionPointCircle;
    pub const checkPointTriangle = raylib.checkCollisionPointTriangle;
    pub const checkPointLine = raylib.checkCollisionPointLine;
    pub const checkPointPoly = raylib.checkCollisionPointPoly;
    pub const checkLines = raylib.checkCollisionLines;
    pub const getRec = raylib.getCollisionRec;
    pub const checkSpheres = raylib.checkCollisionSpheres;
    pub const checkBoxes = raylib.checkCollisionBoxes;
    pub const checkBoxSphere = raylib.checkCollisionBoxSphere;
    pub const getRaySphere = raylib.getRayCollisionSphere;
    pub const getRayBox = raylib.getRayCollisionBox;
    pub const getRayMesh = raylib.getRayCollisionMesh;
    pub const getRayTriangle = raylib.getRayCollisionTriangle;
    pub const getRayQuad = raylib.getRayCollisionQuad;
};

// ============================================================================
// Math Utilities
// ============================================================================

pub const Math = raylib.math;

// ============================================================================
// File I/O
// ============================================================================

pub const File = struct {
    pub const loadData = raylib.loadFileData;
    pub const unloadData = raylib.unloadFileData;
    pub const loadText = raylib.loadFileText;
    pub const unloadText = raylib.unloadFileText;
    pub const saveText = raylib.saveFileText;
    pub const saveData = raylib.saveFileData;
    pub const exists = raylib.fileExists;
    pub const directoryExists = raylib.directoryExists;
    pub const isExtension = raylib.isFileExtension;
    pub const getLength = raylib.getFileLength;
    pub const getModTime = raylib.getFileModTime;
    pub const getExtension = raylib.getFileExtension;
    pub const getFileName = raylib.getFileName;
    pub const getFileNameWithoutExt = raylib.getFileNameWithoutExt;
    pub const getDirectoryPath = raylib.getDirectoryPath;
    pub const getPrevDirectoryPath = raylib.getPrevDirectoryPath;
    pub const getWorkingDirectory = raylib.getWorkingDirectory;
    pub const getApplicationDirectory = raylib.getApplicationDirectory;
    pub const makeDirectory = raylib.makeDirectory;
    pub const changeDirectory = raylib.changeDirectory;
    pub const isPathFile = raylib.isPathFile;
    pub const isFileNameValid = raylib.isFileNameValid;
    pub const loadDirectoryFiles = raylib.loadDirectoryFiles;
    pub const loadDirectoryFilesEx = raylib.loadDirectoryFilesEx;
    pub const unloadDirectoryFiles = raylib.unloadDirectoryFiles;
    pub const isDropped = raylib.isFileDropped;
    pub const loadDroppedFiles = raylib.loadDroppedFiles;
    pub const unloadDroppedFiles = raylib.unloadDroppedFiles;
    pub const rename = raylib.fileRename;
    pub const remove = raylib.fileRemove;
    pub const copy = raylib.fileCopy;
    pub const move = raylib.fileMove;
    pub const textReplace = raylib.fileTextReplace;
    pub const textFindIndex = raylib.fileTextFindIndex;
    pub const exportDataAsCode = raylib.exportDataAsCode;
};

// ============================================================================
// System Utilities
// ============================================================================

pub const System = struct {
    pub const setConfigFlags = raylib.setConfigFlags;
    pub const setTraceLogLevel = raylib.setTraceLogLevel;
    pub const traceLog = raylib.traceLog;
    pub const setTargetFPS = raylib.setTargetFPS;
    pub const getFrameTime = raylib.getFrameTime;
    pub const getTime = raylib.getTime;
    pub const getFPS = raylib.getFPS;
    pub const swapScreenBuffer = raylib.swapScreenBuffer;
    pub const pollInputEvents = raylib.pollInputEvents;
    pub const waitTime = raylib.waitTime;
    pub const setRandomSeed = raylib.setRandomSeed;
    pub const getRandomValue = raylib.getRandomValue;
    pub const loadRandomSequence = raylib.loadRandomSequence;
    pub const unloadRandomSequence = raylib.unloadRandomSequence;
    pub const takeScreenshot = raylib.takeScreenshot;
    pub const openURL = raylib.openURL;
    pub const setClipboardText = raylib.setClipboardText;
    pub const getClipboardText = raylib.getClipboardText;
    pub const getClipboardImage = raylib.getClipboardImage;
    pub const enableEventWaiting = raylib.enableEventWaiting;
    pub const disableEventWaiting = raylib.disableEventWaiting;
    pub const compressData = raylib.compressData;
    pub const decompressData = raylib.decompressData;
    pub const encodeDataBase64 = raylib.encodeDataBase64;
    pub const decodeDataBase64 = raylib.decodeDataBase64;
    pub const computeCRC32 = raylib.computeCRC32;
    pub const computeMD5 = raylib.computeMD5;
    pub const computeSHA1 = raylib.computeSHA1;
};

// ============================================================================
// VR Support
// ============================================================================

pub const VR = struct {
    pub const loadStereoConfig = raylib.loadVrStereoConfig;
    pub const unloadStereoConfig = raylib.unloadVrStereoConfig;
};

// ============================================================================
// Automation & Testing
// ============================================================================

pub const Automation = struct {
    pub const loadEventList = raylib.loadAutomationEventList;
    pub const unloadEventList = raylib.unloadAutomationEventList;
    pub const exportEventList = raylib.exportAutomationEventList;
    pub const setEventList = raylib.setAutomationEventList;
    pub const setBaseFrame = raylib.setAutomationEventBaseFrame;
    pub const startRecording = raylib.startAutomationEventRecording;
    pub const stopRecording = raylib.stopAutomationEventRecording;
    pub const playEvent = raylib.playAutomationEvent;
};

// GLFW namespace with full API support (only available on native platforms)
pub const Glfw = if (glfw_available) struct {
    // Direct access to GLFW types
    pub const Window = zglfw.Window;
    pub const Monitor = zglfw.Monitor;
    pub const Cursor = zglfw.Cursor;
    pub const VidMode = zglfw.VidMode;
    pub const GamepadState = zglfw.GamepadState;
    pub const GammaRamp = zglfw.GammaRamp;

    // Re-export all GLFW enums and constants
    pub const WindowHint = zglfw.WindowHint;
    pub const InputMode = zglfw.InputMode;
    pub const CursorMode = zglfw.CursorMode;
    pub const MouseButton = zglfw.MouseButton;
    pub const Joystick = zglfw.Joystick;
    pub const Key = zglfw.Key;
    pub const ModifierKey = zglfw.ModifierKey;
    pub const KeyAction = zglfw.KeyAction;

    // Initialization and termination
    pub const init = zglfw.init;
    pub const terminate = zglfw.terminate;
    pub const initHint = zglfw.initHint;
    pub const getVersion = zglfw.getVersion;
    pub const getVersionString = zglfw.getVersionString;
    pub const getError = zglfw.getError;
    pub const pollEvents = zglfw.pollEvents;
    pub const waitEvents = zglfw.waitEvents;
    pub const waitEventsTimeout = zglfw.waitEventsTimeout;
    pub const postEmptyEvent = zglfw.postEmptyEvent;

    // Time
    pub const getTime = zglfw.getTime;
    pub const setTime = zglfw.setTime;
    pub const getTimerValue = zglfw.getTimerValue;
    pub const getTimerFrequency = zglfw.getTimerFrequency;

    // Monitors
    pub const getMonitors = zglfw.getMonitors;
    pub const getPrimaryMonitor = zglfw.getPrimaryMonitor;
    pub const getMonitorPos = zglfw.getMonitorPos;
    pub const getMonitorWorkarea = zglfw.getMonitorWorkarea;
    pub const getMonitorPhysicalSize = zglfw.getMonitorPhysicalSize;
    pub const getMonitorContentScale = zglfw.getMonitorContentScale;
    pub const getMonitorName = zglfw.getMonitorName;
    pub const setMonitorUserPointer = zglfw.setMonitorUserPointer;
    pub const getMonitorUserPointer = zglfw.getMonitorUserPointer;
    pub const setMonitorCallback = zglfw.setMonitorCallback;
    pub const getVideoModes = zglfw.getVideoModes;
    pub const getVideoMode = zglfw.getVideoMode;
    pub const setGamma = zglfw.setGamma;
    pub const getGammaRamp = zglfw.getGammaRamp;
    pub const setGammaRamp = zglfw.setGammaRamp;

    // Windows
    pub const windowHint = zglfw.windowHint;
    pub const windowHintString = zglfw.windowHintString;
    pub const defaultWindowHints = zglfw.defaultWindowHints;
    pub const createWindow = zglfw.Window.create;
    pub const destroyWindow = zglfw.Window.destroy;
    pub const windowShouldClose = zglfw.Window.shouldClose;
    pub const setWindowShouldClose = zglfw.Window.setShouldClose;
    pub const setWindowTitle = zglfw.Window.setTitle;
    pub const setWindowIcon = zglfw.Window.setIcon;
    pub const getWindowPos = zglfw.Window.getPos;
    pub const setWindowPos = zglfw.Window.setPos;
    pub const getWindowSize = zglfw.Window.getSize;
    pub const setWindowSize = zglfw.Window.setSize;
    pub const setWindowSizeLimits = zglfw.Window.setSizeLimits;
    pub const setWindowAspectRatio = zglfw.Window.setAspectRatio;
    pub const getFramebufferSize = zglfw.Window.getFramebufferSize;
    pub const getWindowFrameSize = zglfw.Window.getFrameSize;
    pub const getWindowContentScale = zglfw.Window.getContentScale;
    pub const getWindowOpacity = zglfw.Window.getOpacity;
    pub const setWindowOpacity = zglfw.Window.setOpacity;
    pub const iconifyWindow = zglfw.Window.iconify;
    pub const restoreWindow = zglfw.Window.restore;
    pub const maximizeWindow = zglfw.Window.maximize;
    pub const showWindow = zglfw.Window.show;
    pub const hideWindow = zglfw.Window.hide;
    pub const focusWindow = zglfw.Window.focus;
    pub const requestWindowAttention = zglfw.Window.requestAttention;
    pub const getWindowMonitor = zglfw.Window.getMonitor;
    pub const setWindowMonitor = zglfw.Window.setWindowMonitor;
    pub const getWindowAttrib = zglfw.Window.getAttrib;
    pub const setWindowAttrib = zglfw.Window.setAttrib;
    pub const setWindowUserPointer = zglfw.Window.setUserPointer;
    pub const getWindowUserPointer = zglfw.Window.getUserPointer;

    // Context
    pub const makeContextCurrent = zglfw.makeContextCurrent;
    pub const getCurrentContext = zglfw.getCurrentContext;
    pub const swapBuffers = zglfw.Window.swapBuffers;
    pub const swapInterval = zglfw.swapInterval;
    pub const extensionSupported = zglfw.extensionSupported;
    pub const getProcAddress = zglfw.getProcAddress;

    // Input
    pub const getInputMode = zglfw.Window.getInputMode;
    pub const setInputMode = zglfw.Window.setInputMode;
    pub const rawMouseMotionSupported = zglfw.rawMouseMotionSupported;
    pub const getKey = zglfw.Window.getKey;
    pub const getKeyName = zglfw.getKeyName;
    pub const getKeyScancode = zglfw.getKeyScancode;
    pub const getMouseButton = zglfw.Window.getMouseButton;
    pub const getCursorPos = zglfw.Window.getCursorPos;
    pub const setCursorPos = zglfw.Window.setCursorPos;
    pub const createCursor = zglfw.createCursor;
    pub const createStandardCursor = zglfw.createStandardCursor;
    pub const destroyCursor = zglfw.destroyCursor;
    pub const setCursor = zglfw.Window.setCursor;
    pub const setKeyCallback = zglfw.Window.setKeyCallback;
    pub const setCharCallback = zglfw.Window.setCharCallback;
    pub const setCharModsCallback = zglfw.Window.setCharModsCallback;
    pub const setMouseButtonCallback = zglfw.Window.setMouseButtonCallback;
    pub const setCursorPosCallback = zglfw.Window.setCursorPosCallback;
    pub const setCursorEnterCallback = zglfw.Window.setCursorEnterCallback;
    pub const setScrollCallback = zglfw.Window.setScrollCallback;
    pub const setDropCallback = zglfw.Window.setDropCallback;
    pub const joystickPresent = zglfw.joystickPresent;
    pub const getJoystickAxes = zglfw.getJoystickAxes;
    pub const getJoystickButtons = zglfw.getJoystickButtons;
    pub const getJoystickHats = zglfw.getJoystickHats;
    pub const getJoystickName = zglfw.getJoystickName;
    pub const getJoystickGUID = zglfw.getJoystickGUID;
    pub const setJoystickUserPointer = zglfw.setJoystickUserPointer;
    pub const getJoystickUserPointer = zglfw.getJoystickUserPointer;
    pub const joystickIsGamepad = zglfw.joystickIsGamepad;
    pub const setJoystickCallback = zglfw.setJoystickCallback;
    pub const updateGamepadMappings = zglfw.updateGamepadMappings;
    pub const getGamepadName = zglfw.getGamepadName;
    pub const getGamepadState = zglfw.getGamepadState;
    pub const setClipboardString = zglfw.setClipboardString;
    pub const getClipboardString = zglfw.getClipboardString;

    // Vulkan support
    pub const vulkanSupported = zglfw.vulkanSupported;
    pub const getRequiredInstanceExtensions = zglfw.getRequiredInstanceExtensions;
    pub const getInstanceProcAddress = zglfw.getInstanceProcAddress;
    pub const getPhysicalDevicePresentationSupport = zglfw.getPhysicalDevicePresentationSupport;
    pub const createWindowSurface = zglfw.createWindowSurface;

    // Callbacks (re-export callback types)
    pub const ErrorFun = zglfw.ErrorFun;
    pub const WindowPosFun = zglfw.WindowPosFun;
    pub const WindowSizeFun = zglfw.WindowSizeFun;
    pub const WindowCloseFun = zglfw.WindowCloseFun;
    pub const WindowRefreshFun = zglfw.WindowRefreshFun;
    pub const WindowFocusFun = zglfw.WindowFocusFun;
    pub const WindowIconifyFun = zglfw.WindowIconifyFun;
    pub const WindowMaximizeFun = zglfw.WindowMaximizeFun;
    pub const FramebufferSizeFun = zglfw.FramebufferSizeFun;
    pub const WindowContentScaleFun = zglfw.WindowContentScaleFun;
    pub const MouseButtonFun = zglfw.MouseButtonFun;
    pub const CursorPosFun = zglfw.CursorPosFun;
    pub const CursorEnterFun = zglfw.CursorEnterFun;
    pub const ScrollFun = zglfw.ScrollFun;
    pub const KeyFun = zglfw.KeyFun;
    pub const CharFun = zglfw.CharFun;
    pub const CharModsFun = zglfw.CharModsFun;
    pub const DropFun = zglfw.DropFun;
    pub const MonitorFun = zglfw.MonitorFun;
    pub const JoystickFun = zglfw.JoystickFun;

    pub const setErrorCallback = zglfw.setErrorCallback;
    pub const setWindowPosCallback = zglfw.Window.setWindowPosCallback;
    pub const setWindowSizeCallback = zglfw.Window.setWindowSizeCallback;
    pub const setWindowCloseCallback = zglfw.Window.setWindowCloseCallback;
    pub const setWindowRefreshCallback = zglfw.Window.setWindowRefreshCallback;
    pub const setWindowFocusCallback = zglfw.Window.setWindowFocusCallback;
    pub const setWindowIconifyCallback = zglfw.Window.setWindowIconifyCallback;
    pub const setWindowMaximizeCallback = zglfw.Window.setWindowMaximizeCallback;
    pub const setFramebufferSizeCallback = zglfw.Window.setFramebufferSizeCallback;
    pub const setWindowContentScaleCallback = zglfw.Window.setWindowContentScaleCallback;
} else struct {
    // Stub implementations for platforms where GLFW is not available
    pub const Window = opaque {};
    pub const Monitor = opaque {};
    pub const Cursor = opaque {};
    pub const Error = error{GlfwNotAvailable};
    pub const init = error.GlfwNotAvailable;
    pub const terminate = error.GlfwNotAvailable;
    pub const pollEvents = error.GlfwNotAvailable;
    pub const makeContextCurrent = error.GlfwNotAvailable;
    pub const swapInterval = error.GlfwNotAvailable;
    pub const getPrimaryMonitor = error.GlfwNotAvailable;
    pub const windowHint = error.GlfwNotAvailable;
};

// Direct re-exports for convenience (use these if you prefer the original raylib API)
pub const rl = raylib;

// Direct access to GLFW (use this if you prefer the original GLFW API)
pub const glfw = Glfw;
