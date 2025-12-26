//! Nyon Game Engine Library
//!
//! This is the root module for the Nyon game engine library.
//! It provides a unified game engine API that supports multiple backends
//! (raylib, GLFW, WebGPU) for cross-platform game development.
//!
//! The main entry point for applications is `main.zig`, which uses this
//! library module to create games.

// ============================================================================
// Core Engine Systems
// ============================================================================

// Raylib C bindings (direct access for low-level operations)
pub const raylib = @import("raylib");

// Multi-backend engine abstraction
pub const engine = @import("engine.zig");

// ============================================================================
// Entity Component System (ECS)
// ============================================================================

pub const ecs = struct {
    pub const Entity = @import("ecs/entity.zig").Entity;
    pub const EntityId = @import("ecs/entity.zig").EntityId;
    pub const EntityManager = @import("ecs/entity.zig").EntityManager;

    // Components
    pub const Position = @import("ecs/component.zig").Position;
    pub const Rotation = @import("ecs/component.zig").Rotation;
    pub const Scale = @import("ecs/component.zig").Scale;
    pub const Transform = @import("ecs/component.zig").Transform;
    pub const Renderable = @import("ecs/component.zig").Renderable;
    pub const Camera = @import("ecs/component.zig").Camera;
    pub const Light = @import("ecs/component.zig").Light;
    pub const RigidBody = @import("ecs/component.zig").RigidBody;
    pub const Collider = @import("ecs/component.zig").Collider;
    pub const AudioSource = @import("ecs/component.zig").AudioSource;
    pub const AudioListener = @import("ecs/component.zig").AudioListener;

    // Archetype storage
    pub const Archetype = @import("ecs/archetype.zig").Archetype;
    pub const ComponentType = @import("ecs/archetype.zig").ComponentType;

    // Query system
    pub const Query = @import("ecs/query.zig").Query;
    pub const QueryBuilder = @import("ecs/query.zig").QueryBuilder;
    pub const createQuery = @import("ecs/query.zig").createQuery;

    // Main ECS World
    pub const World = @import("ecs/world.zig").World;

    // Physics system
    pub const PhysicsSystem = @import("physics/ecs_integration.zig").PhysicsSystem;
};

// ============================================================================
// Legacy Systems (being migrated to ECS)
// ============================================================================

// Scene management (legacy - migrate to ECS)
pub const scene = @import("scene.zig");
pub const Scene = scene.Scene;

// Material system
pub const material = @import("material.zig");
pub const Material = material.Material;

// Rendering system
pub const rendering = @import("rendering.zig");
pub const RenderingSystem = rendering.RenderingSystem;

// Animation system
pub const animation = @import("animation.zig");
pub const AnimationSystem = animation.AnimationSystem;

// Keyframe system
pub const keyframe = @import("keyframe.zig");
pub const KeyframeSystem = keyframe.KeyframeSystem;

// Asset management
pub const asset = @import("asset.zig");
pub const AssetManager = asset.AssetManager;

// Undo/Redo system
pub const undo_redo = @import("undo_redo.zig");
pub const UndoRedoSystem = undo_redo.UndoRedoSystem;

// Performance monitoring
pub const performance = @import("performance.zig");
pub const PerformanceSystem = performance.PerformanceSystem;

// Node graph system
pub const nodes = @import("nodes/node_graph.zig");
pub const geometry_nodes = @import("geometry_nodes.zig");

// World/save management
pub const worlds = @import("game/worlds.zig");
pub const WorldEntry = worlds.WorldEntry;
pub const game_state = @import("game/state.zig");

// UI system
pub const ui = @import("ui/ui.zig");
pub const UiConfig = ui.UiConfig;
pub const UiContext = ui.UiContext;
pub const UiStyle = ui.UiStyle;

pub const status_message = @import("ui/status_message.zig");
pub const StatusMessage = status_message.StatusMessage;

pub const font_manager = @import("font_manager.zig");
pub const FontManager = font_manager.FontManager;

// File I/O utilities
pub const file_detail = @import("io/file_detail.zig");
pub const FileDetail = file_detail.FileDetail;

pub const file_metadata = @import("io/file_metadata.zig");

// Application wrapper
pub const application = @import("application.zig");
pub const Application = application.Application;

// ============================================================================
// Convenience Type Aliases
// ============================================================================

pub const Engine = engine.Engine;
pub const Color = engine.Color;
pub const Vector2 = engine.Vector2;
pub const Vector3 = engine.Vector3;
pub const Rectangle = engine.Rectangle;
pub const KeyboardKey = engine.KeyboardKey;
pub const MouseButton = engine.MouseButton;

// Re-export commonly used namespaces
pub const Audio = engine.Audio;
pub const Input = engine.Input;
pub const Shapes = engine.Shapes;
pub const Text = engine.Text;
pub const Drawing = engine.Drawing;
pub const Window = engine.Window;
