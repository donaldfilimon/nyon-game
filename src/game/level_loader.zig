//! Level Loading/Saving System
//!
//! Provides serialization and deserialization of game levels

const std = @import("std");
const state_mod = @import("state.zig");
const config = @import("../config/constants.zig");

const JSON_TAG_START_ITEMS = "items";
const JSON_TAG_PLAYER = "player";
const JSON_TAG_X = "x";
const JSON_TAG_Y = "y";
const JSON_TAG_COLLECTED = "collected";
const JSON_TAG_WORLD_NAME = "world_name";
const JSON_TAG_WORLD_VERSION = "world_version";
const DEFAULT_WORLD_NAME = "default_world";

pub const LevelData = struct {
    world_name: []const u8,
    world_version: u32,
    player_pos: struct {
        x: f32,
        y: f32,
    },
    items: []ItemData,

    pub fn init(allocator: std.mem.Allocator) !LevelData {
        return LevelData{
            .world_name = try allocator.dupe(u8, DEFAULT_WORLD_NAME),
            .world_version = 1,
            .player_pos = .{ .x = state_mod.PLAYER_START_X, .y = state_mod.PLAYER_START_Y },
            .items = try allocator.alloc(ItemData, 0),
        };
    }

    pub fn deinit(self: *LevelData, allocator: std.mem.Allocator) void {
        allocator.free(self.world_name);
        allocator.free(self.items);
        self.* = undefined;
    }
};

pub const ItemData = struct {
    x: f32,
    y: f32,
    collected: bool,

    pub fn fromGameStateItem(item: state_mod.CollectibleItem) ItemData {
        return ItemData{
            .x = item.x,
            .y = item.y,
            .collected = item.collected,
        };
    }

    pub fn toGameStateItem(self: ItemData) state_mod.CollectibleItem {
        return state_mod.CollectibleItem{
            .x = self.x,
            .y = self.y,
            .collected = self.collected,
        };
    }
};

pub const LevelSaveError = error{
    OutOfMemory,
    InvalidPath,
    WriteFailed,
    ReadFailed,
    InvalidFormat,
};

pub fn saveLevel(game_state: *const state_mod.GameState, path: [:0]const u8, allocator: std.mem.Allocator) !void {
    var json_string = std.ArrayList(u8).initCapacity(allocator, config.Memory.STRING_BUFFER) catch unreachable;
    defer json_string.deinit(allocator);

    try json_string.print(allocator, "{{\n", .{});
    try json_string.print(allocator, "  \"{s}\": \"{s}\",\n", .{ JSON_TAG_WORLD_NAME, DEFAULT_WORLD_NAME });
    try json_string.print(allocator, "  \"{s}\": {},\n", .{ JSON_TAG_WORLD_VERSION, 1 });

    try json_string.print(allocator, "  \"{s}\": {{\n", .{JSON_TAG_PLAYER});
    try json_string.print(allocator, "    \"{s}\": {d:.2},\n", .{ JSON_TAG_X, game_state.player_x });
    try json_string.print(allocator, "    \"{s}\": {d:.2}\n", .{ JSON_TAG_Y, game_state.player_y });
    try json_string.print(allocator, "  }},\n", .{});

    try json_string.print(allocator, "  \"{s}\": [\n", .{JSON_TAG_START_ITEMS});
    for (game_state.items, 0..) |item, i| {
        try json_string.print(allocator, "    {{\n", .{});
        try json_string.print(allocator, "      \"{s}\": {d:.2},\n", .{ JSON_TAG_X, item.x });
        try json_string.print(allocator, "      \"{s}\": {d:.2},\n", .{ JSON_TAG_Y, item.y });
        try json_string.print(allocator, "      \"{s}\": {}\n", .{ JSON_TAG_COLLECTED, item.collected });
        try json_string.print(allocator, "    }}{}", .{if (i < game_state.items.len - 1) "," else ""});
        try json_string.print(allocator, "\n", .{});
    }
    try json_string.print(allocator, "  ]\n", .{});
    try json_string.print(allocator, "}}\n", .{});

    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    try file.writeAll(json_string.items);
}

pub fn loadLevel(path: [:0]const u8, allocator: std.mem.Allocator) !LevelData {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const content = try allocator.alloc(u8, file_size);
    defer allocator.free(content);

    const bytes_read = try file.readAll(content);
    if (bytes_read != file_size) {
        return LevelSaveError.ReadFailed;
    }

    return parseLevelJSON(content, allocator);
}

