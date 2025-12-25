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
};

// ============================================================================
// End Definitions -- Build/logic code below
// ============================================================================

pub fn build(b: *std.Build) void {
    // Standard build target and optimization option setup.
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Prepare external dependencies.
    const dependencies = setupDependencies(b, target, optimize);

    // Build the main library module.
    const mod = createLibraryModule(b, target, dependencies);

    // Build executable targets.
    const exe = createExecutable(b, target, optimize, mod, dependencies);
    const editor_exe = createEditorExecutable(b, target, optimize, mod, dependencies);

    // Optionally build a WASM executable for WebAssembly platforms.
    var wasm_exe: ?*std.Build.Step.Compile = null;
    if (target.result.cpu.arch == .wasm32) {
        wasm_exe = createWasmExecutable(b, target, optimize, mod);
        if (wasm_exe) |exe_wasm| {
            linkSystemLibraries(exe_wasm, target);
        }
    }

    linkSystemLibraries(exe, target);
    linkSystemLibraries(editor_exe, target);

    // Install standard executables and WASM artifacts.
    b.installArtifact(exe);
    b.installArtifact(editor_exe);
    if (wasm_exe) |exe_wasm| {
        b.installArtifact(exe_wasm);
        b.installFile("shell.html", "shell.html");
    }

    setupBuildSteps(b, exe, mod);
    setupExampleTargets(b, target, optimize, dependencies);

    // Editor run step.
    const run_editor = b.step("run-editor", "Build and run the editor");
    const run_editor_cmd = b.addRunArtifact(editor_exe);
    run_editor.dependOn(&run_editor_cmd.step);

    // WASM support: see note in original file for Emscripten/compat info.

    const build_wasm = b.step("wasm", "Build for WebAssembly (requires emscripten setup)");
    build_wasm.dependOn(b.getInstallStep());
    const run_wasm = b.step("run-wasm", "Build WASM and serve (requires web server setup)");
    run_wasm.dependOn(build_wasm);

    // CLI helper binary for project management.
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

/// Prepare and return a set of dependencies for a given build configuration.
pub fn setupDependencies(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) Dependencies {
    const is_wasm = target.result.cpu.arch == .wasm32;

    var zglfw: ?*std.Build.Module = null;
    if (!is_wasm) {
        const zglfw_dep = b.dependency("zglfw", .{
            .target = target,
            .optimize = optimize,
        });
        zglfw = zglfw_dep.module("glfw");
    }

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

/// Create the main library module for use as a dependency.
pub fn createLibraryModule(
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

/// Create the main executable target.
pub fn createExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    mod: *std.Build.Module,
    deps: Dependencies,
) *std.Build.Step.Compile {
    var imports: [2]std.Build.Module.Import = undefined;
    var import_count: usize = 0;
    imports[import_count] = .{ .name = NYON_GAME_IMPORT_NAME, .module = mod };
    import_count += 1;
    if (deps.zglfw) |zglfw_mod| {
        imports[import_count] = .{ .name = ZGLFW_IMPORT_NAME, .module = zglfw_mod };
        import_count += 1;
    }
    const exe = b.addExecutable(.{
        .name = EXECUTABLE_NAME,
        .root_module = b.createModule(.{
            .root_source_file = b.path(MAIN_SOURCE_PATH),
            .target = target,
            .optimize = optimize,
            .imports = imports[0..import_count],
        }),
    });
    if (deps.raylib_artifact) |raylib_lib| {
        exe.linkLibrary(raylib_lib);
    } else {
        exe.linkSystemLibrary("raylib");
    }
    return exe;
}

/// Create the editor executable.
pub fn createEditorExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    mod: *std.Build.Module,
    deps: Dependencies,
) *std.Build.Step.Compile {
    var imports: [3]std.Build.Module.Import = undefined;
    var import_count: usize = 0;
    imports[import_count] = .{ .name = NYON_GAME_IMPORT_NAME, .module = mod };
    import_count += 1;
    imports[import_count] = .{ .name = RAYLIB_IMPORT_NAME, .module = deps.raylib };
    import_count += 1;
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
    if (deps.raylib_artifact) |raylib_lib| {
        exe.linkLibrary(raylib_lib);
    } else {
        exe.linkSystemLibrary("raylib");
    }
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
    exe.linkLibC();
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
    exe.linkLibC();
    switch (target.result.os.tag) {
        .windows => {
            exe.linkSystemLibrary("opengl32");
            exe.linkSystemLibrary("gdi32");
            exe.linkSystemLibrary("winmm");
        },
        .macos => {
            exe.linkFramework("OpenGL");
            exe.linkFramework("Cocoa");
            exe.linkFramework("IOKit");
            exe.linkFramework("CoreVideo");
        },
        .linux => {
            exe.linkSystemLibrary("GL");
            exe.linkSystemLibrary("m");
            exe.linkSystemLibrary("pthread");
            exe.linkSystemLibrary("dl");
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
