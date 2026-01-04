# Repository Guidelines

## Project Structure & Module Organization

- `src/` stores engine, editor, and library code. Entry points: `src/main.zig`, `src/editor.zig`, `src/main_editor.zig`; public API re-exported in `src/root.zig`.
- Core subsystems:
  - `src/ui/` - UI framework with modules: `ui.zig`, `scaling.zig`, `panels.zig`, `widgets.zig`, `sandbox_ui.zig`, `game_ui.zig`, `menus.zig`, `status_message.zig`
  - `src/common/` - Shared utilities: `error_handling.zig`, `memory.zig`
  - `src/platform/` - Platform abstraction: `paths.zig` (cross-platform paths, fonts, config dirs)
  - `src/config/` - Centralized constants: `constants.zig`
  - `src/nodes/`, `src/game/`, `src/io/`, `src/ecs/`, `src/physics/`, `src/rendering/`
  - Shared modules: `src/rendering.zig`, `src/engine.zig`
- Raylib demos in `examples/`; worlds and UI layouts in `saves/`.
- Keep `build.zig` and `build.zig.zon` aligned with dependency pins.

## New Module Architecture

### `src/common/` - Shared Utilities

- `error_handling.zig`: `ErrorContext`, `SafeWrapper`, `Cast`, `safeArrayAccess`
- `memory.zig`: `ObjectPool`, `MemoryConfig`, `createArena`

### `src/platform/` - Platform Abstraction

- `paths.zig`: `Platform`, `PathUtils`, `FontPaths`, `ExecutablePaths` (cross-platform support)

### `src/config/` - Centralized Constants

- `constants.zig`: `UI`, `Rendering`, `Physics`, `Game`, `Memory`, `Performance`, `Editor` namespaces

### `src/ui/` - Modular UI Framework

- `ui.zig`: Core framework (re-exports widgets, panels, scaling)
- `scaling.zig`: `UiScale`, `DpiInfo`, `ResponsiveConfig`
- `panels.zig`: `clampPanelRect`, `splitDockPanels`, `detectDockPosition`
- `widgets.zig`: `button`, `checkbox`, `sliderFloat`, `sliderInt`
- `sandbox_ui.zig`: Sandbox HUD and settings
- `game_ui.zig`: Game HUD and settings
- `menus.zig`: Menu screens
- `status_message.zig`: Notifications

## Build, Test, and Development Commands

- `zig build`: compile the sandbox executable.
- `zig build run`: launch the sandbox demo.
- `zig build run-editor`: build and start the editor UI.
- `zig build wasm`: emit WebAssembly target.
- `zig build test`: run all tests.
- `zig build test -- <file>`: run tests in a specific file.
- `zig fmt`: format sources before submitting.

## Coding Style & Naming Conventions

- Use four-space indentation; let `zig fmt` align fields.
- Import order: `std` → external → local modules.
- Naming: PascalCase types, camelCase functions/variables, ALL_CAPS constants.
- Explicit error sets preferred over `anyerror`.
- Error handling: `try` propagation, `catch` recovery, error unions `!T`.
- Document modules with `//!` and public APIs with `///`.

## Memory Management

- Use `std.heap.ArenaAllocator` for temporary allocations.
- Use `ObjectPool` for frequently allocated types.
- Track allocations with `LeakyDetector` in debug builds.
- Always pair allocations with `defer` cleanup.

## Platform Abstraction

- Use `platform/paths.zig` for cross-platform operations:
  - `PathUtils.join()` - Platform-aware path joining
  - `FontPaths.getSystemFontPaths()` - Platform font detection
  - `ExecutablePaths.getConfigDir()` / `getSaveDir()`
- No hardcoded paths (e.g., `C:\\Windows\\Fonts`)

## Centralized Configuration

- All magic numbers in `src/config/constants.zig`:
  - `UI.*` - Scale (0.6-2.5), touch target (44px), font sizes
  - `Rendering.*` - Screen (1920x1080), texture sizes, limits
  - `Physics.*` - Gravity, forces, masses
  - `Game.*` - Grid size, block limits, file sizes
  - `Memory.*` - Arena sizes, buffer limits
  - `Performance.*` - LOD thresholds, instance limits
  - `Editor.*` - Timeline, gizmo, grid sizes

## Safe Type Conversions

- Use `Cast.toInt()`, `Cast.toFloat()` for safe conversions.
- Use `Cast.toIntClamped()` / `Cast.toFloatClamped()` with bounds.
- Use `safeArrayAccess()` for bounds-checked array access.

## UI & Editor Patterns

- Immediate-mode UI with `UiContext`, `UiStyle`, `UiConfig`.
- DPI-aware scaling via `UiScale` (0.6-2.5 range).
- Panel docking with `panels.zig` utilities.
- Widget composition with `widgets.zig` primitives.
- UI state persists to `saves/nyon_ui.json`.
- Press `F1` for edit mode, `Ctrl+S` to save layout.

## Testing Guidelines

- Place tests beside code using `test "name"` blocks.
- Use `std.testing.allocator`, `std.testing.expect`.
- Test error handling paths and edge cases.
- Run targeted tests: `zig build test -- <file>`

## Performance Considerations

- Use `ObjectPool` for frequently created/destroyed objects.
- Use arena allocators for per-frame temporary data.
- Batch render calls; minimize state changes.
- Cache component queries; avoid rebuilding per frame.
- Use `initCapacity` for collections with known sizes: `std.ArrayList(T).initCapacity(allocator, 0)`

## Memory Management & Allocator Usage

