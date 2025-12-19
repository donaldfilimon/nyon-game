//! Small status/notification helper for on-screen overlays.
//!
//! Intended for lightweight HUD messages where allocating each frame is
//! undesirable. Call `set()` with a message and duration, then call `update()`
//! each frame and render while `isActive()` is true.

const std = @import("std");

// ============================================================================
// Status Message
// ============================================================================

/// Time-limited message with a fade-out alpha.
pub const StatusMessage = struct {
    buffer: [256]u8 = [_]u8{0} ** 256,
    len: usize = 0,
    timer: f32 = 0.0,
    duration: f32 = 0.0,

    /// Overwrite the message buffer and restart the timer.
    pub fn set(self: *StatusMessage, message: []const u8, duration: f32) void {
        const max_copy = self.buffer.len - 1;
        const copy_len = if (message.len < max_copy) message.len else max_copy;
        std.mem.copyForwards(u8, self.buffer[0..copy_len], message[0..copy_len]);
        self.buffer[copy_len] = 0;

        self.len = copy_len;
        self.timer = duration;
        self.duration = duration;
    }

    /// Clear the message and timer.
    pub fn clear(self: *StatusMessage) void {
        self.len = 0;
        self.buffer[0] = 0;
        self.timer = 0.0;
        self.duration = 0.0;
    }

    /// Advance the message timer by `delta_time` seconds.
    pub fn update(self: *StatusMessage, delta_time: f32) void {
        if (self.timer <= 0.0) return;
        self.timer -= delta_time;
        if (self.timer < 0.0) self.timer = 0.0;
    }

    /// True while the message should be displayed.
    pub fn isActive(self: *const StatusMessage) bool {
        return self.timer > 0.0 and self.len > 0;
    }

    /// Get the current message as a null-terminated string slice.
    pub fn textZ(self: *const StatusMessage) [:0]const u8 {
        return @ptrCast(self.buffer[0 .. self.len + 1]);
    }

    /// Alpha ratio in `[0, 1]` for fade-out.
    pub fn alpha(self: *const StatusMessage) f32 {
        if (self.duration <= 0.0) return 1.0;
        const ratio = self.timer / self.duration;
        if (ratio < 0.0) return 0.0;
        if (ratio > 1.0) return 1.0;
        return ratio;
    }

    /// Alpha value in `[0, 255]` for RGBA colors.
    pub fn alphaU8(self: *const StatusMessage) u8 {
        const ratio = self.alpha();
        const scaled = std.math.round(ratio * 255.0);
        if (scaled <= 0.0) return 0;
        if (scaled >= 255.0) return 255;
        return @intFromFloat(scaled);
    }
};
