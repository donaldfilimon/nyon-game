//! Block Renderer
//!
//! Renders block-based worlds with face culling optimization and proper lighting.
//! Supports transparent blocks (water, glass) with alpha blending.

const std = @import("std");
const math = @import("../math/math.zig");
const render = @import("render.zig");
const game = @import("../game/sandbox.zig");
const lighting = @import("lighting.zig");
const water_mod = @import("water.zig");

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
/// Order: bottom-left, bottom-right, top-right, top-left (CCW when looking at face)
const FACE_VERTICES: [6][4][3]f32 = .{
    // Top (+Y) - looking down from above
    .{ .{ 0, 1, 0 }, .{ 1, 1, 0 }, .{ 1, 1, 1 }, .{ 0, 1, 1 } },
    // Bottom (-Y) - looking up from below
    .{ .{ 0, 0, 1 }, .{ 1, 0, 1 }, .{ 1, 0, 0 }, .{ 0, 0, 0 } },
    // North (+Z) - looking south
    .{ .{ 1, 0, 1 }, .{ 0, 0, 1 }, .{ 0, 1, 1 }, .{ 1, 1, 1 } },
    // South (-Z) - looking north
    .{ .{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ 1, 1, 0 }, .{ 0, 1, 0 } },
    // East (+X) - looking west
    .{ .{ 1, 0, 0 }, .{ 1, 0, 1 }, .{ 1, 1, 1 }, .{ 1, 1, 0 } },
    // West (-X) - looking east
    .{ .{ 0, 0, 1 }, .{ 0, 0, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 1 } },
};

/// AO neighbor offsets for each face's corners
/// For each face, each corner has [side1, side2, corner] neighbor offsets
const FACE_AO_NEIGHBORS: [6][4][3][3]i32 = .{
    // Top face (+Y) - corners: SW, SE, NE, NW
    .{
        .{ .{ -1, 1, 0 }, .{ 0, 1, -1 }, .{ -1, 1, -1 } }, // v0: (0,1,0) - check -X, -Z, -X-Z
        .{ .{ 1, 1, 0 }, .{ 0, 1, -1 }, .{ 1, 1, -1 } }, // v1: (1,1,0) - check +X, -Z, +X-Z
        .{ .{ 1, 1, 0 }, .{ 0, 1, 1 }, .{ 1, 1, 1 } }, // v2: (1,1,1) - check +X, +Z, +X+Z
        .{ .{ -1, 1, 0 }, .{ 0, 1, 1 }, .{ -1, 1, 1 } }, // v3: (0,1,1) - check -X, +Z, -X+Z
    },
    // Bottom face (-Y)
    .{
        .{ .{ -1, -1, 0 }, .{ 0, -1, 1 }, .{ -1, -1, 1 } },
        .{ .{ 1, -1, 0 }, .{ 0, -1, 1 }, .{ 1, -1, 1 } },
        .{ .{ 1, -1, 0 }, .{ 0, -1, -1 }, .{ 1, -1, -1 } },
        .{ .{ -1, -1, 0 }, .{ 0, -1, -1 }, .{ -1, -1, -1 } },
    },
    // North face (+Z)
    .{
        .{ .{ 1, 0, 1 }, .{ 0, -1, 1 }, .{ 1, -1, 1 } },
        .{ .{ -1, 0, 1 }, .{ 0, -1, 1 }, .{ -1, -1, 1 } },
        .{ .{ -1, 0, 1 }, .{ 0, 1, 1 }, .{ -1, 1, 1 } },
        .{ .{ 1, 0, 1 }, .{ 0, 1, 1 }, .{ 1, 1, 1 } },
    },
    // South face (-Z)
    .{
        .{ .{ -1, 0, -1 }, .{ 0, -1, -1 }, .{ -1, -1, -1 } },
        .{ .{ 1, 0, -1 }, .{ 0, -1, -1 }, .{ 1, -1, -1 } },
        .{ .{ 1, 0, -1 }, .{ 0, 1, -1 }, .{ 1, 1, -1 } },
        .{ .{ -1, 0, -1 }, .{ 0, 1, -1 }, .{ -1, 1, -1 } },
    },
    // East face (+X)
    .{
        .{ .{ 1, 0, -1 }, .{ 1, -1, 0 }, .{ 1, -1, -1 } },
        .{ .{ 1, 0, 1 }, .{ 1, -1, 0 }, .{ 1, -1, 1 } },
        .{ .{ 1, 0, 1 }, .{ 1, 1, 0 }, .{ 1, 1, 1 } },
        .{ .{ 1, 0, -1 }, .{ 1, 1, 0 }, .{ 1, 1, -1 } },
    },
    // West face (-X)
    .{
        .{ .{ -1, 0, 1 }, .{ -1, -1, 0 }, .{ -1, -1, 1 } },
        .{ .{ -1, 0, -1 }, .{ -1, -1, 0 }, .{ -1, -1, -1 } },
        .{ .{ -1, 0, -1 }, .{ -1, 1, 0 }, .{ -1, 1, -1 } },
        .{ .{ -1, 0, 1 }, .{ -1, 1, 0 }, .{ -1, 1, 1 } },
    },
};

