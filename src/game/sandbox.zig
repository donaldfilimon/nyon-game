//! 3D sandbox gameplay state and world persistence.

const std = @import("std");
const engine = @import("../engine.zig");
const worlds_mod = @import("worlds.zig");

const Color = engine.Color;
const Vector2 = engine.Vector2;
const Vector3 = engine.Vector3;
const Camera3D = engine.Camera3D;
const Ray = engine.Ray;
const BoundingBox = engine.BoundingBox;
const Input = engine.Input;
const KeyboardKey = engine.KeyboardKey;
const MouseButton = engine.MouseButton;

pub const BLOCK_SIZE: f32 = 1.0;
const HALF_BLOCK: f32 = BLOCK_SIZE * 0.5;

pub const WORLD_DATA_FILE: []const u8 = "world_data.json";
pub const WORLD_DATA_VERSION: u32 = 1;

pub const COLOR_BACKGROUND = Color{ .r = 20, .g = 28, .b = 36, .a = 255 };
const COLOR_GROUND = Color{ .r = 60, .g = 70, .b = 80, .a = 255 };
const COLOR_HIGHLIGHT = Color{ .r = 255, .g = 220, .b = 120, .a = 255 };
const COLOR_PREVIEW = Color{ .r = 120, .g = 220, .b = 160, .a = 200 };

pub const BlockPos = struct {
    x: i32,
    y: i32,
    z: i32,
};

pub const Block = struct {
    pos: BlockPos,
    color_index: u8,
};

pub const BlockColor = struct {
    name: []const u8,
    color: Color,
};

pub const BLOCK_COLORS = [_]BlockColor{
    .{ .name = "Stone", .color = Color{ .r = 160, .g = 165, .b = 175, .a = 255 } },
    .{ .name = "Grass", .color = Color{ .r = 90, .g = 170, .b = 90, .a = 255 } },
    .{ .name = "Sand", .color = Color{ .r = 210, .g = 195, .b = 140, .a = 255 } },
    .{ .name = "Clay", .color = Color{ .r = 190, .g = 120, .b = 110, .a = 255 } },
    .{ .name = "Slate", .color = Color{ .r = 110, .g = 120, .b = 150, .a = 255 } },
};

pub const CameraData = struct {
    x: f32 = 0.0,
    y: f32 = 2.0,
    z: f32 = -6.0,
    yaw: f32 = 0.0,
    pitch: f32 = 0.0,
};

pub const WorldData = struct {
    version: u32 = WORLD_DATA_VERSION,
    camera: CameraData = .{},
    blocks: []Block = &.{},
};

pub const SandboxWorld = struct {
    allocator: std.mem.Allocator,
    blocks: std.ArrayList(Block),

    pub fn init(allocator: std.mem.Allocator) SandboxWorld {
        return .{
            .allocator = allocator,
            .blocks = std.ArrayList(Block).initCapacity(allocator, 0) catch unreachable,
        };
    }

    pub fn deinit(self: *SandboxWorld) void {
        self.blocks.deinit(self.allocator);
    }

    pub fn clear(self: *SandboxWorld) void {
        self.blocks.clearRetainingCapacity();
    }

    pub fn count(self: *const SandboxWorld) usize {
        return self.blocks.items.len;
    }

    pub fn findIndex(self: *const SandboxWorld, pos: BlockPos) ?usize {
        for (self.blocks.items, 0..) |block, i| {
            if (block.pos.x == pos.x and block.pos.y == pos.y and block.pos.z == pos.z) {
                return i;
            }
        }
        return null;
    }

    pub fn add(self: *SandboxWorld, pos: BlockPos, color_index: u8) bool {
        if (self.findIndex(pos) != null) return false;
        self.blocks.append(self.allocator, .{ .pos = pos, .color_index = color_index }) catch return false;
        return true;
    }

    pub fn removeIndex(self: *SandboxWorld, index: usize) void {
        if (index >= self.blocks.items.len) return;
        _ = self.blocks.swapRemove(index);
    }
};

pub const SandboxAction = union(enum) {
    none,
    placed: BlockPos,
    removed: BlockPos,
    color_changed: u8,
};

