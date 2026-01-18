//! Core Components for Entity Component System
//!
//! Defines component types for mobs, NPCs, and other game entities.
//! Components are data-only structures attached to entities.

const std = @import("std");
const math = @import("../math/math.zig");
const collision = @import("../physics/collision.zig");

// Re-export base ECS components
const ecs_component = @import("../ecs/component.zig");
pub const Transform = ecs_component.Transform;
pub const Velocity = ecs_component.Velocity;
pub const Name = ecs_component.Name;

/// Health component for damageable entities
pub const Health = struct {
    current: f32 = 100.0,
    max: f32 = 100.0,
    regen_rate: f32 = 0.0,
    invulnerable: bool = false,
    /// Time remaining for invulnerability frames
    invuln_timer: f32 = 0.0,

    const Self = @This();

    pub fn init(max_hp: f32) Self {
        return .{
            .current = max_hp,
            .max = max_hp,
        };
    }

    pub fn damage(self: *Self, amount: f32) bool {
        if (self.invulnerable or self.invuln_timer > 0) return false;
        self.current = @max(0, self.current - amount);
        return self.current <= 0;
    }

    pub fn heal(self: *Self, amount: f32) void {
        self.current = @min(self.max, self.current + amount);
    }

    pub fn isDead(self: *const Self) bool {
        return self.current <= 0;
    }

    pub fn percent(self: *const Self) f32 {
        if (self.max <= 0) return 0;
        return self.current / self.max;
    }
};

/// AI behavior types
pub const AIBehavior = enum(u8) {
    idle, // Stand still
    wander, // Random movement within radius
    follow, // Follow target entity
    flee, // Run from target
    patrol, // Move between waypoints
    hostile, // Attack player on sight
    passive, // Peaceful, flees when attacked

    pub fn getName(self: AIBehavior) []const u8 {
        return switch (self) {
            .idle => "Idle",
            .wander => "Wander",
            .follow => "Follow",
            .flee => "Flee",
            .patrol => "Patrol",
            .hostile => "Hostile",
            .passive => "Passive",
        };
    }
};

/// AI state machine states
pub const AIState = enum(u8) {
    idle,
    moving,
    attacking,
    fleeing,
    dead,
    stunned,

    pub fn getName(self: AIState) []const u8 {
        return switch (self) {
            .idle => "Idle",
            .moving => "Moving",
            .attacking => "Attacking",
            .fleeing => "Fleeing",
            .dead => "Dead",
            .stunned => "Stunned",
        };
    }
};

/// AI component for behavior control
pub const AI = struct {
    behavior: AIBehavior = .idle,
    state: AIState = .idle,
    /// Target entity for follow/attack behaviors
    target: ?u64 = null,
    /// Home position for wander behavior
    home_position: math.Vec3 = math.Vec3.ZERO,
    /// Maximum distance from home for wander
    wander_radius: f32 = 10.0,
    /// Detection range for player/threats
    detection_range: f32 = 16.0,
    /// Range at which entity can attack
    attack_range: f32 = 2.0,
    /// Damage dealt per attack
    attack_damage: f32 = 10.0,
    /// Cooldown between attacks (seconds)
    attack_cooldown: f32 = 1.0,
    /// Current attack timer
    attack_timer: f32 = 0.0,
    /// Movement speed multiplier
    speed: f32 = 1.0,
    /// Timer for state transitions
    state_timer: f32 = 0.0,
    /// Current movement target
    move_target: math.Vec3 = math.Vec3.ZERO,
    /// Whether entity has valid move target
    has_move_target: bool = false,

    const Self = @This();

    pub fn setTarget(self: *Self, target_hash: u64) void {
        self.target = target_hash;
    }

    pub fn clearTarget(self: *Self) void {
        self.target = null;
    }

    pub fn canAttack(self: *const Self) bool {
        return self.attack_timer <= 0;
    }

    pub fn resetAttackCooldown(self: *Self) void {
        self.attack_timer = self.attack_cooldown;
    }
};

