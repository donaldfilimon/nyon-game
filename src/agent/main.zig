const std = @import("std");
const automation = @import("automation");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    std.log.info("Starting Perihelion Ring AI Agent...", .{});

    if (@import("builtin").os.tag != .windows) {
        std.log.err("Error: AI Agent requires Windows for UI Automation.", .{});
        return;
    }

    // Initialize Automation
    var auto = automation.Automation.init() catch |err| {
        std.log.err("Failed to initialize UI Automation: {}", .{err});
        return;
    };
    defer auto.deinit();

    std.log.info("UI Automation Initialized Successfully.", .{});

    // Try to get root element
    const root = auto.getRoot() catch |err| {
        std.log.err("Failed to get Root Element: {}", .{err});
        return;
    };
    defer _ = root.Release();

    std.log.info("Successfully acquired Root Element.", .{});
}
