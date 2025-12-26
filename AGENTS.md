# Repository Guidelines

## Project Structure & Module Organization
- `src/` contains engine and editor code. Entry points are `src/main.zig` (game) and
  `src/editor.zig` / `src/main_editor.zig` (editor). Public API lives in `src/root.zig`.
- Subsystems are grouped under `src/ui/`, `src/nodes/`, `src/game/`, `src/io/`, plus
  `src/rendering.zig` and `src/engine.zig`.
- `examples/` holds Raylib integration demos; `saves/` stores runtime save data and UI layouts.
- Build configuration is in `build.zig`, with dependency pins in `build.zig.zon`.
- Tests live next to code in Zig files using `test "name"` blocks.

## Build, Test, and Development Commands
- Use Zig 0.16 master for all builds and tests in this codebase.
- `zig build`: build the main game binary.
- `zig build run`: build and run the game demo.
- `zig build run-editor`: build and run the editor.
- `zig build nyon-cli`: build the CLI helper.
- `zig build wasm`: produce WebAssembly output.
- `zig build example-file-browser` / `zig build example-drop-viewer`: build examples.
- `zig build test` or `zig build test -- path/to/test.zig`: run all tests or a single file.
- `zig fmt` / `zig fmt --check`: format or lint formatting.

## Coding Style & Naming Conventions
- Formatting follows `zig fmt` (4-space indent, aligned fields).
- Import order: `std`, external deps, then local modules with descriptive aliases
  (e.g., `engine_mod`).
- Types in PascalCase, functions/vars in camelCase, constants in ALL_CAPS.
- Struct layout: public fields, constants, public methods, then private helpers.
- Prefer explicit error sets, `try`/`catch`, and `!T` for fallible APIs.
- Use arena allocators for scoped work; prefer `[:0]const u8` for file paths.
- Document public APIs with `///` and modules with `//!`.

## Testing Guidelines
- Use `std.testing`, `std.testing.allocator`, and `std.testing.expect`.
- Keep tests close to the implementation and name them clearly
  (e.g., `test "loads scene metadata"`).
- Run `zig build test` before submitting changes.

## Commit & Pull Request Guidelines
- Commit subjects are short, imperative, sentence case (example:
  `Refactor build.zig and enhance game state management`).
- PRs should include a brief description, linked issue (if any), and test commands run.
- Include screenshots or short clips for editor/UI changes and note breaking changes or
  data format updates.

## Dependency Notes
- Raylib-zig and zglfw may drift with Zig 0.16.x; if builds fail, update
  `build.zig.zon` to newer commits and adjust build API usage as needed.
