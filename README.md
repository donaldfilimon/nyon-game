# Nyon Game Engine

**Unleash Your Creativity: The Future of Game Development is Here!**

A blazingly fast, minimal Zig-based game engine that empowers developers to build stunning 3D worlds with unprecedented ease. Featuring cutting-edge raylib integration, an intuitive node-based geometry editor, and a revolutionary plugin system that adapts to your wildest imagination.

## 🚀 Revolutionary Features That Set You Free

- **⚡ Lightning-Fast Cross-Platform Power**: Seamlessly deploy to desktop (Windows/macOS/Linux) and the web with WebAssembly - reach players everywhere!
- **🎨 Intuitive Immediate-Mode UI**: Revolutionary F1 edit mode lets you customize your interface on-the-fly with drag-and-drop panels and persistent JSON layouts
- **🌍 Immersive 3D Sandbox**: Dive into creative freedom with free-fly camera controls, instant block manipulation, and persistent world saving
- **🧠 Node-Based Geometry Wizardry**: Craft procedural masterpieces with our powerful geometry nodes system - no coding required!
- **🎭 Professional Asset Management**: Industry-grade material system with hot-reloadable textures and advanced material management
- **⏪ Time-Travel Development**: Undo/Redo system with full serialization support - experiment fearlessly!
- **🔌 Plugin Architecture Revolution**: Extend the engine infinitely with custom materials, geometry nodes, game modes, and UI panels
- **📊 Performance Mastery**: Built-in profiling tools and real-time performance monitoring keep your games running at peak performance

## 🎯 Getting Started - Your Journey Begins Now!

### Prerequisites

- **Zig 0.16.x or later** - The language that's revolutionizing systems programming
- **For WebAssembly builds: Emscripten toolchain** - Bring your games to the browser!

### Quick Start - Launch into Creativity!

```bash
# Clone the revolution
git clone <repository>
cd nyon-game
zig build

# Experience the magic
zig build run

# Unleash your inner creator
zig build run-editor

# Ensure perfection
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
│   │   ├── sandbox.zig
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

## 🏗️ Architecture of Innovation

### Core Systems - Engineered for Excellence

- **🚀 Engine**: Ultra-flexible backend abstraction supporting Raylib, GLFW, and cutting-edge WebGPU
- **🎭 Scene**: Sophisticated entity-component system with seamless hierarchical transforms
- **🎨 Rendering**: Professional material-based rendering pipeline with stunning post-processing effects
- **💫 UI**: Revolutionary immediate-mode interface with intelligent persistent layouts
- **📦 Assets**: Lightning-fast texture/material management with instant hot reloading
- **🔄 Undo/Redo**: Bulletproof command pattern ensuring your creative flow never breaks

### Editor Features - Where Magic Happens

- **🔍 Property Inspector**: Intuitive component editing that makes complex objects feel simple
- **🌟 Geometry Nodes**: Revolutionary procedural geometry creation - sculpt worlds from pure imagination
- **🎨 Material Editor**: Professional-grade texture and shader management at your fingertips
- **🎬 Animation System**: Powerful keyframe-based animation tools that bring your creations to life

## 🛠️ Development - Crafted by Visionaries

### Coding Conventions - Excellence Through Discipline

Follow the battle-tested guidelines in `AGENTS.md`:

- **📚 Imports**: Strategic organization - std → external → local with crystal-clear descriptive aliases
- **🏷️ Naming**: PascalCase types, camelCase functions, ALL_CAPS constants - consistency that scales
- **🛡️ Error handling**: Robust custom error sets with `try`/`catch` for bulletproof reliability
- **📖 Documentation**: Comprehensive `//!` module docs and `///` API docs for crystal-clear understanding
- **🧪 Testing**: Embedded tests with `std.testing.allocator` ensuring rock-solid stability

### UI Customization

- Press `F1` to enter UI edit mode
- Drag panel title bars to reposition
- Use resize handles for sizing
- `Ctrl+S` to save layout to `nyon_ui.json`
- Drop JSON files to load custom layouts

### Key Bindings (Game)

- `WASD`: Move
- `Q` / `E`: Move down/up
- `Right Mouse`: Look around
- `Left Click`: Place block
- `Ctrl` + `Left Click`: Remove block
- `Tab`: Cycle block color
- `R`: Reset camera
- `Ctrl` + `S`: Save world
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

## 🗺️ Roadmap - The Future We're Building

- [x] **Complete undo/redo serialization** - ✅ Revolutionary time-travel development achieved!
- [ ] **Expand geometry node library** - Crafting an infinite palette of creative possibilities
- [ ] **WebGPU backend implementation** - Next-gen graphics performance for the modern web
- [ ] **CI/CD pipeline with headless testing** - Automated excellence ensuring perfect releases
- [ ] **Additional asset types (models, audio)** - Complete your multimedia masterpiece
- [ ] **Plugin API documentation** - Empowering developers worldwide to extend the revolution

### 🌟 Vision: Democratizing Game Development

Nyon isn't just an engine - it's a movement. We're breaking down barriers, eliminating complexity, and giving every developer the tools to create extraordinary experiences. From indie dreamers to AAA innovators, Nyon adapts to your vision and scales with your ambition.

**Join the revolution. Build the impossible.**

## License

See LICENSE file for details.
