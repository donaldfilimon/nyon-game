//! Nyon Game Engine Library
//!
//! This is the root module for the Nyon game engine library.
//! It provides a unified game engine API that supports multiple backends
//! (raylib, GLFW, WebGPU) for cross-platform game development.
//!
//! The main entry point for applications is `main.zig`, which uses this
//! library module to create games.

// Re-export the engine module as the main public API
pub const engine = @import("engine.zig");
pub const scene = @import("scene.zig");
pub const material = @import("material.zig");
pub const rendering = @import("rendering.zig");
pub const animation = @import("animation.zig");
pub const keyframe = @import("keyframe.zig");
pub const asset = @import("asset.zig");
pub const undo_redo = @import("undo_redo.zig");
pub const performance = @import("performance.zig");
pub const nodes = @import("nodes/node_graph.zig");
pub const geometry_nodes = @import("geometry_nodes.zig");
pub const worlds = @import("game/worlds.zig");
pub const ui = @import("ui/ui.zig");
pub const status_message = @import("ui/status_message.zig");
pub const file_detail = @import("io/file_detail.zig");
pub const file_metadata = @import("io/file_metadata.zig");

// Re-export commonly used types and functions for convenience
pub const Engine = engine.Engine;
pub const Scene = scene.Scene;
// Material system was not defined in the new Material module.
// Users should import `nyon.material.Material` directly.
pub const RenderingSystem = rendering.RenderingSystem;
pub const AnimationSystem = animation.AnimationSystem;
pub const KeyframeSystem = keyframe.KeyframeSystem;
pub const AssetManager = asset.AssetManager;
// Expose convenience type
pub const Material = material.Material;
pub const UndoRedoSystem = undo_redo.UndoRedoSystem;
pub const PerformanceSystem = performance.PerformanceSystem;
pub const Color = engine.Color;
pub const Vector2 = engine.Vector2;
pub const Vector3 = engine.Vector3;
pub const Rectangle = engine.Rectangle;
pub const KeyboardKey = engine.KeyboardKey;
pub const MouseButton = engine.MouseButton;
pub const UiConfig = ui.UiConfig;
pub const UiContext = ui.UiContext;
pub const UiStyle = ui.UiStyle;
pub const StatusMessage = status_message.StatusMessage;
pub const FileDetail = file_detail.FileDetail;
pub const WorldEntry = worlds.WorldEntry;

// Re-export commonly used namespaces
pub const Audio = engine.Audio;
pub const Input = engine.Input;
pub const Shapes = engine.Shapes;
pub const Text = engine.Text;
pub const Drawing = engine.Drawing;
pub const Window = engine.Window;
