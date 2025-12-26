//! Physics Example - Complete physics simulation with ECS integration
//!
//! This example demonstrates a complete physics simulation using the ECS
//! architecture, showing rigid bodies, collision detection, constraints,
//! and realistic physics behavior.

const std = @import("std");
const nyon = @import("nyon_game");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize engine
    var engine = try nyon.Engine.init(allocator, .{
        .width = 1200,
        .height = 800,
        .title = "Nyon Physics Example",
    });
    defer engine.deinit();

    // Initialize ECS World
    var ecs_world = nyon.ecs.World.init(allocator);
    defer ecs_world.deinit();

    // Initialize Physics System
    const physics_config = nyon.ecs.PhysicsSystem.Config{
        .gravity = .{ .x = 0, .y = -9.81, .z = 0 },
        .max_substeps = 10,
        .fixed_timestep = 1.0 / 120.0, // Higher precision for physics
    };
    var physics_system = nyon.ecs.PhysicsSystem.init(allocator, physics_config);
    defer physics_system.deinit();

    // Create ground plane (static body)
    const ground = try ecs_world.createEntity();
    try ecs_world.addComponent(ground, nyon.ecs.Position.init(0, -5, 0));
    try ecs_world.addComponent(ground, nyon.ecs.Scale.uniform(50)); // Large ground plane

    const ground_body = nyon.ecs.RigidBody.static(nyon.ecs.Position.init(0, -5, 0).toVec3());
    const ground_collider = nyon.ecs.Collider.box(nyon.ecs.Position.init(0, -5, 0).toVec3(), nyon.ecs.Scale.init(50, 1, 50).toVec3());
    try physics_system.addRigidBody(&ecs_world, ground, ground_body, ground_collider);

    // Create falling spheres
    for (0..10) |i| {
        const sphere_entity = try ecs_world.createEntity();
        const x_pos = @as(f32, @floatFromInt(i)) * 2.0 - 9.0;
        const y_pos = 10.0 + @as(f32, @floatFromInt(i)) * 2.0;

        try ecs_world.addComponent(sphere_entity, nyon.ecs.Position.init(x_pos, y_pos, 0));
        try ecs_world.addComponent(sphere_entity, nyon.ecs.Rotation.identity());
        try ecs_world.addComponent(sphere_entity, nyon.ecs.Scale.uniform(1));
        try ecs_world.addComponent(sphere_entity, nyon.ecs.Renderable.init(1, 1)); // Sphere mesh, default material

        // Create physics body
        const sphere_body = nyon.ecs.RigidBody.dynamic(1.0, nyon.ecs.Position.init(x_pos, y_pos, 0).toVec3());
        const sphere_collider = nyon.ecs.Collider.sphere(nyon.ecs.Position.zero().toVec3(), 1.0);
        try physics_system.addRigidBody(&ecs_world, sphere_entity, sphere_body, sphere_collider);

        // Add some initial velocity for more interesting motion
        const initial_velocity = nyon.ecs.Vector3.init((@as(f32, @floatFromInt(i)) - 4.5) * 2.0, 0, (@as(f32, @floatFromInt(i)) - 4.5) * 0.5);
        physics_system.setVelocity(sphere_entity, initial_velocity);
    }

    // Create a kinematic platform that moves back and forth
    const platform = try ecs_world.createEntity();
    try ecs_world.addComponent(platform, nyon.ecs.Position.init(0, 2, 0));
    try ecs_world.addComponent(platform, nyon.ecs.Scale.init(8, 1, 2));

    const platform_body = nyon.ecs.RigidBody.kinematic(nyon.ecs.Position.init(0, 2, 0).toVec3());
    const platform_collider = nyon.ecs.Collider.box(nyon.ecs.Position.zero().toVec3(), nyon.ecs.Scale.init(8, 1, 2).toVec3());
    try physics_system.addRigidBody(&ecs_world, platform, platform_body, platform_collider);

    std.debug.print("Physics simulation initialized with {} entities\n", .{ecs_world.getStats().entity_count});

    // Main game loop
    var time: f32 = 0;
    while (!engine.shouldClose()) {
        engine.pollEvents();

        // Update time
        time += 1.0 / 60.0;

        // Move the kinematic platform
        const platform_x = std.math.sin(time) * 5.0;
        physics_system.setPosition(platform, nyon.ecs.Vector3.init(platform_x, 2, 0));

        // Update physics
        try physics_system.update(&ecs_world, 1.0 / 60.0);

        // Render scene
        engine.beginDrawing();
        engine.clearBackground(nyon.Color.init(135, 206, 235, 255)); // Sky blue

        // Render all entities
        renderScene(&ecs_world);

        // Render physics debug information
        renderPhysicsDebug(&physics_system);

        // UI
        drawUI(&ecs_world, &physics_system, time);

        engine.endDrawing();
    }

    // Print final statistics
    const final_stats = physics_system.getStats();
    std.debug.print("Simulation complete!\n", .{});
    std.debug.print("Final physics stats: {} bodies, {} constraints\n", .{
        final_stats.bodies,
        final_stats.constraints,
    });
    std.debug.print("Performance: {} potential collisions, {} actual collisions\n", .{
        final_stats.potential_collisions,
        final_stats.actual_collisions,
    });
}

