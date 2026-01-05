//! 3D sandbox gameplay state and world persistence.

const std = @import("std");
const engine = @import("../engine.zig");
const worlds_mod = @import("worlds.zig");
const common = @import("../common/error_handling.zig");
const config = @import("../config/constants.zig");

const GRID_CELL_SIZE = config.Game.GRID_CELL_SIZE;
const WORLD_DATA_VERSION = config.Game.WORLD_DATA_VERSION;
const COLOR_GROUND = config.Colors.GROUND;
const HALF_BLOCK = config.Game.HALF_BLOCK;
const WORLD_DATA_FILE = config.Game.WORLD_DATA_FILE;
const BLOCK_SIZE = config.Game.BLOCK_SIZE;
const COLOR_HIGHLIGHT = config.Colors.HIGHLIGHT;
const COLOR_PREVIEW = config.Colors.PREVIEW;

const Color = engine.Color;
const Vector2 = engine.Vector2;
const Vector3 = engine.Vector3;
const Camera3D = engine.Camera3D;
const Ray = engine.Ray;
const BoundingBox = engine.BoundingBox;
const Input = engine.Input;
const KeyboardKey = engine.KeyboardKey;
const MouseButton = engine.MouseButton;

pub // Constants moved to config/constants.zig to eliminate magic numbers

const GRID_SIZE: u32 = 256;
const PRIME1: u32 = 73856093;
const PRIME2: u32 = 83492791;

pub const BlockPos = struct {
    x: i32,
    y: i32,
    z: i32,

    pub fn hash(self: BlockPos) u32 {
        const x_hash = @as(u32, @bitCast(@as(i32, self.x))) *% PRIME1;
        const y_hash = @as(u32, @bitCast(@as(i32, self.y))) *% PRIME2;
        const z_hash = @as(u32, @bitCast(@as(i32, self.z))) *% PRIME1;
        return (x_hash +% y_hash +% z_hash) % GRID_SIZE;
    }

    pub fn toCell(self: BlockPos) BlockPos {
        return .{
            .x = @divFloor(self.x, GRID_CELL_SIZE),
            .y = @divFloor(self.y, GRID_CELL_SIZE),
            .z = @divFloor(self.z, GRID_CELL_SIZE),
        };
    }
};

