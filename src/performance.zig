const std = @import("std");
const raylib = @import("raylib");
const nyon = @import("nyon_game");

/// Performance Optimization System
///
/// Provides Level of Detail (LOD), geometry instancing, and culling optimizations
/// for improved rendering performance in the Nyon Game Engine.
pub const PerformanceSystem = struct {
    allocator: std.mem.Allocator,

    /// LOD (Level of Detail) management
    lod_system: LODSystem,

    /// Geometry instancing system
    instancing_system: InstancingSystem,

    /// Frustum culling system
    culling_system: CullingSystem,

    /// Performance statistics
    stats: PerformanceStats,

    /// Initialize the performance system
    pub fn init(allocator: std.mem.Allocator) PerformanceSystem {
        return .{
            .allocator = allocator,
            .lod_system = LODSystem.init(allocator),
            .instancing_system = InstancingSystem.init(allocator),
            .culling_system = CullingSystem.init(allocator),
            .stats = PerformanceStats.init(),
        };
    }

    /// Deinitialize the performance system
    pub fn deinit(self: *PerformanceSystem) void {
        self.lod_system.deinit();
        self.instancing_system.deinit();
        self.culling_system.deinit();
    }

    /// Update performance optimizations
    pub fn update(self: *PerformanceSystem, camera: raylib.Camera3D, dt: f32) void {
        _ = dt; // Not used yet

        // Update culling system with camera
        self.culling_system.updateFrustum(camera);

        // Update LOD system
        self.lod_system.updateLOD(camera.position);
    }

    /// Get performance statistics
    pub fn getStats(self: *const PerformanceSystem) *const PerformanceStats {
        return &self.stats;
    }

    /// Reset performance statistics
    pub fn resetStats(self: *PerformanceSystem) void {
        self.stats.reset();
    }
};

// ============================================================================
// Level of Detail (LOD) System
// ============================================================================

