//! Nyon Editor - Visual Game Editor

const std = @import("std");
const nyon = @import("nyon_game");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.log.info("Nyon Editor v{s}", .{nyon.VERSION.string});

    var engine = try nyon.Engine.init(allocator, .{
        .window_width = 1600,
        .window_height = 900,
        .window_title = "Nyon Editor",
        .enable_debug = true,
    });
    defer engine.deinit();

    // Editor state
    var editor = Editor.init(allocator, &engine);
    defer editor.deinit();

    // Run editor loop
    engine.run(struct {
        fn update(eng: *nyon.Engine) void {
            _ = eng;
            // Editor update
        }
    }.update);
}

const Editor = struct {
    allocator: std.mem.Allocator,
    engine: *nyon.Engine,
    selected_entity: ?nyon.Entity,
    show_hierarchy: bool,
    show_inspector: bool,
    show_assets: bool,
    show_console: bool,

    pub fn init(allocator: std.mem.Allocator, engine: *nyon.Engine) Editor {
        return .{
            .allocator = allocator,
            .engine = engine,
            .selected_entity = null,
            .show_hierarchy = true,
            .show_inspector = true,
            .show_assets = true,
            .show_console = true,
        };
    }

    pub fn deinit(self: *Editor) void {
        _ = self;
    }

    pub fn update(self: *Editor) void {
        self.drawHierarchy();
        self.drawInspector();
        self.drawViewport();
    }

    fn drawHierarchy(self: *Editor) void {
        const ui_ctx = &self.engine.ui_context;
        const x: i32 = 0;
        const y: i32 = 0;
        const w: i32 = 300;
        const h: i32 = @intCast(self.engine.config.window_height);
        _ = h; // autofix

        ui_ctx.label(x + 10, y + 10, "Hierarchy");

        // Simple list of entities
        var entity_query = nyon.ecs.Query(&[_]type{nyon.ecs.Name}).init(&self.engine.world);
        var iter = entity_query.iter();
        var i: i32 = 0;
        while (iter.next()) |res| {
            var res_copy = res;
            const name = res_copy.get(nyon.ecs.Name).get();
            const id = res_copy.entity.hash();

            if (ui_ctx.button(id, x + 10, y + 40 + i * 30, w - 20, 25, name)) {
                self.selected_entity = res_copy.entity;
            }
            i += 1;
        }
    }

    fn drawInspector(self: *Editor) void {
        const entity = self.selected_entity orelse return;
        const ui_ctx = &self.engine.ui_context;
        const x: i32 = @intCast(self.engine.config.window_width - 300);
        const y: i32 = 0;
        const w: i32 = 300;
        const h: i32 = @intCast(self.engine.config.window_height);
        _ = h;

        ui_ctx.label(x + 10, y + 10, "Inspector");

        if (self.engine.world.getComponent(entity, nyon.ecs.Transform)) |transform| {
            ui_ctx.label(x + 10, y + 40, "Transform");
            // Mock sliders for position
            transform.position.data[0] = ui_ctx.slider(entity.hash() + 1, x + 10, y + 60, w - 20, 20, transform.position.x(), -10, 10);
            transform.position.data[1] = ui_ctx.slider(entity.hash() + 2, x + 10, y + 90, w - 20, 20, transform.position.y(), -10, 10);
            transform.position.data[2] = ui_ctx.slider(entity.hash() + 3, x + 10, y + 120, w - 20, 20, transform.position.z(), -10, 10);
        }
    }

    fn drawAssets(self: *Editor) void {
        _ = self;
    }

    fn drawConsole(self: *Editor) void {
        _ = self;
    }

    fn drawViewport(self: *Editor) void {
        _ = self;
    }
};