/// Lighting multipliers per face (directional bias for better visual depth)
const FACE_LIGHT_BIAS: [6]f32 = .{
    1.0, // Top - full light (sky-facing)
    0.5, // Bottom - darkest (ground-facing)
    0.8, // North
    0.8, // South
    0.7, // East
    0.7, // West
};

/// Global lighting system reference
var g_lighting_system: ?*lighting.LightingSystem = null;

/// Global ambient light color (fallback when no lighting system)
var g_ambient_light: [3]f32 = .{ 1.0, 1.0, 1.0 };

/// Sun direction for simple lighting (normalized)
var g_sun_direction: math.Vec3 = math.Vec3.init(0.3, -0.8, -0.5);
var g_sun_intensity: f32 = 1.0;

/// Enable/disable ambient occlusion
var g_ao_enabled: bool = true;

/// Global water renderer instance
var g_water_renderer: water_mod.WaterRenderer = water_mod.WaterRenderer.init();

/// Sea level for underwater detection
var g_sea_level: f32 = @floatFromInt(game.SEA_LEVEL);

/// Set the lighting system reference
pub fn setLightingSystem(sys: ?*lighting.LightingSystem) void {
    g_lighting_system = sys;
}

/// Set the global ambient light color for rendering (legacy support)
pub fn setAmbientLight(r: f32, g: f32, b: f32) void {
    g_ambient_light = .{ r, g, b };
}

/// Set sun parameters for simple lighting mode
pub fn setSunLight(direction: math.Vec3, intensity: f32) void {
    g_sun_direction = math.Vec3.normalize(direction);
    g_sun_intensity = intensity;
}

/// Enable or disable ambient occlusion
pub fn setAOEnabled(enabled: bool) void {
    g_ao_enabled = enabled;
}

/// Update water animation
pub fn updateWater(dt: f32) void {
    g_water_renderer.update(dt);
    g_water_renderer.setSunIntensity(g_sun_intensity);
}

/// Get the water renderer for configuration
pub fn getWaterRenderer() *water_mod.WaterRenderer {
    return &g_water_renderer;
}

/// Set sea level for underwater effects
pub fn setSeaLevel(level: f32) void {
    g_sea_level = level;
}

/// Check if a position is underwater
pub fn isUnderwater(camera_y: f32) bool {
    return camera_y < g_sea_level;
}

/// Get underwater effects if camera is underwater
pub fn getUnderwaterEffects(camera_y: f32) ?*const water_mod.UnderwaterEffects {
    if (isUnderwater(camera_y)) {
        return &g_water_renderer.underwater;
    }
    return null;
}

