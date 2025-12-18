const std = @import("std");
const raylib = @import("raylib");

/// Game engine with full raylib integration
/// Provides organized access to all raylib functionality
pub const Engine = struct {
    allocator: std.mem.Allocator,
    width: u32,
    height: u32,
    title: [:0]const u8,
    raylib_initialized: bool = false,
    target_fps: ?u32 = null,

    /// Backend type for the engine (currently only raylib is supported)
    pub const Backend = enum {
        /// Use raylib for high-level game development features
        raylib,
    };

    /// Configuration for engine initialization
    pub const Config = struct {
        backend: Backend = .raylib,
        width: u32 = 800,
        height: u32 = 600,
        title: [:0]const u8 = "Nyon Game",
        target_fps: ?u32 = 60,
        resizable: bool = true,
        fullscreen: bool = false,
        vsync: bool = true,
        samples: u32 = 0, // MSAA samples
    };

    /// Initialize the engine with the specified configuration
    /// Supports universal std.gpu, GLFW, and raylib backends
    pub fn init(allocator: std.mem.Allocator, config: Config) !Engine {
        var engine = Engine{
            .allocator = allocator,
            .width = config.width,
            .height = config.height,
            .title = config.title,
            .target_fps = config.target_fps,
        };

        // Initialize raylib backend
        try engine.initRaylibBackend(config);

        return engine;
    }

    /// Initialize raylib backend for high-level features
    fn initRaylibBackend(engine: *Engine, config: Config) !void {
        // Configure raylib flags
        const flags = raylib.ConfigFlags{
            .fullscreen_mode = config.fullscreen,
            .window_resizable = config.resizable,
            .vsync_hint = config.vsync,
            .msaa_4x_hint = config.samples > 0,
        };

        raylib.setConfigFlags(flags);
        raylib.initWindow(@intCast(config.width), @intCast(config.height), config.title);
        engine.raylib_initialized = true;

        if (config.target_fps) |fps| {
            raylib.setTargetFPS(@intCast(fps));
        }
    }

    /// Deinitialize the engine and clean up all resources
    pub fn deinit(engine: *Engine) void {
        // Clean up raylib if used
        if (engine.raylib_initialized) {
            raylib.closeWindow();
            engine.raylib_initialized = false;
        }
    }

    /// Check if the window should close
    pub fn shouldClose(engine: *Engine) bool {
        if (engine.raylib_initialized) {
            return raylib.windowShouldClose();
        }
        return false; // No window initialized
    }

    /// Poll for events (raylib handles this automatically)
    pub fn pollEvents(engine: *Engine) void {
        // Raylib handles events automatically in its drawing functions
        _ = engine;
    }

    /// Begin drawing frame (raylib-style API)
    pub fn beginDrawing(engine: *Engine) void {
        if (engine.raylib_initialized) {
            raylib.beginDrawing();
        }
        // For GLFW/GPU backends, drawing is handled differently
    }

    /// End drawing frame (raylib-style API)
    pub fn endDrawing(engine: *Engine) void {
        if (engine.raylib_initialized) {
            raylib.endDrawing();
        }
    }

    /// Clear background with color
    pub fn clearBackground(engine: *Engine, color: raylib.Color) void {
        if (engine.raylib_initialized) {
            raylib.clearBackground(color);
        }
    }

    /// Get the current window size
    pub fn getWindowSize(engine: *Engine) struct { width: u32, height: u32 } {
        if (engine.raylib_initialized) {
            return .{
                .width = @intCast(raylib.getScreenWidth()),
                .height = @intCast(raylib.getScreenHeight()),
            };
        }
        return .{ .width = engine.width, .height = engine.height };
    }

    /// Set target FPS
    pub fn setTargetFPS(engine: *Engine, fps: u32) void {
        engine.target_fps = fps;
        if (engine.raylib_initialized) {
            raylib.setTargetFPS(@intCast(fps));
        }
        // GLFW doesn't have built-in FPS limiting
    }

    /// Get current FPS
    pub fn getFPS(engine: *Engine) u32 {
        if (engine.raylib_initialized) {
            return @intCast(raylib.getFPS());
        }
        return 0; // Not available for GLFW/GPU backends
    }

    /// Get frame time in seconds
    pub fn getFrameTime(engine: *Engine) f32 {
        if (engine.raylib_initialized) {
            return raylib.getFrameTime();
        }
        return 0.0; // Not available for GLFW/GPU backends
    }

    /// Get time since engine initialization
    pub fn getTime(engine: *Engine) f64 {
        if (engine.raylib_initialized) {
            return raylib.getTime();
        }
        return 0.0; // Not available for GLFW/GPU backends
    }
};

