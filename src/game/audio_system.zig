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
        _ = camera_query.with(components.Camera) catch {};
        _ = camera_query.with(components.Position) catch {};
        var cam_iter = camera_query.build() catch unreachable;
        defer cam_iter.deinit();
        cam_iter.updateMatches(world.archetypes.items);

        var iter_cam = cam_iter.iter();
        if (iter_cam.next()) |match| {
            const pos = match.get(components.Position).?;
            raylib.setAudioListenerPosition(pos.x, pos.y, pos.z);
            // Default orientation for now: Forward and Up
            raylib.setAudioListenerOrientation(.{ .x = 0, .y = 0, .z = 1 }, .{ .x = 0, .y = 1, .z = 0 });
        }

        // Update audio sources
        var source_query_builder = world.createQuery();
        defer source_query_builder.deinit();
        const source_with_audio = source_query_builder.with(components.AudioSource) catch unreachable;
        const source_with_pos = source_with_audio.with(components.Position) catch unreachable;
        var source_iter = source_with_pos.build() catch unreachable;
        defer source_iter.deinit();
        source_iter.updateMatches(world.archetypes.items);

        var iter_src = source_iter.iter();
        while (iter_src.next()) |match| {
            // We use getPtr if we want to modify the component, but here we only read.
            // Wait, AudioSource might need status updates (e.g. if it finished playing).
            const source = match.get(components.AudioSource) orelse continue;

            if (self.asset_manager.getSoundByHandle(source.clip_handle)) |sound| {
                if (source.spatial_blend > 0.0) {
                    if (!raylib.isSoundPlaying(sound)) {
                        raylib.playSound(sound);
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
