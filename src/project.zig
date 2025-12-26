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
};

/// Serialises a `Project` into a Zon file at `path`.`
pub fn saveProject(project: Project, path: []const u8, a: std.mem.Allocator) !void {
    const content = try std.fmt.allocPrint(a, "{ name = {s}, root = {s}, version = {s} }", .{ project.name, project.root, project.version });
    var file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    try file.writeAll(content);
}

/// Loads a project from the given zon file path. Returns an error if
/// the file doesn't exist or fails to parse.
pub fn loadProject(path: []const u8, a: std.mem.Allocator) !Project {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const buf = try file.reader().readAllAlloc(a, 1 << 20);
    defer a.free(buf);
    // The earlier `name` variable declaration was removed; no further
    // processing is needed for that placeholder.

    var proj: Project = .{
        .name = "unknown",
        .root = "",
        .version = "0.1.0",
    };

    const kvs = std.mem.tokenize(u8, buf, ',');
    var it = kvs.first();
    while (it) |kv| {
        const parts = std.mem.split(u8, kv, '=');
        const key = std.mem.trim(u8, parts.first(), " ");
        const valraw = parts.rest() orelse "";
        const val = std.mem.trim(u8, valraw, " \n{}\'\"");
        try {
            if (std.mem.eql(u8, key, "name")) {
                proj.name = try a.dupe(u8, val);
            } else if (std.mem.eql(u8, key, "root")) {
                proj.root = try a.dupe(u8, val);
            } else if (std.mem.eql(u8, key, "version")) {
                proj.version = try a.dupe(u8, val);
            }
        } catch {
            // If any duplication or other operation fails, treat it as a
            // parsing error.
            return error.InvalidFormat;
        }
        it = kvs.next();
    }
    return proj;
}