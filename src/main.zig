//! Nyon Game Engine - Sandbox Game Entry Point
//!
//! A first-person sandbox game with block placement and destruction.
//! Controls:
//!   - WASD: Move
//!   - Mouse: Look around
//!   - Left Click: Place block
//!   - Right Click / Ctrl+Click: Remove block
//!   - 1-9: Select block type
//!   - Scroll: Cycle hotbar
//!   - Shift: Sprint / Fast fly
//!   - Ctrl: Crouch / Descend (flight mode)
//!   - Space: Jump / Ascend (flight mode)
//!   - E/Tab: Open inventory
//!   - F3: Toggle debug overlay
//!   - F4: Toggle flight mode
//!   - F5: Quick save
//!   - F6: Pause/resume day/night cycle
//!   - F9: Quick load
//!   - Escape: Close inventory / Quit

const std = @import("std");
const nyon = @import("nyon_game");

/// Integrated game state containing all systems
const IntegratedGame = struct {
    allocator: std.mem.Allocator,
    sandbox: nyon.game.SandboxGame,
    weather: nyon.Weather,
    weather_audio: nyon.WeatherAudio,
    entity_world: nyon.EntityWorld,
    mob_spawner: nyon.MobSpawner,
    sound_manager: ?*nyon.SoundManager,
    audio_engine: ?*nyon.audio.Engine,
    inv_ui: nyon.inventory_ui.InventoryUI,
    rng: std.Random.DefaultPrng,

    // Tracking state
    prev_blocks_placed: u32,
    prev_blocks_broken: u32,
    prev_is_moving: bool,
    footstep_timer: f32,
    weather_particle_timer: f32,
    auto_save_message_timer: f32,

    // Combat state
    attack_cooldown: f32,
    last_hit_entity: ?nyon.Entity,
    hit_flash_timer: f32,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, audio_engine: ?*nyon.audio.Engine) !Self {
        // Use a seed based on timer or fallback to fixed value
        const seed: u64 = blk: {
            var timer = std.time.Timer.start() catch break :blk 12345;
            break :blk timer.read();
        };

        var game = Self{
            .allocator = allocator,
            .sandbox = try nyon.game.SandboxGame.init(allocator),
            .weather = nyon.Weather.init(),
            .weather_audio = nyon.WeatherAudio.init(),
            .entity_world = nyon.EntityWorld.init(allocator),
            .mob_spawner = nyon.MobSpawner.init(allocator, seed),
            .sound_manager = null,
            .audio_engine = audio_engine,
            .inv_ui = nyon.inventory_ui.InventoryUI{},
            .rng = std.Random.DefaultPrng.init(seed +% 1),
            .prev_blocks_placed = 0,
            .prev_blocks_broken = 0,
            .prev_is_moving = false,
            .footstep_timer = 0,
            .weather_particle_timer = 0,
            .auto_save_message_timer = 0,
            .attack_cooldown = 0,
            .last_hit_entity = null,
            .hit_flash_timer = 0,
        };

        // Initialize sound manager if audio engine is available
        if (audio_engine) |ae| {
            const sm = try allocator.create(nyon.SoundManager);
            sm.* = nyon.SoundManager.init(allocator, ae);
            // Generate procedural sounds
            sm.generateProceduralSounds() catch |err| {
                std.log.warn("Failed to generate procedural sounds: {}", .{err});
            };
            game.sound_manager = sm;
        }

        return game;
    }

    pub fn deinit(self: *Self) void {
        self.sandbox.deinit();
        self.entity_world.deinit();
        self.mob_spawner.deinit();
        if (self.sound_manager) |sm| {
            sm.deinit();
            self.allocator.destroy(sm);
        }
    }

    /// Main update function - updates all integrated systems
    pub fn update(self: *Self, engine: *nyon.Engine, dt: f32) !void {
        const input_state = &engine.input_state;

        // Store target block info before update for particle spawning and sounds
        const target_before = self.sandbox.target_block;
        const target_block_type: ?nyon.game.Block = if (target_before) |target|
            self.sandbox.world.getBlock(target.pos[0], target.pos[1], target.pos[2])
        else
            null;

        // Sync inventory UI open state with sandbox
        self.inv_ui.is_open = self.sandbox.inventory_open;

        // Update inventory UI input if open
        if (self.sandbox.inventory_open) {
            self.inv_ui.update(&self.sandbox.inventory, &self.sandbox.crafting, input_state);
            // Play UI sounds
            if (self.sound_manager) |sm| {
                // Could add click detection here for UI sounds
                _ = sm;
            }
        }

        // Update sandbox game
        self.sandbox.update(input_state, dt) catch |err| {
            std.log.warn("Game update error: {}", .{err});
        };

        // =====================================================================
        // Weather System Integration
        // =====================================================================
        self.weather.setTimeOfDay(self.sandbox.day_night.time);
        var random = self.rng.random();
        self.weather.update(dt, &random);

        // Apply weather effects to player movement speed
        const weather_type = self.weather.getEffectiveWeather();
        const weather_intensity = self.weather.getBlendedIntensity();
        self.sandbox.player.speed_multiplier = switch (weather_type) {
            .rain => 1.0 - (0.1 * weather_intensity), // Up to 10% slower in rain
            .storm => 1.0 - (0.15 * weather_intensity), // Up to 15% slower in storm
            .snow => 1.0 - (0.15 * weather_intensity), // Up to 15% slower in snow
            .fog => 1.0 - (0.05 * weather_intensity), // Up to 5% slower in fog
            else => 1.0, // Normal speed
        };

        // Update weather audio state
        self.weather_audio.updateFromWeather(&self.weather, dt);

        // Play thunder sounds when triggered
        if (self.sound_manager) |sm| {
            if (self.weather_audio.consumeThunder()) |volume| {
                sm.playWithOptions(.thunder, .{ .volume = volume });
            }

            // Update weather ambient sounds (use weather_type from above)
            if (weather_type == .rain or weather_type == .storm) {
                sm.setWeather(if (weather_type == .storm) .storm else .rain);
            } else {
                sm.setWeather(.clear);
            }
        }

        // Spawn weather particles (rain/snow)
        self.weather_particle_timer += dt;
        if (self.weather_particle_timer >= 0.05) {
            self.weather_particle_timer = 0;

            if (self.weather.getPrecipitationType()) |precip_type| {
                const player_pos = self.sandbox.player.position;
                // Spawn particles around player
                const spawn_count: u32 = @intFromFloat(self.weather.intensity * 3);
                if (spawn_count > 0) {
                    var i: u32 = 0;
                    while (i < spawn_count) : (i += 1) {
                        const offset_x = (self.rng.random().float(f32) - 0.5) * 20;
                        const offset_z = (self.rng.random().float(f32) - 0.5) * 20;
                        const spawn_pos = nyon.math.Vec3.init(
                            player_pos.x() + offset_x,
                            player_pos.y() + 15,
                            player_pos.z() + offset_z,
                        );
                        engine.renderer.spawnParticles(spawn_pos, precip_type, 1);
                    }
                }
            }
        }

        // =====================================================================
        // Entity System Integration
        // =====================================================================
        const player_pos = self.sandbox.player.position;

        // Update mob spawner
        self.mob_spawner.update(
            &self.entity_world,
            player_pos,
            &self.sandbox.world, // Biome generator
            null, // Light level function
            null, // Surface height function
            dt,
        ) catch {};

        // Update all entity systems
        nyon.entity.systems.updateAllSystems(
            &self.entity_world,
            player_pos,
            null, // Player entity (for attack system)
            dt,
            &self.rng,
        );

        // Resolve entity-world collisions (prevent entities walking through blocks)
        nyon.entity.systems.worldCollisionSystem(
            &self.entity_world,
            &self.sandbox.world,
        );

        // =====================================================================
        // Process Mob Death Events (drops)
        // =====================================================================
        const death_events = nyon.entity.systems.getDeathEvents();
        for (death_events) |event| {
            // Roll for drops
            const drops = nyon.entity.mobs.rollDrops(event.mob_type, &self.rng);
            for (drops) |drop| {
                if (drop.count > 0) {
                    _ = self.sandbox.inventory.addItem(drop.item_id, drop.count);
                }
            }
            // Add experience to player
            self.sandbox.addExperience(event.experience);
        }
        nyon.entity.systems.clearDeathEvents();

        // =====================================================================
        // Process Mob Attacks on Player
        // =====================================================================
        const damage_events = nyon.entity.systems.getPlayerDamageEvents();
        for (damage_events) |event| {
            self.sandbox.takeDamageWithKnockback(event.damage, event.source_position);

            // Play hurt sound
            if (self.sound_manager) |sm| {
                sm.playWithOptions(.mob_hurt, .{ .volume = 0.6 });
            }
        }
        nyon.entity.systems.clearPlayerDamageEvents();

        // =====================================================================
        // Player Combat System
        // =====================================================================
        self.attack_cooldown = @max(0, self.attack_cooldown - dt);
        self.hit_flash_timer = @max(0, self.hit_flash_timer - dt);

        // Clear last hit entity when flash timer expires
        if (self.hit_flash_timer <= 0) {
            self.last_hit_entity = null;
        }

        // Left click attack when:
        // - Not targeting a block (no block placement happening)
        // - Attack cooldown is ready
        // - Inventory is closed
        if (input_state.isMouseButtonDown(.left) and
            self.sandbox.target_block == null and
            self.attack_cooldown <= 0 and
            !self.sandbox.inventory_open)
        {
            const eye_pos = self.sandbox.player.getEyePosition();
            const look_dir = self.sandbox.player.getLookDirection();
            const attack_range: f32 = 4.0;
            const base_damage: f32 = 5.0;

            // Check for critical hit (falling + not grounded + moving downward)
            const is_critical = !self.sandbox.player.is_grounded and
                !self.sandbox.player.is_flying and
                self.sandbox.player.velocity.y() < -0.5;

            // Critical hits deal 50% extra damage
            const final_damage = if (is_critical) base_damage * 1.5 else base_damage;

            // Raycast for entities
            if (nyon.entity.raycastDamageableEntities(&self.entity_world, eye_pos, look_dir, attack_range)) |hit| {
                // Deal damage to the entity
                const killed = nyon.entity.systems.damageEntity(
                    &self.entity_world,
                    hit.entity,
                    final_damage,
                    player_pos,
                );

                // Track hit for visual feedback
                self.last_hit_entity = hit.entity;
                self.hit_flash_timer = if (is_critical) 0.35 else 0.2; // Longer flash for crits

                // Spawn hit particles (more for critical)
                const particle_count: u32 = if (is_critical) 16 else 8;
                engine.renderer.spawnParticles(hit.hit_point, .block_break, particle_count);

                // Play hit sound
                if (self.sound_manager) |sm| {
                    sm.playWithOptions(.mob_hurt, .{ .volume = 0.5 });
                }

                // Log for debugging
                if (killed) {
                    std.log.info("Entity killed!", .{});
                }

                // Set attack cooldown
                self.attack_cooldown = 0.5; // 500ms between attacks
            }
        }

        // =====================================================================
        // Sound System Integration
        // =====================================================================
        if (self.sound_manager) |sm| {
            // Update listener position
            sm.setListenerPosition(player_pos, self.sandbox.player.getLookDirection());

            // Set time of day for ambient sounds (convert 0-1 to 0-24 hours)
            sm.setWorldTime(self.sandbox.day_night.time * 24.0);

            // Update ambient sounds based on biome
            const current_biome = self.sandbox.getCurrentBiome();
            const is_underground = player_pos.y() < 40;
            const depth = 64 - player_pos.y();
            sm.updateAmbient(dt, current_biome.biome_type, is_underground, depth);

            // Footstep sounds
            const is_moving = self.sandbox.player.is_grounded and
                (nyon.math.Vec3.lengthSquared(self.sandbox.player.velocity) > 0.5);
            if (is_moving) {
                // Get block under player
                const foot_x: i32 = @intFromFloat(@floor(player_pos.x()));
                const foot_y: i32 = @intFromFloat(@floor(player_pos.y() - 0.1));
                const foot_z: i32 = @intFromFloat(@floor(player_pos.z()));
                const ground_block = self.sandbox.world.getBlock(foot_x, foot_y, foot_z);
                sm.updateFootsteps(dt, true, self.sandbox.player.is_running, ground_block);
            } else {
                sm.updateFootsteps(dt, false, false, .air);
            }

            // Block break/place sounds
            if (self.sandbox.blocks_placed > self.prev_blocks_placed) {
                if (target_before) |target| {
                    const place_pos = nyon.math.Vec3.init(
                        @as(f32, @floatFromInt(target.pos[0] + target.face[0])) + 0.5,
                        @as(f32, @floatFromInt(target.pos[1] + target.face[1])) + 0.5,
                        @as(f32, @floatFromInt(target.pos[2] + target.face[2])) + 0.5,
                    );
                    sm.playBlockPlace(place_pos);
                }
            }

            if (self.sandbox.blocks_broken > self.prev_blocks_broken) {
                if (target_before) |target| {
                    if (target_block_type) |block| {
                        const break_pos = nyon.math.Vec3.init(
                            @as(f32, @floatFromInt(target.pos[0])) + 0.5,
                            @as(f32, @floatFromInt(target.pos[1])) + 0.5,
                            @as(f32, @floatFromInt(target.pos[2])) + 0.5,
                        );
                        sm.playBlockBreak(block, break_pos);
                    }
                }
            }
        }

        // =====================================================================
        // Particle Effects for Block Events
        // =====================================================================
        if (self.sandbox.blocks_placed > self.prev_blocks_placed) {
            if (target_before) |target| {
                const place_pos = nyon.math.Vec3.init(
                    @as(f32, @floatFromInt(target.pos[0] + target.face[0])) + 0.5,
                    @as(f32, @floatFromInt(target.pos[1] + target.face[1])) + 0.5,
                    @as(f32, @floatFromInt(target.pos[2] + target.face[2])) + 0.5,
                );
                const block_color = nyon.block_renderer.getBlockColor(self.sandbox.selected_block);
                engine.renderer.spawnParticlesWithColor(place_pos, .block_place, 8, block_color);
            }
            self.prev_blocks_placed = self.sandbox.blocks_placed;
        }

        if (self.sandbox.blocks_broken > self.prev_blocks_broken) {
            if (target_before) |target| {
                const break_pos = nyon.math.Vec3.init(
                    @as(f32, @floatFromInt(target.pos[0])) + 0.5,
                    @as(f32, @floatFromInt(target.pos[1])) + 0.5,
                    @as(f32, @floatFromInt(target.pos[2])) + 0.5,
                );
                const block_color = if (target_block_type) |block_type|
                    nyon.block_renderer.getBlockColor(block_type)
                else
                    nyon.render.Color.fromRgb(128, 128, 128);
                engine.renderer.spawnParticlesWithColor(break_pos, .block_break, 12, block_color);
            }
            self.prev_blocks_broken = self.sandbox.blocks_broken;
        }

        // Update particles
        engine.renderer.updateParticles(dt);
    }

    /// Render all game systems
    pub fn render(self: *Self, engine: *nyon.Engine) void {
        // Set camera from player
        const view = self.sandbox.getViewMatrix();
        const aspect = @as(f32, @floatFromInt(engine.config.window_width)) /
            @as(f32, @floatFromInt(engine.config.window_height));
        const projection = nyon.math.Mat4.perspective(
            nyon.math.radians(70.0),
            aspect,
            0.1,
            1000.0,
        );
        engine.renderer.setCamera(view, projection);

        // Apply day/night cycle lighting with weather darkening
        var ambient = self.sandbox.getAmbientLight();
        const sky_darkening = self.weather.getSkyDarkening();
        ambient[0] *= (1.0 - sky_darkening * 0.5);
        ambient[1] *= (1.0 - sky_darkening * 0.5);
        ambient[2] *= (1.0 - sky_darkening * 0.5);
        nyon.block_renderer.setAmbientLight(ambient[0], ambient[1], ambient[2]);

        // Set sun direction based on day/night cycle
        const sun_angle = self.sandbox.day_night.getSunAngle();
        var sun_intensity: f32 = if (sun_angle > 0) @min(sun_angle / (std.math.pi / 4.0), 1.0) else 0.0;
        sun_intensity *= self.weather.getSunIntensity(); // Reduce sun during bad weather
        const sun_dir = nyon.math.Vec3.init(
            0.3,
            -@sin(@max(sun_angle, 0.05)),
            -@cos(@max(sun_angle, 0.05)),
        );
        nyon.block_renderer.setSunLight(sun_dir, sun_intensity);

        // Update water animation
        nyon.block_renderer.updateWater(@floatCast(engine.delta_time));

        // Update skybox animation (cloud drift, star twinkle)
        engine.renderer.updateSkybox(@floatCast(engine.delta_time));

        // Apply weather effects to skybox rendering
        // Modify sky based on cloud density
        engine.renderer.beginFrameWithSky(self.sandbox.day_night.time);

        // Apply fog effect from weather
        const fog_density = self.weather.getFogDensity();
        if (fog_density > 0.05) {
            const fog_color = self.weather.getFogColor();
            engine.renderer.applyScreenTint(fog_color, fog_density * 0.3);
        }

        // Render block world
        nyon.block_renderer.renderBlockWorld(
            &engine.renderer,
            &self.sandbox.world,
            self.sandbox.player.getEyePosition(),
            4, // Render distance in chunks
        );

        // Render block selection highlight
        if (self.sandbox.target_block) |target| {
            nyon.block_renderer.renderBlockHighlight(
                &engine.renderer,
                target.pos,
                nyon.render.Color.fromRgba(255, 255, 255, 150),
            );
        }

        // =====================================================================
        // Entity Rendering
        // =====================================================================
        self.renderEntities(engine);

        // Render particles
        engine.renderer.renderParticles();

        // Apply lightning flash effect
        const lightning_intensity = self.weather.getLightningIntensity();
        if (lightning_intensity > 0.01) {
            const flash_color = nyon.render.Color.fromRgba(255, 255, 255, @intFromFloat(lightning_intensity * 200));
            engine.renderer.applyScreenTint(flash_color, lightning_intensity * 0.5);
        }

        // Apply underwater effect if camera is below water level
        const eye_pos = self.sandbox.player.getEyePosition();
        if (nyon.block_renderer.isUnderwater(eye_pos.y())) {
            if (nyon.block_renderer.getUnderwaterEffects(eye_pos.y())) |underwater| {
                engine.renderer.applyUnderwaterEffect(underwater);
            }
        }

        // =====================================================================
        // UI Rendering
        // =====================================================================
        engine.ui_context.beginFrame(
            engine.input_state.mouse_x,
            engine.input_state.mouse_y,
            engine.input_state.mouse_buttons[0],
        );

        // Check if aiming at an entity for crosshair color
        const targeting_entity = if (!self.sandbox.inventory_open)
            nyon.entity.raycastDamageableEntities(&self.entity_world, eye_pos, self.sandbox.player.getLookDirection(), 4.0) != null
        else
            false;

        // Gather debug stats
        const debug_stats = nyon.hud.DebugStats{
            .fps = engine.getFPS(),
            .frame_time_ms = engine.delta_time * 1000.0,
            .entity_count = @intCast(self.entity_world.entityCount()),
        };

        // Draw HUD with entity targeting info
        nyon.hud.drawHUDWithEntityTarget(
            &engine.ui_context,
            &self.sandbox,
            engine.config.window_width,
            engine.config.window_height,
            targeting_entity,
            debug_stats,
        );

        // Draw weather info on HUD (optional debug)
        if (self.sandbox.show_debug) {
            // Weather info could be added to debug display
        }

        // Draw inventory UI if open
        if (self.sandbox.inventory_open) {
            self.inv_ui.draw(
                &engine.renderer,
                &self.sandbox.inventory,
                engine.config.window_width,
                engine.config.window_height,
            );
        }

        // End frames
        engine.ui_context.endFrame();
        engine.renderer.endFrame();
    }

    /// Render entities (mobs) as colored boxes
    fn renderEntities(self: *Self, engine: *nyon.Engine) void {
        // Collect render data from entity world
        var render_list = nyon.entity.systems.collectRenderData(&self.entity_world, self.allocator) catch return;
        defer render_list.deinit(self.allocator);

        for (render_list.items) |data| {
            // Render each entity as a colored wireframe cube
            const scale = data.scale;
            const pos = data.position;

            // Create model matrix
            const model = nyon.math.Mat4.translation(pos);
            const scaled_model = nyon.math.Mat4.mul(model, nyon.math.Mat4.scaling(scale));

            // Get entity color - flash red if recently hit
            var color: nyon.render.Color = undefined;
            if (self.last_hit_entity) |hit_entity| {
                if (data.entity.eql(hit_entity) and self.hit_flash_timer > 0) {
                    // Flash red when hit
                    const flash_intensity = self.hit_flash_timer / 0.2; // 0.2s total flash time
                    color = nyon.render.Color.fromFloat(
                        1.0,
                        data.color[1] * (1.0 - flash_intensity),
                        data.color[2] * (1.0 - flash_intensity),
                        data.color[3],
                    );
                } else {
                    color = nyon.render.Color.fromFloat(data.color[0], data.color[1], data.color[2], data.color[3]);
                }
            } else {
                color = nyon.render.Color.fromFloat(data.color[0], data.color[1], data.color[2], data.color[3]);
            }

            // Draw wireframe cube for entity
            engine.renderer.drawWireframeCube(scaled_model, color);
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.log.info("Nyon Sandbox v{s} starting...", .{nyon.VERSION.string});

    // Initialize engine
    var engine = try nyon.Engine.init(allocator, .{
        .window_width = 1280,
        .window_height = 720,
        .window_title = "Nyon Sandbox",
        .gpu_backend = .software,
    });
    defer engine.deinit();

    // Log GPU info
    if (engine.gpu_context) |ctx| {
        std.log.info("GPU: {s}", .{ctx.device_info.getName()});
    } else {
        std.log.info("Running in software mode", .{});
    }

    // Initialize integrated game with all systems
    var game = try IntegratedGame.init(allocator, if (engine.audio_engine) |*ae| ae else null);
    defer game.deinit();

    std.log.info("World generated: {} chunks loaded", .{game.sandbox.world.chunks.count()});
    std.log.info("Weather system: {s}", .{game.weather.getEffectiveWeather().getName()});
    std.log.info("Entity system: initialized", .{});
    std.log.info("Sound system: {s}", .{if (game.sound_manager != null) "initialized" else "disabled"});

    // Run game loop
    var timer = std.time.Timer.start() catch {
        std.log.err("Failed to start timer", .{});
        return;
    };

    while (engine.running) {
        const frame_start = timer.read();

        // Poll input
        engine.input_state.poll(engine.window_handle);

        // Check for quit
        if (engine.input_state.shouldQuit() or nyon.window.shouldClose(engine.window_handle)) {
            engine.running = false;
            break;
        }

        // Update all game systems
        game.update(&engine, @floatCast(engine.delta_time)) catch |err| {
            std.log.warn("Game update error: {}", .{err});
        };

        // Update audio engine
        if (engine.audio_engine) |*ae| {
            ae.update();
        }

        // Render all game systems
        game.render(&engine);

        // Calculate delta time
        const frame_end = timer.read();
        engine.delta_time = @as(f64, @floatFromInt(frame_end - frame_start)) / std.time.ns_per_s;
        engine.total_time += engine.delta_time;
        engine.frame_count += 1;
    }

    std.log.info("Game ended. Frames: {}, Avg FPS: {d:.1}", .{
        engine.frame_count,
        if (engine.total_time > 0) @as(f64, @floatFromInt(engine.frame_count)) / engine.total_time else 0,
    });
}

test {
    std.testing.refAllDecls(@This());
}
