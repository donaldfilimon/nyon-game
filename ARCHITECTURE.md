# Nyon Game Engine Architecture

## System Overview

The Nyon Game Engine is built on a modular, multi-backend architecture designed to support both desktop and web platforms through a unified API.

```
┌─────────────────────────────────────────────────────────┐
│                    Application Layer                 │
├─────────────────────────────────────────────────────┤
│                    Engine Core                    │
├─────────────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  │
│  │ Backend  │  │ Backend  │  │ Backend  │  │
│  │ Selection│  │          │  │          │  │
│  └─────────┘  └─────────┘  └─────────┘  │
├─────────────────────────────────────────────────────┤
│  Subsystems (UI, ECS, Rendering, Physics)      │
├─────────────────────────────────────────────────────┤
│  Game Layer (Sandbox, Editor, etc.)          │
└─────────────────────────────────────────────────────┘
```

## System Layers

### 1. Platform Layer

**Location**: `src/` (implicit via platform APIs)

- **Cross-platform abstractions**: Window management, file I/O, input handling
- **Platform detection**: Browser vs desktop (via `is_browser` in `src/engine/types.zig`)
- **Dependencies**:
    - Desktop: raylib, GLFW
    - Web: WebGPU via sysgpu
    - Universal: std library

### 2. Engine Core

**Location**: `src/engine.zig`

- **Unified API**: Single entry point for all game code
- **Backend Selection**:
    - `.auto`: Automatic (WebGPU on browser, raylib on desktop)
    - `.raylib`, `.glfw`, `.webgpu`: Force specific backend
- **Key Functions**:
    - `init()`: Initialize selected backend
    - `deinit()`: Clean up all resources
    - `beginDrawing()`, `endDrawing()`: Render frame management
    - `shouldClose()`: Window state
- **Re-exports**: All raylib types and functions available via `Engine.*`

### 3. Rendering System

**Components**:

- `src/rendering.zig`: PBR rendering, material system
- `src/rendering/render_graph.zig`: Shader-based render pipeline with frame arenas
- `src/material.zig`: PBR material creation and management
- `src/shader/`: Shader compilation and management

**Features**:

- Physically Based Rendering (PBR)
- Shader-based render graph
- Automatic resource management
- Post-processing pipeline support

### 4. Physics System

**Location**: `src/physics/`

- **World**: Physics world simulation (`physics/world.zig`)
- **Colliders**: Collision detection and response
- **Constraints**: Joint and constraint systems
- **Spatial Hashing**: Fast broad-phase collision detection

### 5. Entity Component System (ECS)

**Location**: `src/ecs/`

- **Archetype-based**: Optimized for cache locality
- **Components**: `src/ecs/component.zig` - Position, Velocity, Transform, etc.
- **Entities**: `src/ecs/entity.zig` - Entity ID management with generations
- **Queries**: Efficient component queries with archetype filtering
- **ObjectPool**: Frequent allocation optimization

**Component Types**:

- Position, Velocity, Acceleration
- Transform, Rotation, Scale
- Physics: Collider, RigidBody
- Rendering: Model, Material, Texture

### 6. UI System

**Location**: `src/ui/`

- **Framework**: Immediate-mode GUI with raygui wrapper
- **State Management**: `UiConfig` with JSON persistence
- **Themes**: Dark and light theming system
- **Widgets**: `src/ui/widgets.zig` - All raygui controls wrapped
- **Panels**: `src/ui/panels.zig` - Dockable panel system
- **DPI Scaling**: Automatic scaling support (0.6 - 2.5x)

**Widget Types**:

- Basic: Button, Label, CheckBox, Slider, ProgressBar
- Input: TextBox, Spinner, ComboBox, ValueBox
- Lists: ListView, DropdownBox, ToggleGroup
- Color: ColorPicker, ColorPanel
- Containers: WindowBox, GroupBox, ScrollPanel, Panel
- Dialogs: MessageBox, TextInputBox, File dialogs

### 7. Asset Management

**Location**: `src/asset.zig`

- **AssetManager**: Centralized asset loading and caching
- **Reference Counting**: Automatic cleanup when ref_count reaches 0
- **Metadata System**: Per-asset custom metadata storage
- **Asset Types**:
    - Models (3D meshes)
    - Textures (images)
    - Materials (PBR)
    - Audio (sounds, music)
- **Caching**: Hash-based lookup, automatic cleanup

### 8. Audio System

**Location**: `src/audio/`

- **AudioLoader**: Multi-format audio loading (WAV, OGG, MP3)
- **Spatial Audio**: 3D positioning and attenuation
- **Streaming**: Background music streaming
- **Sound Effects**: Short audio clip playback