// Re-export all raylib types and functions for convenience
pub const Color = raylib.Color;
pub const Vector2 = raylib.Vector2;
pub const Vector3 = raylib.Vector3;
pub const Vector4 = raylib.Vector4;
pub const Rectangle = raylib.Rectangle;
pub const Image = raylib.Image;
pub const Texture = raylib.Texture;
pub const Texture2D = raylib.Texture2D;
pub const RenderTexture = raylib.RenderTexture;
pub const RenderTexture2D = raylib.RenderTexture2D;
pub const NPatchInfo = raylib.NPatchInfo;
pub const GlyphInfo = raylib.GlyphInfo;
pub const Font = raylib.Font;
pub const Camera3D = raylib.Camera3D;
pub const Camera = raylib.Camera;
pub const Camera2D = raylib.Camera2D;
pub const Mesh = raylib.Mesh;
pub const Shader = raylib.Shader;
pub const MaterialMap = raylib.MaterialMap;
pub const Material = raylib.Material;
pub const Transform = raylib.Transform;
pub const BoneInfo = raylib.BoneInfo;
pub const Model = raylib.Model;
pub const ModelAnimation = raylib.ModelAnimation;
pub const Ray = raylib.Ray;
pub const RayCollision = raylib.RayCollision;
pub const BoundingBox = raylib.BoundingBox;
pub const Wave = raylib.Wave;
pub const AudioStream = raylib.AudioStream;
pub const Sound = raylib.Sound;
pub const Music = raylib.Music;
pub const VrDeviceInfo = raylib.VrDeviceInfo;
pub const VrStereoConfig = raylib.VrStereoConfig;
pub const FilePathList = raylib.FilePathList;
pub const AutomationEvent = raylib.AutomationEvent;
pub const AutomationEventList = raylib.AutomationEventList;
pub const ConfigFlags = raylib.ConfigFlags;
pub const TraceLogLevel = raylib.TraceLogLevel;
pub const KeyboardKey = raylib.KeyboardKey;
pub const MouseButton = raylib.MouseButton;
pub const MouseCursor = raylib.MouseCursor;
pub const GamepadButton = raylib.GamepadButton;
pub const GamepadAxis = raylib.GamepadAxis;
pub const MaterialMapIndex = raylib.MaterialMapIndex;
pub const ShaderLocationIndex = raylib.ShaderLocationIndex;
pub const ShaderUniformDataType = raylib.ShaderUniformDataType;
pub const ShaderAttribute = raylib.ShaderAttribute;
pub const PixelFormat = raylib.PixelFormat;
pub const TextureFilter = raylib.TextureFilter;
pub const TextureWrap = raylib.TextureWrap;
pub const CubemapLayout = raylib.CubemapLayout;
pub const FontType = raylib.FontType;
pub const BlendMode = raylib.BlendMode;
pub const Gesture = raylib.Gesture;
pub const CameraMode = raylib.CameraMode;
pub const CameraProjection = raylib.CameraProjection;
pub const NPatchType = raylib.NPatchType;
pub const Quaternion = raylib.Quaternion;
pub const Matrix = raylib.Matrix;
pub const RaylibError = raylib.RaylibError;

// Re-export raylib constants
pub const RAYLIB_VERSION_MAJOR = raylib.RAYLIB_VERSION_MAJOR;
pub const RAYLIB_VERSION_MINOR = raylib.RAYLIB_VERSION_MINOR;
pub const RAYLIB_VERSION_PATCH = raylib.RAYLIB_VERSION_PATCH;
pub const RAYLIB_VERSION = raylib.RAYLIB_VERSION;
pub const MAX_TOUCH_POINTS = raylib.MAX_TOUCH_POINTS;
pub const MAX_MATERIAL_MAPS = raylib.MAX_MATERIAL_MAPS;
pub const MAX_SHADER_LOCATIONS = raylib.MAX_SHADER_LOCATIONS;

// Re-export all raylib functions
pub const Window = struct {
    pub const init = raylib.initWindow;
    pub const close = raylib.closeWindow;
    pub const shouldClose = raylib.windowShouldClose;
    pub const isReady = raylib.isWindowReady;
    pub const isFullscreen = raylib.isWindowFullscreen;
    pub const isHidden = raylib.isWindowHidden;
    pub const isMinimized = raylib.isWindowMinimized;
    pub const isMaximized = raylib.isWindowMaximized;
    pub const isFocused = raylib.isWindowFocused;
    pub const isResized = raylib.isWindowResized;
    pub const isState = raylib.isWindowState;
    pub const setState = raylib.setWindowState;
    pub const clearState = raylib.clearWindowState;
    pub const toggleFullscreen = raylib.toggleFullscreen;
    pub const toggleBorderlessWindowed = raylib.toggleBorderlessWindowed;
    pub const maximize = raylib.maximizeWindow;
    pub const minimize = raylib.minimizeWindow;
    pub const restore = raylib.restoreWindow;
    pub const setIcon = raylib.setWindowIcon;
    pub const setIcons = raylib.setWindowIcons;
    pub const setTitle = raylib.setWindowTitle;
    pub const setPosition = raylib.setWindowPosition;
    pub const setMonitor = raylib.setWindowMonitor;
    pub const setMinSize = raylib.setWindowMinSize;
    pub const setMaxSize = raylib.setWindowMaxSize;
    pub const setSize = raylib.setWindowSize;
    pub const setOpacity = raylib.setWindowOpacity;
    pub const setFocused = raylib.setWindowFocused;
    pub const getHandle = raylib.getWindowHandle;
    pub const getScreenWidth = raylib.getScreenWidth;
    pub const getScreenHeight = raylib.getScreenHeight;
    pub const getRenderWidth = raylib.getRenderWidth;
    pub const getRenderHeight = raylib.getRenderHeight;
    pub const getPosition = raylib.getWindowPosition;
    pub const getScaleDPI = raylib.getWindowScaleDPI;
};

