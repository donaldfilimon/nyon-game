const std = @import("std");

pub const ProfilingSystem = struct {
    allocator: std.mem.Allocator,
    timers: std.StringHashMap(Timer),
    frame_stats: FrameStats,
    enabled: bool = true,

    pub const Timer = struct {
        name: []const u8,
        start_time: i64,
        total_time: i64,
        call_count: usize,
        max_time: i64 = 0,
    };

    pub const FrameStats = struct {
        frame_time: f32 = 0,
        fps: f32 = 0,
        draw_calls: usize = 0,
        memory_usage: usize = 0,
        physics_time_ns: u64 = 0,
        render_time_ns: u64 = 0,
        update_time_ns: u64 = 0,
    };

    pub const ProfileScope = struct {
        timer: *Timer,
        end_time: i64,

        pub fn end(self: ProfileScope) void {
            const elapsed = self.end_time - self.timer.start_time;
            self.timer.total_time += elapsed;
            self.timer.call_count += 1;
            if (elapsed > self.timer.max_time) {
                self.timer.max_time = elapsed;
            }
        }
    };

    pub fn init(allocator: std.mem.Allocator) ProfilingSystem {
        return .{
            .allocator = allocator,
            .timers = std.StringHashMap(Timer).init(allocator),
            .frame_stats = FrameStats{},
        };
    }

    pub fn deinit(self: *ProfilingSystem) void {
        var iter = self.timers.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.timers.deinit();
    }

    pub fn startTimer(self: *ProfilingSystem, name: []const u8) !ProfileScope {
        if (!self.enabled) {
            return .{ .timer = undefined, .end_time = 0 };
        }

        const gop = try self.timers.getOrPut(name);
        if (!gop.found_existing) {
            gop.value_ptr.* = Timer{
                .name = try self.allocator.dupe(u8, name),
                .start_time = 0,
                .total_time = 0,
                .call_count = 0,
                .max_time = 0,
            };
        }

        const timer = gop.value_ptr;
        const now = std.time.nanoTimestamp();
        timer.start_time = now;
        return .{ .timer = timer, .end_time = now };
    }

    pub fn getTimerStats(self: *ProfilingSystem, name: []const u8) ?Timer {
        if (!self.enabled) return null;
        return self.timers.get(name);
    }

    pub fn resetTimers(self: *ProfilingSystem) void {
        var iter = self.timers.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.*.total_time = 0;
            entry.value_ptr.*.call_count = 0;
            entry.value_ptr.*.max_time = 0;
        }
    }

    pub fn printReport(self: *ProfilingSystem) void {
        if (!self.enabled) return;

        std.debug.print("\n=== Performance Profile Report ===\n", .{});
        std.debug.print("Frame Time: {d:.3}ms (FPS: {d:.1})\n", .{ self.frame_stats.frame_time * 1000, self.frame_stats.fps });
        std.debug.print("Memory Usage: {d} MB\n", .{self.frame_stats.memory_usage / (1024 * 1024)});
        std.debug.print("Draw Calls: {d}\n", .{self.frame_stats.draw_calls});
        std.debug.print("Update Time: {d:.3}ms\n", .{@as(f64, self.frame_stats.update_time_ns) / 1000000.0});
        std.debug.print("Physics Time: {d:.3}ms\n", .{@as(f64, self.frame_stats.physics_time_ns) / 1000000.0});
        std.debug.print("Render Time: {d:.3}ms\n", .{@as(f64, self.frame_stats.render_time_ns) / 1000000.0});

        std.debug.print("\n=== Timer Breakdown ===\n", .{});
        var iter = self.timers.iterator();
        while (iter.next()) |entry| {
            const timer = entry.value_ptr.*;
            const avg_time = if (timer.call_count > 0) @as(f64, timer.total_time) / @as(f64, timer.call_count) else 0;
            std.debug.print("{s}: {d:.3}ms (avg), {d:.3}ms (max), {d} calls\n", .{
                timer.name,
                avg_time / 1000000.0,
                @as(f64, timer.max_time) / 1000000.0,
                timer.call_count,
            });
        }
    }

    pub fn identifyHotPaths(self: *ProfilingSystem) void {
        if (!self.enabled) return;

        var max_avg_time: f64 = 0;
        var hot_path_name: ?[]const u8 = null;
        var iter = self.timers.iterator();

        while (iter.next()) |entry| {
            const timer = entry.value_ptr.*;
            if (timer.call_count > 0) {
                const avg_time = @as(f64, timer.total_time) / @as(f64, timer.call_count);
                if (avg_time > max_avg_time) {
                    max_avg_time = avg_time;
                    hot_path_name = timer.name;
                }
            }
        }

        if (hot_path_name) |name| {
            std.log.warn("Hot path detected: {s} (avg: {d:.3}ms)", .{ name, max_avg_time / 1000000.0 });
        }
    }
};

test "profiling system basic usage" {
    var profiler = ProfilingSystem.init(std.testing.allocator);
    defer profiler.deinit();

    {
        const scope = try profiler.startTimer("test_operation");
        @import("std").time.sleep(1 * std.time.ns_per_ms);
        scope.end();
    }

    {
        const scope = try profiler.startTimer("test_operation");
        @import("std").time.sleep(1 * std.time.ns_per_ms);
        scope.end();
    }

    const stats = profiler.getTimerStats("test_operation");
    try std.testing.expect(stats != null);
    if (stats) |s| {
        try std.testing.expect(s.call_count == 2);
        try std.testing.expect(s.total_time > 0);
    }
}

test "profiling hot path detection" {
    var profiler = ProfilingSystem.init(std.testing.allocator);
    defer profiler.deinit();

    {
        const scope = try profiler.startTimer("fast_op");
        @import("std").time.sleep(1 * std.time.ns_per_ms);
        scope.end();
    }

    {
        const scope = try profiler.startTimer("slow_op");
        @import("std").time.sleep(5 * std.time.ns_per_ms);
        scope.end();
    }

    profiler.identifyHotPaths();
    const slow_stats = profiler.getTimerStats("slow_op");
    try std.testing.expect(slow_stats != null);
    if (slow_stats) |s| {
        const avg_time = @as(f64, s.total_time) / @as(f64, s.call_count);
        try std.testing.expect(avg_time > @as(f64, s.max_time) * 0.5);
    }
}

test "profiling disabled" {
    var profiler = ProfilingSystem.init(std.testing.allocator);
    defer profiler.deinit();

    profiler.enabled = false;

    const scope = try profiler.startTimer("disabled_op");
    @import("std").time.sleep(1 * std.time.ns_per_ms);
    scope.end();

    const stats = profiler.getTimerStats("disabled_op");
    try std.testing.expect(stats == null);
}
