//! Power-Up System - Collectible items with various effects

const std = @import("std");
const engine_mod = @import("../engine.zig");
const state_mod = @import("state.zig");

const Vector2 = engine_mod.Vector2;
const Color = engine_mod.Color;

pub const PowerUpType = enum {
    health_boost,
    speed_boost,
    damage_boost,
    shield,
    magnet,
    invincibility,
    double_points,
    time_freeze,
};

pub const PowerUp = struct {
    x: f32,
    y: f32,
    power_up_type: PowerUpType,
    size: f32,
    active: bool,
    spawn_time: f32,
    duration: f32,
    rotation: f32,
    collected_by_player: bool,
    effect_end_time: f32,

    pub fn init(power_up_type: PowerUpType, x: f32, y: f32, game_time: f32) PowerUp {
        return PowerUp{
            .x = x,
            .y = y,
            .power_up_type = power_up_type,
            .size = getPowerUpConfig(power_up_type).size,
            .active = true,
            .spawn_time = game_time,
            .duration = getPowerUpConfig(power_up_type).duration,
            .rotation = 0,
            .collected_by_player = false,
            .effect_end_time = 0,
        };
    }

    pub fn update(self: *PowerUp, game_time: f32, delta_time: f32) void {
        self.rotation += delta_time * 2.0;

        if (self.collected_by_player and game_time >= self.effect_end_time) {
            self.active = false;
        }
    }

    pub fn collect(self: *PowerUp, game_time: f32) void {
        self.collected_by_player = true;
        self.effect_end_time = game_time + self.duration;
    }

    pub fn isEffectActive(self: *const PowerUp, game_time: f32) bool {
        return self.collected_by_player and game_time < self.effect_end_time;
    }

    pub fn getEffectRemaining(self: *const PowerUp, game_time: f32) f32 {
        if (!self.collected_by_player) return 0;
        return @max(0, self.effect_end_time - game_time);
    }
};

pub const PowerUpConfig = struct {
    size: f32,
    duration: f32,
    color: Color,
    glow_color: Color,
    rarity: u8,
};

pub fn getPowerUpConfig(power_up_type: PowerUpType) PowerUpConfig {
    return switch (power_up_type) {
        .health_boost => PowerUpConfig{
            .size = 15.0,
            .duration = 0,
            .color = Color{ .r = 255, .g = 100, .b = 100, .a = 255 },
            .glow_color = Color{ .r = 255, .g = 50, .b = 50, .a = 150 },
            .rarity = 2,
        },
        .speed_boost => PowerUpConfig{
            .size = 15.0,
            .duration = 10.0,
            .color = Color{ .r = 100, .g = 255, .b = 100, .a = 255 },
            .glow_color = Color{ .r = 50, .g = 255, .b = 50, .a = 150 },
            .rarity = 1,
        },
        .damage_boost => PowerUpConfig{
            .size = 15.0,
            .duration = 15.0,
            .color = Color{ .r = 255, .g = 50, .b = 50, .a = 255 },
            .glow_color = Color{ .r = 255, .g = 0, .b = 0, .a = 150 },
            .rarity = 2,
        },
        .shield => PowerUpConfig{
            .size = 15.0,
            .duration = 8.0,
            .color = Color{ .r = 100, .g = 100, .b = 255, .a = 255 },
            .glow_color = Color{ .r = 50, .g = 50, .b = 255, .a = 150 },
            .rarity = 2,
        },
        .magnet => PowerUpConfig{
            .size = 15.0,
            .duration = 12.0,
            .color = Color{ .r = 255, .g = 255, .b = 100, .a = 255 },
            .glow_color = Color{ .r = 255, .g = 255, .b = 50, .a = 150 },
            .rarity = 1,
        },
        .invincibility => PowerUpConfig{
            .size = 15.0,
            .duration = 5.0,
            .color = Color{ .r = 255, .g = 215, .b = 0, .a = 255 },
            .glow_color = Color{ .r = 255, .g = 200, .b = 0, .a = 150 },
            .rarity = 3,
        },
        .double_points => PowerUpConfig{
            .size = 15.0,
            .duration = 20.0,
            .color = Color{ .r = 255, .g = 150, .b = 255, .a = 255 },
            .glow_color = Color{ .r = 255, .g = 100, .b = 255, .a = 150 },
            .rarity = 2,
        },
        .time_freeze => PowerUpConfig{
            .size = 15.0,
            .duration = 5.0,
            .color = Color{ .r = 150, .g = 255, .b = 255, .a = 255 },
            .glow_color = Color{ .r = 100, .g = 255, .b = 255, .a = 150 },
            .rarity = 3,
        },
    };
}

