const std = @import("std");
const nyon_game = @import("nyon_game");
const application_mod = nyon_game.application;

// ============================================================================
// Main Entry Point
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try application_mod.Application.init(allocator);
    defer app.deinit();

    try app.run();
}
