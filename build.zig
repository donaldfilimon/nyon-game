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

    // Safety checks are enabled in source code via GeneralPurposeAllocator(.{.safety = true})

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

    // Build main game executable
    const exe = createExecutable(b, target, optimize, mod, dependencies);

    // Build editor executable (shares same deps & module)
    const editor_exe = createEditorExecutable(b, target, optimize, mod, dependencies);

    // Build WASM version for web (if targeting WASM)
    var wasm_exe: ?*std.Build.Step.Compile = null;
    if (target.result.cpu.arch == .wasm32) {
        wasm_exe = createWasmExecutable(b, target, optimize, mod);
        if (wasm_exe) |exe_wasm| {
            linkSystemLibraries(exe_wasm, target);
        }
    }

    // ========================================================================
    // System Library Linking
    // ========================================================================

    linkSystemLibraries(exe, target);
    linkSystemLibraries(editor_exe, target);

    // ========================================================================
    // Install Step
    // ========================================================================

    // Install the executable to the install prefix (default: zig-out/)
    // Can be overridden with `zig build --prefix <path>` or `-p <path>`
    b.installArtifact(exe);
    b.installArtifact(editor_exe);

    // Install WASM files if building for WASM
    if (wasm_exe) |exe_wasm| {
        b.installArtifact(exe_wasm);

        // Install shell.html for emscripten
        b.installFile("shell.html", "shell.html");
    }

    // ========================================================================
    // Build Steps
    // ========================================================================

    setupBuildSteps(b, exe, mod);
    setupExampleTargets(b, target, optimize, dependencies);

    // Run editor
    const run_editor = b.step("run-editor", "Build and run the editor");
    const run_editor_cmd = b.addRunArtifact(editor_exe);
    run_editor.dependOn(&run_editor_cmd.step);
    run_editor_cmd.step.dependOn(b.getInstallStep());

    // WASM support note: Currently requires manual setup with emscripten
    // The raylib-zig library needs to be updated to support WASM targets
    // For WASM builds, you would need:
    // 1. A WASM-compatible raylib build
    // 2. Emscripten toolchain
    // 3. Custom build configuration

    const build_wasm = b.step("wasm", "Build for WebAssembly (requires emscripten setup)");
    build_wasm.dependOn(b.getInstallStep()); // Just install regular build for now

    const run_wasm = b.step("run-wasm", "Build WASM and serve (requires web server setup)");
    run_wasm.dependOn(build_wasm);

    // Install the CLI helper for project management
    const cli = b.addExecutable(.{
        .name = "nyon-cli",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/cli.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(cli);
}

// ============================================================================
// Dependency Setup
// ============================================================================

const Dependencies = struct {
    raylib: *std.Build.Module,
    raylib_artifact: ?*std.Build.Step.Compile,
    zglfw: ?*std.Build.Module,
};

const Example = struct {
    name: []const u8,
    source: []const u8,
    description: []const u8,
};

const EXAMPLES = [_]Example{
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
    // Check if target is WASM (WebAssembly)
    const is_wasm = target.result.cpu.arch == .wasm32;

    // zglfw dependency (for native platforms only, not available for WASM)
    var zglfw: ?*std.Build.Module = null;
    if (!is_wasm) {
        // Provides GLFW bindings for low-level window/input control
        const zglfw_dep = b.dependency("zglfw", .{
            .target = target,
            .optimize = optimize,
        });
        // Note: zglfw exposes its module as "glfw" not "zglfw"
        zglfw = zglfw_dep.module("glfw");
    }

    // raylib-zig dependency
    // raylib-zig dependency
    // Provides raylib bindings and the compiled raylib library
    const raylib_zig_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });
    const raylib_module = raylib_zig_dep.module("raylib");
    const raylib_artifact = raylib_zig_dep.artifact("raylib");

    return .{
        .raylib = raylib_module,
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
        .imports = if (deps.zglfw) |zglfw| &.{
            .{ .name = RAYLIB_IMPORT_NAME, .module = deps.raylib },
            .{ .name = ZGLFW_IMPORT_NAME, .module = zglfw },
        } else &.{
            .{ .name = RAYLIB_IMPORT_NAME, .module = deps.raylib },
        },
    });
}

