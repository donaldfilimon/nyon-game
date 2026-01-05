const std = @import("std");
const raylib = @import("raylib");
const nyon = @import("nyon_game");
const config = @import("config/constants.zig");

/// Keyframe Animation and Timeline System
///
/// Provides keyframe-based animation capabilities for creating custom animations
/// with precise control over timing and interpolation. Supports animation of
/// various properties like position, rotation, scale, colors, and custom values.
pub const KeyframeSystem = struct {
    allocator: std.mem.Allocator,

    /// Animation tracks for different properties
    tracks: std.ArrayList(AnimationTrack),

    /// Active animations being played
    active_animations: std.ArrayList(ActiveAnimation),

    /// Timeline configuration
    timeline: Timeline,

    pub const TrackId = usize;
    pub const AnimationId = usize;

    /// Supported property types for keyframe animation
    pub const PropertyType = enum {
        position, // Vector3
        rotation, // Vector3 (Euler angles)
        scale, // Vector3
        color, // Color
        float, // f32
        vector2, // Vector2
        custom, // User-defined
    };

    /// Keyframe data
    pub const Keyframe = struct {
        time: f32, // Time in seconds
        value: PropertyValue,
        interpolation: InterpolationType,

        pub const InterpolationType = enum {
            linear,
            smooth, // Smooth interpolation
            step, // No interpolation (constant)
            ease_in, // Ease in curve
            ease_out, // Ease out curve
            ease_in_out, // Ease in and out
        };
    };

    /// Property value union
    pub const PropertyValue = union(PropertyType) {
        position: raylib.Vector3,
        rotation: raylib.Vector3,
        scale: raylib.Vector3,
        color: raylib.Color,
        float: f32,
        vector2: raylib.Vector2,
        custom: []const u8, // JSON or custom format
    };

    /// Animation track containing keyframes for a specific property
    pub const AnimationTrack = struct {
        id: TrackId,
        name: []const u8,
        target_entity: usize, // Entity this track animates
        property_type: PropertyType,
        property_name: []const u8, // Specific property (e.g., "position.x")
        keyframes: std.ArrayList(Keyframe),
        enabled: bool,

        pub fn init(allocator: std.mem.Allocator, id: TrackId, name: []const u8, target_entity: usize, property_type: PropertyType, property_name: []const u8) !AnimationTrack {
            const name_copy = try allocator.dupe(u8, name);
            const prop_name_copy = try allocator.dupe(u8, property_name);

            return .{
                .id = id,
                .name = name_copy,
                .target_entity = target_entity,
                .property_type = property_type,
                .property_name = prop_name_copy,
                .keyframes = std.ArrayList(Keyframe).initCapacity(allocator, 8) catch unreachable,
                .enabled = true,
            };
        }

        pub fn deinit(self: *AnimationTrack, allocator: std.mem.Allocator) void {
            allocator.free(self.name);
            allocator.free(self.property_name);

            // Clean up custom keyframe values
            for (self.keyframes.items) |*keyframe| {
                if (keyframe.value == .custom) {
                    allocator.free(keyframe.value.custom);
                }
            }

            self.keyframes.deinit(allocator);
        }

        /// Add a keyframe to the track
        pub fn addKeyframe(self: *AnimationTrack, allocator: std.mem.Allocator, time: f32, value: PropertyValue, interpolation: Keyframe.InterpolationType) !void {
            const keyframe = Keyframe{
                .time = time,
                .value = value,
                .interpolation = interpolation,
            };
            try self.keyframes.append(allocator, keyframe);

            // Sort keyframes by time
            self.sortKeyframes();
        }

        /// Evaluate the track at a given time
        pub fn evaluate(self: *const AnimationTrack, time: f32) ?PropertyValue {
            if (self.keyframes.items.len == 0 or !self.enabled) return null;

            // Find keyframes around the given time
            var left_idx: ?usize = null;
            var right_idx: ?usize = null;

            for (self.keyframes.items, 0..) |keyframe, i| {
                if (keyframe.time <= time) {
                    left_idx = i;
                }
                if (keyframe.time >= time and right_idx == null) {
                    right_idx = i;
                    break;
                }
            }

            if (left_idx) |left| {
                const left_key = &self.keyframes.items[left];

                if (right_idx) |right| {
                    // Interpolate between keyframes
                    const right_key = &self.keyframes.items[right];
                    const t = (time - left_key.time) / (right_key.time - left_key.time);
                    return self.interpolateValues(left_key, right_key, t);
                } else {
                    // Return the last keyframe value
                    return left_key.value;
                }
            }

            // Before first keyframe, return first keyframe value
            if (self.keyframes.items.len > 0) {
                return self.keyframes.items[0].value;
            }

            return null;
        }

        /// Sort keyframes by time
        fn sortKeyframes(self: *AnimationTrack) void {
            std.mem.sort(Keyframe, self.keyframes.items, {}, struct {
                fn lessThan(_: void, a: Keyframe, b: Keyframe) bool {
                    return a.time < b.time;
                }
            }.lessThan);
        }

        /// Interpolate between two keyframes
        fn interpolateValues(self: *const AnimationTrack, key1: *const Keyframe, key2: *const Keyframe, t: f32) PropertyValue {
            const eased_t = self.applyEasing(t, key1.interpolation);

            return switch (key1.value) {
                .position => |v1| switch (key2.value) {
                    .position => |v2| PropertyValue{ .position = raylib.Vector3{
                        .x = v1.x + (v2.x - v1.x) * eased_t,
                        .y = v1.y + (v2.y - v1.y) * eased_t,
                        .z = v1.z + (v2.z - v1.z) * eased_t,
                    } },
                    else => key1.value,
                },
                .rotation => |v1| switch (key2.value) {
                    .rotation => |v2| PropertyValue{ .rotation = raylib.Vector3{
                        .x = v1.x + (v2.x - v1.x) * eased_t,
                        .y = v1.y + (v2.y - v1.y) * eased_t,
                        .z = v1.z + (v2.z - v1.z) * eased_t,
                    } },
                    else => key1.value,
                },
                .scale => |v1| switch (key2.value) {
                    .scale => |v2| PropertyValue{ .scale = raylib.Vector3{
                        .x = v1.x + (v2.x - v1.x) * eased_t,
                        .y = v1.y + (v2.y - v1.y) * eased_t,
                        .z = v1.z + (v2.z - v1.z) * eased_t,
                    } },
                    else => key1.value,
                },
                .color => |v1| switch (key2.value) {
                    .color => |v2| PropertyValue{ .color = raylib.Color{
                        .r = @intFromFloat(@as(f32, @floatFromInt(v1.r)) + (@as(f32, @floatFromInt(v2.r)) - @as(f32, @floatFromInt(v1.r))) * eased_t),
                        .g = @intFromFloat(@as(f32, @floatFromInt(v1.g)) + (@as(f32, @floatFromInt(v2.g)) - @as(f32, @floatFromInt(v1.g))) * eased_t),
                        .b = @intFromFloat(@as(f32, @floatFromInt(v1.b)) + (@as(f32, @floatFromInt(v2.b)) - @as(f32, @floatFromInt(v1.b))) * eased_t),
                        .a = @intFromFloat(@as(f32, @floatFromInt(v1.a)) + (@as(f32, @floatFromInt(v2.a)) - @as(f32, @floatFromInt(v1.a))) * eased_t),
                    } },
                    else => key1.value,
                },
                .float => |v1| switch (key2.value) {
                    .float => |v2| PropertyValue{ .float = v1 + (v2 - v1) * eased_t },
                    else => key1.value,
                },
                .vector2 => |v1| switch (key2.value) {
                    .vector2 => |v2| PropertyValue{ .vector2 = raylib.Vector2{
                        .x = v1.x + (v2.x - v1.x) * eased_t,
                        .y = v1.y + (v2.y - v1.y) * eased_t,
                    } },
                    else => key1.value,
                },
                .custom => key1.value, // No interpolation for custom values
            };
        }

        /// Apply easing function
        fn applyEasing(self: *const AnimationTrack, t: f32, interpolation: Keyframe.InterpolationType) f32 {
            _ = self;
            return switch (interpolation) {
                .linear => t,
                .smooth => t * t * (3.0 - 2.0 * t), // Smoothstep
                .step => if (t < 1.0) 0.0 else 1.0,
                .ease_in => t * t, // Quadratic ease in
                .ease_out => 1.0 - (1.0 - t) * (1.0 - t), // Quadratic ease out
                .ease_in_out => {
                    const t2 = t * 2.0;
                    if (t2 < 1.0) {
                        return 0.5 * t2 * t2;
                    } else {
                        const t3 = t2 - 1.0;
                        return 0.5 * (1.0 + t3 * (2.0 - t3));
                    }
                },
            };
        }
    };

    /// Active animation instance
    pub const ActiveAnimation = struct {
        id: AnimationId,
        tracks: []TrackId,
        start_time: f32,
        duration: f32,
        loop: bool,
        speed: f32,
        weight: f32,
    };

    /// Timeline configuration
    pub const Timeline = struct {
        current_time: f32,
        total_duration: f32,
        playing: bool,
        loop: bool,
        speed: f32,
    };

    /// Initialize the keyframe system
    pub fn init(allocator: std.mem.Allocator) KeyframeSystem {
        return .{
            .allocator = allocator,
            .tracks = std.ArrayList(AnimationTrack).initCapacity(allocator, 8) catch unreachable,
            .active_animations = std.ArrayList(ActiveAnimation).initCapacity(allocator, 8) catch unreachable,
            .timeline = .{
                .current_time = 0,
                .total_duration = 0,
                .playing = false,
                .loop = false,
                .speed = 1.0,
            },
        };
    }

    /// Deinitialize the keyframe system
    pub fn deinit(self: *KeyframeSystem) void {
        for (self.tracks.items) |*track| {
            track.deinit(self.allocator);
        }
        self.tracks.deinit(self.allocator);
        self.active_animations.deinit(self.allocator);
    }

    /// Create a new animation track
    pub fn createTrack(self: *KeyframeSystem, name: []const u8, target_entity: usize, property_type: PropertyType, property_name: []const u8) !TrackId {
        const id = self.tracks.items.len;
        const track = try AnimationTrack.init(self.allocator, id, name, target_entity, property_type, property_name);
        try self.tracks.append(self.allocator, track);
        return id;
    }

    /// Add a keyframe to a track
    pub fn addKeyframe(self: *KeyframeSystem, track_id: TrackId, time: f32, value: PropertyValue, interpolation: Keyframe.InterpolationType) !void {
        if (track_id >= self.tracks.items.len) return error.InvalidTrackId;
        try self.tracks.items[track_id].addKeyframe(self.allocator, time, value, interpolation);
        self.updateTimelineDuration();
    }

    /// Play an animation
    pub fn playAnimation(self: *KeyframeSystem, track_ids: []const TrackId, loop: bool, speed: f32) !AnimationId {
        const id = self.active_animations.items.len;

        // Calculate duration from tracks
        var max_duration: f32 = 0;
        for (track_ids) |track_id| {
            if (track_id < self.tracks.items.len) {
                const track = &self.tracks.items[track_id];
                if (track.keyframes.items.len > 0) {
                    const last_time = track.keyframes.items[track.keyframes.items.len - 1].time;
                    max_duration = @max(max_duration, last_time);
                }
            }
        }

        const tracks_copy = try self.allocator.dupe(TrackId, track_ids);
        errdefer self.allocator.free(tracks_copy);

        const active_anim = ActiveAnimation{
            .id = id,
            .tracks = tracks_copy,
            .start_time = self.timeline.current_time,
            .duration = max_duration,
            .loop = loop,
            .speed = speed,
            .weight = 1.0,
        };

        try self.active_animations.append(self.allocator, active_anim);
        self.timeline.playing = true;

        return id;
    }

    /// Stop an animation
    pub fn stopAnimation(self: *KeyframeSystem, animation_id: AnimationId) void {
        if (animation_id < self.active_animations.items.len) {
            const anim = &self.active_animations.items[animation_id];
            self.allocator.free(anim.tracks);

            // Remove from active animations
            _ = self.active_animations.orderedRemove(animation_id);
        }
    }

    /// Update the animation system
    pub fn update(self: *KeyframeSystem, dt: f32) void {
        if (!self.timeline.playing) return;

        // Update timeline
        self.timeline.current_time += dt * self.timeline.speed;

        // Handle looping
        if (self.timeline.loop and self.timeline.current_time >= self.timeline.total_duration) {
            self.timeline.current_time = 0;
        }

        // Clamp to duration if not looping
        if (!self.timeline.loop) {
            self.timeline.current_time = @min(self.timeline.current_time, self.timeline.total_duration);
            if (self.timeline.current_time >= self.timeline.total_duration) {
                self.timeline.playing = false;
            }
        }

        // Update active animations
        var i: usize = 0;
        while (i < self.active_animations.items.len) {
            const anim = &self.active_animations.items[i];
            const anim_time = self.timeline.current_time - anim.start_time;

            if (anim.loop or anim_time < anim.duration) {
                // Animation is still active
                i += 1;
            } else {
                // Animation finished, remove it
                self.allocator.free(anim.tracks);
                _ = self.active_animations.orderedRemove(i);
            }
        }
    }

    /// Evaluate all tracks at current time and apply to scene
    pub fn applyToScene(self: *const KeyframeSystem, scene: *nyon.Scene) void {
        for (self.tracks.items) |*track| {
            if (!track.enabled) continue;

            if (track.evaluate(self.timeline.current_time)) |value| {
                self.applyPropertyValueToScene(scene, track.target_entity, track.property_name, value);
            }
        }
    }

    /// Evaluate all tracks at current time and apply to ECS world
    pub fn applyToECS(self: *const KeyframeSystem, world: *nyon.ecs.World, scene_index_to_entity: *const std.AutoHashMap(usize, nyon.ecs.EntityId)) void {
        for (self.tracks.items) |*track| {
            if (!track.enabled) continue;

            if (track.evaluate(self.timeline.current_time)) |value| {
                // Map scene index to entity ID if applicable
                if (scene_index_to_entity.get(track.target_entity)) |entity_id| {
                    self.applyPropertyValueToECS(world, @as(u32, @intCast(entity_id.id)), track.property_name, value);
                } else {
                    // Direct entity ID if track.target_entity is already an entity ID
                    self.applyPropertyValueToECS(world, @as(u32, @intCast(track.target_entity)), track.property_name, value);
                }
            }
        }
    }

    /// Apply a property value to an entity in the scene
    fn applyPropertyValueToScene(self: *const KeyframeSystem, scene: *nyon.Scene, entity_id: usize, property_name: []const u8, value: PropertyValue) void {
        _ = self;

        if (scene.getModelInfo(entity_id) != null) {
            if (std.mem.eql(u8, property_name, "position")) {
                if (value == .position) {
                    scene.setPosition(entity_id, value.position);
                }
            } else if (std.mem.eql(u8, property_name, "rotation")) {
                if (value == .rotation) {
                    scene.setRotation(entity_id, value.rotation);
                }
            } else if (std.mem.eql(u8, property_name, "scale")) {
                if (value == .scale) {
                    scene.setScale(entity_id, value.scale);
                }
            }
        }
    }

    /// Apply a property value to an ECS entity
    fn applyPropertyValueToECS(self: *const KeyframeSystem, world: *nyon.ecs.World, entity_id: u32, property_name: []const u8, value: PropertyValue) void {
        _ = self;

        const eid = nyon.ecs.EntityId{ .id = entity_id, .generation = 0 };
        if (world.getComponent(eid, nyon.ecs.Transform)) |transform| {
            if (std.mem.eql(u8, property_name, "position")) {
                if (value == .position) {
                    transform.position.x = value.position.x;
                    transform.position.y = value.position.y;
                    transform.position.z = value.position.z;
                }
            } else if (std.mem.eql(u8, property_name, "rotation")) {
                if (value == .rotation) {
                    const euler = value.rotation;
                    const cr = @cos(euler.z * 0.5);
                    const sr = @sin(euler.z * 0.5);
                    const cp = @cos(euler.x * 0.5);
                    const sp = @sin(euler.x * 0.5);
                    const cy = @cos(euler.y * 0.5);
                    const sy = @sin(euler.y * 0.5);
                    transform.rotation.w = cr * cp * cy + sr * sp * sy;
                    transform.rotation.x = sr * cp * cy - cr * sp * sy;
                    transform.rotation.y = cr * sp * cy + sr * cp * sy;
                    transform.rotation.z = cr * cp * sy - sr * sp * cy;
                }
            } else if (std.mem.eql(u8, property_name, "scale")) {
                if (value == .scale) {
                    transform.scale.x = value.scale.x;
                    transform.scale.y = value.scale.y;
                    transform.scale.z = value.scale.z;
                }
            }
        }
    }

    /// Update timeline duration based on all tracks
    fn updateTimelineDuration(self: *KeyframeSystem) void {
        var max_time: f32 = 0;
        for (self.tracks.items) |*track| {
            for (track.keyframes.items) |keyframe| {
                max_time = @max(max_time, keyframe.time);
            }
        }
        self.timeline.total_duration = max_time;
    }

    /// Get track by ID
    pub fn getTrack(self: *KeyframeSystem, track_id: TrackId) ?*AnimationTrack {
        if (track_id < self.tracks.items.len) {
            return &self.tracks.items[track_id];
        }
        return null;
    }

    /// Get track count
    pub fn trackCount(self: *const KeyframeSystem) usize {
        return self.tracks.items.len;
    }

    /// Get active animation count
    pub fn activeAnimationCount(self: *const KeyframeSystem) usize {
        return self.active_animations.items.len;
    }
};
