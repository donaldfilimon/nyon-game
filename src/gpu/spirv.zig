//! SPIR-V Backend for GPU Compute

const std = @import("std");
const builtin = @import("builtin");

/// SPIR-V module binary
pub const Module = struct {
    code: []const u32,
    allocator: std.mem.Allocator,
    entry_points: std.StringHashMap(EntryPoint),

    pub const EntryPoint = struct {
        name: []const u8,
        execution_model: ExecutionModel,
        workgroup_size: [3]u32,
    };

    pub const ExecutionModel = enum(u32) {
        vertex = 0,
        tessellation_control = 1,
        tessellation_evaluation = 2,
        geometry = 3,
        fragment = 4,
        glcompute = 5,
        kernel = 6,
    };

    pub fn init(allocator: std.mem.Allocator, spirv_bytes: []const u8) !Module {
        if (spirv_bytes.len < 20) return error.InvalidSpirv;
        if (spirv_bytes.len % 4 != 0) return error.InvalidSpirv;

        const code: []const u32 = @alignCast(std.mem.bytesAsSlice(u32, spirv_bytes));
        if (code[0] != 0x07230203) return error.InvalidSpirv;

        const entry_points = std.StringHashMap(EntryPoint).init(allocator);

        return Module{
            .code = code,
            .allocator = allocator,
            .entry_points = entry_points,
        };
    }

    pub fn deinit(self: *Module) void {
        self.entry_points.deinit();
    }

    pub fn getEntryPoint(self: *const Module, name: []const u8) ?EntryPoint {
        return self.entry_points.get(name);
    }
};

/// SPIR-V address spaces
pub const AddressSpace = enum(u32) {
    function = 0,
    uniform_constant = 1,
    input = 2,
    output = 3,
    workgroup = 4,
    cross_workgroup = 5,
    private = 6,
    storage_buffer = 12,
    push_constant = 9,

    pub fn toZigAddrSpace(self: AddressSpace) std.builtin.AddressSpace {
        return switch (self) {
            .workgroup => .shared,
            .private, .function => .generic,
            else => .global,
        };
    }
};

/// Descriptor binding
pub const Binding = struct {
    set: u32 = 0,
    binding: u32,
    descriptor_type: DescriptorType,
    array_size: u32 = 1,

    pub const DescriptorType = enum {
        uniform_buffer,
        storage_buffer,
        storage_image,
        sampled_image,
        sampler,
    };
};

/// Compile to SPIR-V stub
pub fn compileToSpirv(allocator: std.mem.Allocator, zig_source: []const u8) ![]u8 {
    _ = zig_source;
    const header = [_]u32{ 0x07230203, 0x00010500, 0x00000000, 1, 0 };
    const result = try allocator.alloc(u8, header.len * 4);
    @memcpy(result, std.mem.sliceAsBytes(&header));
    return result;
}

/// SPIR-V Assembler
pub const Assembler = struct {
    allocator: std.mem.Allocator,
    instructions: std.ArrayListUnmanaged(u32),
    next_id: u32,
    capabilities: std.ArrayListUnmanaged(Capability),
    entry_point_id: ?u32,

    pub const Capability = enum(u32) {
        shader = 1,
        kernel = 6,
        int64 = 11,
        float64 = 10,
        addresses = 4,
    };

    pub fn init(allocator: std.mem.Allocator) Assembler {
        return .{
            .allocator = allocator,
            .instructions = .{},
            .next_id = 1,
            .capabilities = .{},
            .entry_point_id = null,
        };
    }

    pub fn deinit(self: *Assembler) void {
        self.instructions.deinit(self.allocator);
        self.capabilities.deinit(self.allocator);
    }

    pub fn allocId(self: *Assembler) u32 {
        const id = self.next_id;
        self.next_id += 1;
        return id;
    }

    pub fn addCapability(self: *Assembler, cap: Capability) !void {
        try self.capabilities.append(self.allocator, cap);
    }

    pub fn finalize(self: *Assembler) ![]u8 {
        var output = std.ArrayListUnmanaged(u32){};
        defer output.deinit(self.allocator);

        try output.append(self.allocator, 0x07230203);
        try output.append(self.allocator, 0x00010500);
        try output.append(self.allocator, 0x00000000);
        try output.append(self.allocator, self.next_id);
        try output.append(self.allocator, 0);

        for (self.capabilities.items) |cap| {
            try output.append(self.allocator, makeOpCode(17, 2));
            try output.append(self.allocator, @intFromEnum(cap));
        }

        try output.appendSlice(self.allocator, self.instructions.items);

        const result = try self.allocator.alloc(u8, output.items.len * 4);
        @memcpy(result, std.mem.sliceAsBytes(output.items));
        return result;
    }

    fn makeOpCode(op: u16, word_count: u16) u32 {
        return (@as(u32, word_count) << 16) | @as(u32, op);
    }
};

test "SPIR-V module header" {
    const allocator = std.testing.allocator;
    const spirv_data = compileToSpirv(allocator, "") catch unreachable;
    defer allocator.free(spirv_data);

    var module = try Module.init(allocator, spirv_data);
    defer module.deinit();
}
