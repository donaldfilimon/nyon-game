# Nyon Game

The Nyon Game repository packages a minimal Zig-based engine plus a small  
collect-and-score demo.  It demonstrates how the `nyon_engine` abstractions  
wrap `raylib` (and optional GLFW/WebGPU) backends so the same API can be used  
for gameplay, editor tooling, and future WebAssembly targets.

## Getting started

1. Ensure Zig 0.16.x is installed and your global cache is initialized.  
2. Fetch dependencies and compile the game with `zig build`.  
3. Run the game: `zig build run`.  
4. Run the editor: `zig build run-editor`.  
5. Build for WebAssembly (requires an emscripten-style toolchain): `zig build wasm`.  
6. Run the automated suite with `zig build test` or target a single test file with `zig build test -- <path/to/test.zig>`.

## Project layout

- `build.zig`: orchestrates build targets for the game, editor, and optional WebAssembly artifacts, wiring in `raylib_zig` (and GLFW when available).  
- `src/root.zig`: re-exports the public engine surface.  
- `src/main.zig`: the collect-items demo that showcases grid drawing, animated pickups, UI, and basic gameplay.  
- `src/editor.zig` / `src/main_editor.zig`: editor entry points that layer tooling on top of the engine (undo/redo, material inspectors, geometry nodes, etc.).  
- `src/{engine,scene,rendering,...}`: the core engine modules, including the extended undo/redo system, animation helpers, asset management, and plugin infrastructure.  
- `AGENTS.md`: living agent instructions for builds, coding style, and documentation conventions.

## Coding conventions

Follow the style guide in `AGENTS.md`: module-level docs use `//!`, public APIs use `///`, constants stay in ALL_CAPS, Zig errors are surfaced via `error` unions, and imports are grouped std → deps → local with qualified names.  The guide also highlights performance sensibilities (budgeted allocators, hot-path attention) and documentation expectations for public types/functions.

## Development notes

- The sample game keeps the player within bounds, animates the collectible pulse, and renders a HUD with score/time/fps.  
- The HUD/settings UI is customizable: press `F1` to toggle UI edit mode, drag panel title bars to move them, and use the resize handle in the bottom-right corner. Save with `Ctrl+S` or the Settings panel (persists to `nyon_ui.json`), and drop a `.json` file onto the window to load a layout.
- The undo/redo subsystem defines a command/vtable system with compound commands and scene-transform helpers, keeping history capped at 100 entries and supporting serialization stubs.  
- Engine internals wrap `raylib` directly but expose `Glfw`/`WebGPU` stubs for future work, and the build script already wires editor/exe/test targets plus install steps for convenience.
- File handling is richer: pass an optional path when launching (`zig build run -- <file>`) to view metadata in the HUD, and drop assets onto the window to have the HUD and status overlay update with the latest file details.

## Raylib examples

- `zig build example-file-browser` compiles a dedicated explorer that lists files, highlights selections, and shows file size/modified metadata using `raylib.loadDirectoryFilesEx` together with `std.fs`.
- `zig build example-drop-viewer` watches for OS drag-and-drop events, captures dropped paths, and renders their sizes in a scrollable list; press `C` inside the window to flush the list and start over.

## Next steps

1. Fill out serialization/deserialization for command types so the undo history can persist/load.  
2. Expand the editor UI modules (`property_inspector`, `geometry_nodes`, `material`, etc.) with more doc comments and sample inspectors.  
3. Harden the WebGPU/GLFW backends once those APIs settle, and add CI-friendly scripts or tooling for headless testing.

Pull requests should update this README if new subprojects or workflows are introduced so collaborators always have a current entry point.
