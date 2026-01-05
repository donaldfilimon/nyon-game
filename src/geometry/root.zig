//! Geometry node system root module.
//!
//! Re-exports all geometry modules for convenient access.
//!
//! Modules:
//! - mesh_operations: Mesh copying and memory management
//! - primitives: Basic shape nodes (cube, sphere, cylinder, cone, plane)
//! - transformations: Transformation nodes (translate, scale, rotate)
//! - torus: Torus primitive node
//! - modifiers: Mesh modification nodes (mirror, subdivide, noise, bevel)
//! - generators: Procedural generators (heightfield, array)
//! - combiners: Mesh combining nodes (merge)
//! - system: Main GeometryNodeSystem

pub const mesh_operations = @import("mesh_operations.zig");
pub const primitives = @import("primitives.zig");
pub const transformations = @import("transformations.zig");
pub const torus = @import("torus.zig");
pub const modifiers = @import("modifiers.zig");
pub const generators = @import("generators.zig");
pub const combiners = @import("combiners.zig");
pub const system = @import("system.zig");

// Core system
pub const GeometryNodeSystem = system.GeometryNodeSystem;

// Primitives
pub const CubeNode = primitives.CubeNode;
pub const SphereNode = primitives.SphereNode;
pub const CylinderNode = primitives.CylinderNode;
pub const ConeNode = primitives.ConeNode;
pub const PlaneNode = primitives.PlaneNode;
pub const TorusNode = torus.TorusNode;

// Transformations
pub const TranslateNode = transformations.TranslateNode;
pub const ScaleNode = transformations.ScaleNode;
pub const RotateNode = transformations.RotateNode;

// Modifiers
pub const MirrorNode = modifiers.MirrorNode;
pub const SubdivideNode = modifiers.SubdivideNode;
pub const NoiseNode = modifiers.NoiseNode;
pub const BevelNode = modifiers.BevelNode;

// Generators
pub const HeightfieldNode = generators.HeightfieldNode;
pub const ArrayNode = generators.ArrayNode;

// Combiners
pub const MergeNode = combiners.MergeNode;
