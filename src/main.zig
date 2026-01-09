//! Nyon Game Engine - Main Entry Point

const std = @import("std");
const nyon = @import("nyon_game");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.log.info("Nyon Engine v{s} starting...", .{nyon.VERSION.string});

    // Initialize engine
    var engine = try nyon.Engine.init(allocator, .{
        .window_width = 1280,
        .window_height = 720,
        .window_title = "Nyon Engine",
        .gpu_backend = .spirv_vulkan,
    });
    defer engine.deinit();

    // Log GPU info
    if (engine.gpu_context) |ctx| {
        std.log.info("GPU: {s}", .{ctx.device_info.getName()});
    } else {
        std.log.info("Running in software mode (no GPU)", .{});
    }

    // Create a test entity
    const camera_entity = try engine.world.spawn();
    try engine.world.addComponent(camera_entity, nyon.ecs.Name, nyon.ecs.component.Name.init("Main Camera"));
    try engine.world.addComponent(camera_entity, nyon.ecs.Transform, .{
        .position = nyon.Vec3.init(0, 2, 5),
    });
    try engine.world.addComponent(camera_entity, nyon.ecs.Camera, .{
        .is_active = true,
        .fov = 60.0,
    });

    // Create a cube
    const cube_entity = try engine.world.spawn();
    try engine.world.addComponent(cube_entity, nyon.ecs.Name, nyon.ecs.component.Name.init("Cube"));
    try engine.world.addComponent(cube_entity, nyon.ecs.Transform, .{});
    try engine.world.addComponent(cube_entity, nyon.ecs.Renderable, .{});

    std.log.info("Created {} entities", .{engine.world.entityCount()});

    // Run game loop
    engine.run(gameUpdate);

    std.log.info("Engine shutdown. Frames: {}, Avg FPS: {d:.1}", .{
        engine.frame_count,
        if (engine.total_time > 0) @as(f64, @floatFromInt(engine.frame_count)) / engine.total_time else 0,
    });
}

fn gameUpdate(engine: *nyon.Engine) void {
    // Rotate entities named "Cube"
    var query = nyon.ecs.Query(&[_]type{ nyon.ecs.Transform, nyon.ecs.Name }).init(&engine.world);
    var iter = query.iter();
    while (iter.next()) |res| {
        var res_copy = res;
        const name = res_copy.get(nyon.ecs.Name).get();
        if (std.mem.eql(u8, name, "Cube")) {
            const transform = res_copy.get(nyon.ecs.Transform);
            const rot = nyon.math.Quat.fromAxisAngle(nyon.math.Vec3.UP, @as(f32, @floatCast(engine.delta_time)));
            transform.rotation = nyon.math.Quat.mul(transform.rotation, rot);
        }
    }
}

test {
    std.testing.refAllDecls(@This());
}
