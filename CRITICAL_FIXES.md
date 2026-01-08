# Critical Fixes - Implementation Plan

## Status: In Progress

This document tracks the systematic fixing of critical issues identified in the codebase review.

## ✅ Already Fixed/Correct

- **Physics typos**: Code is actually correct - `potential_pairs`, `force_accumulator`, `torque_accumulator`, `baumgarte_factor` are all correct
- **Arena allocators**: Already used in `sandbox.zig` line 269 for JSON parsing
- **Constants**: Most magic numbers already in `config/constants.zig`
- **Font manager memory**: Correctly handles allocation/deallocation

## 🔴 Critical Issues to Fix

### 1. Unsafe Casts (HIGH PRIORITY)

- [ ] `src/ui/ui.zig:116` - Add bounds checking for text width conversion
- [ ] `src/game/sandbox.zig:251-252` - Use Cast.toInt() for color index
- [ ] `src/application.zig:100-101` - Use Cast.toFloat() for window size
- [ ] `src/physics/world.zig:209` - Add bounds checking for substep calculation

### 2. Memory Management (MEDIUM PRIORITY)

- [ ] `src/std_ext/assets.zig:52` - Document ownership contract for load() return value
- [ ] `src/ui/game_ui.zig:137,226` - Add overflow protection for timestamp casting

### 3. Performance Issues (HIGH PRIORITY)

- [ ] `src/game/sandbox.zig:364-407` - Replace O(n) linear search with spatial partitioning
- [ ] `src/physics/world.zig:41-48` - Already has spatial hash, but verify it's being used
- [ ] `src/ecs/world.zig:26-27` - Change initCapacity(0) to reasonable defaults

### 4. Code Quality (MEDIUM PRIORITY)

- [ ] `src/ui/sandbox_ui.zig` and `game_ui.zig` - Extract common code to shared module
- [ ] `src/game/sandbox.zig:410-491` - Remove duplicate vector math, use physics/types.zig

### 5. Error Handling (MEDIUM PRIORITY)

- [ ] `src/ui/ui.zig:263,268` - Add error logging instead of silent catch {}
- [ ] `src/font_manager.zig:52` - Document why continue is acceptable

## Implementation Order

1. **Phase 1**: Fix unsafe casts (prevents crashes)
2. **Phase 2**: Fix performance bottlenecks (O(n²) -> O(n log n))
3. **Phase 3**: Code quality improvements (duplication, documentation)
4. **Phase 4**: Error handling improvements

## Notes

- Many issues in the original report were false positives
- Codebase already follows many best practices
- Focus on actual bugs and performance issues
