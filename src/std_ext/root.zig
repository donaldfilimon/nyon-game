//! Extended Standard Library for Game Engine Development
//!
//! This module provides production-ready utilities for game engine development
//! using Zig's standard library.
//!

const std = @import("std");

// Re-export commonly used types
pub const memory = @import("memory.zig");
pub const data = @import("data.zig");
pub const math = @import("math.zig");
pub const compression = @import("compression.zig");
pub const net = @import("net.zig");
pub const audio = @import("audio.zig");
pub const input = @import("input.zig");
pub const profiling = @import("profiling.zig");
pub const assets = @import("assets.zig");
pub const serialization = @import("serialization.zig");

// Version information
pub const VERSION = "1.0.0";
