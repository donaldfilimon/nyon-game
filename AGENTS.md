# Repository Guidelines

## Project Structure & Module Organization

- `src/` contains engine and editor code. Core entry points are `src/main.zig`
  (game) and `src/editor.zig` / `src/main_editor.zig` (editor). The public API
  is re-exported from `src/root.zig`.
- Subsystems live under `src/ui/`, `src/nodes/`, `src/game/`, `src/io/`, plus
  `src/rendering.zig` and `src/engine.zig`.
- `examples/` holds Raylib integration demos; `saves/` stores runtime save data
  and UI layouts.
- Build configuration is in `build.zig` and dependency pins in `build.zig.zon`.
- Tests are embedded in Zig files using `test "name"` blocks.

## Build, Test, and Development Commands

- `zig build`: build the main game binary.
- `zig build run`: build and run the game demo.
- `zig build run-editor`: build and run the editor.
- `zig build nyon-cli`: build the CLI helper.
- `zig build wasm`: produce WebAssembly output.
- `zig build example-file-browser` / `zig build example-drop-viewer`: build
  examples.
- `zig build test` or `zig build test -- <path/to/test.zig>`: run all tests or a
  single file.
- `zig fmt` / `zig fmt --check`: format or lint format.

## Coding Style & Naming Conventions

- Use `zig fmt`-style formatting (4-space indent, aligned fields).
- Imports order: std, external deps, then local modules with descriptive aliases
  (e.g., `engine_mod`).
- Types in PascalCase, functions/vars in camelCase, constants in ALL_CAPS.
- Struct layout: public fields, constants, public methods, then private helpers.
- Use explicit error sets, `try`/`catch`, and `!T` for fallible APIs.
- Prefer arena allocators for scoped work; use `[:0]const u8` for file paths.
- Document public APIs with `///` and modules with `//!`.

## Testing Guidelines

- Use `std.testing` with `std.testing.allocator` and `std.testing.expect`.
- Keep tests close to code in the same module.
- Name tests descriptively: `test "loads scene metadata"`.

## Commit & Pull Request Guidelines

- Commit history uses short, imperative, sentence-case summaries (for example,
  `Refactor build.zig and enhance game state management`). Keep scope in the
  subject line when helpful.
- PRs should include a brief description, linked issue (if any), and test
  commands run.
- Include screenshots or short clips for editor/UI changes and call out breaking
  changes or data format updates.

## Dependency Notes

- Raylib-zig and zglfw can drift with Zig 0.16.x; if builds fail, update
  `build.zig.zon` to newer commits and adjust build API usage as needed.
