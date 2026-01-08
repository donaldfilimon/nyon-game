/// D3D12 C bindings wrapper for Zig 0.16+
/// This module re-exports all D3D12/DXGI types from the C imports.
/// Note: In Zig 0.16, `usingnamespace` was removed. We now export types explicitly.
const cimport = @cImport({
    @cDefine("MIDL_INTERFACE", "struct");
    @cInclude("d3d12.h");
    @cInclude("dxgi1_6.h");
    @cInclude("d3dcompiler.h");
    @cInclude("dxgidebug.h");
});

// ============================================================================
// Re-export the entire C namespace for direct access
// This allows code to use c.c.* for any types not explicitly exported
// ============================================================================
pub const c = cimport;

// ============================================================================
// D3D12 Interface Types
// ============================================================================
pub const ID3D12Device = cimport.ID3D12Device;
pub const ID3D12CommandQueue = cimport.ID3D12CommandQueue;
pub const ID3D12CommandAllocator = cimport.ID3D12CommandAllocator;
pub const ID3D12GraphicsCommandList = cimport.ID3D12GraphicsCommandList;
pub const ID3D12PipelineState = cimport.ID3D12PipelineState;
pub const ID3D12RootSignature = cimport.ID3D12RootSignature;
pub const ID3D12Resource = cimport.ID3D12Resource;
pub const ID3D12Fence = cimport.ID3D12Fence;
pub const ID3D12DescriptorHeap = cimport.ID3D12DescriptorHeap;
pub const ID3D12Heap = cimport.ID3D12Heap;
pub const ID3D12Object = cimport.ID3D12Object;
pub const ID3D12Debug1 = cimport.ID3D12Debug1;
pub const ID3D12InfoQueue = cimport.ID3D12InfoQueue;

// ============================================================================
// DXGI Interface Types
// ============================================================================
pub const IDXGIFactory4 = cimport.IDXGIFactory4;
pub const IDXGIFactory5 = cimport.IDXGIFactory5;
pub const IDXGISwapChain3 = cimport.IDXGISwapChain3;
pub const IDXGIAdapter1 = cimport.IDXGIAdapter1;
pub const IDXGIDebug = cimport.IDXGIDebug;

// ============================================================================
// D3D12 Enum/Flag Types
// ============================================================================
pub const D3D12_COMMAND_LIST_TYPE = cimport.D3D12_COMMAND_LIST_TYPE;
pub const D3D12_DESCRIPTOR_HEAP_TYPE = cimport.D3D12_DESCRIPTOR_HEAP_TYPE;
pub const D3D12_DESCRIPTOR_HEAP_FLAG_NONE = cimport.D3D12_DESCRIPTOR_HEAP_FLAG_NONE;
pub const D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE = cimport.D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
pub const D3D12_HEAP_FLAGS = cimport.D3D12_HEAP_FLAGS;
pub const D3D12_HEAP_FLAG_NONE = cimport.D3D12_HEAP_FLAG_NONE;
pub const D3D12_HEAP_FLAG_ALLOW_ONLY_BUFFERS = cimport.D3D12_HEAP_FLAG_ALLOW_ONLY_BUFFERS;
pub const D3D12_HEAP_FLAG_ALLOW_ONLY_RT_DS_TEXTURES = cimport.D3D12_HEAP_FLAG_ALLOW_ONLY_RT_DS_TEXTURES;
pub const D3D12_HEAP_FLAG_ALLOW_ONLY_NON_RT_DS_TEXTURES = cimport.D3D12_HEAP_FLAG_ALLOW_ONLY_NON_RT_DS_TEXTURES;
pub const D3D12_HEAP_TYPE = cimport.D3D12_HEAP_TYPE;
pub const D3D12_RESOURCE_STATES = cimport.D3D12_RESOURCE_STATES;
pub const D3D12_DESCRIPTOR_RANGE_TYPE = cimport.D3D12_DESCRIPTOR_RANGE_TYPE;
pub const D3D12_ROOT_PARAMETER_TYPE = cimport.D3D12_ROOT_PARAMETER_TYPE;
pub const D3D12_PRIMITIVE_TOPOLOGY_TYPE = cimport.D3D12_PRIMITIVE_TOPOLOGY_TYPE;
pub const D3D12_RESOURCE_DIMENSION_BUFFER = cimport.D3D12_RESOURCE_DIMENSION_BUFFER;
pub const D3D12_TEXTURE_LAYOUT_ROW_MAJOR = cimport.D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
pub const D3D12_FEATURE_ARCHITECTURE = cimport.D3D12_FEATURE_ARCHITECTURE;
pub const D3D_FEATURE_LEVEL_11_0 = cimport.D3D_FEATURE_LEVEL_11_0;
pub const D3D12_MESSAGE_SEVERITY_INFO = cimport.D3D12_MESSAGE_SEVERITY_INFO;
pub const D3D12_MESSAGE_SEVERITY_MESSAGE = cimport.D3D12_MESSAGE_SEVERITY_MESSAGE;
pub const D3D12_MESSAGE_ID_CLEARRENDERTARGETVIEW_MISMATCHINGCLEARVALUE = cimport.D3D12_MESSAGE_ID_CLEARRENDERTARGETVIEW_MISMATCHINGCLEARVALUE;
pub const D3D12_MESSAGE_ID_CLEARDEPTHSTENCILVIEW_MISMATCHINGCLEARVALUE = cimport.D3D12_MESSAGE_ID_CLEARDEPTHSTENCILVIEW_MISMATCHINGCLEARVALUE;
pub const DXGI_ADAPTER_FLAG_SOFTWARE = cimport.DXGI_ADAPTER_FLAG_SOFTWARE;
pub const DXGI_FEATURE_PRESENT_ALLOW_TEARING = cimport.DXGI_FEATURE_PRESENT_ALLOW_TEARING;

