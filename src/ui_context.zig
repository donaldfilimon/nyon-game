const std = @import("std");

const editor_tabs = @import("editor_tabs.zig");
const ui = @import("ui/ui.zig");

pub const UiContext = struct {
    base_context: ui.UiContext,
    active_tab_context: ?editor_tabs.TabType = null,

    pub fn init() UiContext {
        return .{
            .base_context = .{ .style = ui.UiStyle.fromTheme(.dark, 180, 1.0) },
        };
    }
};
