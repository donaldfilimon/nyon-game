const std = @import("std");
const types = @import("types.zig");
const raylib = @import("raylib");

pub const Backend = types.Backend;

pub fn shouldClose(backend: Backend, raylib_initialized: bool) bool {
    if (raylib_initialized) {
        return raylib.windowShouldClose();
    }
    return false;
}

pub fn pollEvents() void {}

pub fn getFPS(raylib_initialized: bool) types.EngineError!u32 {
    if (!raylib_initialized) return types.EngineError.BackendNotInitialized;
    return @intCast(raylib.getFPS());
}

pub fn getFrameTime(raylib_initialized: bool) types.EngineError!f32 {
    if (!raylib_initialized) return types.EngineError.BackendNotInitialized;
    return raylib.getFrameTime();
}

pub fn getTime(raylib_initialized: bool) types.EngineError!f64 {
    if (!raylib_initialized) return types.EngineError.BackendNotInitialized;
    return raylib.getTime();
}

pub fn getWindowSize(backend: Backend, raylib_initialized: bool, config: types.Config) struct { width: u32, height: u32 } {
    if (raylib_initialized) {
        return .{
            .width = @intCast(raylib.getScreenWidth()),
            .height = @intCast(raylib.getScreenHeight()),
        };
    }
    return .{
        .width = config.width,
        .height = config.height,
    };
}

pub fn setTargetFPS(raylib_initialized: bool, fps: u32) void {
    if (raylib_initialized) {
        raylib.setTargetFPS(@intCast(fps));
    }
}
