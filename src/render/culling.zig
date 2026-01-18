//! Frustum Culling System
//!
//! Provides frustum extraction and AABB/point intersection testing for efficient
//! view-space culling of chunks and objects.

const std = @import("std");
const math = @import("../math/math.zig");

/// A plane in 3D space represented by normal and distance from origin
pub const Plane = struct {
    normal: math.Vec3,
    distance: f32,

    const Self = @This();

    /// Create a plane from normal and distance
    pub fn init(normal: math.Vec3, distance: f32) Self {
        return .{
            .normal = normal,
            .distance = distance,
        };
    }

    /// Create a plane from three points (CCW winding)
    pub fn fromPoints(p0: math.Vec3, p1: math.Vec3, p2: math.Vec3) Self {
        const edge1 = math.Vec3.sub(p1, p0);
        const edge2 = math.Vec3.sub(p2, p0);
        const normal = math.Vec3.normalize(math.Vec3.cross(edge1, edge2));
        const distance = -math.Vec3.dot(normal, p0);
        return .{
            .normal = normal,
            .distance = distance,
        };
    }

    /// Normalize the plane equation
    pub fn normalize(self: Self) Self {
        const length = math.Vec3.length(self.normal);
        if (length > 0.0001) {
            return .{
                .normal = math.Vec3.scale(self.normal, 1.0 / length),
                .distance = self.distance / length,
            };
        }
        return self;
    }

    /// Calculate signed distance from a point to the plane
    /// Positive = in front of plane (in normal direction)
    /// Negative = behind plane
    /// Zero = on plane
    pub fn distanceToPoint(self: *const Self, point: math.Vec3) f32 {
        return math.Vec3.dot(self.normal, point) + self.distance;
    }

    /// Check if a point is in front of or on the plane
    pub fn isPointInFront(self: *const Self, point: math.Vec3) bool {
        return self.distanceToPoint(point) >= 0;
    }

    /// Check if a point is behind the plane
    pub fn isPointBehind(self: *const Self, point: math.Vec3) bool {
        return self.distanceToPoint(point) < 0;
    }
};

/// Frustum plane indices
pub const FrustumPlane = enum(u3) {
    near = 0,
    far = 1,
    left = 2,
    right = 3,
    top = 4,
    bottom = 5,
};

/// Frustum intersection results
pub const IntersectionResult = enum {
    outside, // Completely outside frustum
    inside, // Completely inside frustum
    intersecting, // Partially inside (crossing frustum boundary)
};

