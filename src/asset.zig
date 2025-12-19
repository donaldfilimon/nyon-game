const std = @import("std");
const raylib = @import("raylib");
const nyon = @import("nyon_game");

/// Asset Management System
///
/// Provides centralized asset loading, caching, and management for the Nyon Game Engine.
/// Supports models, textures, materials, animations, and other assets with automatic
/// reference counting and cleanup.
pub const AssetManager = struct {
    allocator: std.mem.Allocator,

    /// Asset caches
    models: std.StringHashMap(AssetEntry(raylib.Model)),
    textures: std.StringHashMap(AssetEntry(raylib.Texture)),
    materials: std.StringHashMap(AssetEntry(nyon.MaterialSystem.Material)),
    animations: std.StringHashMap(AssetEntry(nyon.AnimationSystem.AnimationClip)),
    audio: std.StringHashMap(AssetEntry(raylib.Sound)),

    /// Asset types
    pub const AssetType = enum {
        model,
        texture,
        material,
        animation,
        audio,
        custom,
    };

    /// Generic asset entry with reference counting
    pub fn AssetEntry(comptime T: type) type {
        return struct {
            asset: T,
            ref_count: usize,
            file_path: []const u8,
            asset_type: AssetType,
            metadata: std.StringHashMap([]const u8), // Key-value metadata
        };
    }

    /// Asset loading options
    pub const LoadOptions = struct {
        preload: bool = false, // Load immediately
        compress: bool = false, // Compress if supported
        generate_mipmaps: bool = true, // Generate mipmaps for textures
        flip_textures: bool = true, // Flip textures on load
    };

    /// Initialize the asset manager
    pub fn init(allocator: std.mem.Allocator) AssetManager {
        return .{
            .allocator = allocator,
            .models = std.StringHashMap(AssetEntry(raylib.Model)).init(allocator),
            .textures = std.StringHashMap(AssetEntry(raylib.Texture)).init(allocator),
            .materials = std.StringHashMap(AssetEntry(nyon.MaterialSystem.Material)).init(allocator),
            .animations = std.StringHashMap(AssetEntry(nyon.AnimationSystem.AnimationClip)).init(allocator),
            .audio = std.StringHashMap(AssetEntry(raylib.Sound)).init(allocator),
        };
    }

    /// Deinitialize the asset manager and free all assets
    pub fn deinit(self: *AssetManager) void {
        // Clean up models
        var model_iter = self.models.iterator();
        while (model_iter.next()) |entry| {
            raylib.unloadModel(entry.value_ptr.asset);
            self.allocator.free(entry.value_ptr.file_path);
            entry.value_ptr.metadata.deinit();
        }
        self.models.deinit();

        // Clean up textures
        var tex_iter = self.textures.iterator();
        while (tex_iter.next()) |entry| {
            raylib.unloadTexture(entry.value_ptr.asset);
            self.allocator.free(entry.value_ptr.file_path);
            entry.value_ptr.metadata.deinit();
        }
        self.textures.deinit();

        // Clean up materials (materials are managed by MaterialSystem)
        var mat_iter = self.materials.iterator();
        while (mat_iter.next()) |entry| {
            entry.value_ptr.metadata.deinit();
            // Note: Material assets are freed by MaterialSystem
        }
        self.materials.deinit();

        // Clean up animations (animations are managed by AnimationSystem)
        var anim_iter = self.animations.iterator();
        while (anim_iter.next()) |entry| {
            entry.value_ptr.metadata.deinit();
            // Note: Animation assets are freed by AnimationSystem
        }
        self.animations.deinit();

        // Clean up audio
        var audio_iter = self.audio.iterator();
        while (audio_iter.next()) |entry| {
            raylib.unloadSound(entry.value_ptr.asset);
            self.allocator.free(entry.value_ptr.file_path);
            entry.value_ptr.metadata.deinit();
        }
        self.audio.deinit();
    }

    /// Load a model asset
    pub fn loadModel(_: *AssetManager, file_path: []const u8, _: LoadOptions) !raylib.Model {
        // Options not yet implemented for models
        // For now, just load directly without caching
        const model = raylib.loadModel(file_path.ptr);
        return model;
    }

    /// Load a texture asset
    pub fn loadTexture(self: *AssetManager, file_path: []const u8, options: LoadOptions) !raylib.Texture {
        // Check cache first
        if (self.textures.get(file_path)) |*entry| {
            entry.ref_count += 1;
            return entry.asset;
        }

        // Load new texture
        var texture: raylib.Texture = undefined;

        if (options.flip_textures) {
            raylib.imageFlipVertical(&raylib.loadImage(file_path.ptr));
        }

        if (std.mem.eql(u8, std.fs.path.extension(file_path), ".png") or
            std.mem.eql(u8, std.fs.path.extension(file_path), ".jpg") or
            std.mem.eql(u8, std.fs.path.extension(file_path), ".jpeg") or
            std.mem.eql(u8, std.fs.path.extension(file_path), ".bmp"))
        {
            texture = raylib.loadTexture(file_path.ptr);
        } else {
            return error.UnsupportedTextureFormat;
        }

        if (texture.id == 0) {
            return error.TextureLoadFailed;
        }

        // Generate mipmaps if requested
        if (options.generate_mipmaps) {
            raylib.genTextureMipmaps(&texture);
        }

        // Create asset entry
        const path_copy = try self.allocator.dupe(u8, file_path);
        errdefer self.allocator.free(path_copy);

        var metadata = std.StringHashMap([]const u8).init(self.allocator);
        errdefer metadata.deinit();

        // Add texture metadata
        const width_str = try std.fmt.allocPrint(self.allocator, "{}", .{texture.width});
        defer self.allocator.free(width_str);
        try metadata.put("width", width_str);

        const height_str = try std.fmt.allocPrint(self.allocator, "{}", .{texture.height});
        defer self.allocator.free(height_str);
        try metadata.put("height", height_str);

        const entry = AssetEntry(raylib.Texture){
            .asset = texture,
            .ref_count = 1,
            .file_path = path_copy,
            .asset_type = .texture,
            .metadata = metadata,
        };

        try self.textures.put(path_copy, entry);
        return texture;
    }

    /// Unload an asset by path
    pub fn unloadAsset(self: *AssetManager, file_path: []const u8) void {
        // Try to unload from each cache
        if (self.models.getPtr(file_path)) |entry| {
            entry.ref_count -= 1;
            if (entry.ref_count == 0) {
                raylib.unloadModel(entry.asset);
                self.allocator.free(entry.file_path);
                entry.metadata.deinit();
                _ = self.models.remove(file_path);
            }
        } else if (self.textures.getPtr(file_path)) |entry| {
            entry.ref_count -= 1;
            if (entry.ref_count == 0) {
                raylib.unloadTexture(entry.asset);
                self.allocator.free(entry.file_path);
                entry.metadata.deinit();
                _ = self.textures.remove(file_path);
            }
        }
        // Note: Materials and animations are managed by their respective systems
    }

    /// Get asset metadata
    pub fn getAssetMetadata(self: *const AssetManager, file_path: []const u8, key: []const u8) ?[]const u8 {
        if (self.models.get(file_path)) |entry| {
            return entry.metadata.get(key);
        } else if (self.textures.get(file_path)) |entry| {
            return entry.metadata.get(key);
        } else if (self.materials.get(file_path)) |entry| {
            return entry.metadata.get(key);
        }
        return null;
    }

    /// Set asset metadata
    pub fn setAssetMetadata(self: *AssetManager, file_path: []const u8, key: []const u8, value: []const u8) !void {
        const value_copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(value_copy);

        if (self.models.getPtr(file_path)) |entry| {
            if (entry.metadata.get(key)) |old_value| {
                self.allocator.free(old_value);
            }
            try entry.metadata.put(key, value_copy);
        } else if (self.textures.getPtr(file_path)) |entry| {
            if (entry.metadata.get(key)) |old_value| {
                self.allocator.free(old_value);
            }
            try entry.metadata.put(key, value_copy);
        } else {
            self.allocator.free(value_copy);
            return error.AssetNotFound;
        }
    }

    /// Get file size helper
    fn getFileSize(self: *const AssetManager, file_path: []const u8) !u64 {
        _ = self;
        const file = try std.fs.openFileAbsolute(file_path, .{});
        defer file.close();
        return try file.getEndPos();
    }

    /// Get memory usage statistics
    pub fn getMemoryStats(self: *const AssetManager) struct {
        models_loaded: usize,
        textures_loaded: usize,
        materials_loaded: usize,
        animations_loaded: usize,
        audio_loaded: usize,
        total_assets: usize,
    } {
        return .{
            .models_loaded = self.models.count(),
            .textures_loaded = self.textures.count(),
            .materials_loaded = self.materials.count(),
            .animations_loaded = self.animations.count(),
            .audio_loaded = self.audio.count(),
            .total_assets = self.models.count() + self.textures.count() +
                self.materials.count() + self.animations.count() + self.audio.count(),
        };
    }

    /// Preload assets from a list
    pub fn preloadAssets(self: *AssetManager, asset_list: []const []const u8, options: LoadOptions) !void {
        for (asset_list) |asset_path| {
            const ext = std.fs.path.extension(asset_path);

            if (std.mem.eql(u8, ext, ".obj") or std.mem.eql(u8, ext, ".gltf") or std.mem.eql(u8, ext, ".glb")) {
                _ = try self.loadModel(asset_path, options);
            } else if (std.mem.eql(u8, ext, ".png") or std.mem.eql(u8, ext, ".jpg") or
                std.mem.eql(u8, ext, ".jpeg") or std.mem.eql(u8, ext, ".bmp"))
            {
                _ = try self.loadTexture(asset_path, options);
            }
        }
    }

    /// Clear unused assets (ref_count == 0)
    pub fn clearUnusedAssets(self: *AssetManager) void {
        _ = self; // Not yet implemented
        // This would be more complex in a full implementation
        // For now, assets are only unloaded when explicitly requested
    }

    /// Export asset manifest (for debugging/project management)
    pub fn exportManifest(self: *const AssetManager, allocator: std.mem.Allocator) ![]const u8 {
        var manifest = std.ArrayList(u8).init(allocator);
        defer manifest.deinit();

        try manifest.appendSlice("Asset Manifest\n");
        try manifest.appendSlice("================\n\n");

        // Models
        try manifest.appendSlice("Models:\n");
        var model_iter = self.models.iterator();
        while (model_iter.next()) |entry| {
            try manifest.writer().print("  - {s} (refs: {})\n", .{ entry.value_ptr.file_path, entry.value_ptr.ref_count });
        }

        // Textures
        try manifest.appendSlice("\nTextures:\n");
        var tex_iter = self.textures.iterator();
        while (tex_iter.next()) |entry| {
            try manifest.writer().print("  - {s} (refs: {})\n", .{ entry.value_ptr.file_path, entry.value_ptr.ref_count });
        }

        return manifest.toOwnedSlice();
    }
};
