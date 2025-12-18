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

// Re-export commonly used types and functions for convenience
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
