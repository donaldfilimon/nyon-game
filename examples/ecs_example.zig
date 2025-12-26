//! ECS Example - Demonstrating the new Entity Component System
//!
//! This example shows how to use the modern ECS architecture alongside
//! the existing scene-based systems for a smooth migration path.

const std = @import("std");
const nyon = @import("nyon_game");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize the engine (existing system)
    var engine = try nyon.Engine.init(allocator, .{
        .width = 1200,
        .height = 800,
        .title = "Nyon ECS Example",
    });
    defer engine.deinit();

    // Initialize ECS World (new system)
    var world = nyon.ecs.World.init(allocator);
    defer world.deinit();

    // Create some entities
    std.debug.print("Creating ECS entities...\n", .{});

    // Player entity
    const player = try world.createEntity();
    try world.addComponent(player, nyon.ecs.Position.init(0, 0, 0));
    try world.addComponent(player, nyon.ecs.Rotation.identity());
    try world.addComponent(player, nyon.ecs.Renderable.init(1, 1)); // mesh_id, material_id
    try world.addComponent(player, nyon.ecs.RigidBody.dynamic(1.0));

    // Camera entity
    const camera = try world.createEntity();
    try world.addComponent(camera, nyon.ecs.Position.init(0, 5, 10));
    try world.addComponent(camera, nyon.ecs.Rotation.fromEuler(-0.3, 0, 0)); // Look down slightly
    try world.addComponent(camera, nyon.ecs.Camera.perspective(60, 1200.0 / 800.0, 0.1, 100.0));

    // Some scenery entities
    for (0..10) |i| {
        const scenery = try world.createEntity();
        const x = @as(f32, @floatFromInt(i)) * 3.0 - 13.5;
        try world.addComponent(scenery, nyon.ecs.Position.init(x, 0, -5));
        try world.addComponent(scenery, nyon.ecs.Scale.uniform(0.5 + @as(f32, @floatFromInt(i)) * 0.1));
        try world.addComponent(scenery, nyon.ecs.Renderable.init(2, 2)); // Different mesh/material
    }

    std.debug.print("ECS World Stats: {}\n", .{world.getStats()});

    // Main game loop
    while (!engine.shouldClose()) {
        engine.pollEvents();

        // Update ECS systems
        updatePlayerMovement(&world, player);

        // Render using ECS queries
        engine.beginDrawing();
        engine.clearBackground(nyon.Color.sky_blue);

        // Render all renderable entities
        renderScene(&world);

        // UI overlay
        drawUI(&world);

        engine.endDrawing();
    }
}

/// Update player movement based on input
fn updatePlayerMovement(world: *nyon.ecs.World, player: nyon.ecs.EntityId) void {
    // Get player position component
    if (world.getComponent(player, nyon.ecs.Position)) |pos| {
        // Simple movement (in a real game, you'd check input)
        pos.x += 0.01; // Move right over time

        // Keep player in bounds
        if (pos.x > 10) pos.x = -10;
    }
}

/// Render all renderable entities in the scene
fn renderScene(world: *const nyon.ecs.World) void {
    // Create a query for entities with Position and Renderable components
    var render_query = world.createQuery()
        .with(nyon.ecs.Position)
        .with(nyon.ecs.Renderable)
        .build() catch return;
    defer render_query.deinit();

    // Update query with current archetypes
    render_query.updateMatches(world.archetypes.items);

    // Iterate and render each entity
    var iter = render_query.iter();
    var entity_count: usize = 0;

    while (iter.next()) |entity_data| {
        entity_count += 1;

        // Get components
        const pos = entity_data.get(nyon.ecs.Position) orelse continue;
        const renderable = entity_data.get(nyon.ecs.Renderable) orelse continue;

        // Simple rendering (in a real engine, this would use the actual mesh/material)
        // For now, just draw colored rectangles to represent entities

        const screen_x = 600 + pos.x * 20; // Simple projection
        const screen_y = 400 - pos.z * 20;

        // Different colors for different mesh IDs
        const color = switch (renderable.mesh_handle) {
            1 => nyon.Color.red, // Player
            2 => nyon.Color.green, // Scenery
            else => nyon.Color.blue,
        };

        // Draw entity as a rectangle
        // Note: In a real implementation, this would use proper 3D rendering
        std.debug.print("Rendering entity at ({d:.1}, {d:.1}) with color {}\n", .{ screen_x, screen_y, @intFromEnum(color) });
    }

    // Debug: Show entity count
    std.debug.print("Rendered {} entities\n", .{entity_count});
}

