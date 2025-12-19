//! Advanced Rendering Example - Complete render graph pipeline
//!
//! This example demonstrates how to set up and use the advanced rendering
//! pipeline with render graphs, multiple passes, and post-processing effects.

const std = @import("std");
const nyon = @import("../nyon_game.zig");
const render_graph = @import("../rendering/render_graph.zig");
const passes = @import("../rendering/passes/passes.zig");
const resources = @import("../rendering/resources/resources.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize engine
    var engine = try nyon.Engine.init(allocator, .{
        .width = 1920,
        .height = 1080,
        .title = "Nyon Advanced Rendering Demo",
    });
    defer engine.deinit();

    // Create render graph
    var graph = render_graph.RenderGraph.init(allocator);
    defer graph.deinit();

    // Set up resource cache
    var resource_cache = resources.ResourceCache.init(allocator);
    defer resource_cache.deinit();

    // Configure rendering pipeline
    try setupRenderingPipeline(&graph, &resource_cache, 1920, 1080);

    // Main render loop
    var frame_count: usize = 0;
    while (!engine.shouldClose()) {
        engine.pollEvents();

        // Update scene (would update transforms, animations, etc.)
        updateScene(frame_count);

        // Execute render graph
        try graph.execute();

        // Present the final result
        presentFinalImage(&graph);

        // UI and debug info
        drawUI(&graph, frame_count);

        frame_count += 1;
    }

    std.debug.print("Advanced rendering demo completed!\n", .{});
}

/// Set up the complete rendering pipeline
fn setupRenderingPipeline(
    graph: *render_graph.RenderGraph,
    cache: *resources.ResourceCache,
    width: u32,
    height: u32,
) !void {
    // Create render targets
    const color_target = try graph.createResource(.{
        .render_target = .{
            .width = width,
            .height = height,
            .format = .rgba8,
            .clear_color = nyon.Color.init(135, 206, 235, 255), // Sky blue
        },
    });

    const normal_target = try graph.createResource(.{
        .render_target = .{
            .width = width,
            .height = height,
            .format = .rgba8,
        },
    });

    const depth_target = try graph.createResource(.{
        .depth_stencil = .{
            .width = width,
            .height = height,
            .format = .depth24_stencil8,
            .clear_depth = 1.0,
        },
    });

    const bloom_target = try graph.createResource(.{
        .render_target = .{
            .width = width / 4,
            .height = height / 4,
            .format = .rgba8,
        },
    });

    const final_target = try graph.createResource(.{
        .render_target = .{
            .width = width,
            .height = height,
            .format = .rgba8,
        },
    });

    // Create shadow map for directional light
    const shadow_map = try graph.createResource(.{
        .depth_stencil = .{
            .width = 2048,
            .height = 2048,
            .format = .depth32f,
        },
    });

    // Add render passes
    std.debug.print("Setting up render passes...\n", .{});

    // 1. Shadow mapping pass
    _ = try graph.addPass(try passes.ShadowMapPass.create(
        allocator,
        shadow_map,
        createLightViewProjectionMatrix(), // Would compute actual light matrix
    ));

    // 2. Geometry pass (G-buffer)
    _ = try graph.addPass(try passes.GeometryPass.create(
        allocator,
        color_target,
        depth_target,
        normal_target,
    ));

    // 3. Deferred lighting pass
    _ = try graph.addPass(try passes.DeferredLightingPass.create(
        allocator,
        color_target,
        color_target, // albedo (would be separate target)
        normal_target,
        depth_target,
    ));

    // 4. Bloom extraction and blur
    _ = try graph.addPass(try createBloomExtractPass(graph, color_target, bloom_target));
    _ = try graph.addPass(try createBloomBlurPass(graph, bloom_target, bloom_target));

    // 5. Post-processing (tone mapping, bloom composite, etc.)
    _ = try graph.addPass(try passes.PostProcessPass.create(
        allocator,
        color_target,
        final_target,
        &[_]passes.PostProcessPass.Effect{
            .tone_mapping,
            .bloom,
            .color_grading,
            .fxaa,
        },
    ));

    // 6. UI rendering
    _ = try graph.addPass(try passes.UIPass.create(allocator, final_target));

    // 7. Debug visualization
    _ = try graph.addPass(try passes.DebugPass.create(allocator, final_target, depth_target));

    std.debug.print("Render pipeline configured with {} passes\n", .{graph.passes.items.len});
}

/// Create a custom bloom extraction pass
fn createBloomExtractPass(
    graph: *render_graph.RenderGraph,
    input_target: render_graph.ResourceHandle,
    output_target: render_graph.ResourceHandle,
) !render_graph.PassDesc {
    return .{
        .name = "BloomExtract",
        .color_attachments = &[_]render_graph.Attachment{.{
            .resource = output_target,
            .load_op = .dont_care,
            .store_op = .store,
        }},
        .input_attachments = &[_]render_graph.ResourceHandle{input_target},
        .execute = executeBloomExtractPass,
    };
}