- Keep allocator lifetimes explicit when passing slices into the render graph, sandbox world, or UI state.
- Always deinit allocators in `defer` blocks: `defer em.deinit();`
- For temporary allocations in hot paths, use `std.heap.FixedBufferAllocator` or `FrameDataBuffer` (see `src/rendering.zig`).
- Use `std.testing.allocator` in tests for leak detection: `var em = EntityManager.init(std.testing.allocator);`

## ECS Architecture Patterns

- Use archetype-based ECS in `src/ecs/` for high-performance game logic.
- Components are stored in `src/ecs/component.zig`; entities managed in `src/ecs/entity.zig`.
- Create queries with `createQuery` or `QueryBuilder` for component iteration.
- Example: `var query = try createQuery(world.allocator, &.{ Position.id, Velocity.id });`
- Physics integration via `PhysicsSystem` in `src/physics/ecs_integration.zig`.

## Testing Guidelines

- Place tests beside code using `test "name"` blocks.
- Use `std.testing.allocator`, `std.testing.expect`, `std.testing.expectEqual` for assertions.
- Test common error paths and edge cases.
- Add coverage for new behaviors; iterate with targeted runs (e.g., `zig build test -- src/rendering/render_graph.zig`) and list commands in PRs.
- Example test structure:

  ```zig
  test "entity creation and destruction" {
      var em = EntityManager.init(std.testing.allocator);
      defer em.deinit();
      const e1 = try em.create();
      try std.testing.expect(em.isAlive(e1));
  }
  ```

## UI & Editor Patterns

- Immediate-mode UI in `src/ui/` with modular structure:
  - `ui.zig`: Core framework (UiContext, UiStyle, UiConfig, PanelId, re-exports modules)
  - `scaling.zig`: DPI-aware scaling utilities (`UiScale`, `DpiInfo`, `ResponsiveConfig`)
  - `panels.zig`: Shared panel utilities (`clampPanelRect`, `splitDockPanels`, `detectDockPosition`)
  - `widgets.zig`: Reusable widget primitives (`button`, `checkbox`, `sliderFloat`, `sliderInt`)
  - `sandbox_ui.zig`: Sandbox-specific UI (HUD, Settings, crosshair, instructions)
  - `game_ui.zig`: Game-specific UI (HUD, Settings, win message, progress bar)
  - `menus.zig`: Menu screens (Title, World List, Pause, Server Browser)
  - `status_message.zig`: Lightweight status/notification overlay
- UI state persists to `saves/nyon_ui.json`; bump version if format changes.
- Node graph system in `src/nodes/` and `src/geometry_nodes.zig` for procedural content.
- Property inspector pattern: iterate component fields with reflection-like metadata.
- Font loading via `FontSet` in `src/font_manager.zig`; handle Windows font paths with fallbacks.
- Scale range: 0.6 to 2.5 (clamped by `UiScale.clamp()`)

## Rendering & Asset Patterns

- Rendering pipeline in `src/rendering.zig` with PBR material support (`PBRMaterialSystem`).
- Shaders managed in `src/rendering/render_graph.zig`; use `FrameDataBuffer` for uniform updates.
- Materials in `src/material.zig`; support textures (albedo, normal, metallic/roughness, emissive, AO).
- Post-processing passes in `src/shaders/` and `src/post_processing.zig` (bloom, chromatic aberration, etc.).
- Asset manager in `src/asset.zig`; use `AssetManager` for texture loading and caching.

## Documentation Standards

- Module-level docs: `//! Brief description\n//!\n//! Optional extended explanation.`
- Function/struct docs: `/// Brief single-line description.` or `/// Brief.\n/// Extended details.`
- Keep comments concise and focused on "why" not "what".
- Document error conditions in function comments.

## Performance Considerations

- Use `initCapacity` for known-size collections to avoid reallocations.
- Batch render calls; minimize state changes between draw calls.
- Cache component queries where possible; avoid rebuilding queries every frame.
- Use `FixedBufferAllocator` for per-frame temporary allocations.
- Profile hot paths with `src/performance.zig` before optimizing.

## Common Patterns

- Struct initialization with default values: `.{ .x = 0, .y = 1 }` or `.{}`
- Error propagation: `const result = try someFallibleOperation();`
- Optional handling: `if (optional_value) |value| { /* use value */ }`
- Enum switch with exhaustive matching: `switch (enum_value) { .case1 => {}, .case2 => {} }`
- String formatting: `try std.fmt.bufPrintZ(&buffer, "Value: {d}", .{value})`
- Resource cleanup: `defer resource.deinit();`

## Commit & Pull Request Guidelines

- Commit subjects: short, imperative, sentence-case (e.g., `Refactor sandbox camera`, `Add render graph system`).
- Keep commit scope focused; cite issues when relevant.
- PRs summarize scope/motivation, list test commands, and flag breaking data or format changes (saves serialization).
- Include screenshots or short clips for UI/editor updates.
- Mention dependency bumps in `build.zig.zon` and explain tooling updates (raylib/zglfw versions).
- Keep `README.md` and this guide aligned when demo behavior changes.

## Operational Notes

- Worlds saved by the sandbox live under `saves/`; bump version metadata if serialization changes.
- Run `zig fmt` and `zig build` before pushing.
- For sandbox/UI additions, mirror allocator/ownership flows from `src/game/sandbox.zig` and `src/ui/sandbox_ui.zig`.
- Engine backend selection: `.auto` defaults to `.raylib` on native and `.webgpu` in browser.
- UI press `F1` for edit mode, `Ctrl+S` to save layout to `nyon_ui.json`.
