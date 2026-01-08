const std = @import("std");
const types = @import("types.zig");
const sysgpu_mod = @import("sysgpu");
const gpu = sysgpu_mod.sysgpu;

const log = std.log.scoped(.webgpu);

// Global state for internal use by the WebGPU backend
var g_allocator: std.mem.Allocator = undefined;
var g_instance: *gpu.Instance = undefined;
var g_adapter: *gpu.Adapter = undefined;
var g_device: *gpu.Device = undefined;
var g_queue: *gpu.Queue = undefined;
var g_surface: ?*gpu.Surface = null;

pub const WebGpuBackend = struct {
    pub fn init(_: *anyopaque, config: types.Config) types.EngineError!void {
        g_allocator = std.heap.c_allocator;

        // Initialize the sysgpu implementation
        sysgpu_mod.Impl.init(g_allocator, .{}) catch |err| {
            log.err("Failed to initialize sysgpu: {}", .{err});
            return types.EngineError.WebGpuBackendNotImplemented;
        };

        // Create Instance
        g_instance = sysgpu_mod.Impl.createInstance(null) orelse return types.EngineError.WebGpuBackendNotImplemented;

        // Request Adapter (Simulated sync for mock)
        const AdapterContext = struct {
            pub var a: ?*gpu.Adapter = null;
            fn callback(status: gpu.RequestAdapterStatus, adp: ?*gpu.Adapter, msg: ?[*:0]const u8, userdata: ?*anyopaque) void {
                _ = userdata;
                _ = msg;
                if (status == .success) {
                    a = adp;
                }
            }
        };

        const options = gpu.RequestAdapterOptions{
            .power_preference = switch (config.webgpu.power_preference) {
                .default => .undefined,
                .low_power => .low_power,
                .high_performance => .high_performance,
            },
            .force_fallback_adapter = gpu.Bool32.from(config.webgpu.force_fallback_adapter),
        };

        sysgpu_mod.Impl.instanceRequestAdapter(g_instance, &options, AdapterContext.callback, null);

        if (AdapterContext.a) |a| {
            g_adapter = a;
        } else {
            return types.EngineError.WebGpuBackendNotImplemented;
        }

        // Create Device
        const DeviceContext = struct {
            pub var d: ?*gpu.Device = null;
            fn callback(status: gpu.RequestDeviceStatus, dev: ?*gpu.Device, msg: ?[*:0]const u8, userdata: ?*anyopaque) void {
                _ = userdata;
                _ = msg;
                if (status == .success) {
                    d = dev;
                }
            }
        };

        sysgpu_mod.Impl.adapterRequestDevice(g_adapter, null, DeviceContext.callback, null);

        if (DeviceContext.d) |d| {
            g_device = d;
        } else {
            return types.EngineError.WebGpuBackendNotImplemented;
        }

        g_queue = sysgpu_mod.Impl.deviceGetQueue(g_device);

        log.info("WebGPU backend initialized successfully!", .{});
    }

    pub fn deinit(_: *anyopaque) void {
        // Releases are typically internal or mock-specific for now
        log.info("WebGPU backend deinitialized.", .{});
    }

    pub fn getDeviceInfo(_: *anyopaque, internal_allocator: std.mem.Allocator) types.EngineError!types.WebGpuDeviceInfo {
        var props: gpu.Adapter.Properties = undefined;
        sysgpu_mod.Impl.adapterGetProperties(g_adapter, &props);

        return types.WebGpuDeviceInfo{
            .device_name = try internal_allocator.dupe(u8, std.mem.span(props.name)),
            .adapter_name = try internal_allocator.dupe(u8, std.mem.span(props.driver_description)),
            .backend = .webgpu,
            .features = &[_]types.WebGpuFeature{},
        };
    }

    pub fn supportsFeature(_: *anyopaque, feature: types.WebGpuFeature) bool {
        _ = feature;
        return true;
    }
};

// Resource wrappers
pub const WebGpuBuffer = struct {
    handle: *gpu.Buffer,
};

pub const WebGpuTexture = struct {
    handle: *gpu.Texture,
};
