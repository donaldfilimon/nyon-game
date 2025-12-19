# Nyon Game Engine - Agent Instructions

## Build Commands
- **Build game**: `zig build`
- **Build and run game**: `zig build run`
- **Build and run editor**: `zig build run-editor`
- **Build for WebAssembly**: `zig build wasm`
- **Run all tests**: `zig build test`
- **Run single test file**: `zig build test -- <path/to/test.zig>`

## Code Style Guidelines

### Documentation
- Use `//!` for module-level documentation
- Use `///` for function/struct documentation
- Add comprehensive doc comments for public APIs

### Formatting & Structure
- Use `// ============================================================================` for major section headers
- Use `// --------------------------------------------------------------------------` for subsections
- Constants in ALL_CAPS with type annotations
- PascalCase for types (structs, enums, unions)
- camelCase for variables and functions
- No semicolons at end of statements
- 4-space indentation (Zig default)

### Naming Conventions
- Types: PascalCase (e.g., `GameState`, `EngineError`)
- Functions: camelCase (e.g., `handleInput`, `drawPlayer`)
- Constants: ALL_CAPS (e.g., `WINDOW_WIDTH`, `PLAYER_SPEED`)
- Private fields: camelCase with underscore prefix if needed
- Import aliases: descriptive names (e.g., `engine_mod` for clarity)

### Error Handling
- Define custom error types using `error{...}`
- Use `try` for errorable operations
- Use `catch` for error recovery when appropriate
- Return `!T` for functions that can fail

### Imports & Dependencies
- Group imports by standard library, external deps, then local
- Use `@import` for all module imports
- Prefer qualified imports over `*` imports
- Conditional imports for platform-specific code

### Type Safety
- Use explicit types for constants
- Prefer `const` over `var` when possible
- Use optional types `?T` for nullable values
- Use error unions `!T` for fallible operations
- Leverage Zig's compile-time features (`comptime`, generics)

### Performance
- Profile performance-critical code
- Use appropriate data structures for algorithms
- Consider memory allocation patterns
- Optimize hot paths when measured

### File Handling & Examples
- The collect-and-score demo now surfaces file metadata/status overlays (HUD panel, status banner). Capture file drops with `std.mem.span` or the Raylib `loadDroppedFiles()` result to build `[:0]const u8` slices before formatting/storing paths.
- UI helpers live under `src/ui`: use `ui.UiContext` for lightweight immediate-mode widgets (panels/buttons/sliders), and persist layouts via `ui.UiConfig` (`nyon_ui.json`). The demo supports `F1` UI edit mode, drag-to-move, resize handles, `Ctrl+S` save, and dropping a `.json` file to load a layout.
- Example utilities live under `examples/raylib`. Use `zig build example-file-browser` to inspect directory listings or `zig build example-drop-viewer` to visualize dropped files; these targets rely on the public Raylib `loadDirectoryFilesEx`, `loadDroppedFiles`, and allocated `std.ArrayList` helpers, so keep their allocator usage aligned with the latest stdlib signatures.
- The engine/drivers accept an optional file path on launch (`zig build run -- <path>`); follow its error handling pattern (`std.process.argsAlloc`, post-parsing cleanup) to surface load failures via `StatusMessage`.
