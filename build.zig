const std = @import("std");

// ============================================================================
// Build Configuration Constants
// ============================================================================

const EXECUTABLE_NAME = "nyon_game";
const MODULE_NAME = "nyon_game";
const ROOT_MODULE_PATH = "src/root.zig";
const MAIN_SOURCE_PATH = "src/main.zig";

// Module import names (used in @import statements)
const RAYLIB_IMPORT_NAME = "raylib";
const ZGLFW_IMPORT_NAME = "zglfw";
const NYON_GAME_IMPORT_NAME = "nyon_game";

// ============================================================================
// Main Build Function
// ============================================================================

/// Main build function that configures the build graph.
///
/// This function defines:
/// - Build target and optimization options
/// - Dependencies (raylib, zglfw)
/// - Library module (nyon_game)
/// - Executable (nyon_game)
/// - Build steps (run, test)
///
/// The build system uses a declarative DSL where this function mutates the
/// build graph, which is then executed by an external runner. This allows
/// for automatic parallelization and caching.
pub fn build(b: *std.Build) void {
    // ========================================================================
    // Build Options
    // ========================================================================

    // Standard target options - allows user to choose target via `zig build -Dtarget=<target>`
    // Default is native target. No restrictions are set, so any target is allowed.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options - allows user to choose via `zig build -Doptimize=<mode>`
    // Options: Debug, ReleaseSafe, ReleaseFast, ReleaseSmall
    // No preferred mode is set, allowing the user to decide.
    const optimize = b.standardOptimizeOption(.{});

    // ========================================================================
    // Dependencies
    // ========================================================================

    const dependencies = setupDependencies(b, target, optimize);

    // ========================================================================
    // Library Module
    // ========================================================================

    const mod = createLibraryModule(b, target, dependencies);

    // ========================================================================
    // Executable
    // ========================================================================

    const exe = createExecutable(b, target, optimize, mod, dependencies);

    // ========================================================================
    // System Library Linking
    // ========================================================================

    linkSystemLibraries(exe, target);

    // ========================================================================
    // Install Step
    // ========================================================================

    // Install the executable to the install prefix (default: zig-out/)
    // Can be overridden with `zig build --prefix <path>` or `-p <path>`
    b.installArtifact(exe);

    // ========================================================================
    // Build Steps
    // ========================================================================

    setupBuildSteps(b, exe, mod);
}

// ============================================================================
// Dependency Setup
// ============================================================================

const Dependencies = struct {
    raylib: *std.Build.Module,
    raylib_artifact: *std.Build.Step.Compile,
    zglfw: *std.Build.Module,
};

/// Setup and configure all external dependencies.
///
/// Returns a struct containing all dependency modules and artifacts needed
/// for linking and importing.
fn setupDependencies(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) Dependencies {
    // zglfw dependency (for native platforms only)
    // Provides GLFW bindings for low-level window/input control
    const zglfw_dep = b.dependency("zglfw", .{
        .target = target,
        .optimize = optimize,
    });
    // Note: zglfw exposes its module as "glfw" not "zglfw"
    const zglfw = zglfw_dep.module("glfw");

    // raylib-zig dependency
    // Provides raylib bindings and the compiled raylib library
    const raylib_zig_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });
    const raylib = raylib_zig_dep.module("raylib");
    const raylib_artifact = raylib_zig_dep.artifact("raylib");

    // Note: raygui and raylib-extras are not included in raylib-zig by default.
    // They would need to be added as separate dependencies if needed.
    // For now, raylib core functionality is available via the "raylib" module.

    return .{
        .raylib = raylib,
        .raylib_artifact = raylib_artifact,
        .zglfw = zglfw,
    };
}

// ============================================================================
// Module Creation
// ============================================================================

