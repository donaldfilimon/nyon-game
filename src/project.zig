// Project configuration and serialization for Nyon projects.
// This module provides a minimal `Project` struct and functions to
// load/save it from/to a `.zon` file.
//
// The zon format is intentionally simple: it contains only a few
// fields that are useful for a git‑backed project. Additional fields
// can be added as needed.
//
// Example structure:
//   {
//       name = "my_project",
//       root = "/path/to/project",
//       version = "0.1.0",
//   }
//
// The project file is named `project.zon` and situated at the root of a
// project directory.

const std = @import("std");

pub const Project = struct {
    name: []const u8,
    root: []const u8,
    version: []const u8 = "0.1.0",

    pub fn deinit(self: *Project, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.root);
        allocator.free(self.version);
        self.* = undefined;
    }
};

/// Serialises a `Project` into a Zon file at `path`.`
pub fn saveProject(project: Project, path: []const u8, a: std.mem.Allocator) !void {
    const content = try std.fmt.allocPrint(
        a,
        "{{\n  name = \"{s}\",\n  root = \"{s}\",\n  version = \"{s}\",\n}}\n",
        .{ project.name, project.root, project.version },
    );
    defer a.free(content);
    var file = try std.Io.Dir.cwd().createFile(path, .{ .truncate = true });
    defer file.close();
    try file.writeAll(content);
}

/// Loads a project from the given zon file path. Returns an error if
/// the file doesn't exist or fails to parse.
pub fn loadProject(path: []const u8, a: std.mem.Allocator) !Project {
    var file = try std.Io.Dir.cwd().openFile(path, .{});
    defer file.close();
    const buf = try file.reader().readAllAlloc(a, 1 << 20);
    defer a.free(buf);
    var proj = Project{
        .name = try a.dupe(u8, "unknown"),
        .root = try a.dupe(u8, ""),
        .version = try a.dupe(u8, "0.1.0"),
    };
    errdefer proj.deinit(a);

    var it = std.mem.splitScalar(u8, buf, ',');
    while (it.next()) |kv| {
        var parts = std.mem.splitScalar(u8, kv, '=');
        const key = std.mem.trim(u8, parts.next() orelse "", " \n\t{}");
        const valraw = parts.next() orelse "";
        const val = std.mem.trim(u8, valraw, " \n\t{}'\"");

        if (std.mem.eql(u8, key, "name")) {
            a.free(proj.name);
            proj.name = try a.dupe(u8, val);
        } else if (std.mem.eql(u8, key, "root")) {
            a.free(proj.root);
            proj.root = try a.dupe(u8, val);
        } else if (std.mem.eql(u8, key, "version")) {
            a.free(proj.version);
            proj.version = try a.dupe(u8, val);
        }
    }

    return proj;
}
