const std = @import("std");
const raylib = @import("raylib");

/// Property Inspector for the Nyon Game Editor
///
/// Provides a dynamic UI for editing object properties, materials,
/// transforms, and other component data.
pub const PropertyInspector = struct {
    allocator: std.mem.Allocator,
    scroll_offset: f32,
    selected_object: ?ObjectReference,
    post_processing_system: ?*@import("post_processing.zig").PostProcessingSystem = null,
    ecs_world: ?*@import("ecs/ecs.zig").World = null,

    pub const ObjectReference = union(enum) {
        scene_node: usize, // Index in scene
        ecs_entity: usize, // ECS Entity ID
        geometry_node: usize, // Node ID in geometry system
        material: usize, // Material ID
        light: usize, // Light ID
        global_settings, // Global editor/engine settings
    };

    pub const PropertyValue = union(enum) {
        float: f32,
        int: i32,
        bool: bool,
        vector3: raylib.Vector3,
        vector2: raylib.Vector2,
        color: raylib.Color,
        string: []const u8,
        texture: usize, // Texture ID
    };

    pub fn init(allocator: std.mem.Allocator) PropertyInspector {
        return .{
            .allocator = allocator,
            .scroll_offset = 0,
            .selected_object = null,
        };
    }

    pub fn deinit(self: *PropertyInspector) void {
        _ = self; // No dynamic allocation
    }

    /// Set the selected object to inspect
    pub fn setSelectedObject(self: *PropertyInspector, object: ?ObjectReference) void {
        self.selected_object = object;
        self.scroll_offset = 0; // Reset scroll when selecting new object
    }

    /// Set the ECS world reference for entity inspection
    pub fn setECSWorld(self: *PropertyInspector, world: *@import("ecs/ecs.zig").World) void {
        self.ecs_world = world;
    }

    /// Render the property inspector UI
    pub fn render(self: *PropertyInspector, rect: raylib.Rectangle, post_sys: *@import("post_processing.zig").PostProcessingSystem) void {
        self.post_processing_system = post_sys;
        // Background
        raylib.drawRectangleRec(rect, raylib.Color{ .r = 35, .g = 35, .b = 45, .a = 255 });
        raylib.drawRectangleLinesEx(rect, 1, raylib.Color{ .r = 80, .g = 80, .b = 100, .a = 255 });

        // Title
        raylib.drawText("Properties", @intFromFloat(rect.x + 10), @intFromFloat(rect.y + 10), 18, raylib.Color.white);

        // Content area
        const content_rect = raylib.Rectangle{
            .x = rect.x + 5,
            .y = rect.y + 35,
            .width = rect.width - 10,
            .height = rect.height - 40,
        };

        // Scissor for scrollable content
        raylib.beginScissorMode(
            @intFromFloat(content_rect.x),
            @intFromFloat(content_rect.y),
            @intFromFloat(content_rect.width),
            @intFromFloat(content_rect.height),
        );

        var y_offset: f32 = content_rect.y - self.scroll_offset;

        if (self.selected_object) |object| {
            switch (object) {
                .scene_node => |_| {
                    y_offset = self.renderSceneNodeProperties(content_rect.x, y_offset, content_rect.width);
                },
                .ecs_entity => |entity_id| {
                    y_offset = self.renderECSEntityProperties(entity_id, content_rect.x, y_offset, content_rect.width);
                },
                .geometry_node => |node_id| {
                    y_offset = self.renderGeometryNodeProperties(node_id, content_rect.x, y_offset, content_rect.width);
                },
                .material => |material_id| {
                    y_offset = self.renderMaterialProperties(material_id, content_rect.x, y_offset, content_rect.width);
                },
                .light => |light_id| {
                    y_offset = self.renderLightProperties(light_id, content_rect.x, y_offset, content_rect.width);
                },
                .global_settings => {
                    y_offset = self.renderGlobalSettings(content_rect.x, y_offset, content_rect.width);
                },
            }
        } else {
            raylib.drawText("No object selected", @intFromFloat(content_rect.x), @intFromFloat(y_offset), 14, raylib.Color.gray);
        }

        raylib.endScissorMode();

        // Handle scrolling
        const wheel = raylib.getMouseWheelMove();
        if (wheel != 0 and raylib.checkCollisionPointRec(raylib.getMousePosition(), rect)) {
            self.scroll_offset = @max(0, self.scroll_offset - wheel * 20);
        }
    }

    fn renderSceneNodeProperties(self: *PropertyInspector, x: f32, y: f32, width: f32) f32 {
        var current_y = y;

        // Header
        current_y = self.drawPropertyHeader("Scene Node", x, current_y, width);

        // Position
        current_y = self.drawVector3Property("Position", .{ .x = 0, .y = 0, .z = 0 }, x, current_y, width);

        // Rotation
        current_y = self.drawVector3Property("Rotation", .{ .x = 0, .y = 0, .z = 0 }, x, current_y, width);

        // Scale
        current_y = self.drawVector3Property("Scale", .{ .x = 1, .y = 1, .z = 1 }, x, current_y, width);

        // Material
        current_y = self.drawPropertyHeader("Material", x, current_y, width);
        current_y = self.drawColorProperty("Diffuse Color", raylib.Color.white, x, current_y, width);

        return current_y;
    }

    fn renderECSEntityProperties(self: *PropertyInspector, entity_id: usize, x: f32, y: f32, width: f32) f32 {
        var current_y = y;

        // Header
        current_y = self.drawPropertyHeader("ECS Entity", x, current_y, width);

        // Entity ID display
        var id_buf: [32]u8 = undefined;
        const id_str = std.fmt.bufPrintZ(&id_buf, "ID: {d}", .{entity_id}) catch "ID: ?";
        current_y = self.drawPropertyHeader(id_str, x, current_y, width);

        if (self.ecs_world) |world| {
            const eid = @import("ecs/entity.zig").EntityId{ .id = @as(u32, @intCast(entity_id)), .generation = 0 };
            // Transform component
            if (world.getComponent(eid, @import("ecs/component.zig").Transform)) |transform| {
                current_y = self.drawPropertyHeader("Transform", x, current_y, width);
                current_y = self.drawVector3Property("Position", .{ .x = transform.position.x, .y = transform.position.y, .z = transform.position.z }, x, current_y, width);
                current_y = self.drawVector3Property("Scale", .{ .x = transform.scale.x, .y = transform.scale.y, .z = transform.scale.z }, x, current_y, width);
            }

            // RigidBody component
            if (world.getComponent(eid, @import("ecs/component.zig").RigidBody)) |rigid_body| {
                current_y = self.drawPropertyHeader("RigidBody", x, current_y, width);
                var mass_buf: [64:0]u8 = undefined;
                const mass_str = std.fmt.bufPrintZ(&mass_buf, "Mass: {d:.2}", .{rigid_body.mass}) catch "Mass: 0.00";
                current_y = self.drawPropertyHeader(mass_str, x, current_y, width);
                const is_kinematic = if (rigid_body.is_kinematic) "Kinematic" else "Dynamic";
                current_y = self.drawPropertyHeader(is_kinematic, x, current_y, width);
            }

            // Collider component
            if (world.getComponent(eid, @import("ecs/component.zig").Collider)) |collider| {
                current_y = self.drawPropertyHeader("Collider", x, current_y, width);
                const collider_type = @tagName(collider.*);
                var type_buf: [32]u8 = undefined;
                const type_str = std.fmt.bufPrintZ(&type_buf, "Type: {s}", .{collider_type}) catch "Type: ?";
                current_y = self.drawPropertyHeader(type_str, x, current_y, width);
            }

            // Renderable component
            if (world.getComponent(eid, @import("ecs/component.zig").Renderable)) |renderable| {
                current_y = self.drawPropertyHeader("Renderable", x, current_y, width);
                const visible_str = if (renderable.visible) "Visible" else "Hidden";
                current_y = self.drawPropertyHeader(visible_str, x, current_y, width);
                const shadow_str = if (renderable.cast_shadows) "Cast Shadows" else "No Shadows";
                current_y = self.drawPropertyHeader(shadow_str, x, current_y, width);
            }
        } else {
            current_y = self.drawPropertyHeader("No ECS World", x, current_y, width);
        }

        return current_y;
    }

    fn renderGeometryNodeProperties(self: *PropertyInspector, _: usize, x: f32, y: f32, width: f32) f32 {
        var current_y = y;

        // Header
        current_y = self.drawPropertyHeader("Geometry Node", x, current_y, width);

        // Node type specific properties
        current_y = self.drawPropertyHeader("Parameters", x, current_y, width);
        current_y = self.drawFloatProperty("Width", 2.0, x, current_y, width);
        current_y = self.drawFloatProperty("Height", 2.0, x, current_y, width);
        current_y = self.drawFloatProperty("Depth", 2.0, x, current_y, width);

        return current_y;
    }

    fn renderMaterialProperties(self: *PropertyInspector, _: usize, x: f32, y: f32, width: f32) f32 {
        var current_y = y;

        // Header
        current_y = self.drawPropertyHeader("Material", x, current_y, width);

        // Basic properties
        current_y = self.drawColorProperty("Base Color", raylib.Color.white, x, current_y, width);
        current_y = self.drawFloatProperty("Metallic", 0.0, x, current_y, width);
        current_y = self.drawFloatProperty("Roughness", 0.5, x, current_y, width);
        current_y = self.drawFloatProperty("Emission", 0.0, x, current_y, width);

        // Texture properties
        current_y = self.drawPropertyHeader("Textures", x, current_y, width);
        current_y = self.drawTextureProperty("Albedo", x, current_y, width);
        current_y = self.drawTextureProperty("Normal", x, current_y, width);
        current_y = self.drawTextureProperty("Metallic", x, current_y, width);
        current_y = self.drawTextureProperty("Roughness", x, current_y, width);

        return current_y;
    }

    fn renderLightProperties(self: *PropertyInspector, _: usize, x: f32, y: f32, width: f32) f32 {
        var current_y = y;

        // Header
        current_y = self.drawPropertyHeader("Light", x, current_y, width);

        // Light properties
        current_y = self.drawColorProperty("Color", raylib.Color.white, x, current_y, width);
        current_y = self.drawFloatProperty("Intensity", 1.0, x, current_y, width);
        current_y = self.drawFloatProperty("Range", 10.0, x, current_y, width);
        current_y = self.drawVector3Property("Position", raylib.Vector3{ .x = 0, .y = 5, .z = 0 }, x, current_y, width);
        current_y = self.drawVector3Property("Direction", raylib.Vector3{ .x = 0, .y = -1, .z = 0 }, x, current_y, width);

        return current_y;
    }

    fn renderGlobalSettings(self: *PropertyInspector, x: f32, y: f32, width: f32) f32 {
        var current_y = y;

        // Header
        current_y = self.drawPropertyHeader("Global Settings", x, current_y, width);

        // Post-Processing
        current_y = self.drawPropertyHeader("Post-Processing", x, current_y, width);

        if (self.post_processing_system) |ps| {
            const active_effect = ps.active_effect;
            const effect_name = @tagName(active_effect);

            if (self.drawEnumProperty("Active Effect", effect_name, x, current_y, width)) {
                // Cycle effect
                const current_val = @intFromEnum(active_effect);
                const next_val = (current_val + 1) % (@typeInfo(@import("post_processing.zig").PostProcessingSystem.EffectType).@"enum".fields.len);
                ps.active_effect = @enumFromInt(@as(u3, @intCast(next_val)));
            }
        }
        current_y += 25;

        return current_y;
    }

    fn drawEnumProperty(_: *PropertyInspector, name: []const u8, value: []const u8, x: f32, y: f32, width: f32) bool {
        // Label
        raylib.drawText(name, @intFromFloat(x + 5), @intFromFloat(y + 5), 12, raylib.Color.gray);

        // Value background
        const value_rect = raylib.Rectangle{
            .x = x + width - 100,
            .y = y + 2,
            .width = 95,
            .height = 18,
        };

        const is_hovered = raylib.checkCollisionPointRec(raylib.getMousePosition(), value_rect);
        const bg_color = if (is_hovered) raylib.Color{ .r = 80, .g = 80, .b = 100, .a = 255 } else raylib.Color{ .r = 60, .g = 60, .b = 80, .a = 255 };

        raylib.drawRectangleRec(value_rect, bg_color);
        raylib.drawRectangleLinesEx(value_rect, 1, raylib.Color{ .r = 100, .g = 100, .b = 120, .a = 255 });

        // Value text
        raylib.drawText(value, @intFromFloat(value_rect.x + 5), @intFromFloat(value_rect.y + 2), 12, raylib.Color.white);

        return is_hovered and raylib.isMouseButtonPressed(.left);
    }

    fn drawPropertyHeader(self: *PropertyInspector, title: []const u8, x: f32, y: f32, width: f32) f32 {
        _ = self; // unused

        // Header background
        const header_rect = raylib.Rectangle{
            .x = x,
            .y = y,
            .width = width,
            .height = 25,
        };
        raylib.drawRectangleRec(header_rect, raylib.Color{ .r = 50, .g = 50, .b = 70, .a = 255 });
        var title_buf: [128:0]u8 = undefined;
        const title_z = std.fmt.bufPrintZ(&title_buf, "{s}", .{title}) catch "";
        raylib.drawText(title_z, @intFromFloat(x + 5), @intFromFloat(y + 5), 14, raylib.Color.white);

        return y + 30;
    }

    fn drawFloatProperty(_: *PropertyInspector, name: []const u8, value: f32, x: f32, y: f32, width: f32) f32 {

        // Label
        raylib.drawText(name, @intFromFloat(x + 5), @intFromFloat(y + 5), 12, raylib.Color.gray);

        // Value background
        const value_rect = raylib.Rectangle{
            .x = x + width - 60,
            .y = y + 2,
            .width = 55,
            .height = 18,
        };
        raylib.drawRectangleRec(value_rect, raylib.Color{ .r = 60, .g = 60, .b = 80, .a = 255 });
        raylib.drawRectangleLinesEx(value_rect, 1, raylib.Color{ .r = 100, .g = 100, .b = 120, .a = 255 });

        // Value text
        // Note: This would need a proper allocator reference
        var val_buf: [32:0]u8 = undefined;
        const value_text = std.fmt.bufPrintZ(&val_buf, "{d:.2}", .{value}) catch "0.00";
        raylib.drawText(value_text, @intFromFloat(value_rect.x + 5), @intFromFloat(value_rect.y + 2), 12, raylib.Color.white);

        return y + 25;
    }

    fn drawVector3Property(self: *PropertyInspector, name: []const u8, value: raylib.Vector3, x: f32, y: f32, width: f32) f32 {
        _ = self;
        _ = self;
        _ = self;
        var name_buf: [128:0]u8 = undefined;
        const name_z = std.fmt.bufPrintZ(&name_buf, "{s}", .{name}) catch "";
        // Label
        raylib.drawText(name_z, @intFromFloat(x + 5), @intFromFloat(y + 5), 12, raylib.Color.gray);

        // X component
        const x_rect = raylib.Rectangle{ .x = x + width - 180, .y = y + 2, .width = 50, .height = 18 };
        raylib.drawRectangleRec(x_rect, raylib.Color{ .r = 80, .g = 40, .b = 40, .a = 255 });
        raylib.drawText("X", @intFromFloat(x_rect.x + 2), @intFromFloat(x_rect.y + 2), 10, raylib.Color.white);
        var x_val_buf: [32:0]u8 = undefined;
        const x_text = std.fmt.bufPrintZ(&x_val_buf, "{d:.1}", .{value.x}) catch "0.0";
        raylib.drawText(x_text, @intFromFloat(x_rect.x + 15), @intFromFloat(x_rect.y + 2), 10, raylib.Color.white);

        // Y component
        const y_rect = raylib.Rectangle{ .x = x + width - 125, .y = y + 2, .width = 50, .height = 18 };
        raylib.drawRectangleRec(y_rect, raylib.Color{ .r = 40, .g = 80, .b = 40, .a = 255 });
        raylib.drawText("Y", @intFromFloat(y_rect.x + 2), @intFromFloat(y_rect.y + 2), 10, raylib.Color.white);
        var y_val_buf: [32:0]u8 = undefined;
        const y_text = std.fmt.bufPrintZ(&y_val_buf, "{d:.1}", .{value.y}) catch "0.0";
        raylib.drawText(y_text, @intFromFloat(y_rect.x + 15), @intFromFloat(y_rect.y + 2), 10, raylib.Color.white);

        // Z component
        const z_rect = raylib.Rectangle{ .x = x + width - 70, .y = y + 2, .width = 50, .height = 18 };
        raylib.drawRectangleRec(z_rect, raylib.Color{ .r = 40, .g = 40, .b = 80, .a = 255 });
        raylib.drawText("Z", @intFromFloat(z_rect.x + 2), @intFromFloat(z_rect.y + 2), 10, raylib.Color.white);
        var z_val_buf: [32:0]u8 = undefined;
        const z_text = std.fmt.bufPrintZ(&z_val_buf, "{d:.1}", .{value.z}) catch "0.0";
        raylib.drawText(z_text, @intFromFloat(z_rect.x + 15), @intFromFloat(z_rect.y + 2), 10, raylib.Color.white);

        return y + 25;
    }

    fn drawColorProperty(_: *PropertyInspector, name: []const u8, value: raylib.Color, x: f32, y: f32, width: f32) f32 {

        // Label
        var name_buf: [128:0]u8 = undefined;
        const name_z = std.fmt.bufPrintZ(&name_buf, "{s}", .{name}) catch "";
        raylib.drawText(name_z, @intFromFloat(x + 5), @intFromFloat(y + 5), 12, raylib.Color.gray);

        // Color swatch
        const color_rect = raylib.Rectangle{
            .x = x + width - 50,
            .y = y + 2,
            .width = 45,
            .height = 18,
        };
        raylib.drawRectangleRec(color_rect, value);
        raylib.drawRectangleLinesEx(color_rect, 1, raylib.Color.white);

        return y + 25;
    }

    fn drawTextureProperty(_: *PropertyInspector, name: []const u8, x: f32, y: f32, width: f32) f32 {

        // Label
        raylib.drawText(name, @intFromFloat(x + 5), @intFromFloat(y + 5), 12, raylib.Color.gray);

        // Texture slot
        const tex_rect = raylib.Rectangle{
            .x = x + width - 100,
            .y = y + 2,
            .width = 95,
            .height = 18,
        };
        raylib.drawRectangleRec(tex_rect, raylib.Color{ .r = 60, .g = 60, .b = 80, .a = 255 });
        raylib.drawRectangleLinesEx(tex_rect, 1, raylib.Color{ .r = 100, .g = 100, .b = 120, .a = 255 });
        raylib.drawText("None", @intFromFloat(tex_rect.x + 5), @intFromFloat(tex_rect.y + 2), 12, raylib.Color.gray);

        return y + 25;
    }
};
