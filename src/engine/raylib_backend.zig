const std = @import("std");
const raylib = @import("raylib");
const types = @import("types.zig");

pub const RaylibBackend = struct {
    pub fn init(_: *anyopaque, config: types.Config) types.EngineError!void {
        if (types.is_browser) return types.EngineError.BackendNotAvailable;

        // Set configuration flags
        var flags: c_uint = 0;
        if (config.resizable) flags |= raylib.FLAG_WINDOW_RESIZABLE;
        if (config.fullscreen) flags |= raylib.FLAG_FULLSCREEN_MODE;
        if (config.vsync) flags |= raylib.FLAG_VSYNC_HINT;
        if (config.samples > 0) flags |= raylib.FLAG_MSAA_4X_HINT; // Simplified

        raylib.setConfigFlags(flags);

        // Initialize Window
        raylib.initWindow(@intCast(config.width), @intCast(config.height), config.title);

        if (!raylib.isWindowReady()) {
            return types.EngineError.RaylibInitializationFailed;
        }

        if (config.target_fps) |fps| {
            raylib.setTargetFPS(@intCast(fps));
        }
    }

    pub fn deinit(_: *anyopaque) void {
        raylib.closeWindow();
    }
};
