//! Enemy System - AI behavior and enemy entities

const std = @import("std");
const engine_mod = @import("../engine.zig");
const state_mod = @import("state.zig");

const Vector2 = engine_mod.Vector2;
const Color = engine_mod.Color;

pub const EnemyType = enum {
    chaser,
    patroller,
    sniper,
    drone,
};

pub const EnemyState = enum {
    idle,
    patrolling,
    chasing,
    attacking,
    fleeing,
    dead,
};

pub const Enemy = struct {
    x: f32,
    y: f32,
    enemy_type: EnemyType,
    state: EnemyState,
    health: f32,
    max_health: f32,
    speed: f32,
    size: f32,
    damage: f32,
    detection_range: f32,
    attack_range: f32,
    attack_cooldown: f32,
    current_cooldown: f32,
    patrol_points: []Vector2,
    current_patrol_index: usize,
    patrol_progress: f32,
    last_seen_player: ?Vector2,
    target_position: Vector2,

    pub fn init(enemy_type: EnemyType, x: f32, y: f32, allocator: std.mem.Allocator) !Enemy {
        const patrol_points = try allocator.alloc(Vector2, 0);
        errdefer allocator.free(patrol_points);

        return Enemy{
            .x = x,
            .y = y,
            .enemy_type = enemy_type,
            .state = .idle,
            .health = getEnemyConfig(enemy_type).base_health,
            .max_health = getEnemyConfig(enemy_type).base_health,
            .speed = getEnemyConfig(enemy_type).base_speed,
            .size = getEnemyConfig(enemy_type).base_size,
            .damage = getEnemyConfig(enemy_type).base_damage,
            .detection_range = getEnemyConfig(enemy_type).detection_range,
            .attack_range = getEnemyConfig(enemy_type).attack_range,
            .attack_cooldown = getEnemyConfig(enemy_type).attack_cooldown,
            .current_cooldown = 0,
            .patrol_points = patrol_points,
            .current_patrol_index = 0,
            .patrol_progress = 0,
            .last_seen_player = null,
            .target_position = Vector2{ .x = x, .y = y },
        };
    }

    pub fn deinit(self: *Enemy, allocator: std.mem.Allocator) void {
        allocator.free(self.patrol_points);
    }

    pub fn update(self: *Enemy, player_x: f32, player_y: f32, delta_time: f32, game_state: *const state_mod.GameState) void {
        if (self.health <= 0) {
            self.state = .dead;
            return;
        }

        const player_pos = Vector2{ .x = player_x, .y = player_y };
        const distance_to_player = std.math.sqrt(std.math.pow(f32, self.x - player_x, 2) +
            std.math.pow(f32, self.y - player_y, 2));

        self.current_cooldown = @max(0, self.current_cooldown - delta_time);

        switch (self.enemy_type) {
            .chaser => self.updateChaser(player_pos, distance_to_player, delta_time),
            .patroller => self.updatePatroller(player_pos, distance_to_player, delta_time),
            .sniper => self.updateSniper(player_pos, distance_to_player, delta_time, game_state),
            .drone => self.updateDrone(player_pos, distance_to_player, delta_time, game_state),
        }
    }

    fn updateChaser(self: *Enemy, player_pos: Vector2, distance_to_player: f32, delta_time: f32) void {
        if (distance_to_player <= self.detection_range) {
            self.state = .chasing;
            self.last_seen_player = player_pos;

            const dx = player_pos.x - self.x;
            const dy = player_pos.y - self.y;
            const distance = @max(0.1, distance_to_player);

            self.x += (dx / distance) * self.speed * delta_time;
            self.y += (dy / distance) * self.speed * delta_time;

            if (distance_to_player <= self.attack_range and self.current_cooldown <= 0) {
                self.state = .attacking;
                self.current_cooldown = self.attack_cooldown;
            }
        } else {
            self.state = .idle;
        }
    }

    fn updatePatroller(self: *Enemy, player_pos: Vector2, distance_to_player: f32, delta_time: f32) void {
        if (distance_to_player <= self.detection_range) {
            self.state = .chasing;
            const dx = player_pos.x - self.x;
            const dy = player_pos.y - self.y;
            const distance = @max(0.1, distance_to_player);

            self.x += (dx / distance) * self.speed * delta_time;
            self.y += (dy / distance) * self.speed * delta_time;

            if (distance_to_player <= self.attack_range and self.current_cooldown <= 0) {
                self.state = .attacking;
                self.current_cooldown = self.attack_cooldown;
            }
        } else {
            self.state = .patrolling;
            self.followPatrolRoute(delta_time);
        }
    }

    fn updateSniper(self: *Enemy, player_pos: Vector2, distance_to_player: f32, delta_time: f32, game_state: *const state_mod.GameState) void {
        _ = delta_time;
        _ = game_state;
        if (distance_to_player <= self.detection_range) {
            self.state = .chasing;
            self.last_seen_player = player_pos;

            if (distance_to_player > self.attack_range and self.current_cooldown <= 0) {
                self.state = .attacking;
                self.current_cooldown = self.attack_cooldown;
            } else {
                self.state = .idle;
            }
        } else {
            self.state = .idle;
        }
    }

    fn updateDrone(self: *Enemy, player_pos: Vector2, distance_to_player: f32, delta_time: f32, game_state: *const state_mod.GameState) void {
        const time = game_state.game_time;
        const offset = @sin(time * 2.0) * 50.0;

        if (distance_to_player <= self.detection_range) {
            self.state = .chasing;
            self.last_seen_player = player_pos;

            const dx = player_pos.x - self.x;
            const dy = player_pos.y - self.y;
            const distance = @max(0.1, distance_to_player);

            self.x += (dx / distance) * self.speed * delta_time;
            self.y += (dy / distance + offset / 100.0) * self.speed * delta_time;

            if (distance_to_player <= self.attack_range and self.current_cooldown <= 0) {
                self.state = .attacking;
                self.current_cooldown = self.attack_cooldown;
            }
        } else {
            self.state = .idle;
            self.y += @sin(time) * 0.5 * delta_time;
        }
    }

    fn followPatrolRoute(self: *Enemy, delta_time: f32) void {
        if (self.patrol_points.len == 0) return;

        const target = self.patrol_points[self.current_patrol_index];
        const dx = target.x - self.x;
        const dy = target.y - self.y;
        const distance = std.math.sqrt(dx * dx + dy * dy);

        if (distance < 10.0) {
            self.current_patrol_index = (self.current_patrol_index + 1) % self.patrol_points.len;
        } else {
            self.x += (dx / distance) * (self.speed * 0.5) * delta_time;
            self.y += (dy / distance) * (self.speed * 0.5) * delta_time;
        }
    }

    pub fn takeDamage(self: *Enemy, damage: f32) bool {
        self.health -= damage;
        return self.health <= 0;
    }

    pub fn canAttack(self: *Enemy) bool {
        return self.current_cooldown <= 0 and self.state == .attacking;
    }

    pub fn getAttackDamage(self: *Enemy) f32 {
        self.current_cooldown = self.attack_cooldown;
        return self.damage;
    }
};

