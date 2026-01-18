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
// CLSID_CUIAutomation: {ff48dba4-60ef-4201-aa87-54103eef594e}
// On Windows, the CUIAutomation coclass and IUIAutomation interface share the same GUID
pub const CLSID_CUIAutomation = GUID{
    .Data1 = 0xff48dba4,
    .Data2 = 0x60ef,
    .Data3 = 0x4201,
    .Data4 = .{ 0xaa, 0x87, 0x54, 0x10, 0x3e, 0xef, 0x59, 0x4e },
};

// IID_IUIAutomation: {30cbe57d-d9d0-452a-ab13-7ac5ac4825ee}
pub const IID_IUIAutomation = GUID{
    .Data1 = 0x30cbe57d,
    .Data2 = 0xd9d0,
    .Data3 = 0x452a,
    .Data4 = .{ 0xab, 0x13, 0x7a, 0xc5, 0xac, 0x48, 0x25, 0xee },
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

// VARIANT structure for property conditions
pub const VARIANT = extern struct {
    vt: u16,
    wReserved1: u16 = 0,
    wReserved2: u16 = 0,
    wReserved3: u16 = 0,
    data: extern union {
        llVal: i64,
        lVal: i32,
        bVal: u8,
        iVal: i16,
        fltVal: f32,
        dblVal: f64,
        boolVal: i16,
        scode: i32,
        bstrVal: ?*anyopaque,
        punkVal: ?*anyopaque,
        pdispVal: ?*anyopaque,
        parray: ?*anyopaque,
        pbVal: ?*u8,
        piVal: ?*i16,
        plVal: ?*i32,
        pllVal: ?*i64,
        pfltVal: ?*f32,
        pdblVal: ?*f64,
        pboolVal: ?*i16,
        pscode: ?*i32,
        pbstrVal: ?*?*anyopaque,
        byref: ?*anyopaque,
        cVal: u8,
        uiVal: u16,
        ulVal: u32,
        ullVal: u64,
        intVal: i32,
        uintVal: u32,
        pdecVal: ?*anyopaque,
        pcVal: ?*u8,
        puiVal: ?*u16,
        pulVal: ?*u32,
        pullVal: ?*u64,
        pintVal: ?*i32,
        puintVal: ?*u32,
    } = .{ .llVal = 0 },
};

pub const RECT = extern struct {
    left: i32,
    top: i32,
    right: i32,
    bottom: i32,
};

pub const POINT = extern struct {
    x: i32,
    y: i32,
};

pub const IUIAutomation = extern struct {
    vtable: *const VTable,

    // IUIAutomation vtable - must match Windows SDK exactly (55 methods after IUnknown)
    // Reference: UIAutomationClient.h from Windows SDK
    pub const VTable = extern struct {
        // IUnknown methods (3 methods, indices 0-2)
        base: IUnknown.VTable,

        // IUIAutomation methods (indices 3-57)
        // Index 3
        CompareElements: *const fn (self: *IUIAutomation, el1: ?*IUIAutomationElement, el2: ?*IUIAutomationElement, areSame: *i32) callconv(WINAPI) HRESULT,
        // Index 4
        CompareRuntimeIds: *const fn (self: *IUIAutomation, runtimeId1: ?*anyopaque, runtimeId2: ?*anyopaque, areSame: *i32) callconv(WINAPI) HRESULT,
        // Index 5
        GetRootElement: *const fn (self: *IUIAutomation, root: *?*IUIAutomationElement) callconv(WINAPI) HRESULT,
        // Index 6
        ElementFromHandle: *const fn (self: *IUIAutomation, hwnd: ?*anyopaque, element: *?*IUIAutomationElement) callconv(WINAPI) HRESULT,
        // Index 7
        ElementFromPoint: *const fn (self: *IUIAutomation, pt: POINT, element: *?*IUIAutomationElement) callconv(WINAPI) HRESULT,
        // Index 8
        GetFocusedElement: *const fn (self: *IUIAutomation, element: *?*IUIAutomationElement) callconv(WINAPI) HRESULT,
        // Index 9
        GetRootElementBuildCache: *const fn (self: *IUIAutomation, cacheRequest: ?*anyopaque, root: *?*IUIAutomationElement) callconv(WINAPI) HRESULT,
        // Index 10
        ElementFromHandleBuildCache: *const fn (self: *IUIAutomation, hwnd: ?*anyopaque, cacheRequest: ?*anyopaque, element: *?*IUIAutomationElement) callconv(WINAPI) HRESULT,
        // Index 11
        ElementFromPointBuildCache: *const fn (self: *IUIAutomation, pt: POINT, cacheRequest: ?*anyopaque, element: *?*IUIAutomationElement) callconv(WINAPI) HRESULT,
        // Index 12
        GetFocusedElementBuildCache: *const fn (self: *IUIAutomation, cacheRequest: ?*anyopaque, element: *?*IUIAutomationElement) callconv(WINAPI) HRESULT,
        // Index 13
        CreateTreeWalker: *const fn (self: *IUIAutomation, pCondition: ?*IUIAutomationCondition, walker: *?*anyopaque) callconv(WINAPI) HRESULT,
        // Index 14
        get_ControlViewWalker: *const fn (self: *IUIAutomation, walker: *?*anyopaque) callconv(WINAPI) HRESULT,
        // Index 15
        get_ContentViewWalker: *const fn (self: *IUIAutomation, walker: *?*anyopaque) callconv(WINAPI) HRESULT,
        // Index 16
        get_RawViewWalker: *const fn (self: *IUIAutomation, walker: *?*anyopaque) callconv(WINAPI) HRESULT,
        // Index 17
        get_RawViewCondition: *const fn (self: *IUIAutomation, condition: *?*IUIAutomationCondition) callconv(WINAPI) HRESULT,
        // Index 18
        get_ControlViewCondition: *const fn (self: *IUIAutomation, condition: *?*IUIAutomationCondition) callconv(WINAPI) HRESULT,
        // Index 19
        get_ContentViewCondition: *const fn (self: *IUIAutomation, condition: *?*IUIAutomationCondition) callconv(WINAPI) HRESULT,
        // Index 20
        CreateCacheRequest: *const fn (self: *IUIAutomation, cacheRequest: *?*anyopaque) callconv(WINAPI) HRESULT,
        // Index 21
        CreateTrueCondition: *const fn (self: *IUIAutomation, newCondition: *?*IUIAutomationCondition) callconv(WINAPI) HRESULT,
        // Index 22
        CreateFalseCondition: *const fn (self: *IUIAutomation, newCondition: *?*IUIAutomationCondition) callconv(WINAPI) HRESULT,
        // Index 23
        CreatePropertyCondition: *const fn (self: *IUIAutomation, propertyId: i32, value: VARIANT, newCondition: *?*IUIAutomationCondition) callconv(WINAPI) HRESULT,
        // Index 24
        CreatePropertyConditionEx: *const fn (self: *IUIAutomation, propertyId: i32, value: VARIANT, flags: i32, newCondition: *?*IUIAutomationCondition) callconv(WINAPI) HRESULT,
        // Index 25
        CreateAndCondition: *const fn (self: *IUIAutomation, condition1: ?*IUIAutomationCondition, condition2: ?*IUIAutomationCondition, newCondition: *?*IUIAutomationCondition) callconv(WINAPI) HRESULT,
        // Index 26
        CreateAndConditionFromArray: *const fn (self: *IUIAutomation, conditions: ?*anyopaque, newCondition: *?*IUIAutomationCondition) callconv(WINAPI) HRESULT,
        // Index 27
        CreateAndConditionFromNativeArray: *const fn (self: *IUIAutomation, conditions: ?*?*IUIAutomationCondition, conditionCount: i32, newCondition: *?*IUIAutomationCondition) callconv(WINAPI) HRESULT,
        // Index 28
        CreateOrCondition: *const fn (self: *IUIAutomation, condition1: ?*IUIAutomationCondition, condition2: ?*IUIAutomationCondition, newCondition: *?*IUIAutomationCondition) callconv(WINAPI) HRESULT,
        // Index 29
        CreateOrConditionFromArray: *const fn (self: *IUIAutomation, conditions: ?*anyopaque, newCondition: *?*IUIAutomationCondition) callconv(WINAPI) HRESULT,
        // Index 30
        CreateOrConditionFromNativeArray: *const fn (self: *IUIAutomation, conditions: ?*?*IUIAutomationCondition, conditionCount: i32, newCondition: *?*IUIAutomationCondition) callconv(WINAPI) HRESULT,
        // Index 31
        CreateNotCondition: *const fn (self: *IUIAutomation, condition: ?*IUIAutomationCondition, newCondition: *?*IUIAutomationCondition) callconv(WINAPI) HRESULT,
        // Index 32
        AddAutomationEventHandler: *const fn (self: *IUIAutomation, eventId: i32, element: ?*IUIAutomationElement, scope: TreeScope, cacheRequest: ?*anyopaque, handler: ?*anyopaque) callconv(WINAPI) HRESULT,
        // Index 33
        RemoveAutomationEventHandler: *const fn (self: *IUIAutomation, eventId: i32, element: ?*IUIAutomationElement, handler: ?*anyopaque) callconv(WINAPI) HRESULT,
        // Index 34
        AddPropertyChangedEventHandlerNativeArray: *const fn (self: *IUIAutomation, element: ?*IUIAutomationElement, scope: TreeScope, cacheRequest: ?*anyopaque, handler: ?*anyopaque, propertyArray: ?*i32, propertyCount: i32) callconv(WINAPI) HRESULT,
        // Index 35
        AddPropertyChangedEventHandler: *const fn (self: *IUIAutomation, element: ?*IUIAutomationElement, scope: TreeScope, cacheRequest: ?*anyopaque, handler: ?*anyopaque, propertyArray: ?*anyopaque) callconv(WINAPI) HRESULT,
        // Index 36
        RemovePropertyChangedEventHandler: *const fn (self: *IUIAutomation, element: ?*IUIAutomationElement, handler: ?*anyopaque) callconv(WINAPI) HRESULT,
        // Index 37
        AddStructureChangedEventHandler: *const fn (self: *IUIAutomation, element: ?*IUIAutomationElement, scope: TreeScope, cacheRequest: ?*anyopaque, handler: ?*anyopaque) callconv(WINAPI) HRESULT,
        // Index 38
        RemoveStructureChangedEventHandler: *const fn (self: *IUIAutomation, element: ?*IUIAutomationElement, handler: ?*anyopaque) callconv(WINAPI) HRESULT,
        // Index 39
        AddFocusChangedEventHandler: *const fn (self: *IUIAutomation, cacheRequest: ?*anyopaque, handler: ?*anyopaque) callconv(WINAPI) HRESULT,
        // Index 40
        RemoveFocusChangedEventHandler: *const fn (self: *IUIAutomation, handler: ?*anyopaque) callconv(WINAPI) HRESULT,
        // Index 41
        RemoveAllEventHandlers: *const fn (self: *IUIAutomation) callconv(WINAPI) HRESULT,
        // Index 42
        IntNativeArrayToSafeArray: *const fn (self: *IUIAutomation, array: ?*i32, arrayCount: i32, safeArray: *?*anyopaque) callconv(WINAPI) HRESULT,
        // Index 43
        IntSafeArrayToNativeArray: *const fn (self: *IUIAutomation, intArray: ?*anyopaque, array: *?*i32, arrayCount: *i32) callconv(WINAPI) HRESULT,
        // Index 44
        RectToVariant: *const fn (self: *IUIAutomation, rc: RECT, @"var": *VARIANT) callconv(WINAPI) HRESULT,
        // Index 45
        VariantToRect: *const fn (self: *IUIAutomation, @"var": VARIANT, rc: *RECT) callconv(WINAPI) HRESULT,
        // Index 46
        SafeArrayToRectNativeArray: *const fn (self: *IUIAutomation, rects: ?*anyopaque, rectArray: *?*RECT, rectArrayCount: *i32) callconv(WINAPI) HRESULT,
        // Index 47
        CreateProxyFactoryEntry: *const fn (self: *IUIAutomation, factory: ?*anyopaque, factoryEntry: *?*anyopaque) callconv(WINAPI) HRESULT,
        // Index 48
        get_ProxyFactoryMapping: *const fn (self: *IUIAutomation, factoryMapping: *?*anyopaque) callconv(WINAPI) HRESULT,
        // Index 49
        GetPropertyProgrammaticName: *const fn (self: *IUIAutomation, property: i32, name: *?*anyopaque) callconv(WINAPI) HRESULT,
        // Index 50
        GetPatternProgrammaticName: *const fn (self: *IUIAutomation, pattern: i32, name: *?*anyopaque) callconv(WINAPI) HRESULT,
        // Index 51
        PollForPotentialSupportedPatterns: *const fn (self: *IUIAutomation, pElement: ?*IUIAutomationElement, patternIds: *?*anyopaque, patternNames: *?*anyopaque) callconv(WINAPI) HRESULT,
        // Index 52
        PollForPotentialSupportedProperties: *const fn (self: *IUIAutomation, pElement: ?*IUIAutomationElement, propertyIds: *?*anyopaque, propertyNames: *?*anyopaque) callconv(WINAPI) HRESULT,
        // Index 53
        CheckNotSupported: *const fn (self: *IUIAutomation, value: VARIANT, isNotSupported: *i32) callconv(WINAPI) HRESULT,
        // Index 54
        get_ReservedNotSupportedValue: *const fn (self: *IUIAutomation, notSupportedValue: *?*IUnknown) callconv(WINAPI) HRESULT,
        // Index 55
        get_ReservedMixedAttributeValue: *const fn (self: *IUIAutomation, mixedAttributeValue: *?*IUnknown) callconv(WINAPI) HRESULT,
        // Index 56
        ElementFromIAccessible: *const fn (self: *IUIAutomation, accessible: ?*anyopaque, childId: i32, element: *?*IUIAutomationElement) callconv(WINAPI) HRESULT,
        // Index 57
        ElementFromIAccessibleBuildCache: *const fn (self: *IUIAutomation, accessible: ?*anyopaque, childId: i32, cacheRequest: ?*anyopaque, element: *?*IUIAutomationElement) callconv(WINAPI) HRESULT,
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
        // Initialize COM (UI Automation requires apartment-threaded model)
        var hr_init = CoInitializeEx(null, COINIT_APARTMENTTHREADED);
        if (hr_init != S_OK and hr_init != S_FALSE) {
            std.log.warn("Apartment-threaded COM init failed: 0x{x}, trying multithreaded", .{@as(u32, @bitCast(hr_init))});
            // Try multithreaded as fallback
            hr_init = CoInitializeEx(null, COINIT_MULTITHREADED);
            if (hr_init != S_OK and hr_init != S_FALSE) {
                std.log.err("COM initialization failed: 0x{x}", .{@as(u32, @bitCast(hr_init))});
                return error.InitializationFailed;
            }
        }

        // Create Instance
        var client_ptr: ?*anyopaque = null;
        const hr_create = CoCreateInstance(&CLSID_CUIAutomation, null, CLSCTX_INPROC_SERVER, &IID_IUIAutomation, &client_ptr);

        if (hr_create != S_OK or client_ptr == null) {
            std.log.err("CoCreateInstance failed: 0x{x}", .{@as(u32, @bitCast(hr_create))});
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
