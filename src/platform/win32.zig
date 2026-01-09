//! Win32 API Definitions

const std = @import("std");
const builtin = @import("builtin");

pub const WINAPI: std.builtin.CallingConvention = if (builtin.cpu.arch == .x86) .stdcall else .c;

pub const HWND = *opaque {};
pub const HINSTANCE = *opaque {};
pub const HICON = *opaque {};
pub const HCURSOR = *opaque {};
pub const HBRUSH = *opaque {};
pub const HMENU = *opaque {};
pub const HDC = *opaque {};

pub const WNDPROC = *const fn (hwnd: HWND, uMsg: u32, wParam: usize, lParam: isize) callconv(WINAPI) isize;

pub const WNDCLASSEXA = extern struct {
    cbSize: u32,
    style: u32,
    lpfnWndProc: WNDPROC,
    cbClsExtra: i32,
    cbWndExtra: i32,
    hInstance: HINSTANCE,
    hIcon: ?HICON,
    hCursor: ?HCURSOR,
    hbrBackground: ?HBRUSH,
    lpszMenuName: ?[*:0]const u8,
    lpszClassName: [*:0]const u8,
    hIconSm: ?HICON,
};

pub const POINT = extern struct {
    x: i32,
    y: i32,
};

pub const MSG = extern struct {
    hwnd: ?HWND,
    message: u32,
    wParam: usize,
    lParam: isize,
    time: u32,
    pt: POINT,
    lPrivate: u32,
};

pub const RECT = extern struct {
    left: i32,
    top: i32,
    right: i32,
    bottom: i32,
};

// Functions
pub extern "user32" fn RegisterClassExA(lpwcx: *const WNDCLASSEXA) callconv(WINAPI) u16;
pub extern "user32" fn CreateWindowExA(
    dwExStyle: u32,
    lpClassName: [*:0]const u8,
    lpWindowName: [*:0]const u8,
    dwStyle: u32,
    x: i32,
    y: i32,
    nWidth: i32,
    nHeight: i32,
    hWndParent: ?HWND,
    hMenu: ?HMENU,
    hInstance: ?HINSTANCE,
    lpParam: ?*anyopaque,
) callconv(WINAPI) ?HWND;

pub extern "user32" fn DestroyWindow(hWnd: HWND) callconv(WINAPI) i32;
pub extern "user32" fn DefWindowProcA(hWnd: HWND, Msg: u32, wParam: usize, lParam: isize) callconv(WINAPI) isize;
pub extern "user32" fn PeekMessageA(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: u32, wMsgFilterMax: u32, wRemoveMsg: u32) callconv(WINAPI) i32;
pub extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(WINAPI) i32;
pub extern "user32" fn DispatchMessageA(lpMsg: *const MSG) callconv(WINAPI) isize;
pub extern "user32" fn GetModuleHandleA(lpModuleName: ?[*:0]const u8) callconv(WINAPI) ?HINSTANCE;
pub extern "user32" fn LoadCursorA(hInstance: ?HINSTANCE, lpCursorName: ?[*:0]const u8) callconv(WINAPI) ?HCURSOR;
pub extern "user32" fn AdjustWindowRect(lpRect: *RECT, dwStyle: u32, bMenu: i32) callconv(WINAPI) i32;
pub extern "user32" fn SetWindowTextA(hWnd: HWND, lpString: [*:0]const u8) callconv(WINAPI) i32;
pub extern "user32" fn GetClientRect(hWnd: HWND, lpRect: *RECT) callconv(WINAPI) i32;
pub extern "user32" fn SetWindowLongPtrA(hWnd: HWND, nIndex: i32, dwNewLong: isize) callconv(WINAPI) isize;
pub extern "user32" fn GetWindowLongPtrA(hWnd: HWND, nIndex: i32) callconv(WINAPI) isize;

// Constants
pub const GWLP_USERDATA = -21;
pub const CS_HREDRAW = 0x0002;
pub const CS_VREDRAW = 0x0001;
pub const CS_OWNDC = 0x0020;

pub const WS_OVERLAPPED = 0x00000000;
pub const WS_CAPTION = 0x00C00000;
pub const WS_SYSMENU = 0x00080000;
pub const WS_THICKFRAME = 0x00040000;
pub const WS_MINIMIZEBOX = 0x00020000;
pub const WS_MAXIMIZEBOX = 0x00010000;
pub const WS_OVERLAPPEDWINDOW = (WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX);
pub const WS_VISIBLE = 0x10000000;

pub const PM_REMOVE = 0x0001;

pub const WM_QUIT = 0x0012;
pub const WM_DESTROY = 0x0002;
pub const WM_CLOSE = 0x0010;
pub const WM_KEYDOWN = 0x0100;
pub const WM_KEYUP = 0x0101;
pub const WM_LBUTTONDOWN = 0x0201;
pub const WM_LBUTTONUP = 0x0202;
pub const WM_MOUSEMOVE = 0x0200;

pub const IDC_ARROW: ?[*:0]const u8 = @ptrFromInt(32512);
