const std = @import("std");
const application_mod = @import("application.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try application_mod.Application.init(allocator);
    defer app.deinit();

    try app.run();
}
