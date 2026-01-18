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

/// Encode a SPIR-V opcode with word count
fn makeOpCode(op: u16, word_count: u16) u32 {
    return (@as(u32, word_count) << 16) | @as(u32, op);
}

/// Shader compilation options
pub const CompileOptions = struct {
    /// Entry point name (default: "main")
    entry_point: []const u8 = "main",
    /// Workgroup size for compute shaders
    workgroup_size: [3]u32 = .{ 64, 1, 1 },
    /// Execution model (compute, vertex, fragment, etc.)
    execution_model: Module.ExecutionModel = .glcompute,
    /// Enable 64-bit integer support
    enable_int64: bool = false,
    /// Enable 64-bit float support
    enable_float64: bool = false,
};

/// Compile Zig source to SPIR-V bytecode.
///
/// NOTE: This is currently a stub implementation that generates a minimal valid
/// SPIR-V module. Full compilation from Zig to SPIR-V requires either:
/// - Using Zig's experimental SPIR-V backend (zig build -Dtarget=spirv64-unknown-unknown)
/// - Integrating with an external shader compiler (glslc, dxc, etc.)
///
/// The generated module contains:
/// - Valid SPIR-V magic number and version (1.5)
/// - Shader capability declaration
/// - Memory model (Logical GLSL450)
/// - A void main entry point for GLCompute
///
/// This stub allows the rest of the GPU infrastructure to work while the actual
/// shader compilation pipeline is being developed.
pub fn compileToSpirv(allocator: std.mem.Allocator, zig_source: []const u8) ![]u8 {
    return compileToSpirvWithOptions(allocator, zig_source, .{});
}

/// Compile Zig source to SPIR-V bytecode with custom options.
pub fn compileToSpirvWithOptions(allocator: std.mem.Allocator, zig_source: []const u8, options: CompileOptions) ![]u8 {
    // Parse source for metadata directives (e.g., workgroup size hints)
    var effective_options = options;
    parseSourceMetadata(zig_source, &effective_options);

    // Build a minimal but structurally valid SPIR-V compute shader
    var asm_builder = Assembler.init(allocator);
    defer asm_builder.deinit();

    // Add required capabilities based on options
    try asm_builder.addCapability(.shader);
    if (effective_options.enable_int64) {
        try asm_builder.addCapability(.int64);
    }
    if (effective_options.enable_float64) {
        try asm_builder.addCapability(.float64);
    }

    // Reserve IDs for our types and functions
    const void_type_id = asm_builder.allocId();
    const func_type_id = asm_builder.allocId();
    const main_func_id = asm_builder.allocId();
    const label_id = asm_builder.allocId();

    // Store main function ID for entry point
    asm_builder.entry_point_id = main_func_id;

    // OpMemoryModel Logical GLSL450
    try asm_builder.instructions.append(asm_builder.allocator, makeOpCode(14, 3)); // OpMemoryModel
    try asm_builder.instructions.append(asm_builder.allocator, 0); // Logical
    try asm_builder.instructions.append(asm_builder.allocator, 1); // GLSL450

    // Encode entry point name
    const encoded_name = encodeString(effective_options.entry_point);
    const entry_point_word_count: u16 = @intCast(3 + encoded_name.word_count);

    // OpEntryPoint
    try asm_builder.instructions.append(asm_builder.allocator, makeOpCode(15, entry_point_word_count));
    try asm_builder.instructions.append(asm_builder.allocator, @intFromEnum(effective_options.execution_model));
    try asm_builder.instructions.append(asm_builder.allocator, main_func_id);
    for (encoded_name.words[0..encoded_name.word_count]) |word| {
        try asm_builder.instructions.append(asm_builder.allocator, word);
    }

    // OpExecutionMode for compute shaders
    if (effective_options.execution_model == .glcompute or effective_options.execution_model == .kernel) {
        try asm_builder.instructions.append(asm_builder.allocator, makeOpCode(16, 6)); // OpExecutionMode
        try asm_builder.instructions.append(asm_builder.allocator, main_func_id);
        try asm_builder.instructions.append(asm_builder.allocator, 17); // LocalSize
        try asm_builder.instructions.append(asm_builder.allocator, effective_options.workgroup_size[0]);
        try asm_builder.instructions.append(asm_builder.allocator, effective_options.workgroup_size[1]);
        try asm_builder.instructions.append(asm_builder.allocator, effective_options.workgroup_size[2]);
    }

    // OpTypeVoid %void
    try asm_builder.instructions.append(asm_builder.allocator, makeOpCode(19, 2)); // OpTypeVoid
    try asm_builder.instructions.append(asm_builder.allocator, void_type_id);

    // OpTypeFunction %func_type %void
    try asm_builder.instructions.append(asm_builder.allocator, makeOpCode(33, 3)); // OpTypeFunction
    try asm_builder.instructions.append(asm_builder.allocator, func_type_id);
    try asm_builder.instructions.append(asm_builder.allocator, void_type_id);

    // OpFunction %void None %func_type
    try asm_builder.instructions.append(asm_builder.allocator, makeOpCode(54, 5)); // OpFunction
    try asm_builder.instructions.append(asm_builder.allocator, void_type_id);
    try asm_builder.instructions.append(asm_builder.allocator, main_func_id);
    try asm_builder.instructions.append(asm_builder.allocator, 0); // None
    try asm_builder.instructions.append(asm_builder.allocator, func_type_id);

    // OpLabel %label
    try asm_builder.instructions.append(asm_builder.allocator, makeOpCode(248, 2)); // OpLabel
    try asm_builder.instructions.append(asm_builder.allocator, label_id);

    // OpReturn
    try asm_builder.instructions.append(asm_builder.allocator, makeOpCode(253, 1)); // OpReturn

    // OpFunctionEnd
    try asm_builder.instructions.append(asm_builder.allocator, makeOpCode(56, 1)); // OpFunctionEnd

    return asm_builder.finalize();
}