fn parseLevelJSON(content: []const u8, allocator: std.mem.Allocator) !LevelData {
    var level_data = try LevelData.init(allocator);
    errdefer level_data.deinit(allocator);
    var items = std.ArrayList(ItemData).initCapacity(allocator, config.Game.DEFAULT_ITEM_COUNT) catch unreachable;
    defer items.deinit(allocator);

    var i: usize = 0;
    const content_len = content.len;

    while (i < content_len) {
        skipWhitespace(content, &i);

        if (i >= content_len) break;

        if (content[i] == '"') {
            const key = parseString(content, &i) catch continue;

            skipWhitespace(content, &i);
            if (i >= content_len or content[i] != ':') continue;
            i += 1;
            skipWhitespace(content, &i);

            if (std.mem.eql(u8, key, JSON_TAG_WORLD_NAME)) {
                const world_name = parseString(content, &i) catch DEFAULT_WORLD_NAME;
                allocator.free(level_data.world_name);
                level_data.world_name = try allocator.dupe(u8, world_name);
            } else if (std.mem.eql(u8, key, JSON_TAG_WORLD_VERSION)) {
                level_data.world_version = parseNumber(content, &i) catch 1;
            } else if (std.mem.eql(u8, key, JSON_TAG_PLAYER)) {
                if (i < content_len and content[i] == '{') {
                    i += 1;
                    while (i < content_len and content[i] != '}') {
                        skipWhitespace(content, &i);
                        if (content[i] == '"') {
                            const player_key = parseString(content, &i) catch continue;
                            skipWhitespace(content, &i);
                            if (i < content_len and content[i] == ':') {
                                i += 1;
                                skipWhitespace(content, &i);
                                const value = parseNumber(content, &i) catch 0;
                                if (std.mem.eql(u8, player_key, JSON_TAG_X)) {
                                    level_data.player_pos.x = value;
                                } else if (std.mem.eql(u8, player_key, JSON_TAG_Y)) {
                                    level_data.player_pos.y = value;
                                }
                            }
                        } else {
                            i += 1;
                        }
                    }
                    i += 1;
                }
            } else if (std.mem.eql(u8, key, JSON_TAG_START_ITEMS)) {
                if (i < content_len and content[i] == '[') {
                    i += 1;
                    while (i < content_len and content[i] != ']') {
                        skipWhitespace(content, &i);
                        if (content[i] == '{') {
                            i += 1;
                            var item_data = ItemData{ .x = 0, .y = 0, .collected = false };
                            while (i < content_len and content[i] != '}') {
                                skipWhitespace(content, &i);
                                if (content[i] == '"') {
                                    const item_key = parseString(content, &i) catch continue;
                                    skipWhitespace(content, &i);
                                    if (i < content_len and content[i] == ':') {
                                        i += 1;
                                        skipWhitespace(content, &i);

                                        if (std.mem.eql(u8, item_key, JSON_TAG_X)) {
                                            item_data.x = parseNumber(content, &i) catch 0;
                                        } else if (std.mem.eql(u8, item_key, JSON_TAG_Y)) {
                                            item_data.y = parseNumber(content, &i) catch 0;
                                        } else if (std.mem.eql(u8, item_key, JSON_TAG_COLLECTED)) {
                                            if (i < content_len and content[i] == 't') {
                                                item_data.collected = true;
                                                i += 4;
                                            } else {
                                                item_data.collected = false;
                                                i += 5;
                                            }
                                        }
                                    }
                                } else {
                                    i += 1;
                                }
                            }
                            try items.append(allocator, item_data);
                            i += 1;
                        } else {
                            i += 1;
                        }
                    }
                    i += 1;
                }
            }
        } else {
            i += 1;
        }
    }

    allocator.free(level_data.items);
    level_data.items = try items.toOwnedSlice(allocator);
    return level_data;
}

fn skipWhitespace(content: []const u8, i: *usize) void {
    while (i.* < content.len and std.ascii.isWhitespace(content[i.*])) : (i.* += 1) {}
}

fn parseString(content: []const u8, i: *usize) ![]const u8 {
    if (i.* >= content.len or content[i.*] != '"') return error.InvalidString;

    i.* += 1;
    const start = i.*;

    while (i.* < content.len and content[i.*] != '"') : (i.* += 1) {
        if (content[i.*] == '\\') i.* += 1;
    }

    if (i.* >= content.len) return error.InvalidString;
    i.* += 1;

    return content[start .. i.* - 1];
}

fn parseNumber(content: []const u8, i: *usize) !f32 {
    const start = i.*;

    while (i.* < content.len and (std.ascii.isDigit(content[i.*]) or content[i.*] == '.' or content[i.*] == '-')) : (i.* += 1) {}

    const number_str = content[start..i.*];
    return std.fmt.parseFloat(f32, number_str);
}

pub fn applyLevelData(game_state: *state_mod.GameState, level_data: *const LevelData) void {
    game_state.player_x = level_data.player_pos.x;
    game_state.player_y = level_data.player_pos.y;

    const copy_count = @min(game_state.items.len, level_data.items.len);
    for (0..copy_count) |idx| {
        game_state.items[idx] = level_data.items[idx].toGameStateItem();
    }
}

pub fn exportToGameState(game_state: *state_mod.GameState, allocator: std.mem.Allocator) !LevelData {
    const world_name = try allocator.dupe(u8, DEFAULT_WORLD_NAME);
    errdefer allocator.free(world_name);
    var items = try allocator.alloc(ItemData, game_state.items.len);
    errdefer allocator.free(items);
    for (game_state.items, 0..) |item, i| {
        items[i] = ItemData.fromGameStateItem(item);
    }

    return LevelData{
        .world_name = world_name,
        .world_version = 1,
        .player_pos = .{ .x = game_state.player_x, .y = game_state.player_y },
        .items = items,
    };
}
