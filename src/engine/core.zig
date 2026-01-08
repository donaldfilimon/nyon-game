const std = @import("std");
const types = @import("types.zig");

pub const Backend = types.Backend;
pub const Config = types.Config;

pub const Engine = struct {
    allocator: std.mem.Allocator,
    backend_type: Backend,
    config: Config,
    raylib_initialized: bool = false,
    glfw_initialized: bool = false,
    webgpu_initialized: bool = false,

    pub fn init(allocator: std.mem.Allocator, config: Config) types.EngineError!Engine {
        if (config.width == 0 or config.height == 0) {
            return types.EngineError.InvalidConfig;
        }

        var engine = Engine{
            .allocator = allocator,
            .backend_type = config.backend,
            .config = config,
        };

        const resolved_backend: Backend = switch (config.backend) {
            .auto => if (types.is_browser) .webgpu else .raylib,
            else => config.backend,
        };

        engine.backend_type = resolved_backend;

        const raylib_backend = @import("raylib_backend.zig");
        const glfw_backend = @import("glfw_backend.zig");
        const webgpu_backend = @import("webgpu_backend.zig");

        switch (resolved_backend) {
            .webgpu => {
                try webgpu_backend.WebGpuBackend.init(@ptrCast(&engine), config);
                engine.webgpu_initialized = true;
            },
            .glfw => {
                try glfw_backend.GlfwBackend.init(@ptrCast(&engine), config);
                engine.glfw_initialized = true;
            },
            .raylib => {
                try raylib_backend.RaylibBackend.init(@ptrCast(&engine), config);
                engine.raylib_initialized = true;
            },
            .auto => unreachable,
        }

        return engine;
    }

    pub fn deinit(self: *Engine) void {
        const raylib_backend = @import("raylib_backend.zig");
        const glfw_backend = @import("glfw_backend.zig");
        const webgpu_backend = @import("webgpu_backend.zig");

        if (self.raylib_initialized) {
            raylib_backend.RaylibBackend.deinit(@ptrCast(self));
            self.raylib_initialized = false;
        }
        if (self.glfw_initialized) {
            glfw_backend.GlfwBackend.deinit(@ptrCast(self));
            self.glfw_initialized = false;
        }
        if (self.webgpu_initialized) {
            webgpu_backend.WebGpuBackend.deinit(@ptrCast(self));
            self.webgpu_initialized = false;
        }
    }

    pub fn isRaylibInitialized(self: *const Engine) bool {
        return self.raylib_initialized;
    }

    pub fn isGlfwInitialized(self: *const Engine) bool {
        return self.glfw_initialized;
    }

    pub fn isWebGpuInitialized(self: *const Engine) bool {
        return self.webgpu_initialized;
    }

    pub fn isBackendInitialized(self: *const Engine) bool {
        return self.raylib_initialized or self.glfw_initialized or self.webgpu_initialized;
    }
};