pub const SandboxState = struct {
    allocator: std.mem.Allocator,
    camera: Camera3D,
    yaw: f32,
    pitch: f32,
    move_speed: f32,
    fast_multiplier: f32,
    mouse_sensitivity: f32,
    mouse_look: bool,
    world: SandboxWorld,
    active_color: u8,
    hovered_block: ?usize = null,
    placement_target: ?BlockPos = null,

    pub fn init(allocator: std.mem.Allocator) SandboxState {
        const camera_pos = vec3(0.0, 2.0, -6.0);
        const camera_target = vec3(0.0, 1.2, 0.0);
        const orientation = orientationFromTarget(camera_pos, camera_target);
        return .{
            .allocator = allocator,
            .camera = Camera3D{
                .position = camera_pos,
                .target = camera_target,
                .up = vec3(0.0, 1.0, 0.0),
                .fovy = 60.0,
                .projection = engine.CameraProjection.perspective,
            },
            .yaw = orientation.yaw,
            .pitch = orientation.pitch,
            .move_speed = 6.0,
            .fast_multiplier = 3.0,
            .mouse_sensitivity = 0.0025,
            .mouse_look = false,
            .world = SandboxWorld.init(allocator),
            .active_color = 0,
        };
    }

    pub fn deinit(self: *SandboxState) void {
        if (self.mouse_look) {
            engine.Cursor.enable();
        }
        self.world.deinit();
    }

    pub fn resetCamera(self: *SandboxState) void {
        const camera_pos = vec3(0.0, 2.0, -6.0);
        const camera_target = vec3(0.0, 1.2, 0.0);
        const orientation = orientationFromTarget(camera_pos, camera_target);
        self.camera.position = camera_pos;
        self.camera.target = camera_target;
        self.camera.up = vec3(0.0, 1.0, 0.0);
        self.yaw = orientation.yaw;
        self.pitch = orientation.pitch;
    }

    pub fn clearWorld(self: *SandboxState) void {
        self.world.clear();
        self.resetCamera();
    }

    pub fn loadWorld(self: *SandboxState, folder: []const u8) !void {
        self.world.clear();

        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const path = try worldDataPath(folder, &path_buf);

        const file_bytes = std.fs.cwd().readFileAlloc(path, self.allocator, std.Io.Limit.limited(512 * 1024)) catch |err| switch (err) {
            error.FileNotFound => return,
            else => return err,
        };
        defer self.allocator.free(file_bytes);

        const Parsed = std.json.Parsed(WorldData);
        var parsed: Parsed = try std.json.parseFromSlice(WorldData, self.allocator, file_bytes, .{
            .ignore_unknown_fields = true,
        });
        defer parsed.deinit();

        for (parsed.value.blocks) |block| {
            _ = self.world.add(block.pos, block.color_index);
        }

        self.camera.position = vec3(parsed.value.camera.x, parsed.value.camera.y, parsed.value.camera.z);
        self.yaw = parsed.value.camera.yaw;
        self.pitch = parsed.value.camera.pitch;
        self.camera.up = vec3(0.0, 1.0, 0.0);
        self.camera.target = vec3Add(self.camera.position, forwardFromAngles(self.yaw, self.pitch));
    }

    pub fn saveWorld(self: *const SandboxState, folder: []const u8) !void {
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const path = try worldDataPath(folder, &path_buf);

        var file = try std.fs.cwd().createFile(path, .{ .truncate = true });
        defer file.close();

        const data = WorldData{
            .version = WORLD_DATA_VERSION,
            .camera = .{
                .x = self.camera.position.x,
                .y = self.camera.position.y,
                .z = self.camera.position.z,
                .yaw = self.yaw,
                .pitch = self.pitch,
            },
            .blocks = self.world.blocks.items,
        };

        var buffer: [4096]u8 = undefined;
        var writer = file.writer(&buffer);
        try std.json.Stringify.value(data, .{ .whitespace = .indent_2 }, &writer.interface);
        try writer.interface.flush();
    }

    pub fn update(
        self: *SandboxState,
        dt: f32,
        allow_input: bool,
        screen_width: f32,
        screen_height: f32,
    ) SandboxAction {
        if (!allow_input and self.mouse_look) {
            engine.Cursor.enable();
            self.mouse_look = false;
        }

        self.updateCamera(dt, allow_input);
        self.updateTargets(allow_input, screen_width, screen_height);

        var action: SandboxAction = .none;
        if (!allow_input) return action;

        if (Input.Keyboard.isPressed(KeyboardKey.tab)) {
            const next = (@as(usize, self.active_color) + 1) % BLOCK_COLORS.len;
            self.active_color = @intCast(next);
            action = .{ .color_changed = self.active_color };
        }

        const ctrl_down = Input.Keyboard.isDown(KeyboardKey.left_control) or Input.Keyboard.isDown(KeyboardKey.right_control);
        if (Input.Mouse.isButtonPressed(MouseButton.left)) {
            if (ctrl_down) {
                if (self.hovered_block) |index| {
                    const removed = self.world.blocks.items[index].pos;
                    self.world.removeIndex(index);
                    action = .{ .removed = removed };
                }
            } else if (self.placement_target) |pos| {
                if (self.world.add(pos, self.active_color)) {
                    action = .{ .placed = pos };
                }
            }
        }

        if (!ctrl_down and Input.Keyboard.isPressed(KeyboardKey.r)) {
            self.resetCamera();
        }

        return action;
    }

    pub fn drawWorld(self: *const SandboxState) void {
        engine.Drawing.beginMode3D(self.camera);

        engine.Shapes.drawPlane(vec3(0.0, 0.0, 0.0), Vector2{ .x = 100.0, .y = 100.0 }, COLOR_GROUND);
        engine.Shapes.drawGrid(100, 1.0);

        for (self.world.blocks.items) |block| {
            const center = blockCenter(block.pos);
            const color_index = @min(@as(usize, block.color_index), BLOCK_COLORS.len - 1);
            const color = BLOCK_COLORS[color_index].color;
            engine.Shapes.drawCube(center, BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE, color);
        }

        if (self.hovered_block) |index| {
            const center = blockCenter(self.world.blocks.items[index].pos);
            engine.Shapes.drawCubeWires(center, BLOCK_SIZE + 0.02, BLOCK_SIZE + 0.02, BLOCK_SIZE + 0.02, COLOR_HIGHLIGHT);
        }

        if (self.placement_target) |pos| {
            const center = blockCenter(pos);
            engine.Shapes.drawCubeWires(center, BLOCK_SIZE + 0.02, BLOCK_SIZE + 0.02, BLOCK_SIZE + 0.02, COLOR_PREVIEW);
        }

        engine.Drawing.endMode3D();
    }

    pub fn activeColor(self: *const SandboxState) BlockColor {
        const index = @min(@as(usize, self.active_color), BLOCK_COLORS.len - 1);
        return BLOCK_COLORS[index];
    }

    fn updateCamera(self: *SandboxState, dt: f32, allow_input: bool) void {
        if (!allow_input) {
            self.camera.target = vec3Add(self.camera.position, forwardFromAngles(self.yaw, self.pitch));
            return;
        }

        if (Input.Mouse.isButtonDown(MouseButton.right)) {
            if (!self.mouse_look) {
                engine.Cursor.disable();
                self.mouse_look = true;
            }
            const delta = Input.Mouse.getDelta();
            self.yaw += delta.x * self.mouse_sensitivity;
            self.pitch -= delta.y * self.mouse_sensitivity;
            self.pitch = std.math.clamp(self.pitch, -1.5, 1.5);
        } else if (self.mouse_look) {
            engine.Cursor.enable();
            self.mouse_look = false;
        }

        var move_dir = vec3(0.0, 0.0, 0.0);
        const forward_flat = vec3Normalize(vec3(@sin(self.yaw), 0.0, @cos(self.yaw)));
        const right = vec3Normalize(vec3(@cos(self.yaw), 0.0, -@sin(self.yaw)));
        const up = vec3(0.0, 1.0, 0.0);

        if (Input.Keyboard.isDown(KeyboardKey.w)) {
            move_dir = vec3Add(move_dir, forward_flat);
        }
        if (Input.Keyboard.isDown(KeyboardKey.s)) {
            move_dir = vec3Sub(move_dir, forward_flat);
        }
        if (Input.Keyboard.isDown(KeyboardKey.d)) {
            move_dir = vec3Add(move_dir, right);
        }
        if (Input.Keyboard.isDown(KeyboardKey.a)) {
            move_dir = vec3Sub(move_dir, right);
        }
        if (Input.Keyboard.isDown(KeyboardKey.e)) {
            move_dir = vec3Add(move_dir, up);
        }
        if (Input.Keyboard.isDown(KeyboardKey.q)) {
            move_dir = vec3Sub(move_dir, up);
        }

        const move_len = vec3Length(move_dir);
        if (move_len > 0.001) {
            const sprint = Input.Keyboard.isDown(KeyboardKey.left_shift) or Input.Keyboard.isDown(KeyboardKey.right_shift);
            const speed = self.move_speed * (if (sprint) self.fast_multiplier else 1.0);
            const delta = vec3Scale(vec3Normalize(move_dir), speed * dt);
            self.camera.position = vec3Add(self.camera.position, delta);
        }

        self.camera.target = vec3Add(self.camera.position, forwardFromAngles(self.yaw, self.pitch));
    }

    fn updateTargets(self: *SandboxState, allow_input: bool, screen_width: f32, screen_height: f32) void {
        self.hovered_block = null;
        self.placement_target = null;

        if (!allow_input) return;

        const screen_pos = if (self.mouse_look)
            Vector2{ .x = screen_width * 0.5, .y = screen_height * 0.5 }
        else
            Input.Mouse.getPosition();
        const ray = engine.Cameras.getScreenToWorldRay(screen_pos, self.camera);

        var best_distance: f32 = std.math.inf(f32);
        var best_index: ?usize = null;
        var best_normal = vec3(0.0, 0.0, 0.0);

        for (self.world.blocks.items, 0..) |block, i| {
            const bbox = blockBounds(block.pos);
            const collision = engine.Collision.getRayBox(ray, bbox);
            if (!collision.hit) continue;
            if (collision.distance < best_distance) {
                best_distance = collision.distance;
                best_index = i;
                best_normal = collision.normal;
            }
        }

        if (best_index) |index| {
            self.hovered_block = index;
            const offset = normalToOffset(best_normal);
            const base = self.world.blocks.items[index].pos;
            self.placement_target = BlockPos{
                .x = base.x + offset.x,
                .y = base.y + offset.y,
                .z = base.z + offset.z,
            };
            return;
        }

        if (rayPlaneIntersection(ray, 0.0)) |point| {
            const pos = blockPosFromPoint(point);
            self.placement_target = BlockPos{ .x = pos.x, .y = 0, .z = pos.z };
        }
    }
};

