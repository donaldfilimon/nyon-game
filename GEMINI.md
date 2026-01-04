# Nyon Game Engine - Context for Agents

## Project Overview

**Nyon Game** is a minimal, cross-platform game engine written in Zig (0.16.x). It integrates with **Raylib** for rendering and input handling. The project includes a 3D sandbox game demo and a node-based geometry editor.

**Key Features:**

- **Engine:** Core systems for Windowing, Input, Audio, and ECS.
- **Rendering:** Raylib-based backend with support for Materials and Post-processing.
- **UI:** Custom immediate-mode UI system with persistent layouts (JSON), docking, and edit mode (`F1`).
- **Editor:** Features a property inspector, scene editor, and node-based geometry system.
- **Platform:** Native (Windows/macOS/Linux) and WebAssembly (via Emscripten).

## Building and Running

The project uses the standard `zig build` system.

| Command                          | Description                                                            |
| :------------------------------- | :--------------------------------------------------------------------- |
| `zig build`                      | Build the main game executable.                                        |
| `zig build run`                  | Build and run the **Sandbox Game** (Free-fly camera, block placement). |
| `zig build run-editor`           | Build and run the **Editor** (Node graph, inspector).                  |
| `zig build test`                 | Run all unit tests.                                                    |
| `zig build example-file-browser` | Build the Raylib file browser example.                                 |
| `zig build wasm`                 | Build for WebAssembly (requires Emscripten).                           |

**Key Inputs:**

- **Game:** `WASD` Move, `Mouse` Look, `L-Click` Place, `Ctrl+L-Click` Remove, `F1` UI Edit, `F2` Settings.
- **Editor:** `Ctrl+S` Save, `Ctrl+D` Debug Graph, Mouse to interact with nodes/panels.

## Codebase Structure

### Root Directory

- `build.zig`: Build configuration and dependency management (Raylib, zglfw).
- `src/`: Source code root.
- `examples/`: Standalone examples demonstrating specific features (Raylib integration).
- `saves/`: Directory for game save data (JSON format).

### Source (`src/`)

- `main.zig`: Entry point for the **Sandbox Game**.
- `editor.zig` / `main_editor.zig`: Entry point and main loop for the **Editor**.
- `root.zig`: Public API re-exports.
- `engine.zig`: Core engine abstractions (Window, Input, Audio).
- `ecs/`: Entity-Component-System implementation (`world.zig`, `entity.zig`, `component.zig`).
- `ui/`: Immediate-mode UI system (`ui.zig`, `menus.zig`, `sandbox_ui.zig`).
- `rendering/`: Render graph, passes, and resources.
- `nodes/`: Node graph system for the editor (`node_graph.zig`).
- `game/`: Game-specific logic (`sandbox.zig`, `worlds.zig`, `physics_integration.zig`).

## Development Guidelines

**Strictly adhere to the conventions defined in `AGENTS.md`:**

### Coding Style

- **Formatting:** Use `zig fmt` (4 spaces indentation).
- **Naming:**
  - Types/Structs: `PascalCase`
  - Functions/Variables: `camelCase`
  - Constants: `ALL_CAPS`
- **Imports:** Order: `std` -> External (Raylib/zglfw) -> Local (aliased, e.g., `const ui = @import("ui/ui.zig")`).

### Architecture & Memory

- **Allocation:** Explicitly pass `std.mem.Allocator` to functions requiring allocation. Prefer `std.heap.GeneralPurposeAllocator` in debug.
- **Ownership:** Clearly define ownership in struct documentation. Use `deinit()` methods for cleanup.
- **Error Handling:** Use Zig's `try`/`catch` mechanism. Define custom error sets where appropriate.

### Testing

- Write unit tests in the same file as the code they test, using `test "description" { ... }`.
- Use `std.testing` and `std.testing.allocator`.
- Run tests frequently: `zig build test`.
