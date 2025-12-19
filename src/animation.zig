const std = @import("std");
const raylib = @import("raylib");

/// Advanced Skeletal Animation System
///
/// Provides high-level animation management with blending, state machines,
/// and integration with the Nyon Game Engine's scene and material systems.
pub const AnimationSystem = struct {
    allocator: std.mem.Allocator,

    /// Animation states for entities
    animation_states: std.AutoHashMap(usize, AnimationState),

    /// Available animations loaded from files
    animations: std.ArrayList(AnimationClip),

    /// Animation blend trees for complex blending
    blend_trees: std.ArrayList(BlendTree),

    pub const AnimationId = usize;
    pub const BlendTreeId = usize;

    /// Animation playback state for an entity
    pub const AnimationState = struct {
        entity_id: usize,
        current_animation: ?AnimationId,
        playback_time: f32,
        speed: f32,
        loop: bool,
        weight: f32, // For blending (0-1)
        fade_time: f32, // For smooth transitions
        fade_duration: f32,
        previous_animation: ?AnimationId,

        pub fn init(entity_id: usize) AnimationState {
            return .{
                .entity_id = entity_id,
                .current_animation = null,
                .playback_time = 0,
                .speed = 1.0,
                .loop = true,
                .weight = 1.0,
                .fade_time = 0,
                .fade_duration = 0,
                .previous_animation = null,
            };
        }
    };

    /// Animation clip loaded from file
    pub const AnimationClip = struct {
        id: AnimationId,
        name: []const u8,
        raylib_animation: raylib.ModelAnimation,
        duration: f32,
        fps: f32,
        bone_count: u32,

        pub fn init(allocator: std.mem.Allocator, id: AnimationId, name: []const u8, animation: raylib.ModelAnimation) !AnimationClip {
            const name_copy = try allocator.dupe(u8, name);
            const frame_count = animation.frameCount;
            const fps = if (animation.frameCount > 0 and animation.frameCount < 1000) 30.0 else 30.0; // Default FPS
            const duration = @as(f32, @floatFromInt(frame_count)) / fps;

            return .{
                .id = id,
                .name = name_copy,
                .raylib_animation = animation,
                .duration = duration,
                .fps = fps,
                .bone_count = animation.boneCount,
            };
        }

        pub fn deinit(self: *AnimationClip, allocator: std.mem.Allocator) void {
            allocator.free(self.name);
            raylib.unloadModelAnimation(self.raylib_animation);
        }
    };

    /// Blend tree for complex animation blending
    pub const BlendTree = struct {
        id: BlendTreeId,
        name: []const u8,
        root_node: BlendNode,

        pub const BlendNodeType = enum {
            animation_clip,
            blend_2d,
            additive,
            layer,
        };

        pub const BlendNode = union(BlendNodeType) {
            animation_clip: struct {
                animation_id: AnimationId,
                speed: f32,
            },
            blend_2d: struct {
                x_param: []const u8,
                y_param: []const u8,
                animations: []BlendPoint,
            },
            additive: struct {
                base_animation: AnimationId,
                additive_animation: AnimationId,
                weight: f32,
            },
            layer: struct {
                layers: []BlendNode,
                blend_mode: enum { override, additive },
            },
        };

        pub const BlendPoint = struct {
            x: f32,
            y: f32,
            animation_id: AnimationId,
        };
    };

    /// Initialize the animation system
    pub fn init(allocator: std.mem.Allocator) AnimationSystem {
        return .{
            .allocator = allocator,
            .animation_states = std.AutoHashMap(usize, AnimationState).init(allocator),
            .animations = std.ArrayList(AnimationClip).init(allocator),
            .blend_trees = std.ArrayList(BlendTree).init(allocator),
        };
    }

    /// Deinitialize the animation system
    pub fn deinit(self: *AnimationSystem) void {
        // Clean up animation states
        self.animation_states.deinit();

        // Clean up animations
        for (self.animations.items) |*anim| {
            anim.deinit(self.allocator);
        }
        self.animations.deinit();

        // Clean up blend trees
        for (self.blend_trees.items) |*tree| {
            self.allocator.free(tree.name);
            // Note: Blend tree cleanup would be more complex in a full implementation
        }
        self.blend_trees.deinit();
    }

    /// Load an animation from file
    pub fn loadAnimation(self: *AnimationSystem, file_path: []const u8, name: []const u8) !AnimationId {
        // Extract animation from model file
        var anim_count: c_uint = 0;
        const temp_animations = raylib.loadModelAnimations(file_path.ptr, &anim_count) catch {
            return error.AnimationLoadFailed;
        };
        defer raylib.unloadModelAnimations(temp_animations, anim_count);

        if (anim_count == 0) {
            return error.NoAnimationsFound;
        }

        // For now, take the first animation (could be extended to load multiple)
        const raylib_anim = temp_animations[0];

        const id = self.animations.items.len;
        const clip = try AnimationClip.init(self.allocator, id, name, raylib_anim);
        try self.animations.append(clip);

        return id;
    }

    /// Create animation state for an entity
    pub fn createAnimationState(self: *AnimationSystem, entity_id: usize) !void {
        const state = AnimationState.init(entity_id);
        try self.animation_states.put(entity_id, state);
    }

    /// Play an animation on an entity
    pub fn playAnimation(self: *AnimationSystem, entity_id: usize, animation_id: AnimationId, fade_duration: f32) !void {
        const state_ptr = self.animation_states.getPtr(entity_id) orelse {
            try self.createAnimationState(entity_id);
            return self.playAnimation(entity_id, animation_id, fade_duration);
        };

        if (state_ptr.current_animation) |current| {
            state_ptr.previous_animation = current;
        }

        state_ptr.current_animation = animation_id;
        state_ptr.playback_time = 0;
        state_ptr.fade_time = 0;
        state_ptr.fade_duration = fade_duration;
        state_ptr.weight = if (fade_duration > 0) 0.0 else 1.0;
    }

    /// Stop animation playback
    pub fn stopAnimation(self: *AnimationSystem, entity_id: usize, fade_duration: f32) void {
        const state_ptr = self.animation_states.getPtr(entity_id) orelse return;

        if (fade_duration > 0) {
            state_ptr.fade_duration = fade_duration;
            state_ptr.fade_time = 0;
        } else {
            state_ptr.current_animation = null;
            state_ptr.previous_animation = null;
        }
    }

    /// Set animation speed
    pub fn setAnimationSpeed(self: *AnimationSystem, entity_id: usize, speed: f32) void {
        const state_ptr = self.animation_states.getPtr(entity_id) orelse return;
        state_ptr.speed = speed;
    }

    /// Set animation loop mode
    pub fn setAnimationLoop(self: *AnimationSystem, entity_id: usize, loop: bool) void {
        const state_ptr = self.animation_states.getPtr(entity_id) orelse return;
        state_ptr.loop = loop;
    }

    /// Update all animations
    pub fn update(self: *AnimationSystem, dt: f32) void {
        var iter = self.animation_states.iterator();
        while (iter.next()) |entry| {
            var state = entry.value_ptr;

            // Update fading
            if (state.fade_duration > 0) {
                state.fade_time += dt;
                const fade_progress = @min(state.fade_time / state.fade_duration, 1.0);

                if (state.previous_animation != null and state.current_animation != null) {
                    // Cross-fading between animations
                    state.weight = fade_progress;
                } else if (state.current_animation != null) {
                    // Fading in
                    state.weight = fade_progress;
                }

                if (fade_progress >= 1.0) {
                    state.fade_duration = 0;
                    state.fade_time = 0;
                    state.previous_animation = null;
                    if (state.current_animation == null) {
                        // Finished fading out
                        state.weight = 0;
                    }
                }
            }

            // Update playback time
            if (state.current_animation) |anim_id| {
                if (anim_id < self.animations.items.len) {
                    const clip = &self.animations.items[anim_id];
                    state.playback_time += dt * state.speed;

                    if (state.loop) {
                        // Loop animation
                        while (state.playback_time >= clip.duration) {
                            state.playback_time -= clip.duration;
                        }
                    } else {
                        // Clamp to end
                        state.playback_time = @min(state.playback_time, clip.duration);
                    }
                }
            }
        }
    }

    /// Apply animation to a model
    pub fn applyAnimationToModel(self: *const AnimationSystem, entity_id: usize, model: *raylib.Model) void {
        const state = self.animation_states.get(entity_id) orelse return;

        if (state.current_animation) |anim_id| {
            if (anim_id < self.animations.items.len) {
                const clip = &self.animations.items[anim_id];

                // Calculate frame index
                const frame_time = state.playback_time * clip.fps;
                const frame_index = @as(c_int, @intFromFloat(@floor(frame_time)));
                const clamped_frame = @min(@max(frame_index, 0), @as(c_int, clip.raylib_animation.frameCount) - 1);

                // Apply animation to model
                raylib.updateModelAnimation(model.*, clip.raylib_animation, clamped_frame);

                // Handle blending with previous animation
                if (state.previous_animation) |prev_id| {
                    if (prev_id < self.animations.items.len) {
                        const prev_clip = &self.animations.items[prev_id];
                        const prev_frame_time = state.playback_time * prev_clip.fps;
                        const prev_frame_index = @as(c_int, @intFromFloat(@floor(prev_frame_time)));
                        const prev_clamped_frame = @min(@max(prev_frame_index, 0), @as(c_int, prev_clip.raylib_animation.frameCount) - 1);

                        // Simple blending - in a full implementation, this would be more sophisticated
                        const blend_weight = 1.0 - state.weight;

                        // Note: Raylib doesn't directly support animation blending
                        // This would require custom bone interpolation
                        _ = prev_clamped_frame;
                        _ = blend_weight;
                    }
                }
            }
        }
    }

    /// Get animation state for an entity
    pub fn getAnimationState(self: *const AnimationSystem, entity_id: usize) ?*const AnimationState {
        return self.animation_states.getPtr(entity_id);
    }

    /// Get animation clip by ID
    pub fn getAnimationClip(self: *const AnimationSystem, animation_id: AnimationId) ?*const AnimationClip {
        if (animation_id < self.animations.items.len) {
            return &self.animations.items[animation_id];
        }
        return null;
    }

    /// Get animation count
    pub fn animationCount(self: *const AnimationSystem) usize {
        return self.animations.items.len;
    }

    /// Get entity count with animations
    pub fn animatedEntityCount(self: *const AnimationSystem) usize {
        return self.animation_states.count();
    }
};
