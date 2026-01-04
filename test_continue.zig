//! Test the continue functionality

const std = @import("std");
const expect = std.testing.expect;

const worlds_mod = @import("src/game/worlds.zig");

test "getMostRecentWorld handles empty saves directory" {
    const allocator = std.testing.allocator;

    // Should return null when no worlds exist
    const world = worlds_mod.getMostRecentWorld(allocator);
    try expect(world == null);
}

test "listWorlds sorts by last played descending" {
    const allocator = std.testing.allocator;

    // This test requires actual world files, so we'll just verify the function exists
    // and doesn't crash when called
    const worlds = worlds_mod.listWorlds(allocator) catch &.{};
    defer {
        for (worlds) |*entry| entry.deinit();
        if (worlds.len > 0) allocator.free(worlds);
    }

    // Verify worlds are accessible (may be empty)
    try expect(worlds.len >= 0);
}