pub const PlayerPowerUps = struct {
    health_boost_active: bool = false,
    speed_boost_active: bool = false,
    damage_boost_active: bool = false,
    shield_active: bool = false,
    magnet_active: bool = false,
    invincibility_active: bool = false,
    double_points_active: bool = false,
    time_freeze_active: bool = false,

    speed_multiplier: f32 = 1.0,
    damage_multiplier: f32 = 1.0,
    score_multiplier: f32 = 1.0,
    shield_health: f32 = 0,

    pub fn reset(self: *PlayerPowerUps) void {
        self.* = PlayerPowerUps{};
    }

    pub fn applyPowerUp(self: *PlayerPowerUps, power_up_type: PowerUpType, game_time: f32, power_up: *const PowerUp) void {
        _ = power_up.getEffectRemaining(game_time);

        switch (power_up_type) {
            .health_boost => {
                self.health_boost_active = true;
            },
            .speed_boost => {
                self.speed_boost_active = true;
                self.speed_multiplier = 1.5;
            },
            .damage_boost => {
                self.damage_boost_active = true;
                self.damage_multiplier = 2.0;
            },
            .shield => {
                self.shield_active = true;
                self.shield_health = 50.0;
            },
            .magnet => {
                self.magnet_active = true;
            },
            .invincibility => {
                self.invincibility_active = true;
            },
            .double_points => {
                self.double_points_active = true;
                self.score_multiplier = 2.0;
            },
            .time_freeze => {
                self.time_freeze_active = true;
            },
        }
    }

    pub fn update(self: *PlayerPowerUps, power_ups: []const PowerUp, game_time: f32) void {
        var has_speed = false;
        var has_damage = false;
        var has_double = false;

        for (power_ups) |*power_up| {
            if (power_up.isEffectActive(game_time)) {
                switch (power_up.power_up_type) {
                    .speed_boost => has_speed = true,
                    .damage_boost => has_damage = true,
                    .double_points => has_double = true,
                    .health_boost => self.health_boost_active = true,
                    .shield => self.shield_active = true,
                    .magnet => self.magnet_active = true,
                    .invincibility => self.invincibility_active = true,
                    .time_freeze => self.time_freeze_active = true,
                }
            }
        }

        if (!has_speed) {
            self.speed_boost_active = false;
            self.speed_multiplier = 1.0;
        }

        if (!has_damage) {
            self.damage_boost_active = false;
            self.damage_multiplier = 1.0;
        }

        if (!has_double) {
            self.double_points_active = false;
            self.score_multiplier = 1.0;
        }
    }

    pub fn getEffectiveSpeed(self: *const PlayerPowerUps, base_speed: f32) f32 {
        return base_speed * self.speed_multiplier;
    }

    pub fn getEffectiveDamage(self: *const PlayerPowerUps, base_damage: f32) f32 {
        return base_damage * self.damage_multiplier;
    }

    pub fn getEffectiveScore(self: *const PlayerPowerUps, base_score: f32) f32 {
        return base_score * self.score_multiplier;
    }

    pub fn takeDamage(self: *PlayerPowerUps, damage: f32) f32 {
        if (self.invincibility_active) return 0;

        if (self.shield_active and self.shield_health > 0) {
            const shield_damage = @min(damage, self.shield_health);
            self.shield_health -= shield_damage;
            if (self.shield_health <= 0) {
                self.shield_active = false;
                self.shield_health = 0;
            }
            return damage - shield_damage;
        }

        return damage;
    }
};

