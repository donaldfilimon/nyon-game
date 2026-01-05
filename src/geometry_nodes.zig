//! Geometry Node System for Nyon Game Engine
//!
//! Node-based geometry generation and manipulation system.
//! This module provides nodes for creating and transforming 3D geometry.
//!
//! DEPRECATED: This module has been split into multiple files in src/geometry/
//! Please use the new modular structure:
//!   - src/geometry/root.zig for main exports
//!   - src/geometry/mesh_operations.zig for mesh utilities
//!   - src/geometry/primitives.zig for shape nodes
//!   - src/geometry/transformations.zig for transform nodes
//!   - src/geometry/system.zig for the main system

const std = @import("std");
const raylib = @import("raylib");
const nodes = @import("nodes/node_graph.zig");

pub const mesh_operations = @import("geometry/mesh_operations.zig");
pub const primitives = @import("geometry/primitives.zig");
pub const transformations = @import("geometry/transformations.zig");
pub const system = @import("geometry/system.zig");

pub const GeometryNodeSystem = system.GeometryNodeSystem;
pub const CubeNode = primitives.CubeNode;
pub const SphereNode = primitives.SphereNode;
pub const CylinderNode = primitives.CylinderNode;
pub const ConeNode = primitives.ConeNode;
pub const PlaneNode = primitives.PlaneNode;
pub const TranslateNode = transformations.TranslateNode;
pub const ScaleNode = transformations.ScaleNode;
pub const RotateNode = transformations.RotateNode;

pub const copyMesh = mesh_operations.copyMesh;
pub const freeMesh = mesh_operations.freeMesh;