fn vec3(x: f32, y: f32, z: f32) Vector3 {
    return .{ .x = x, .y = y, .z = z };
}

fn vec3Add(a: Vector3, b: Vector3) Vector3 {
    return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
}

fn vec3Sub(a: Vector3, b: Vector3) Vector3 {
    return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
}

fn vec3Scale(v: Vector3, s: f32) Vector3 {
    return .{ .x = v.x * s, .y = v.y * s, .z = v.z * s };
}

fn vec3Length(v: Vector3) f32 {
    return @sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
}

fn vec3Normalize(v: Vector3) Vector3 {
    const len = vec3Length(v);
    if (len <= 0.00001) return vec3(0.0, 0.0, 0.0);
    return vec3Scale(v, 1.0 / len);
}

fn forwardFromAngles(yaw: f32, pitch: f32) Vector3 {
    const cos_pitch = @cos(pitch);
    return vec3(@sin(yaw) * cos_pitch, @sin(pitch), @cos(yaw) * cos_pitch);
}

fn orientationFromTarget(position: Vector3, target: Vector3) struct { yaw: f32, pitch: f32 } {
    const forward = vec3Normalize(vec3Sub(target, position));
    const clamped_y = std.math.clamp(forward.y, -1.0, 1.0);
    return .{
        .yaw = std.math.atan2(forward.x, forward.z),
        .pitch = std.math.asin(clamped_y),
    };
}

