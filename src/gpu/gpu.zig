//! Nyon GPU Abstraction Layer
//!
//! This module provides GPU compute capabilities using Zig's experimental
//! SPIR-V and PTX backends. It supports:
//! - SPIR-V for Vulkan compute
//! - PTX for NVIDIA CUDA
//! - Software fallback

const std = @import("std");
const builtin = @import("builtin");

pub const spirv = @import("spirv.zig");
pub const compute = @import("compute.zig");
pub const buffer = @import("buffer.zig");

/// Supported GPU backends
pub const Backend = enum {
    /// SPIR-V for Vulkan compute shaders
    spirv_vulkan,
    /// SPIR-V for OpenCL
    spirv_opencl,
    /// PTX for NVIDIA GPUs
    nvptx,
    /// AMD GPU backend
    amdgcn,
    /// Software fallback (no GPU)
    software,

    pub fn isAvailable(self: Backend) bool {
        return switch (self) {
            .spirv_vulkan => checkVulkanSupport(),
            .spirv_opencl => checkOpenCLSupport(),
            .nvptx => checkCudaSupport(),
            .amdgcn => checkAmdSupport(),
            .software => true,
        };
    }
};

/// GPU device information
pub const DeviceInfo = struct {
    name: [256]u8,
    name_len: usize,
    vendor: Vendor,
    compute_units: u32,
    max_workgroup_size: u32,
    local_memory_size: u64,
    global_memory_size: u64,
    supports_fp64: bool,
    supports_fp16: bool,

    pub const Vendor = enum {
        nvidia,
        amd,
        intel,
        apple,
        software,
        unknown,
    };

    pub fn getName(self: *const DeviceInfo) []const u8 {
        return self.name[0..self.name_len];
    }
};

/// GPU Context - manages GPU resources and command submission
pub const Context = struct {
    allocator: std.mem.Allocator,
    backend: Backend,
    device_info: DeviceInfo,
    command_queue: CommandQueue,
    buffer_pool: buffer.BufferPool,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, preferred_backend: Backend) !Self {
        // Try preferred backend first, then fallback
        var backend = preferred_backend;
        if (!backend.isAvailable()) {
            std.log.info("Preferred GPU backend {s} not available, trying alternatives...", .{@tagName(backend)});
            backend = findAvailableBackend() orelse .software;
        }

        const device_info = try queryDeviceInfo(backend);
        const command_queue = try CommandQueue.init(allocator, backend);
        const buffer_pool = try buffer.BufferPool.init(allocator, 64 * 1024 * 1024); // 64MB pool

        std.log.info("GPU Context initialized: {s} ({s})", .{
            device_info.getName(),
            @tagName(backend),
        });

        return Self{
            .allocator = allocator,
            .backend = backend,
            .device_info = device_info,
            .command_queue = command_queue,
            .buffer_pool = buffer_pool,
        };
    }

    pub fn deinit(self: *Self) void {
        self.buffer_pool.deinit();
        self.command_queue.deinit();
    }

    /// Create a GPU buffer
    pub fn createBuffer(self: *Self, size: usize, usage: buffer.Usage) !buffer.Handle {
        return self.buffer_pool.allocate(size, usage);
    }

    /// Upload data to GPU buffer
    pub fn uploadBuffer(self: *Self, handle: buffer.Handle, data: []const u8) !void {
        const buf = self.buffer_pool.get(handle) orelse return error.InvalidHandle;
        try buf.upload(data);
    }

    /// Download data from GPU buffer
    pub fn downloadBuffer(self: *Self, handle: buffer.Handle, out: []u8) !void {
        const buf = self.buffer_pool.get(handle) orelse return error.InvalidHandle;
        try buf.download(out);
    }

    /// Destroy a GPU buffer
    pub fn destroyBuffer(self: *Self, handle: buffer.Handle) void {
        self.buffer_pool.free(handle);
    }

    /// Dispatch a compute shader
    pub fn dispatch(self: *Self, kernel: compute.Kernel, work_groups: [3]u32) !void {
        try self.command_queue.submit(.{
            .kernel = kernel,
            .work_groups = work_groups,
        });
    }

    /// Wait for all GPU operations to complete
    pub fn sync(self: *Self) !void {
        try self.command_queue.flush();
    }

    /// Check if using hardware acceleration
    pub fn isHardwareAccelerated(self: *const Self) bool {
        return self.backend != .software;
    }
};

/// Command queue for GPU command submission
pub const CommandQueue = struct {
    allocator: std.mem.Allocator,
    backend: Backend,
    pending_commands: std.ArrayListUnmanaged(Command),

    pub const Command = struct {
        kernel: compute.Kernel,
        work_groups: [3]u32,
    };

    pub fn init(allocator: std.mem.Allocator, backend: Backend) !CommandQueue {
        return CommandQueue{
            .allocator = allocator,
            .backend = backend,
            .pending_commands = .{},
        };
    }

    pub fn deinit(self: *CommandQueue) void {
        self.pending_commands.deinit(self.allocator);
    }

    pub fn submit(self: *CommandQueue, cmd: Command) !void {
        try self.pending_commands.append(self.allocator, cmd);
    }

    pub fn flush(self: *CommandQueue) !void {
        for (self.pending_commands.items) |cmd| {
            try executeCommand(self.backend, cmd);
        }
        self.pending_commands.clearRetainingCapacity();
    }
};

