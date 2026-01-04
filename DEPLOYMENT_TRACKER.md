# Deployment Tracker - Usage Guide

## Overview

The `deployment_tracker.ps1` PowerShell script helps track implementation progress for the performance optimization enhancements outlined in `DEPLOYMENT.md`.

## Usage

### Basic Commands

```powershell
# Show full status of all phases
.\deployment_tracker.ps1

# Show Phase 1 status only
.\deployment_tracker.ps1 -Phase1

# Show Phase 2 status only
.\deployment_tracker.ps1 -Phase2

# Show Phase 3 status only
.\deployment_tracker.ps1 -Phase3

# Check build and test status
.\deployment_tracker.ps1 -Check

# Full status report (phases + build check)
.\deployment_tracker.ps1 -Status
```

## Phase 1 - Near Term Items

1. **MemoryPool for entity IDs** - High-churn allocation optimization
   - File: `src/ecs/entity.zig`
   - Status: PENDING
   - Implementation: Replace `std.ArrayList` and `std.AutoHashMap` with a memory pool for entity ID recycling

2. **ArrayHashMap for archetype queries** - Stable iteration
   - File: `src/ecs/world.zig`
   - Status: PENDING
   - Implementation: Replace `std.AutoHashMap` with `std.ArrayHashMap` for `archetype_lookup` to enable stable iteration

3. **Profiling integration** - Measure actual gains
   - File: `src/performance.zig`
   - Status: PENDING
   - Implementation: Add performance measurement hooks to track optimization impact

## Phase 2 - Medium Term Items

1. **Parallel ECS query execution** - Job system
2. **GPU-driven rendering** - Compute shaders
3. **Texture streaming** - Large world support

## Phase 3 - Long Term Items

1. **Custom allocators** - Subsystem-specific
2. **Hot-reloading shaders** - Runtime shader updates
3. **Memory tracking tools** - Profiling infrastructure

## Implementation Notes

### Phase 1.1: MemoryPool for Entity IDs

Current implementation uses:

- `std.ArrayList(Entity)` for free_ids
- `std.AutoHashMap(Entity, EntityGeneration)` for generations

Proposed optimization:

- Use a specialized `MemoryPool` or enhance `ObjectPool` in `src/common/memory.zig`
- Pre-allocate entity ID blocks
- Reduce allocation overhead in high-churn scenarios

### Phase 1.2: ArrayHashMap for Archetype Queries

Current implementation:

```zig
archetype_lookup: std.AutoHashMap(u64, *archetype.Archetype)
```

Proposed change:

```zig
archetype_lookup: std.ArrayHashMap(u64, *archetype.Archetype, ...)
```

Benefits:

- Stable iteration order
- Better cache locality when iterating
- Predictable performance characteristics

### Phase 1.3: Profiling Integration

Add to `src/performance.zig`:

- Frame time measurement
- Allocation tracking
- Query execution time
- Component access patterns

## Running the Tracker

The script automatically:

1. Scans source files for implementation patterns
2. Checks build status
3. Reports progress percentages
4. Provides color-coded status output

## Next Steps

1. Review Phase 1 items and prioritize
2. Implement MemoryPool for entity IDs
3. Migrate to ArrayHashMap for archetype lookups
4. Add profiling hooks to measure improvements
5. Run tracker regularly to monitor progress