pub fn drawPowerUp(power_up: *const PowerUp, game_time: f32) void {
    if (!power_up.active) return;

    const config = getPowerUpConfig(power_up.power_up_type);
    const pulse = @sin(game_time * 4.0) * 3.0;
    const size = power_up.size + pulse;

    engine_mod.Shapes.drawCircle(
        @intFromFloat(power_up.x),
        @intFromFloat(power_up.y),
        size + 5,
        config.glow_color,
    );

    engine_mod.Shapes.drawCircle(
        @intFromFloat(power_up.x),
        @intFromFloat(power_up.y),
        size,
        config.color,
    );

    const symbol_size = size * 0.6;
    const symbol_color = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };

    switch (power_up.power_up_type) {
        .health_boost => {
            engine_mod.Shapes.drawCircle(
                @intFromFloat(power_up.x),
                @intFromFloat(power_up.y - symbol_size / 4),
                symbol_size / 2,
                symbol_color,
            );
        },
        .speed_boost => {
            engine_mod.Shapes.drawCircle(
                @intFromFloat(power_up.x),
                @intFromFloat(power_up.y),
                symbol_size / 2,
                symbol_color,
            );
            engine_mod.Shapes.drawCircle(
                @intFromFloat(power_up.x),
                @intFromFloat(power_up.y),
                symbol_size / 4,
                Color{ .r = 0, .g = 0, .b = 0, .a = 255 },
            );
        },
        .damage_boost => {
            const points = [4]Vector2{
                Vector2{ .x = power_up.x, .y = power_up.y - symbol_size },
                Vector2{ .x = power_up.x - symbol_size, .y = power_up.y },
                Vector2{ .x = power_up.x, .y = power_up.y + symbol_size },
                Vector2{ .x = power_up.x + symbol_size, .y = power_up.y },
            };
            for (points, 0..) |p, i| {
                if (i < points.len - 1) {
                    engine_mod.Shapes.drawLine(
                        @intFromFloat(p.x),
                        @intFromFloat(p.y),
                        @intFromFloat(points[i + 1].x),
                        @intFromFloat(points[i + 1].y),
                        symbol_color,
                    );
                }
            }
        },
        .shield => {
            engine_mod.Shapes.drawCircleLines(
                @intFromFloat(power_up.x),
                @intFromFloat(power_up.y),
                symbol_size,
                symbol_color,
            );
            engine_mod.Shapes.drawCircleLines(
                @intFromFloat(power_up.x),
                @intFromFloat(power_up.y),
                symbol_size / 2,
                symbol_color,
            );
        },
        .magnet => {
            engine_mod.Shapes.drawCircle(
                @intFromFloat(power_up.x - symbol_size / 2),
                @intFromFloat(power_up.y),
                symbol_size / 3,
                symbol_color,
            );
            engine_mod.Shapes.drawCircle(
                @intFromFloat(power_up.x + symbol_size / 2),
                @intFromFloat(power_up.y),
                symbol_size / 3,
                symbol_color,
            );
        },
        .invincibility => {
            const star_points = [5]Vector2{
                Vector2{ .x = power_up.x, .y = power_up.y - symbol_size },
                Vector2{ .x = power_up.x + symbol_size * 0.3, .y = power_up.y - symbol_size * 0.3 },
                Vector2{ .x = power_up.x + symbol_size, .y = power_up.y },
                Vector2{ .x = power_up.x + symbol_size * 0.3, .y = power_up.y + symbol_size * 0.3 },
                Vector2{ .x = power_up.x, .y = power_up.y + symbol_size },
            };
            for (star_points, 0..) |p, i| {
                const next_i = (i + 2) % star_points.len;
                engine_mod.Shapes.drawLine(
                    @intFromFloat(p.x),
                    @intFromFloat(p.y),
                    @intFromFloat(star_points[next_i].x),
                    @intFromFloat(star_points[next_i].y),
                    symbol_color,
                );
            }
        },
        .double_points => {
            engine_mod.Shapes.drawCircle(
                @intFromFloat(power_up.x - symbol_size / 2),
                @intFromFloat(power_up.y - symbol_size / 2),
                symbol_size / 3,
                symbol_color,
            );
            engine_mod.Shapes.drawCircle(
                @intFromFloat(power_up.x + symbol_size / 2),
                @intFromFloat(power_up.y + symbol_size / 2),
                symbol_size / 3,
                symbol_color,
            );
        },
        .time_freeze => {
            engine_mod.Shapes.drawCircleLines(
                @intFromFloat(power_up.x),
                @intFromFloat(power_up.y),
                symbol_size,
                symbol_color,
            );
            for (0..12) |i| {
                const angle = @as(f32, @floatFromInt(i)) * std.math.pi / 6.0;
                const end_x = power_up.x + @cos(angle) * symbol_size;
                const end_y = power_up.y + @sin(angle) * symbol_size;
                engine_mod.Shapes.drawLine(
                    @intFromFloat(power_up.x),
                    @intFromFloat(power_up.y),
                    @intFromFloat(end_x),
                    @intFromFloat(end_y),
                    symbol_color,
                );
            }
        },
    }
}

pub fn spawnRandomPowerUp(x: f32, y: f32, game_time: f32, rng: *std.rand.DefaultPrng) PowerUp {
    const types = [_]PowerUpType{
        .health_boost,
        .speed_boost,
        .damage_boost,
        .shield,
        .magnet,
        .invincibility,
        .double_points,
        .time_freeze,
    };

    const config_values = [_]u8{
        getPowerUpConfig(.health_boost).rarity,
        getPowerUpConfig(.speed_boost).rarity,
        getPowerUpConfig(.damage_boost).rarity,
        getPowerUpConfig(.shield).rarity,
        getPowerUpConfig(.magnet).rarity,
        getPowerUpConfig(.invincibility).rarity,
        getPowerUpConfig(.double_points).rarity,
        getPowerUpConfig(.time_freeze).rarity,
    };

    var total_weight: u32 = 0;
    for (config_values) |rarity| {
        total_weight += @as(u32, 4 - rarity);
    }

    const random_value = rng.random().uintLessThan(u32, total_weight);
    var selected_type = PowerUpType.health_boost;
    var current_weight: u32 = 0;

    for (types, config_values) |power_up_type, rarity| {
        const weight = @as(u32, 4 - rarity);
        if (random_value < current_weight + weight) {
            selected_type = power_up_type;
            break;
        }
        current_weight += weight;
    }

    return PowerUp.init(selected_type, x, y, game_time);
}