/// Draw UI overlay showing ECS information
fn drawUI(world: *const nyon.ecs.World) void {
    const stats = world.getStats();

    // This would use the UI system to draw text
    // For now, just demonstrating the concept
    std.debug.print("Entities: {}, Archetypes: {}\r", .{
        stats.entity_count,
        stats.archetype_count,
    });
}

/// Alternative: Hybrid approach using both ECS and legacy Scene
pub fn hybridExample() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize both systems
    var engine = try nyon.Engine.init(allocator, .{ .width = 800, .height = 600, .title = "Hybrid Example" });
    defer engine.deinit();

    var world = nyon.ecs.World.init(allocator);
    defer world.deinit();

    // Legacy scene for compatibility
    var scene = nyon.Scene.init(allocator);
    defer scene.deinit();

    // Use ECS for game logic, Scene for rendering compatibility
    const player_entity = try world.createEntity();
    try world.addComponent(player_entity, nyon.ecs.Position.init(0, 0, 0));
    try world.addComponent(player_entity, nyon.ecs.Renderable.init(1, 1));

    // Add to legacy scene for rendering (migration strategy)
    // This allows gradual migration from Scene to ECS
    _ = scene.addModel(nyon.raylib.genMeshCube(1, 1, 1), nyon.Vector3{ .x = 0, .y = 0, .z = 0 }) catch {};

    std.debug.print("Hybrid approach: ECS for logic, Scene for rendering\n", .{});
}

/// Performance comparison between ECS and Scene approaches
pub fn performanceComparison() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const entity_count = 10000;

    // Test ECS performance
    var world = nyon.ecs.World.init(allocator);
    defer world.deinit();

    var ecs_timer = try std.time.Timer.start();

    // Create many entities with components
    var i: usize = 0;
    while (i < entity_count) : (i += 1) {
        const entity = try world.createEntity();
        try world.addComponent(entity, nyon.ecs.Position.init(@as(f32, @floatFromInt(i)), @as(f32, @floatFromInt(i)), @as(f32, @floatFromInt(i))));

        if (i % 2 == 0) {
            try world.addComponent(entity, nyon.ecs.Rotation.identity());
        }
    }

    const ecs_time = ecs_timer.read();

    // Test Scene performance (legacy)
    var scene = nyon.Scene.init(allocator);
    defer scene.deinit();

    var scene_timer = try std.time.Timer.start();

    i = 0;
    while (i < entity_count) : (i += 1) {
        const mesh = nyon.raylib.genMeshCube(1, 1, 1);
        _ = scene.addModel(mesh, nyon.Vector3{
            .x = @as(f32, @floatFromInt(i)),
            .y = @as(f32, @floatFromInt(i)),
            .z = @as(f32, @floatFromInt(i)),
        }) catch {};
    }

    const scene_time = scene_timer.read();

    std.debug.print("Performance Comparison ({} entities):\n", .{entity_count});
    std.debug.print("  ECS: {d:.2}ms\n", .{@as(f64, @floatFromInt(ecs_time)) / 1_000_000.0});
    std.debug.print("  Scene: {d:.2}ms\n", .{@as(f64, @floatFromInt(scene_time)) / 1_000_000.0});
    std.debug.print("  ECS is {d:.1}x {}\n", .{
        @as(f64, @floatFromInt(scene_time)) / @as(f64, @floatFromInt(ecs_time)),
        if (ecs_time < scene_time) "faster" else "slower",
    });
}

// ============================================================================
// Migration Guide Examples
// ============================================================================

/// Example: Migrating from Scene-based to ECS-based camera
pub const SceneToECSMigration = struct {
    /// Old approach: Manual scene management
    pub fn oldApproach(scene: *nyon.Scene, camera_pos: nyon.Vector3) void {
        // Manually manage camera in scene
        // Hard to query, modify, or extend
        std.debug.print("Old approach: camera at {}\n", .{camera_pos});
        _ = scene;
    }

    /// New approach: ECS-based camera
    pub fn newApproach(world: *nyon.ecs.World, camera_entity: nyon.ecs.EntityId, new_pos: nyon.ecs.Position) void {
        // Easy to find and modify camera
        if (world.getComponent(camera_entity, nyon.ecs.Position)) |pos| {
            pos.* = new_pos;
        }

        // Easy to query all cameras
        var camera_query = world.createQuery()
            .with(nyon.ecs.Position)
            .with(nyon.ecs.Camera)
            .build() catch return;
        defer camera_query.deinit();

        camera_query.updateMatches(world.archetypes.items);

        var iter = camera_query.iter();
        while (iter.next()) |entity_data| {
            // Process each camera
            _ = entity_data;
        }
    }
};
