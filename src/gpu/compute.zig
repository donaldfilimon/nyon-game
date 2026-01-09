//! GPU Compute Kernel API

const std = @import("std");
const buffer = @import("buffer.zig");
const spirv = @import("spirv.zig");

/// Compute kernel definition
pub const Kernel = struct {
    name: []const u8,
    module: ?*spirv.Module,
    bindings: []const Binding,
    workgroup_size: [3]u32,
    cpu_fallback: ?CpuKernelFn,

    pub const CpuKernelFn = *const fn ([3]u32, [3]u32, [3]u32, *anyopaque) void;

    pub const Binding = struct {
        slot: u32,
        buffer_handle: buffer.Handle,
        access: Access,

        pub const Access = enum { read_only, write_only, read_write };
    };
};

/// Kernel builder
pub const KernelBuilder = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    bindings: std.ArrayListUnmanaged(Kernel.Binding),
    workgroup_size: [3]u32,
    cpu_fallback: ?Kernel.CpuKernelFn,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) KernelBuilder {
        return .{
            .allocator = allocator,
            .name = name,
            .bindings = .{},
            .workgroup_size = .{ 64, 1, 1 },
            .cpu_fallback = null,
        };
    }

    pub fn deinit(self: *KernelBuilder) void {
        self.bindings.deinit(self.allocator);
    }

    pub fn setWorkgroupSize(self: *KernelBuilder, x: u32, y: u32, z: u32) *KernelBuilder {
        self.workgroup_size = .{ x, y, z };
        return self;
    }

    pub fn build(self: *KernelBuilder) !Kernel {
        return Kernel{
            .name = self.name,
            .module = null,
            .bindings = try self.allocator.dupe(Kernel.Binding, self.bindings.items),
            .workgroup_size = self.workgroup_size,
            .cpu_fallback = self.cpu_fallback,
        };
    }
};

/// Execute kernel on CPU (fallback)
pub fn executeCpu(kernel: Kernel, work_groups: [3]u32, context: *anyopaque) !void {
    const fallback = kernel.cpu_fallback orelse return error.NoCpuFallback;

    for (0..work_groups[2]) |gz| {
        for (0..work_groups[1]) |gy| {
            for (0..work_groups[0]) |gx| {
                for (0..kernel.workgroup_size[2]) |lz| {
                    for (0..kernel.workgroup_size[1]) |ly| {
                        for (0..kernel.workgroup_size[0]) |lx| {
                            const global_id = [3]u32{
                                @intCast(gx * kernel.workgroup_size[0] + lx),
                                @intCast(gy * kernel.workgroup_size[1] + ly),
                                @intCast(gz * kernel.workgroup_size[2] + lz),
                            };
                            const local_id = [3]u32{ @intCast(lx), @intCast(ly), @intCast(lz) };
                            const group_id = [3]u32{ @intCast(gx), @intCast(gy), @intCast(gz) };
                            fallback(global_id, local_id, group_id, context);
                        }
                    }
                }
            }
        }
    }
}
