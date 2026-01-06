const std = @import("std");
const types = @import("types.zig");
// Import the module, then alias the internal namespace if needed.
// Based on file structure: src/vendor/sysgpu/main.zig exports `pub const sysgpu = @import("sysgpu/main.zig");`
const sysgpu_mod = @import("sysgpu");
const sysgpu = sysgpu_mod.sysgpu;

const log = std.log.scoped(.webgpu);

pub const WebGpuBackend = struct {
    allocator: std.mem.Allocator,
    instance: *sysgpu.Instance,
    adapter: *sysgpu.Adapter,
    device: *sysgpu.Device,
    queue: *sysgpu.Queue,
    surface: ?*sysgpu.Surface = null,
    swap_chain: ?*sysgpu.SwapChain = null,

    pub fn init(engine: *anyopaque, config: types.Config) types.EngineError!void {
        _ = engine;

        allocator = std.heap.c_allocator;

        // Initialize the sysgpu implementation
        sysgpu.Impl.init(allocator, .{}) catch return types.EngineError.WebGpuBackendNotImplemented;

        // Create Instance
        instance = sysgpu.Impl.createInstance(null) orelse return types.EngineError.WebGpuBackendNotImplemented;

        // Request Adapter (Simulated sync for mock)
        var adapter_ptr: ?*sysgpu.Adapter = null;

        const AdapterContext = struct {
            pub var a: ?*sysgpu.Adapter = null;
            fn callback(status: sysgpu.RequestAdapterStatus, adp: ?*sysgpu.Adapter, msg: ?[*:0]const u8, userdata: ?*anyopaque) void {
                _ = userdata;
                _ = msg;
                if (status == .success) {
                    a = adp;
                }
            }
        };

        const options = sysgpu.RequestAdapterOptions{
            .power_preference = switch (config.webgpu.power_preference) {
                .default => .undefined,
                .low_power => .low_power,
                .high_performance => .high_performance,
            },
            .force_fallback_adapter = config.webgpu.force_fallback_adapter,
        };

        sysgpu.Impl.instanceRequestAdapter(instance, &options, AdapterContext.callback, null);

        if (AdapterContext.a) |a| {
            adapter_ptr = a;
            adapter = a;
        } else {
            return types.EngineError.WebGpuBackendNotImplemented; // Adapter failed
        }

        // Create Device
        const DeviceContext = struct {
            pub var d: ?*sysgpu.Device = null;
            fn callback(status: sysgpu.RequestDeviceStatus, dev: ?*sysgpu.Device, msg: ?[*:0]const u8, userdata: ?*anyopaque) void {
                _ = userdata;
                _ = msg;
                if (status == .success) {
                    d = dev;
                }
            }
        };

        sysgpu.Impl.adapterRequestDevice(adapter, null, DeviceContext.callback, null);

        if (DeviceContext.d) |d| {
            device = d;
        } else {
            return types.EngineError.WebGpuBackendNotImplemented;
        }

        queue = sysgpu.Impl.deviceGetQueue(device);

        log.info("WebGPU backend initialized successfully!", .{});
        return;
    }

    pub fn deinit(_: *anyopaque) void {
        // Cleanup logic
    }

    pub fn getDeviceInfo(_: *anyopaque, internal_allocator: std.mem.Allocator) types.EngineError!types.WebGpuDeviceInfo {
        var props: sysgpu.Adapter.Properties = undefined;
        sysgpu.Impl.adapterGetProperties(adapter, &props);

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

// Global state tracking for now if needed, but struct holds member fields?
// No, the methods Init/Deinit are called on the Engine pointer but here we are treating them as static-ish
// or as if Engine IS the backend.
// In `engine.zig`, `WebGpuBackend.init` is called.
// If `WebGpuBackend` is a struct, `init` is a namespaced function.

// Global state variables for the singleton backend
var allocator: std.mem.Allocator = undefined;
var instance: *sysgpu.Instance = undefined;
var adapter: *sysgpu.Adapter = undefined;
var device: *sysgpu.Device = undefined;
var queue: *sysgpu.Queue = undefined;
var surface: ?*sysgpu.Surface = null;

// Resource wrappers
pub const WebGpuBuffer = struct {
    handle: *sysgpu.Buffer,
};

pub const WebGpuTexture = struct {
    handle: *sysgpu.Texture,
};