pub const Monitor = struct {
    pub const getCount = raylib.getMonitorCount;
    pub const getCurrent = raylib.getCurrentMonitor;
    pub const getPosition = raylib.getMonitorPosition;
    pub const getWidth = raylib.getMonitorWidth;
    pub const getHeight = raylib.getMonitorHeight;
    pub const getPhysicalWidth = raylib.getMonitorPhysicalWidth;
    pub const getPhysicalHeight = raylib.getMonitorPhysicalHeight;
    pub const getRefreshRate = raylib.getMonitorRefreshRate;
    pub const getName = raylib.getMonitorName;
};

pub const Cursor = struct {
    pub const show = raylib.showCursor;
    pub const hide = raylib.hideCursor;
    pub const isHidden = raylib.isCursorHidden;
    pub const enable = raylib.enableCursor;
    pub const disable = raylib.disableCursor;
    pub const isOnScreen = raylib.isCursorOnScreen;
    pub const set = raylib.setMouseCursor;
};

pub const Drawing = struct {
    pub const begin = raylib.beginDrawing;
    pub const end = raylib.endDrawing;
    pub const clearBackground = raylib.clearBackground;
    pub const beginMode2D = raylib.beginMode2D;
    pub const endMode2D = raylib.endMode2D;
    pub const beginMode3D = raylib.beginMode3D;
    pub const endMode3D = raylib.endMode3D;
    pub const beginTextureMode = raylib.beginTextureMode;
    pub const endTextureMode = raylib.endTextureMode;
    pub const beginShaderMode = raylib.beginShaderMode;
    pub const endShaderMode = raylib.endShaderMode;
    pub const beginBlendMode = raylib.beginBlendMode;
    pub const endBlendMode = raylib.endBlendMode;
    pub const beginScissorMode = raylib.beginScissorMode;
    pub const endScissorMode = raylib.endScissorMode;
    pub const beginVrStereoMode = raylib.beginVrStereoMode;
    pub const endVrStereoMode = raylib.endVrStereoMode;
};

pub const Shapes = struct {
    pub const drawPixel = raylib.drawPixel;
    pub const drawPixelV = raylib.drawPixelV;
    pub const drawLine = raylib.drawLine;
    pub const drawLineV = raylib.drawLineV;
    pub const drawLineEx = raylib.drawLineEx;
    pub const drawLineBezier = raylib.drawLineBezier;
    pub const drawLineDashed = raylib.drawLineDashed;
    pub const drawLineStrip = raylib.drawLineStrip;
    pub const drawCircle = raylib.drawCircle;
    pub const drawCircleSector = raylib.drawCircleSector;
    pub const drawCircleSectorLines = raylib.drawCircleSectorLines;
    pub const drawCircleGradient = raylib.drawCircleGradient;
    pub const drawCircleV = raylib.drawCircleV;
    pub const drawCircleLines = raylib.drawCircleLines;
    pub const drawCircleLinesV = raylib.drawCircleLinesV;
    pub const drawEllipse = raylib.drawEllipse;
    pub const drawEllipseV = raylib.drawEllipseV;
    pub const drawEllipseLines = raylib.drawEllipseLines;
    pub const drawEllipseLinesV = raylib.drawEllipseLinesV;
    pub const drawRing = raylib.drawRing;
    pub const drawRingLines = raylib.drawRingLines;
    pub const drawRectangle = raylib.drawRectangle;
    pub const drawRectangleV = raylib.drawRectangleV;
    pub const drawRectangleRec = raylib.drawRectangleRec;
    pub const drawRectanglePro = raylib.drawRectanglePro;
    pub const drawRectangleGradientV = raylib.drawRectangleGradientV;
    pub const drawRectangleGradientH = raylib.drawRectangleGradientH;
    pub const drawRectangleGradientEx = raylib.drawRectangleGradientEx;
    pub const drawRectangleLines = raylib.drawRectangleLines;
    pub const drawRectangleLinesEx = raylib.drawRectangleLinesEx;
    pub const drawRectangleRounded = raylib.drawRectangleRounded;
    pub const drawRectangleRoundedLines = raylib.drawRectangleRoundedLines;
    pub const drawRectangleRoundedLinesEx = raylib.drawRectangleRoundedLinesEx;
    pub const drawTriangle = raylib.drawTriangle;
    pub const drawTriangleLines = raylib.drawTriangleLines;
    pub const drawPoly = raylib.drawPoly;
    pub const drawPolyLines = raylib.drawPolyLines;
    pub const drawPolyLinesEx = raylib.drawPolyLinesEx;
    pub const drawSplineLinear = raylib.drawSplineLinear;
    pub const drawSplineBasis = raylib.drawSplineBasis;
    pub const drawSplineCatmullRom = raylib.drawSplineCatmullRom;
    pub const drawSplineBezierQuadratic = raylib.drawSplineBezierQuadratic;
    pub const drawSplineBezierCubic = raylib.drawSplineBezierCubic;
    pub const drawSplineSegmentLinear = raylib.drawSplineSegmentLinear;
    pub const drawSplineSegmentBasis = raylib.drawSplineSegmentBasis;
    pub const drawSplineSegmentCatmullRom = raylib.drawSplineSegmentCatmullRom;
    pub const drawSplineSegmentBezierQuadratic = raylib.drawSplineSegmentBezierQuadratic;
    pub const drawSplineSegmentBezierCubic = raylib.drawSplineSegmentBezierCubic;
    pub const drawLine3D = raylib.drawLine3D;
    pub const drawPoint3D = raylib.drawPoint3D;
    pub const drawCircle3D = raylib.drawCircle3D;
    pub const drawTriangle3D = raylib.drawTriangle3D;
    pub const drawTriangleStrip3D = raylib.drawTriangleStrip3D;
    pub const drawCube = raylib.drawCube;
    pub const drawCubeV = raylib.drawCubeV;
    pub const drawCubeWires = raylib.drawCubeWires;
    pub const drawCubeWiresV = raylib.drawCubeWiresV;
    pub const drawSphere = raylib.drawSphere;
    pub const drawSphereEx = raylib.drawSphereEx;
    pub const drawSphereWires = raylib.drawSphereWires;
    pub const drawCylinder = raylib.drawCylinder;
    pub const drawCylinderEx = raylib.drawCylinderEx;
    pub const drawCylinderWires = raylib.drawCylinderWires;
    pub const drawCylinderWiresEx = raylib.drawCylinderWiresEx;
    pub const drawCapsule = raylib.drawCapsule;
    pub const drawCapsuleWires = raylib.drawCapsuleWires;
    pub const drawPlane = raylib.drawPlane;
    pub const drawRay = raylib.drawRay;
    pub const drawGrid = raylib.drawGrid;
};