/// Execute bloom extraction
fn executeBloomExtractPass(context: *render_graph.RenderContext) void {
    _ = context;
    // In full implementation, this would:
    // 1. Sample input texture
    // 2. Apply brightness threshold
    // 3. Extract bright areas for bloom
    // 4. Downsample to bloom buffer
}

/// Create a bloom blur pass
fn createBloomBlurPass(
    graph: *render_graph.RenderGraph,
    input_target: render_graph.ResourceHandle,
    output_target: render_graph.ResourceHandle,
) !render_graph.PassDesc {
    return .{
        .name = "BloomBlur",
        .color_attachments = &[_]render_graph.Attachment{.{
            .resource = output_target,
            .load_op = .load,
            .store_op = .store,
        }},
        .input_attachments = &[_]render_graph.ResourceHandle{input_target},
        .execute = executeBloomBlurPass,
    };
}

/// Execute bloom blur
fn executeBloomBlurPass(context: *render_graph.RenderContext) void {
    _ = context;
    // In full implementation, this would:
    // 1. Apply Gaussian blur to bloom texture
    // 2. Multiple passes for better quality
    // 3. Use separable blur for performance
}

/// Create a light view-projection matrix for shadows
fn createLightViewProjectionMatrix() nyon.Matrix {
    // Simplified: would compute actual light matrix
    return nyon.matrixIdentity();
}

/// Update scene state each frame
fn updateScene(frame_count: usize) void {
    // Update camera
    // Update object transforms
    // Update lighting
    // Update animations
    _ = frame_count;
}

/// Present the final rendered image
fn presentFinalImage(graph: *const render_graph.RenderGraph) void {
    // In full implementation, this would copy the final render target to the screen
    _ = graph;
}

/// Draw UI overlay with rendering stats
fn drawUI(graph: *const render_graph.RenderGraph, frame_count: usize) void {
    const stats = graph.getStats();
    std.debug.print("\rFrame: {}, Passes: {}, Resources: {}   ", .{ frame_count, stats.passes, stats.resources });
}

// ============================================================================
// Advanced Pipeline Examples
// ============================================================================

/// Example: Forward rendering pipeline
pub fn createForwardPipeline(
    graph: *render_graph.RenderGraph,
    cache: *resources.ResourceCache,
    width: u32,
    height: u32,
) !void {
    // Forward rendering: render geometry directly with lighting
    var builder = passes.RenderGraphBuilder.init(cache.allocator, graph);
    try builder.buildForwardPipeline(width, height);

    // Add shadow mapping
    const shadow_map = try graph.createResource(.{
        .depth_stencil = .{
            .width = 2048,
            .height = 2048,
            .format = .depth32f,
        },
    });

    _ = try graph.addPass(try passes.ShadowMapPass.create(
        cache.allocator,
        shadow_map,
        nyon.matrixIdentity(), // Would be actual light matrix
    ));
}

/// Example: Physically-based rendering (PBR) pipeline
pub fn createPBRPipeline(
    graph: *render_graph.RenderGraph,
    cache: *resources.ResourceCache,
    width: u32,
    height: u32,
) !void {
    // PBR requires more G-buffer targets
    const albedo_target = try graph.createResource(.{
        .render_target = .{ .width = width, .height = height, .format = .rgba8 },
    });

    const normal_target = try graph.createResource(.{
        .render_target = .{ .width = width, .height = height, .format = .rgba8 },
    });

    const material_target = try graph.createResource(.{
        .render_target = .{ .width = width, .height = height, .format = .rgba8 },
    });

    const depth_target = try graph.createResource(.{
        .depth_stencil = .{ .width = width, .height = height, .format = .depth24_stencil8 },
    });

    // PBR geometry pass outputs material properties
    _ = try graph.addPass(try createPBRGeometryPass(graph, cache.allocator, albedo_target, normal_target, material_target, depth_target));

    // PBR lighting uses image-based lighting, reflections, etc.
    const final_target = try graph.createResource(.{
        .render_target = .{ .width = width, .height = height, .format = .rgba8 },
    });

    _ = try graph.addPass(try createPBRLightingPass(graph, cache.allocator, final_target, albedo_target, normal_target, material_target, depth_target));
}

/// Create PBR geometry pass
fn createPBRGeometryPass(
    graph: *render_graph.RenderGraph,
    allocator: std.mem.Allocator,
    albedo: render_graph.ResourceHandle,
    normal: render_graph.ResourceHandle,
    material: render_graph.ResourceHandle,
    depth: render_graph.ResourceHandle,
) !render_graph.PassDesc {
    _ = allocator;

    return .{
        .name = "PBRGeometry",
        .color_attachments = &[_]render_graph.Attachment{
            .{ .resource = albedo, .load_op = .clear, .store_op = .store },
            .{ .resource = normal, .load_op = .clear, .store_op = .store },
            .{ .resource = material, .load_op = .clear, .store_op = .store },
        },
        .depth_attachment = .{ .resource = depth, .load_op = .clear, .store_op = .store },
        .execute = executePBRGeometryPass,
    };
}

