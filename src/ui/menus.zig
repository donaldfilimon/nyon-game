const std = @import("std");
const nyon_game = @import("../root.zig");
const ui_mod = nyon_game.ui;
const StatusMessage = nyon_game.status_message.StatusMessage;
const worlds_mod = nyon_game.worlds;
const FontManager = nyon_game.font_manager.FontManager;

pub const AppMode = enum {
    title,
    worlds,
    create_world,
    server_browser,
    playing,
    paused,
};

const TitleMenuAction = enum {
    none,
    singleplayer,
    multiplayer,

    quit,
};

const WorldMenuAction = enum {
    none,
    play_selected,
    create_world,
    back,
};

const PauseMenuAction = enum {
    none,
    unpause,
    quit_to_title,
};

const NameInput = struct {
    buffer: [32]u8 = [_]u8{0} ** 32,
    len: usize = 0,

    pub fn clear(self: *NameInput) void {
        self.len = 0;
        self.buffer[0] = 0;
    }

    pub fn asSlice(self: *const NameInput) []const u8 {
        return self.buffer[0..self.len];
    }

    pub fn pushAscii(self: *NameInput, c: u8) void {
        if (self.len + 1 >= self.buffer.len) return;
        self.buffer[self.len] = c;
        self.len += 1;
        self.buffer[self.len] = 0;
    }

    pub fn pop(self: *NameInput) void {
        if (self.len == 0) return;
        self.len -= 1;
        self.buffer[self.len] = 0;
    }
};

pub const MenuState = struct {
    allocator: std.mem.Allocator,
    ctx: ui_mod.UiContext = ui_mod.UiContext{ .style = ui_mod.UiStyle.fromTheme(.dark, 180, 1.0) },
    worlds: []worlds_mod.WorldEntry = &.{},
    selected_world: ?usize = null,
    create_name: NameInput = NameInput{},

    pub fn init(allocator: std.mem.Allocator) MenuState {
        return .{
            .allocator = allocator,
            .ctx = .{ .style = ui_mod.UiStyle.fromTheme(.dark, 180, 1.0) },
        };
    }

    pub fn deinit(self: *MenuState) void {
        self.freeWorlds();
    }

    pub fn refreshWorlds(self: *MenuState) void {
        self.freeWorlds();
        self.worlds = worlds_mod.listWorlds(self.allocator) catch &.{};
        self.selected_world = if (self.worlds.len > 0) 0 else null;
    }

    fn freeWorlds(self: *MenuState) void {
        for (self.worlds) |*entry| entry.deinit();
        if (self.worlds.len > 0) self.allocator.free(self.worlds);
        self.worlds = &.{};
        self.selected_world = null;
    }
};

const ServerBrowserAction = enum {
    none,
    back,
    connect,
};

const CreateWorldResult = union(enum) {
    none,
    back,
    created: WorldSession,
};

pub const WorldSession = struct {
    allocator: std.mem.Allocator,
    folder: []u8,
    name: []u8,

    pub fn deinit(self: *WorldSession) void {
        self.allocator.free(self.folder);
        self.allocator.free(self.name);
        self.* = undefined;
    }
};

pub fn drawTitleMenu(menu: *MenuState, ui_style: ui_mod.UiStyle, status_message: *StatusMessage, screen_width: f32, screen_height: f32) TitleMenuAction {
    const title = "NYON";
    const subtitle = "A Zig + raylib sandbox";

    const title_size: i32 = @intFromFloat(std.math.round(64.0 * ui_style.scale));
    const subtitle_size: i32 = ui_style.small_font_size;

    const title_w = nyon_game.engine.Text.measure(title, title_size);
    const title_x: i32 = @intFromFloat((screen_width - @as(f32, @floatFromInt(title_w))) / 2.0);
    nyon_game.engine.Text.draw(title, title_x, @intFromFloat(screen_height * 0.12), title_size, ui_style.text);

    const sub_w = nyon_game.engine.Text.measure(subtitle, subtitle_size);
    const sub_x: i32 = @intFromFloat((screen_width - @as(f32, @floatFromInt(sub_w))) / 2.0);
    nyon_game.engine.Text.draw(subtitle, sub_x, @as(i32, @intFromFloat(screen_height * 0.12)) + title_size + 8, subtitle_size, ui_style.text_muted);

    const button_w: f32 = 340.0 * ui_style.scale;
    const button_h: f32 = 46.0 * ui_style.scale;
    const start_y: f32 = screen_height * 0.42;
    const x: f32 = (screen_width - button_w) / 2.0;

    const single_id = std.hash.Wyhash.hash(0, "menu_singleplayer");
    if (menu.ctx.button(single_id, nyon_game.engine.Rectangle{ .x = x, .y = start_y, .width = button_w, .height = button_h }, "Singleplayer")) {
        menu.refreshWorlds();
        status_message.set("Select a world", 3.0);
        return .singleplayer;
    }

    const multiplayer_id = std.hash.Wyhash.hash(0, "menu_multiplayer");
    if (menu.ctx.button(multiplayer_id, nyon_game.engine.Rectangle{ .x = x, .y = start_y + button_h + 12, .width = button_w, .height = button_h }, "Multiplayer")) {
        return .multiplayer;
    }

    const options_id = std.hash.Wyhash.hash(0, "menu_options");
    if (menu.ctx.button(options_id, nyon_game.engine.Rectangle{ .x = x, .y = start_y + (button_h + 12) * 2, .width = button_w, .height = button_h }, "Options")) {
        status_message.set("Use in-game Settings panel for now (F2)", 4.5);
        return .none;
    }

    const quit_id = std.hash.Wyhash.hash(0, "menu_quit");
    if (menu.ctx.button(quit_id, nyon_game.engine.Rectangle{ .x = x, .y = start_y + (button_h + 12) * 3, .width = button_w, .height = button_h }, "Quit")) {
        return .quit;
    }

    return .none;
}

