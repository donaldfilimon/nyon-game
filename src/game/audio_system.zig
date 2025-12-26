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
            // Default orientation for now: Forward and Up
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
            // We use getPtr if we want to modify the component, but here we only read.
            // Wait, AudioSource might need status updates (e.g. if it finished playing).
            const source = match.get(components.AudioSource);
            const pos = match.get(components.Position);

            if (self.asset_manager.getSoundByHandle(source.clip_handle)) |sound| {
                if (source.playing) {
                    if (!raylib.isSoundPlaying(sound)) {
                        raylib.playSound(sound);
                    }

                    if (source.spatial) {
                        // Note: Raylib's raudio might not have SetSoundPosition in base bindings.
                        // If it's missing, we'll need to use setSoundPan or a 3D extension.
                        // For Nyon Game, we assume the raylib wrapper provides some spatialization.
                        // If setSoundPosition is not available, we can approximate with pan.
                        // raylib.setSoundPosition(sound, pos.x, pos.y, pos.z);

                        // Approx pan based on listener (relative to cam forward)
                        // This is a placeholder for true 3D audio if the backend supports it.
                        _ = pos;
                    }

                    raylib.setSoundVolume(sound, source.volume);
                    raylib.setSoundPitch(sound, source.pitch);
                    // Handle looping
                    // raylib.setSoundLooping(sound, source.looping);
                } else {
                    if (raylib.isSoundPlaying(sound)) {
                        raylib.stopSound(sound);
                    }
                }
            }
        }
    }
};