/// View frustum for culling operations
pub const Frustum = struct {
    planes: [6]Plane,

    const Self = @This();

    /// Create a frustum from view and projection matrices
    /// Uses the Gribb/Hartmann method for extracting frustum planes
    pub fn fromViewProjection(view: math.Mat4, proj: math.Mat4) Self {
        const vp = math.Mat4.mul(proj, view);
        return fromMatrix(vp);
    }

    /// Create a frustum from a combined view-projection matrix
    pub fn fromMatrix(m: math.Mat4) Self {
        var planes: [6]Plane = undefined;

        // Extract frustum planes from the view-projection matrix
        // Each plane is a linear combination of rows of the matrix

        // Left plane: row3 + row0
        planes[@intFromEnum(FrustumPlane.left)] = Plane.init(
            math.Vec3.init(
                m.cols[0][3] + m.cols[0][0],
                m.cols[1][3] + m.cols[1][0],
                m.cols[2][3] + m.cols[2][0],
            ),
            m.cols[3][3] + m.cols[3][0],
        ).normalize();

        // Right plane: row3 - row0
        planes[@intFromEnum(FrustumPlane.right)] = Plane.init(
            math.Vec3.init(
                m.cols[0][3] - m.cols[0][0],
                m.cols[1][3] - m.cols[1][0],
                m.cols[2][3] - m.cols[2][0],
            ),
            m.cols[3][3] - m.cols[3][0],
        ).normalize();

        // Bottom plane: row3 + row1
        planes[@intFromEnum(FrustumPlane.bottom)] = Plane.init(
            math.Vec3.init(
                m.cols[0][3] + m.cols[0][1],
                m.cols[1][3] + m.cols[1][1],
                m.cols[2][3] + m.cols[2][1],
            ),
            m.cols[3][3] + m.cols[3][1],
        ).normalize();

        // Top plane: row3 - row1
        planes[@intFromEnum(FrustumPlane.top)] = Plane.init(
            math.Vec3.init(
                m.cols[0][3] - m.cols[0][1],
                m.cols[1][3] - m.cols[1][1],
                m.cols[2][3] - m.cols[2][1],
            ),
            m.cols[3][3] - m.cols[3][1],
        ).normalize();

        // Near plane: row3 + row2
        planes[@intFromEnum(FrustumPlane.near)] = Plane.init(
            math.Vec3.init(
                m.cols[0][3] + m.cols[0][2],
                m.cols[1][3] + m.cols[1][2],
                m.cols[2][3] + m.cols[2][2],
            ),
            m.cols[3][3] + m.cols[3][2],
        ).normalize();

        // Far plane: row3 - row2
        planes[@intFromEnum(FrustumPlane.far)] = Plane.init(
            math.Vec3.init(
                m.cols[0][3] - m.cols[0][2],
                m.cols[1][3] - m.cols[1][2],
                m.cols[2][3] - m.cols[2][2],
            ),
            m.cols[3][3] - m.cols[3][2],
        ).normalize();

        return .{ .planes = planes };
    }

    /// Get a specific frustum plane
    pub fn getPlane(self: *const Self, plane: FrustumPlane) Plane {
        return self.planes[@intFromEnum(plane)];
    }

    /// Check if a point is inside the frustum
    pub fn containsPoint(self: *const Self, point: math.Vec3) bool {
        for (self.planes) |plane| {
            if (plane.distanceToPoint(point) < 0) {
                return false;
            }
        }
        return true;
    }

    /// Check if an axis-aligned bounding box is completely inside the frustum
    pub fn containsAABB(self: *const Self, min: math.Vec3, max: math.Vec3) bool {
        // All 8 corners must be inside all planes
        const corners = getAABBCorners(min, max);

        for (self.planes) |plane| {
            var all_inside = true;
            for (corners) |corner| {
                if (plane.distanceToPoint(corner) < 0) {
                    all_inside = false;
                    break;
                }
            }
            if (!all_inside) {
                return false;
            }
        }
        return true;
    }

    /// Check if an axis-aligned bounding box intersects the frustum
    /// Returns true if any part of the AABB is inside the frustum
    pub fn intersectsAABB(self: *const Self, min: math.Vec3, max: math.Vec3) bool {
        for (self.planes) |plane| {
            // Find the corner of the AABB most in the direction of the plane normal
            const positive_vertex = math.Vec3.init(
                if (plane.normal.x() >= 0) max.x() else min.x(),
                if (plane.normal.y() >= 0) max.y() else min.y(),
                if (plane.normal.z() >= 0) max.z() else min.z(),
            );

            // If the most positive vertex is behind the plane, the AABB is outside
            if (plane.distanceToPoint(positive_vertex) < 0) {
                return false;
            }
        }
        return true;
    }

    /// Test AABB against frustum and return detailed intersection result
    pub fn testAABB(self: *const Self, min: math.Vec3, max: math.Vec3) IntersectionResult {
        var result = IntersectionResult.inside;

        for (self.planes) |plane| {
            // Find positive and negative vertices relative to plane normal
            const positive_vertex = math.Vec3.init(
                if (plane.normal.x() >= 0) max.x() else min.x(),
                if (plane.normal.y() >= 0) max.y() else min.y(),
                if (plane.normal.z() >= 0) max.z() else min.z(),
            );

            const negative_vertex = math.Vec3.init(
                if (plane.normal.x() >= 0) min.x() else max.x(),
                if (plane.normal.y() >= 0) min.y() else max.y(),
                if (plane.normal.z() >= 0) min.z() else max.z(),
            );

            // If positive vertex is outside, AABB is completely outside this plane
            if (plane.distanceToPoint(positive_vertex) < 0) {
                return .outside;
            }

            // If negative vertex is outside but positive is inside, we're intersecting
            if (plane.distanceToPoint(negative_vertex) < 0) {
                result = .intersecting;
            }
        }

        return result;
    }

    /// Check if a sphere is inside or intersects the frustum
    pub fn intersectsSphere(self: *const Self, center: math.Vec3, radius: f32) bool {
        for (self.planes) |plane| {
            const distance = plane.distanceToPoint(center);
            if (distance < -radius) {
                return false; // Sphere is completely outside this plane
            }
        }
        return true;
    }

    /// Test sphere against frustum with detailed result
    pub fn testSphere(self: *const Self, center: math.Vec3, radius: f32) IntersectionResult {
        var result = IntersectionResult.inside;

        for (self.planes) |plane| {
            const distance = plane.distanceToPoint(center);

            if (distance < -radius) {
                return .outside; // Completely outside
            }
            if (distance < radius) {
                result = .intersecting; // Intersecting this plane
            }
        }

        return result;
    }

    /// Check if a chunk is visible (using chunk coordinates and size)
    pub fn isChunkVisible(
        self: *const Self,
        chunk_x: i32,
        chunk_y: i32,
        chunk_z: i32,
        chunk_size: f32,
    ) bool {
        const min = math.Vec3.init(
            @as(f32, @floatFromInt(chunk_x)) * chunk_size,
            @as(f32, @floatFromInt(chunk_y)) * chunk_size,
            @as(f32, @floatFromInt(chunk_z)) * chunk_size,
        );
        const max = math.Vec3.init(
            min.x() + chunk_size,
            min.y() + chunk_size,
            min.z() + chunk_size,
        );
        return self.intersectsAABB(min, max);
    }
};

