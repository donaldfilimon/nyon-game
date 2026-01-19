# Nyon Game Engine - Agent Instructions

## Build/Lint/Test Commands

- Build game: `zig build` / `zig build run`
- Build editor: `zig build run-editor`
- Build CLI: `zig build nyon-cli`
- Build examples: `zig build example-file-browser` / `zig build example-drop-viewer`
- Build WebAssembly: `zig build wasm`
- Run all tests: `zig build test`
- Run single test file: `zig build test -- <path/to/test.zig>`
- Lint/format: `zig fmt --check` (check) / `zig fmt` (apply)

## Known Issues

- **Dependency Compatibility**: Raylib-zig and zglfw dependencies have API compatibility issues with Zig 0.16.x. Currently using raylib_stub.zig as workaround. Need to find compatible raylib bindings or use C library directly.

## Code Style Guidelines

- **Imports**: std → external deps → local (descriptive aliases like `engine_mod`)
- **Naming**: PascalCase types, camelCase functions/vars, ALL_CAPS constants
- **Structure**: Public fields → constants → pub methods → private in structs
- **Error handling**: Custom error{} sets, try/catch, !T for fallibles
- **Memory**: Arena allocators for scoped allocations, careful ownership
- **Documentation**: `//!` module-level, `///` APIs, comprehensive for public items
- **Testing**: `std.testing.allocator`, defer cleanup, `std.testing.expect()`, embed tests with `test "description"`

## Build System & Project Patterns

- Constants-first, modular functions (setupDependencies, createLibraryModule)
- Platform-conditional builds, example targets as constants array
- C bindings via extern functions for raylib integration (currently stubbed)
- Root module (`src/root.zig`) re-exports public API
- ECS architecture with archetype-based storage
- **Refactored UI system**: `src/ui/` with `game_ui.zig`, `menus.zig`, UiContext/Config, F1 edit mode, Ctrl+S save
- **Modular game state**: `src/game/state.zig` with game constants, state structures, and management functions
- **Application coordination**: `src/application.zig` handles main loop and mode switching
- File handling: Modern std.fs patterns, [:0]const u8 paths, StatusMessage for errors
- Multi-backend: raylib/GLFW/WebGPU abstraction via `src/engine.zig` (backends incomplete)
- Docking UI: Resizable panels, property inspectors, scene hierarchy views
- **Comprehensive testing**: `src/tests.zig` with unit tests for game state and session management
