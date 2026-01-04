//! Test the title menu action enum contains continue_last

const std = @import("std");
const expect = std.testing.expect;

// Import the menu enum
const menus_mod = @import("src/ui/menus.zig");

test "TitleMenuAction includes continue_last" {
    // Test that the enum variant exists
    const action = menus_mod.TitleMenuAction.continue_last;
    try expect(action == .continue_last);
}