pub const Textures = struct {
    pub const load = raylib.loadTexture;
    pub const loadFromImage = raylib.loadTextureFromImage;
    pub const loadCubemap = raylib.loadTextureCubemap;
    pub const unload = raylib.unloadTexture;
    pub const update = raylib.updateTexture;
    pub const updateRec = raylib.updateTextureRec;
    pub const genMipmaps = raylib.genTextureMipmaps;
    pub const setFilter = raylib.setTextureFilter;
    pub const setWrap = raylib.setTextureWrap;
    pub const draw = raylib.drawTexture;
    pub const drawV = raylib.drawTextureV;
    pub const drawEx = raylib.drawTextureEx;
    pub const drawRec = raylib.drawTextureRec;
    pub const drawPro = raylib.drawTexturePro;
    pub const drawNPatch = raylib.drawTextureNPatch;
};

pub const Images = struct {
    pub const load = raylib.loadImage;
    pub const loadRaw = raylib.loadImageRaw;
    pub const loadAnim = raylib.loadImageAnim;
    pub const loadFromMemory = raylib.loadImageFromMemory;
    pub const loadFromTexture = raylib.loadImageFromTexture;
    pub const loadFromScreen = raylib.loadImageFromScreen;
    pub const unload = raylib.unloadImage;
    pub const exportImage = raylib.exportImage;
    pub const exportToMemory = raylib.exportImageToMemory;
    pub const exportAsCode = raylib.exportImageAsCode;
    pub const genColor = raylib.genImageColor;
    pub const genGradientLinear = raylib.genImageGradientLinear;
    pub const genGradientRadial = raylib.genImageGradientRadial;
    pub const genGradientSquare = raylib.genImageGradientSquare;
    pub const genChecked = raylib.genImageChecked;
    pub const genWhiteNoise = raylib.genImageWhiteNoise;
    pub const genPerlinNoise = raylib.genImagePerlinNoise;
    pub const genCellular = raylib.genImageCellular;
    pub const genText = raylib.genImageText;
    pub const copy = raylib.imageCopy;
    pub const copyRec = raylib.imageFromImage;
    pub const setFormat = raylib.imageFormat;
    pub const toPOT = raylib.imageToPOT;
    pub const crop = raylib.imageCrop;
    pub const alphaCrop = raylib.imageAlphaCrop;
    pub const alphaClear = raylib.imageAlphaClear;
    pub const alphaMask = raylib.imageAlphaMask;
    pub const alphaPremultiply = raylib.imageAlphaPremultiply;
    pub const blurGaussian = raylib.imageBlurGaussian;
    pub const resize = raylib.imageResize;
    pub const resizeNN = raylib.imageResizeNN;
    pub const resizeCanvas = raylib.imageResizeCanvas;
    pub const mipmaps = raylib.imageMipmaps;
    pub const dither = raylib.imageDither;
    pub const flipVertical = raylib.imageFlipVertical;
    pub const flipHorizontal = raylib.imageFlipHorizontal;
    pub const rotate = raylib.imageRotate;
    pub const rotateCW = raylib.imageRotateCW;
    pub const rotateCCW = raylib.imageRotateCCW;
    pub const tint = raylib.imageColorTint;
    pub const invert = raylib.imageColorInvert;
    pub const grayscale = raylib.imageColorGrayscale;
    pub const contrast = raylib.imageColorContrast;
    pub const brightness = raylib.imageColorBrightness;
    pub const replaceColor = raylib.imageColorReplace;
    pub const getAlphaBorder = raylib.getImageAlphaBorder;
    pub const getColor = raylib.getImageColor;
    pub const clearBackground = raylib.imageClearBackground;
    pub const drawPixel = raylib.imageDrawPixel;
    pub const drawPixelV = raylib.imageDrawPixelV;
    pub const drawLine = raylib.imageDrawLine;
    pub const drawLineV = raylib.imageDrawLineV;
    pub const drawCircle = raylib.imageDrawCircle;
    pub const drawCircleV = raylib.imageDrawCircleV;
    pub const drawCircleLines = raylib.imageDrawCircleLines;
    pub const drawCircleLinesV = raylib.imageDrawCircleLinesV;
    pub const drawRectangle = raylib.imageDrawRectangle;
    pub const drawRectangleV = raylib.imageDrawRectangleV;
    pub const drawRectangleRec = raylib.imageDrawRectangleRec;
    pub const drawRectangleLines = raylib.imageDrawRectangleLines;
    pub const drawTriangle = raylib.imageDrawTriangle;
    pub const drawTriangleEx = raylib.imageDrawTriangleEx;
    pub const drawTriangleLines = raylib.imageDrawTriangleLines;
    pub const drawTriangleFan = raylib.imageDrawTriangleFan;
    pub const drawTriangleStrip = raylib.imageDrawTriangleStrip;
    pub const draw = raylib.imageDraw;
    pub const drawText = raylib.imageDrawText;
    pub const drawTextEx = raylib.imageDrawTextEx;
    pub const loadColors = raylib.loadImageColors;
    pub const unloadColors = raylib.unloadImageColors;
    pub const loadPalette = raylib.loadImagePalette;
    pub const unloadPalette = raylib.unloadImagePalette;
};