// Internal helper functions

fn findAvailableBackend() ?Backend {
    const backends = [_]Backend{
        .spirv_vulkan,
        .nvptx,
        .amdgcn,
        .spirv_opencl,
    };

    for (backends) |b| {
        if (b.isAvailable()) return b;
    }
    return null;
}

fn queryDeviceInfo(backend: Backend) !DeviceInfo {
    var info = DeviceInfo{
        .name = undefined,
        .name_len = 0,
        .vendor = .unknown,
        .compute_units = 0,
        .max_workgroup_size = 256,
        .local_memory_size = 0,
        .global_memory_size = 0,
        .supports_fp64 = false,
        .supports_fp16 = false,
    };

    @memset(&info.name, 0);

    switch (backend) {
        .software => {
            const name = "Software Renderer (CPU)";
            @memcpy(info.name[0..name.len], name);
            info.name_len = name.len;
            info.vendor = .software;
            info.compute_units = @intCast(std.Thread.getCpuCount() catch 1);
        },
        .spirv_vulkan => {
            const vk_loader = @import("vulkan_loader.zig");
            if (vk_loader.Loader.init()) |loader_val| {
                var loader = loader_val;
                defer loader.deinit();
                var instance: vk_loader.VkInstance = undefined;
                var app_info = vk_loader.VkApplicationInfo{
                    .pApplicationName = "Nyon Game",
                    .apiVersion = 1, // VK_API_VERSION_1_0 roughly
                };
                var create_info = vk_loader.VkInstanceCreateInfo{
                    .pApplicationInfo = &app_info,
                };

                if (loader.createInstance(&create_info, null, &instance) == 0) { // VK_SUCCESS
                    var device_count: u32 = 0;
                    _ = loader.enumeratePhysicalDevices(instance, &device_count, null);
                    if (device_count > 0) {

                        // Just allocate on stack for simplicity of this example if small enough
                        var phys_dev: vk_loader.VkPhysicalDevice = undefined;
                        // For this basic query we just take the first one
                        device_count = 1;
                        if (loader.enumeratePhysicalDevices(instance, &device_count, @ptrCast(&phys_dev)) == 0) {
                            var props: vk_loader.VkPhysicalDeviceProperties = undefined;
                            loader.getPhysicalDeviceProperties(phys_dev, &props);

                            // Copy name
                            const name_slice = std.mem.sliceTo(&props.deviceName, 0);
                            const copy_len = @min(name_slice.len, info.name.len);
                            @memcpy(info.name[0..copy_len], name_slice[0..copy_len]);
                            info.name_len = copy_len;
                            info.vendor = switch (props.vendorID) {
                                0x10DE => .nvidia,
                                0x1002 => .amd,
                                0x8086 => .intel,
                                else => .unknown,
                            };
                        }
                    }
                }
            } else |_| {
                const name = "Vulkan (Loader Failed)";
                @memcpy(info.name[0..name.len], name);
                info.name_len = name.len;
            }
        },
        .spirv_opencl => {
            const name = "GPU (SPIR-V OpenCL)";
            @memcpy(info.name[0..name.len], name);
            info.name_len = name.len;
        },
        .nvptx => {
            const name = "GPU (NVIDIA PTX)";
            @memcpy(info.name[0..name.len], name);
            info.name_len = name.len;
            info.vendor = .nvidia;
        },
        .amdgcn => {
            const name = "GPU (AMD GCN)";
            @memcpy(info.name[0..name.len], name);
            info.name_len = name.len;
            info.vendor = .amd;
        },
    }

    return info;
}

fn executeCommand(backend: Backend, cmd: CommandQueue.Command) !void {
    if (backend == .software) {
        try executeSoftwareCompute(cmd);
    }
    // Other backends: TODO implementation
}

fn executeSoftwareCompute(cmd: CommandQueue.Command) !void {
    const total_groups = cmd.work_groups[0] * cmd.work_groups[1] * cmd.work_groups[2];
    _ = total_groups;
    // TODO: Parallel CPU execution using thread pool
}

fn checkVulkanSupport() bool {
    // TODO: Check for Vulkan instance creation
    return switch (builtin.os.tag) {
        .windows, .linux => true,
        else => false,
    };
}

fn checkOpenCLSupport() bool {
    return false; // TODO
}

fn checkCudaSupport() bool {
    // TODO: Check for CUDA driver
    return switch (builtin.os.tag) {
        .windows, .linux => true,
        else => false,
    };
}

fn checkAmdSupport() bool {
    return false; // TODO
}

test "GPU context initialization" {
    const allocator = std.testing.allocator;
    var ctx = try Context.init(allocator, .software);
    defer ctx.deinit();

    try std.testing.expectEqual(Backend.software, ctx.backend);
}