/// Render a block world with lighting
/// Uses two-pass rendering: opaque blocks first, then transparent blocks (water, glass)
pub fn renderBlockWorld(
    renderer: *render.Renderer,
    world: *game.BlockWorld,
    camera_pos: math.Vec3,
    render_distance: i32,
) void {
    const cam_chunk_x: i32 = @intFromFloat(@floor(camera_pos.x() / @as(f32, game.CHUNK_SIZE)));
    const cam_chunk_z: i32 = @intFromFloat(@floor(camera_pos.z() / @as(f32, game.CHUNK_SIZE)));

    // Pass 1: Render opaque blocks first
    var cz = cam_chunk_z - render_distance;
    while (cz <= cam_chunk_z + render_distance) : (cz += 1) {
        var cx = cam_chunk_x - render_distance;
        while (cx <= cam_chunk_x + render_distance) : (cx += 1) {
            var cy: i32 = -2;
            while (cy <= 3) : (cy += 1) {
                if (world.getChunk(cx, cy, cz)) |chunk| {
                    renderChunkOpaque(renderer, world, chunk);
                }
            }
        }
    }

    // Pass 2: Render transparent blocks (water, glass, leaves, ice)
    // These need to be rendered after opaque blocks for correct alpha blending
    cz = cam_chunk_z - render_distance;
    while (cz <= cam_chunk_z + render_distance) : (cz += 1) {
        var cx = cam_chunk_x - render_distance;
        while (cx <= cam_chunk_x + render_distance) : (cx += 1) {
            var cy: i32 = -2;
            while (cy <= 3) : (cy += 1) {
                if (world.getChunk(cx, cy, cz)) |chunk| {
                    renderChunkTransparent(renderer, world, chunk, camera_pos);
                }
            }
        }
    }
}

/// Render a single chunk (legacy - renders all blocks)
fn renderChunk(renderer: *render.Renderer, world: *game.BlockWorld, chunk: *game.Chunk) void {
    renderChunkOpaque(renderer, world, chunk);
}

/// Render only opaque blocks in a chunk
fn renderChunkOpaque(renderer: *render.Renderer, world: *game.BlockWorld, chunk: *game.Chunk) void {
    const chunk_world_pos = chunk.getWorldPosition();

    var y: usize = 0;
    while (y < game.CHUNK_SIZE) : (y += 1) {
        var z: usize = 0;
        while (z < game.CHUNK_SIZE) : (z += 1) {
            var x: usize = 0;
            while (x < game.CHUNK_SIZE) : (x += 1) {
                const block = chunk.getBlock(x, y, z);
                // Skip air, water, and other transparent blocks in opaque pass
                if (!block.isSolid() or block.isTransparent()) continue;

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
                    const face_offset = face.offset();

                    // Check if neighbor is transparent
                    const neighbor = world.getBlock(wx + face_offset[0], wy + face_offset[1], wz + face_offset[2]);

                    if (neighbor.isTransparent()) {
                        renderBlockFaceWithLighting(renderer, world, block_pos, block, face, wx, wy, wz);
                    }
                }
            }
        }
    }
}

/// Render only transparent blocks in a chunk (water, glass, leaves, ice)
fn renderChunkTransparent(
    renderer: *render.Renderer,
    world: *game.BlockWorld,
    chunk: *game.Chunk,
    camera_pos: math.Vec3,
) void {
    const chunk_world_pos = chunk.getWorldPosition();

    var y: usize = 0;
    while (y < game.CHUNK_SIZE) : (y += 1) {
        var z: usize = 0;
        while (z < game.CHUNK_SIZE) : (z += 1) {
            var x: usize = 0;
            while (x < game.CHUNK_SIZE) : (x += 1) {
                const block = chunk.getBlock(x, y, z);
                // Only render transparent solid blocks (glass, leaves, ice)
                // and water in this pass
                if (block == .air) continue;
                if (block == .water) {
                    // Water gets special rendering
                    renderWaterBlock(renderer, world, chunk, x, y, z, camera_pos);
                    continue;
                }
                if (!block.isTransparent()) continue;

                const block_pos = math.Vec3.init(
                    chunk_world_pos.x() + @as(f32, @floatFromInt(x)),
                    chunk_world_pos.y() + @as(f32, @floatFromInt(y)),
                    chunk_world_pos.z() + @as(f32, @floatFromInt(z)),
                );

                // World block coordinates
                const wx: i32 = chunk.position[0] * @as(i32, game.CHUNK_SIZE) + @as(i32, @intCast(x));
                const wy: i32 = chunk.position[1] * @as(i32, game.CHUNK_SIZE) + @as(i32, @intCast(y));
                const wz: i32 = chunk.position[2] * @as(i32, game.CHUNK_SIZE) + @as(i32, @intCast(z));

                // Render transparent block faces
                inline for (0..6) |face_idx| {
                    const face: Face = @enumFromInt(face_idx);
                    const face_offset = face.offset();

                    const neighbor = world.getBlock(wx + face_offset[0], wy + face_offset[1], wz + face_offset[2]);

                    // Only render face if neighbor is air or different transparent block
                    if (neighbor == .air or (neighbor != block and neighbor.isTransparent())) {
                        renderBlockFaceWithLighting(renderer, world, block_pos, block, face, wx, wy, wz);
                    }
                }
            }
        }
    }
}

