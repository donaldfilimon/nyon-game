const std = @import("std");
const raylib = @import("raylib");
const nyon = @import("nyon_game");

/// Asset-specific error types with detailed context (modern error handling)
pub const AssetError = union(enum) {
    unsupported_texture_format: struct {
        path: []const u8,
        extension: []const u8,
    },
    texture_load_failed: struct {
        path: []const u8,
        reason: []const u8,
    },
    file_not_found: struct {
        path: []const u8,
        attempted_location: []const u8,
    },
    out_of_memory: struct {
        requested_size: usize,
        available_size: usize,
    },
    invalid_asset_data: struct {
        path: []const u8,
        expected_format: []const u8,
        actual_format: []const u8,
    },
    metadata_error: struct {
        key: []const u8,
        reason: []const u8,
    },
};

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
    sounds_by_handle: std.AutoHashMap(u64, raylib.Sound),
    next_audio_handle: u64 = 1,

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
            .sounds_by_handle = std.AutoHashMap(u64, raylib.Sound).init(allocator),
            .next_audio_handle = 1,
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
        self.sounds_by_handle.deinit();
    }

    /// Load a model asset
    pub fn loadModel(self: *AssetManager, file_path: []const u8, _: LoadOptions) (AssetError || error{OutOfMemory})!raylib.Model {
        // Check cache first
        if (self.models.get(file_path)) |*entry| {
            entry.ref_count += 1;
            return entry.asset;
        }

        // Check if file exists before loading
        const file = std.fs.cwd().openFile(file_path, .{}) catch {
            return AssetError{ .file_not_found = .{
                .path = file_path,
                .attempted_location = "current working directory",
            } };
        };
        file.close();

        // Load new model
        const path_z = try self.allocator.dupeZ(u8, file_path);
        defer self.allocator.free(path_z);

        const model = raylib.loadModel(path_z) catch {
            return AssetError{ .invalid_asset_data = .{
                .path = file_path,
                .expected_format = "Valid 3D model file (.obj, .gltf, etc.)",
                .actual_format = "Raylib failed to load model",
            } };
        };

        // Check if model loaded successfully
        if (model.meshCount == 0) {
            return AssetError{ .invalid_asset_data = .{
                .path = file_path,
                .expected_format = "Valid 3D model file (.obj, .gltf, etc.)",
                .actual_format = "Empty or corrupted model file",
            } };
        }

        // Create asset entry with caching
        const path_copy = try self.allocator.dupe(u8, file_path);
        errdefer self.allocator.free(path_copy);

        const metadata = std.StringHashMap([]const u8).init(self.allocator);

        const entry = AssetEntry(raylib.Model){
            .asset = model,
            .ref_count = 1,
            .file_path = path_copy,
            .asset_type = .model,
            .metadata = metadata,
        };

        try self.models.put(path_copy, entry);

        return model;
    }

    /// Load an audio asset
    pub fn loadAudio(self: *AssetManager, file_path: []const u8, _: LoadOptions) (AssetError || error{OutOfMemory})!raylib.Sound {
        // Check cache first
        if (self.audio.get(file_path)) |*entry| {
            entry.ref_count += 1;
            return entry.asset;
        }

        // Check if file exists
        const file = std.fs.cwd().openFile(file_path, .{}) catch {
            return AssetError{ .file_not_found = .{
                .path = file_path,
                .attempted_location = "current working directory",
            } };
        };
        file.close();

        // Load new sound
        const path_z = try self.allocator.dupeZ(u8, file_path);
        defer self.allocator.free(path_z);

        const sound = raylib.loadSound(path_z) catch {
            return AssetError{ .invalid_asset_data = .{
                .path = file_path,
                .expected_format = "Valid audio file (.wav, .mp3, .ogg)",
                .actual_format = "Raylib failed to load sound",
            } };
        };

        if (sound.frameCount == 0) {
            return AssetError{ .invalid_asset_data = .{
                .path = file_path,
                .expected_format = "Valid audio file",
                .actual_format = "Empty or corrupted audio file",
            } };
        }

        // Create asset entry
        const path_copy = try self.allocator.dupe(u8, file_path);
        errdefer self.allocator.free(path_copy);

        const metadata = std.StringHashMap([]const u8).init(self.allocator);

        const entry = AssetEntry(raylib.Sound){
            .asset = sound,
            .ref_count = 1,
            .file_path = path_copy,
            .asset_type = .audio,
            .metadata = metadata,
        };

        try self.audio.put(path_copy, entry);

        // Assign handle
        const handle = self.next_audio_handle;
        self.next_audio_handle += 1;
        try self.sounds_by_handle.put(handle, sound);

        return sound;
    }

    /// Get sound by its numeric handle
    pub fn getSoundByHandle(self: *const AssetManager, handle: u64) ?raylib.Sound {
        return self.sounds_by_handle.get(handle);
    }

    /// Get handle for a loaded audio asset path
    pub fn getAudioHandle(self: *const AssetManager, file_path: []const u8) ?u64 {
        const sound = if (self.audio.get(file_path)) |entry| entry.asset else return null;
        var iter = self.sounds_by_handle.iterator();
        while (iter.next()) |entry| {
            // This is a bit slow but okay for initialization
            if (entry.value_ptr.id == sound.id) return entry.key_ptr.*;
        }
        return null;
    }

    /// Load a texture asset
    pub fn loadTexture(self: *AssetManager, file_path: []const u8, options: LoadOptions) (AssetError || error{OutOfMemory})!raylib.Texture {
        // Check cache first
        if (self.textures.get(file_path)) |*entry| {
            entry.ref_count += 1;
            return entry.asset;
        }

        // Check if file exists before loading
        const file = std.fs.cwd().openFile(file_path, .{}) catch {
            return AssetError{ .file_not_found = .{
                .path = file_path,
                .attempted_location = "current working directory",
            } };
        };
        file.close();

        // Load new texture
        var texture: raylib.Texture = undefined;
        const path_z = try self.allocator.dupeZ(u8, file_path);
        defer self.allocator.free(path_z);

        const ext = std.fs.path.extension(file_path);
        if (std.mem.eql(u8, ext, ".png") or
            std.mem.eql(u8, ext, ".jpg") or
            std.mem.eql(u8, ext, ".jpeg") or
            std.mem.eql(u8, ext, ".bmp"))
        {
            if (options.flip_textures) {
                var image = raylib.loadImage(path_z) catch {
                    return AssetError{ .texture_load_failed = .{
                        .path = file_path,
                        .reason = "Raylib failed to load image for flipping",
                    } };
                };
                defer raylib.unloadImage(image);
                raylib.imageFlipVertical(&image);
                texture = raylib.loadTextureFromImage(image) catch {
                    return AssetError{ .texture_load_failed = .{
                        .path = file_path,
                        .reason = "Raylib failed to load texture from image",
                    } };
                };
            } else {
                texture = raylib.loadTexture(path_z) catch {
                    return AssetError{ .texture_load_failed = .{
                        .path = file_path,
                        .reason = "Raylib failed to load texture",
                    } };
                };
            }
        } else {
            return AssetError{ .unsupported_texture_format = .{
                .path = file_path,
                .extension = ext,
            } };
        }

        if (texture.id == 0) {
            return AssetError{ .texture_load_failed = .{
                .path = file_path,
                .reason = "Raylib failed to load texture (invalid file or unsupported format)",
            } };
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

        // Use arena allocator for temporary metadata strings (modern pattern)
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const temp_allocator = arena.allocator();

        // Add texture metadata
        const width_str = try std.fmt.allocPrint(temp_allocator, "{}", .{texture.width});
        try metadata.put("width", try self.allocator.dupe(u8, width_str));

        const height_str = try std.fmt.allocPrint(temp_allocator, "{}", .{texture.height});
        try metadata.put("height", try self.allocator.dupe(u8, height_str));

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
        } else if (self.audio.getPtr(file_path)) |entry| {
            entry.ref_count -= 1;
            if (entry.ref_count == 0) {
                raylib.unloadSound(entry.asset);
                self.allocator.free(entry.file_path);
                entry.metadata.deinit();
                _ = self.audio.remove(file_path);
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
    pub fn setAssetMetadata(self: *AssetManager, file_path: []const u8, key: []const u8, value: []const u8) (AssetError || error{OutOfMemory})!void {
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
            return AssetError{ .invalid_asset_data = .{
                .path = file_path,
                .expected_format = "Loaded asset",
                .actual_format = "Asset not found in cache",
            } };
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
        var manifest = std.ArrayList(u8).initCapacity(allocator, 0) catch unreachable;
        defer manifest.deinit(allocator);

        try manifest.appendSlice(allocator, "Asset Manifest\n");
        try manifest.appendSlice(allocator, "================\n\n");

        // Models
        try manifest.appendSlice(allocator, "Models:\n");
        var model_iter = self.models.iterator();
        while (model_iter.next()) |entry| {
            try manifest.print(allocator, "  - {s} (refs: {})\n", .{ entry.value_ptr.file_path, entry.value_ptr.ref_count });
        }

        // Textures
        try manifest.appendSlice(allocator, "\nTextures:\n");
        var tex_iter = self.textures.iterator();
        while (tex_iter.next()) |entry| {
            try manifest.print(allocator, "  - {s} (refs: {})\n", .{ entry.value_ptr.file_path, entry.value_ptr.ref_count });
        }

        return manifest.toOwnedSlice(allocator);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "AssetManager initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var asset_manager = AssetManager.init(allocator);
    defer asset_manager.deinit();

    try std.testing.expectEqual(asset_manager.models.count(), 0);
    try std.testing.expectEqual(asset_manager.textures.count(), 0);
    try std.testing.expectEqual(asset_manager.materials.count(), 0);
}

test "AssetError detailed context" {
    const err = AssetError{ .unsupported_texture_format = .{
        .path = "test.png",
        .extension = ".png",
    } };

    try std.testing.expect(std.mem.eql(u8, err.unsupported_texture_format.path, "test.png"));
    try std.testing.expect(std.mem.eql(u8, err.unsupported_texture_format.extension, ".png"));
}

test "AssetManager manifest generation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var asset_manager = AssetManager.init(allocator);
    defer asset_manager.deinit();

    const manifest = try asset_manager.exportManifest(allocator);
    defer allocator.free(manifest);

    try std.testing.expect(std.mem.indexOf(u8, manifest, "Asset Manifest") != null);
}
