//! Dynamic Vulkan Loader
//! Only defines what is strictly needed for initialization and SPIR-V pipeline creation.

const std = @import("std");
const builtin = @import("builtin");

/// Whether dynamic library loading is supported on this platform
pub const is_supported = builtin.os.tag != .freestanding and builtin.os.tag != .wasi;

// Vulkan Handle Types
pub const VkInstance = *opaque {};
pub const VkPhysicalDevice = *opaque {};
pub const VkDevice = *opaque {};

// Vulkan Structs (Simplified)
pub const VkApplicationInfo = extern struct {
    sType: u32 = 0, // VK_STRUCTURE_TYPE_APPLICATION_INFO
    pNext: ?*const anyopaque = null,
    pApplicationName: ?[*:0]const u8 = null,
    applicationVersion: u32 = 0,
    pEngineName: ?[*:0]const u8 = null,
    engineVersion: u32 = 0,
    apiVersion: u32 = 0,
};

pub const VkInstanceCreateInfo = extern struct {
    sType: u32 = 1, // VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
    pNext: ?*const anyopaque = null,
    flags: u32 = 0,
    pApplicationInfo: ?*const VkApplicationInfo = null,
    enabledLayerCount: u32 = 0,
    ppEnabledLayerNames: ?[*]const [*:0]const u8 = null,
    enabledExtensionCount: u32 = 0,
    ppEnabledExtensionNames: ?[*]const [*:0]const u8 = null,
};

pub const VkPhysicalDeviceProperties = extern struct {
    apiVersion: u32,
    driverVersion: u32,
    vendorID: u32,
    deviceID: u32,
    deviceType: u32,
    deviceName: [256]u8,
    pipelineCacheUUID: [16]u8,
    limits: [500]u8, // Stubbed large array to avoid defining VkPhysicalDeviceLimits fully
    sparseProperties: [5]u32, // VkPhysicalDeviceSparseProperties
};

// Function Pointers
pub const PFN_vkCreateInstance = *const fn (pCreateInfo: *const VkInstanceCreateInfo, pAllocator: ?*anyopaque, pInstance: *VkInstance) callconv(.c) i32;
pub const PFN_vkEnumeratePhysicalDevices = *const fn (instance: VkInstance, pPhysicalDeviceCount: *u32, pPhysicalDevices: ?[*]VkPhysicalDevice) callconv(.c) i32;
pub const PFN_vkGetPhysicalDeviceProperties = *const fn (physicalDevice: VkPhysicalDevice, pProperties: *VkPhysicalDeviceProperties) callconv(.c) void;

pub const Loader = if (is_supported) struct {
    library: std.DynLib,
    createInstance: PFN_vkCreateInstance,
    enumeratePhysicalDevices: PFN_vkEnumeratePhysicalDevices,
    getPhysicalDeviceProperties: PFN_vkGetPhysicalDeviceProperties,

    pub fn init() !Loader {
        const lib_name = if (builtin.os.tag == .windows) "vulkan-1.dll" else "libvulkan.so.1";
        var lib = std.DynLib.open(lib_name) catch return error.VulkanLibraryNotFound;

        return Loader{
            .library = lib,
            .createInstance = lib.lookup(PFN_vkCreateInstance, "vkCreateInstance") orelse return error.SymbolNotFound,
            .enumeratePhysicalDevices = lib.lookup(PFN_vkEnumeratePhysicalDevices, "vkEnumeratePhysicalDevices") orelse return error.SymbolNotFound,
            .getPhysicalDeviceProperties = lib.lookup(PFN_vkGetPhysicalDeviceProperties, "vkGetPhysicalDeviceProperties") orelse return error.SymbolNotFound,
        };
    }

    pub fn deinit(self: *Loader) void {
        self.library.close();
    }
} else struct {
    // Stub for unsupported platforms (WASM, freestanding)
    pub fn init() !@This() {
        return error.UnsupportedPlatform;
    }

    pub fn deinit(_: *@This()) void {}
};