/// Mesh types for rendering
pub const MeshType = enum(u8) {
    cube,
    sphere,
    cylinder,
    capsule,
    quad,
    custom,

    pub fn getName(self: MeshType) []const u8 {
        return switch (self) {
            .cube => "Cube",
            .sphere => "Sphere",
            .cylinder => "Cylinder",
            .capsule => "Capsule",
            .quad => "Quad",
            .custom => "Custom",
        };
    }
};

/// Color for rendering (RGBA)
pub const Color = packed struct {
    r: u8 = 255,
    g: u8 = 255,
    b: u8 = 255,
    a: u8 = 255,

    pub const WHITE = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
    pub const BLACK = Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
    pub const RED = Color{ .r = 255, .g = 0, .b = 0, .a = 255 };
    pub const GREEN = Color{ .r = 0, .g = 255, .b = 0, .a = 255 };
    pub const BLUE = Color{ .r = 0, .g = 0, .b = 255, .a = 255 };
    pub const PINK = Color{ .r = 255, .g = 192, .b = 203, .a = 255 };
    pub const BROWN = Color{ .r = 139, .g = 90, .b = 43, .a = 255 };
    pub const DARK_GREEN = Color{ .r = 0, .g = 100, .b = 0, .a = 255 };
    pub const LIGHT_GRAY = Color{ .r = 200, .g = 200, .b = 200, .a = 255 };
    pub const GRAY = Color{ .r = 128, .g = 128, .b = 128, .a = 255 };
    pub const YELLOW = Color{ .r = 255, .g = 255, .b = 0, .a = 255 };
    pub const ORANGE = Color{ .r = 255, .g = 165, .b = 0, .a = 255 };

    pub fn fromRgb(r: u8, g: u8, b: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = 255 };
    }

    pub fn fromRgba(r: u8, g: u8, b: u8, a: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn toFloat(self: Color) [4]f32 {
        return .{
            @as(f32, @floatFromInt(self.r)) / 255.0,
            @as(f32, @floatFromInt(self.g)) / 255.0,
            @as(f32, @floatFromInt(self.b)) / 255.0,
            @as(f32, @floatFromInt(self.a)) / 255.0,
        };
    }
};

/// Render component for visual representation
pub const Render = struct {
    mesh_type: MeshType = .cube,
    color: Color = Color.WHITE,
    scale: math.Vec3 = math.Vec3.ONE,
    visible: bool = true,
    cast_shadows: bool = true,

    const Self = @This();

    pub fn cube(color: Color, size: f32) Self {
        return .{
            .mesh_type = .cube,
            .color = color,
            .scale = math.Vec3.init(size, size, size),
        };
    }

    pub fn box(color: Color, sx: f32, sy: f32, sz: f32) Self {
        return .{
            .mesh_type = .cube,
            .color = color,
            .scale = math.Vec3.init(sx, sy, sz),
        };
    }
};

/// Collider component for physics interactions
pub const Collider = struct {
    half_extents: math.Vec3 = math.Vec3.init(0.5, 0.5, 0.5),
    offset: math.Vec3 = math.Vec3.ZERO,
    is_trigger: bool = false,
    layer: u8 = 0,
    /// Collision mask (which layers to collide with)
    mask: u8 = 0xFF,

    const Self = @This();

    /// Get AABB in world space given entity position
    pub fn getWorldAABB(self: *const Self, position: math.Vec3) collision.AABB {
        const center = math.Vec3.add(position, self.offset);
        return collision.AABB.fromCenterExtents(center, self.half_extents);
    }

    pub fn box(hx: f32, hy: f32, hz: f32) Self {
        return .{ .half_extents = math.Vec3.init(hx, hy, hz) };
    }

    pub fn cube(half_size: f32) Self {
        return .{ .half_extents = math.Vec3.init(half_size, half_size, half_size) };
    }
};

/// Inventory slot
pub const ItemStack = struct {
    item_id: u16 = 0,
    count: u16 = 0,

    pub fn isEmpty(self: *const ItemStack) bool {
        return self.count == 0 or self.item_id == 0;
    }
};

