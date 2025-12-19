const std = @import("std");
const engine = @import("engine.zig");
const raylib = @import("raylib");

/// Simple texture wrapper used by materials.
pub const Texture = struct {
    id: u32,
    width: u32,
    height: u32,
};

/// Basic material representation.
/// Supports a diffuse texture, an optional normal map, and a shading program.
/// Uses raylib's `LoadTextureFromImage` under the hood.
pub const Material = struct {
    diffuse: Texture,
    normal: ?Texture = null,
    shader: u32 = 0, // raylib shader program id

    /// Load a texture from a file. Returns a `Texture` struct.
    pub fn loadTexture(_: *std.mem.Allocator, path: [:0]const u8) !Texture {
        const result = raylib.LoadTexture(path);
        if (result.id == 0) return error.TextureLoadFailed;
        return Texture{ .id = result.id, .width = result.width, .height = result.height };
    }

    /// Create a new material with a diffuse texture.
    pub fn init(alloc: *std.mem.Allocator, diffuse_path: [:0]const u8) !Material {
        const tex = try loadTexture(alloc, diffuse_path);
        return Material{ .diffuse = tex };
    }

    /// Free owned resources.
    pub fn deinit(self: *Material) void {
        raylib.UnloadTexture(raylib.Texture{ .id = self.diffuse.id });
        if (self.normal) |n| {
            raylib.UnloadTexture(raylib.Texture{ .id = n.id });
        }
    }
};

test "texture load" {
    const a = std.testing.allocator;
    const t = try Material.loadTexture(a, "assets/small.png");
    defer t;
    std.testing.expect(t.id != 0);
}
