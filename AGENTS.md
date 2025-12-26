# Repository Guidelines

## Project Structure & Module Organization
- `src/` stores the engine/editor/library logic. Entry points are `src/main.zig`, `src/editor.zig`, and `src/main_editor.zig`, while `src/root.zig` re-exports the public API. Subsystems live under `src/ui/`, `src/nodes/`, `src/game/`, and `src/io/`, alongside `src/rendering.zig` and `src/engine.zig`. The 3D sandbox runtime/UI now live in `src/game/sandbox.zig` and `src/ui/sandbox_ui.zig`, so mirror their allocator/ownership patterns for block, camera, and HUD flows.
- `examples/` holds Raylib demos and `saves/` stores persisted worlds and UI layouts (including `nyon_ui.json`). Keep `build.zig`/`build.zig.zon` in sync with dependency pins (`raylib_zig`, `zglfw`) whenever root APIs change.

## Build, Test, and Development Commands
- `zig build`: compile the main sandbox executable via `src/root.zig`.
- `zig build run`: run the sandbox demo (free-fly camera + block build/removal).
- `zig build run-editor`: build and launch the editor UI.
- `zig build nyon-cli`: build the CLI helper.
- `zig build wasm`: produce WebAssembly output.
- `zig build example-file-browser` / `zig build example-drop-viewer`: compile the provided Raylib samples.
- `zig build test` (or `zig build test -- <path>`): run every test or a targeted Zig file.
- `zig fmt`: enforce repository formatting before submitting commits.


## Coding Style & Naming Conventions
- Four-space indentation with field alignment that matches `zig fmt`. Order imports as `std`, then external deps (raylib/zglfw), then local modules with descriptive aliases (e.g., `nyon_game @import("../root.zig")`).
- Use PascalCase for types, camelCase for functions/vars, and ALL_CAPS for constants. Prefer explicit error sets and handle fallible calls with `try`/`catch` or matching `error` branches.
- Document modules with `//!` and public APIs with `///`. Favored data structures follow Zig 0.16’s unmanaged `std.ArrayList` pattern where ownership is explicit.
- Keep allocator ownership clear when passing slices to the `RenderGraph`, sandbox world, or UI state.


## Testing Guidelines
- Tests live alongside their code in Zig files via `test "name"` blocks using `std.testing`, `std.testing.allocator`, and `std.testing.expect`.
- Run targeted tests for touched modules (e.g., `zig build test -- src/rendering/render_graph.zig`). Note the command(s) in the PR description.


## Commit & Pull Request Guidelines
- Write short, imperative, sentence-case commit subjects (e.g., `Refactor sandbox camera`). Keep scope focused and cite issues when applicable.
- PRs should explain the change, list test commands executed, and call out breaking data/format updates. UI/editor work benefits from screenshots or short clips.
- Reference dependency bumps in `build.zig.zon` and explain tooling updates (new raylib/zglfw versions).


## Operational Notes
- Worlds saved by the sandbox live under `saves/`; bump version metadata if serialization changes.
- Run `zig fmt` and `zig build` before pushing, and keep `AGENTS.md`/`README.md` aligned when demo behavior changes.
