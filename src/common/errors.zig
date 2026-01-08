const std = @import("std");

pub const AssetError = error{
    NotFound,
    InvalidFormat,
    LoadFailed,
    OutOfMemory,
};

pub const RenderError = error{
    ShaderCompilationFailed,
    PipelineCreationFailed,
    TextureLoadFailed,
    MeshLoadFailed,
    OutOfMemory,
};

pub const PhysicsError = error{
    CollisionShapeInvalid,
    RigidBodyCreationFailed,
    SimulationStepFailed,
    OutOfMemory,
};

pub const AudioError = error{
    FormatNotSupported,
    DecodeFailed,
    PlaybackFailed,
    OutOfMemory,
};

pub const EngineError = error{
    InitializationFailed,
    BackendNotAvailable,
    WindowCreationFailed,
    OutOfMemory,
};

pub const SerializationError = error{
    InvalidData,
    VersionMismatch,
    ParseError,
    WriteError,
    OutOfMemory,
};

pub const NodeGraphError = error{
    CycleDetected,
    EvaluationFailed,
    InvalidConnection,
    OutOfMemory,
};

pub const InputError = error{
    DeviceNotFound,
    MappingFailed,
    OutOfMemory,
};

pub const CommonError = error{
    InvalidArgument,
    OutOfMemory,
    OperationFailed,
};

pub fn combineErrorSets(comptime errors: []const type) type {
    comptime var result = @typeInfo(error{}).ErrorSet orelse error{};
    for (errors) |err_type| {
        const err_set = @typeInfo(err_type).ErrorSet orelse error{};
        inline for (@typeInfo(err_set).ErrorSet.?) |_| {
            result = result || err_set;
        }
    }
    return result;
}

pub const AnyError = combineErrorSets(&[_]type{
    AssetError,
    RenderError,
    PhysicsError,
    AudioError,
    EngineError,
    SerializationError,
    NodeGraphError,
    InputError,
    CommonError,
});

pub fn unwrap(comptime T: type, result: anyerror!T) T {
    return result catch |err| {
        std.log.err("Unexpected error: {}", .{err});
        @panic(@errorName(err));
    };
}

pub fn unwrapOr(comptime T: type, result: anyerror!T, default: T) T {
    return result catch |err| {
        std.log.warn("Error: {}, using default", .{err});
        return default;
    };
}

pub fn unwrapOrNull(comptime T: type, result: anyerror!?T) ?T {
    return result catch |err| {
        std.log.warn("Error: {}, returning null", .{err});
        return null;
    };
}