/// Render all entities in the scene
fn renderScene(ecs_world: *const nyon.ecs.World) void {
    var query = ecs_world.createQuery();
    defer query.deinit();

    var render_query = query
        .with(nyon.ecs.Position)
        .with(nyon.ecs.Renderable)
        .build() catch return;
    defer render_query.deinit();

    render_query.updateMatches(ecs_world.archetypes.items);

    var iter = render_query.iter();
    var entity_count: usize = 0;

    while (iter.next()) |entity_data| {
        entity_count += 1;
        const position = entity_data.get(nyon.ecs.Position) orelse continue;
        const renderable = entity_data.get(nyon.ecs.Renderable) orelse continue;

        // Simple rendering: draw colored circles/rectangles to represent entities
        const screen_x = 600 + position.x * 15;
        const screen_y = 400 - position.y * 15;
        const size = 20;

        // Color based on entity type (simplified detection)
        var color: nyon.Color = nyon.Color.blue; // Default
        if (position.y < -3) {
            color = nyon.Color.green; // Ground
        } else if (position.y > 5) {
            color = nyon.Color.red; // Falling objects
        } else if (@abs(position.x) > 3) {
            color = nyon.Color.yellow; // Platform
        }

        // Draw entity representation (would be replaced with actual 3D rendering)
        _ = color;
        _ = screen_x;
        _ = screen_y;
        _ = size; // Placeholder for rendering
    }

    std.debug.print("Rendered {} entities\r", .{entity_count});
}

/// Render physics debug information
fn renderPhysicsDebug(physics_system: *const nyon.ecs.PhysicsSystem) void {
    const stats = physics_system.getStats();

    // Draw debug info (would use actual rendering in a real implementation)
    std.debug.print("Physics: {} bodies, {} collisions/frame\r", .{
        stats.bodies,
        stats.actual_collisions,
    });
}

/// Draw UI overlay
fn drawUI(ecs_world: *const nyon.ecs.World, physics_system: *const nyon.ecs.PhysicsSystem, time: f32) void {
    const ecs_stats = ecs_world.getStats();
    const physics_stats = physics_system.getStats();

    // UI rendering would go here (using the UI system)
    std.debug.print("Time: {d:.1}s | ECS: {} entities, {} archetypes | Physics: {} bodies, {}ms solve time\n", .{
        time,
        ecs_stats.entity_count,
        ecs_stats.archetype_count,
        physics_stats.bodies,
        @divFloor(physics_stats.solve_time_ns, 1_000_000),
    });
}

/// Advanced example: Physics constraints and joints
pub fn constraintExample() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var ecs_world = nyon.ecs.World.init(allocator);
    defer ecs_world.deinit();

    var physics_system = nyon.ecs.PhysicsSystem.init(allocator, .{});
    defer physics_system.deinit();

    // Create a pendulum (two bodies connected by distance constraint)
    const anchor = try ecs_world.createEntity();
    try ecs_world.addComponent(anchor, nyon.ecs.Position.init(0, 10, 0));
    const anchor_body = nyon.ecs.RigidBody.static(nyon.ecs.Vector3.init(0, 10, 0));
    try physics_system.addRigidBody(&ecs_world, anchor, anchor_body, null);

    const pendulum = try ecs_world.createEntity();
    try ecs_world.addComponent(pendulum, nyon.ecs.Position.init(5, 5, 0));
    const pendulum_body = nyon.ecs.RigidBody.dynamic(1.0, nyon.ecs.Vector3.init(5, 5, 0));
    try physics_system.addRigidBody(&ecs_world, pendulum, pendulum_body, null);

    // Add distance constraint (pendulum rope)
    const constraint = nyon.ecs.Constraint.distance(0, // anchor body handle
        1, // pendulum body handle
        nyon.ecs.Vector3.zero(), // local anchor on anchor
        nyon.ecs.Vector3.zero(), // local anchor on pendulum
        5.0 // rope length
    );
    try physics_system.addConstraint(constraint);

    std.debug.print("Created pendulum with distance constraint\n", .{});

    // Simulation would run here...
}