/// Load pre-compiled SPIR-V bytecode from a file.
/// This is the recommended approach for production use - compile shaders offline
/// using glslc, dxc, or Zig's SPIR-V backend, then load them at runtime.
pub fn loadFromFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        return switch (err) {
            error.FileNotFound => error.ShaderFileNotFound,
            else => error.ShaderLoadError,
        };
    };
    defer file.close();

    const stat = try file.stat();
    if (stat.size == 0 or stat.size > 16 * 1024 * 1024) { // Max 16MB shader
        return error.InvalidShaderSize;
    }

    const data = try allocator.alloc(u8, @intCast(stat.size));
    errdefer allocator.free(data);

    const bytes_read = try file.readAll(data);
    if (bytes_read != stat.size) {
        return error.ShaderLoadError;
    }

    // Validate SPIR-V magic number
    if (data.len < 4) return error.InvalidSpirv;
    const magic = std.mem.bytesAsSlice(u32, data[0..4]);
    if (magic[0] != 0x07230203) return error.InvalidSpirv;

    return data;
}

/// Parse source metadata for shader configuration.
/// Supports directives like:
///   // @workgroup_size(256, 1, 1)
///   // @entry_point("compute_main")
fn parseSourceMetadata(source: []const u8, options: *CompileOptions) void {
    var line_start: usize = 0;
    for (source, 0..) |c, i| {
        if (c == '\n' or i == source.len - 1) {
            const line = source[line_start..i];
            parseMetadataLine(line, options);
            line_start = i + 1;
        }
    }
}

fn parseMetadataLine(line: []const u8, options: *CompileOptions) void {
    // Skip whitespace and look for comment marker
    var i: usize = 0;
    while (i < line.len and (line[i] == ' ' or line[i] == '\t')) : (i += 1) {}

    if (i + 2 >= line.len) return;
    if (line[i] != '/' or line[i + 1] != '/') return;
    i += 2;

    // Skip whitespace after //
    while (i < line.len and (line[i] == ' ' or line[i] == '\t')) : (i += 1) {}

    // Look for @directive
    if (i >= line.len or line[i] != '@') return;
    i += 1;

    // Parse workgroup_size directive
    if (i + 14 <= line.len and std.mem.eql(u8, line[i..][0..14], "workgroup_size")) {
        i += 14;
        // Skip to opening paren
        while (i < line.len and line[i] != '(') : (i += 1) {}
        if (i >= line.len) return;
        i += 1;

        // Parse three numbers
        var dim: usize = 0;
        while (dim < 3 and i < line.len) {
            // Skip whitespace
            while (i < line.len and (line[i] == ' ' or line[i] == '\t')) : (i += 1) {}

            // Parse number
            var num: u32 = 0;
            while (i < line.len and line[i] >= '0' and line[i] <= '9') {
                num = num * 10 + @as(u32, line[i] - '0');
                i += 1;
            }

            if (num > 0) {
                options.workgroup_size[dim] = num;
            }
            dim += 1;

            // Skip comma/whitespace
            while (i < line.len and (line[i] == ',' or line[i] == ' ' or line[i] == '\t')) : (i += 1) {}
        }
    }
}

/// Encoded string result with word count
const EncodedString = struct {
    words: [16]u32,
    word_count: usize,
};

/// Encode a string as SPIR-V words (null-terminated, padded to word boundary)
fn encodeString(s: []const u8) EncodedString {
    var result = EncodedString{
        .words = [_]u32{0} ** 16,
        .word_count = 0,
    };
    var word_idx: usize = 0;
    var byte_idx: usize = 0;

    for (s) |c| {
        result.words[word_idx] |= @as(u32, c) << @intCast(byte_idx * 8);
        byte_idx += 1;
        if (byte_idx == 4) {
            byte_idx = 0;
            word_idx += 1;
            if (word_idx >= 16) break;
        }
    }
    // Null terminator is already there (initialized to 0)
    // Count words including the one with null terminator
    result.word_count = word_idx + 1;

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
};

test "SPIR-V module header" {
    const allocator = std.testing.allocator;
    const spirv_data = compileToSpirv(allocator, "") catch unreachable;
    defer allocator.free(spirv_data);

    var module = try Module.init(allocator, spirv_data);
    defer module.deinit();
}
