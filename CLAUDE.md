# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**SSC — Spin Spin Carnage** is a top-down, physics-based spinning-action dungeon
crawler built with **Flutter + Flame**. The player drags to charge a spinner,
flings it into a procedurally generated dungeon, and smashes everything. Ships as
a single mobile app. Dart package name and bundle/app id are `ssc` /
`no.mariushorne.ssc`; the display name "Spin Spin Carnage" is set per-platform.

## Commands

```bash
flutter pub get                 # install deps
flutter run                     # run on a connected device/simulator
flutter analyze --no-fatal-infos   # lint (matches CI)
flutter test                    # run all tests
flutter test test/systems/upgrade_system_test.dart           # single file
flutter test --name "substring of test description"          # single test by name
```

Install on a physical phone without TestFlight (auto-picks the first
cable/wireless device; runs analyze + test first):

```bash
./tool/deploy_phone.sh               # release build, installs and detaches
./tool/deploy_phone.sh --debug       # stays attached for hot reload
./tool/deploy_phone.sh -d <id> --skip-checks
```

Regenerate native splash after editing the `flutter_native_splash` block in
`pubspec.yaml`:

```bash
dart run flutter_native_splash:create
```

Versioning (`pubspec.yaml` uses `version: x.y.z+build`):

```bash
./tool/bump_version.sh --build   # or --patch / --minor / --major (each also bumps build)
```

CI (`.github/workflows/testflight.yml`) runs `flutter analyze --no-fatal-infos`
then `flutter test` on push to `master`, then builds and uploads an iOS IPA to
TestFlight. Keep both green; the build number is set from the CI run number, not
`pubspec.yaml`.

## Architecture

The game is one `FlameGame` subclass with a Flutter overlay layer for menus/HUD.

- **`lib/main.dart`** — `SscApp` bootstraps a single `SpinnerGame` inside a
  `GameWidget`. Registers three Flutter overlays by id (`hud`, `start_flow`,
  `upgrade_menu`). A `WidgetsBindingObserver` calls
  `game.persistRunSnapshotNow()` on inactive/paused/detached so a run survives
  backgrounding.

- **`lib/game/spinner_game.dart`** — the core (~6.6k lines). `SpinnerGame extends
  FlameGame with HasCollisionDetection, MultiTouchTapDetector, ScaleDetector,
  DoubleTapDetector`. It owns world geometry, all entity lists (walls, enemies,
  coins, powerups, shots, chests, …), camera, input/gesture handling, the run
  lifecycle, and persistence wiring. Key state:
  - `enum RunPhase { startMenu, loadout, playing, runOver, upgrading }` drives
    which overlays show; `bool get show…` getters expose phase to the UI.
  - The campaign is `DungeonLevelGenerator.campaignFloorCount` (5) floors;
    the Warden boss spawns on the last one, and clearing it ends the run with
    `RunEndReason.victory` (HUD shows the VICTORY card).
  - `enum SpinnerGameMode { dungeon, invasion }` — two run types (procedural
    dungeon crawl vs. a space-invaders-style defense). `enum RunEndReason`
    records why a run ended.
  - When touching this file, look for the relevant `_` field/getter block near
    the top and the matching `void _start…` / `_spawn…` / overlay-toggling
    method rather than reading top-to-bottom. Private helper classes
    (`_LevelPlan`, `_RoomPlan`, `_GridPos`, `_ThemeSprites`, …) live at the
    bottom of the same file.

- **Room props** — `SpinnerGame._spawnRoomProps` seeds per room: pinball
  bumper sets (light all → jackpot chest), breakable `PillarComponent`s and
  explosive `BarrelComponent`s (`dungeon_prop_components.dart`, both subclass
  `BumperComponent`). Explosions go through `SpinnerGame.triggerExplosion`.

- **`lib/game/` components** — Flame components for each entity
  (`spinner_component`, `enemy_component`, `coin_pickup_component`,
  `powerup_component`, `chest_component`, `wall_component`, `bumper_component`,
  `trap_component`, `pit_component`, projectiles, combat FX, tether link).
  Spinner motion physics is split into `spinner_top_physics.dart` /
  `physics.dart`. Creatures are drawn procedurally via `creature_body.dart` +
  `enemy_taxonomy.dart` (see Art rules below) — sprites in `assets/images/enemies`
  and `assets/images/powerups` are **legacy and no longer loaded**.

- **Dungeon generation** — `dungeon_level_generator.dart` produces a room graph;
  `spinner_game._generateLevel` lays it out in world space and builds geometry,
  **then** `_spawnLevelContent` spawns enemies/chests/pickups (always after
  geometry so combatants see final walls). The **same** `DungeonLevelGenerator`
  is used by the CLI tool, so a seed reproduces identically in-game and offline.
  `dungeon_preview_renderer.dart` rasterizes a layout to PNG.

