//! Block Renderer
//!
//! Renders block-based worlds with face culling optimization.

const std = @import("std");
const math = @import("../math/math.zig");
const render = @import("render.zig");
const game = @import("../game/sandbox.zig");

/// Block face directions
pub const Face = enum(u3) {
    top = 0, // +Y
    bottom = 1, // -Y
    north = 2, // +Z
    south = 3, // -Z
    east = 4, // +X
    west = 5, // -X

    pub fn normal(self: Face) math.Vec3 {
        return switch (self) {
            .top => math.Vec3.init(0, 1, 0),
            .bottom => math.Vec3.init(0, -1, 0),
            .north => math.Vec3.init(0, 0, 1),
            .south => math.Vec3.init(0, 0, -1),
            .east => math.Vec3.init(1, 0, 0),
            .west => math.Vec3.init(-1, 0, 0),
        };
    }

    pub fn offset(self: Face) [3]i32 {
        return switch (self) {
            .top => .{ 0, 1, 0 },
            .bottom => .{ 0, -1, 0 },
            .north => .{ 0, 0, 1 },
            .south => .{ 0, 0, -1 },
            .east => .{ 1, 0, 0 },
            .west => .{ -1, 0, 0 },
        };
    }
};

/// Face vertices (as offsets from block origin)
const FACE_VERTICES: [6][4][3]f32 = .{
    // Top (+Y)
    .{ .{ 0, 1, 0 }, .{ 1, 1, 0 }, .{ 1, 1, 1 }, .{ 0, 1, 1 } },
    // Bottom (-Y)
    .{ .{ 0, 0, 1 }, .{ 1, 0, 1 }, .{ 1, 0, 0 }, .{ 0, 0, 0 } },
    // North (+Z)
    .{ .{ 1, 0, 1 }, .{ 0, 0, 1 }, .{ 0, 1, 1 }, .{ 1, 1, 1 } },
    // South (-Z)
    .{ .{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ 1, 1, 0 }, .{ 0, 1, 0 } },
    // East (+X)
    .{ .{ 1, 0, 0 }, .{ 1, 0, 1 }, .{ 1, 1, 1 }, .{ 1, 1, 0 } },
    // West (-X)
    .{ .{ 0, 0, 1 }, .{ 0, 0, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 1 } },
};

/// Lighting multipliers per face (fake AO)
const FACE_LIGHT: [6]f32 = .{
    1.0, // Top - full light
    0.5, // Bottom - darkest
    0.8, // North
    0.8, // South
    0.7, // East
    0.7, // West
};

/// Render a block world
pub fn renderBlockWorld(
    renderer: *render.Renderer,
    world: *game.BlockWorld,
    camera_pos: math.Vec3,
    render_distance: i32,
) void {
    const cam_chunk_x: i32 = @intFromFloat(@floor(camera_pos.x() / @as(f32, game.CHUNK_SIZE)));
    const cam_chunk_z: i32 = @intFromFloat(@floor(camera_pos.z() / @as(f32, game.CHUNK_SIZE)));

    // Iterate chunks within render distance
    var cz = cam_chunk_z - render_distance;
    while (cz <= cam_chunk_z + render_distance) : (cz += 1) {
        var cx = cam_chunk_x - render_distance;
        while (cx <= cam_chunk_x + render_distance) : (cx += 1) {
            // Render ground-level chunks
            var cy: i32 = -1;
            while (cy <= 1) : (cy += 1) {
                if (world.getChunk(cx, cy, cz)) |chunk| {
                    renderChunk(renderer, world, chunk);
                }
            }
        }
    }
}

/// Render a single chunk
fn renderChunk(renderer: *render.Renderer, world: *game.BlockWorld, chunk: *game.Chunk) void {
    const chunk_world_pos = chunk.getWorldPosition();

    var y: usize = 0;
    while (y < game.CHUNK_SIZE) : (y += 1) {
        var z: usize = 0;
        while (z < game.CHUNK_SIZE) : (z += 1) {
            var x: usize = 0;
            while (x < game.CHUNK_SIZE) : (x += 1) {
                const block = chunk.getBlock(x, y, z);
                if (!block.isSolid()) continue;

                const block_pos = math.Vec3.init(
                    chunk_world_pos.x() + @as(f32, @floatFromInt(x)),
                    chunk_world_pos.y() + @as(f32, @floatFromInt(y)),
                    chunk_world_pos.z() + @as(f32, @floatFromInt(z)),
                );

                // World block coordinates
                const wx: i32 = chunk.position[0] * @as(i32, game.CHUNK_SIZE) + @as(i32, @intCast(x));
                const wy: i32 = chunk.position[1] * @as(i32, game.CHUNK_SIZE) + @as(i32, @intCast(y));
                const wz: i32 = chunk.position[2] * @as(i32, game.CHUNK_SIZE) + @as(i32, @intCast(z));

                // Check each face for visibility
                inline for (0..6) |face_idx| {
                    const face: Face = @enumFromInt(face_idx);
                    const offset = face.offset();

                    // Check if neighbor is transparent
                    const neighbor = world.getBlock(wx + offset[0], wy + offset[1], wz + offset[2]);

                    if (neighbor.isTransparent()) {
                        renderBlockFace(renderer, block_pos, block, face);
                    }
                }
            }
        }
    }
}

/// Render a single block face as two triangles
fn renderBlockFace(renderer: *render.Renderer, block_pos: math.Vec3, block: game.Block, face: Face) void {
    const face_idx = @intFromEnum(face);
    const verts = FACE_VERTICES[face_idx];
    const light = FACE_LIGHT[face_idx];

    // Get block color and apply lighting
    const base_color = block.getColor();
    const color = render.Color{
        .r = @intFromFloat(@as(f32, @floatFromInt(base_color[0])) * light),
        .g = @intFromFloat(@as(f32, @floatFromInt(base_color[1])) * light),
        .b = @intFromFloat(@as(f32, @floatFromInt(base_color[2])) * light),
        .a = base_color[3],
    };

    // Build world-space vertices
    var world_verts: [4]math.Vec3 = undefined;
    for (0..4) |i| {
        world_verts[i] = math.Vec3.init(
            block_pos.x() + verts[i][0],
            block_pos.y() + verts[i][1],
            block_pos.z() + verts[i][2],
        );
    }

    // Draw two triangles
    renderer.drawTriangle(world_verts[0], world_verts[1], world_verts[2], color);
    renderer.drawTriangle(world_verts[0], world_verts[2], world_verts[3], color);
}

/// Render block selection highlight
pub fn renderBlockHighlight(
    renderer: *render.Renderer,
    block_pos: [3]i32,
    color: render.Color,
) void {
    const pos = math.Vec3.init(
        @floatFromInt(block_pos[0]),
        @floatFromInt(block_pos[1]),
        @floatFromInt(block_pos[2]),
    );

    // Draw wireframe cube slightly larger than block
    const offset: f32 = 0.005;
    const model = math.Mat4.mul(
        math.Mat4.translation(math.Vec3.init(pos.x() - offset, pos.y() - offset, pos.z() - offset)),
        math.Mat4.scaling(math.Vec3.init(1 + offset * 2, 1 + offset * 2, 1 + offset * 2)),
    );

    renderer.drawWireframeCube(model, color);
}
