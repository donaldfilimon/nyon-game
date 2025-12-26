# Repository Guidelines

## Project Structure & Module Organization

- `src/` stores engine, editor, and library code. Entry points: `src/main.zig`, `src/editor.zig`, `src/main_editor.zig`; public API re-exported in `src/root.zig`.
- Subsystems live in `src/ui/`, `src/nodes/`, `src/game/`, `src/io/`, plus shared modules `src/rendering.zig` and `src/engine.zig`. Sandbox runtime/UI live in `src/game/sandbox.zig` and `src/ui/sandbox_ui.zig`; reuse their allocator patterns for blocks, camera, HUD.
- Raylib demos in `examples/`; worldsr and UI layouts (e.g., `nyon_ui.json`) in `saves/`. Keep `build.zig` and `build.zig.zon` aligned with dependency pins (`raylib_zig`, `zglfw`) when APIs shift.

## Build, Test, and Development Commands

- `zig build`: compile the sandbox executable via `src/root.zig`.
- `zig build run`: launch the sandbox demo (free-fly camera; place/remove blocks).
- `zig build run-editor`: build and start the editor UI.
- `zig build nyon-cli`: build the CLI helper.
- `zig build wasm`: emit the WebAssembly target.
- `zig build example-file-browser` / `zig build example-drop-viewer`: build bundled Raylib samples.
- `zig build test` or `zig build test -- src/rendering/render_graph.zig`: run all tests or target a file.
- `zig fmt`: format sources before submitting.

## Coding Style & Naming Conventions

- Use four-space indentation; let `zig fmt` align fields. Import order: `std`, external deps (raylib/zglfw), then local modules with aliases (e.g., `nyon_game @import("../root.zig")`).
- Naming: PascalCase types, camelCase functions/variables, ALL_CAPS constants. Prefer explicit error sets; handle fallible paths with `try`/`catch` or error unions.
- Document modules with `//!` and public APIs with `///`. Favor unmanaged `std.ArrayList`-style ownership; keep allocator lifetimes explicit when passing slices into the render graph, sandbox world, or UI state.

## Testing Guidelines

- Place tests beside code using `test "name"` blocks with `std.testing`, `std.testing.allocator`, and `std.testing.expect`.
- Add coverage for new behaviors; iterate with targeted runs (e.g., `zig build test -- src/rendering/render_graph.zig`) and list commands in PRs.

## Commit & Pull Request Guidelines

- Commit subjects: short, imperative, sentence-case (e.g., `Refactor sandbox camera`); keep scope focused and cite issues when relevant.
- PRs summarize scope/motivation, list test commands, and flag breaking data or format changes (saves serialization). Include screenshots or short clips for UI/editor updates.
- Mention dependency bumps in `build.zig.zon` and explain tooling updates (raylib/zglfw versions). Keep `README.md` and this guide aligned when demo behavior changes.

## Operational Notes

- Worlds saved by the sandbox live under `saves/`; bump version metadata if serialization changes.
- Run `zig fmt` and `zig build` before pushing. For sandbox/UI additions, mirror allocator/ownership flows from `src/game/sandbox.zig` and `src/ui/sandbox_ui.zig`.
