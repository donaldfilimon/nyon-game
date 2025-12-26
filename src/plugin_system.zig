const std = @import("std");

// Plugin system architecture for extensible engine functionality
pub const PluginSystem = struct {
    allocator: std.mem.Allocator,
    plugins: std.ArrayList(Plugin),
    plugin_libraries: std.ArrayList(std.DynLib),

    pub const PluginType = enum {
        material,
        geometry_node,
        game_mode,
        ui_panel,
        asset_importer,
        tool,
    };

    pub const PluginCapabilities = struct {
        plugin_type: PluginType,
        name: [:0]const u8,
        version: [:0]const u8,
        description: [:0]const u8,
        author: [:0]const u8,
    };

    pub const PluginContext = struct {
        allocator: std.mem.Allocator,
        engine: ?*anyopaque = null,
        user_data: ?*anyopaque = null,
    };

    pub const Plugin = struct {
        library: std.DynLib,
        context: PluginContext,
        capabilities: PluginCapabilities,

        // Function pointers
        init_fn: ?*const fn (*PluginContext) callconv(.C) bool,
        deinit_fn: ?*const fn (*PluginContext) callconv(.C) void,
        update_fn: ?*const fn (*PluginContext, f32) callconv(.C) void,
        render_fn: ?*const fn (*PluginContext) callconv(.C) void,

        // Plugin-specific functions
        get_material_fn: ?*const fn (*PluginContext, [:0]const u8) callconv(.C) ?*anyopaque,
        create_geometry_node_fn: ?*const fn (*PluginContext, [:0]const u8) callconv(.C) ?*anyopaque,
        get_ui_panel_fn: ?*const fn (*PluginContext) callconv(.C) ?*anyopaque,
    };

    pub fn init(allocator: std.mem.Allocator) PluginSystem {
        return PluginSystem{
            .allocator = allocator,
            .plugins = std.ArrayList(Plugin).initCapacity(allocator, 0) catch unreachable,
            .plugin_libraries = std.ArrayList(std.DynLib).initCapacity(allocator, 0) catch unreachable,
        };
    }

    pub fn deinit(self: *PluginSystem) void {
        // Deinitialize plugins in reverse order
        var i = self.plugins.items.len;
        while (i > 0) {
            i -= 1;
            const plugin = &self.plugins.items[i];
            if (plugin.deinit_fn) |deinit_fn| {
                deinit_fn(&plugin.context);
            }
        }

        // Close dynamic libraries
        for (self.plugin_libraries.items) |*lib| {
            lib.close();
        }

        self.plugins.deinit(self.allocator);
        self.plugin_libraries.deinit(self.allocator);
    }

    /// Load a plugin from a dynamic library file
    pub fn loadPlugin(self: *PluginSystem, file_path: []const u8) !void {
        // Load the dynamic library
        var library = std.DynLib.open(file_path) catch |err| {
            std.debug.print("Failed to load plugin {s}: {s}\n", .{ file_path, @errorName(err) });
            return err;
        };
        errdefer library.close();

        // Get plugin interface functions
        const get_capabilities_fn = library.lookup(*const fn () callconv(.C) PluginCapabilities, "nyon_plugin_get_capabilities") catch |err| {
            std.debug.print("Plugin {s} missing nyon_plugin_get_capabilities function: {s}\n", .{ file_path, @errorName(err) });
            return err;
        };

        const capabilities = get_capabilities_fn();

        // Create plugin context
        var context = PluginContext{
            .allocator = self.allocator,
            .engine = null, // Set by caller
            .user_data = null,
        };

        // Get function pointers
        const init_fn = library.lookup(*const fn (*PluginContext) callconv(.C) bool, "nyon_plugin_init") catch null;
        const deinit_fn = library.lookup(*const fn (*PluginContext) callconv(.C) void, "nyon_plugin_deinit") catch null;
        const update_fn = library.lookup(*const fn (*PluginContext, f32) callconv(.C) void, "nyon_plugin_update") catch null;
        const render_fn = library.lookup(*const fn (*PluginContext) callconv(.C) void, "nyon_plugin_render") catch null;

        // Type-specific functions
        const get_material_fn = library.lookup(*const fn (*PluginContext, [:0]const u8) callconv(.C) ?*anyopaque, "nyon_plugin_get_material") catch null;
        const create_geometry_node_fn = library.lookup(*const fn (*PluginContext, [:0]const u8) callconv(.C) ?*anyopaque, "nyon_plugin_create_geometry_node") catch null;
        const get_ui_panel_fn = library.lookup(*const fn (*PluginContext) callconv(.C) ?*anyopaque, "nyon_plugin_get_ui_panel") catch null;

        // Initialize plugin
        if (init_fn) |init_func| {
            if (!init_func(&context)) {
                std.debug.print("Plugin {s} initialization failed\n", .{capabilities.name});
                return error.PluginInitFailed;
            }
        }

        // Create plugin entry
        const plugin = Plugin{
            .library = library,
            .context = context,
            .capabilities = capabilities,
            .init_fn = init_fn,
            .deinit_fn = deinit_fn,
            .update_fn = update_fn,
            .render_fn = render_fn,
            .get_material_fn = get_material_fn,
            .create_geometry_node_fn = create_geometry_node_fn,
            .get_ui_panel_fn = get_ui_panel_fn,
        };

        // Store plugin and library
        try self.plugins.append(self.allocator, plugin);
        try self.plugin_libraries.append(self.allocator, library);

        std.debug.print("Loaded plugin: {s} v{s} by {s}\n", .{
            capabilities.name,
            capabilities.version,
            capabilities.author,
        });
    }

    /// Update all loaded plugins
    pub fn updatePlugins(self: *PluginSystem, delta_time: f32) void {
        for (self.plugins.items) |*plugin| {
            if (plugin.update_fn) |update_fn| {
                update_fn(&plugin.context, delta_time);
            }
        }
    }

    /// Render all loaded plugins
    pub fn renderPlugins(self: *PluginSystem) void {
        for (self.plugins.items) |*plugin| {
            if (plugin.render_fn) |render_fn| {
                render_fn(&plugin.context);
            }
        }
    }

    /// Get material from material plugins
    pub fn getMaterial(self: *const PluginSystem, material_name: [:0]const u8) ?*anyopaque {
        for (self.plugins.items) |plugin| {
            if (plugin.capabilities.plugin_type == .material and plugin.get_material_fn) |get_fn| {
                if (get_fn(&plugin.context, material_name)) |material| {
                    return material;
                }
            }
        }
        return null;
    }

    /// Create geometry node from geometry plugins
    pub fn createGeometryNode(self: *const PluginSystem, node_type: [:0]const u8) ?*anyopaque {
        for (self.plugins.items) |plugin| {
            if (plugin.capabilities.plugin_type == .geometry_node and plugin.create_geometry_node_fn) |create_fn| {
                if (create_fn(&plugin.context, node_type)) |node| {
                    return node;
                }
            }
        }
        return null;
    }

    /// Get UI panels from UI plugins
    pub fn getUIPanels(self: *const PluginSystem, allocator: std.mem.Allocator) ![]*anyopaque {
        var panels = std.ArrayList(*anyopaque).initCapacity(allocator, 0) catch unreachable;
        defer panels.deinit(allocator);

        for (self.plugins.items) |plugin| {
            if (plugin.capabilities.plugin_type == .ui_panel and plugin.get_ui_panel_fn) |get_fn| {
                if (get_fn(&plugin.context)) |panel| {
                    try panels.append(allocator, panel);
                }
            }
        }

        return panels.toOwnedSlice(allocator);
    }

    /// Get loaded plugins by type
    pub fn getPluginsByType(self: *const PluginSystem, plugin_type: PluginType, allocator: std.mem.Allocator) ![]*const Plugin {
        var matching_plugins = std.ArrayList(*const Plugin).initCapacity(allocator, 0) catch unreachable;
        defer matching_plugins.deinit(allocator);

        for (self.plugins.items) |*plugin| {
            if (plugin.capabilities.plugin_type == plugin_type) {
                try matching_plugins.append(allocator, plugin);
            }
        }

        return matching_plugins.toOwnedSlice(allocator);
    }
};

// ============================================================================
// Plugin Development Helpers
// ============================================================================

/// Plugin registration macro for C plugins
pub const PLUGIN_INTERFACE_VERSION = 1;

/// Standard plugin entry points (for C plugins)
export fn nyon_plugin_get_version() callconv(.C) u32 {
    return PLUGIN_INTERFACE_VERSION;
}

/// Example material plugin structure
pub const MaterialPlugin = struct {
    name: [:0]const u8,
    description: [:0]const u8,

    pub fn create(name: [:0]const u8, desc: [:0]const u8) MaterialPlugin {
        return MaterialPlugin{
            .name = name,
            .description = desc,
        };
    }
};

/// Example geometry node plugin structure
pub const GeometryNodePlugin = struct {
    supported_node_types: []const [:0]const u8,

    pub fn supportsNodeType(self: *const GeometryNodePlugin, node_type: [:0]const u8) bool {
        for (self.supported_node_types) |supported| {
            if (std.mem.eql(u8, supported, node_type)) return true;
        }
        return false;
    }
};

// The duplicate deinit below was removed to avoid conflicting definitions.
// Plugin loading and management continue after the struct definition.
