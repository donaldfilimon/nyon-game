const std = @import("std");

const raylib = @import("raylib");

/// Post-processing effects system
pub const PostProcessingSystem = struct {
    allocator: std.mem.Allocator,
    shaders: std.StringHashMap(raylib.Shader),
    active_effect: EffectType = .none,

    pub const EffectType = enum {
        none,
        grayscale,
        inversion,
        sepia,
        bloom,
        vignette,
        chromatic_aberration,
    };

    pub fn init(allocator: std.mem.Allocator) !PostProcessingSystem {
        return PostProcessingSystem{
            .allocator = allocator,
            .shaders = std.StringHashMap(raylib.Shader).init(allocator),
            .active_effect = .none,
        };
    }

    pub fn deinit(self: *PostProcessingSystem) void {
        var iter = self.shaders.iterator();
        while (iter.next()) |entry| {
            raylib.unloadShader(entry.value_ptr.*);
        }
        self.shaders.deinit();
    }

    pub fn loadEffect(self: *PostProcessingSystem, effect: EffectType, path: [:0]const u8) !void {
        const shader = raylib.loadShader(null, path);
        try self.shaders.put(@tagName(effect), shader);
    }

    pub fn beginEffect(self: *PostProcessingSystem, effect: EffectType) void {
        self.active_effect = effect;
        if (effect != .none) {
            if (self.shaders.get(@tagName(effect))) |shader| {
                raylib.beginShaderMode(shader);
            }
        }
    }

    pub fn endEffect(self: *PostProcessingSystem) void {
        if (self.active_effect != .none) {
            raylib.endShaderMode();
        }
        self.active_effect = .none;
    }

    /// Apply post-processing to a texture
    pub fn apply(self: *PostProcessingSystem, target: raylib.RenderTexture2D) void {
        if (self.active_effect == .none) {
            raylib.drawTextureRec(target.texture, .{ .x = 0, .y = 0, .width = @floatFromInt(target.texture.width), .height = @floatFromInt(-target.texture.height) }, .{ .x = 0, .y = 0 }, raylib.Color.white);
            return;
        }

        if (self.shaders.get(@tagName(self.active_effect))) |shader| {
            raylib.beginShaderMode(shader);
            raylib.drawTextureRec(target.texture, .{ .x = 0, .y = 0, .width = @floatFromInt(target.texture.width), .height = @floatFromInt(-target.texture.height) }, .{ .x = 0, .y = 0 }, raylib.Color.white);
            raylib.endShaderMode();
        } else {
            raylib.drawTextureRec(target.texture, .{ .x = 0, .y = 0, .width = @floatFromInt(target.texture.width), .height = @floatFromInt(-target.texture.height) }, .{ .x = 0, .y = 0 }, raylib.Color.white);
        }
    }
};
