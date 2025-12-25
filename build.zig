/// @Browser @Definitions
const std = @import("std");

// ============================================================================
// Build Configuration Definitions
// ============================================================================

/// The name of the main executable.
pub const EXECUTABLE_NAME = "nyon_game";

/// The name for the library module, used as an import name.
pub const MODULE_NAME = "nyon_game";

/// The root source file for the main library module.
pub const ROOT_MODULE_PATH = "src/root.zig";

/// The main entry source file for the application.
pub const MAIN_SOURCE_PATH = "src/main.zig";

/// The import name for raylib, to be used with @import().
pub const RAYLIB_IMPORT_NAME = "raylib";

/// The import name for zglfw, to be used with @import().
pub const ZGLFW_IMPORT_NAME = "zglfw";

/// The import name for this project's library module.
pub const NYON_GAME_IMPORT_NAME = "nyon_game";

/// Data structure used to track dependencies prepared by the build system.
pub const Dependencies = struct {
    raylib: *std.Build.Module,
    raylib_artifact: ?*std.Build.Step.Compile,
    zglfw: ?*std.Build.Module,
};

/// Data record for an example target.
pub const Example = struct {
    name: []const u8,
    source: []const u8,
    description: []const u8,
};

/// List of all available example targets.
pub const EXAMPLES = [_]Example{
    Example{
        .name = "example-file-browser",
        .source = "examples/raylib/file_browser.zig",
        .description = "Compile and run the Raylib file browser sample",
    },
    Example{
        .name = "example-drop-viewer",
        .source = "examples/raylib/drop_viewer.zig",
        .description = "Show drag-and-drop metadata via Raylib file IO",
    },
    Example{
        .name = "example-webgpu-basic",
        .source = "examples/webgpu_basic.zig",
        .description = "Basic WebGPU backend example",
    },
};

// ============================================================================
// End Definitions -- Build/logic code below
// ============================================================================

pub fn build(b: *std.Build) void {
    // Standard build target and optimization option setup.
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create raylib stub module
    const raylib_stub = b.addModule("raylib", .{
        .root_source_file = b.path("src/raylib_stub.zig"),
        .target = target,
    });

    // Build executable targets directly (simplified for refactoring)
    const exe = b.addExecutable(.{
        .name = EXECUTABLE_NAME,
        .root_module = b.createModule(.{
            .root_source_file = b.path(MAIN_SOURCE_PATH),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "raylib", .module = raylib_stub },
            },
        }),
    });
    exe.root_module.link_libc = true;

    const editor_exe = b.addExecutable(.{
        .name = "nyon_editor",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/editor.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "raylib", .module = raylib_stub },
            },
        }),
    });
    editor_exe.root_module.link_libc = true;

    // Install executables
    b.installArtifact(exe);
    b.installArtifact(editor_exe);

    // Test step
    const test_step = b.step("test", "Run all tests");
    const test_cmd = b.addSystemCommand(&[_][]const u8{ "zig", "test", "src/tests.zig" });
    test_step.dependOn(&test_cmd.step);

    // Run steps
    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the game");
    run_step.dependOn(&run_cmd.step);

    const run_editor = b.step("run-editor", "Build and run the editor");
    const run_editor_cmd = b.addRunArtifact(editor_exe);
    run_editor.dependOn(&run_editor_cmd.step);
}