pub const LODSystem = struct {
    allocator: std.mem.Allocator,

    /// LOD groups containing different detail levels
    lod_groups: std.ArrayList(LODGroup),

    /// LOD distances configuration
    distances: LODDistances,

    pub const LODLevel = enum {
        high_detail, // Closest - full geometry
        medium_detail, // Medium distance - simplified geometry
        low_detail, // Far - very simplified or billboard
        culled, // Too far - not rendered
    };

    pub const LODGroup = struct {
        entity_id: usize,
        position: raylib.Vector3,
        lod_levels: std.ArrayList(LODGeometry),
        current_lod: LODLevel,
        last_distance: f32,

        pub const LODGeometry = union(enum) {
            mesh: raylib.Mesh,
            model: raylib.Model,
            billboard: raylib.Texture,
        };
    };

    pub const LODDistances = struct {
        high_to_medium: f32 = 20.0,
        medium_to_low: f32 = 50.0,
        low_to_culled: f32 = 100.0,
    };

    /// Initialize LOD system
    pub fn init(allocator: std.mem.Allocator) LODSystem {
        return .{
            .allocator = allocator,
            .lod_groups = std.ArrayList(LODGroup).initCapacity(allocator, 0) catch unreachable,
            .distances = LODDistances{},
        };
    }

    /// Deinitialize LOD system
    pub fn deinit(self: *LODSystem) void {
        for (self.lod_groups.items) |*group| {
            for (group.lod_levels.items) |*level| {
                switch (level.*) {
                    .mesh => |mesh| raylib.unloadMesh(mesh),
                    .model => |model| raylib.unloadModel(model),
                    .billboard => |texture| raylib.unloadTexture(texture),
                }
            }
            group.lod_levels.deinit(self.allocator);
        }
        self.lod_groups.deinit(self.allocator);
    }

    /// Create LOD group for an entity
    pub fn createLODGroup(self: *LODSystem, entity_id: usize, position: raylib.Vector3) !usize {
        const group_id = self.lod_groups.items.len;

        var group = LODGroup{
            .entity_id = entity_id,
            .position = position,
            .lod_levels = std.ArrayList(LODGroup.LODGeometry).initCapacity(self.allocator, 0) catch unreachable,
            .current_lod = .high_detail,
            .last_distance = 0,
        };

        // Add placeholder LOD levels (would be populated with actual geometry)
        try group.lod_levels.append(self.allocator, .{ .mesh = raylib.genMeshCube(1.0, 1.0, 1.0) }); // High detail
        try group.lod_levels.append(self.allocator, .{ .mesh = raylib.genMeshCube(1.0, 1.0, 1.0) }); // Medium detail
        try group.lod_levels.append(self.allocator, .{ .mesh = raylib.genMeshCube(1.0, 1.0, 1.0) }); // Low detail

        try self.lod_groups.append(self.allocator, group);
        return group_id;
    }

    /// Update LOD levels based on camera position
    pub fn updateLOD(self: *LODSystem, camera_position: raylib.Vector3) void {
        for (self.lod_groups.items) |*group| {
            const distance = camera_position.distance(group.position);
            group.last_distance = distance;

            // Determine appropriate LOD level
            const new_lod = if (distance < self.distances.high_to_medium) .high_detail else if (distance < self.distances.medium_to_low) .medium_detail else if (distance < self.distances.low_to_culled) .low_detail else .culled;

            group.current_lod = new_lod;
        }
    }

    /// Get current geometry for an LOD group
    pub fn getCurrentGeometry(self: *const LODSystem, group_id: usize) ?LODGroup.LODGeometry {
        if (group_id >= self.lod_groups.items.len) return null;

        const group = &self.lod_groups.items[group_id];
        const lod_index = switch (group.current_lod) {
            .high_detail => 0,
            .medium_detail => 1,
            .low_detail => 2,
            .culled => return null,
        };

        if (lod_index < group.lod_levels.items.len) {
            return group.lod_levels.items[lod_index];
        }

        return null;
    }

    /// Set LOD distances
    pub fn setLODDistances(self: *LODSystem, distances: LODDistances) void {
        self.distances = distances;
    }

    /// Get LOD statistics
    pub fn getLODStats(self: *const LODSystem) struct {
        total_groups: usize,
        high_detail: usize,
        medium_detail: usize,
        low_detail: usize,
        culled: usize,
    } {
        var stats = std.mem.zeroes(struct {
            total_groups: usize,
            high_detail: usize,
            medium_detail: usize,
            low_detail: usize,
            culled: usize,
        });

        stats.total_groups = self.lod_groups.items.len;

        for (self.lod_groups.items) |group| {
            switch (group.current_lod) {
                .high_detail => stats.high_detail += 1,
                .medium_detail => stats.medium_detail += 1,
                .low_detail => stats.low_detail += 1,
                .culled => stats.culled += 1,
            }
        }

        return stats;
    }
};

// ============================================================================
// Geometry Instancing System
// ============================================================================

