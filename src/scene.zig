const std = @import("std");
const raylib = @import("raylib");
const Memory = @import("config/constants.zig").Memory;

/// 3D Scene management with ray casting capabilities
///
/// Provides scene graph functionality and ray casting for 3D interaction.
/// Supports adding/removing models, transforming them, and performing
/// ray casts against the entire scene for picking and interaction.
pub const Scene = struct {
    allocator: std.mem.Allocator,
    models: std.ArrayList(raylib.Model),
    positions: std.ArrayList(raylib.Vector3),
    rotations: std.ArrayList(raylib.Vector3), // Euler angles in degrees
    scales: std.ArrayList(raylib.Vector3),
    bounding_boxes: std.ArrayList(raylib.BoundingBox),
    transforms: std.ArrayList(raylib.Matrix),

    /// Initialize a new empty scene
    pub fn init(allocator: std.mem.Allocator) Scene {
        return .{
            .allocator = allocator,
            .models = std.ArrayList(raylib.Model).initCapacity(allocator, 8) catch unreachable,
            .positions = std.ArrayList(raylib.Vector3).initCapacity(allocator, 8) catch unreachable,
            .rotations = std.ArrayList(raylib.Vector3).initCapacity(allocator, 8) catch unreachable,
            .scales = std.ArrayList(raylib.Vector3).initCapacity(allocator, 8) catch unreachable,
            .bounding_boxes = std.ArrayList(raylib.BoundingBox).initCapacity(allocator, 8) catch unreachable,
            .transforms = std.ArrayList(raylib.Matrix).initCapacity(allocator, 8) catch unreachable,
        };
    }

    /// Deinitialize the scene and free all resources
    pub fn deinit(self: *Scene) void {
        // Unload all models
        for (self.models.items) |model| {
            raylib.unloadModel(model);
        }

        self.models.deinit(self.allocator);
        self.positions.deinit(self.allocator);
        self.rotations.deinit(self.allocator);
        self.scales.deinit(self.allocator);
        self.bounding_boxes.deinit(self.allocator);
        self.transforms.deinit(self.allocator);
    }

    /// Add a model to the scene at the specified position
    pub fn addModel(self: *Scene, model: raylib.Model, position: raylib.Vector3) !usize {
        try self.models.append(self.allocator, model);
        try self.positions.append(self.allocator, position);
        try self.rotations.append(self.allocator, .{ .x = 0, .y = 0, .z = 0 });
        try self.scales.append(self.allocator, .{ .x = 1, .y = 1, .z = 1 });

        // Calculate bounding box
        const bbox = raylib.getModelBoundingBox(model);
        try self.bounding_boxes.append(self.allocator, bbox);

        // Calculate initial transform matrix
        const transform = self.calculateTransform(self.positions.items.len - 1);
        try self.transforms.append(self.allocator, transform);

        return self.models.items.len - 1;
    }

    /// Remove a model from the scene by index
    pub fn removeModel(self: *Scene, index: usize) void {
        if (index >= self.models.items.len) return;

        // Unload the model
        raylib.unloadModel(self.models.items[index]);

        // Remove from all arrays
        _ = self.models.orderedRemove(index);
        _ = self.positions.orderedRemove(index);
        _ = self.rotations.orderedRemove(index);
        _ = self.scales.orderedRemove(index);
        _ = self.bounding_boxes.orderedRemove(index);
        _ = self.transforms.orderedRemove(index);
    }

    /// Set the position of a model
    pub fn setPosition(self: *Scene, index: usize, position: raylib.Vector3) void {
        if (index >= self.positions.items.len) return;
        self.positions.items[index] = position;
        self.transforms.items[index] = self.calculateTransform(index);
    }

    /// Set the rotation of a model (Euler angles in degrees)
    pub fn setRotation(self: *Scene, index: usize, rotation: raylib.Vector3) void {
        if (index >= self.rotations.items.len) return;
        self.rotations.items[index] = rotation;
        self.transforms.items[index] = self.calculateTransform(index);
    }

    /// Set the scale of a model
    pub fn setScale(self: *Scene, index: usize, scale: raylib.Vector3) void {
        if (index >= self.scales.items.len) return;
        self.scales.items[index] = scale;
        self.transforms.items[index] = self.calculateTransform(index);
    }

    /// Get the current transform matrix for a model
    fn calculateTransform(self: *Scene, index: usize) raylib.Matrix {
        _ = self;
        _ = index;
        // For now, return identity matrix - we'll handle transforms manually in render
        return raylib.Matrix.identity();
    }

    /// Result of a ray cast operation
    pub const RaycastHit = struct {
        /// Index of the hit model in the scene
        model_index: usize,
        /// World space hit point
        hit_point: raylib.Vector3,
        /// Surface normal at hit point
        normal: raylib.Vector3,
        /// Distance from ray origin to hit point
        distance: f32,
        /// UV coordinates on the surface (if available)
        uv: ?raylib.Vector2,
    };

    /// Cast a ray into the scene and return the closest hit
    /// Returns null if no intersection found
    pub fn raycast(self: *const Scene, ray: raylib.Ray) ?RaycastHit {
        var closest_hit: ?RaycastHit = null;

        for (self.models.items, self.bounding_boxes.items, self.transforms.items, 0..) |model, bbox, transform, i| {
            // Transform the bounding box to world space for initial check
            const world_bbox = self.transformBoundingBox(bbox, transform);

            // First check bounding box intersection
            var box_collision = raylib.getRayCollisionBox(ray, world_bbox);
            if (box_collision.hit) {
                // If bounding box hit, check individual meshes
                for (0..model.meshCount) |mesh_idx| {
                    const mesh = model.meshes[mesh_idx];
                    // Apply model transform to mesh transform
                    const mesh_transform = mesh.transform.multiply(transform);

                    var mesh_collision = raylib.getRayCollisionMesh(ray, mesh, mesh_transform);
                    if (mesh_collision.hit) {
                        // Check if this is closer than previous hits
                        if (closest_hit == null or mesh_collision.distance < closest_hit.?.distance) {
                            closest_hit = RaycastHit{
                                .model_index = i,
                                .hit_point = mesh_collision.point,
                                .normal = mesh_collision.normal,
                                .distance = mesh_collision.distance,
                                .uv = null, // UV calculation would require more complex mesh processing
                            };
                        }
                    }
                }
            }
        }

        return closest_hit;
    }

    /// Cast a ray and return all hits sorted by distance
    pub fn raycastAll(self: *const Scene, allocator: std.mem.Allocator, ray: raylib.Ray) ![]RaycastHit {
        var hits = std.ArrayList(RaycastHit).initCapacity(allocator, 0) catch unreachable;
        defer hits.deinit(allocator);

        for (self.models.items, self.bounding_boxes.items, self.transforms.items, 0..) |model, bbox, transform, i| {
            const world_bbox = self.transformBoundingBox(bbox, transform);
            var box_collision = raylib.getRayCollisionBox(ray, world_bbox);

            if (box_collision.hit) {
                for (0..model.meshCount) |mesh_idx| {
                    const mesh = model.meshes[mesh_idx];
                    const mesh_transform = mesh.transform.multiply(transform);
                    var mesh_collision = raylib.getRayCollisionMesh(ray, mesh, mesh_transform);

                    if (mesh_collision.hit) {
                        try hits.append(allocator, RaycastHit{
                            .model_index = i,
                            .hit_point = mesh_collision.point,
                            .normal = mesh_collision.normal,
                            .distance = mesh_collision.distance,
                            .uv = null,
                        });
                    }
                }
            }
        }

        // Sort hits by distance (ascending order)
        std.sort.sort(RaycastHit, hits.items, {}, struct {
            fn lessThan(context: void, a: RaycastHit, b: RaycastHit) bool {
                _ = context;
                return a.distance < b.distance;
            }
        }.lessThan);

        return hits.toOwnedSlice(allocator);
    }

    /// Transform a bounding box by a matrix
    fn transformBoundingBox(self: *const Scene, bbox: raylib.BoundingBox, transform: raylib.Matrix) raylib.BoundingBox {
        _ = self; // unused

        // Transform the 8 corners of the bounding box
        const corners = [_]raylib.Vector3{
            .{ .x = bbox.min.x, .y = bbox.min.y, .z = bbox.min.z }, // 000
            .{ .x = bbox.max.x, .y = bbox.min.y, .z = bbox.min.z }, // 100
            .{ .x = bbox.min.x, .y = bbox.max.y, .z = bbox.min.z }, // 010
            .{ .x = bbox.max.x, .y = bbox.max.y, .z = bbox.min.z }, // 110
            .{ .x = bbox.min.x, .y = bbox.min.y, .z = bbox.max.z }, // 001
            .{ .x = bbox.max.x, .y = bbox.min.y, .z = bbox.max.z }, // 101
            .{ .x = bbox.min.x, .y = bbox.max.y, .z = bbox.max.z }, // 011
            .{ .x = bbox.max.x, .y = bbox.max.y, .z = bbox.max.z }, // 111
        };

        var transformed_min = raylib.Vector3{ .x = std.math.inf(f32), .y = std.math.inf(f32), .z = std.math.inf(f32) };
        var transformed_max = raylib.Vector3{ .x = -std.math.inf(f32), .y = -std.math.inf(f32), .z = -std.math.inf(f32) };

        for (corners) |corner| {
            const transformed = corner.transform(transform);
            transformed_min.x = @min(transformed_min.x, transformed.x);
            transformed_min.y = @min(transformed_min.y, transformed.y);
            transformed_min.z = @min(transformed_min.z, transformed.z);
            transformed_max.x = @max(transformed_max.x, transformed.x);
            transformed_max.y = @max(transformed_max.y, transformed.y);
            transformed_max.z = @max(transformed_max.z, transformed.z);
        }

        return raylib.BoundingBox{
            .min = transformed_min,
            .max = transformed_max,
        };
    }

    /// Get the position of a model by index
    pub fn getPosition(self: *const Scene, index: usize) ?raylib.Vector3 {
        if (index < self.positions.items.len) {
            return self.positions.items[index];
        }
        return null;
    }

    /// Render all models in the scene
    pub fn render(self: *const Scene) void {
        for (self.models.items, 0..) |model, i| {
            const pos = self.positions.items[i];
            const rot = self.rotations.items[i];
            const scl = self.scales.items[i];

            // Apply transformations manually since drawModelEx handles rotation as Euler angles
            // For full matrix transforms, we'd need to modify the model matrix before drawing
            raylib.drawModelEx(model, pos, .{ .x = 0, .y = 1, .z = 0 }, rot.y, scl, raylib.Color.white);
        }
    }

    /// Get the number of models in the scene
    pub fn modelCount(self: *const Scene) usize {
        return self.models.items.len;
    }

    /// Get model information at index
    pub fn getModelInfo(self: *const Scene, index: usize) ?struct {
        model: raylib.Model,
        position: raylib.Vector3,
        rotation: raylib.Vector3,
        scale: raylib.Vector3,
        bounding_box: raylib.BoundingBox,
    } {
        if (index >= self.models.items.len) return null;

        return .{
            .model = self.models.items[index],
            .position = self.positions.items[index],
            .rotation = self.rotations.items[index],
            .scale = self.scales.items[index],
            .bounding_box = self.bounding_boxes.items[index],
        };
    }
};
