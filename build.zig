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
    return exe;
}

/// Create the editor executable.
pub fn createEditorExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    mod: *std.Build.Module,
    _: Dependencies,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = "nyon_editor",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/editor.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = NYON_GAME_IMPORT_NAME, .module = mod },
            },
        }),
    });
    exe.root_module.link_libc = true;
    return exe;
}

/// Create a WASM build target (WebAssembly, Emscripten).
pub fn createWasmExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    mod: *std.Build.Module,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = "nyon_game",
        .root_module = b.createModule(.{
            .root_source_file = b.path(MAIN_SOURCE_PATH),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = NYON_GAME_IMPORT_NAME, .module = mod },
            },
        }),
    });
    exe.entry = .disabled;
    exe.rdynamic = true;
    exe.root_module.link_libc = true;
    return exe;
}

/// Create an example executable.
pub fn createExampleExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    deps: Dependencies,
    source: []const u8,
    name: []const u8,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(source),
            .target = target,
            .optimize = optimize,
        }),
    });
    if (deps.raylib_artifact) |raylib_lib| {
        exe.linkLibrary(raylib_lib);
    }
    return exe;
}

/// Link system libraries/frameworks as needed for the build target.
pub fn linkSystemLibraries(exe: *std.Build.Step.Compile, target: std.Build.ResolvedTarget) void {
    if (target.result.cpu.arch == .wasm32) return;
    exe.root_module.link_libc = true;
    switch (target.result.os.tag) {
        .windows => {
            exe.root_module.linkSystemLibrary("opengl32", .{});
            exe.root_module.linkSystemLibrary("gdi32", .{});
            exe.root_module.linkSystemLibrary("winmm", .{});
        },
        .macos => {
            exe.root_module.linkFramework("OpenGL", .{});
            exe.root_module.linkFramework("Cocoa", .{});
            exe.root_module.linkFramework("IOKit", .{});
            exe.root_module.linkFramework("CoreVideo", .{});
        },
        .linux => {
            exe.root_module.linkSystemLibrary("GL", .{});
            exe.root_module.linkSystemLibrary("m", .{});
            exe.root_module.linkSystemLibrary("pthread", .{});
            exe.root_module.linkSystemLibrary("dl", .{});
        },
        else => {},
    }
}

/// Set up the run/test build steps.
pub fn setupBuildSteps(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    mod: *std.Build.Module,
) void {
    const run_step = b.step("run", "Build and run the game");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.setCwd(b.path("."));
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}

/// Configure example build targets.
/// (Currently disabled; see original comment in template.)
pub fn setupExampleTargets(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    deps: Dependencies,
) void {
    _ = b;
    _ = target;
    _ = optimize;
    _ = deps;
}