pub const InstancingSystem = struct {
    allocator: std.mem.Allocator,

    /// Instance groups for efficient rendering
    instance_groups: std.ArrayList(InstanceGroup),

    /// Maximum instances per draw call
    max_instances_per_draw: usize,

    pub const InstanceGroup = struct {
        mesh: raylib.Mesh,
        material: raylib.Material,
        instances: std.ArrayList(InstanceData),
        transforms: std.ArrayList(raylib.Matrix),
        instance_buffer: ?raylib.Texture, // For GPU instancing

        pub const InstanceData = struct {
            position: raylib.Vector3,
            rotation: raylib.Vector3, // Euler angles
            scale: raylib.Vector3,
            color: raylib.Color,
        };
    };

    /// Initialize instancing system
    pub fn init(allocator: std.mem.Allocator) InstancingSystem {
        return .{
            .allocator = allocator,
            .instance_groups = std.ArrayList(InstanceGroup).initCapacity(allocator, 0) catch unreachable,
            .max_instances_per_draw = 1024,
        };
    }

    /// Deinitialize instancing system
    pub fn deinit(self: *InstancingSystem) void {
        for (self.instance_groups.items) |*group| {
            group.instances.deinit(self.allocator);
            group.transforms.deinit(self.allocator);
            if (group.instance_buffer) |buffer| {
                raylib.unloadTexture(buffer);
            }
            // Note: mesh and material are owned by asset system
        }
        self.instance_groups.deinit(self.allocator);
    }

    /// Create instance group
    pub fn createInstanceGroup(self: *InstancingSystem, mesh: raylib.Mesh, material: raylib.Material) !usize {
        const group_id = self.instance_groups.items.len;

        const group = InstanceGroup{
            .mesh = mesh,
            .material = material,
            .instances = std.ArrayList(InstanceGroup.InstanceData).initCapacity(self.allocator, 0) catch unreachable,
            .transforms = std.ArrayList(raylib.Matrix).initCapacity(self.allocator, 0) catch unreachable,
            .instance_buffer = null,
        };

        try self.instance_groups.append(self.allocator, group);
        return group_id;
    }

    /// Add instance to group
    pub fn addInstance(self: *InstancingSystem, group_id: usize, instance_data: InstanceGroup.InstanceData) !void {
        if (group_id >= self.instance_groups.items.len) return error.InvalidGroupId;

        const group = &self.instance_groups.items[group_id];
        try group.instances.append(self.allocator, instance_data);

        // Update transform matrix
        const transform = self.calculateTransform(instance_data);
        try group.transforms.append(self.allocator, transform);
    }

    /// Update instance in group
    pub fn updateInstance(self: *InstancingSystem, group_id: usize, instance_index: usize, instance_data: InstanceGroup.InstanceData) !void {
        if (group_id >= self.instance_groups.items.len) return error.InvalidGroupId;

        const group = &self.instance_groups.items[group_id];
        if (instance_index >= group.instances.items.len) return error.InvalidInstanceIndex;

        group.instances.items[instance_index] = instance_data;
        group.transforms.items[instance_index] = self.calculateTransform(instance_data);
    }

    /// Remove instance from group
    pub fn removeInstance(self: *InstancingSystem, group_id: usize, instance_index: usize) !void {
        if (group_id >= self.instance_groups.items.len) return error.InvalidGroupId;

        const group = &self.instance_groups.items[group_id];
        if (instance_index >= group.instances.items.len) return error.InvalidInstanceIndex;

        _ = group.instances.orderedRemove(instance_index);
        _ = group.transforms.orderedRemove(instance_index);
    }

    /// Render all instance groups
    pub fn renderInstances(self: *InstancingSystem) void {
        for (self.instance_groups.items) |*group| {
            if (group.instances.items.len == 0) continue;

            // For now, render each instance individually
            // In a full implementation, this would use GPU instancing
            for (group.instances.items) |instance| {
                const model = raylib.loadModelFromMesh(group.mesh) catch continue;
                defer raylib.unloadModel(model);

                model.materials[0] = group.material;
                model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE].color = instance.color;

                // Apply transform
                raylib.drawModelEx(model, instance.position, .{ .x = 0, .y = 1, .z = 0 }, instance.rotation.y, instance.scale, instance.color);
            }
        }
    }

    /// Calculate transform matrix from instance data
    fn calculateTransform(self: *InstancingSystem, instance: InstanceGroup.InstanceData) raylib.Matrix {
        _ = self; // unused

        // Scale -> Rotate -> Translate
        var transform = raylib.Matrix.identity();

        // Apply scale
        transform = transform.multiply(raylib.Matrix.scale(instance.scale.x, instance.scale.y, instance.scale.z));

        const deg_to_rad: f32 = @as(f32, std.math.pi / 180.0);

        // Apply rotations (Z, Y, X)
        transform = transform.multiply(raylib.Matrix.rotateZ(instance.rotation.z * deg_to_rad));
        transform = transform.multiply(raylib.Matrix.rotateY(instance.rotation.y * deg_to_rad));
        transform = transform.multiply(raylib.Matrix.rotateX(instance.rotation.x * deg_to_rad));

        // Apply translation
        transform = transform.multiply(raylib.Matrix.translate(instance.position.x, instance.position.y, instance.position.z));

        return transform;
    }

    /// Get instancing statistics
    pub fn getInstancingStats(self: *const InstancingSystem) struct {
        total_groups: usize,
        total_instances: usize,
        average_instances_per_group: f32,
    } {
        var total_instances: usize = 0;

        for (self.instance_groups.items) |group| {
            total_instances += group.instances.items.len;
        }

        const avg_instances = if (self.instance_groups.items.len > 0)
            @as(f32, @floatFromInt(total_instances)) / @as(f32, @floatFromInt(self.instance_groups.items.len))
        else
            0;

        return .{
            .total_groups = self.instance_groups.items.len,
            .total_instances = total_instances,
            .average_instances_per_group = avg_instances,
        };
    }
};