pub const EnemyConfig = struct {
    base_health: f32,
    base_speed: f32,
    base_size: f32,
    base_damage: f32,
    detection_range: f32,
    attack_range: f32,
    attack_cooldown: f32,
    color: Color,
};

pub fn getEnemyConfig(enemy_type: EnemyType) EnemyConfig {
    return switch (enemy_type) {
        .chaser => EnemyConfig{
            .base_health = 50.0,
            .base_speed = 150.0,
            .base_size = 20.0,
            .base_damage = 10.0,
            .detection_range = 300.0,
            .attack_range = 25.0,
            .attack_cooldown = 1.0,
            .color = Color{ .r = 255, .g = 50, .b = 50, .a = 255 },
        },
        .patroller => EnemyConfig{
            .base_health = 75.0,
            .base_speed = 80.0,
            .base_size = 25.0,
            .base_damage = 15.0,
            .detection_range = 250.0,
            .attack_range = 30.0,
            .attack_cooldown = 1.5,
            .color = Color{ .r = 255, .g = 150, .b = 50, .a = 255 },
        },
        .sniper => EnemyConfig{
            .base_health = 30.0,
            .base_speed = 50.0,
            .base_size = 18.0,
            .base_damage = 25.0,
            .detection_range = 400.0,
            .attack_range = 350.0,
            .attack_cooldown = 2.0,
            .color = Color{ .r = 150, .g = 50, .b = 255, .a = 255 },
        },
        .drone => EnemyConfig{
            .base_health = 40.0,
            .base_speed = 120.0,
            .base_size = 15.0,
            .base_damage = 8.0,
            .detection_range = 200.0,
            .attack_range = 20.0,
            .attack_cooldown = 0.8,
            .color = Color{ .r = 50, .g = 255, .b = 200, .a = 255 },
        },
    };
}

pub fn drawEnemy(enemy: *const Enemy, game_time: f32) void {
    if (enemy.state == .dead) return;

    const config = getEnemyConfig(enemy.enemy_type);
    const pulse = @sin(game_time * 3.0) * 2.0;
    const size = enemy.size + pulse;

    engine_mod.Shapes.drawCircle(
        @intFromFloat(enemy.x),
        @intFromFloat(enemy.y),
        size,
        config.color,
    );

    engine_mod.Shapes.drawCircleLines(
        @intFromFloat(enemy.x),
        @intFromFloat(enemy.y),
        size,
        Color{ .r = 255, .g = 255, .b = 255, .a = 200 },
    );

    const health_bar_width = 40.0;
    const health_bar_height = 4.0;
    const health_percent = enemy.health / enemy.max_health;

    const health_x = enemy.x - health_bar_width / 2;
    const health_y = enemy.y - enemy.size - 10;

    engine_mod.Shapes.drawRectangle(
        @intFromFloat(health_x),
        @intFromFloat(health_y),
        @intFromFloat(health_bar_width),
        @intFromFloat(health_bar_height),
        Color{ .r = 50, .g = 50, .b = 50, .a = 200 },
    );

    engine_mod.Shapes.drawRectangle(
        @intFromFloat(health_x),
        @intFromFloat(health_y),
        @intFromFloat(health_bar_width * health_percent),
        @intFromFloat(health_bar_height),
        if (health_percent > 0.6) Color{ .r = 0, .g = 255, .b = 0, .a = 255 } else if (health_percent > 0.3) Color{ .r = 255, .g = 255, .b = 0, .a = 255 } else Color{ .r = 255, .g = 0, .b = 0, .a = 255 },
    );

    if (enemy.state == .chasing) {
        engine_mod.Shapes.drawCircleLines(
            @intFromFloat(enemy.x),
            @intFromFloat(enemy.y),
            enemy.detection_range,
            Color{ .r = 255, .g = 0, .b = 0, .a = 50 },
        );
    }
}