pub const Text = struct {
    pub const draw = raylib.drawText;
    pub const drawEx = raylib.drawTextEx;
    pub const drawPro = raylib.drawTextPro;
    pub const drawCodepoint = raylib.drawTextCodepoint;
    pub const drawCodepoints = raylib.drawTextCodepoints;
    pub const drawFPS = raylib.drawFPS;
    pub const setLineSpacing = raylib.setTextLineSpacing;
    pub const measure = raylib.measureText;
    pub const measureEx = raylib.measureTextEx;
    pub const getGlyphIndex = raylib.getGlyphIndex;
    pub const getGlyphInfo = raylib.getGlyphInfo;
    pub const getGlyphAtlasRec = raylib.getGlyphAtlasRec;
    pub const format = raylib.textFormat;
    pub const join = raylib.textJoin;
    pub const split = raylib.textSplit;
    pub const append = raylib.textAppend;
    pub const findIndex = raylib.textFindIndex;
    pub const toUpper = raylib.textToUpper;
    pub const toLower = raylib.textToLower;
    pub const toPascal = raylib.textToPascal;
    pub const toSnake = raylib.textToSnake;
    pub const toCamel = raylib.textToCamel;
    pub const toInteger = raylib.textToInteger;
    pub const toFloat = raylib.textToFloat;
    pub const copy = raylib.textCopy;
    pub const isEqual = raylib.textIsEqual;
    pub const length = raylib.textLength;
    pub const subtext = raylib.textSubtext;
    pub const removeSpaces = raylib.textRemoveSpaces;
    pub const getBetween = raylib.getTextBetween;
    pub const replace = raylib.textReplace;
    pub const replaceBetween = raylib.textReplaceBetween;
    pub const insert = raylib.textInsert;
    pub const loadCodepoints = raylib.loadCodepoints;
    pub const unloadCodepoints = raylib.unloadCodepoints;
    pub const getCodepointCount = raylib.getCodepointCount;
    pub const getCodepoint = raylib.getCodepoint;
    pub const getCodepointNext = raylib.getCodepointNext;
    pub const getCodepointPrevious = raylib.getCodepointPrevious;
    pub const codepointToUTF8 = raylib.codepointToUTF8;
    pub const loadUTF8 = raylib.loadUTF8;
    pub const unloadUTF8 = raylib.unloadUTF8;
    pub const loadLines = raylib.loadTextLines;
    pub const unloadLines = raylib.unloadTextLines;
};

pub const Models = struct {
    pub const load = raylib.loadModel;
    pub const loadFromMesh = raylib.loadModelFromMesh;
    pub const unload = raylib.unloadModel;
    pub const getBoundingBox = raylib.getModelBoundingBox;
    pub const draw = raylib.drawModel;
    pub const drawEx = raylib.drawModelEx;
    pub const drawWires = raylib.drawModelWires;
    pub const drawWiresEx = raylib.drawModelWiresEx;
    pub const drawPoints = raylib.drawModelPoints;
    pub const drawPointsEx = raylib.drawModelPointsEx;
    pub const loadAnimations = raylib.loadModelAnimations;
    pub const updateAnimation = raylib.updateModelAnimation;
    pub const updateAnimationBones = raylib.updateModelAnimationBones;
    pub const unloadAnimation = raylib.unloadModelAnimation;
    pub const unloadAnimations = raylib.unloadModelAnimations;
    pub const isAnimationValid = raylib.isModelAnimationValid;
};