/// Ray casting example
pub fn raycastExample(physics_system: *const nyon.ecs.PhysicsSystem) void {
    // Create a ray from camera position downward
    const ray = nyon.ecs.Ray.init(nyon.ecs.Vector3.init(0, 10, 0), // Origin
        nyon.ecs.Vector3.init(0, -1, 0) // Direction (down)
    );

    // Perform ray cast
    if (physics_system.raycast(ray)) |result| {
        std.debug.print("Ray hit entity at ({d:.2}, {d:.2}, {d:.2}), distance: {d:.2}\n", .{
            result.hit.point.x,
            result.hit.point.y,
            result.hit.point.z,
            result.hit.distance,
        });
    } else {
        std.debug.print("Ray cast hit nothing\n", .{});
    }
}

/// Performance benchmark for physics system
pub fn physicsBenchmark() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var ecs_world = nyon.ecs.World.init(allocator);
    defer ecs_world.deinit();

    var physics_system = nyon.ecs.PhysicsSystem.init(allocator, .{});
    defer physics_system.deinit();

    // Create many physics objects for benchmarking
    const num_objects = 100;
    std.debug.print("Creating {} physics objects for benchmark...\n", .{num_objects});

    const start_time = std.time.nanoTimestamp();

    for (0..num_objects) |i| {
        const entity = try ecs_world.createEntity();
        const x = (@as(f32, @floatFromInt(i)) - @as(f32, @floatFromInt(num_objects)) / 2.0) * 0.5;
        const y = 10.0 + @as(f32, @floatFromInt(i)) * 0.1;

        try ecs_world.addComponent(entity, nyon.ecs.Position.init(x, y, 0));

        const body = nyon.ecs.RigidBody.dynamic(1.0, nyon.ecs.Vector3.init(x, y, 0));
        const collider = nyon.ecs.Collider.sphere(nyon.ecs.Vector3.zero(), 0.5);
        try physics_system.addRigidBody(&ecs_world, entity, body, collider);
    }

    const creation_time = std.time.nanoTimestamp() - start_time;
    std.debug.print("Created {} objects in {d:.2}ms\n", .{
        num_objects,
        @as(f64, @floatFromInt(creation_time)) / 1_000_000.0,
    });

    // Benchmark physics simulation
    const simulation_start = std.time.nanoTimestamp();
    const frames = 100;

    for (0..frames) |_| {
        try physics_system.update(&ecs_world, 1.0 / 60.0);
    }

    const simulation_time = std.time.nanoTimestamp() - simulation_start;
    const avg_frame_time = @as(f64, @floatFromInt(simulation_time)) / @as(f64, @floatFromInt(frames));

    std.debug.print("Simulated {} frames in {d:.2}ms (avg: {d:.2}ms/frame, {d:.1}fps)\n", .{
        frames,
        @as(f64, @floatFromInt(simulation_time)) / 1_000_000.0,
        avg_frame_time / 1_000_000.0,
        1_000_000_000.0 / avg_frame_time,
    });

    const final_stats = physics_system.getStats();
    std.debug.print("Final stats: {} bodies, {} constraints, {} avg collisions/frame\n", .{
        final_stats.bodies,
        final_stats.constraints,
        final_stats.actual_collisions,
    });
}

// ============================================================================
// Integration with Game Logic
// ============================================================================

/// Example game system that uses physics for gameplay
pub fn gamePhysicsSystem(
    ecs_world: *nyon.ecs.World,
    physics_system: *nyon.ecs.PhysicsSystem,
    player_input: anytype,
) void {
    // Handle player input
    var player_query = ecs_world.createQuery();
    defer player_query.deinit();

    var player_entities = player_query
        .with(nyon.ecs.Position)
        .with(nyon.ecs.RigidBody)
        // .with(PlayerController) // Would add custom component
        .build() catch return;
    defer player_entities.deinit();

    player_entities.updateMatches(ecs_world.archetypes.items);

    var iter = player_entities.iter();
    while (iter.next()) |entity_data| {
        const entity = entity_data.entity;

        // Apply player input as forces
        var force = nyon.ecs.Vector3.zero();

        if (player_input.left) force.x -= 100.0;
        if (player_input.right) force.x += 100.0;
        if (player_input.forward) force.z -= 100.0;
        if (player_input.backward) force.z += 100.0;
        if (player_input.jump) force.y += 300.0;

        physics_system.applyForce(entity, force);

        // Add some drag for control
        if (ecs_world.getComponent(entity, nyon.ecs.RigidBody)) |rb| {
            rb.linear_damping = 0.9;
        }
    }
}
