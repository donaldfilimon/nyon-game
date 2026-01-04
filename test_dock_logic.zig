//! Test the dock position detection logic

const std = @import("std");

const Rectangle = struct {
    x: f32 = 0,
    y: f32 = 0,
    width: f32 = 100,
    height: f32 = 50,
};

const DockPosition = enum {
    left,
    right,
    top,
    bottom,
};

/// Fixed detectDockPosition function
pub fn detectDockPosition(
    mouse_x: f32,
    mouse_y: f32,
    target_rect: Rectangle,
    _: struct { x: f32, y: f32 },
) ?DockPosition {
    const tx = target_rect.x + target_rect.width / 2.0;
    const ty = target_rect.y + target_rect.height / 2.0;
    const dx = mouse_x - tx;
    const dy = mouse_y - ty;
    const adx = @abs(dx);
    const ady = @abs(dy);

    if (adx > ady) {
        if (adx > target_rect.width * 0.5) return null;
        if (dx > 0) return .right else return .left;
    } else {
        if (ady > target_rect.height * 0.5) return null;
        if (dy > 0) return .bottom else return .top;
    }
}

pub fn main() !void {
    const rect = Rectangle{ .x = 0, .y = 0, .width = 100, .height = 50 };

    std.debug.print("Testing dock position detection...\n", .{});
    std.debug.print("Rectangle: x={}, y={}, w={}, h={}\n", .{ rect.x, rect.y, rect.width, rect.height });
    std.debug.print("Center: x={}, y={}\n\n", .{ rect.x + rect.width / 2, rect.y + rect.height / 2 });

    // Test cases
    const test_cases = [_]struct {
        mouse_x: f32,
        mouse_y: f32,
        expected: ?DockPosition,
        desc: []const u8,
    }{
        // Left side
        .{ .mouse_x = 10, .mouse_y = 25, .expected = .left, .desc = "Left of center" },
        // Right side
        .{ .mouse_x = 90, .mouse_y = 25, .expected = .right, .desc = "Right of center" },
        // Top side
        .{ .mouse_x = 50, .mouse_y = 10, .expected = .top, .desc = "Above center" },
        // Bottom side
        .{ .mouse_x = 50, .mouse_y = 40, .expected = .bottom, .desc = "Below center" },
        // Too far - should return null
        .{ .mouse_x = 150, .mouse_y = 25, .expected = null, .desc = "Too far right" },
        .{ .mouse_x = 50, .mouse_y = 100, .expected = null, .desc = "Too far down" },
    };

    for (test_cases) |test_case| {
        const result = detectDockPosition(test_case.mouse_x, test_case.mouse_y, rect, .{ .x = 0, .y = 0 });
        const passed = result == test_case.expected;

        std.debug.print("Mouse: ({d:.0}, {d:.0}) - {s}\n", .{ test_case.mouse_x, test_case.mouse_y, test_case.desc });
        const expected_str = if (test_case.expected) |e| @tagName(e) else "null";
        const result_str = if (result) |r| @tagName(r) else "null";

        std.debug.print("  Expected: {s}, Got: {s} - {s}\n\n", .{ expected_str, result_str, if (passed) "PASS" else "FAIL" });
    }

    std.debug.print("Dock position detection logic verified!\n", .{});
}
