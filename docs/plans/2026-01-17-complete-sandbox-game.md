# Nyon Game Sandbox Completion Plan

## Overview

Complete the Nyon Game sandbox application with four areas: GPU improvements, Entity/Combat, Crafting, and Polish.

**Approach:** Systematic completion - GPU → Entity/Combat → Crafting → Polish

---

## Area 1: GPU Improvements (Light Touch)

Skip full Vulkan compute pipeline (40-60 hour undertaking). Instead:

### Task 1.1: Fix GPU TODOs
- [ ] `gpu.zig:467` - Change `checkOpenCLSupport()` to return `false` with proper comment (not planned)
- [ ] `gpu.zig:490` - Change `checkAmdSupport()` to return `false` with proper comment (not planned)
- [ ] Add clear documentation that GPU compute is software-fallback only for now

### Task 1.2: Improve Software Fallback Logging
- [ ] Add startup log message clearly stating "GPU: Software rendering (hardware acceleration not implemented)"
- [ ] Remove misleading "Vulkan compute dispatch not fully implemented" warnings during runtime

**Verification:** Run game, verify clean startup logs without confusing warnings

---

## Area 2: Entity/Combat System

### Task 2.1: Entity Raycasting
Create `src/entity/raycast.zig`:
- [ ] `raycastEntities(world, origin, direction, max_distance)` function
- [ ] Ray-vs-AABB intersection test for each entity with Collider
- [ ] Return closest hit: `{ entity, distance, hit_point }`
- [ ] Export from `src/entity/entity.zig`

### Task 2.2: Player Attack Input
Modify `src/game/sandbox.zig`:
- [ ] Add `attack_cooldown: f32` field to SandboxGame
- [ ] On left-click (when not targeting block or inventory closed):
  - Check attack cooldown <= 0
  - Raycast entities within 4 blocks
  - If hit: call `damageEntity()` with 5 damage
  - Set cooldown to 0.5 seconds
- [ ] Decrement cooldown each frame

### Task 2.3: Combat Visual Feedback
- [ ] Spawn hit particles when entity damaged (use existing particle system)
- [ ] Entity flash red when hit (modify render color briefly)
- [ ] Crosshair color change when aiming at entity

### Task 2.4: Entity-World Collision
Modify `src/entity/systems.zig`:
- [ ] Add `worldCollisionSystem()` that checks entity positions against blocks
- [ ] Prevent entities from falling through ground
- [ ] Call from `updateAllSystems()`

**Verification:** 
- Run game, find a mob, left-click to attack
- Verify damage numbers in debug, mob health decreases
- Verify mob dies after enough hits
- Verify mobs don't fall through ground

---

## Area 3: Crafting System

### Task 3.1: Add Missing Tool Recipes
In `src/game/crafting.zig`:
- [ ] Add hoe recipes for all 5 materials (wood, stone, iron, gold, diamond)
- [ ] Verify all pickaxe/axe/shovel/sword recipes exist for all materials

### Task 3.2: Add Armor Recipes
- [ ] Leather armor set (helmet, chestplate, leggings, boots) - 4 recipes
- [ ] Iron armor set - 4 recipes  
- [ ] Gold armor set - 4 recipes
- [ ] Diamond armor set - 4 recipes
- [ ] Add armor item definitions in `items.zig` if missing

### Task 3.3: Add Essential Recipes
- [ ] Torch (coal + stick = 4 torches)
- [ ] Ladder (7 sticks = 3 ladders)
- [ ] Fence (4 planks + 2 sticks = 3 fences)
- [ ] Door (6 planks = 3 doors)
- [ ] Chest (8 planks = 1 chest)
- [ ] Bed (3 wool + 3 planks = 1 bed)

### Task 3.4: Crafting Table Block (3x3 Crafting)
- [ ] Add `crafting_table` to Block enum in `world.zig` or `sandbox.zig`
- [ ] Fix crafting table recipe to output crafting_table block (currently outputs planks)
- [ ] Add crafting table texture/color
- [ ] When player right-clicks crafting table: open 3x3 crafting UI
- [ ] Extend `inventory_ui.zig` to support 3x3 mode
- [ ] Update `crafting.zig` pattern matching for 3x3 recipes

**Verification:**
- Craft a crafting table from 4 planks
- Place crafting table in world
- Right-click to open 3x3 grid
- Craft iron pickaxe (requires 3x3)

---

## Area 4: Polish & Bug Fixes

### Task 4.1: Critical Bug - Save Timestamp (P0)
In `src/game/save.zig`:
- [ ] Line 390: Preserve original `created_timestamp` when loading
- [ ] Only set to `now` on first creation
- [ ] Add `original_created_timestamp` field or parameter

### Task 4.2: Memory Leak - Mob Spawn Counts (P1)
In `src/entity/spawning.zig`:
- [ ] Line 193: When decrementing count to 0, remove entry from hash map
- [ ] Add cleanup in `deinit()` to clear the map

### Task 4.3: Error Handling Improvements (P1)
Add logging to critical `catch {}` blocks:
- [ ] `chunk_manager.zig` - log chunk load/unload failures
- [ ] `spawning.zig` - log spawn failures
- [ ] Keep silent for non-critical operations

### Task 4.4: Crafting Bounds Check (P1)
In `src/game/crafting.zig`:
- [ ] Lines 146, 158: Add bounds check for item IDs >= 600
- [ ] Or increase array size to 1000
- [ ] Or convert to HashMap for dynamic sizing

### Task 4.5: User Feedback
- [ ] Add simple text feedback when block placement fails (inventory empty, can't place there)
- [ ] Add feedback when attack misses or hits

**Verification:**
- Save world, check timestamp preserved on reload
- Play for extended time, verify no memory growth from mob spawns
- Check logs for any silent errors now being logged

---

## Implementation Order

1. **Area 4.1** - Save timestamp fix (quick win, critical bug)
2. **Area 2.1-2.2** - Entity raycast + player attack (core combat)
3. **Area 2.3** - Combat visual feedback
4. **Area 2.4** - Entity-world collision
5. **Area 3.1-3.2** - Missing recipes (tools + armor)
6. **Area 3.3** - Essential recipes
7. **Area 3.4** - Crafting table block
8. **Area 4.2-4.5** - Remaining polish
9. **Area 1** - GPU cleanup (last, lowest priority)

---

## Files to Modify

| File | Changes |
|------|---------|
| `src/game/save.zig` | Fix timestamp preservation |
| `src/entity/raycast.zig` | NEW - entity raycasting |
| `src/entity/entity.zig` | Export raycast module |
| `src/game/sandbox.zig` | Add attack input, attack cooldown |
| `src/entity/systems.zig` | Add world collision system |
| `src/game/crafting.zig` | Add recipes, bounds checking |
| `src/game/items.zig` | Add armor items if missing |
| `src/game/world.zig` | Add crafting_table block type |
| `src/ui/inventory_ui.zig` | Support 3x3 crafting mode |
| `src/entity/spawning.zig` | Fix memory leak |
| `src/world/chunk_manager.zig` | Add error logging |
| `src/gpu/gpu.zig` | Clean up TODOs, improve logging |

---

## Success Criteria

- [ ] Player can attack and kill mobs with left-click
- [ ] Mobs don't fall through terrain
- [ ] All tool tiers craftable (wood through diamond)
- [ ] All armor sets craftable
- [ ] Crafting table enables 3x3 recipes
- [ ] Save/load preserves world creation timestamp
- [ ] No memory leaks during extended play
- [ ] Clean startup logs without confusing warnings