pub const Block = struct {
    pos: BlockPos,
    color_index: u8,
    index: usize = 0,
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
    spatial_grid: std.ArrayList(std.ArrayListUnmanaged(usize)),

    pub fn init(allocator: std.mem.Allocator) SandboxWorld {
        var spatial_grid = std.ArrayList(std.ArrayListUnmanaged(usize)).initCapacity(allocator, GRID_SIZE) catch unreachable;
        spatial_grid.items.len = GRID_SIZE;
        for (0..GRID_SIZE) |i| {
            spatial_grid.items[i] = .{};
        }

        return .{
            .allocator = allocator,
            .blocks = std.ArrayList(Block).initCapacity(allocator, config.Game.MAX_BLOCKS) catch unreachable,
            .spatial_grid = spatial_grid,
        };
    }

    pub fn deinit(self: *SandboxWorld) void {
        self.blocks.deinit(self.allocator);
        for (self.spatial_grid.items) |*cell| {
            cell.deinit(self.allocator);
        }
        self.spatial_grid.deinit(self.allocator);
    }

    pub fn clear(self: *SandboxWorld) void {
        self.blocks.clearRetainingCapacity();
        for (self.spatial_grid.items) |*cell| {
            cell.clearRetainingCapacity();
        }
    }

    pub fn count(self: *const SandboxWorld) usize {
        return self.blocks.items.len;
    }

    pub fn findIndex(self: *const SandboxWorld, pos: BlockPos) ?usize {
        const cell_hash = pos.hash();
        const cell = &self.spatial_grid.items[cell_hash];

        for (cell.items) |block_index| {
            const block = &self.blocks.items[block_index];
            if (block.pos.x == pos.x and block.pos.y == pos.y and block.pos.z == pos.z) {
                return block_index;
            }
        }
        return null;
    }

    pub fn add(self: *SandboxWorld, pos: BlockPos, color_index: u8) bool {
        if (self.findIndex(pos) != null) return false;

        const index = self.blocks.items.len;
        self.blocks.append(self.allocator, .{ .pos = pos, .color_index = color_index, .index = index }) catch return false;
        self.blocks.items[index].index = index;

        const cell_hash = pos.hash();
        try self.spatial_grid.items[cell_hash].append(self.allocator, index);

        return true;
    }

    pub fn removeIndex(self: *SandboxWorld, index: usize) void {
        if (index >= self.blocks.items.len) return;

        const block = self.blocks.items[index];
        const cell_hash = block.pos.hash();
        const cell = &self.spatial_grid.items[cell_hash];

        var found_cell_idx: ?usize = null;
        for (cell.items, 0..) |block_idx, i| {
            if (block_idx == index) {
                found_cell_idx = i;
                break;
            }
        }

        if (found_cell_idx) |ci| {
            const last_idx = cell.items.len - 1;
            if (ci < last_idx) {
                cell.items[ci] = cell.items[last_idx];
            }
            cell.items.len -= 1;
        }

        _ = self.blocks.swapRemove(index);
        try self.rebuildSpatialGrid();
    }

    fn rebuildSpatialGrid(self: *SandboxWorld) !void {
        for (self.spatial_grid.items) |*cell| {
            cell.clearRetainingCapacity();
        }

        for (self.blocks.items, 0..) |block, i| {
            const cell_hash = block.pos.hash();
            try self.spatial_grid.items[cell_hash].append(self.allocator, i);
        }
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

    /// Load world data from JSON file and populate the sandbox
    /// Parses world geometry, camera position, and other state from saved file.
    /// Uses arena allocator for efficient JSON parsing and temporary allocations.
    pub fn loadWorld(self: *SandboxState, folder: []const u8) !void {
        self.world.clear();

        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const path = try worldDataPath(folder, &path_buf);

        const file_bytes = try retryRead(3, path, self.allocator, std.Io.Limit.limited(512 * 1024));
        defer self.allocator.free(file_bytes);

        // Use arena allocator for all JSON parsing allocations
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const arena_alloc = arena.allocator();

        const Parsed = std.json.Parsed(WorldData);
        var parsed: Parsed = try std.json.parseFromSlice(WorldData, arena_alloc, file_bytes, .{
            .ignore_unknown_fields = true,
        });
        defer parsed.deinit();

        // Pre-allocate blocks array with known capacity for better performance
        const block_count = parsed.value.blocks.len;
        var blocks = std.ArrayList(Block).initCapacity(self.allocator, block_count) catch unreachable;
        defer blocks.deinit(self.allocator);

        for (parsed.value.blocks) |block| {
            blocks.append(self.allocator, block) catch unreachable;
        }

        // Bulk add all blocks at once for better performance
        for (blocks.items) |block| {
            _ = self.world.add(block.pos, block.color_index);
        }

        self.world.rebuildSpatialGrid() catch {};

        self.camera.position = vec3(parsed.value.camera.x, parsed.value.camera.y, parsed.value.camera.z);
        self.yaw = parsed.value.camera.yaw;
        self.pitch = parsed.value.camera.pitch;
        self.camera.up = vec3(0.0, 1.0, 0.0);
        self.camera.target = vec3Add(self.camera.position, forwardFromAngles(self.yaw, self.pitch));
    }

    fn retryRead(max_attempts: u32, path: []const u8, allocator: std.mem.Allocator, max_size: std.Io.SizeLimit) ![]u8 {
        var attempt: u32 = 0;
        while (attempt < max_attempts) : (attempt += 1) {
            const result = std.fs.cwd().readFileAlloc(path, allocator, max_size);
            if (result) |data| {
                return data;
            } else |err| {
                if (attempt < max_attempts - 1) {
                    std.log.warn("Failed to read file (attempt {d}/{d}): {}, retrying...", .{ attempt + 1, max_attempts, err });
                    std.time.sleep(100 * std.time.ns_per_ms);
                    continue;
                }
                if (err == error.FileNotFound) {
                    std.log.warn("World file not found: {s}", .{path});
                    return error.FileNotFound;
                }
                std.log.err("Failed to read file after {d} attempts: {}", .{ max_attempts, err });
                return err;
            }
        }
        return error.OperationFailed;
    }

    pub fn saveWorld(self: *const SandboxState, folder: []const u8) !void {
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const path = try worldDataPath(folder, &path_buf);

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
        var fba = std.heap.FixedBufferAllocator.init(&buffer);
        const arena = fba.allocator();

        var string_writer = std.ArrayList(u8).initCapacity(arena, 4096) catch unreachable;
        defer string_writer.deinit();

        try std.json.stringify(data, .{ .whitespace = .indent_2 }, string_writer.writer());

        try retryWrite(3, path, string_writer.items);
    }

    fn retryWrite(max_attempts: u32, path: []const u8, data: []const u8) !void {
        var attempt: u32 = 0;
        while (attempt < max_attempts) : (attempt += 1) {
            const result = std.fs.cwd().atomicFile(path, .{ .mode = .write_only });
            if (result) |af| {
                defer af.file_handle.close();
                const write_result = af.file_handle.writeAll(data);
                if (write_result) |_| {
                    try af.finish();
                    return;
                } else |err| {
                    std.log.warn("Failed to write file (attempt {d}/{d}): {}, retrying...", .{ attempt + 1, max_attempts, err });
                    if (attempt < max_attempts - 1) {
                        std.time.sleep(100 * std.time.ns_per_ms);
                        continue;
                    }
                    std.log.err("Failed to write file after {d} attempts: {}", .{ max_attempts, err });
                    return err;
                }
            } else |err| {
                std.log.warn("Failed to create file (attempt {d}/{d}): {}, retrying...", .{ attempt + 1, max_attempts, err });
                if (attempt < max_attempts - 1) {
                    std.time.sleep(100 * std.time.ns_per_ms);
                    continue;
                }
                std.log.err("Failed to create file after {d} attempts: {}", .{ max_attempts, err });
                return err;
            }
        }
        return error.OperationFailed;
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
            const next = (common.Cast.toInt(usize, self.active_color) + 1) % BLOCK_COLORS.len;
            self.active_color = common.Cast.toInt(u8, next);
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

    /// Render all blocks in the sandbox world using the spatial grid
    /// Iterates through blocks and draws them as cubes at their world positions.
    /// Uses instancing where possible for better performance.
    pub fn drawWorld(self: *const SandboxState) void {
        engine.Drawing.beginMode3D(self.camera);

        engine.Shapes.drawPlane(vec3(0.0, 0.0, 0.0), Vector2{ .x = 100.0, .y = 100.0 }, COLOR_GROUND);
        engine.Shapes.drawGrid(100, 1.0);

        for (self.world.blocks.items) |block| {
            const center = blockCenter(block.pos);
            const color_index = @min(common.Cast.toInt(usize, block.color_index), BLOCK_COLORS.len - 1);
            const color = BLOCK_COLORS[color_index].color;
            engine.Shapes.drawCube(center, BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE, color);
        }

        if (self.hovered_block) |index| {
            if (index < self.world.blocks.items.len) {
                const center = blockCenter(self.world.blocks.items[index].pos);
                engine.Shapes.drawCubeWires(center, BLOCK_SIZE + 0.02, BLOCK_SIZE + 0.02, BLOCK_SIZE + 0.02, COLOR_HIGHLIGHT);
            }
        }

        if (self.placement_target) |pos| {
            const center = blockCenter(pos);
            engine.Shapes.drawCubeWires(center, BLOCK_SIZE + 0.02, BLOCK_SIZE + 0.02, BLOCK_SIZE + 0.02, COLOR_PREVIEW);
        }

        engine.Drawing.endMode3D();
    }

    pub fn activeColor(self: *const SandboxState) BlockColor {
        const index = @min(common.Cast.toInt(usize, self.active_color), BLOCK_COLORS.len - 1);
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
        common.Cast.toFloat(f32, pos.x) + 0.5,
        common.Cast.toFloat(f32, pos.y) + 0.5,
        common.Cast.toFloat(f32, pos.z) + 0.5,
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
        .x = common.Cast.toInt(i32, @floor(point.x)),
        .y = common.Cast.toInt(i32, @floor(point.y)),
        .z = common.Cast.toInt(i32, @floor(point.z)),
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
    const platform = @import("../platform/paths.zig");
    const sep = platform.PathUtils.Separator;
    return std.fmt.bufPrint(buffer, "{s}{s}{s}{s}{s}", .{
        worlds_mod.SAVES_DIR,
        sep,
        folder,
        sep,
        WORLD_DATA_FILE,
    });
}

test "block position hashing" {
    const pos = BlockPos{ .x = 10, .y = 20, .z = 30 };
    const hash1 = pos.hash();
    const hash2 = pos.hash();

    try std.testing.expect(hash1 == hash2);
    try std.testing.expect(hash1 < GRID_SIZE);
}

test "spatial grid cell computation" {
    const pos = BlockPos{ .x = 10, .y = 5, .z = 15 };
    const cell = pos.toCell();

    const expected_x = @divFloor(pos.x, GRID_CELL_SIZE);
    const expected_y = @divFloor(pos.y, GRID_CELL_SIZE);
    const expected_z = @divFloor(pos.z, GRID_CELL_SIZE);

    try std.testing.expect(cell.x == expected_x);
    try std.testing.expect(cell.y == expected_y);
    try std.testing.expect(cell.z == expected_z);
}

test "spatial grid lookup" {
    var world = SandboxWorld.init(std.testing.allocator);
    defer world.deinit();

    const pos1 = BlockPos{ .x = 0, .y = 0, .z = 0 };
    const pos2 = BlockPos{ .x = 100, .y = 0, .z = 0 };
    const pos3 = BlockPos{ .x = 50, .y = 0, .z = 50 };

    _ = world.add(pos1, 0);
    _ = world.add(pos2, 1);
    _ = world.add(pos3, 2);

    const found = world.findIndex(pos2);
    try std.testing.expect(found != null);

    const not_found = world.findIndex(BlockPos{ .x = 999, .y = 999, .z = 999 });
    try std.testing.expect(not_found == null);
}

test "spatial grid collision detection" {
    var world = SandboxWorld.init(std.testing.allocator);
    defer world.deinit();

    const pos = BlockPos{ .x = 10, .y = 10, .z = 10 };
    _ = world.add(pos, 0);

    const duplicate_result = world.add(pos, 1);
    try std.testing.expect(duplicate_result == false);
}
