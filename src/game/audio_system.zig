const std = @import("std");
const raylib = @import("raylib");
const ecs = @import("../ecs/world.zig");
const components = @import("../ecs/component.zig");
const asset = @import("../asset.zig");

pub const AudioSystem = struct {
    asset_manager: *asset.AssetManager,

    pub fn init(asset_manager: *asset.AssetManager) AudioSystem {
        return .{
            .asset_manager = asset_manager,
        };
    }

    pub fn update(self: *AudioSystem, world: *ecs.World, _: f32) void {
        _ = self;
        // Update listener position (assume first camera is the listener)
        var camera_query = world.createQuery();
        defer camera_query.deinit();
        var cam_iter = camera_query
            .with(components.Camera)
            .with(components.Position)
            .build() catch unreachable;
        defer cam_iter.deinit();
        cam_iter.updateMatches(world.archetypes.items);

        var iter_cam = cam_iter.iter();
        if (iter_cam.next()) |match| {
            const pos = match.get(components.Position);
            raylib.setAudioListenerPosition(pos.x, pos.y, pos.z);
            // Default orientation for now
            raylib.setAudioListenerOrientation(.{ .x = 0, .y = 0, .z = 1 }, .{ .x = 0, .y = 1, .z = 0 });
        }

        // Update audio sources
        var source_query = world.createQuery();
        defer source_query.deinit();
        var source_iter = source_query
            .with(components.AudioSource)
            .with(components.Position)
            .build() catch unreachable;
        defer source_iter.deinit();
        source_iter.updateMatches(world.archetypes.items);

        var iter_src = source_iter.iter();
        while (iter_src.next()) |match| {
            var source = match.get(components.AudioSource);
            const pos = match.get(components.Position);

            // In a real system, we'd need to map clip_handle to raylib.Sound
            // For now, we assume the clip is already loaded in asset manager
            // and we use a mock approach or look it up by some id.
            // Since clip_handle is u64, let's assume it's a pointer or index.
            // Actually, let's just use the clip_handle as a key for now if it's a hash.
            // BUT raylib.Sound is a struct, we need to call raylib functions on it.

            // This is a bit tricky without a proper handle-to-sound mapping.
            // For a demo/placeholder, we'll just demonstrate the logic.

            if (source.playing) {
                // demonstrative: raylib.setSoundPosition(sound, pos.x, pos.y, pos.z);
                // raylib.setSoundVolume(sound, source.volume);
                // raylib.setSoundPitch(sound, source.pitch);
                _ = pos;
            }
        }
    }
};
