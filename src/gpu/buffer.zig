//! GPU Buffer Management

const std = @import("std");

/// Buffer handle for GPU memory
pub const Handle = struct {
    index: u32,
    generation: u32,
};

/// Buffer usage flags
pub const Usage = packed struct {
    vertex: bool = false,
    index: bool = false,
    uniform: bool = false,
    storage: bool = false,
    transfer_src: bool = false,
    transfer_dst: bool = false,
    _padding: u2 = 0,
};

/// GPU buffer
pub const Buffer = struct {
    data: []u8,
    size: usize,
    usage: Usage,
    mapped: bool,

    pub fn upload(self: *Buffer, data: []const u8) !void {
        if (data.len > self.size) return error.BufferTooSmall;
        @memcpy(self.data[0..data.len], data);
    }

    pub fn download(self: *Buffer, out: []u8) !void {
        const len = @min(out.len, self.size);
        @memcpy(out[0..len], self.data[0..len]);
    }
};

/// Buffer pool for GPU memory management
pub const BufferPool = struct {
    allocator: std.mem.Allocator,
    buffers: std.ArrayListUnmanaged(?Buffer),
    free_list: std.ArrayListUnmanaged(u32),
    generations: std.ArrayListUnmanaged(u32),
    total_allocated: usize,
    max_size: usize,

    pub fn init(allocator: std.mem.Allocator, max_size: usize) !BufferPool {
        return BufferPool{
            .allocator = allocator,
            .buffers = .{},
            .free_list = .{},
            .generations = .{},
            .total_allocated = 0,
            .max_size = max_size,
        };
    }

    pub fn deinit(self: *BufferPool) void {
        for (self.buffers.items) |maybe_buf| {
            if (maybe_buf) |buf| {
                self.allocator.free(buf.data);
            }
        }
        self.buffers.deinit(self.allocator);
        self.free_list.deinit(self.allocator);
        self.generations.deinit(self.allocator);
    }

    pub fn allocate(self: *BufferPool, size: usize, usage: Usage) !Handle {
        if (self.total_allocated + size > self.max_size) {
            return error.OutOfMemory;
        }

        const data = try self.allocator.alloc(u8, size);
        @memset(data, 0);

        const buf = Buffer{
            .data = data,
            .size = size,
            .usage = usage,
            .mapped = false,
        };

        var index: u32 = undefined;
        var generation: u32 = undefined;

        if (self.free_list.pop()) |free_idx| {
            index = free_idx;
            self.buffers.items[index] = buf;
            generation = self.generations.items[index];
        } else {
            index = @intCast(self.buffers.items.len);
            try self.buffers.append(self.allocator, buf);
            try self.generations.append(self.allocator, 0);
            generation = 0;
        }

        self.total_allocated += size;

        return Handle{ .index = index, .generation = generation };
    }

    pub fn get(self: *BufferPool, handle: Handle) ?*Buffer {
        if (handle.index >= self.buffers.items.len) return null;
        if (self.generations.items[handle.index] != handle.generation) return null;
        if (self.buffers.items[handle.index]) |*buf| {
            return buf;
        }
        return null;
    }

    pub fn free(self: *BufferPool, handle: Handle) void {
        if (handle.index >= self.buffers.items.len) return;
        if (self.generations.items[handle.index] != handle.generation) return;

        if (self.buffers.items[handle.index]) |buf| {
            self.total_allocated -= buf.size;
            self.allocator.free(buf.data);
            self.buffers.items[handle.index] = null;
            self.generations.items[handle.index] += 1;
            self.free_list.append(self.allocator, handle.index) catch {};
        }
    }
};

test "buffer pool" {
    const allocator = std.testing.allocator;
    var pool = try BufferPool.init(allocator, 1024 * 1024);
    defer pool.deinit();

    const handle = try pool.allocate(256, .{ .storage = true });
    const buf = pool.get(handle).?;

    const data = [_]u8{ 1, 2, 3, 4 };
    try buf.upload(&data);

    var out: [4]u8 = undefined;
    try buf.download(&out);
    try std.testing.expectEqualSlices(u8, &data, &out);

    pool.free(handle);
    try std.testing.expect(pool.get(handle) == null);
}