/// Render a water block with special effects
fn renderWaterBlock(
    renderer: *render.Renderer,
    world: *game.BlockWorld,
    chunk: *game.Chunk,
    x: usize,
    y: usize,
    z: usize,
    camera_pos: math.Vec3,
) void {
    const chunk_world_pos = chunk.getWorldPosition();
    const block_pos = math.Vec3.init(
        chunk_world_pos.x() + @as(f32, @floatFromInt(x)),
        chunk_world_pos.y() + @as(f32, @floatFromInt(y)),
        chunk_world_pos.z() + @as(f32, @floatFromInt(z)),
    );

    // World block coordinates
    const wx: i32 = chunk.position[0] * @as(i32, game.CHUNK_SIZE) + @as(i32, @intCast(x));
    const wy: i32 = chunk.position[1] * @as(i32, game.CHUNK_SIZE) + @as(i32, @intCast(y));
    const wz: i32 = chunk.position[2] * @as(i32, game.CHUNK_SIZE) + @as(i32, @intCast(z));

    // Calculate water depth (how many water blocks above this one)
    var depth: u32 = 0;
    var check_y = wy + 1;
    while (check_y < wy + 16) : (check_y += 1) {
        if (world.getBlock(wx, check_y, wz) == .water) {
            depth += 1;
        } else {
            break;
        }
    }

    // Check each face for visibility
    inline for (0..6) |face_idx| {
        const face: Face = @enumFromInt(face_idx);
        const face_offset = face.offset();

        const neighbor = world.getBlock(wx + face_offset[0], wy + face_offset[1], wz + face_offset[2]);

        // Only render water face if neighbor is not water and not solid
        if (neighbor != .water and !neighbor.isSolid()) {
            // Check if this is an edge (touching solid block)
            const is_edge = checkWaterEdge(world, wx, wy, wz);

            renderWaterFace(renderer, block_pos, face, depth, is_edge, camera_pos);
        }
    }
}

/// Check if water block is at an edge (adjacent to solid block horizontally)
fn checkWaterEdge(world: *game.BlockWorld, wx: i32, wy: i32, wz: i32) bool {
    // Check horizontal neighbors for solid blocks
    if (world.getBlock(wx + 1, wy, wz).isSolid()) return true;
    if (world.getBlock(wx - 1, wy, wz).isSolid()) return true;
    if (world.getBlock(wx, wy, wz + 1).isSolid()) return true;
    if (world.getBlock(wx, wy, wz - 1).isSolid()) return true;
    return false;
}

