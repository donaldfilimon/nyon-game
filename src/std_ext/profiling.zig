//! Profiling Utilities for Game Engine Development
//!

const std = @import("std");

/// High-resolution timer for profiling
pub const ProfilerTimer = struct {
    name: []const u8,
    timer: std.time.Timer,
    allocator: std.mem.Allocator,

    pub fn init(name: []const u8, allocator: std.mem.Allocator) !ProfilerTimer {
        const name_copy = try allocator.dupe(u8, name);
        return ProfilerTimer{
            .name = name_copy,
            .timer = try std.time.Timer.start(),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ProfilerTimer) void {
        self.allocator.free(self.name);
    }

    pub fn lap(self: *ProfilerTimer) u64 {
        return self.timer.read();
    }

    pub fn elapsedMs(self: *ProfilerTimer) f64 {
        return @as(f64, @floatFromInt(self.timer.read())) / 1_000_000.0;
    }

    pub fn log(self: *ProfilerTimer) void {
        std.log.debug("{s}: {d:.3}ms", .{ self.name, self.elapsedMs() });
    }
};

/// Scoped profiler that logs on drop
pub const ScopedProfiler = struct {
    name: []const u8,
    timer: std.time.Timer,
    allocator: std.mem.Allocator,

    pub fn init(name: []const u8, allocator: std.mem.Allocator) !ScopedProfiler {
        const name_copy = try allocator.dupe(u8, name);
        return ScopedProfiler{
            .name = name_copy,
            .timer = try std.time.Timer.start(),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ScopedProfiler) void {
        self.allocator.free(self.name);
    }

    pub fn log(self: *ScopedProfiler) void {
        const elapsed = @as(f64, @floatFromInt(self.timer.read())) / 1_000_000.0;
        std.log.debug("{s}: {d:.3}ms", .{ self.name, elapsed });
    }
};

/// Profiler that logs when it goes out of scope
pub fn scoped(comptime name: []const u8, allocator: std.mem.Allocator) !ScopedProfiler {
    return ScopedProfiler.init(name, allocator);
}

/// Frame profiler for tracking frame times
pub const FrameProfiler = struct {
    frame_times: std.ArrayList(f64),
    min_frame_time: f64,
    max_frame_time: f64,
    avg_frame_time: f64,
    frame_count: usize,
    window_size: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, window_size: usize) !FrameProfiler {
        return FrameProfiler{
            .frame_times = try std.ArrayList(f64).initCapacity(allocator, window_size),
            .min_frame_time = std.math.inf(f64),
            .max_frame_time = 0,
            .avg_frame_time = 0,
            .frame_count = 0,
            .window_size = window_size,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FrameProfiler) void {
        self.frame_times.deinit();
    }

    pub fn recordFrame(self: *FrameProfiler, frame_time_ms: f64) void {
        if (self.frame_times.items.len >= self.window_size) {
            const old = self.frame_times.orderedRemove(0);
            self.frame_count -= 1;
            if (old == self.min_frame_time or old == self.max_frame_time) {
                self.recalculateStats();
            }
        }

        self.frame_times.append(frame_time_ms) catch {};
        self.frame_count += 1;

        if (frame_time_ms < self.min_frame_time) self.min_frame_time = frame_time_ms;
        if (frame_time_ms > self.max_frame_time) self.max_frame_time = frame_time_ms;

        // Running average
        const total: f64 = blk: {
            var sum: f64 = 0;
            for (self.frame_times.items) |t| sum += t;
            break :blk sum;
        };
        self.avg_frame_time = total / @as(f64, @floatFromInt(self.frame_times.items.len));
    }

    fn recalculateStats(self: *FrameProfiler) void {
        self.min_frame_time = std.math.inf(f64);
        self.max_frame_time = 0;
        for (self.frame_times.items) |t| {
            if (t < self.min_frame_time) self.min_frame_time = t;
            if (t > self.max_frame_time) self.max_frame_time = t;
        }
    }

    pub fn getFps(self: *const FrameProfiler) f64 {
        if (self.avg_frame_time == 0) return 0;
        return 1000.0 / self.avg_frame_time;
    }

    pub fn report(self: *const FrameProfiler) void {
        std.log.debug("FPS: {d:.1} (min: {d:.2f}ms, max: {d:.2f}ms, avg: {d:.2f}ms)", .{
            self.getFps(), self.min_frame_time, self.max_frame_time, self.avg_frame_time,
        });
    }
};
