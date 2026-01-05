const std = @import("std");
const nyon_game = @import("nyon_game");
const engine_mod = nyon_game.engine;
const status_msg = nyon_game.status_message;
const common = @import("common/error_handling.zig");
const config = @import("config/constants.zig");

// Direct types from engine modules
const Engine = engine_mod.Engine;
const Audio = engine_mod.Audio;
const Input = engine_mod.Input;
const KeyboardKey = engine_mod.KeyboardKey;

const StatusMessage = status_msg.StatusMessage;
const sandbox_ui_mod = @import("ui/sandbox_ui.zig");
const menus_mod = @import("ui/menus.zig");
const sandbox_mod = @import("game/sandbox.zig");
const worlds_mod = @import("game/worlds.zig");

// Import menu types
const AppMode = menus_mod.AppMode;
const MenuState = menus_mod.MenuState;
const WorldSession = menus_mod.WorldSession;

// Game constants
const WINDOW_WIDTH = config.Rendering.WINDOW_WIDTH;
const WINDOW_HEIGHT = config.Rendering.WINDOW_HEIGHT;
const WINDOW_TITLE = "Nyon Game - 3D Sandbox";
const TARGET_FPS = config.Rendering.TARGET_FPS;

pub const Application = struct {
    allocator: std.mem.Allocator,
    engine: Engine,
    sandbox_state: sandbox_mod.SandboxState,
    status_message: StatusMessage,
    ui_state: sandbox_ui_mod.SandboxUiState,
    menu_state: MenuState,
    app_mode: AppMode,
    world_session: ?WorldSession,
    quit_requested: bool,
    save_error: ?anyerror,

    pub fn init(allocator: std.mem.Allocator) !Application {
        // Initialize engine with raylib backend
        const engine = try Engine.init(allocator, .{
            .backend = .raylib,
            .width = WINDOW_WIDTH,
            .height = WINDOW_HEIGHT,
            .title = WINDOW_TITLE,
            .target_fps = TARGET_FPS,
            .resizable = true,
            .vsync = true,
            .samples = 4,
        });

        const sandbox_state = sandbox_mod.SandboxState.init(allocator);

        var status_message = StatusMessage{};
        status_message.set("Welcome to the sandbox!", 3.0);

        const ui_state = sandbox_ui_mod.SandboxUiState.initWithDefaultScale(allocator, sandbox_ui_mod.defaultUiScaleFromDpi());
        const menu_state = MenuState.init(allocator);

        return .{
            .allocator = allocator,
            .engine = engine,
            .sandbox_state = sandbox_state,
            .status_message = status_message,
            .ui_state = ui_state,
            .menu_state = menu_state,
            .app_mode = .title,
            .world_session = null,
            .quit_requested = false,
            .save_error = null,
        };
    }

    pub fn deinit(self: *Application) void {
        var errors = std.ArrayList(u8).initCapacity(self.allocator, 0) catch return;
        defer errors.deinit(self.allocator);

        if (self.ui_state.dirty) {
            if (self.ui_state.config.save(self.allocator, nyon_game.ui.UiConfig.DEFAULT_PATH)) |_| {
                self.ui_state.dirty = false;
            } else |err| {
                std.log.err("Failed to save UI config: {}", .{err});
                errors.appendSlice(self.allocator, "UI config save failed. ") catch {};
            }
        }

        if (self.world_session) |session| {
            if (self.sandbox_state.saveWorld(session.folder)) |_| {
                if (worlds_mod.touchWorld(self.allocator, session.folder, null, null)) |_| {} else |err| {
                    std.log.err("Failed to touch world metadata: {}", .{err});
                    errors.appendSlice(self.allocator, "World metadata update failed. ") catch {};
                }
            } else |err| {
                std.log.err("Failed to save world: {}", .{err});
                errors.appendSlice(self.allocator, "World save failed. ") catch {};
            }
        }

        clearWorldSession(&self.world_session);
        self.menu_state.deinit();
        self.ui_state.deinit();
        self.sandbox_state.deinit();
        self.engine.deinit();

        if (errors.items.len > 0) {
            std.log.err("Save errors occurred: {s}", .{errors.items});
        }
    }

    pub fn run(self: *Application) !void {
        while (!self.engine.shouldClose() and !self.quit_requested) {
            // Reset frame arena for temporary allocations
            // Note: In real implementation, use arena allocator

            self.engine.pollEvents();
            const window_size = self.engine.getWindowSize();
            const screen_width = common.Cast.toFloat(f32, window_size.width);
            const screen_height = common.Cast.toFloat(f32, window_size.height);

            const ctrl_down = Input.Keyboard.isDown(KeyboardKey.left_control) or Input.Keyboard.isDown(KeyboardKey.right_control);

            const ui_input = nyon_game.ui.FrameInput{
                .mouse_pos = Input.Mouse.getPosition(),
                .mouse_pressed = Input.Mouse.isButtonPressed(nyon_game.engine.MouseButton.left),
                .mouse_down = Input.Mouse.isButtonDown(nyon_game.engine.MouseButton.left),
                .mouse_released = Input.Mouse.isButtonReleased(nyon_game.engine.MouseButton.left),
            };

            self.engine.beginDrawing();

            // Update game time
            const delta_time = try self.engine.getFrameTime();
            self.status_message.update(delta_time);

            // Clear background
            self.engine.clearBackground(sandbox_mod.COLOR_BACKGROUND);

            try self.updateAndDraw(delta_time, screen_width, screen_height, ctrl_down, ui_input);

            self.engine.endDrawing();
        }
    }

    fn updateAndDraw(self: *Application, delta_time: f32, screen_width: f32, screen_height: f32, ctrl_down: bool, ui_input: nyon_game.ui.FrameInput) !void {
        switch (self.app_mode) {
            .title => {
                self.menu_state.ctx.beginFrame(ui_input, self.ui_state.style());
                defer self.menu_state.ctx.endFrame();

                const action = menus_mod.drawTitleMenu(&self.menu_state, self.ui_state.style(), &self.status_message, screen_width, screen_height);
                sandbox_ui_mod.drawStatusMessage(&self.status_message, screen_width);
                if (action == .singleplayer) {
                    self.app_mode = .worlds;
                } else if (action == .continue_last) {
                    if (worlds_mod.getMostRecentWorld(self.allocator)) |entry| {
                        setWorldSession(&self.world_session, WorldSession{
                            .allocator = self.allocator,
                            .folder = try self.allocator.dupe(u8, entry.folder),
                            .name = try self.allocator.dupe(u8, entry.meta.name),
                        });
                        self.sandbox_state.clearWorld();
                        self.sandbox_state.loadWorld(entry.folder) catch {
                            self.status_message.set("Failed to load world data", 3.0);
                        };
                        self.status_message.set("Resuming world...", 3.0);
                        self.app_mode = .playing;
                    } else {
                        self.status_message.set("No saved worlds found", 3.0);
                    }
                } else if (action == .multiplayer) {
                    self.app_mode = .server_browser;
                } else if (action == .quit) {
                    self.quit_requested = true;
                }
            },
            .worlds => {
                if (Input.Keyboard.isPressed(KeyboardKey.escape)) {
                    self.app_mode = .title;
                }

                self.menu_state.ctx.beginFrame(ui_input, self.ui_state.style());
                defer self.menu_state.ctx.endFrame();

                const action = menus_mod.drawWorldListMenu(&self.menu_state, self.ui_state.style(), &self.status_message, screen_width, screen_height);
                sandbox_ui_mod.drawStatusMessage(&self.status_message, screen_width);

                if (action == .back) {
                    self.app_mode = .title;
                } else if (action == .create_world) {
                    self.app_mode = .create_world;
                } else if (action == .play_selected) {
                    if (self.menu_state.selected_world) |idx| {
                        const entry = self.menu_state.worlds[idx];
                        setWorldSession(&self.world_session, WorldSession{
                            .allocator = self.allocator,
                            .folder = try self.allocator.dupe(u8, entry.folder),
                            .name = try self.allocator.dupe(u8, entry.meta.name),
                        });
                        self.sandbox_state.clearWorld();
                        self.sandbox_state.loadWorld(entry.folder) catch {
                            self.status_message.set("Failed to load world data", 3.0);
                        };
                        self.status_message.set("World loaded!", 3.0);
                        self.app_mode = .playing;
                    }
                }
            },
            .create_world => {
                if (Input.Keyboard.isPressed(KeyboardKey.escape)) {
                    self.app_mode = .worlds;
                }

                self.menu_state.ctx.beginFrame(ui_input, self.ui_state.style());
                defer self.menu_state.ctx.endFrame();

                const result = menus_mod.drawCreateWorldMenu(&self.menu_state, self.ui_state.style(), &self.status_message, screen_width, screen_height);
                sandbox_ui_mod.drawStatusMessage(&self.status_message, screen_width);
                switch (result) {
                    .none => {},
                    .back => self.app_mode = .worlds,
                    .created => |session| {
                        setWorldSession(&self.world_session, session);
                        self.sandbox_state.clearWorld();
                        if (self.world_session) |world| {
                            self.sandbox_state.saveWorld(world.folder) catch {
                                self.status_message.set("Failed to create world data", 3.0);
                            };
                        }
                        self.status_message.set("Entering new world...", 3.0);
                        self.app_mode = .playing;
                    },
                }
            },
            .server_browser => {
                if (Input.Keyboard.isPressed(KeyboardKey.escape)) {
                    self.app_mode = .title;
                }

                self.menu_state.ctx.beginFrame(ui_input, self.ui_state.style());
                defer self.menu_state.ctx.endFrame();

                const action = menus_mod.drawServerBrowser(&self.menu_state, self.ui_state.style(), &self.status_message, screen_width, screen_height);
                sandbox_ui_mod.drawStatusMessage(&self.status_message, screen_width);

                if (action == .back) {
                    self.app_mode = .title;
                } else if (action == .connect) {
                    self.status_message.set("Server connection not yet implemented", 3.0);
                }
            },
            .playing, .paused => {
                self.ui_state.ctx.beginFrame(ui_input, self.ui_state.style());
                defer self.ui_state.ctx.endFrame();

                if (self.app_mode == .playing) {
                    if (Input.Keyboard.isPressed(KeyboardKey.escape)) {
                        self.app_mode = .paused;
                    }

                    if (Input.Keyboard.isPressed(KeyboardKey.f1)) {
                        self.ui_state.edit_mode = !self.ui_state.edit_mode;
                        self.status_message.set(if (self.ui_state.edit_mode) "UI edit mode enabled" else "UI edit mode disabled", 3.0);
                    }

                    if (Input.Keyboard.isPressed(KeyboardKey.f2)) {
                        self.ui_state.config.settings.visible = !self.ui_state.config.settings.visible;
                        self.ui_state.dirty = true;
                        self.status_message.set(if (self.ui_state.config.settings.visible) "Settings opened" else "Settings hidden", 3.0);
                    }

                    if (ctrl_down and Input.Keyboard.isPressed(KeyboardKey.s)) {
                        if (self.ui_state.edit_mode) {
                            self.ui_state.config.save(self.allocator, nyon_game.ui.UiConfig.DEFAULT_PATH) catch {
                                self.status_message.set("Failed to save UI layout", 3.0);
                            };
                            self.ui_state.dirty = false;
                            self.status_message.set("Saved UI layout", 3.0);
                        } else if (self.world_session) |session| {
                            self.sandbox_state.saveWorld(session.folder) catch {
                                self.status_message.set("Failed to save world data", 3.0);
                            };
                            self.status_message.set("World saved", 3.0);
                        }
                    }

                    if (ctrl_down and Input.Keyboard.isPressed(KeyboardKey.r)) {
                        self.ui_state.config = nyon_game.ui.UiConfig{};
                        self.ui_state.dirty = true;
                        self.status_message.set("Reset UI layout", 3.0);
                    }
                } else {
                    if (Input.Keyboard.isPressed(KeyboardKey.escape)) {
                        self.app_mode = .playing;
                    }
                }

                const ui_capture = self.ui_state.edit_mode or (ui_input.mouse_down and isMouseOverPanels(&self.ui_state, ui_input.mouse_pos));
                const allow_input = self.app_mode == .playing and !ui_capture;
                const action = self.sandbox_state.update(delta_time, allow_input, screen_width, screen_height);
                if (self.app_mode == .playing) {
                    switch (action) {
                        .none => {},
                        .placed => |pos| {
                            var msg_buf: [96:0]u8 = undefined;
                            const msg = try std.fmt.bufPrintZ(&msg_buf, "Placed block at {d} {d} {d}", .{ pos.x, pos.y, pos.z });
                            self.status_message.set(msg, 2.0);
                        },
                        .removed => |pos| {
                            var msg_buf: [96:0]u8 = undefined;
                            const msg = try std.fmt.bufPrintZ(&msg_buf, "Removed block at {d} {d} {d}", .{ pos.x, pos.y, pos.z });
                            self.status_message.set(msg, 2.0);
                        },
                        .color_changed => |_| {
                            const color = self.sandbox_state.activeColor();
                            var msg_buf: [64:0]u8 = undefined;
                            const msg = try std.fmt.bufPrintZ(&msg_buf, "Block color: {s}", .{color.name});
                            self.status_message.set(msg, 2.0);
                        },
                    }
                }

                self.sandbox_state.drawWorld();

                if (self.app_mode == .playing and !self.ui_state.edit_mode and self.sandbox_state.mouse_look) {
                    sandbox_ui_mod.drawCrosshair(screen_width, screen_height);
                }

                const world_name = if (self.world_session) |session| session.name else null;
                try sandbox_ui_mod.drawUI(&self.sandbox_state, world_name, &self.ui_state, &self.status_message, self.allocator, screen_width, screen_height);
                sandbox_ui_mod.drawStatusMessage(&self.status_message, screen_width);
                sandbox_ui_mod.drawInstructions(screen_width, screen_height);

                if (self.app_mode == .paused) {
                    self.menu_state.ctx.beginFrame(ui_input, self.ui_state.style());
                    defer self.menu_state.ctx.endFrame();

                    const pause_action = menus_mod.drawPauseMenu(&self.menu_state, self.ui_state.style(), &self.status_message, screen_width, screen_height);
                    if (pause_action == .unpause) {
                        self.app_mode = .playing;
                    } else if (pause_action == .quit_to_title) {
                        if (self.world_session) |session| {
                            self.sandbox_state.saveWorld(session.folder) catch {};
                            worlds_mod.touchWorld(self.allocator, session.folder, null, null) catch {};
                        }
                        clearWorldSession(&self.world_session);
                        self.app_mode = .title;
                    }
                }
            },
        }
    }
};

fn pointInRect(point: engine_mod.Vector2, rect: engine_mod.Rectangle) bool {
    return point.x >= rect.x and point.y >= rect.y and point.x <= rect.x + rect.width and point.y <= rect.y + rect.height;
}

fn isMouseOverPanels(ui_state: *sandbox_ui_mod.SandboxUiState, point: engine_mod.Vector2) bool {
    if (ui_state.config.hud.visible and pointInRect(point, ui_state.config.hud.rect)) return true;
    if (ui_state.config.settings.visible and pointInRect(point, ui_state.config.settings.rect)) return true;
    return false;
}

fn clearWorldSession(session: *?WorldSession) void {
    if (session.*) |*active| {
        active.deinit();
        session.* = null;
    }
}

fn setWorldSession(session: *?WorldSession, value: WorldSession) void {
    clearWorldSession(session);
    session.* = value;
}
