# LDtk authoring

Shipped combats can use **semantic tile grids** shared across all biomes. IDs are defined in [`lib/game/tile_semantics.dart`](../lib/game/tile_semantics.dart). Per-theme **art** for the same ID lives in `assets/images/dungeon/semantic_theme_*.json` (sprite index 0–15 in the 4×4 Wang sheet).

## Layers (LDtk)

| Layer name   | Type    | Values |
|-------------|---------|--------|
| `Semantics` | IntGrid | Same integers as `TileSemantics` (`0` floor, `1` north band, …). |
| `Hurt`      | IntGrid | Optional: `0` none, `1` light, `2` heavy (overrides hazard bits on `Semantics` when set). |
| Entities    | —       | Optional: point/rect rows in [RoomTemplate] JSON — `kind` + `fields` (see below). |

World **grid size** in LDtk should match the template you expect (e.g. 8×3 for `band_arena`). The game **scales** that grid to the room’s world rectangle.

### Entity `kind` values

- **`enemy`**, **`item`**: data for placement or loot (consumed when you wire template entities into the spawn pipeline).
- **`socket`**: **not** a spawn point — marks where on an **enemy visual** to attach add-ons (shields, plates, etc.). Use custom `fields` (e.g. `slot`, `facing`, `offset`) for your art rig; the combat spawn system stays separate.

## Runtime order (run loop)

1. The procedural graph is generated ([`DungeonLevelGenerator`](../lib/game/dungeon_level_generator.dart) → [`_generateLevel`](../lib/game/spinner_game.dart)).
2. The level is **laid out** in world space and **geometry** is built (perimeter, corridors, semantic template overlays, interior walls, hazards).
3. **After** that, [`_spawnLevelContent`](../lib/game/spinner_game.dart) spawns enemies, traps, chests, and pickups from each room’s counts — so combatants always see the final arena.

Template entities in JSON are not yet applied in step 3; when they are, spawns should still run **after** step 2 so positions respect walls and room bounds.

## Runtime data

1. **Checked-in JSON (recommended for builds):** `assets/levels/room_templates/<id>.json` — see [`band_arena.json`](../assets/levels/room_templates/band_arena.json).
2. **`.ldtk` file:** use [`roomTemplateFromLdtkProjectString`](../lib/game/ldtk/ldtk_semantics_io.dart) to extract a [RoomTemplate], or the **full** pipeline via [`flame_ldtk`](../lib/game/ldtk/flame_ldtk_bridge.dart) (`LdtkWorld`, `LdtkLevelComponent`).

## Generator

Combat rooms on **level 2+** receive [`kDefaultCombatRoomTemplateId`](../lib/game/dungeon_level_generator.dart) (`band_arena`) with a random 90° rotation and optional flips, unless you change the generator.

## Base64 / export

From a terminal, copy a template for a GitHub secret (not required for local JSON assets):

```sh
base64 -i path/to/room.json | pbcopy
```

For LDtk, export the project JSON into `assets/` and add the path to your asset bundle, or pre-convert to `room_template` JSON in CI.