/// Render a single water face with wave animation and effects
fn renderWaterFace(
    renderer: *render.Renderer,
    block_pos: math.Vec3,
    face: Face,
    depth: u32,
    is_edge: bool,
    camera_pos: math.Vec3,
) void {
    const face_idx = @intFromEnum(face);
    const verts = FACE_VERTICES[face_idx];
    const face_normal = face.normal();
    const face_light_bias = FACE_LIGHT_BIAS[face_idx];

    // Get water color based on depth
    const water_color = g_water_renderer.getWaterColor(
        block_pos.x(),
        block_pos.z(),
        depth,
        is_edge,
        face_light_bias * g_ambient_light[0],
    );

    // Build vertices with wave offset for top face
    var world_verts: [4]math.Vec3 = undefined;
    var vertex_colors: [4]render.Color = undefined;

    for (0..4) |i| {
        var vy = block_pos.y() + verts[i][1];

        // Apply wave animation to top surface vertices
        if (face == .top and verts[i][1] > 0.5) {
            const wave_offset = g_water_renderer.water.getWaveOffset(
                block_pos.x() + verts[i][0],
                block_pos.z() + verts[i][2],
            );
            vy += wave_offset;
        }

        world_verts[i] = math.Vec3.init(
            block_pos.x() + verts[i][0],
            vy,
            block_pos.z() + verts[i][2],
        );

        // Apply simple lighting to water
        const lit_color = lighting.calculateSimpleLighting(
            face_normal,
            g_sun_direction,
            g_sun_intensity,
            g_ambient_light[0] * 0.4,
            water_color,
        );

        // Vary color slightly per vertex for shimmer effect
        const color_f = lit_color.toFloat();
        const sparkle = g_water_renderer.water.getSparkle(
            block_pos.x() + verts[i][0],
            block_pos.z() + verts[i][2],
            g_sun_intensity,
        );

        vertex_colors[i] = render.Color.fromFloat(
            std.math.clamp(color_f[0] * face_light_bias + sparkle, 0.0, 1.0),
            std.math.clamp(color_f[1] * face_light_bias + sparkle, 0.0, 1.0),
            std.math.clamp(color_f[2] * face_light_bias + sparkle * 0.7, 0.0, 1.0),
            color_f[3],
        );
    }

    // Draw water triangles with alpha blending
    _ = camera_pos;
    renderer.drawTriangleShadedAlpha(world_verts[0], world_verts[1], world_verts[2], vertex_colors[0], vertex_colors[1], vertex_colors[2]);
    renderer.drawTriangleShadedAlpha(world_verts[0], world_verts[2], world_verts[3], vertex_colors[0], vertex_colors[2], vertex_colors[3]);
}

/// Render a single block face with proper lighting and AO
fn renderBlockFaceWithLighting(
    renderer: *render.Renderer,
    world: *game.BlockWorld,
    block_pos: math.Vec3,
    block: game.Block,
    face: Face,
    wx: i32,
    wy: i32,
    wz: i32,
) void {
    const face_idx = @intFromEnum(face);
    const verts = FACE_VERTICES[face_idx];
    const face_normal = face.normal();
    const face_light_bias = FACE_LIGHT_BIAS[face_idx];

    // Get base block color
    const base_color_arr = block.getColor();
    const base_color = render.Color{
        .r = base_color_arr[0],
        .g = base_color_arr[1],
        .b = base_color_arr[2],
        .a = base_color_arr[3],
    };

    // Calculate ambient occlusion for each vertex
    var ao_values: [4]f32 = .{ 1.0, 1.0, 1.0, 1.0 };
    if (g_ao_enabled) {
        const ao_neighbors = FACE_AO_NEIGHBORS[face_idx];
        for (0..4) |i| {
            const s1 = world.getBlock(
                wx + ao_neighbors[i][0][0],
                wy + ao_neighbors[i][0][1],
                wz + ao_neighbors[i][0][2],
            ).isSolid();
            const s2 = world.getBlock(
                wx + ao_neighbors[i][1][0],
                wy + ao_neighbors[i][1][1],
                wz + ao_neighbors[i][1][2],
            ).isSolid();
            const corner = world.getBlock(
                wx + ao_neighbors[i][2][0],
                wy + ao_neighbors[i][2][1],
                wz + ao_neighbors[i][2][2],
            ).isSolid();
            ao_values[i] = lighting.LightingSystem.calculateAmbientOcclusion(s1, s2, corner);
        }
    }

    // Calculate lit colors for each vertex
    var vertex_colors: [4]render.Color = undefined;

    if (g_lighting_system) |light_sys| {
        // Full lighting system path
        for (0..4) |i| {
            const vertex_pos = math.Vec3.init(
                block_pos.x() + verts[i][0],
                block_pos.y() + verts[i][1],
                block_pos.z() + verts[i][2],
            );
            vertex_colors[i] = light_sys.calculateLightingWithAO(
                vertex_pos,
                face_normal,
                base_color,
                lighting.Material.MATTE, // Blocks are matte
                ao_values[i],
            );
        }
    } else {
        // Simple lighting path (faster)
        for (0..4) |i| {
            // Simple directional + ambient lighting
            const lit_color = lighting.calculateSimpleLighting(
                face_normal,
                g_sun_direction,
                g_sun_intensity,
                g_ambient_light[0] * 0.3, // Ambient contribution
                base_color,
            );

            // Apply face bias and AO
            const color_f = lit_color.toFloat();
            const total_factor = face_light_bias * ao_values[i];
            vertex_colors[i] = render.Color.fromFloat(
                color_f[0] * total_factor * g_ambient_light[0],
                color_f[1] * total_factor * g_ambient_light[1],
                color_f[2] * total_factor * g_ambient_light[2],
                color_f[3],
            );
        }
    }

    // Build world-space vertices
    var world_verts: [4]math.Vec3 = undefined;
    for (0..4) |i| {
        world_verts[i] = math.Vec3.init(
            block_pos.x() + verts[i][0],
            block_pos.y() + verts[i][1],
            block_pos.z() + verts[i][2],
        );
    }

    // Determine triangle split based on AO values to avoid artifacts
    // Use the split that keeps similar AO values together
    const ao_diag1 = @abs(ao_values[0] - ao_values[2]);
    const ao_diag2 = @abs(ao_values[1] - ao_values[3]);

    if (ao_diag1 < ao_diag2) {
        // Split along 0-2 diagonal
        renderer.drawTriangleShaded(world_verts[0], world_verts[1], world_verts[2], vertex_colors[0], vertex_colors[1], vertex_colors[2]);
        renderer.drawTriangleShaded(world_verts[0], world_verts[2], world_verts[3], vertex_colors[0], vertex_colors[2], vertex_colors[3]);
    } else {
        // Split along 1-3 diagonal
        renderer.drawTriangleShaded(world_verts[0], world_verts[1], world_verts[3], vertex_colors[0], vertex_colors[1], vertex_colors[3]);
        renderer.drawTriangleShaded(world_verts[1], world_verts[2], world_verts[3], vertex_colors[1], vertex_colors[2], vertex_colors[3]);
    }
}