/// Create the library module that can be imported by other packages.
///
/// This module exposes the game engine API through `src/root.zig`.
/// Other packages can depend on this module and import it as `@import("nyon_game")`.
fn createLibraryModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    deps: Dependencies,
) *std.Build.Module {
    return b.addModule(MODULE_NAME, .{
        .root_source_file = b.path(ROOT_MODULE_PATH),
        .target = target,
        .imports = &.{
            .{ .name = RAYLIB_IMPORT_NAME, .module = deps.raylib },
            .{ .name = ZGLFW_IMPORT_NAME, .module = deps.zglfw },
        },
    });
}

/// Create the main executable.
///
/// The executable uses `src/main.zig` as its entry point and imports
/// the library module along with dependencies.
fn createExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    mod: *std.Build.Module,
    deps: Dependencies,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = EXECUTABLE_NAME,
        .root_module = b.createModule(.{
            // createModule creates a module that is not exposed to package consumers,
            // unlike addModule. This is appropriate for the executable's root module.
            .root_source_file = b.path(MAIN_SOURCE_PATH),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = NYON_GAME_IMPORT_NAME, .module = mod },
                .{ .name = RAYLIB_IMPORT_NAME, .module = deps.raylib },
                .{ .name = ZGLFW_IMPORT_NAME, .module = deps.zglfw },
            },
        }),
    });

    // Link the raylib library artifact
    exe.linkLibrary(deps.raylib_artifact);

    return exe;
}

// ============================================================================
// System Library Linking
// ============================================================================

/// Link platform-specific system libraries required by raylib and GLFW.
///
/// Different platforms require different system libraries:
/// - Windows: OpenGL, GDI, WinMM
/// - macOS: OpenGL, Cocoa, IOKit, CoreVideo frameworks
/// - Linux: OpenGL, math, pthread, dl
fn linkSystemLibraries(exe: *std.Build.Step.Compile, target: std.Build.ResolvedTarget) void {
    // Always link libc (required by raylib)
    exe.linkLibC();

    // Platform-specific libraries
    switch (target.result.os.tag) {
        .windows => {
            exe.linkSystemLibrary("opengl32"); // OpenGL
            exe.linkSystemLibrary("gdi32"); // Graphics Device Interface
            exe.linkSystemLibrary("winmm"); // Windows Multimedia (audio)
            // Note: raylib includes GLFW internally, so we don't need to link it separately.
            // If you need direct GLFW access, you can use @cImport with GLFW headers.
        },
        .macos => {
            exe.linkFramework("OpenGL"); // OpenGL framework
            exe.linkFramework("Cocoa"); // Cocoa UI framework
            exe.linkFramework("IOKit"); // I/O Kit framework
            exe.linkFramework("CoreVideo"); // Core Video framework
        },
        .linux => {
            exe.linkSystemLibrary("GL"); // OpenGL
            exe.linkSystemLibrary("m"); // Math library
            exe.linkSystemLibrary("pthread"); // POSIX threads
            exe.linkSystemLibrary("dl"); // Dynamic linking
        },
        else => {
            // Other platforms may need additional libraries
            // Add platform-specific linking here as needed
        },
    }
}

// ============================================================================
// Build Steps
// ============================================================================

/// Setup all build steps (run, test).
///
/// Build steps can be invoked via `zig build <step-name>`.
/// Available steps:
/// - `zig build` or `zig build install`: Build and install the executable
/// - `zig build run`: Build and run the executable
/// - `zig build test`: Run all tests
fn setupBuildSteps(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    mod: *std.Build.Module,
) void {
    // ========================================================================
    // Run Step
    // ========================================================================

    const run_step = b.step("run", "Build and run the game");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    // Run from the installation directory (zig-out/bin/) rather than cache
    run_cmd.step.dependOn(b.getInstallStep());

    // Allow passing arguments: `zig build run -- --arg1 --arg2`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // ========================================================================
    // Test Steps
    // ========================================================================

    // Test the library module (src/root.zig and its dependencies)
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    // Test the executable module (src/main.zig and its dependencies)
    // Note: Test executables only test one module at a time, hence two separate test executables
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    // Top-level test step that runs all tests in parallel
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
