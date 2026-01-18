//! Platform Window Abstraction

const std = @import("std");
const builtin = @import("builtin");
const win32 = if (builtin.os.tag == .windows) @import("win32.zig") else struct {};

/// Window handle
pub const Handle = *anyopaque;

var should_close: bool = false;

/// Create a window
pub fn create(width: u32, height: u32, title: []const u8) !?Handle {
    should_close = false;
    switch (builtin.os.tag) {
        .windows => return createWin32Window(width, height, title),
        else => return null,
    }
}

/// Destroy a window
pub fn destroy(handle: ?Handle) void {
    if (handle) |h| {
        switch (builtin.os.tag) {
            .windows => {
                _ = win32.DestroyWindow(@ptrCast(@alignCast(h)));
            },
            else => {},
        }
    }
}

/// Check if window should close
pub fn shouldClose(handle: ?Handle) bool {
    _ = handle;
    return should_close;
}

/// Poll window events
pub fn pollEvents() void {
    switch (builtin.os.tag) {
        .windows => {
            var msg: win32.MSG = undefined;
            while (win32.PeekMessageA(&msg, null, 0, 0, win32.PM_REMOVE) != 0) {
                if (msg.message == win32.WM_QUIT) {
                    should_close = true;
                }
                _ = win32.TranslateMessage(&msg);
                _ = win32.DispatchMessageA(&msg);
            }
        },
        else => {},
    }
}

/// Get window size
pub fn getSize(handle: ?Handle) struct { width: u32, height: u32 } {
    var w: u32 = 0;
    var h: u32 = 0;

    if (handle) |hwnd| {
        if (builtin.os.tag == .windows) {
            var rect: win32.RECT = undefined;
            if (win32.GetClientRect(@ptrCast(@alignCast(hwnd)), &rect) != 0) {
                w = @intCast(rect.right - rect.left);
                h = @intCast(rect.bottom - rect.top);
            }
        }
    }

    return .{ .width = w, .height = h };
}

/// Present a framebuffer to the window
/// The framebuffer is expected to be RGBA (4 bytes per pixel), stored row-major from top-left.
pub fn presentFramebuffer(handle: ?Handle, pixels: []const u8, width: u32, height: u32) void {
    if (handle == null) return;

    switch (builtin.os.tag) {
        .windows => presentFramebufferWin32(handle.?, pixels, width, height),
        else => {},
    }
}

fn presentFramebufferWin32(handle: Handle, pixels: []const u8, width: u32, height: u32) void {
    const hwnd: win32.HWND = @ptrCast(@alignCast(handle));
    const hdc = win32.GetDC(hwnd) orelse return;
    defer _ = win32.ReleaseDC(hwnd, hdc);

    // Set up BITMAPINFO for 32-bit RGBA
    // Note: Windows DIB uses bottom-up by default; negative height = top-down
    var bmi: win32.BITMAPINFO = undefined;
    bmi.bmiHeader = .{
        .biSize = @sizeOf(win32.BITMAPINFOHEADER),
        .biWidth = @intCast(width),
        .biHeight = -@as(i32, @intCast(height)), // Negative for top-down
        .biPlanes = 1,
        .biBitCount = 32,
        .biCompression = win32.BI_RGB,
        .biSizeImage = 0,
        .biXPelsPerMeter = 0,
        .biYPelsPerMeter = 0,
        .biClrUsed = 0,
        .biClrImportant = 0,
    };

    // Get current client size for stretching
    const size = getSize(handle);
    const dest_width: i32 = @intCast(size.width);
    const dest_height: i32 = @intCast(size.height);

    _ = win32.StretchDIBits(
        hdc,
        0,
        0,
        dest_width,
        dest_height,
        0,
        0,
        @intCast(width),
        @intCast(height),
        pixels.ptr,
        &bmi,
        win32.DIB_RGB_COLORS,
        win32.SRCCOPY,
    );
}

// Platform-specific implementations