pub const Meshes = struct {
    pub const upload = raylib.uploadMesh;
    pub const updateBuffer = raylib.updateMeshBuffer;
    pub const unload = raylib.unloadMesh;
    pub const draw = raylib.drawMesh;
    pub const drawInstanced = raylib.drawMeshInstanced;
    pub const getBoundingBox = raylib.getMeshBoundingBox;
    pub const genTangents = raylib.genMeshTangents;
    pub const exportToFile = raylib.exportMesh;
    pub const exportAsCode = raylib.exportMeshAsCode;
    pub const genPoly = raylib.genMeshPoly;
    pub const genPlane = raylib.genMeshPlane;
    pub const genCube = raylib.genMeshCube;
    pub const genSphere = raylib.genMeshSphere;
    pub const genHemiSphere = raylib.genMeshHemiSphere;
    pub const genCylinder = raylib.genMeshCylinder;
    pub const genCone = raylib.genMeshCone;
    pub const genTorus = raylib.genMeshTorus;
    pub const genKnot = raylib.genMeshKnot;
    pub const genHeightmap = raylib.genMeshHeightmap;
    pub const genCubicmap = raylib.genMeshCubicmap;
};

pub const Materials = struct {
    pub const loadDefault = raylib.loadMaterialDefault;
    pub const load = raylib.loadMaterials;
    pub const unload = raylib.unloadMaterial;
    pub const setTexture = raylib.setMaterialTexture;
    pub const setMeshMaterial = raylib.setModelMeshMaterial;
};

pub const Shaders = struct {
    pub const load = raylib.loadShader;
    pub const loadFromMemory = raylib.loadShaderFromMemory;
    pub const unload = raylib.unloadShader;
    pub const getLocation = raylib.getShaderLocation;
    pub const getLocationAttrib = raylib.getShaderLocationAttrib;
    pub const setValue = raylib.setShaderValue;
    pub const setValueV = raylib.setShaderValueV;
    pub const setValueMatrix = raylib.setShaderValueMatrix;
    pub const setValueTexture = raylib.setShaderValueTexture;
    pub const activate = raylib.beginShaderMode;
    pub const deactivate = raylib.endShaderMode;
};

pub const Fonts = struct {
    pub const getDefault = raylib.getFontDefault;
    pub const load = raylib.loadFont;
    pub const loadEx = raylib.loadFontEx;
    pub const loadFromMemory = raylib.loadFontFromMemory;
    pub const loadFromImage = raylib.loadFontFromImage;
    pub const loadData = raylib.loadFontData;
    pub const unload = raylib.unloadFont;
    pub const unloadData = raylib.unloadFontData;
    pub const exportAsCode = raylib.exportFontAsCode;
    pub const genAtlas = raylib.genImageFontAtlas;
    pub const isReady = raylib.isFontValid;
};

pub const Cameras = struct {
    pub const update = raylib.updateCamera;
    pub const updatePro = raylib.updateCameraPro;
    pub const getMatrix = raylib.getCameraMatrix;
    pub const getMatrix2D = raylib.getCameraMatrix2D;
    pub const getScreenToWorldRay = raylib.getScreenToWorldRay;
    pub const getScreenToWorldRayEx = raylib.getScreenToWorldRayEx;
    pub const getWorldToScreen = raylib.getWorldToScreen;
    pub const getWorldToScreenEx = raylib.getWorldToScreenEx;
    pub const getWorldToScreen2D = raylib.getWorldToScreen2D;
    pub const getScreenToWorld2D = raylib.getScreenToWorld2D;
};

pub const Audio = struct {
    pub const initDevice = raylib.initAudioDevice;
    pub const closeDevice = raylib.closeAudioDevice;
    pub const isDeviceReady = raylib.isAudioDeviceReady;
    pub const setMasterVolume = raylib.setMasterVolume;
    pub const getMasterVolume = raylib.getMasterVolume;
};

pub const Sounds = struct {
    pub const load = raylib.loadSound;
    pub const loadFromWave = raylib.loadSoundFromWave;
    pub const loadAlias = raylib.loadSoundAlias;
    pub const unload = raylib.unloadSound;
    pub const unloadAlias = raylib.unloadSoundAlias;
    pub const play = raylib.playSound;
    pub const stop = raylib.stopSound;
    pub const pause = raylib.pauseSound;
    pub const resumePlaying = raylib.resumeSound;
    pub const isPlaying = raylib.isSoundPlaying;
    pub const setVolume = raylib.setSoundVolume;
    pub const setPitch = raylib.setSoundPitch;
    pub const setPan = raylib.setSoundPan;
};

pub const MusicFunctions = struct {
    pub const load = raylib.loadMusicStream;
    pub const loadFromMemory = raylib.loadMusicStreamFromMemory;
    pub const unload = raylib.unloadMusicStream;
    pub const play = raylib.playMusicStream;
    pub const isPlaying = raylib.isMusicStreamPlaying;
    pub const update = raylib.updateMusicStream;
    pub const stop = raylib.stopMusicStream;
    pub const pause = raylib.pauseMusicStream;
    pub const resumePlaying = raylib.resumeMusicStream;
    pub const seek = raylib.seekMusicStream;
    pub const setVolume = raylib.setMusicVolume;
    pub const setPitch = raylib.setMusicPitch;
    pub const setPan = raylib.setMusicPan;
    pub const getTimeLength = raylib.getMusicTimeLength;
    pub const getTimePlayed = raylib.getMusicTimePlayed;
};