fn blockCenter(pos: BlockPos) Vector3 {
    return vec3(
        @as(f32, @floatFromInt(pos.x)) + 0.5,
        @as(f32, @floatFromInt(pos.y)) + 0.5,
        @as(f32, @floatFromInt(pos.z)) + 0.5,
    );
}

fn blockBounds(pos: BlockPos) BoundingBox {
    const center = blockCenter(pos);
    return .{
        .min = vec3(center.x - HALF_BLOCK, center.y - HALF_BLOCK, center.z - HALF_BLOCK),
        .max = vec3(center.x + HALF_BLOCK, center.y + HALF_BLOCK, center.z + HALF_BLOCK),
    };
}

fn blockPosFromPoint(point: Vector3) BlockPos {
    return .{
        .x = @intFromFloat(@floor(point.x)),
        .y = @intFromFloat(@floor(point.y)),
        .z = @intFromFloat(@floor(point.z)),
    };
}

fn normalToOffset(normal: Vector3) BlockPos {
    const nx: i32 = if (normal.x > 0.5) 1 else if (normal.x < -0.5) -1 else 0;
    const ny: i32 = if (normal.y > 0.5) 1 else if (normal.y < -0.5) -1 else 0;
    const nz: i32 = if (normal.z > 0.5) 1 else if (normal.z < -0.5) -1 else 0;
    return .{ .x = nx, .y = ny, .z = nz };
}

fn rayPlaneIntersection(ray: Ray, plane_y: f32) ?Vector3 {
    const denom = ray.direction.y;
    if (@abs(denom) < 0.0001) return null;
    const t = (plane_y - ray.position.y) / denom;
    if (t < 0.0) return null;
    return vec3(
        ray.position.x + ray.direction.x * t,
        plane_y,
        ray.position.z + ray.direction.z * t,
    );
}

fn worldDataPath(folder: []const u8, buffer: *[std.fs.max_path_bytes]u8) ![]const u8 {
    const sep = std.fs.path.sep_str;
    return std.fmt.bufPrint(buffer, "{s}{s}{s}{s}{s}", .{
        worlds_mod.SAVES_DIR,
        sep,
        folder,
        sep,
        WORLD_DATA_FILE,
    });
}
