const std = @import("std");
const nyon_game = @import("nyon_game");
const engine_mod = nyon_game.engine;
const status_msg = nyon_game.status_message;

// Direct types from engine modules
const Engine = engine_mod.Engine;
const Audio = engine_mod.Audio;
const Input = engine_mod.Input;
const KeyboardKey = engine_mod.KeyboardKey;

const StatusMessage = status_msg.StatusMessage;
const game_ui_mod = @import("ui/game_ui.zig");
const menus_mod = @import("ui/menus.zig");
const game_state_module = @import("game/state.zig");
const game_logic_module = @import("game/game.zig");
const worlds_mod = @import("game/worlds.zig");

// Import menu types
const AppMode = menus_mod.AppMode;
const MenuState = menus_mod.MenuState;
const WorldSession = menus_mod.WorldSession;

// Game constants
const WINDOW_WIDTH: u32 = 800;
const WINDOW_HEIGHT: u32 = 600;
const WINDOW_TITLE = "Nyon Game - Collect Items!";
const TARGET_FPS: u32 = 60;

pub const Application = struct {
    allocator: std.mem.Allocator,
    engine: Engine,
    game_state: game_state_module.GameState,
    status_message: StatusMessage,
    ui_state: game_ui_mod.GameUiState,
    menu_state: MenuState,
    app_mode: AppMode,
    world_session: ?WorldSession,
    quit_requested: bool,

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

        var game_state = game_state_module.GameState{};
        game_state_module.resetGameState(&game_state);

        var status_message = StatusMessage{};
        status_message.set("Collect every item to win!", 3.0);

        const ui_state = game_ui_mod.GameUiState.initWithDefaultScale(allocator, game_ui_mod.defaultUiScaleFromDpi());
        const menu_state = MenuState.init(allocator);

        // Initialize audio device
        Audio.initDevice();

        // Load args if provided
        var args_iter = try std.process.argsWithAllocator(allocator);
        defer args_iter.deinit();
        _ = args_iter.skip(); // skip program name
        if (args_iter.next()) |arg_path| {
            if (arg_path.len > 0) {
                game_logic_module.loadFileMetadata(&game_state, &status_message, arg_path) catch {
                    var err_buf: [128:0]u8 = undefined;
                    const err_msg = std.fmt.bufPrintZ(&err_buf, "Could not open {s}", .{arg_path}) catch "Could not open file";
                    status_message.set(err_msg, 3.0);
                };
            }
        }

        return .{
            .allocator = allocator,
            .engine = engine,
            .game_state = game_state,
            .status_message = status_message,
            .ui_state = ui_state,
            .menu_state = menu_state,
            .app_mode = .title,
            .world_session = null,
            .quit_requested = false,
        };
    }

    pub fn deinit(self: *Application) void {
        // Save UI config if dirty
        if (self.ui_state.dirty) {
            self.ui_state.config.save(self.allocator, nyon_game.ui.UiConfig.DEFAULT_PATH) catch {};
        }

        // Save world session data
        if (self.world_session) |session| {
            const best_time_ms: ?u32 = if (self.game_state.best_time) |t| @intFromFloat(t * 1000.0) else null;
            worlds_mod.touchWorld(self.allocator, session.folder, self.game_state.best_score, best_time_ms) catch {};
        }

        clearWorldSession(&self.world_session);
        self.menu_state.deinit();
        self.ui_state.deinit();
        self.engine.deinit();
        Audio.closeDevice();
    }

    pub fn run(self: *Application) !void {
        while (!self.engine.shouldClose() and !self.quit_requested) {
            // Reset frame arena for temporary allocations
            // Note: In real implementation, use arena allocator

            self.engine.pollEvents();
            const window_size = self.engine.getWindowSize();
            const screen_width = @as(f32, @floatFromInt(window_size.width));
            const screen_height = @as(f32, @floatFromInt(window_size.height));

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
            self.engine.clearBackground(game_ui_mod.COLOR_BACKGROUND);

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
                game_ui_mod.drawStatusMessage(&self.status_message, screen_width);
                if (action == .singleplayer) {
                    self.app_mode = .worlds;
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
                game_ui_mod.drawStatusMessage(&self.status_message, screen_width);

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
                        self.game_state.best_score = entry.meta.best_score;
                        if (entry.meta.best_time_ms) |ms| {
                            self.game_state.best_time = @as(f32, @floatFromInt(ms)) / 1000.0;
                        } else {
                            self.game_state.best_time = null;
                        }
                        game_state_module.resetGameState(&self.game_state);
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
                game_ui_mod.drawStatusMessage(&self.status_message, screen_width);
                switch (result) {
                    .none => {},
                    .back => self.app_mode = .worlds,
                    .created => |session| {
                        setWorldSession(&self.world_session, session);
                        self.game_state.best_score = 0;
                        self.game_state.best_time = null;
                        game_state_module.resetGameState(&self.game_state);
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
                game_ui_mod.drawStatusMessage(&self.status_message, screen_width);

                if (action == .back) {
                    self.app_mode = .title;
                } else if (action == .connect) {
                    // TODO: Implement server connection
                    self.status_message.set("Server connection not yet implemented", 3.0);
                }
            },
            .playing, .paused => {
                self.ui_state.ctx.beginFrame(ui_input, self.ui_state.style());
                defer self.ui_state.ctx.endFrame();

                var player_moved_draw = false;
                var has_won_draw = game_logic_module.isGameWon(&self.game_state);

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
                        self.ui_state.config.save(self.allocator, nyon_game.ui.UiConfig.DEFAULT_PATH) catch {
                            self.status_message.set("Failed to save UI layout", 3.0);
                        };
                        self.ui_state.dirty = false;
                        self.status_message.set("Saved UI layout", 3.0);
                    }

                    if (ctrl_down and Input.Keyboard.isPressed(KeyboardKey.r)) {
                        self.ui_state.config = nyon_game.ui.UiConfig{};
                        self.ui_state.dirty = true;
                        self.status_message.set("Reset UI layout", 3.0);
                    } else if (Input.Keyboard.isPressed(KeyboardKey.r)) {
                        game_state_module.resetGameState(&self.game_state);
                        self.status_message.set("Reset complete! Collect them again!", 3.0);
                    }

                    // TODO: Re-enable file dropping once raylib issues are resolved
                    // handleDroppedFile(&self.game_state, &self.ui_state, &self.status_message, self.allocator, frame_allocator) catch {
                    //     self.status_message.set("Failed to read dropped file", 3.0);
                    // };

                    self.game_state.game_time += delta_time;
                    const player_moved = if (self.ui_state.edit_mode and (ui_input.mouse_down or ctrl_down))
                        false
                    else
                        game_logic_module.handleInput(&self.game_state, delta_time, screen_width, screen_height);
                    player_moved_draw = player_moved;

                    const collected = game_logic_module.checkCollisions(&self.game_state);
                    if (collected > 0 and self.game_state.remaining_items > 0) {
                        var collect_buf: [80:0]u8 = undefined;
                        const collect_str = try std.fmt.bufPrintZ(&collect_buf, "{d} item(s) left", .{self.game_state.remaining_items});
                        self.status_message.set(collect_str, 3.0);
                    }

                    const has_won = game_logic_module.isGameWon(&self.game_state);
                    has_won_draw = has_won;
                    if (has_won and !self.game_state.has_won) {
                        self.game_state.has_won = true;
                        const completion_time = self.game_state.game_time;
                        var win_buf: [128:0]u8 = undefined;
                        if (self.game_state.best_time) |prev_best| {
                            if (completion_time < prev_best) {
                                self.game_state.best_time = completion_time;
                                const win_str = try std.fmt.bufPrintZ(&win_buf, "New personal best! {d:.2}s", .{completion_time});
                                self.status_message.set(win_str, 4.5);
                            } else {
                                const win_str = try std.fmt.bufPrintZ(&win_buf, "You win! {d:.2}s (best {d:.2}s)", .{ completion_time, prev_best });
                                self.status_message.set(win_str, 3.0);
                            }
                        } else {
                            self.game_state.best_time = completion_time;
                            const win_str = try std.fmt.bufPrintZ(&win_buf, "First win in {d:.2}s!", .{completion_time});
                            self.status_message.set(win_str, 4.5);
                        }
                    } else if (!has_won) {
                        self.game_state.has_won = false;
                    }
                } else {
                    if (Input.Keyboard.isPressed(KeyboardKey.escape)) {
                        self.app_mode = .playing;
                    }
                }

                // Draw game elements
                game_logic_module.drawGrid(screen_width, screen_height);
                game_logic_module.drawItems(&self.game_state);
                game_logic_module.drawPlayer(&self.game_state, player_moved_draw);

                // Draw UI
                try game_ui_mod.drawUI(&self.game_state, &self.ui_state, &self.status_message, self.allocator, screen_width, screen_height);
                game_ui_mod.drawStatusMessage(&self.status_message, screen_width);
                game_ui_mod.drawInstructions(screen_width, screen_height);

                if (has_won_draw) {
                    game_ui_mod.drawWinMessage(screen_width, screen_height);
                }

                if (self.app_mode == .paused) {
                    self.menu_state.ctx.beginFrame(ui_input, self.ui_state.style());
                    defer self.menu_state.ctx.endFrame();

                    const action = menus_mod.drawPauseMenu(&self.menu_state, self.ui_state.style(), &self.status_message, screen_width, screen_height);
                    if (action == .unpause) {
                        self.app_mode = .playing;
                    } else if (action == .quit_to_title) {
                        if (self.world_session) |session| {
                            const best_time_ms: ?u32 = if (self.game_state.best_time) |t| @intFromFloat(t * 1000.0) else null;
                            worlds_mod.touchWorld(self.allocator, session.folder, self.game_state.best_score, best_time_ms) catch {};
                        }
                        clearWorldSession(&self.world_session);
                        self.app_mode = .title;
                    }
                }
            },
        }
    }
};

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
