const std = @import("std");
const builtin = @import("builtin");

/// Platform detection.
pub const is_browser = builtin.target.os.tag == .freestanding or builtin.target.os.tag == .wasi;

/// Engine-specific error types.
pub const EngineError = error{
    BackendNotInitialized,
    BackendNotAvailable,
    GlfwBackendNotImplemented,
    GlfwNotAvailable,
    InvalidConfig,
    RaylibInitializationFailed,
    WindowCreationFailed,
    WebGpuBackendNotImplemented,
};

/// Supported rendering backends.
pub const Backend = enum {
    auto,
    webgpu,
    glfw,
    raylib,
};

/// WebGPU-specific types (placeholder).
pub const WebGpuContext = struct {
    initialized: bool = false,
};

/// WebGPU configuration.
pub const WebGpuConfig = struct {
    power_preference: enum { default, low_power, high_performance } = .default,
    force_fallback_adapter: bool = false,
    preferred_backend: enum { auto, vulkan, d3d12, metal, opengl, webgpu } = .auto,
    debug_mode: bool = false,
};

/// Engine configuration.
pub const Config = struct {
    backend: Backend = .auto,
    width: u32 = 800,
    height: u32 = 600,
    title: [:0]const u8 = "Nyon Game",
    target_fps: ?u32 = 60,
    resizable: bool = true,
    fullscreen: bool = false,
    vsync: bool = true,
    samples: u32 = 0,
    webgpu: WebGpuConfig = .{},
};
