//! Memory Management Utilities for Game Engine Development
//!

const std = @import("std");

/// Simple frame allocator for per-frame allocations
pub const FrameAllocator = struct {
    buffer: []u8,
    offset: usize,

    pub fn init(buffer: []u8) FrameAllocator {
        return FrameAllocator{ .buffer = buffer, .offset = 0 };
    }

    pub fn reset(self: *FrameAllocator) void {
        self.offset = 0;
    }

    pub fn alloc(self: *FrameAllocator, size: usize) ![]u8 {
        const aligned = std.mem.alignForward(usize, self.offset, 16);
        if (aligned + size > self.buffer.len) {
            return error.OutOfMemory;
        }
        const ptr = self.buffer[aligned..];
        self.offset = aligned + size;
        return ptr[0..size];
    }
};

/// Utility functions
pub const util = struct {
    pub fn memCopy(dst: []u8, src: []const u8) void {
        std.mem.copy(u8, dst, src);
    }

    pub fn memSet(ptr: []u8, value: u8) void {
        @memset(ptr, value);
    }

    pub fn memZero(ptr: []u8) void {
        @memset(ptr, 0);
    }
};

/// Testing utilities
pub const testing = struct {
    pub fn testWithArena(test_fn: fn (std.mem.Allocator) anyerror!void) !void {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        try test_fn(arena.allocator());
    }
};