/// Legacy render function (without per-vertex lighting)
fn renderBlockFace(renderer: *render.Renderer, block_pos: math.Vec3, block: game.Block, face: Face) void {
    const face_idx = @intFromEnum(face);
    const verts = FACE_VERTICES[face_idx];
    const light = FACE_LIGHT_BIAS[face_idx];

    // Get block color and apply lighting with ambient color
    const base_color = block.getColor();

    // Apply face lighting and ambient light
    const r_f = @as(f32, @floatFromInt(base_color[0])) * light * g_ambient_light[0];
    const g_f = @as(f32, @floatFromInt(base_color[1])) * light * g_ambient_light[1];
    const b_f = @as(f32, @floatFromInt(base_color[2])) * light * g_ambient_light[2];

    const color = render.Color{
        .r = @intFromFloat(std.math.clamp(r_f, 0, 255)),
        .g = @intFromFloat(std.math.clamp(g_f, 0, 255)),
        .b = @intFromFloat(std.math.clamp(b_f, 0, 255)),
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

/// Get the color for a block type (for particle effects)
pub fn getBlockColor(block: game.Block) render.Color {
    const color_arr = block.getColor();
    return render.Color{
        .r = color_arr[0],
        .g = color_arr[1],
        .b = color_arr[2],
        .a = color_arr[3],
    };
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
    const offset_val: f32 = 0.005;
    const model = math.Mat4.mul(
        math.Mat4.translation(math.Vec3.init(pos.x() - offset_val, pos.y() - offset_val, pos.z() - offset_val)),
        math.Mat4.scaling(math.Vec3.init(1 + offset_val * 2, 1 + offset_val * 2, 1 + offset_val * 2)),
    );

    renderer.drawWireframeCube(model, color);
}

// ============================================================================
// Tests
// ============================================================================

test "face normals match" {
    const top_normal = Face.top.normal();
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), top_normal.y(), 0.001);

    const bottom_normal = Face.bottom.normal();
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), bottom_normal.y(), 0.001);
}

test "ao calculation" {
    // No neighbors = full brightness
    const ao_none = lighting.LightingSystem.calculateAmbientOcclusion(false, false, false);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), ao_none, 0.001);

    // Both sides = darkest
    const ao_full = lighting.LightingSystem.calculateAmbientOcclusion(true, true, true);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), ao_full, 0.001);
}