pub const Waves = struct {
    pub const load = raylib.loadWave;
    pub const loadFromMemory = raylib.loadWaveFromMemory;
    pub const unload = raylib.unloadWave;
    pub const exportToFile = raylib.exportWave;
    pub const exportAsCode = raylib.exportWaveAsCode;
    pub const copy = raylib.waveCopy;
    pub const crop = raylib.waveCrop;
    pub const format = raylib.waveFormat;
    pub const loadSamples = raylib.loadWaveSamples;
    pub const unloadSamples = raylib.unloadWaveSamples;
};

pub const AudioStreams = struct {
    pub const load = raylib.loadAudioStream;
    pub const unload = raylib.unloadAudioStream;
    pub const update = raylib.updateAudioStream;
    pub const isProcessed = raylib.isAudioStreamProcessed;
    pub const play = raylib.playAudioStream;
    pub const pause = raylib.pauseAudioStream;
    pub const resumePlaying = raylib.resumeAudioStream;
    pub const isPlaying = raylib.isAudioStreamPlaying;
    pub const stop = raylib.stopAudioStream;
    pub const setVolume = raylib.setAudioStreamVolume;
    pub const setPitch = raylib.setAudioStreamPitch;
    pub const setPan = raylib.setAudioStreamPan;
    pub const setBufferSizeDefault = raylib.setAudioStreamBufferSizeDefault;
    pub const setCallback = raylib.setAudioStreamCallback;
    pub const attachProcessor = raylib.attachAudioStreamProcessor;
    pub const detachProcessor = raylib.detachAudioStreamProcessor;
    pub const attachMixedProcessor = raylib.attachAudioMixedProcessor;
    pub const detachMixedProcessor = raylib.detachAudioMixedProcessor;
};

pub const Input = struct {
    pub const Keyboard = struct {
        pub const isPressed = raylib.isKeyPressed;
        pub const isPressedRepeat = raylib.isKeyPressedRepeat;
        pub const isDown = raylib.isKeyDown;
        pub const isReleased = raylib.isKeyReleased;
        pub const isUp = raylib.isKeyUp;
        pub const getPressed = raylib.getKeyPressed;
        pub const getCharPressed = raylib.getCharPressed;
        pub const getName = raylib.getKeyName;
        pub const setExitKey = raylib.setExitKey;
    };
    pub const Mouse = struct {
        pub const isButtonPressed = raylib.isMouseButtonPressed;
        pub const isButtonDown = raylib.isMouseButtonDown;
        pub const isButtonReleased = raylib.isMouseButtonReleased;
        pub const isButtonUp = raylib.isMouseButtonUp;
        pub const getX = raylib.getMouseX;
        pub const getY = raylib.getMouseY;
        pub const getPosition = raylib.getMousePosition;
        pub const getDelta = raylib.getMouseDelta;
        pub const setPosition = raylib.setMousePosition;
        pub const setOffset = raylib.setMouseOffset;
        pub const setScale = raylib.setMouseScale;
        pub const getWheelMove = raylib.getMouseWheelMove;
        pub const getWheelMoveV = raylib.getMouseWheelMoveV;
        pub const setCursor = raylib.setMouseCursor;
    };
    pub const Gamepad = struct {
        pub const isAvailable = raylib.isGamepadAvailable;
        pub const getName = raylib.getGamepadName;
        pub const isButtonPressed = raylib.isGamepadButtonPressed;
        pub const isButtonDown = raylib.isGamepadButtonDown;
        pub const isButtonReleased = raylib.isGamepadButtonReleased;
        pub const isButtonUp = raylib.isGamepadButtonUp;
        pub const getButtonPressed = raylib.getGamepadButtonPressed;
        pub const getAxisCount = raylib.getGamepadAxisCount;
        pub const getAxisMovement = raylib.getGamepadAxisMovement;
        pub const setMappings = raylib.setGamepadMappings;
        pub const setVibration = raylib.setGamepadVibration;
    };
    pub const Touch = struct {
        pub const getX = raylib.getTouchX;
        pub const getY = raylib.getTouchY;
        pub const getPosition = raylib.getTouchPosition;
        pub const getPointId = raylib.getTouchPointId;
        pub const getPointCount = raylib.getTouchPointCount;
    };
    pub const Gestures = struct {
        pub const setEnabled = raylib.setGesturesEnabled;
        pub const isDetected = raylib.isGestureDetected;
        pub const getDetected = raylib.getGestureDetected;
        pub const getHoldDuration = raylib.getGestureHoldDuration;
        pub const getDragVector = raylib.getGestureDragVector;
        pub const getDragAngle = raylib.getGestureDragAngle;
        pub const getPinchVector = raylib.getGesturePinchVector;
        pub const getPinchAngle = raylib.getGesturePinchAngle;
    };
};

pub const Collision = struct {
    pub const checkRecs = raylib.checkCollisionRecs;
    pub const checkCircles = raylib.checkCollisionCircles;
    pub const checkCircleRec = raylib.checkCollisionCircleRec;
    pub const checkCircleLine = raylib.checkCollisionCircleLine;
    pub const checkPointRec = raylib.checkCollisionPointRec;
    pub const checkPointCircle = raylib.checkCollisionPointCircle;
    pub const checkPointTriangle = raylib.checkCollisionPointTriangle;
    pub const checkPointLine = raylib.checkCollisionPointLine;
    pub const checkPointPoly = raylib.checkCollisionPointPoly;
    pub const checkLines = raylib.checkCollisionLines;
    pub const getRec = raylib.getCollisionRec;
    pub const checkSpheres = raylib.checkCollisionSpheres;
    pub const checkBoxes = raylib.checkCollisionBoxes;
    pub const checkBoxSphere = raylib.checkCollisionBoxSphere;
    pub const getRaySphere = raylib.getRayCollisionSphere;
    pub const getRayBox = raylib.getRayCollisionBox;
    pub const getRayMesh = raylib.getRayCollisionMesh;
    pub const getRayTriangle = raylib.getRayCollisionTriangle;
    pub const getRayQuad = raylib.getRayCollisionQuad;
};