- **Terrain rendering** — floors and walls are drawn procedurally as one vector
  `ui.Picture` per level by `rendering/dungeon_terrain.dart` (hand-drawn
  flagstones, chunky outlined wall tops, per-`DungeonTheme` `TerrainPalette`
  mixed from `agent.md` hexes). No tile textures are used in-game; the Wang
  sheets in `assets/images/dungeon/` are only used by tooling. Props (chest,
  pit, spike trap) are likewise vector-drawn top-down in
  `rendering/prop_painters.dart`; no prop PNGs are shipped.
- **Room templates** — `room_template*.dart`, `tile_semantics.dart`, and the
  `ldtk/` bridge load **semantic tile grids** (biome-agnostic IDs) that are
  stretched over a room to spawn interior walls/pits/hazards. Cells near a
  doorway are skipped. Assignment is gated by `kCombatRoomTemplatesEnabled`
  (off: the only bundled template, `band_arena`, walled off doorways). See
  `docs/ldtk.md` for authoring rooms.

- **`lib/systems/`** — pure-ish logic, decoupled from Flame:
  - `upgrade_system.dart` — `MetaProgress`, upgrade/ability enums, leaderboard.
  - `spinner_parts.dart` — part definitions (core/ring/blade/glow), `BladeShape`,
    and the combat/visual stat contract for blades.
  - `progression_repository.dart` / `run_snapshot_repository.dart` — persistence
    behind abstract interfaces with `SharedPreferences` implementations
    (`MetaProgress` under `ssc_meta_progress_v1`, in-progress run under
    `ssc_run_snapshot_v1`). Inject fakes in tests.
  - `combat_system.dart`, `collision_system.dart` — small combat/collision helpers.
  - `trick_shot_system.dart` — per-fling bank-shot / multi-kill rules,
    the cross-fling `ComboTracker` (drains only while the spinner rests) and
    `FloorPace` speed bonus vs par; unit-tested.

- **`lib/ui/`** — Flutter (not Flame) overlays: `start_flow_overlay.dart` (start
  menu → loadout), `hud.dart`, `upgrade_menu.dart`, `hall_of_spinners_screen.dart`,
  and `workbench/` (the diegetic drag-and-drop spinner builder). The HUD reacts to
  `game.hudTick` (a `ValueNotifier<int>` bumped by the game loop).

- **`lib/input/spin_gesture_detector.dart`** — translates drag gestures into spin
  charge; unit-tested in isolation.

## Tests

Tests live in `test/` mirroring `lib/` (`test/systems`, `test/game`, `test/input`).
They cover the deterministic, decoupled pieces — generator, repositories, upgrade
system, gesture detector — not the full Flame render loop. New logic should go in a
testable `systems/` or pure helper so it can be tested without booting the game.

## Tooling (`tool/`)

`generate_dungeon.dart` produces a layout JSON (and optional PNG) from
`--level`/`--seed` using the in-game generator — the primary way to inspect/repro a
seed (`--verbose`, `--render-image`, `--width/--height/--target-rooms`,
`--no-monsters`, `--no-items`). The in-game HUD `Seed` copy button gives a seed to
paste here. Other scripts inspect/export tilesheets and dungeon previews.

## Art & visual direction (load-bearing)

This project has a strict art bible in **`agent.md`** (full) and **`.cursorrules`**
(condensed) — read `agent.md` before any visual/asset change. Non-negotiables:

- Aesthetic is "Soft-Vector Chunky Cartoon"; `assets/images/ui/logo.png` is the
  north star ("does it belong in the logo?" test).
- Use only the palette hexes in `agent.md` (no eyeballed colours).
- Dynamic entities wear thick dark outlines; walls use a darkened base-texture
  colour, not pure black.
- Creatures are "thumb silhouettes" with **8-directional facing**: compute
  `facingAngle` with `atan2`, snap to 45°, and **draw features per direction — do
  not rotate the sprite**. Hedgehog (`enemy_component`/`creature_body`) is the
  reference implementation; danger arcs must be clearly bounded.
- Enemy visual language = body **color** (family) + **size** (weight) + **shape
  markers** (type/archetype). Keep `enemy_taxonomy.dart`, `enemy_component.dart`,
  and `docs/enemies.md` in sync when changing it.
- Keep the central/lower screen clear (thumb zone); HUD info is diegetic (rings on
  the spinner, ember trajectory arrows).
