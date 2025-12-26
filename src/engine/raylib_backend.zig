const std = @import("std");
const raylib = @import("raylib");
const types = @import("types.zig");

pub const RaylibBackend = struct {
    pub fn init(_: *anyopaque, config: types.Config) types.EngineError!void {
        if (types.is_browser) return types.EngineError.BackendNotAvailable;

        // Set configuration flags
        var flags = raylib.ConfigFlags{};
        flags.window_resizable = config.resizable;
        flags.fullscreen_mode = config.fullscreen;
        flags.vsync_hint = config.vsync;
        if (config.samples > 0) flags.msaa_4x_hint = true;

        raylib.setConfigFlags(@bitCast(flags));

        // Initialize Window
        raylib.initWindow(@intCast(config.width), @intCast(config.height), config.title);

        if (!raylib.isWindowReady()) {
            return types.EngineError.RaylibInitializationFailed;
        }

        if (config.target_fps) |fps| {
            raylib.setTargetFPS(@intCast(fps));
        }

        raylib.initAudioDevice();
    }

    pub fn deinit(_: *anyopaque) void {
        raylib.closeAudioDevice();
        raylib.closeWindow();
    }
};