pub const Math = raylib.math;

pub const File = struct {
    pub const loadData = raylib.loadFileData;
    pub const unloadData = raylib.unloadFileData;
    pub const loadText = raylib.loadFileText;
    pub const unloadText = raylib.unloadFileText;
    pub const saveText = raylib.saveFileText;
    pub const saveData = raylib.saveFileData;
    pub const exists = raylib.fileExists;
    pub const directoryExists = raylib.directoryExists;
    pub const isExtension = raylib.isFileExtension;
    pub const getLength = raylib.getFileLength;
    pub const getModTime = raylib.getFileModTime;
    pub const getExtension = raylib.getFileExtension;
    pub const getFileName = raylib.getFileName;
    pub const getFileNameWithoutExt = raylib.getFileNameWithoutExt;
    pub const getDirectoryPath = raylib.getDirectoryPath;
    pub const getPrevDirectoryPath = raylib.getPrevDirectoryPath;
    pub const getWorkingDirectory = raylib.getWorkingDirectory;
    pub const getApplicationDirectory = raylib.getApplicationDirectory;
    pub const makeDirectory = raylib.makeDirectory;
    pub const changeDirectory = raylib.changeDirectory;
    pub const isPathFile = raylib.isPathFile;
    pub const isFileNameValid = raylib.isFileNameValid;
    pub const loadDirectoryFiles = raylib.loadDirectoryFiles;
    pub const loadDirectoryFilesEx = raylib.loadDirectoryFilesEx;
    pub const unloadDirectoryFiles = raylib.unloadDirectoryFiles;
    pub const isDropped = raylib.isFileDropped;
    pub const loadDroppedFiles = raylib.loadDroppedFiles;
    pub const unloadDroppedFiles = raylib.unloadDroppedFiles;
    pub const rename = raylib.fileRename;
    pub const remove = raylib.fileRemove;
    pub const copy = raylib.fileCopy;
    pub const move = raylib.fileMove;
    pub const textReplace = raylib.fileTextReplace;
    pub const textFindIndex = raylib.fileTextFindIndex;
    pub const exportDataAsCode = raylib.exportDataAsCode;
};

pub const System = struct {
    pub const setConfigFlags = raylib.setConfigFlags;
    pub const setTraceLogLevel = raylib.setTraceLogLevel;
    pub const traceLog = raylib.traceLog;
    pub const setTargetFPS = raylib.setTargetFPS;
    pub const getFrameTime = raylib.getFrameTime;
    pub const getTime = raylib.getTime;
    pub const getFPS = raylib.getFPS;
    pub const swapScreenBuffer = raylib.swapScreenBuffer;
    pub const pollInputEvents = raylib.pollInputEvents;
    pub const waitTime = raylib.waitTime;
    pub const setRandomSeed = raylib.setRandomSeed;
    pub const getRandomValue = raylib.getRandomValue;
    pub const loadRandomSequence = raylib.loadRandomSequence;
    pub const unloadRandomSequence = raylib.unloadRandomSequence;
    pub const takeScreenshot = raylib.takeScreenshot;
    pub const openURL = raylib.openURL;
    pub const setClipboardText = raylib.setClipboardText;
    pub const getClipboardText = raylib.getClipboardText;
    pub const getClipboardImage = raylib.getClipboardImage;
    pub const enableEventWaiting = raylib.enableEventWaiting;
    pub const disableEventWaiting = raylib.disableEventWaiting;
    pub const compressData = raylib.compressData;
    pub const decompressData = raylib.decompressData;
    pub const encodeDataBase64 = raylib.encodeDataBase64;
    pub const decodeDataBase64 = raylib.decodeDataBase64;
    pub const computeCRC32 = raylib.computeCRC32;
    pub const computeMD5 = raylib.computeMD5;
    pub const computeSHA1 = raylib.computeSHA1;
};

pub const VR = struct {
    pub const loadStereoConfig = raylib.loadVrStereoConfig;
    pub const unloadStereoConfig = raylib.unloadVrStereoConfig;
};

pub const Automation = struct {
    pub const loadEventList = raylib.loadAutomationEventList;
    pub const unloadEventList = raylib.unloadAutomationEventList;
    pub const exportEventList = raylib.exportAutomationEventList;
    pub const setEventList = raylib.setAutomationEventList;
    pub const setBaseFrame = raylib.setAutomationEventBaseFrame;
    pub const startRecording = raylib.startAutomationEventRecording;
    pub const stopRecording = raylib.stopAutomationEventRecording;
    pub const playEvent = raylib.playAutomationEvent;
};

// Note: GLFW support is not currently implemented
// The engine focuses on raylib for comprehensive game development features

// Direct re-exports for convenience (use these if you prefer the original raylib API)
pub const rl = raylib;