pub fn drawWorldListMenu(menu: *MenuState, ui_style: ui_mod.UiStyle, status_message: *StatusMessage, screen_width: f32, screen_height: f32) WorldMenuAction {
    const header = "Select World";
    const header_w = nyon_game.engine.Text.measure(header, ui_style.font_size);
    nyon_game.engine.Text.draw(header, @intFromFloat((screen_width - @as(f32, @floatFromInt(header_w))) / 2.0), @intFromFloat(24.0 * ui_style.scale), ui_style.font_size, ui_style.text);

    const list_w: f32 = 620.0 * ui_style.scale;
    const row_h: f32 = 44.0 * ui_style.scale;
    const list_x: f32 = (screen_width - list_w) / 2.0;
    const list_y: f32 = 90.0 * ui_style.scale;
    const max_rows: usize = @intFromFloat(@max(1.0, (screen_height - list_y - 180.0 * ui_style.scale) / (row_h + 10.0)));

    const start_index: usize = 0;
    const end_index: usize = @min(menu.worlds.len, start_index + max_rows);

    var selected: ?usize = null;
    for (start_index..end_index) |i| {
        const entry = menu.worlds[i];
        var name_buf: [80:0]u8 = undefined;
        const label = std.fmt.bufPrintZ(&name_buf, "{s}", .{entry.meta.name}) catch "World";
        const y = list_y + @as(f32, @floatFromInt(i - start_index)) * (row_h + 10.0);
        const id = std.hash.Wyhash.hash(0, entry.folder);
        const clicked = menu.ctx.button(id, nyon_game.engine.Rectangle{ .x = list_x, .y = y, .width = list_w, .height = row_h }, label);
        if (clicked) {
            menu.selected_world = i;
            selected = i;
        }
    }

    if (menu.worlds.len == 0) {
        nyon_game.engine.Text.draw("No worlds found.", @intFromFloat(list_x), @intFromFloat(list_y), ui_style.small_font_size, ui_style.text_muted);
        nyon_game.engine.Text.draw("Create a new world to begin.", @intFromFloat(list_x), @intFromFloat(list_y + 22.0 * ui_style.scale), ui_style.small_font_size, ui_style.text_muted);
    }

    const button_w: f32 = 300.0 * ui_style.scale;
    const button_h: f32 = 44.0 * ui_style.scale;
    const button_y: f32 = screen_height - 120.0 * ui_style.scale;
    const left_x: f32 = (screen_width - (button_w * 2.0 + 20.0 * ui_style.scale)) / 2.0;

    const create_id = std.hash.Wyhash.hash(0, "world_create");
    if (menu.ctx.button(create_id, nyon_game.engine.Rectangle{ .x = left_x, .y = button_y, .width = button_w, .height = button_h }, "Create New World")) {
        menu.create_name.clear();
        status_message.set("Type a name and press Enter", 4.5);
        menu.selected_world = null;
        return .create_world;
    }

    const back_id = std.hash.Wyhash.hash(0, "world_back");
    if (menu.ctx.button(back_id, nyon_game.engine.Rectangle{ .x = left_x + button_w + 20.0 * ui_style.scale, .y = button_y, .width = button_w, .height = button_h }, "Back")) {
        return .back;
    }

    if (selected != null) {
        status_message.set("Press Play to start", 3.0);
    }

    const play_id = std.hash.Wyhash.hash(0, "world_play");
    const play_y: f32 = button_y - (button_h + 12.0 * ui_style.scale);
    const play_x: f32 = (screen_width - button_w) / 2.0;
    const can_play = menu.selected_world != null and menu.selected_world.? < menu.worlds.len;
    const play_label: [:0]const u8 = if (can_play) "Play Selected World" else "Select a World";
    if (menu.ctx.button(play_id, nyon_game.engine.Rectangle{ .x = play_x, .y = play_y, .width = button_w, .height = button_h }, play_label) and can_play) {
        return .play_selected;
    }

    return .none;
}

