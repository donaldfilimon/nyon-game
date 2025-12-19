# Nyon Game Engine

A minimal Zig-based game engine with raylib integration, featuring a collect-and-score demo, node-based geometry editor, and extensible plugin system.

## Features

- **Cross-platform**: Native desktop (Windows/macOS/Linux) and WebAssembly support
- **Immediate-mode UI**: Custom UI system with F1 edit mode, drag-and-drop panels, and JSON persistence
- **Node-based editor**: Geometry nodes system for procedural content creation
- **Asset management**: Material system with texture loading and management
- **Undo/Redo**: Command-based history system with serialization support
- **Plugin system**: Extensible architecture for custom components
- **Performance profiling**: Built-in profiling tools and performance monitoring

## Getting Started

### Prerequisites
- Zig 0.16.x or later
- For WebAssembly builds: Emscripten toolchain

### Quick Start
```bash
# Clone and build
git clone <repository>
cd nyon-game
zig build

# Run the demo game
zig build run

# Run the editor
zig build run-editor

# Run tests
zig build test
```

### Build Targets
- `zig build`: Build the main game executable
- `zig build run`: Build and run the game
- `zig build run-editor`: Build and run the editor
- `zig build example-file-browser`: Build file browser example
- `zig build example-drop-viewer`: Build file drop viewer example
- `zig build wasm`: Build for WebAssembly
- `zig build nyon-cli`: Build CLI helper tool
- `zig build test`: Run all tests
- `zig build test -- <path/to/test.zig>`: Run specific test file

## Project Structure

```
nyon-game/
├── build.zig                 # Build configuration
├── src/
│   ├── root.zig             # Public API re-exports
│   ├── main.zig             # Game demo entry point
│   ├── editor.zig           # Editor entry point
│   ├── main_editor.zig      # Editor main loop
│   ├── engine.zig           # Core engine systems
│   ├── scene.zig            # Scene management
│   ├── rendering.zig        # Rendering pipeline
│   ├── ui/                  # User interface system
│   │   ├── ui.zig
│   │   └── status_message.zig
│   ├── nodes/               # Node graph system
│   │   └── node_graph.zig
│   ├── game/                # Game-specific logic
│   │   └── worlds.zig
│   ├── io/                  # File I/O utilities
│   │   ├── file_detail.zig
│   │   └── file_metadata.zig
│   └── [other modules...]
├── examples/
│   └── raylib/              # Raylib integration examples
├── saves/                   # Game save data
└── AGENTS.md               # Development guidelines
```

## Architecture

### Core Systems
- **Engine**: Backend abstraction (Raylib/GLFW/WebGPU)
- **Scene**: Entity-component system with hierarchical transforms
- **Rendering**: Material-based rendering with post-processing
- **UI**: Immediate-mode interface with persistent layouts
- **Assets**: Texture/material management with hot reloading
- **Undo/Redo**: Command pattern with history management

### Editor Features
- **Property Inspector**: Component editing interface
- **Geometry Nodes**: Procedural geometry creation
- **Material Editor**: Texture and shader management
- **Animation System**: Keyframe-based animation tools

### File Handling
- Drag-and-drop support for assets
- Metadata display in HUD overlays
- JSON configuration persistence (`nyon_ui.json`)
- Command-line file loading (`zig build run -- <path>`)

## Development

### Coding Conventions
Follow the guidelines in `AGENTS.md`:
- **Imports**: std → external → local with descriptive aliases
- **Naming**: PascalCase types, camelCase functions, ALL_CAPS constants
- **Error handling**: Custom error sets with `try`/`catch`
- **Documentation**: `//!` module docs, `///` API docs
- **Testing**: Embedded tests with `std.testing.allocator`

### UI Customization
- Press `F1` to enter UI edit mode
- Drag panel title bars to reposition
- Use resize handles for sizing
- `Ctrl+S` to save layout to `nyon_ui.json`
- Drop JSON files to load custom layouts

### Key Bindings (Game)
- `WASD` / Arrow keys: Movement
- `R`: Restart level
- `F1`: Toggle UI edit mode
- `F2`: Settings panel

### Key Bindings (Editor)
- `Ctrl+S`: Save project
- `Ctrl+D`: Debug print node graph
- Mouse: Select and manipulate nodes

## Examples

### File Browser
```bash
zig build example-file-browser
```
Lists directory contents with metadata display.

### Drop Viewer
```bash
zig build example-drop-viewer
```
Demonstrates drag-and-drop file handling with size display.

## Contributing

1. Follow coding conventions in `AGENTS.md`
2. Add tests for new functionality
3. Update README.md for new features
4. Run `zig build test` before submitting

## Roadmap

- [ ] Complete undo/redo serialization
- [ ] Expand geometry node library
- [ ] WebGPU backend implementation
- [ ] CI/CD pipeline with headless testing
- [ ] Additional asset types (models, audio)
- [ ] Plugin API documentation

## License

See LICENSE file for details.