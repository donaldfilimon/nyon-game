# Nyon Game Engine - Agent Instructions

## Build Commands
- Game: `zig build` / `zig build run`
- Editor: `zig build run-editor`
- CLI: `zig build nyon-cli`
- Examples: `zig build example-file-browser` / `zig build example-drop-viewer`
- WebAssembly: `zig build wasm`
- Tests: `zig build test` / `zig build test -- <path/to/test.zig>`

## Code Style
- Imports: std → external deps → local (with descriptive aliases like `engine_mod`)
- Naming: PascalCase types, camelCase functions/vars, ALL_CAPS constants
- Structure: Public fields → constants → pub methods → private in structs
- Error handling: Custom error{} sets, try/catch, !T for fallibles
- Docs: `//!` module-level, `///` APIs, comprehensive for public items

## Testing Patterns
- Use `std.testing.allocator`, defer cleanup, `std.testing.expect()`
- Embed tests in source files with `test "description"`

## Build System
- Constants-first, modular functions (setupDependencies, createLibraryModule)
- Platform-conditional builds, example targets as constants array

## Project Patterns
- Root module (`src/root.zig`) re-exports public API
- UI system in `src/ui/` with UiContext/Config, F1 edit mode, Ctrl+S save
- File handling: Raylib loadDroppedFiles, [:0]const u8 paths, StatusMessage for errors