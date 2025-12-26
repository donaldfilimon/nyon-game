const std = @import("std");
const types = @import("types.zig");

pub const WebGpuBackend = struct {
    pub fn init(_: *anyopaque, _: types.Config) types.EngineError!void {
        // Placeholder for future implementation
        return types.EngineError.WebGpuBackendNotImplemented;
    }

    pub fn deinit(_: *anyopaque) void {
        // No-op
    }
};