### 9. Game Systems

**Location**: `src/game/`

- **Sandbox**: Main game loop and world management (`src/game/sandbox.zig`)
- **Worlds**: World metadata and loading (`src/game/worlds.zig`)
- **Serialization**: JSON-based save/load with versioning
- **Undo/Redo**: Command pattern for game state changes

**Save System**:

- Format: JSON with NYON header
- Versioning: `WORLD_DATA_VERSION`
- Location: `saves/` directory
- Retry logic: 3 attempts with exponential backoff

### 10. Editor System

**Location**: `src/editor/`

- **Scene Editor**: Level design and entity placement
- **Property Inspector**: Component editing
- **Material Editor**: PBR material tuning
- **Asset Browser**: Visual asset preview
- **Timeline**: Animation and timeline editing

## Data Flow

```
Input (Keyboard/Mouse/Gamepad)
  ↓
Engine Core (pollEvents, input processing)
  ↓
ECS Systems (Update loop)
  ├─→ Physics System (velocity, collision)
  ├─→ Animation System (update animations)
  ├─→ Audio System (spatial audio)
  └─→ Game Logic (custom systems)
  ↓
Rendering Pipeline
  ├─→ Render Graph (shader selection)
  ├─→ Draw Commands (batched)
  └─→ Present Frame (display)
  ↓
Display (Window/Frontbuffer)
```

## Memory Management

### Allocation Strategy

1. **Frame Temporary**: `std.heap.ArenaAllocator`
    - Reset each frame
    - Used for: Rendering, temporary calculations
    - Location: `frame_arena` in `RenderGraph`

2. **Long-lived**: `std.heap.ArenaAllocator` with retain
    - Persists across frames
    - Used for: Game state, assets

3. **Object Pools**: `src/common/object_pool.zig`
    - Pre-allocated pools for frequent allocations
    - Used for: Entities, particles

4. **Asset Caching**: Reference-counted assets
    - Automatic cleanup at ref_count = 0
    - `unloadAsset()` function handles cleanup

### Memory Safety

- **Bounds Checking**: `src/common/error_handling.zig` with `Cast` utilities
- **Leak Detection**: `LeakyDetector` for debug builds
- **RAII**: `defer` pattern for all allocations

## Configuration System

**Location**: `src/config/constants.zig`

### Configuration Categories

- **UI**: DPI scaling, font sizes, touch targets, colors
- **Rendering**: Screen resolution, texture sizes, limits
- **Physics**: Gravity, forces, masses
- **Game**: Grid sizes, block limits, file sizes
- **Memory**: Arena sizes, buffer limits
- **Performance**: LOD thresholds, instance limits
- **Editor**: Timeline, gizmo, grid sizes

## Performance Optimization

### Rendering

- **Batch Rendering**: Group draw calls by material/shader
- **Level of Detail (LOD)**: Distance-based model simplification
- **Culling**: Frustum and occlusion culling
- **Instancing**: GPU instancing for repeated objects

### ECS

- **Archetype-based queries**: Cache-friendly component access
- **Query caching**: Reuse query results
- **Component separation**: Minimize cache line invalidation

### Physics

- **Spatial Hashing**: O(1) broad-phase collision
- **Broad phase → Narrow phase**: Two-stage collision detection
- **Sleeping**: Disable processing for stationary objects

## Zig 0.16 Migration Status

### Completed Migrations

- ✅ **Build System**: Updated `build.zig.zon` to stable Zig 0.16.0
- ✅ **Error Handling**: Replaced `@panic()` with proper error propagation in `src/vendor/sysgpu/main.zig`
- ✅ **JSON API**: Updated `std.json.parseFromSlice` and `std.json.stringify` calls
- ✅ **Memory Safety**: Implemented proper cleanup in AssetManager and retryWrite
- ✅ **UI System**: Implemented JSON save() with writer-based API
- ✅ **Error Propagation**: Replaced `catch unreachable` with proper error returns

### Deferred Tasks

- ⏸ **@intCast Safety**: Comprehensive pass to replace with Cast utility (requires extensive testing)
- ⏸ **@ptrCast in Engine**: Requires backend architecture refactor (FFI pattern is intentional)
- ⏸ **Raygui Integration**: Actual bindings require raylib/raygui library (stubs provide safe defaults)

## Build Commands

### Core Commands

- `zig build`: Compile the sandbox executable
- `zig build run`: Launch the sandbox demo
- `zig build run-editor`: Build and start the editor UI
- `zig build wasm`: Emit WebAssembly target
- `zig build test`: Run all tests
- `zig build test -- <file>`: Run tests in a specific file
- `zig fmt`: Format source code using Zig's formatter
- `zig fmt --check`: Check if code is formatted without modifying files