pub fn drawServerBrowser(menu: *MenuState, ui_style: ui_mod.UiStyle, status_message: *StatusMessage, screen_width: f32, screen_height: f32) ServerBrowserAction {
    const header = "Server Browser";
    const header_w = nyon_game.engine.Text.measure(header, ui_style.font_size);
    nyon_game.engine.Text.draw(header, @intFromFloat((screen_width - @as(f32, @floatFromInt(header_w))) / 2.0), @intFromFloat(24.0 * ui_style.scale), ui_style.font_size, ui_style.text);

    const list_w: f32 = 620.0 * ui_style.scale;
    const row_h: f32 = 44.0 * ui_style.scale;
    const list_x: f32 = (screen_width - list_w) / 2.0;
    const list_y: f32 = 90.0 * ui_style.scale;

    // Placeholder server list (in a real implementation, this would be fetched from a server)
    const servers = [_][]const u8{
        "localhost:1234 - Local Development Server",
        "game.example.com:5678 - Public Server 1",
        "multiplayer.demo.net:9999 - Demo Server",
    };

    var selected: ?usize = null;
    for (servers, 0..) |server, i| {
        const y = list_y + @as(f32, @floatFromInt(i)) * (row_h + 10.0);
        const id = std.hash.Wyhash.hash(0, std.fmt.allocPrint(menu.allocator, "server_{d}", .{i}) catch "server");
        // Convert server name to null-terminated string for button label
        var server_buf: [128:0]u8 = undefined;
        const server_label = std.fmt.bufPrintZ(&server_buf, "{s}", .{server}) catch "Server";
        const clicked = menu.ctx.button(id, nyon_game.engine.Rectangle{ .x = list_x, .y = y, .width = list_w, .height = row_h }, server_label);
        if (clicked) {
            selected = i;
        }
    }

    const button_w: f32 = 300.0 * ui_style.scale;
    const button_h: f32 = 44.0 * ui_style.scale;
    const button_y: f32 = screen_height - 120.0 * ui_style.scale;
    const left_x: f32 = (screen_width - (button_w * 2.0 + 20.0 * ui_style.scale)) / 2.0;

    const connect_id = std.hash.Wyhash.hash(0, "server_connect");
    if (menu.ctx.button(connect_id, nyon_game.engine.Rectangle{ .x = left_x, .y = button_y, .width = button_w, .height = button_h }, "Connect to Selected") and selected != null) {
        return .connect;
    }

    const back_id = std.hash.Wyhash.hash(0, "server_back");
    if (menu.ctx.button(back_id, nyon_game.engine.Rectangle{ .x = left_x + button_w + 20.0 * ui_style.scale, .y = button_y, .width = button_w, .height = button_h }, "Back")) {
        return .back;
    }

    if (selected != null) {
        status_message.set("Click Connect to join server", 3.0);
    }

    return .none;
}

fn updateNameInput(input: *NameInput) void {
    var c: i32 = nyon_game.engine.Input.Keyboard.getCharPressed();
    while (c != 0) : (c = nyon_game.engine.Input.Keyboard.getCharPressed()) {
        if (c >= 32 and c <= 126) {
            input.pushAscii(@intCast(c));
        }
    }

    if (nyon_game.engine.Input.Keyboard.isPressed(nyon_game.engine.KeyboardKey.backspace)) {
        input.pop();
    }
}

