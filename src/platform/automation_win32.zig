//! Windows UI Automation Bindings for Perihelion Ring AI Agent

const std = @import("std");
const win32 = @import("win32.zig");

pub const WINAPI = win32.WINAPI;

pub const GUID = extern struct {
    Data1: u32,
    Data2: u16,
    Data3: u16,
    Data4: [8]u8,
};

// GUIDs
pub const CLSID_CUIAutomation = GUID{
    .Data1 = 0xff48dba4,
    .Data2 = 0x60ef,
    .Data3 = 0x4201,
    .Data4 = .{ 0xaa, 0x87, 0x54, 0x10, 0x3e, 0xef, 0x59, 0x4e },
};

pub const IID_IUIAutomation = GUID{
    .Data1 = 0x30cbe57d,
    .Data2 = 0xd9d0,
    .Data3 = 0x452a,
    .Data4 = .{ 0xab, 0x13, 0x7a, 0xc4, 0xf9, 0x85, 0xda, 0x70 },
};

pub const IID_IUIAutomationElement = GUID{
    .Data1 = 0xd22108aa,
    .Data2 = 0x8ac5,
    .Data3 = 0x49a5,
    .Data4 = .{ 0x83, 0x7b, 0x37, 0xbb, 0xb3, 0xd7, 0x59, 0x1e },
};

// COM Helper Types
pub const HRESULT = i32;
pub const S_OK: HRESULT = 0;
pub const S_FALSE: HRESULT = 1;

pub const CLSCTX_INPROC_SERVER = 0x1;

// Interfaces
pub const IUnknown = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        QueryInterface: *const fn (self: *IUnknown, riid: *const GUID, ppvObject: *?*anyopaque) callconv(WINAPI) HRESULT,
        AddRef: *const fn (self: *IUnknown) callconv(WINAPI) u32,
        Release: *const fn (self: *IUnknown) callconv(WINAPI) u32,
    };

    pub inline fn Release(self: *IUnknown) u32 {
        return self.vtable.Release(self);
    }
};

pub const IUIAutomationElement = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        base: IUnknown.VTable,
        SetFocus: *const fn (self: *IUIAutomationElement) callconv(WINAPI) HRESULT,
        GetRuntimeId: *const fn (self: *IUIAutomationElement, runtimeId: *?*anyopaque) callconv(WINAPI) HRESULT,
        FindFirst: *const fn (self: *IUIAutomationElement, scope: TreeScope, condition: *IUIAutomationCondition, found: *?*IUIAutomationElement) callconv(WINAPI) HRESULT,
        FindAll: *const fn (self: *IUIAutomationElement, scope: TreeScope, condition: *IUIAutomationCondition, found: *?*anyopaque) callconv(WINAPI) HRESULT,
        // ... incomplete vtable, add methods as needed
        get_CurrentProcessId: *const fn (self: *IUIAutomationElement, retVal: *i32) callconv(WINAPI) HRESULT,
        get_CurrentControlType: *const fn (self: *IUIAutomationElement, retVal: *i32) callconv(WINAPI) HRESULT,
        get_CurrentLocalizedControlType: *const fn (self: *IUIAutomationElement, retVal: *?*anyopaque) callconv(WINAPI) HRESULT,
        get_CurrentName: *const fn (self: *IUIAutomationElement, retVal: *?*anyopaque) callconv(WINAPI) HRESULT, // Should be BSTR
    };

    pub inline fn Release(self: *IUIAutomationElement) u32 {
        return self.vtable.base.Release(@ptrCast(self));
    }

    pub inline fn FindFirst(self: *IUIAutomationElement, scope: TreeScope, condition: *IUIAutomationCondition) !?*IUIAutomationElement {
        var found: ?*IUIAutomationElement = null;
        const hr = self.vtable.FindFirst(self, scope, condition, &found);
        if (hr != S_OK) return error.ComError;
        return found;
    }
};

pub const IUIAutomationCondition = extern struct {
    vtable: *const VTable,
    pub const VTable = extern struct {
        base: IUnknown.VTable,
    };
};