### Platform-Specific Commands

- Desktop: `zig build run` (raylib backend)
- Web: `zig build wasm` (WebGPU backend)

## Dependencies

### External Libraries

- **raylib**: Cross-platform game development library
- **raygui**: Immediate-mode GUI library
- **GLFW**: Window and input management (desktop)
- **WebGPU**: Graphics API for web (via sysgpu)
- **std**: Zig standard library

### Internal Modules

- `src/common/`: Shared utilities (memory, error handling)
- `src/ecs/`: Entity-component system
- `src/physics/`: Physics simulation
- `src/rendering/`: Rendering pipeline
- `src/ui/`: User interface
- `src/game/`: Game-specific systems
- `src/editor/`: Editor tools

## Thread Safety

**Design**: Single-threaded main loop model

- **Main Thread**: All rendering, input processing, and game logic
- **Worker Threads**: Used internally by:
    - File I/O operations
    - Asset loading
    - Physics simulation (optional)
- **Thread-Safe Collections**:
    - Atomic operations where needed
    - Lock-free algorithms where possible
    - Message passing for cross-thread communication

## Known Issues

### Vendor Code Issues

- `src/vendor/sysgpu/`: Auto-generated code has Zig 0.16 compatibility issues
    - Error: Function signature mismatch in `deviceCreateRenderPipeline`
    - Status: Requires upstream sysgpu update
    - Impact: Does not affect raylib backend usage

### Build System

- Windows path handling requires attention to backslashes in generated code
- C allocator usage patterns need documentation (intentional for libc integration)

## Development Workflow

### Before Commit

1. `zig fmt`: Format all code
2. `zig build`: Verify compilation
3. `zig build test`: Run test suite
4. Review changes for breaking API modifications

### Debugging

- Use `std.log` with appropriate levels (err/warn/info/debug)
- Enable `LeakyDetector` for tracking allocations in debug builds
- Use `zig build -ODebug` for better error messages
- Use `zig build -OReleaseFast` for performance profiling

## File Organization

```
src/
├── engine.zig              # Engine core and backend selection
├── root.zig                # Public API re-exports
├── main.zig                # Game entry point
├── editor.zig              # Editor entry point
├── common/                 # Shared utilities
│   ├── error_handling.zig  # Safe type conversions
│   ├── memory.zig         # Memory utilities
│   └── object_pool.zig     # Object pools
├── ecs/                    # Entity-component system
│   ├── entity.zig          # Entity management
│   ├── component.zig        # Component definitions
│   └── archetype.zig        # Archetype queries
├── physics/                # Physics simulation
│   ├── world.zig           # Physics world
│   └── collision.zig       # Collision detection
├── rendering/              # Rendering pipeline
│   ├── render_graph.zig    # Shader graph
│   ├── material.zig         # PBR materials
│   └── shader/            # Shader management
├── ui/                     # User interface
│   ├── ui.zig              # UI core and config
│   ├── widgets.zig          # Widget implementations
│   ├── panels.zig           # Panel system
│   ├── game_ui.zig          # In-game UI
│   └── menus.zig           # Menu system
├── game/                   # Game-specific systems
│   ├── sandbox.zig         # Main game loop
│   └── worlds.zig          # World management
├── editor/                 # Editor tools
│   ├── scene_editor.zig     # Scene editing
│   └── material_editor.zig  # Material editing
├── asset.zig               # Asset management
├── audio/                  # Audio system
├── config/                 # Configuration constants
└── vendor/                 # External libraries
    ├── raylib/             # Raylib bindings
    ├── raygui/             # Raygui bindings
    └── sysgpu/              # WebGPU interface
```

## Performance Targets

### Frame Time Budgets (60 FPS target)

- **Rendering**: ≤ 8.33ms
- **Physics**: ≤ 4.0ms
- **Game Logic**: ≤ 2.0ms
- **UI**: ≤ 1.0ms
- **Audio**: Asynchronous (no frame time)

### Memory Budgets

- **Frame Temporary**: Reset each frame, ~1-5MB
- **Game State**: 10-50MB (depends on world size)
- **Assets**: Cached with LRU eviction, ~50-200MB
- **GPU**: Textures and buffers managed by raylib

## Version History

### Zig 0.16 Migration (Current)

- Updated build configuration
- Fixed JSON API calls throughout codebase
- Improved error handling and propagation
- Enhanced memory safety

### Previous Versions

- Various incremental updates for Zig 0.13-0.15 compatibility
