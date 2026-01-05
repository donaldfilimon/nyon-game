//! Geometry node system root module.
//!
//! Re-exports all geometry modules for convenient access.
//!
//! Modules:
//! - mesh_operations: Mesh copying and memory management
//! - primitives: Basic shape nodes (cube, sphere, cylinder, cone, plane)
//! - transformations: Transformation nodes (translate, scale, rotate)
//! - system: Main GeometryNodeSystem

pub const mesh_operations = @import("mesh_operations.zig");
pub const primitives = @import("primitives.zig");
pub const transformations = @import("transformations.zig");
pub const system = @import("system.zig");

pub const GeometryNodeSystem = system.GeometryNodeSystem;
pub const CubeNode = primitives.CubeNode;
pub const SphereNode = primitives.SphereNode;
pub const CylinderNode = primitives.CylinderNode;
pub const ConeNode = primitives.ConeNode;
pub const PlaneNode = primitives.PlaneNode;
pub const TranslateNode = transformations.TranslateNode;
pub const ScaleNode = transformations.ScaleNode;
pub const RotateNode = transformations.RotateNode;
