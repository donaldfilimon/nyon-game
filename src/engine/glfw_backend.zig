const std = @import("std");
const types = @import("types.zig");

pub const GlfwBackend = struct {
    pub fn init(_: *anyopaque, _: types.Config) types.EngineError!void {
        return types.EngineError.GlfwBackendNotImplemented;
    }

    pub fn deinit(_: *anyopaque) void {
        // No-op for now
    }
};
