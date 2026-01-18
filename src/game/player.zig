//! Player Controller
//!
//! First-person player movement and camera control.

const std = @import("std");
const math = @import("../math/math.zig");
const physics = @import("../physics/physics.zig");
const input = @import("../platform/input.zig");

/// Player movement configuration
pub const Config = struct {
    pub const WALK_SPEED: f32 = 4.5;
    pub const RUN_SPEED: f32 = 7.0;
    pub const CROUCH_SPEED: f32 = 2.0;
    pub const FLY_SPEED: f32 = 10.0;
    pub const FLY_FAST_SPEED: f32 = 25.0;
    pub const JUMP_VELOCITY: f32 = 8.0;
    pub const MOUSE_SENSITIVITY: f32 = 0.002;
    pub const EYE_HEIGHT: f32 = 1.6;
    pub const CROUCH_HEIGHT: f32 = 1.2;
};

/// Player controller component
pub const PlayerController = struct {
    // Position and orientation
    position: math.Vec3 = math.Vec3.init(0, 10, 0),
    yaw: f32 = 0,
    pitch: f32 = 0,

    // Physics
    velocity: math.Vec3 = math.Vec3.ZERO,
    is_grounded: bool = false,
    is_crouching: bool = false,
    is_running: bool = false,
    is_flying: bool = false,

    // Collider
    collider: physics.Collider = physics.Collider.player(),

    // Input state
    wish_dir: math.Vec3 = math.Vec3.ZERO,
    wish_jump: bool = false,
    wish_fly_up: bool = false,
    wish_fly_down: bool = false,

    // Double-tap detection for flight toggle
    last_jump_time: f64 = 0,
    double_tap_window: f64 = 0.3, // 300ms window for double tap

    // External modifiers (weather, effects, etc.)
    speed_multiplier: f32 = 1.0,

    /// Get eye position (camera position)
    pub fn getEyePosition(self: *const PlayerController) math.Vec3 {
        const height = if (self.is_crouching) Config.CROUCH_HEIGHT else Config.EYE_HEIGHT;
        return math.Vec3.add(self.position, math.Vec3.init(0, height, 0));
    }

    /// Get forward direction (horizontal only)
    pub fn getForward(self: *const PlayerController) math.Vec3 {
        return math.Vec3.init(
            @sin(self.yaw),
            0,
            @cos(self.yaw),
        );
    }

    /// Get right direction
    pub fn getRight(self: *const PlayerController) math.Vec3 {
        return math.Vec3.init(
            @cos(self.yaw),
            0,
            -@sin(self.yaw),
        );
    }

    /// Get look direction (with pitch)
    pub fn getLookDirection(self: *const PlayerController) math.Vec3 {
        return math.Vec3.init(
            @sin(self.yaw) * @cos(self.pitch),
            @sin(self.pitch),
            @cos(self.yaw) * @cos(self.pitch),
        );
    }

    /// Get view matrix for rendering
    pub fn getViewMatrix(self: *const PlayerController) math.Mat4 {
        const eye = self.getEyePosition();
        const forward = self.getLookDirection();
        const target = math.Vec3.add(eye, forward);
        return math.Mat4.lookAt(eye, target, math.Vec3.UP);
    }

    /// Process input
    pub fn processInput(self: *PlayerController, input_state: *const input.State, mouse_dx: i32, mouse_dy: i32) void {
        // Mouse look
        self.yaw -= @as(f32, @floatFromInt(mouse_dx)) * Config.MOUSE_SENSITIVITY;
        self.pitch -= @as(f32, @floatFromInt(mouse_dy)) * Config.MOUSE_SENSITIVITY;

        // Clamp pitch to prevent flipping
        self.pitch = std.math.clamp(self.pitch, -std.math.pi / 2.0 + 0.1, std.math.pi / 2.0 - 0.1);

        // Movement input - in fly mode, use look direction for forward
        var move_input = math.Vec3.ZERO;

        if (self.is_flying) {
            // Flying movement uses look direction
            if (input_state.isKeyDown(.w)) {
                move_input = math.Vec3.add(move_input, self.getLookDirection());
            }
            if (input_state.isKeyDown(.s)) {
                move_input = math.Vec3.sub(move_input, self.getLookDirection());
            }
            if (input_state.isKeyDown(.a)) {
                move_input = math.Vec3.sub(move_input, self.getRight());
            }
            if (input_state.isKeyDown(.d)) {
                move_input = math.Vec3.add(move_input, self.getRight());
            }
        } else {
            // Ground movement uses horizontal forward
            if (input_state.isKeyDown(.w)) {
                move_input = math.Vec3.add(move_input, self.getForward());
            }
            if (input_state.isKeyDown(.s)) {
                move_input = math.Vec3.sub(move_input, self.getForward());
            }
            if (input_state.isKeyDown(.a)) {
                move_input = math.Vec3.sub(move_input, self.getRight());
            }
            if (input_state.isKeyDown(.d)) {
                move_input = math.Vec3.add(move_input, self.getRight());
            }
        }

        // Normalize movement
        if (math.Vec3.lengthSquared(move_input) > 0.0001) {
            self.wish_dir = math.Vec3.normalize(move_input);
        } else {
            self.wish_dir = math.Vec3.ZERO;
        }

        // Sprint
        self.is_running = input_state.isKeyDown(.left_shift);

        // Crouch / descend in flight
        self.is_crouching = input_state.isKeyDown(.left_ctrl);
        self.wish_fly_down = self.is_crouching;

        // Jump / ascend in flight
        self.wish_jump = input_state.isKeyPressed(.space);
        self.wish_fly_up = input_state.isKeyDown(.space);
    }

    /// Toggle flight mode (called from game update with time tracking)
    pub fn toggleFlight(self: *PlayerController) void {
        self.is_flying = !self.is_flying;
        if (self.is_flying) {
            // Stop vertical velocity when entering flight
            self.velocity.data[1] = 0;
        }
    }

    /// Update physics
    pub fn update(self: *PlayerController, physics_world: *physics.PhysicsWorld, dt: f32) void {
        if (self.is_flying) {
            self.updateFlying(dt);
        } else {
            self.updateWalking(physics_world, dt);
        }
    }

    /// Update walking/ground physics
    fn updateWalking(self: *PlayerController, physics_world: *physics.PhysicsWorld, dt: f32) void {
        // Calculate movement speed with external modifiers
        const base_speed: f32 = if (self.is_crouching)
            Config.CROUCH_SPEED
        else if (self.is_running)
            Config.RUN_SPEED
        else
            Config.WALK_SPEED;

        const speed = base_speed * self.speed_multiplier;

        // Apply movement to velocity
        const target_vel = math.Vec3.scale(self.wish_dir, speed);

        // Smooth acceleration
        const accel: f32 = if (self.is_grounded) 10.0 else 2.0;
        self.velocity.data[0] = math.lerp(self.velocity.x(), target_vel.x(), accel * dt);
        self.velocity.data[2] = math.lerp(self.velocity.z(), target_vel.z(), accel * dt);

        // Jump
        if (self.wish_jump and self.is_grounded) {
            self.velocity.data[1] = Config.JUMP_VELOCITY;
            self.is_grounded = false;
        }

        // Apply gravity
        if (!self.is_grounded) {
            self.velocity.data[1] += physics.Config.GRAVITY * dt;
        }

        // Move with collision
        const result = physics_world.moveAndSlide(
            self.position,
            self.collider,
            self.velocity,
            dt,
        );

        self.position = result.position;
        self.velocity = result.velocity;
        self.is_grounded = result.grounded;
    }

    /// Update flying physics (no gravity, no collision)
    fn updateFlying(self: *PlayerController, dt: f32) void {
        // Calculate movement speed with external modifiers
        const base_speed: f32 = if (self.is_running)
            Config.FLY_FAST_SPEED
        else
            Config.FLY_SPEED;

        const speed = base_speed * self.speed_multiplier;

        // Apply horizontal movement
        const target_vel = math.Vec3.scale(self.wish_dir, speed);

        // Smooth acceleration (faster in flight)
        const accel: f32 = 8.0;
        self.velocity.data[0] = math.lerp(self.velocity.x(), target_vel.x(), accel * dt);
        self.velocity.data[1] = math.lerp(self.velocity.y(), target_vel.y(), accel * dt);
        self.velocity.data[2] = math.lerp(self.velocity.z(), target_vel.z(), accel * dt);

        // Vertical movement
        var vert_speed: f32 = 0;
        if (self.wish_fly_up) {
            vert_speed = speed;
        } else if (self.wish_fly_down) {
            vert_speed = -speed;
        }
        self.velocity.data[1] = math.lerp(self.velocity.y(), vert_speed, accel * dt);

        // Apply velocity directly (no collision in flight)
        self.position = math.Vec3.add(self.position, math.Vec3.scale(self.velocity, dt));
        self.is_grounded = false;
    }
};

/// Linear interpolation helper
fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * std.math.clamp(t, 0, 1);
}

// Add lerp to math module usage
const math_lerp = math.lerp orelse lerp;

// ============================================================================
// Tests
// ============================================================================

test "player look direction" {
    var player = PlayerController{};
    player.yaw = 0;
    player.pitch = 0;

    const dir = player.getLookDirection();
    // Looking along +Z when yaw and pitch are 0
    try std.testing.expectApproxEqAbs(@as(f32, 0), dir.x(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), dir.y(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1), dir.z(), 0.001);
}

test "player forward direction" {
    var player = PlayerController{};
    player.yaw = std.math.pi / 2.0; // 90 degrees - looking +X

    const forward = player.getForward();
    try std.testing.expectApproxEqAbs(@as(f32, 1), forward.x(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), forward.z(), 0.001);
}
