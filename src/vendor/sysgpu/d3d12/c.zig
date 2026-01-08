/// D3D12 C bindings wrapper for Zig 0.16+
/// Note: In Zig 0.16, `usingnamespace` was removed. We now export the C namespace directly.
pub const c = @cImport({
    @cDefine("MIDL_INTERFACE", "struct");
    @cInclude("d3d12.h");
    @cInclude("dxgi1_6.h");
    @cInclude("d3dcompiler.h");
    @cInclude("dxgidebug.h");
});

// ============================================================================
// D3D12 Interface Types
// ============================================================================
pub const ID3D12Device = c.ID3D12Device;
pub const ID3D12CommandQueue = c.ID3D12CommandQueue;
pub const ID3D12CommandAllocator = c.ID3D12CommandAllocator;
pub const ID3D12GraphicsCommandList = c.ID3D12GraphicsCommandList;
pub const ID3D12PipelineState = c.ID3D12PipelineState;
pub const ID3D12RootSignature = c.ID3D12RootSignature;
pub const ID3D12Resource = c.ID3D12Resource;
pub const ID3D12Fence = c.ID3D12Fence;
pub const ID3D12DescriptorHeap = c.ID3D12DescriptorHeap;
pub const ID3D12Heap = c.ID3D12Heap;
pub const ID3D12Object = c.ID3D12Object;
pub const ID3D12Debug1 = c.ID3D12Debug1;
pub const ID3D12InfoQueue = c.ID3D12InfoQueue;

// ============================================================================
// DXGI Interface Types
// ============================================================================
pub const IDXGIFactory4 = c.IDXGIFactory4;
pub const IDXGIFactory5 = c.IDXGIFactory5;
pub const IDXGISwapChain3 = c.IDXGISwapChain3;
pub const IDXGIAdapter1 = c.IDXGIAdapter1;
pub const IDXGIDebug = c.IDXGIDebug;

// ============================================================================
// D3D12 Enum/Flag Types
// ============================================================================
pub const D3D12_COMMAND_LIST_TYPE = c.D3D12_COMMAND_LIST_TYPE;
pub const D3D12_DESCRIPTOR_HEAP_TYPE = c.D3D12_DESCRIPTOR_HEAP_TYPE;
pub const D3D12_DESCRIPTOR_HEAP_FLAG_NONE = c.D3D12_DESCRIPTOR_HEAP_FLAG_NONE;
pub const D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE = c.D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
pub const D3D12_HEAP_FLAGS = c.D3D12_HEAP_FLAGS;
pub const D3D12_HEAP_FLAG_NONE = c.D3D12_HEAP_FLAG_NONE;
pub const D3D12_HEAP_FLAG_ALLOW_ONLY_BUFFERS = c.D3D12_HEAP_FLAG_ALLOW_ONLY_BUFFERS;
pub const D3D12_HEAP_FLAG_ALLOW_ONLY_RT_DS_TEXTURES = c.D3D12_HEAP_FLAG_ALLOW_ONLY_RT_DS_TEXTURES;
pub const D3D12_HEAP_FLAG_ALLOW_ONLY_NON_RT_DS_TEXTURES = c.D3D12_HEAP_FLAG_ALLOW_ONLY_NON_RT_DS_TEXTURES;
pub const D3D12_HEAP_TYPE = c.D3D12_HEAP_TYPE;
pub const D3D12_RESOURCE_STATES = c.D3D12_RESOURCE_STATES;
pub const D3D12_DESCRIPTOR_RANGE_TYPE = c.D3D12_DESCRIPTOR_RANGE_TYPE;
pub const D3D12_ROOT_PARAMETER_TYPE = c.D3D12_ROOT_PARAMETER_TYPE;
pub const D3D12_PRIMITIVE_TOPOLOGY_TYPE = c.D3D12_PRIMITIVE_TOPOLOGY_TYPE;
pub const D3D12_RESOURCE_DIMENSION_BUFFER = c.D3D12_RESOURCE_DIMENSION_BUFFER;
pub const D3D12_TEXTURE_LAYOUT_ROW_MAJOR = c.D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
pub const D3D12_FEATURE_ARCHITECTURE = c.D3D12_FEATURE_ARCHITECTURE;
pub const D3D_FEATURE_LEVEL_11_0 = c.D3D_FEATURE_LEVEL_11_0;
pub const D3D12_MESSAGE_SEVERITY_INFO = c.D3D12_MESSAGE_SEVERITY_INFO;
pub const D3D12_MESSAGE_SEVERITY_MESSAGE = c.D3D12_MESSAGE_SEVERITY_MESSAGE;
pub const D3D12_MESSAGE_ID_CLEARRENDERTARGETVIEW_MISMATCHINGCLEARVALUE = c.D3D12_MESSAGE_ID_CLEARRENDERTARGETVIEW_MISMATCHINGCLEARVALUE;
pub const D3D12_MESSAGE_ID_CLEARDEPTHSTENCILVIEW_MISMATCHINGCLEARVALUE = c.D3D12_MESSAGE_ID_CLEARDEPTHSTENCILVIEW_MISMATCHINGCLEARVALUE;
pub const DXGI_ADAPTER_FLAG_SOFTWARE = c.DXGI_ADAPTER_FLAG_SOFTWARE;
pub const DXGI_FEATURE_PRESENT_ALLOW_TEARING = c.DXGI_FEATURE_PRESENT_ALLOW_TEARING;

