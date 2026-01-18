//! Game Configuration
//!
//! Centralized configuration for all game balance values.
//! Modify these values to tune gameplay without hunting through code.

/// Player movement configuration
pub const Player = struct {
    // Movement speeds (blocks per second)
    pub const walk_speed: f32 = 4.5;
    pub const run_speed: f32 = 7.0;
    pub const crouch_speed: f32 = 2.0;
    pub const fly_speed: f32 = 10.0;
    pub const fly_fast_speed: f32 = 25.0;
    pub const swim_speed: f32 = 3.0;

    // Jump and physics
    pub const jump_velocity: f32 = 8.0;
    pub const gravity: f32 = 28.0;
    pub const terminal_velocity: f32 = 78.0;

    // Camera
    pub const mouse_sensitivity: f32 = 0.002;
    pub const eye_height: f32 = 1.6;
    pub const crouch_height: f32 = 1.2;

    // Combat
    pub const base_attack_damage: f32 = 5.0;
    pub const attack_cooldown: f32 = 0.5;
    pub const attack_range: f32 = 4.0;
    pub const critical_multiplier: f32 = 1.5;

    // Health and hunger
    pub const max_health: f32 = 20.0;
    pub const max_hunger: f32 = 20.0;
    pub const health_regen_rate: f32 = 0.5; // per second when hunger > 18
    pub const starvation_damage: f32 = 0.5; // per second when hunger = 0
    pub const hunger_drain_base: f32 = 0.01; // per second idle
    pub const hunger_drain_run: f32 = 0.03; // per second while running
    pub const hunger_drain_jump: f32 = 0.02; // per second while airborne

    // Mining
    pub const block_reach: f32 = 5.0;
    pub const place_cooldown: f32 = 0.15;
    pub const min_break_time: f32 = 0.05;
};

/// Combat configuration
pub const Combat = struct {
    // Knockback
    pub const knockback_horizontal: f32 = 8.0;
    pub const knockback_vertical: f32 = 4.0;
    pub const mob_knockback_strength: f32 = 8.0;

    // Invulnerability
    pub const invuln_frames_duration: f32 = 0.5;

    // Critical hits
    pub const critical_fall_threshold: f32 = -0.5; // must be falling faster than this

    // Armor
    pub const armor_reduction_per_point: f32 = 0.04; // 4% per armor point
    pub const max_armor_reduction: f32 = 0.8; // 80% max damage reduction
};

/// Mob configuration
pub const Mobs = struct {
    // Detection and AI
    pub const detection_range: f32 = 16.0;
    pub const melee_attack_range: f32 = 2.0;
    pub const ranged_attack_range: f32 = 10.0;
    pub const flee_range: f32 = 8.0;
    pub const flee_duration: f32 = 3.0;

    // Attack values
    pub const zombie_damage: f32 = 3.0;
    pub const skeleton_damage: f32 = 2.0;
    pub const spider_damage: f32 = 2.0;
    pub const creeper_explosion_radius: f32 = 4.0;

    // Experience drops
    pub const passive_mob_xp: u16 = 3;
    pub const hostile_mob_xp: u16 = 5;
    pub const boss_xp: u16 = 50;

    // Spawn rates
    pub const passive_spawn_chance: f32 = 0.01;
    pub const hostile_spawn_chance: f32 = 0.02;
    pub const spawn_distance_min: f32 = 24.0;
    pub const spawn_distance_max: f32 = 128.0;
    pub const despawn_distance: f32 = 128.0;
};

/// World configuration
pub const World = struct {
    // Chunks
    pub const chunk_size: i32 = 16;
    pub const chunk_height: i32 = 256;
    pub const sea_level: i32 = 64;
    pub const render_distance: i32 = 8;

    // Generation
    pub const terrain_scale: f32 = 0.02;
    pub const height_scale: f32 = 32.0;
    pub const cave_threshold: f32 = 0.55;

    // Day/night cycle
    pub const day_length_seconds: f32 = 600.0; // 10 minutes real time
    pub const night_mob_spawn_multiplier: f32 = 2.0;
};

/// Tool material stats (speed multiplier, durability)
pub const Tools = struct {
    pub const wood_speed: f32 = 1.0;
    pub const wood_durability: u32 = 60;
    pub const stone_speed: f32 = 1.5;
    pub const stone_durability: u32 = 132;
    pub const iron_speed: f32 = 2.0;
    pub const iron_durability: u32 = 251;
    pub const gold_speed: f32 = 3.0;
    pub const gold_durability: u32 = 33;
    pub const diamond_speed: f32 = 2.5;
    pub const diamond_durability: u32 = 1562;
};

/// Experience curve configuration
pub const Experience = struct {
    // Levels 1-16: quadratic with low coefficient
    pub const early_level_a: u32 = 2;
    pub const early_level_b: u32 = 7;
    pub const early_level_max: u32 = 16;

    // Levels 17-31: higher quadratic
    pub const mid_level_a: u32 = 5;
    pub const mid_level_b: i32 = -38;
    pub const mid_level_c: u32 = 360;
    pub const mid_level_max: u32 = 31;

    // Levels 32+: steep quadratic
    pub const late_level_a: u32 = 9;
    pub const late_level_b: i32 = -158;
    pub const late_level_c: u32 = 2220;
};

/// Weather configuration
pub const Weather = struct {
    // Durations (seconds)
    pub const clear_duration_min: f32 = 300.0;
    pub const clear_duration_max: f32 = 900.0;
    pub const rain_duration_min: f32 = 120.0;
    pub const rain_duration_max: f32 = 600.0;
    pub const storm_duration_min: f32 = 60.0;
    pub const storm_duration_max: f32 = 300.0;

    // Transition times
    pub const transition_time: f32 = 30.0;

    // Gameplay effects
    pub const rain_speed_multiplier: f32 = 0.9; // 10% slower in rain
    pub const snow_speed_multiplier: f32 = 0.85; // 15% slower in snow
    pub const storm_visibility_range: f32 = 32.0;
};

/// UI configuration
pub const UI = struct {
    // Hotbar
    pub const hotbar_slot_size: i32 = 40;
    pub const hotbar_padding: i32 = 4;

    // Inventory
    pub const inventory_slot_size: i32 = 36;

    // Text
    pub const chat_display_time: f32 = 5.0;
    pub const tooltip_delay: f32 = 0.3;

    // Save messages
    pub const save_message_duration: f32 = 3.0;
};

/// Audio configuration
pub const Audio = struct {
    pub const master_volume: f32 = 1.0;
    pub const music_volume: f32 = 0.5;
    pub const sfx_volume: f32 = 0.8;
    pub const ambient_volume: f32 = 0.6;

    // Footstep timing
    pub const footstep_interval_walk: f32 = 0.5;
    pub const footstep_interval_run: f32 = 0.3;
};
