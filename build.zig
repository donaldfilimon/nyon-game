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

    // Create raylib dependency
    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });
    const raylib_mod = raylib_dep.module("raylib");
    const raylib_lib = raylib_dep.artifact("raylib");

    const zglfw_dep = b.dependency("zglfw", .{
        .target = target,
        .optimize = optimize,
    });
    const zglfw_mod = zglfw_dep.module("root");
    const zglfw_lib = if (target.result.os.tag == .emscripten)
        null
    else
        zglfw_dep.artifact("glfw");

    const nyon_game_mod = b.createModule(.{
        .root_source_file = b.path(ROOT_MODULE_PATH),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = RAYLIB_IMPORT_NAME, .module = raylib_mod },
            .{ .name = ZGLFW_IMPORT_NAME, .module = zglfw_mod },
        },
    });
    nyon_game_mod.addImport(NYON_GAME_IMPORT_NAME, nyon_game_mod);

    // Build executable targets directly (simplified for refactoring)
    const exe = b.addExecutable(.{
        .name = EXECUTABLE_NAME,
        .root_module = b.createModule(.{
            .root_source_file = b.path(MAIN_SOURCE_PATH),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "raylib", .module = raylib_mod },
                .{ .name = "zglfw", .module = zglfw_mod },
                .{ .name = NYON_GAME_IMPORT_NAME, .module = nyon_game_mod },
            },
        }),
    });
    exe.root_module.linkLibrary(raylib_lib);
    if (zglfw_lib) |glfw_lib| {
        exe.root_module.linkLibrary(glfw_lib);
    }
    exe.root_module.link_libc = true;
    b.installArtifact(exe);

    const editor_exe = b.addExecutable(.{
        .name = "nyon_editor",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/editor.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "raylib", .module = raylib_mod },
                .{ .name = "zglfw", .module = zglfw_mod },
                .{ .name = NYON_GAME_IMPORT_NAME, .module = nyon_game_mod },
            },
        }),
    });
    editor_exe.root_module.linkLibrary(raylib_lib);
    if (zglfw_lib) |glfw_lib| {
        editor_exe.root_module.linkLibrary(glfw_lib);
    }
    editor_exe.root_module.link_libc = true;
    b.installArtifact(editor_exe);

    setupBuildSteps(b, exe, exe.root_module, raylib_lib, zglfw_lib);
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
        exe.root_module.linkLibrary(raylib_lib);
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
    raylib_lib: *std.Build.Step.Compile,
    zglfw_lib: ?*std.Build.Step.Compile,
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
    mod_tests.root_module.linkLibrary(raylib_lib);
    if (zglfw_lib) |glfw_lib| {
        mod_tests.root_module.linkLibrary(glfw_lib);
    }
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    exe_tests.root_module.linkLibrary(raylib_lib);
    if (zglfw_lib) |glfw_lib| {
        exe_tests.root_module.linkLibrary(glfw_lib);
    }
    const run_exe_tests = b.addRunArtifact(exe_tests);

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