pub fn drawCreateWorldMenu(menu: *MenuState, ui_style: ui_mod.UiStyle, status_message: *StatusMessage, screen_width: f32, screen_height: f32) CreateWorldResult {
    const header = "Create New World";
    const header_w = nyon_game.engine.Text.measure(header, ui_style.font_size);
    nyon_game.engine.Text.draw(header, @intFromFloat((screen_width - @as(f32, @floatFromInt(header_w))) / 2.0), @intFromFloat(24.0 * ui_style.scale), ui_style.font_size, ui_style.text);

    updateNameInput(&menu.create_name);

    const field_w: f32 = 620.0 * ui_style.scale;
    const field_h: f32 = 54.0 * ui_style.scale;
    const field_x: f32 = (screen_width - field_w) / 2.0;
    const field_y: f32 = screen_height * 0.32;

    nyon_game.engine.Shapes.drawRectangleRec(nyon_game.engine.Rectangle{ .x = field_x, .y = field_y, .width = field_w, .height = field_h }, ui_style.panel_bg);
    nyon_game.engine.Shapes.drawRectangleLinesEx(nyon_game.engine.Rectangle{ .x = field_x, .y = field_y, .width = field_w, .height = field_h }, ui_style.border_width, ui_style.panel_border);

    var text_buf: [64:0]u8 = undefined;
    const name = menu.create_name.asSlice();
    const display = if (name.len == 0) "World name..." else std.fmt.bufPrintZ(&text_buf, "{s}", .{name}) catch "World";
    nyon_game.engine.Text.draw(display, @intFromFloat(field_x + 14.0 * ui_style.scale), @intFromFloat(field_y + 16.0 * ui_style.scale), ui_style.font_size, if (name.len == 0) ui_style.text_muted else ui_style.text);

    if (nyon_game.engine.Input.Keyboard.isPressed(nyon_game.engine.KeyboardKey.enter)) {
        const world = worlds_mod.createWorld(menu.allocator, name) catch {
            status_message.set("Invalid world name", 3.0);
            return .none;
        };

        const session = WorldSession{
            .allocator = menu.allocator,
            .folder = menu.allocator.dupe(u8, world.folder) catch unreachable,
            .name = menu.allocator.dupe(u8, world.meta.name) catch unreachable,
        };
        // world owns its buffers; free it now.
        var tmp = world;
        tmp.deinit();

        status_message.set("World created!", 3.0);
        return .{ .created = session };
    }

    const button_w: f32 = 300.0 * ui_style.scale;
    const button_h: f32 = 44.0 * ui_style.scale;
    const button_y: f32 = screen_height - 120.0 * ui_style.scale;
    const left_x: f32 = (screen_width - (button_w * 2.0 + 20.0 * ui_style.scale)) / 2.0;

    const create_id = std.hash.Wyhash.hash(0, "create_confirm");
    if (menu.ctx.button(create_id, nyon_game.engine.Rectangle{ .x = left_x, .y = button_y, .width = button_w, .height = button_h }, "Create")) {
        if (name.len == 0) {
            status_message.set("Enter a world name", 3.0);
            return .none;
        }
        const world = worlds_mod.createWorld(menu.allocator, name) catch {
            status_message.set("Invalid world name", 3.0);
            return .none;
        };

        const session = WorldSession{
            .allocator = menu.allocator,
            .folder = menu.allocator.dupe(u8, world.folder) catch unreachable,
            .name = menu.allocator.dupe(u8, world.meta.name) catch unreachable,
        };
        var tmp = world;
        tmp.deinit();

        status_message.set("World created!", 3.0);
        return .{ .created = session };
    }

    const back_id = std.hash.Wyhash.hash(0, "create_back");
    if (menu.ctx.button(back_id, nyon_game.engine.Rectangle{ .x = left_x + button_w + 20.0 * ui_style.scale, .y = button_y, .width = button_w, .height = button_h }, "Back")) {
        return .back;
    }

    nyon_game.engine.Text.draw("Press Enter to create.", @intFromFloat(field_x), @intFromFloat(field_y + field_h + 10.0 * ui_style.scale), ui_style.small_font_size, ui_style.text_muted);
    return .none;
}

pub fn drawPauseMenu(menu: *MenuState, ui_style: ui_mod.UiStyle, status_message: *StatusMessage, screen_width: f32, screen_height: f32) PauseMenuAction {
    _ = status_message;
    nyon_game.engine.Shapes.drawRectangleRec(nyon_game.engine.Rectangle{ .x = 0, .y = 0, .width = screen_width, .height = screen_height }, nyon_game.engine.Color{ .r = 0, .g = 0, .b = 0, .a = 120 });

    const header = "Paused";
    const header_w = nyon_game.engine.Text.measure(header, ui_style.font_size);
    nyon_game.engine.Text.draw(header, @intFromFloat((screen_width - @as(f32, @floatFromInt(header_w))) / 2.0), @intFromFloat(screen_height * 0.2), ui_style.font_size, ui_style.text);

    const button_w: f32 = 340.0 * ui_style.scale;
    const button_h: f32 = 46.0 * ui_style.scale;
    const start_y: f32 = screen_height * 0.34;
    const x: f32 = (screen_width - button_w) / 2.0;

    const resume_id = std.hash.Wyhash.hash(0, "pause_resume");
    if (menu.ctx.button(resume_id, nyon_game.engine.Rectangle{ .x = x, .y = start_y, .width = button_w, .height = button_h }, "Resume Game")) {
        return .unpause;
    }

    const quit_id = std.hash.Wyhash.hash(0, "pause_quit");
    if (menu.ctx.button(quit_id, nyon_game.engine.Rectangle{ .x = x, .y = start_y + button_h + 12, .width = button_w, .height = button_h }, "Save & Quit to Title")) {
        return .quit_to_title;
    }

    return .none;
}