// ============================================================================
// D3D12 Struct Types
// ============================================================================
pub const D3D12_CPU_DESCRIPTOR_HANDLE = cimport.D3D12_CPU_DESCRIPTOR_HANDLE;
pub const D3D12_GPU_DESCRIPTOR_HANDLE = cimport.D3D12_GPU_DESCRIPTOR_HANDLE;
pub const D3D12_GPU_VIRTUAL_ADDRESS = cimport.D3D12_GPU_VIRTUAL_ADDRESS;
pub const D3D12_HEAP_DESC = cimport.D3D12_HEAP_DESC;
pub const D3D12_HEAP_PROPERTIES = cimport.D3D12_HEAP_PROPERTIES;
pub const D3D12_RESOURCE_DESC = cimport.D3D12_RESOURCE_DESC;
pub const D3D12_CLEAR_VALUE = cimport.D3D12_CLEAR_VALUE;
pub const D3D12_INFO_QUEUE_FILTER = cimport.D3D12_INFO_QUEUE_FILTER;
pub const D3D12_MESSAGE_ID = cimport.D3D12_MESSAGE_ID;
pub const D3D12_MESSAGE_SEVERITY = cimport.D3D12_MESSAGE_SEVERITY;
pub const D3D12_FEATURE_DATA_ARCHITECTURE = cimport.D3D12_FEATURE_DATA_ARCHITECTURE;
pub const D3D12_DEFAULT_MSAA_RESOURCE_PLACEMENT_ALIGNMENT = cimport.D3D12_DEFAULT_MSAA_RESOURCE_PLACEMENT_ALIGNMENT;
pub const D3D12_RESOURCE_BARRIER = cimport.D3D12_RESOURCE_BARRIER;
pub const D3D12_RESOURCE_STATE_UNORDERED_ACCESS = cimport.D3D12_RESOURCE_STATE_UNORDERED_ACCESS;

// ============================================================================
// DXGI Types
// ============================================================================
pub const DXGI_FORMAT = cimport.DXGI_FORMAT;
pub const DXGI_FORMAT_UNKNOWN = cimport.DXGI_FORMAT_UNKNOWN;
pub const DXGI_SWAP_CHAIN_DESC1 = cimport.DXGI_SWAP_CHAIN_DESC1;
pub const DXGI_ADAPTER_DESC1 = cimport.DXGI_ADAPTER_DESC1;
pub const DXGI_DEBUG_ALL = cimport.DXGI_DEBUG_ALL;
pub const DXGI_DEBUG_RLO_ALL = cimport.DXGI_DEBUG_RLO_ALL;

// ============================================================================
// Win32/Common Types
// ============================================================================
pub const HRESULT = cimport.HRESULT;
pub const HANDLE = cimport.HANDLE;
pub const HWND = cimport.HWND;
pub const BOOL = cimport.BOOL;
pub const UINT = cimport.UINT;
pub const IID = cimport.IID;
pub const GUID = cimport.GUID;
pub const LUID = cimport.LUID;

// ============================================================================
// Constants
// ============================================================================
pub const S_OK = cimport.S_OK;
pub const TRUE = cimport.TRUE;
pub const FALSE = cimport.FALSE;
pub const E_OUTOFMEMORY = cimport.E_OUTOFMEMORY;
pub const DXGI_ERROR_NOT_FOUND = cimport.DXGI_ERROR_NOT_FOUND;
pub const DXGI_ERROR_INVALID_CALL = cimport.DXGI_ERROR_INVALID_CALL;
pub const DXGI_CREATE_FACTORY_DEBUG = cimport.DXGI_CREATE_FACTORY_DEBUG;

// ============================================================================
// IIDs (Interface Identifiers) - Access via c.c.IID_* at runtime
// These cannot be exported as comptime values since they're C runtime values.
// Use c.c.IID_IDXGIFactory4, c.c.IID_ID3D12Device, etc.
// ============================================================================

// ============================================================================
// Functions - Re-export from C bindings
// ============================================================================
pub const CreateDXGIFactory2 = cimport.CreateDXGIFactory2;
pub const D3D12CreateDevice = cimport.D3D12CreateDevice;
pub const D3D12GetDebugInterface = cimport.D3D12GetDebugInterface;
pub const DXGIGetDebugInterface1 = cimport.DXGIGetDebugInterface1;

// ============================================================================
// BoundedArray replacement for Zig 0.16+
// std.BoundedArray was removed in Zig 0.15
// ============================================================================
pub fn BoundedArray(comptime T: type, comptime capacity: usize) type {
    return struct {
        buffer: [capacity]T = undefined,
        len: usize = 0,

        const Self = @This();

        pub fn init(initial_len: usize) Self {
            return .{ .len = initial_len };
        }

        pub fn slice(self: *Self) []T {
            return self.buffer[0..self.len];
        }

        pub fn constSlice(self: *const Self) []const T {
            return self.buffer[0..self.len];
        }

        pub fn append(self: *Self, item: T) !void {
            if (self.len >= capacity) return error.Overflow;
            self.buffer[self.len] = item;
            self.len += 1;
        }

        pub fn appendAssumeCapacity(self: *Self, item: T) void {
            self.buffer[self.len] = item;
            self.len += 1;
        }

        pub fn get(self: *const Self, index: usize) T {
            return self.buffer[index];
        }

        pub fn set(self: *Self, index: usize, value: T) void {
            self.buffer[index] = value;
        }

        pub fn resize(self: *Self, new_len: usize) !void {
            if (new_len > capacity) return error.Overflow;
            self.len = new_len;
        }
    };
}
