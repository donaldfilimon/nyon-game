# Repository Guidelines

## Project Structure & Module Organization

- `src/` stores engine, editor, and library code. Entry points: `src/main.zig`, `src/editor.zig`, `src/main_editor.zig`; public API re-exported in `src/root.zig`.
- Subsystems live in `src/ui/`, `src/nodes/`, `src/game/`, `src/io/`, plus shared modules `src/rendering.zig` and `src/engine.zig`. Sandbox runtime/UI live in `src/game/sandbox.zig` and `src/ui/sandbox_ui.zig`; reuse their allocator patterns for blocks, camera, HUD.
- Raylib demos in `examples/`; worlds and UI layouts (e.g., `nyon_ui.json`) in `saves/`. Keep `build.zig` and `build.zig.zon` aligned with dependency pins (`raylib_zig`, `zglfw`) when APIs shift.

## Build, Test, and Development Commands

- `zig build`: compile the sandbox executable via `src/root.zig`.
- `zig build run`: launch the sandbox demo (free-fly camera; place/remove blocks).
- `zig build run-editor`: build and start the editor UI.
- `zig build nyon-cli`: build the CLI helper.
- `zig build wasm`: emit the WebAssembly target.
- `zig build example-file-browser` / `zig build example-drop-viewer`: build bundled Raylib samples.
- `zig build test`: run all tests (module tests and executable tests).
- `zig build test -- src/rendering/render_graph.zig`: run tests in a specific file only.
- `zig fmt`: format sources before submitting.

## Coding Style & Naming Conventions

- Use four-space indentation; let `zig fmt` align fields and struct members.
- Import order: `std` library first, then external dependencies (raylib/zglfw), then local modules with descriptive aliases (e.g., `nyon_game @import("../root.zig")`).
- Naming: PascalCase for types, camelCase for functions/variables, ALL_CAPS for constants.
- Prefer explicit error sets over `anyerror`. Example: `pub const MyError = error{InvalidState, OutOfMemory};`
- Error handling: Use `try` for error propagation, `catch` for error recovery, and error unions `!T` for fallible functions.
- Document modules with top-level `//!` comments and public APIs with `///` documentation comments.

## Memory Management & Allocator Usage

- Favor unmanaged `std.ArrayList`-style ownership (e.g., `std.ArrayList(T).initCapacity(allocator, 0)`).
- Keep allocator lifetimes explicit when passing slices into the render graph, sandbox world, or UI state.
- Always deinit allocators in `defer` blocks: `defer em.deinit();`
- Use `std.testing.allocator` in tests for leak detection: `var em = EntityManager.init(std.testing.allocator);`

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

## Documentation Standards

- Module-level docs: `//! Brief description\n//!\n//! Optional extended explanation.`
- Function/struct docs: `/// Brief single-line description.` or `/// Brief.\n/// Extended details.`
- Keep comments concise and focused on "why" not "what".
- Document error conditions in function comments.

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

## Common Patterns

- Struct initialization with default values: `.{ .x = 0, .y = 1 }` or `.{}`
- Error propagation: `const result = try someFallibleOperation();`
- Optional handling: `if (optional_value) |value| { /* use value */ }`
- Enum switch with exhaustive matching: `switch (enum_value) { .case1 => {}, .case2 => {} }`
- String formatting: `try std.fmt.bufPrintZ(&buffer, "Value: {d}", .{value})`
