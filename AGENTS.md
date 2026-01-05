# Repository Guidelines

## Build, Lint, and Test Commands

- `zig build`: Compile the sandbox executable.
- `zig build run`: Launch the sandbox demo.
- `zig build run-editor`: Build and start the editor UI.
- `zig build wasm`: Emit WebAssembly target.
- `zig build test`: Run all tests.
- `zig build test -- <file>`: Run tests in a specific file (e.g., `zig build test -- src/ui/ui.zig`).
- `zig fmt`: Format source code using Zig's formatter.
- `zig fmt --check`: Check if code is formatted without modifying files.

## Code Style Guidelines

### Formatting

- Use four-space indentation; let `zig fmt` align fields.
- Always run `zig fmt` before submitting changes.

### Imports and Modules

- Import order: `std` → external libraries → local modules.
- Prefer explicit imports over wildcard re-exports.
- Example:

  ```zig
  const std = @import("std");
  const raylib = @import("raylib");
  const common = @import("common");
  ```

### Naming Conventions

- Types: PascalCase (e.g., `UiContext`, `EntityManager`)
- Functions and variables: camelCase (e.g., `renderFrame`, `entityCount`)
- Constants: ALL_CAPS (e.g., `MAX_ENTITIES`, `DEFAULT_SCALE`)
- Struct fields: camelCase
- Enum variants: PascalCase

### Error Handling

- Use explicit error sets preferred over `anyerror`.
- Propagate with `try`: `const result = try function();`
- Recover with `catch`: `const result = function() catch |err| default;`
- Document error conditions in function comments.

### Types and Data Structures

- Use `const` for immutable bindings.
- Prefer `struct` for data aggregation.
- Use `enum` for options with finite sets.
- Use `union(enum)` for tagged unions.
- Arrays: `[_]T` for fixed-size, `std.ArrayList(T)` for dynamic.

### Documentation

- Module-level: `//! Brief description\n//!\n//! Extended if needed.`
- Public APIs: `/// Brief description.`
- Focus on "why" over "what".

### Memory Management

- Use `std.heap.ArenaAllocator` for temporary allocations.
- Use `ObjectPool` for frequently allocated types.
- Track with `LeakyDetector` in debug.
- Always `defer` cleanup: `defer allocator.free(data);`

### Testing Guidelines

- Place tests in `test "name"` blocks beside code.
- Use `std.testing.allocator`.
- Assertions: `std.testing.expect`, `std.testing.expectEqual`.
- Test error paths, edge cases.
- Run single file: `zig build test -- <file>`
- Example:

  ```zig
  test "entity creation" {
      var em = EntityManager.init(std.testing.allocator);
      defer em.deinit();
      const e = try em.create();
      try std.testing.expect(em.isAlive(e));
  }
  ```

### Common Patterns

- Struct init: `.{ .field = value }` or `.{}`
- Optionals: `if (opt) |val| { ... }`
- Switches: exhaustive matching.
- Strings: `std.fmt.bufPrint`
- Cleanup: `defer`

## Project Structure & Module Organization

- `src/`: Engine, editor, library code.
- Entry points: `src/main.zig`, `src/editor.zig`, `src/main_editor.zig`
- Public API: `src/root.zig`
- Core subsystems: `ui/`, `common/`, `platform/`, `config/`, `nodes/`, `game/`, `io/`, `ecs/`, `physics/`, `rendering/`, `std_ext/`
- Examples: `examples/`
- Saves: `saves/`

## Centralized Configuration

- Constants in `src/config/constants.zig`:
  - `UI.*`: Scale 0.6-2.5, touch target 44px, font sizes
  - `Rendering.*`: Screen 1920x1080, texture sizes, limits
  - `Physics.*`: Gravity, forces, masses
  - `Game.*`: Grid size, block limits, file sizes
  - `Memory.*`: Arena sizes, buffer limits
  - `Performance.*`: LOD thresholds, instance limits
  - `Editor.*`: Timeline, gizmo, grid sizes

## Safe Type Conversions

- Use `Cast.toInt()`, `Cast.toFloat()` from `src/common/error_handling.zig`
- Clamped versions: `Cast.toIntClamped()`, `Cast.toFloatClamped()`
- Array access: `safeArrayAccess()`

## UI & Editor Patterns

- Immediate-mode UI with `UiContext`, `UiStyle`, `UiConfig`
- DPI scaling: `UiScale` (0.6-2.5)
- Panel docking: `panels.zig` utilities
- Widgets: `widgets.zig` primitives
- Persistence: `saves/nyon_ui.json`
- Edit mode: F1, Save: Ctrl+S

## Rendering & Asset Patterns

- Pipeline: `src/rendering.zig` with PBR
- Shaders: `src/rendering/render_graph.zig`
- Materials: `src/material.zig`
- Post-processing: `src/shaders/`, `src/post_processing.zig`
- Assets: `src/asset.zig`, `AssetManager`

## ECS Architecture Patterns

- Archetype-based: `src/ecs/`
- Components: `src/ecs/component.zig`
- Queries: `createQuery(world.allocator, &.{ Position.id, Velocity.id })`
- Physics: `src/physics/ecs_integration.zig`

## Performance Considerations

- `initCapacity` for known sizes
- Batch renders, minimize state changes
- Cache queries
- Arena allocators for temporaries
- Profile with `src/performance.zig`

## Commit & Pull Request Guidelines

- Commit subjects: short, imperative (e.g., `Add render graph system`)
- PRs: summarize scope, list test commands, flag breaking changes
- Screenshots for UI updates
- Mention dependency bumps

## Operational Notes

- Worlds: `saves/`
- Run `zig fmt` and `zig build` before push
- Backend: `.auto` -> raylib native, webgpu browser
- UI edit: F1, save: Ctrl+S
