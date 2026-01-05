# Nyon Game Engine Plugin API

This document describes how to create plugins for the Nyon Game Engine.

## Overview

The plugin system allows extending the engine with:

- Custom materials
- Geometry nodes
- Game modes
- UI panels

Plugins are dynamic libraries (.dll/.so/.dylib) loaded at runtime.

## Plugin Structure

Every plugin must export these C ABI functions:

```c
// Required: Return plugin capabilities
NyonPluginCapabilities nyon_plugin_get_capabilities(void);

// Optional: Called when plugin is loaded
void nyon_plugin_init(NyonPluginContext* ctx);

// Optional: Called when plugin is unloaded
void nyon_plugin_deinit(NyonPluginContext* ctx);

// Optional: Called every frame
void nyon_plugin_update(NyonPluginContext* ctx, float delta_time);

// Optional: Called during rendering
void nyon_plugin_render(NyonPluginContext* ctx);
```

## Capabilities Struct

```zig
pub const PluginCapabilities = extern struct {
    name: [*:0]const u8,
    version: [*:0]const u8,
    author: [*:0]const u8,
    description: [*:0]const u8,
    plugin_type: PluginType,
};

pub const PluginType = enum(u8) {
    material = 0,
    geometry_node = 1,
    game_mode = 2,
    ui_panel = 3,
};
```

## Plugin Context

The `PluginContext` provides access to engine systems:

```zig
pub const PluginContext = struct {
    engine: *anyopaque,      // Engine instance
    allocator: *anyopaque,   // Memory allocator
    user_data: ?*anyopaque,  // Plugin-specific data
};
```

## Material Plugins

Material plugins provide custom shaders and material types.

### Required Export

```c
void* nyon_plugin_get_material(
    NyonPluginContext* ctx,
    const char* material_name
);
```

### Example

```zig
export fn nyon_plugin_get_material(
    ctx: *PluginContext,
    name: [*:0]const u8,
) ?*anyopaque {
    if (std.mem.eql(u8, std.mem.span(name), "custom_pbr")) {
        return createCustomPbrMaterial(ctx);
    }
    return null;
}
```

## Geometry Node Plugins

Geometry node plugins add custom nodes to the node editor.

### Required Export

```c
void* nyon_plugin_create_geometry_node(
    NyonPluginContext* ctx,
    const char* node_type
);
```

### Example

```zig
export fn nyon_plugin_create_geometry_node(
    ctx: *PluginContext,
    node_type: [*:0]const u8,
) ?*anyopaque {
    const type_str = std.mem.span(node_type);
    if (std.mem.eql(u8, type_str, "custom_shape")) {
        return createCustomShapeNode(ctx);
    }
    return null;
}
```

## UI Panel Plugins

UI panel plugins add custom panels to the editor.

### Required Export

```c
void* nyon_plugin_get_ui_panel(NyonPluginContext* ctx);
```

## Loading Plugins

```zig
const std = @import("std");
const nyon = @import("nyon_game");

pub fn main() !void {
    var plugin_system = nyon.PluginSystem.init(allocator);
    defer plugin_system.deinit();

    try plugin_system.loadPlugin("plugins/my_plugin.dll");

    // Plugins are now active
    while (running) {
        plugin_system.updatePlugins(delta_time);
        plugin_system.renderPlugins();
    }
}
```

## Building Plugins

### Zig Plugin

```zig
// build.zig
const lib = b.addSharedLibrary(.{
    .name = "my_plugin",
    .root_source_file = .{ .path = "src/plugin.zig" },
    .target = target,
    .optimize = optimize,
});
b.installArtifact(lib);
```

### C Plugin

```c
// plugin.c
#include "nyon_plugin.h"

NyonPluginCapabilities nyon_plugin_get_capabilities(void) {
    return (NyonPluginCapabilities){
        .name = "My Plugin",
        .version = "1.0.0",
        .author = "Developer",
        .description = "Example plugin",
        .plugin_type = NYON_PLUGIN_MATERIAL,
    };
}
```

Compile with:

```bash
# Windows
cl /LD plugin.c /Fe:my_plugin.dll

# Linux
gcc -shared -fPIC plugin.c -o my_plugin.so

# macOS
clang -dynamiclib plugin.c -o my_plugin.dylib
```

## Error Handling

Plugins should handle errors gracefully:

```zig
export fn nyon_plugin_init(ctx: *PluginContext) callconv(.C) void {
    initializePlugin(ctx) catch |err| {
        std.debug.print("Plugin init failed: {}\n", .{err});
        return;
    };
}
```

## Best Practices

1. **Memory**: Use the provided allocator, not global state
2. **Thread Safety**: Assume update/render may be called from different threads
3. **Cleanup**: Always implement `nyon_plugin_deinit` for proper cleanup
4. **Versioning**: Check engine version in `nyon_plugin_init`
5. **Logging**: Use engine logging facilities when available
