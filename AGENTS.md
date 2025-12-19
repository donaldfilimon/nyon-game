# Nyon Game Engine - Agent Instructions

## Build Commands
- Game: `zig build` / `zig build run`
- Editor: `zig build run-editor`
- CLI: `zig build nyon-cli`
- Examples: `zig build example-file-browser` / `zig build example-drop-viewer`
- WebAssembly: `zig build wasm`
- Tests: `zig build test` / `zig build test -- <path/to/test.zig>`
- Lint/Format: `zig fmt --check` (check) / `zig fmt` (apply)

## Code Style
- Imports: std → external deps → local (with descriptive aliases like `engine_mod`)
- Naming: PascalCase types, camelCase functions/vars, ALL_CAPS constants
- Structure: Public fields → constants → pub methods → private in structs
- Error handling: Custom error{} sets, try/catch, !T for fallibles
- Memory: Arena allocators for scoped allocations, careful ownership
- Docs: `//!` module-level, `///` APIs, comprehensive for public items

## Testing Patterns
- Use `std.testing.allocator`, defer cleanup, `std.testing.expect()`
- Embed tests in source files with `test "description"`
- Single test: `zig test src/specific_file.zig`

## Build System
- Constants-first, modular functions (setupDependencies, createLibraryModule)
- Platform-conditional builds, example targets as constants array
- C bindings via extern functions for raylib integration

## Project Patterns
- Root module (`src/root.zig`) re-exports public API
- ECS architecture with archetype-based storage
- UI system in `src/ui/` with UiContext/Config, F1 edit mode, Ctrl+S save
- File handling: Modern std.fs patterns, [:0]const u8 paths, StatusMessage for errors
- Physics: Custom 3D physics engine with rigid bodies and constraints
- Node System: Geometry nodes in `src/geometry_nodes.zig`, interactive editor in `src/editor.zig`
- Multi-Backend: raylib/GLFW/WebGPU abstraction via `src/engine.zig`
- Docking UI: Resizable panels, property inspectors, scene hierarchy views