/// Get all 8 corners of an AABB
fn getAABBCorners(min: math.Vec3, max: math.Vec3) [8]math.Vec3 {
    return .{
        math.Vec3.init(min.x(), min.y(), min.z()),
        math.Vec3.init(max.x(), min.y(), min.z()),
        math.Vec3.init(min.x(), max.y(), min.z()),
        math.Vec3.init(max.x(), max.y(), min.z()),
        math.Vec3.init(min.x(), min.y(), max.z()),
        math.Vec3.init(max.x(), min.y(), max.z()),
        math.Vec3.init(min.x(), max.y(), max.z()),
        math.Vec3.init(max.x(), max.y(), max.z()),
    };
}

/// Culling statistics for debugging
pub const CullingStats = struct {
    total_tested: u32 = 0,
    culled: u32 = 0,
    visible: u32 = 0,
    intersecting: u32 = 0,

    const Self = @This();

    /// Reset all counters
    pub fn reset(self: *Self) void {
        self.total_tested = 0;
        self.culled = 0;
        self.visible = 0;
        self.intersecting = 0;
    }

    /// Record a culling test result
    pub fn record(self: *Self, result: IntersectionResult) void {
        self.total_tested += 1;
        switch (result) {
            .outside => self.culled += 1,
            .inside => self.visible += 1,
            .intersecting => {
                self.visible += 1;
                self.intersecting += 1;
            },
        }
    }

    /// Get the cull ratio (0.0 to 1.0)
    pub fn getCullRatio(self: *const Self) f32 {
        if (self.total_tested == 0) return 0.0;
        return @as(f32, @floatFromInt(self.culled)) / @as(f32, @floatFromInt(self.total_tested));
    }
};

// ============================================================================
// Tests
// ============================================================================

test "plane distance to point" {
    // Plane at y=0, normal pointing up
    const plane = Plane.init(math.Vec3.init(0, 1, 0), 0);

    // Point above plane should be positive
    try std.testing.expect(plane.distanceToPoint(math.Vec3.init(0, 5, 0)) > 0);

    // Point below plane should be negative
    try std.testing.expect(plane.distanceToPoint(math.Vec3.init(0, -5, 0)) < 0);

    // Point on plane should be zero
    try std.testing.expectApproxEqAbs(@as(f32, 0), plane.distanceToPoint(math.Vec3.init(5, 0, 5)), 0.0001);
}

test "plane from points" {
    const p0 = math.Vec3.init(0, 0, 0);
    const p1 = math.Vec3.init(1, 0, 0);
    const p2 = math.Vec3.init(0, 0, 1);

    const plane = Plane.fromPoints(p0, p1, p2);

    // Normal should point up (positive Y)
    try std.testing.expectApproxEqAbs(@as(f32, 0), plane.normal.x(), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1), plane.normal.y(), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), plane.normal.z(), 0.0001);
}

test "frustum from perspective matrix" {
    const proj = math.Mat4.perspective(math.radians(60.0), 16.0 / 9.0, 0.1, 100.0);
    const view = math.Mat4.lookAt(
        math.Vec3.init(0, 0, 5),
        math.Vec3.init(0, 0, 0),
        math.Vec3.UP,
    );

    const frustum = Frustum.fromViewProjection(view, proj);

    // Point at origin should be inside frustum (camera looking at it from z=5)
    try std.testing.expect(frustum.containsPoint(math.Vec3.init(0, 0, 0)));

    // Point far behind camera should be outside
    try std.testing.expect(!frustum.containsPoint(math.Vec3.init(0, 0, 200)));
}

test "frustum AABB intersection" {
    const proj = math.Mat4.perspective(math.radians(60.0), 16.0 / 9.0, 0.1, 100.0);
    const view = math.Mat4.lookAt(
        math.Vec3.init(0, 0, 10),
        math.Vec3.init(0, 0, 0),
        math.Vec3.UP,
    );

    const frustum = Frustum.fromViewProjection(view, proj);

    // Box at origin should intersect (camera looking at it)
    const min1 = math.Vec3.init(-1, -1, -1);
    const max1 = math.Vec3.init(1, 1, 1);
    try std.testing.expect(frustum.intersectsAABB(min1, max1));

    // Box far to the side should not intersect
    const min2 = math.Vec3.init(100, 100, 0);
    const max2 = math.Vec3.init(101, 101, 1);
    try std.testing.expect(!frustum.intersectsAABB(min2, max2));
}

test "culling stats" {
    var stats = CullingStats{};

    stats.record(.outside);
    stats.record(.outside);
    stats.record(.inside);
    stats.record(.intersecting);

    try std.testing.expectEqual(@as(u32, 4), stats.total_tested);
    try std.testing.expectEqual(@as(u32, 2), stats.culled);
    try std.testing.expectEqual(@as(u32, 2), stats.visible);
    try std.testing.expectEqual(@as(u32, 1), stats.intersecting);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), stats.getCullRatio(), 0.0001);
}
