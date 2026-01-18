//! World Module
//!
//! Re-exports world generation systems including noise, biomes, terrain, weather,
//! chunk LOD management, and streaming systems.

pub const noise = @import("noise.zig");
pub const biome = @import("biome.zig");
pub const terrain = @import("terrain.zig");
pub const weather = @import("weather.zig");
pub const chunk_lod = @import("chunk_lod.zig");
pub const chunk_manager = @import("chunk_manager.zig");

// Re-export commonly used types
pub const SeededNoise = noise.SeededNoise;
pub const VoronoiResult = noise.VoronoiResult;

pub const Biome = biome.Biome;
pub const BiomeType = biome.BiomeType;
pub const BiomeGenerator = biome.BiomeGenerator;
pub const TreeType = biome.TreeType;
pub const OreConfig = biome.OreConfig;
pub const ORES = biome.ORES;

pub const TerrainGenerator = terrain.TerrainGenerator;
pub const SEA_LEVEL = terrain.SEA_LEVEL;

// Weather system types
pub const Weather = weather.Weather;
pub const WeatherType = weather.WeatherType;
pub const BiomeWeather = weather.BiomeWeather;
pub const WeatherAudio = weather.WeatherAudio;
pub const LightningFlash = weather.LightningFlash;
pub const PrecipitationConfig = weather.PrecipitationConfig;

// LOD and streaming types
pub const LODLevel = chunk_lod.LODLevel;
pub const ChunkLOD = chunk_lod.ChunkLOD;
pub const RenderDistance = chunk_lod.RenderDistance;
pub const LODDistances = chunk_lod.LODDistances;
pub const LODStats = chunk_lod.LODStats;

pub const ChunkCoord = chunk_manager.ChunkCoord;
pub const ChunkManager = chunk_manager.ChunkManager;
pub const ChunkState = chunk_manager.ChunkState;
pub const ChunkEntry = chunk_manager.ChunkEntry;
pub const ChunkPool = chunk_manager.ChunkPool;
pub const GreedyMesher = chunk_manager.GreedyMesher;
pub const OcclusionCuller = chunk_manager.OcclusionCuller;

test {
    _ = noise;
    _ = biome;
    _ = terrain;
    _ = weather;
    _ = chunk_lod;
    _ = chunk_manager;
}
