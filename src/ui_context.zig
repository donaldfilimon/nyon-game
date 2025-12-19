const std = @import("std");
const ui = @import("ui/ui.zig");
const editor_tabs = @import("editor_tabs.zig");

pub const UiContext = struct {
    base_context: ui.UiContext,
    active_tab_context: ?editor_tabs.TabType = null,

    pub fn init() UiContext {
        return .{
            .base_context = ui.UiContext{},
        };
    }
};