// ============================================================================
// D3D12 Struct Types
// ============================================================================
pub const D3D12_CPU_DESCRIPTOR_HANDLE = c.D3D12_CPU_DESCRIPTOR_HANDLE;
pub const D3D12_GPU_DESCRIPTOR_HANDLE = c.D3D12_GPU_DESCRIPTOR_HANDLE;
pub const D3D12_GPU_VIRTUAL_ADDRESS = c.D3D12_GPU_VIRTUAL_ADDRESS;
pub const D3D12_HEAP_DESC = c.D3D12_HEAP_DESC;
pub const D3D12_HEAP_PROPERTIES = c.D3D12_HEAP_PROPERTIES;
pub const D3D12_RESOURCE_DESC = c.D3D12_RESOURCE_DESC;
pub const D3D12_CLEAR_VALUE = c.D3D12_CLEAR_VALUE;
pub const D3D12_INFO_QUEUE_FILTER = c.D3D12_INFO_QUEUE_FILTER;
pub const D3D12_MESSAGE_ID = c.D3D12_MESSAGE_ID;
pub const D3D12_MESSAGE_SEVERITY = c.D3D12_MESSAGE_SEVERITY;
pub const D3D12_FEATURE_DATA_ARCHITECTURE = c.D3D12_FEATURE_DATA_ARCHITECTURE;
pub const D3D12_DEFAULT_MSAA_RESOURCE_PLACEMENT_ALIGNMENT = c.D3D12_DEFAULT_MSAA_RESOURCE_PLACEMENT_ALIGNMENT;
pub const D3D12_RESOURCE_BARRIER = c.D3D12_RESOURCE_BARRIER;
pub const D3D12_RESOURCE_STATE_UNORDERED_ACCESS = c.D3D12_RESOURCE_STATE_UNORDERED_ACCESS;

// ============================================================================
// DXGI Types
// ============================================================================
pub const DXGI_FORMAT = c.DXGI_FORMAT;
pub const DXGI_FORMAT_UNKNOWN = c.DXGI_FORMAT_UNKNOWN;
pub const DXGI_SWAP_CHAIN_DESC1 = c.DXGI_SWAP_CHAIN_DESC1;
pub const DXGI_ADAPTER_DESC1 = c.DXGI_ADAPTER_DESC1;
pub const DXGI_DEBUG_ALL = c.DXGI_DEBUG_ALL;
pub const DXGI_DEBUG_RLO_ALL = c.DXGI_DEBUG_RLO_ALL;

// ============================================================================
// Win32/Common Types
// ============================================================================
pub const HRESULT = c.HRESULT;
pub const HANDLE = c.HANDLE;
pub const HWND = c.HWND;
pub const BOOL = c.BOOL;
pub const UINT = c.UINT;
pub const IID = c.IID;
pub const LUID = c.LUID;

// ============================================================================
// Constants
// ============================================================================
pub const S_OK = c.S_OK;
pub const TRUE = c.TRUE;
pub const FALSE = c.FALSE;
pub const E_OUTOFMEMORY = c.E_OUTOFMEMORY;
pub const DXGI_ERROR_NOT_FOUND = c.DXGI_ERROR_NOT_FOUND;
pub const DXGI_ERROR_INVALID_CALL = c.DXGI_ERROR_INVALID_CALL;
pub const DXGI_CREATE_FACTORY_DEBUG = c.DXGI_CREATE_FACTORY_DEBUG;

// ============================================================================
// IIDs (Interface Identifiers) - accessed via c namespace at runtime
// ============================================================================
pub inline fn getIID_IDXGIFactory4() *const IID {
    return &c.IID_IDXGIFactory4;
}
pub inline fn getIID_IDXGIFactory5() *const IID {
    return &c.IID_IDXGIFactory5;
}
pub inline fn getIID_ID3D12Debug1() *const IID {
    return &c.IID_ID3D12Debug1;
}
pub inline fn getIID_ID3D12Device() *const IID {
    return &c.IID_ID3D12Device;
}
pub inline fn getIID_ID3D12Heap() *const IID {
    return &c.IID_ID3D12Heap;
}
pub inline fn getIID_ID3D12InfoQueue() *const IID {
    return &c.IID_ID3D12InfoQueue;
}
pub inline fn getIID_IDXGIDebug() *const IID {
    return &c.IID_IDXGIDebug;
}
pub inline fn getWKPDID_D3DDebugObjectName() *const c.GUID {
    return &c.WKPDID_D3DDebugObjectName;
}

// ============================================================================
// Functions - Re-export from C bindings
// ============================================================================
pub const CreateDXGIFactory2 = c.CreateDXGIFactory2;
pub const D3D12CreateDevice = c.D3D12CreateDevice;
pub const D3D12GetDebugInterface = c.D3D12GetDebugInterface;
pub const DXGIGetDebugInterface1 = c.DXGIGetDebugInterface1;
