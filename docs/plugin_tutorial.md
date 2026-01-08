# 🎨 Plugin Tutorial: Crafting Your First Custom Geometry Node

**From Zero to Hero: Master the Art of Plugin Development!**

This hands-on tutorial transforms you from a curious developer into a plugin powerhouse. Learn to create a custom geometry node that bends the Nyon Game Engine to your creative will.

## Step 1: Project Setup

Create a new Zig project:

```bash
mkdir nyon_spiral_plugin
cd nyon_spiral_plugin
zig init
```

## Step 2: Plugin Source

Create `src/main.zig`:

```zig
const std = @import("std");

// Plugin capabilities
const capabilities = .{
    .name = "Spiral Generator",
    .version = "1.0.0",
    .author = "Developer",
    .description = "Adds a spiral geometry node",
    .plugin_type = 1, // geometry_node
};

export fn nyon_plugin_get_capabilities() @TypeOf(capabilities) {
    return capabilities;
}

export fn nyon_plugin_init(ctx: *anyopaque) callconv(.C) void {
    _ = ctx;
    std.debug.print("Spiral plugin loaded!\n", .{});
}

export fn nyon_plugin_deinit(ctx: *anyopaque) callconv(.C) void {
    _ = ctx;
    std.debug.print("Spiral plugin unloaded\n", .{});
}

export fn nyon_plugin_create_geometry_node(
    ctx: *anyopaque,
    node_type: [*:0]const u8,
) callconv(.C) ?*anyopaque {
    _ = ctx;
    const type_str = std.mem.span(node_type);

    if (std.mem.eql(u8, type_str, "spiral")) {
        // Return spiral node data
        return createSpiralNode();
    }
    return null;
}

fn createSpiralNode() *anyopaque {
    // Implementation would create and return node
    return undefined;
}
```

## Step 3: Build Configuration

Update `build.zig`:

```zig
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addSharedLibrary(.{
        .name = "spiral_plugin",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(lib);
}
```

## Step 4: Build

```bash
zig build
```

Output: `zig-out/lib/spiral_plugin.dll` (or .so/.dylib)

## Step 5: Install

Copy to `nyon-game/plugins/`:

```bash
cp zig-out/lib/spiral_plugin.* ../nyon-game/plugins/
```

## Step 6: Load in Engine

In your game code:

```zig
var plugins = PluginSystem.init(allocator);
try plugins.loadPlugin("plugins/spiral_plugin.dll");

// Use the new node type
const node = plugins.createGeometryNode("spiral");
```

## 🚀 Next Steps - Your Plugin Journey Continues

Now that you've conquered the basics, unleash your full potential:

- **📚 Master the API**: Dive deep into `docs/plugin_api.md` for the complete API reference
- **🔧 Explore the Core**: Examine `src/plugin_system.zig` for implementation insights
- **💡 Get Inspired**: Browse revolutionary example plugins in `examples/plugins/`
- **🌍 Join the Community**: Share your creations and collaborate with fellow innovators

**The plugin ecosystem is yours to command. What impossible feature will you create next?**