// ============================================================================
// Frustum Culling System
// ============================================================================

pub const CullingSystem = struct {
    allocator: std.mem.Allocator,

    /// View frustum planes
    frustum_planes: [6]raylib.Vector4,

    /// Culling statistics
    stats: CullingStats,

    pub const CullingStats = struct {
        objects_tested: usize = 0,
        objects_passed: usize = 0,
        objects_failed: usize = 0,

        pub fn reset(self: *CullingStats) void {
            self.objects_tested = 0;
            self.objects_passed = 0;
            self.objects_failed = 0;
        }
    };

    /// Initialize culling system
    pub fn init(allocator: std.mem.Allocator) CullingSystem {
        return .{
            .allocator = allocator,
            .frustum_planes = [_]raylib.Vector4{.{ .x = 0, .y = 0, .z = 0, .w = 0 }} ** 6,
            .stats = CullingStats{},
        };
    }

    /// Deinitialize culling system
    pub fn deinit(self: *CullingSystem) void {
        _ = self; // Nothing to deinit
    }

    /// Update frustum planes from camera
    pub fn updateFrustum(self: *CullingSystem, camera: raylib.Camera3D) void {
        // Calculate view-projection matrix
        const view_matrix = raylib.getCameraMatrix(camera);
        const aspect = @as(f64, @floatFromInt(raylib.getScreenWidth())) / @as(f64, @floatFromInt(raylib.getScreenHeight()));
        const proj_matrix = raylib.Matrix.perspective(@as(f64, camera.fovy) * std.math.pi / 180.0, aspect, 0.1, 1000.0);
        const view_proj = view_matrix.multiply(proj_matrix);

        // Extract frustum planes from view-projection matrix
        // Left plane
        self.frustum_planes[0] = raylib.Vector4{
            .x = view_proj.m14 + view_proj.m11,
            .y = view_proj.m24 + view_proj.m21,
            .z = view_proj.m34 + view_proj.m31,
            .w = view_proj.m44 + view_proj.m41,
        };

        // Right plane
        self.frustum_planes[1] = raylib.Vector4{
            .x = view_proj.m14 - view_proj.m11,
            .y = view_proj.m24 - view_proj.m21,
            .z = view_proj.m34 - view_proj.m31,
            .w = view_proj.m44 - view_proj.m41,
        };

        // Bottom plane
        self.frustum_planes[2] = raylib.Vector4{
            .x = view_proj.m14 + view_proj.m12,
            .y = view_proj.m24 + view_proj.m22,
            .z = view_proj.m34 + view_proj.m32,
            .w = view_proj.m44 + view_proj.m42,
        };

        // Top plane
        self.frustum_planes[3] = raylib.Vector4{
            .x = view_proj.m14 - view_proj.m12,
            .y = view_proj.m24 - view_proj.m22,
            .z = view_proj.m34 - view_proj.m32,
            .w = view_proj.m44 - view_proj.m42,
        };

        // Near plane
        self.frustum_planes[4] = raylib.Vector4{
            .x = view_proj.m13,
            .y = view_proj.m23,
            .z = view_proj.m33,
            .w = view_proj.m43,
        };

        // Far plane
        self.frustum_planes[5] = raylib.Vector4{
            .x = view_proj.m14 - view_proj.m13,
            .y = view_proj.m24 - view_proj.m23,
            .z = view_proj.m34 - view_proj.m33,
            .w = view_proj.m44 - view_proj.m43,
        };

        // Normalize planes
        for (&self.frustum_planes) |*plane| {
            const length = @sqrt(plane.x * plane.x + plane.y * plane.y + plane.z * plane.z);
            plane.x /= length;
            plane.y /= length;
            plane.z /= length;
            plane.w /= length;
        }
    }

    /// Test if a sphere is inside the frustum
    pub fn testSphere(self: *CullingSystem, center: raylib.Vector3, radius: f32) bool {
        self.stats.objects_tested += 1;

        for (self.frustum_planes) |plane| {
            const distance = plane.x * center.x + plane.y * center.y + plane.z * center.z + plane.w;
            if (distance < -radius) {
                self.stats.objects_failed += 1;
                return false;
            }
        }

        self.stats.objects_passed += 1;
        return true;
    }

    /// Test if an AABB is inside the frustum
    pub fn testAABB(self: *CullingSystem, min: raylib.Vector3, max: raylib.Vector3) bool {
        self.stats.objects_tested += 1;

        // Test all 8 corners of the AABB against each plane
        const corners = [_]raylib.Vector3{
            .{ .x = min.x, .y = min.y, .z = min.z }, // 000
            .{ .x = max.x, .y = min.y, .z = min.z }, // 100
            .{ .x = min.x, .y = max.y, .z = min.z }, // 010
            .{ .x = max.x, .y = max.y, .z = min.z }, // 110
            .{ .x = min.x, .y = min.y, .z = max.z }, // 001
            .{ .x = max.x, .y = min.y, .z = max.z }, // 101
            .{ .x = min.x, .y = max.y, .z = max.z }, // 011
            .{ .x = max.x, .y = max.y, .z = max.z }, // 111
        };

        for (self.frustum_planes) |plane| {
            var inside = false;

            // If any corner is inside this plane, the box is not completely outside
            for (corners) |corner| {
                const distance = plane.x * corner.x + plane.y * corner.y + plane.z * corner.z + plane.w;
                if (distance >= 0) {
                    inside = true;
                    break;
                }
            }

            if (!inside) {
                self.stats.objects_failed += 1;
                return false;
            }
        }

        self.stats.objects_passed += 1;
        return true;
    }

    /// Get culling statistics
    pub fn getStats(self: *const CullingSystem) *const CullingStats {
        return &self.stats;
    }

    /// Reset culling statistics
    pub fn resetStats(self: *CullingSystem) void {
        self.stats.reset();
    }
};

// ============================================================================
// Performance Statistics
// ============================================================================

pub const PerformanceStats = struct {
    /// Frame time statistics
    frame_time: f32 = 0,
    fps: f32 = 0,

    /// Rendering statistics
    triangles_rendered: usize = 0,
    draw_calls: usize = 0,

    /// Memory usage
    memory_used: usize = 0,

    /// LOD statistics
    lod_stats: struct {
        high_detail: usize = 0,
        medium_detail: usize = 0,
        low_detail: usize = 0,
        culled: usize = 0,
    } = .{},

    /// Culling statistics
    culling_stats: CullingSystem.CullingStats = .{},

    /// Initialize performance stats
    pub fn init() PerformanceStats {
        return .{};
    }

    /// Reset all statistics
    pub fn reset(self: *PerformanceStats) void {
        self.frame_time = 0;
        self.fps = 0;
        self.triangles_rendered = 0;
        self.draw_calls = 0;
        self.memory_used = 0;
        self.lod_stats = .{};
        self.culling_stats.reset();
    }

    /// Update frame statistics
    pub fn updateFrameStats(self: *PerformanceStats, dt: f32) void {
        self.frame_time = dt;
        self.fps = if (dt > 0) 1.0 / dt else 0;
    }
};
