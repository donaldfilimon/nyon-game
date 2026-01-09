const std = @import("std");
const automation = @import("automation");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const stdout = std.io.getStdOut().writer();

    try stdout.print("Starting Perihelion Ring AI Agent...\n", .{});

    if (@import("builtin").os.tag != .windows) {
        try stdout.print("Error: AI Agent requires Windows for UI Automation.\n", .{});
        return;
    }

    // Initialize Automation
    var auto = automation.Automation.init() catch |err| {
        try stdout.print("Failed to initialize UI Automation: {}\n", .{err});
        return;
    };
    defer auto.deinit();

    try stdout.print("UI Automation Initialized Successfully.\n", .{});

    // Try to get root element
    const root = auto.getRoot() catch |err| {
        try stdout.print("Failed to get Root Element: {}\n", .{err});
        return;
    };
    defer _ = root.Release();

    try stdout.print("Successfully acquired Root Element.\n", .{});
}