/// Inventory component for entities that can hold items
pub const Inventory = struct {
    slots: [36]ItemStack = [_]ItemStack{.{}} ** 36,
    selected_slot: u8 = 0,

    const Self = @This();

    pub fn getSelectedItem(self: *const Self) ?*const ItemStack {
        if (self.selected_slot >= self.slots.len) return null;
        const slot = &self.slots[self.selected_slot];
        if (slot.isEmpty()) return null;
        return slot;
    }

    pub fn addItem(self: *Self, item_id: u16, count: u16) bool {
        // First try to stack with existing items
        for (&self.slots) |*slot| {
            if (slot.item_id == item_id and slot.count > 0) {
                slot.count += count;
                return true;
            }
        }
        // Find empty slot
        for (&self.slots) |*slot| {
            if (slot.isEmpty()) {
                slot.item_id = item_id;
                slot.count = count;
                return true;
            }
        }
        return false;
    }
};

/// Mob type identifier
pub const MobType = enum(u8) {
    // Passive mobs
    pig,
    cow,
    chicken,
    sheep,
    // Hostile mobs
    zombie,
    skeleton,
    creeper,
    spider,
    // NPCs
    villager,
    // Special
    player,
    custom,

    pub fn getName(self: MobType) []const u8 {
        return switch (self) {
            .pig => "Pig",
            .cow => "Cow",
            .chicken => "Chicken",
            .sheep => "Sheep",
            .zombie => "Zombie",
            .skeleton => "Skeleton",
            .creeper => "Creeper",
            .spider => "Spider",
            .villager => "Villager",
            .player => "Player",
            .custom => "Custom",
        };
    }

    pub fn isHostile(self: MobType) bool {
        return switch (self) {
            .zombie, .skeleton, .creeper, .spider => true,
            else => false,
        };
    }

    pub fn isPassive(self: MobType) bool {
        return switch (self) {
            .pig, .cow, .chicken, .sheep, .villager => true,
            else => false,
        };
    }
};

/// Mob tag component for mob-specific data
pub const Mob = struct {
    mob_type: MobType = .custom,
    /// Time since spawn
    age: f32 = 0,
    /// Whether mob is a baby
    is_baby: bool = false,
    /// Time until despawn (-1 for never)
    despawn_timer: f32 = -1,
    /// Experience dropped on death
    experience: u16 = 0,

    const Self = @This();

    pub fn init(mob_type: MobType) Self {
        return .{ .mob_type = mob_type };
    }
};

/// Physics body component for movement
pub const PhysicsBody = struct {
    /// Whether entity is affected by gravity
    use_gravity: bool = true,
    /// Whether entity is currently on ground
    grounded: bool = false,
    /// Gravity multiplier
    gravity_scale: f32 = 1.0,
    /// Drag coefficient
    drag: f32 = 0.1,
    /// Jump velocity
    jump_velocity: f32 = 8.0,
    /// Movement speed
    move_speed: f32 = 4.0,
    /// Mass for physics calculations
    mass: f32 = 1.0,

    const Self = @This();

    pub fn init() Self {
        return .{};
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Health component" {
    var health = Health.init(100);

    try std.testing.expect(!health.isDead());
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), health.percent(), 0.001);

    const killed = health.damage(50);
    try std.testing.expect(!killed);
    try std.testing.expectApproxEqAbs(@as(f32, 50), health.current, 0.001);

    health.heal(25);
    try std.testing.expectApproxEqAbs(@as(f32, 75), health.current, 0.001);

    const killed2 = health.damage(100);
    try std.testing.expect(killed2);
    try std.testing.expect(health.isDead());
}

test "AI component" {
    var ai = AI{};
    ai.behavior = .hostile;
    ai.detection_range = 20.0;

    try std.testing.expect(ai.canAttack());
    ai.resetAttackCooldown();
    try std.testing.expect(!ai.canAttack());
}

test "Collider AABB" {
    const collider = Collider.box(0.5, 1.0, 0.5);
    const pos = math.Vec3.init(10, 5, 10);
    const aabb = collider.getWorldAABB(pos);

    try std.testing.expectApproxEqAbs(@as(f32, 9.5), aabb.min.x(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), aabb.min.y(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.5), aabb.max.x(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), aabb.max.y(), 0.001);
}

test "Inventory" {
    var inv = Inventory{};

    try std.testing.expect(inv.addItem(1, 10));
    try std.testing.expect(inv.addItem(1, 5)); // Stack

    try std.testing.expectEqual(@as(u16, 15), inv.slots[0].count);
}