/// Create the main executable.
/// The executable uses `src/main.zig` as its entry point and imports
/// the library module along with dependencies.
fn createExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    mod: *std.Build.Module,
    deps: Dependencies,
) *std.Build.Step.Compile {
    // Build import array conditionally (zglfw not available for WASM)
    var imports: [2]std.Build.Module.Import = undefined;
    var import_count: usize = 0;

    imports[import_count] = .{ .name = NYON_GAME_IMPORT_NAME, .module = mod };
    import_count += 1;

    // Only add zglfw if available (not available for WASM)
    if (deps.zglfw) |zglfw_mod| {
        imports[import_count] = .{ .name = ZGLFW_IMPORT_NAME, .module = zglfw_mod };
        import_count += 1;
    }

    const exe = b.addExecutable(.{
        .name = EXECUTABLE_NAME,
        .root_module = b.createModule(.{
            // createModule creates a module that is not exposed to package consumers,
            // unlike addModule. This is appropriate for the executable's root module.
            .root_source_file = b.path(MAIN_SOURCE_PATH),
            .target = target,
            .optimize = optimize,
            .imports = imports[0..import_count],
        }),
    });

    // Link the raylib library if available
    if (deps.raylib_artifact) |raylib_lib| {
        exe.linkLibrary(raylib_lib);
    } else {
        // Assume system-installed raylib
        exe.linkSystemLibrary("raylib");
    }

    return exe;
}

fn createEditorExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    mod: *std.Build.Module,
    deps: Dependencies,
) *std.Build.Step.Compile {
    // Build import array conditionally (zglfw not available for WASM)
    var imports: [3]std.Build.Module.Import = undefined;
    var import_count: usize = 0;

    imports[import_count] = .{ .name = NYON_GAME_IMPORT_NAME, .module = mod };
    import_count += 1;
    imports[import_count] = .{ .name = RAYLIB_IMPORT_NAME, .module = deps.raylib };
    import_count += 1;

    // Only add zglfw if available (not available for WASM)
    if (deps.zglfw) |zglfw_mod| {
        imports[import_count] = .{ .name = ZGLFW_IMPORT_NAME, .module = zglfw_mod };
        import_count += 1;
    }

    const exe = b.addExecutable(.{
        .name = "nyon_editor",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/editor.zig"),
            .target = target,
            .optimize = optimize,
            .imports = imports[0..import_count],
        }),
    });

    // Link the raylib library if available
    if (deps.raylib_artifact) |raylib_lib| {
        exe.linkLibrary(raylib_lib);
    } else {
        // Assume system-installed raylib
        exe.linkSystemLibrary("raylib");
    }

    return exe;
}

fn createWasmExecutable(
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
                // Note: raylib and zglfw not available for WASM, GLFW is handled by emscripten
            },
        }),
    });

    // Configure for emscripten
    exe.entry = .disabled; // Use emscripten's main
    exe.rdynamic = true;
    exe.linkLibC();

    return exe;
}

fn createExampleExecutable(
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

// ============================================================================
// System Library Linking
// ============================================================================

/// Link platform-specific system libraries required by raylib and GLFW.
///
/// Different platforms require different system libraries:
/// - Windows: OpenGL, GDI, WinMM
/// - macOS: OpenGL, Cocoa, IOKit, CoreVideo frameworks
/// - Linux: OpenGL, math, pthread, dl
/// - WASM: No system libraries needed (emscripten handles this)
fn linkSystemLibraries(exe: *std.Build.Step.Compile, target: std.Build.ResolvedTarget) void {
    // For WASM targets, emscripten handles all linking
    if (target.result.cpu.arch == .wasm32) {
        return;
    }

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

    // Run with project root as CWD so relative asset/UI paths resolve.
    run_cmd.setCwd(b.path("."));

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

fn setupExampleTargets(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    deps: Dependencies,
) void {
    // Temporarily disabled examples due to raylib dependency issues
    // TODO: Re-enable once raylib C library is properly installed/linked
    _ = b;
    _ = target;
    _ = optimize;
    _ = deps;
}
