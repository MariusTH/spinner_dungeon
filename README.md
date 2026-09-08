# SSC — Spin Spin Carnage

**SSC** is short for **Spin Spin Carnage** — a chunky-cartoon, physics-based
spinning-action dungeon crawler built with Flutter + Flame. Drag circles on the
screen to charge your spinner, fling it into a procedurally generated dungeon,
and smash everything that moves.

> Throughout the codebase the short name `ssc` is used for the Dart package,
> the iOS bundle id (`no.mariushorne.ssc`), and the Android application id
> (`no.mariushorne.ssc`). The display name ("Spin Spin Carnage") is set on
> each platform via `CFBundleDisplayName` / `android:label`.

## Development

```bash
flutter pub get
flutter run
```

After pulling changes that touch `pubspec.yaml` splash/icon config, regenerate
the native splash assets:

```bash
dart run flutter_native_splash:create
```

## Dungeon Generator Tool

`SpinnerGame` and this CLI both use the same `DungeonLevelGenerator` logic.

Generate a dungeon layout JSON from parameters:

```bash
dart run tool/generate_dungeon.dart --level 5 --seed 1337
```

Useful flags:

```bash
--width <int> --height <int> --target-rooms <int>
--no-monsters
--no-items
--verbose
--render-image
--output-image <path>
--image-scale <int>
```

`--verbose` prints generation process details and then the final JSON.
`--render-image` saves a PNG preview to `output/dungeons/level<level>_seed<seed>.png`.

Example:

```bash
dart run tool/generate_dungeon.dart --level 6 --seed 1337 --verbose --render-image
```

## Seed Workflow

1. In-game: open `Build Spinner`, set a `Run Seed`, and start the run.
2. During a run: use the HUD `Seed` copy button.
3. In CLI: paste the same seed with `--seed <value>` to inspect generation.

## Versioning

`pubspec.yaml` uses `version: x.y.z+build`.

Bump with:

```bash
./tool/bump_version.sh --build   # build only
./tool/bump_version.sh --patch   # patch + build
./tool/bump_version.sh --minor   # minor + build
./tool/bump_version.sh --major   # major + build
```

## iOS / TestFlight

1. Ensure `Runner` bundle id (`no.mariushorne.ssc`) and signing are correct in Xcode.
2. Replace app icons in `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
3. Bump version/build (`./tool/bump_version.sh --build`).
4. Build archive:

```bash
flutter build ipa --release
```

5. Upload in Xcode Organizer (`Window` → `Organizer` → `Distribute App`) or Transporter.
6. Complete App Store Connect metadata (privacy, age rating, export compliance, test notes).

## Enemies (shapes & colors)

Procedural enemies use **body color** for family, **size** (collision radius) for weight class, and small **shape markers** (triangle, square, circle, hexagon) for type + archetype. Full tables and behaviors: [`docs/enemies.md`](docs/enemies.md) (kept in sync with `lib/game/enemy_taxonomy.dart` and `enemy_component.dart`).

## Project Layout

```
lib/
  main.dart              # SscApp bootstrap + lifecycle snapshotting
  game/                  # Flame world, enemies, spinner, dungeon gen
  input/                 # Spin gesture detector
  systems/               # Combat, physics, progression, run snapshot
  ui/                    # Overlays: start flow, HUD, workbench, upgrade menu
assets/
  images/
    dungeon/             # Tilesets + theme JSON
    enemies/             # (legacy) pixel sprite cache, no longer loaded
    powerups/            # (legacy) pixel sprite cache, no longer loaded
    props/               # Chests, coins, doors
    ui/                  # Title logo + splash art
test/                    # Unit tests per subsystem
tool/                    # CLI utilities (dungeon gen, version bump, etc.)
```
