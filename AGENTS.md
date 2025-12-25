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
- **Dependency Compatibility**: Raylib-zig and zglfw dependencies may have API compatibility issues with current Zig version (0.16.x). Update dependency URLs in `build.zig.zon` to latest commits and fix any build API changes (linkLibC → linkLibC, addCSourceFiles → addCSourceFiles, etc.)

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
- C bindings via extern functions for raylib integration
- Root module (`src/root.zig`) re-exports public API
- ECS architecture with archetype-based storage
- UI system in `src/ui/` with UiContext/Config, F1 edit mode, Ctrl+S save
- File handling: Modern std.fs patterns, [:0]const u8 paths, StatusMessage for errors
- Multi-backend: raylib/GLFW/WebGPU abstraction via `src/engine.zig`
- Docking UI: Resizable panels, property inspectors, scene hierarchy views