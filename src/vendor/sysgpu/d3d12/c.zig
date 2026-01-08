/// D3D12 C bindings wrapper for Zig 0.16+
/// Note: In Zig 0.16, `usingnamespace` was removed. We now export the C namespace directly.
const c = @cImport({
    @cDefine("MIDL_INTERFACE", "struct");
    @cInclude("d3d12.h");
    @cInclude("dxgi1_6.h");
    @cInclude("d3dcompiler.h");
    @cInclude("dxgidebug.h");
});

// Re-export all C declarations
pub const d3d12 = c;

// Common type aliases for convenience
pub const ID3D12Device = c.ID3D12Device;
pub const ID3D12CommandQueue = c.ID3D12CommandQueue;
pub const ID3D12CommandAllocator = c.ID3D12CommandAllocator;
pub const ID3D12GraphicsCommandList = c.ID3D12GraphicsCommandList;
pub const ID3D12PipelineState = c.ID3D12PipelineState;
pub const ID3D12RootSignature = c.ID3D12RootSignature;
pub const ID3D12Resource = c.ID3D12Resource;
pub const ID3D12Fence = c.ID3D12Fence;
pub const ID3D12DescriptorHeap = c.ID3D12DescriptorHeap;
pub const IDXGIFactory4 = c.IDXGIFactory4;
pub const IDXGISwapChain3 = c.IDXGISwapChain3;
pub const IDXGIAdapter1 = c.IDXGIAdapter1;
pub const D3D12_COMMAND_LIST_TYPE = c.D3D12_COMMAND_LIST_TYPE;
pub const D3D12_DESCRIPTOR_HEAP_TYPE = c.D3D12_DESCRIPTOR_HEAP_TYPE;
pub const D3D12_HEAP_FLAGS = c.D3D12_HEAP_FLAGS;
pub const D3D12_HEAP_TYPE = c.D3D12_HEAP_TYPE;
pub const D3D12_RESOURCE_STATES = c.D3D12_RESOURCE_STATES;
pub const D3D12_CPU_DESCRIPTOR_HANDLE = c.D3D12_CPU_DESCRIPTOR_HANDLE;
pub const D3D12_GPU_DESCRIPTOR_HANDLE = c.D3D12_GPU_DESCRIPTOR_HANDLE;
pub const DXGI_FORMAT = c.DXGI_FORMAT;
pub const DXGI_SWAP_CHAIN_DESC1 = c.DXGI_SWAP_CHAIN_DESC1;
pub const HRESULT = c.HRESULT;
