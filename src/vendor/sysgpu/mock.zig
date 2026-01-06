const std = @import("std");
const sysgpu = @import("sysgpu/main.zig");
const utils = @import("utils.zig");

// Mock manager for reference counting
const Manager = struct {
    ref_count: usize = 1,

    pub fn reference(self: *Manager) void {
        _ = self;
    }
    pub fn release(self: *Manager) void {
        _ = self;
    }
};

pub const InitOptions = struct {};

pub fn init(allocator: std.mem.Allocator, options: InitOptions) !void {
    _ = allocator;
    _ = options;
}

pub const Instance = struct {
    manager: Manager = .{},

    pub fn init(descriptor: *const sysgpu.Instance.Descriptor) !*Instance {
        _ = descriptor;
        return @constCast(&valid_instance);
    }

    pub fn createSurface(self: *Instance, descriptor: *const sysgpu.Surface.Descriptor) !*Surface {
        _ = self;
        _ = descriptor;
        return @constCast(&valid_surface);
    }
};

pub const Adapter = struct {
    manager: Manager = .{},
    instance: *Instance,

    pub fn init(instance: *Instance, options: *const sysgpu.RequestAdapterOptions) !*Adapter {
        _ = options;
        return &Adapter{ .instance = instance };
    }

    pub fn getProperties(self: *Adapter) sysgpu.Adapter.Properties {
        _ = self;
        return .{
            .vendor_id = 0,
            .device_id = 0,
            .name = "Mock Adapter",
            .driver_description = "Mock Driver",
            .adapter_type = .cpu,
            .backend_type = .null,
        };
    }

    pub fn createDevice(self: *Adapter, descriptor: ?*const sysgpu.Device.Descriptor) !*Device {
        _ = self;
        _ = descriptor;
        return @constCast(&valid_device);
    }
};

pub const Device = struct {
    manager: Manager = .{},
    lost_cb: ?sysgpu.Device.LostCallback = null,
    lost_cb_userdata: ?*anyopaque = null,
    log_cb: ?sysgpu.LoggingCallback = null,
    log_cb_userdata: ?*anyopaque = null,
    err_cb: ?sysgpu.ErrorCallback = null,
    err_cb_userdata: ?*anyopaque = null,

    pub fn getQueue(self: *Device) !*Queue {
        _ = self;
        return @constCast(&valid_queue);
    }

    pub fn createShaderModuleAir(self: *Device, air: *anyopaque, label: ?[*:0]const u8) !*ShaderModule {
        _ = self;
        _ = air;
        _ = label;
        return @constCast(&valid_shader_module);
    }

    pub fn createSwapChain(self: *Device, surface: *Surface, descriptor: *const sysgpu.SwapChain.Descriptor) !*SwapChain {
        _ = self;
        _ = surface;
        _ = descriptor;
        return @constCast(&valid_swap_chain);
    }

    pub fn createCommandEncoder(self: *Device, descriptor: *const sysgpu.CommandEncoder.Descriptor) !*CommandEncoder {
        _ = self;
        _ = descriptor;
        return &valid_command_encoder;
    }
};

pub const Queue = struct {
    manager: Manager = .{},

    pub fn submit(self: *Queue, command_buffers: []const *const sysgpu.CommandBuffer) !void {
        _ = self;
        _ = command_buffers;
    }
};

pub const Surface = struct {
    manager: Manager = .{},

    pub fn getCurrentTexture(self: *Surface) !sysgpu.Surface.Texture {
        _ = self;
        return sysgpu.Surface.Texture{
            .texture = @ptrCast(&valid_texture),
            .suboptimal = false,
            .status = .success,
        };
    }

    pub fn present(self: *Surface) void {
        _ = self;
    }
};

pub const SwapChain = struct {
    manager: Manager = .{},

    pub fn getCurrentTextureView(self: *SwapChain) !*TextureView {
        _ = self;
        return @constCast(&valid_texture_view);
    }

    pub fn present(self: *SwapChain) void {
        _ = self;
    }
};

pub const CommandEncoder = struct {
    manager: Manager = .{},

    pub fn beginRenderPass(self: *CommandEncoder, descriptor: *const sysgpu.RenderPassDescriptor) !*RenderPassEncoder {
        _ = self;
        _ = descriptor;
        return @constCast(&valid_render_pass_encoder);
    }

    pub fn finish(self: *CommandEncoder, descriptor: *const sysgpu.CommandBuffer.Descriptor) !*CommandBuffer {
        _ = self;
        _ = descriptor;
        return @constCast(&valid_command_buffer);
    }
};

pub const RenderPassEncoder = struct {
    manager: Manager = .{},

    pub fn end(self: *RenderPassEncoder) void {
        _ = self;
    }

    pub fn setPipeline(self: *RenderPassEncoder, pipeline: *RenderPipeline) !void {
        _ = self;
        _ = pipeline;
    }

    pub fn draw(self: *RenderPassEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
        _ = self;
        _ = vertex_count;
        _ = instance_count;
        _ = first_vertex;
        _ = first_instance;
    }
};

pub const ShaderModule = struct {
    manager: Manager = .{},
};

pub const RenderPipeline = struct {
    manager: Manager = .{},
};

pub const Texture = struct {
    manager: Manager = .{},
};

pub const TextureView = struct {
    manager: Manager = .{},
};

pub const CommandBuffer = struct {
    manager: Manager = .{},
};

pub const BindGroup = struct {
    manager: Manager = .{},
};
pub const BindGroupLayout = struct {
    manager: Manager = .{},
};
pub const Buffer = struct {
    manager: Manager = .{},
};
pub const ComputePassEncoder = struct {
    manager: Manager = .{},
};
pub const ComputePipeline = struct {
    manager: Manager = .{},
};
pub const ExternalTexture = struct {
    manager: Manager = .{},
};
pub const PipelineLayout = struct {
    manager: Manager = .{},
};
pub const QuerySet = struct {
    manager: Manager = .{},
};
pub const Sampler = struct {
    manager: Manager = .{},
};
pub const SharedFence = struct {
    manager: Manager = .{},
};
pub const SharedTextureMemory = struct {
    manager: Manager = .{},
};

// Singletons to avoid allocation in mock
var valid_instance = Instance{};
var valid_device = Device{};
var valid_surface = Surface{};
var valid_queue = Queue{};
var valid_swap_chain = SwapChain{};
var valid_command_encoder = CommandEncoder{};
var valid_render_pass_encoder = RenderPassEncoder{};
var valid_command_buffer = CommandBuffer{};
var valid_shader_module = ShaderModule{};
var valid_texture = Texture{};
var valid_texture_view = TextureView{};