/// Execute PBR geometry pass
fn executePBRGeometryPass(context: *render_graph.RenderContext) void {
    _ = context;
    // Output: albedo (RGB), AO (A)
    // Output: normal (RGB), unused (A)
    // Output: metallic (R), roughness (G), emissive (B), unused (A)
}

/// Create PBR lighting pass
fn createPBRLightingPass(
    graph: *render_graph.RenderGraph,
    allocator: std.mem.Allocator,
    output: render_graph.ResourceHandle,
    albedo: render_graph.ResourceHandle,
    normal: render_graph.ResourceHandle,
    material: render_graph.ResourceHandle,
    depth: render_graph.ResourceHandle,
) !render_graph.PassDesc {
    _ = allocator;

    return .{
        .name = "PBRLighting",
        .color_attachments = &[_]render_graph.Attachment{
            .{ .resource = output, .load_op = .clear, .store_op = .store },
        },
        .input_attachments = &[_]render_graph.ResourceHandle{ albedo, normal, material, depth },
        .execute = executePBRLightingPass,
    };
}

/// Execute PBR lighting pass
fn executePBRLightingPass(context: *render_graph.RenderContext) void {
    _ = context;
    // Implement Cook-Torrance BRDF
    // Image-based lighting
    // Screen-space reflections
    // Area lights, etc.
}

// ============================================================================
// Performance and Debugging
// ============================================================================

/// Performance monitoring for render graphs
pub const RenderGraphProfiler = struct {
    frame_times: std.ArrayList(u64),
    pass_times: std.AutoHashMap(render_graph.PassId, std.ArrayList(u64)),

    pub fn init(allocator: std.mem.Allocator) RenderGraphProfiler {
        return .{
            .frame_times = std.ArrayList(u64).init(allocator),
            .pass_times = std.AutoHashMap(render_graph.PassId, std.ArrayList(u64)).init(allocator),
        };
    }

    pub fn deinit(self: *RenderGraphProfiler) void {
        self.frame_times.deinit();

        var iter = self.pass_times.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.pass_times.deinit();
    }

    pub fn recordFrameTime(self: *RenderGraphProfiler, time_ns: u64) !void {
        try self.frame_times.append(time_ns);
    }

    pub fn recordPassTime(self: *RenderGraphProfiler, pass_id: render_graph.PassId, time_ns: u64) !void {
        const gop = try self.pass_times.getOrPut(pass_id);
        if (!gop.found_existing) {
            gop.value_ptr.* = std.ArrayList(u64).init(self.pass_times.allocator);
        }
        try gop.value_ptr.append(time_ns);
    }

    pub fn getAverageFrameTime(self: *const RenderGraphProfiler) f32 {
        if (self.frame_times.items.len == 0) return 0;

        var total: u64 = 0;
        for (self.frame_times.items) |time| {
            total += time;
        }
        return @as(f32, @floatFromInt(total)) / @as(f32, @floatFromInt(self.frame_times.items.len));
    }

    pub fn getAveragePassTime(self: *const RenderGraphProfiler, pass_id: render_graph.PassId) f32 {
        if (self.pass_times.get(pass_id)) |times| {
            if (times.items.len == 0) return 0;

            var total: u64 = 0;
            for (times.items) |time| {
                total += time;
            }
            return @as(f32, @floatFromInt(total)) / @as(f32, @floatFromInt(times.items.len));
        }
        return 0;
    }

    pub fn printReport(self: *const RenderGraphProfiler) void {
        const avg_frame = self.getAverageFrameTime() / 1_000_000.0; // Convert to ms
        std.debug.print("=== Render Graph Performance Report ===\n", .{});
        std.debug.print("Average frame time: {d:.2}ms ({d:.1}fps)\n", .{ avg_frame, 1000.0 / avg_frame });

        var iter = self.pass_times.iterator();
        while (iter.next()) |entry| {
            const pass_id = entry.key_ptr.*;
            const avg_pass = self.getAveragePassTime(pass_id) / 1_000.0; // Convert to μs
            std.debug.print("Pass {}: {d:.1}μs average\n", .{ pass_id, avg_pass });
        }
    }
};

// ============================================================================
// Usage Examples
// ============================================================================

/// Example: Setting up a complete rendering pipeline
pub fn setupCompletePipeline() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var graph = render_graph.RenderGraph.init(allocator);
    defer graph.deinit();

    var cache = resources.ResourceCache.init(allocator);
    defer cache.deinit();

    var profiler = RenderGraphProfiler.init(allocator);
    defer profiler.deinit();

    // Setup PBR pipeline
    try createPBRPipeline(&graph, &cache, 1920, 1080);

    // Compile graph
    try graph.compile();

    // Example frame
    const frame_start = std.time.nanoTimestamp();
    try graph.execute();
    const frame_time = std.time.nanoTimestamp() - frame_start;

    try profiler.recordFrameTime(frame_time);
    profiler.printReport();
}
