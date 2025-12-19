//! Quick physics test
const std = @import("std");
const physics = @import("../src/physics/physics.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create physics world
    var world = physics.world.PhysicsWorld.init(allocator, .{});
    defer world.deinit();

    // Create a falling ball
    const ball_body = physics.rigidbody.RigidBody.dynamic(1.0, physics.types.Vector3.init(0, 10, 0));
    const ball_collider = physics.colliders.Collider.sphere(physics.types.Vector3.zero(), 1.0);

    const ball_handle = try world.createBody(ball_body);
    try world.attachCollider(ball_handle, ball_collider);

    // Create ground
    const ground_body = physics.rigidbody.RigidBody.static(physics.types.Vector3.init(0, -5, 0));
    const ground_collider = physics.colliders.Collider.box(physics.types.Vector3.zero(), physics.types.Vector3.init(20, 1, 20));

    const ground_handle = try world.createBody(ground_body);
    try world.attachCollider(ground_handle, ground_collider);

    std.debug.print("Physics test initialized with {} bodies\n", .{world.getStats().bodies});

    // Simulate for a few seconds
    var time: f32 = 0;
    while (time < 3.0) {
        try world.step(1.0 / 60.0);
        time += 1.0 / 60.0;

        if (world.getBody(ball_handle)) |body| {
            std.debug.print("Ball at ({d:.2}, {d:.2}, {d:.2})\r", .{ body.position.x, body.position.y, body.position.z });
        }
    }

    std.debug.print("\nPhysics simulation completed!\n", .{});
}