fn createWin32Window(width: u32, height: u32, title: []const u8) !?Handle {
    const hInstance = win32.GetModuleHandleA(null);
    const class_name = "NyonWindowClass";

    var wnd_class = win32.WNDCLASSEXA{
        .cbSize = @sizeOf(win32.WNDCLASSEXA),
        .style = win32.CS_HREDRAW | win32.CS_VREDRAW | win32.CS_OWNDC,
        .lpfnWndProc = wndProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = hInstance orelse return error.WindowInitFailed,
        .hIcon = null,
        .hCursor = win32.LoadCursorA(null, win32.IDC_ARROW),
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = class_name,
        .hIconSm = null,
    };

    if (win32.RegisterClassExA(&wnd_class) == 0) {
        return error.RegisterClassFailed;
    }

    // Adjust window size
    var rect = win32.RECT{ .left = 0, .top = 0, .right = @intCast(width), .bottom = @intCast(height) };
    _ = win32.AdjustWindowRect(&rect, win32.WS_OVERLAPPEDWINDOW, 0);

    const win_width = rect.right - rect.left;
    const win_height = rect.bottom - rect.top;

    // Convert title slice to C string
    // This is lazy but works for short titles. In real app use an allocator.
    var title_buf: [256]u8 = undefined;
    const len = @min(title.len, 255);
    @memcpy(title_buf[0..len], title[0..len]);
    title_buf[len] = 0;

    const hwnd = win32.CreateWindowExA(
        0,
        class_name,
        @ptrCast(&title_buf),
        win32.WS_OVERLAPPEDWINDOW | win32.WS_VISIBLE,
        100, // CW_USEDEFAULT
        100, // CW_USEDEFAULT
        win_width,
        win_height,
        null,
        null,
        hInstance,
        null,
    );

    if (hwnd == null) return error.WindowCreateFailed;

    return @ptrCast(hwnd);
}

const input = @import("input.zig");

// Helper to set user pointer
pub fn setUserPointer(handle: Handle, ptr: *anyopaque) void {
    if (builtin.os.tag == .windows) {
        _ = win32.SetWindowLongPtrA(@ptrCast(@alignCast(handle)), win32.GWLP_USERDATA, @intCast(@intFromPtr(ptr)));
    }
}

fn wndProc(hwnd: win32.HWND, msg: u32, wParam: usize, lParam: isize) callconv(win32.WINAPI) isize {
    // helpers
    const get_state = struct {
        fn call(h: win32.HWND) ?*input.State {
            const ptr = win32.GetWindowLongPtrA(h, win32.GWLP_USERDATA);
            if (ptr != 0) {
                return @ptrFromInt(@as(usize, @intCast(ptr)));
            }
            return null;
        }
    }.call;

    switch (msg) {
        win32.WM_DESTROY, win32.WM_CLOSE => {
            should_close = true;
            return 0;
        },
        win32.WM_KEYDOWN, win32.WM_KEYUP => {
            if (get_state(hwnd)) |state| {
                const pressed = (msg == win32.WM_KEYDOWN);
                // Simple mapping for now, assuming ASCII for letters
                // A real implementation would map virtual keys to input.Key
                const key_code: u32 = @intCast(wParam);
                const key: input.Key = switch (key_code) {
                    0x41...0x5A => @enumFromInt(key_code), // A-Z
                    0x30...0x39 => @enumFromInt(key_code), // 0-9
                    0x1B => .escape,
                    else => .unknown,
                };
                if (key != .unknown) {
                    if (pressed) state.onKeyDown(key) else state.onKeyUp(key);
                }
            }
            return 0;
        },
        win32.WM_LBUTTONDOWN, win32.WM_LBUTTONUP => {
            if (get_state(hwnd)) |state| {
                state.onMouseButton(.left, msg == win32.WM_LBUTTONDOWN);
            }
            return 0;
        },
        win32.WM_MOUSEMOVE => {
            if (get_state(hwnd)) |state| {
                const x: i32 = @intCast(lParam & 0xFFFF);
                const y: i32 = @intCast((lParam >> 16) & 0xFFFF);
                state.onMouseMove(x, y);
            }
            return 0;
        },
        else => return win32.DefWindowProcA(hwnd, msg, wParam, lParam),
    }
}
