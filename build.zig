const std = @import("std");

// ============================================================================
// Nyon Engine - GPU-Accelerated Build Configuration
// ============================================================================

/// The name of the main executable.
pub const EXECUTABLE_NAME = "nyon_game";

/// The root source file for the main library module.
pub const ROOT_MODULE_PATH = "src/root.zig";

/// The main entry source file for the application.
pub const MAIN_SOURCE_PATH = "src/main.zig";

/// Editor entry point
pub const EDITOR_SOURCE_PATH = "src/editor.zig";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the main nyon_game module (pure Zig, no external dependencies)
    const nyon_game_mod = b.createModule(.{
        .root_source_file = b.path(ROOT_MODULE_PATH),
        .target = target,
        .optimize = optimize,
    });
    if (target.result.os.tag == .windows) {
        nyon_game_mod.linkSystemLibrary("user32", .{});
        nyon_game_mod.linkSystemLibrary("gdi32", .{});
    }

    // Build main executable
    const exe = b.addExecutable(.{
        .name = EXECUTABLE_NAME,
        .root_module = b.createModule(.{
            .root_source_file = b.path(MAIN_SOURCE_PATH),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "nyon_game", .module = nyon_game_mod },
            },
        }),
    });
    b.installArtifact(exe);

    // Build editor executable
    const editor_exe = b.addExecutable(.{
        .name = "nyon_editor",
        .root_module = b.createModule(.{
            .root_source_file = b.path(EDITOR_SOURCE_PATH),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "nyon_game", .module = nyon_game_mod },
            },
        }),
    });
    b.installArtifact(editor_exe);

    // Build agent executable
    const automation_mod = b.createModule(.{
        .root_source_file = b.path("src/platform/automation_win32.zig"),
        .target = target,
        .optimize = optimize,
    });

    const agent_exe = b.addExecutable(.{
        .name = "perihelion_agent",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/agent/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "automation", .module = automation_mod },
            },
        }),
    });
    if (target.result.os.tag == .windows) {
        agent_exe.root_module.linkSystemLibrary("ole32", .{});
        agent_exe.root_module.linkSystemLibrary("oleaut32", .{});
    }
    b.installArtifact(agent_exe);

    const run_agent_step = b.step("run-agent", "Run the AI Agent");
    const run_agent_cmd = b.addRunArtifact(agent_exe);
    run_agent_step.dependOn(&run_agent_cmd.step);

    // GPU compute shader target (SPIR-V)
    const gpu_target_spirv = b.resolveTargetQuery(.{
        .cpu_arch = .spirv64,
        .os_tag = .vulkan,
    });

    // GPU compute module (compiles to SPIR-V)
    const gpu_compute_mod = b.addObject(.{
        .name = "nyon_compute",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gpu/compute.zig"),
            .target = gpu_target_spirv,
            .optimize = .ReleaseFast,
        }),
    });

    // Build steps
    const run_step = b.step("run", "Build and run the game");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.setCwd(b.path("."));
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_editor_step = b.step("run-editor", "Build and run the editor");
    const run_editor_cmd = b.addRunArtifact(editor_exe);
    run_editor_step.dependOn(&run_editor_cmd.step);
    run_editor_cmd.setCwd(b.path("."));

    // SPIR-V build step
    const spirv_step = b.step("spirv", "Compile GPU shaders to SPIR-V");
    spirv_step.dependOn(&gpu_compute_mod.step);

    // Tests
    const mod_tests = b.addTest(.{
        .root_module = nyon_game_mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_mod_tests.step);

    // WASM target (experimental)
    // Note: wasm32-freestanding has std library limitations in Zig 0.16 that prevent
    // full compilation of the engine (no Thread, DynLib, or posix support).
    // A dedicated WASM entry point with conditional compilation would be needed.
    const wasm_step = b.step("wasm", "Build for WebAssembly (experimental)");
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });
    const wasm_mod = b.createModule(.{
        .root_source_file = b.path(ROOT_MODULE_PATH),
        .target = wasm_target,
        .optimize = .ReleaseSmall,
    });
    const wasm_exe = b.addExecutable(.{
        .name = "nyon_game",
        .root_module = b.createModule(.{
            .root_source_file = b.path(MAIN_SOURCE_PATH),
            .target = wasm_target,
            .optimize = .ReleaseSmall,
            .imports = &.{
                .{ .name = "nyon_game", .module = wasm_mod },
            },
        }),
    });
    wasm_exe.entry = .disabled;
    wasm_exe.rdynamic = true;
    const wasm_install = b.addInstallArtifact(wasm_exe, .{});
    wasm_step.dependOn(&wasm_install.step);

    // NVPTX target (NVIDIA GPU)
    const nvptx_step = b.step("nvptx", "Compile GPU shaders to PTX (NVIDIA)");
    const nvptx_target = b.resolveTargetQuery(.{
        .cpu_arch = .nvptx64,
        .os_tag = .cuda,
    });
    const nvptx_mod = b.addObject(.{
        .name = "nyon_compute_ptx",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gpu/compute.zig"),
            .target = nvptx_target,
            .optimize = .ReleaseFast,
        }),
    });
    nvptx_step.dependOn(&nvptx_mod.step);
}