pub const IUIAutomation = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        base: IUnknown.VTable,
        CompareElements: *const fn (self: *IUIAutomation, el1: *IUIAutomationElement, el2: *IUIAutomationElement, areSame: *i32) callconv(WINAPI) HRESULT,
        CompareRuntimeIds: *const fn (self: *IUIAutomation, safearray1: *anyopaque, safearray2: *anyopaque, areSame: *i32) callconv(WINAPI) HRESULT,
        GetRootElement: *const fn (self: *IUIAutomation, root: *?*IUIAutomationElement) callconv(WINAPI) HRESULT,
        GetElementFromHandle: *const fn (self: *IUIAutomation, hwnd: ?*anyopaque, element: *?*IUIAutomationElement) callconv(WINAPI) HRESULT,
        GetFocusedElement: *const fn (self: *IUIAutomation, element: *?*IUIAutomationElement) callconv(WINAPI) HRESULT,
        GetRootElementBuildCache: *const fn (self: *IUIAutomation, cacheRequest: *anyopaque, root: *?*IUIAutomationElement) callconv(WINAPI) HRESULT,
        GetElementFromHandleBuildCache: *const fn (self: *IUIAutomation, hwnd: ?*anyopaque, cacheRequest: *anyopaque, element: *?*IUIAutomationElement) callconv(WINAPI) HRESULT,
        GetFocusedElementBuildCache: *const fn (self: *IUIAutomation, cacheRequest: *anyopaque, element: *?*IUIAutomationElement) callconv(WINAPI) HRESULT,
        CreateTreeWalker: *const fn (self: *IUIAutomation, condition: *IUIAutomationCondition, walker: *?*anyopaque) callconv(WINAPI) HRESULT,
        get_ControlViewWalker: *const fn (self: *IUIAutomation, walker: *?*anyopaque) callconv(WINAPI) HRESULT,
        get_ContentViewWalker: *const fn (self: *IUIAutomation, walker: *?*anyopaque) callconv(WINAPI) HRESULT,
        get_RawViewWalker: *const fn (self: *IUIAutomation, walker: *?*anyopaque) callconv(WINAPI) HRESULT,
        get_RawViewCondition: *const fn (self: *IUIAutomation, condition: *?*IUIAutomationCondition) callconv(WINAPI) HRESULT,
        get_ControlViewCondition: *const fn (self: *IUIAutomation, condition: *?*IUIAutomationCondition) callconv(WINAPI) HRESULT,
        get_ContentViewCondition: *const fn (self: *IUIAutomation, condition: *?*IUIAutomationCondition) callconv(WINAPI) HRESULT,
        CreateCacheRequest: *const fn (self: *IUIAutomation, cacheRequest: *?*anyopaque) callconv(WINAPI) HRESULT,
        CreateTrueCondition: *const fn (self: *IUIAutomation, newCondition: *?*IUIAutomationCondition) callconv(WINAPI) HRESULT,
        CreateFalseCondition: *const fn (self: *IUIAutomation, newCondition: *?*IUIAutomationCondition) callconv(WINAPI) HRESULT,
        // CreatePropertyCondition: *const fn (self: *IUIAutomation, propertyId: i32, value: std.os.windows.VARIANT, newCondition: *?*IUIAutomationCondition) callconv(WINAPI) HRESULT,
        // CreatePropertyConditionEx: *const fn (self: *IUIAutomation, propertyId: i32, value: std.os.windows.VARIANT, flags: i32, newCondition: *?*IUIAutomationCondition) callconv(WINAPI) HRESULT,
        // ... simplified
    };

    pub inline fn Release(self: *IUIAutomation) u32 {
        return self.vtable.base.Release(@ptrCast(self));
    }

    pub inline fn GetRootElement(self: *IUIAutomation) !*IUIAutomationElement {
        var root: ?*IUIAutomationElement = null;
        const hr = self.vtable.GetRootElement(self, &root);
        if (hr != S_OK) return error.ComError;
        return root orelse error.ElementNotFound;
    }
};

// Enums
pub const TreeScope = enum(i32) {
    Element = 0x1,
    Children = 0x2,
    Descendants = 0x4,
    Parent = 0x8,
    Ancestors = 0x10,
    Subtree = 0x7,
};

// Functions
pub extern "ole32" fn CoInitializeEx(pvReserved: ?*anyopaque, dwCoInit: u32) callconv(WINAPI) HRESULT;
pub extern "ole32" fn CoUninitialize() callconv(WINAPI) void;
pub extern "ole32" fn CoCreateInstance(rclsid: *const GUID, pUnkOuter: ?*IUnknown, dwClsContext: u32, riid: *const GUID, ppv: *?*anyopaque) callconv(WINAPI) HRESULT;

pub const COINIT_MULTITHREADED = 0x0;
pub const COINIT_APARTMENTTHREADED = 0x2;

pub const AutomationError = error{
    ComError,
    ElementNotFound,
    InitializationFailed,
};

// Main Automation Handler
pub const Automation = struct {
    client: *IUIAutomation,

    pub fn init() !Automation {
        // Initialize COM
        const hr_init = CoInitializeEx(null, COINIT_MULTITHREADED);
        if (hr_init != S_OK and hr_init != S_FALSE) return error.InitializationFailed;

        // Create Instance
        var client_ptr: ?*anyopaque = null;
        const hr_create = CoCreateInstance(&CLSID_CUIAutomation, null, CLSCTX_INPROC_SERVER, &IID_IUIAutomation, &client_ptr);

        if (hr_create != S_OK or client_ptr == null) {
            CoUninitialize();
            return error.InitializationFailed;
        }

        return Automation{
            .client = @ptrCast(@alignCast(client_ptr)),
        };
    }

    pub fn deinit(self: *Automation) void {
        _ = self.client.Release();
        CoUninitialize();
    }

    pub fn getRoot(self: *Automation) !*IUIAutomationElement {
        return self.client.GetRootElement();
    }
};
