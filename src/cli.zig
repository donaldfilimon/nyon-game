// A tiny command‑line helper for managing Nyon projects.
// It currently supports:
//   init   – create a new project.zon with defaults.
//   save   – overwrite current project.zon with updated data.
//
// Usage examples:
//   zig build nyon-cli init
//   zig build nyon-cli save

const std = @import("std");
const Project = @import("project").Project;
const project_module = @import("project");

pub fn main() void {
    // CLI functionality temporarily disabled - argument parsing issues
    std.debug.print("CLI functionality temporarily disabled due to argument parsing issues\n", .{});
}

fn initProject(alloc: std.mem.Allocator, cwd: std.fs.Dir) !void {
    const dir_name = try cwd.getName(alloc);
    defer alloc.free(dir_name);
    const proj: Project = .{
        .name = dir_name,
        .root = try cwd.realpath("/", alloc),
    };
    const zon_path = try std.fs.path.join(alloc, &.{"project.zon"});
    defer alloc.free(zon_path);
    try project_module.saveProject(proj, zon_path, alloc);
    std.debug.print("Project initialized at {s}\n", .{zon_path});
}

fn saveProject(alloc: std.mem.Allocator, cwd: std.fs.Dir, zon_path: []const u8) !void {
    _ = cwd; // Not used in this demo implementation
    const proj = try project_module.loadProject(zon_path, alloc);
    // For demo we simply rewrite the same data; real logic could update metadata.
    try project_module.saveProject(proj, zon_path, alloc);
    std.debug.print("Project saved at {s}\n", .{zon_path});
}
