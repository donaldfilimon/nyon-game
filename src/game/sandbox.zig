//! Sandbox Game
//!
//! Main game logic for the sandbox experience.

const std = @import("std");
const math = @import("../math/math.zig");
const player_mod = @import("player.zig");
const world_mod = @import("world.zig");
const physics = @import("../physics/physics.zig");
const input = @import("../platform/input.zig");

pub const PlayerController = player_mod.PlayerController;
pub const BlockWorld = world_mod.BlockWorld;
pub const Block = world_mod.Block;
pub const Chunk = world_mod.Chunk;
pub const CHUNK_SIZE = world_mod.CHUNK_SIZE;

/// Sandbox game state
pub const SandboxGame = struct {
    allocator: std.mem.Allocator,
    world: BlockWorld,
    player: PlayerController,
    selected_block: Block,
    hotbar: [9]Block,
    hotbar_index: usize,
    show_debug: bool,
    block_reach: f32,

    // Block interaction
    target_block: ?struct {
        pos: [3]i32,
        face: [3]i32,
    },

    pub fn init(allocator: std.mem.Allocator) !SandboxGame {
        var game = SandboxGame{
            .allocator = allocator,
            .world = BlockWorld.init(allocator),
            .player = PlayerController{},
            .selected_block = .stone,
            .hotbar = .{
                .grass,
                .dirt,
                .stone,
                .brick,
                .wood,
                .sand,
                .glass,
                .leaves,
                .water,
            },
            .hotbar_index = 0,
            .show_debug = false,
            .block_reach = 5.0,
            .target_block = null,
        };

        // Generate initial terrain
        try game.world.generateFlat(4, 0);

        // Set player spawn above ground
        game.player.position = math.Vec3.init(0, 5, 0);

        return game;
    }

    pub fn deinit(self: *SandboxGame) void {
        self.world.deinit();
    }

    /// Main update function
    pub fn update(self: *SandboxGame, input_state: *const input.State, dt: f32) !void {
        // Toggle debug
        if (input_state.isKeyPressed(.f3)) {
            self.show_debug = !self.show_debug;
        }

        // Hotbar selection with number keys
        inline for (0..9) |i| {
            const key: input.Key = @enumFromInt(0x31 + i); // '1' to '9'
            if (input_state.isKeyPressed(key)) {
                self.hotbar_index = i;
                self.selected_block = self.hotbar[i];
            }
        }

        // Scroll wheel for hotbar
        if (input_state.scroll_y != 0) {
            if (input_state.scroll_y > 0) {
                self.hotbar_index = (self.hotbar_index + 8) % 9;
            } else {
                self.hotbar_index = (self.hotbar_index + 1) % 9;
            }
            self.selected_block = self.hotbar[self.hotbar_index];
        }

        // Process player input
        const delta = input_state.getMouseDelta();
        self.player.processInput(input_state, delta.dx, delta.dy);

        // Update physics colliders near player
        try self.world.updatePhysicsNear(self.player.position, 3);

        // Update player physics
        self.player.update(&self.world.physics_world, dt);

        // Raycast for block targeting
        const eye = self.player.getEyePosition();
        const look_dir = self.player.getLookDirection();

        if (self.world.raycastBlock(eye, look_dir, self.block_reach)) |hit| {
            self.target_block = .{
                .pos = hit.block_pos,
                .face = hit.face_normal,
            };
        } else {
            self.target_block = null;
        }

        // Block placement (left click)
        if (input_state.isMouseButtonDown(.left) and self.target_block != null) {
            const target = self.target_block.?;
            const place_pos = [3]i32{
                target.pos[0] + target.face[0],
                target.pos[1] + target.face[1],
                target.pos[2] + target.face[2],
            };

            // Don't place block inside player
            const player_aabb = self.player.collider.getAABB(self.player.position);
            const block_aabb = physics.AABB.unitCube(math.Vec3.init(
                @floatFromInt(place_pos[0]),
                @floatFromInt(place_pos[1]),
                @floatFromInt(place_pos[2]),
            ));

            if (!player_aabb.intersects(block_aabb)) {
                try self.world.setBlock(place_pos[0], place_pos[1], place_pos[2], self.selected_block);
            }
        }

        // Block removal (right click or Ctrl+left click)
        const removing = input_state.isMouseButtonDown(.right) or
            (input_state.isKeyDown(.left_ctrl) and input_state.isMouseButtonDown(.left));

        if (removing and self.target_block != null) {
            const target = self.target_block.?;
            try self.world.setBlock(target.pos[0], target.pos[1], target.pos[2], .air);
        }
    }

    /// Get current view matrix
    pub fn getViewMatrix(self: *const SandboxGame) math.Mat4 {
        return self.player.getViewMatrix();
    }

    /// Get debug info string
    pub fn getDebugInfo(self: *const SandboxGame) DebugInfo {
        return .{
            .position = self.player.position,
            .yaw = self.player.yaw,
            .pitch = self.player.pitch,
            .grounded = self.player.is_grounded,
            .velocity = self.player.velocity,
            .chunk_count = @intCast(self.world.chunks.count()),
            .selected_block = self.selected_block,
        };
    }

    pub const DebugInfo = struct {
        position: math.Vec3,
        yaw: f32,
        pitch: f32,
        grounded: bool,
        velocity: math.Vec3,
        chunk_count: u32,
        selected_block: Block,
    };
};

// ============================================================================
// Tests
// ============================================================================

test "sandbox init and cleanup" {
    const allocator = std.testing.allocator;
    var game = try SandboxGame.init(allocator);
    defer game.deinit();

    try std.testing.expect(game.world.chunks.count() > 0);
}
