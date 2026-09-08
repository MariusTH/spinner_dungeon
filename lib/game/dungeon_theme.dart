/// Visual biomes used across the 10-level campaign. Each theme is backed by its
/// own Wang tileset, letting the dungeon feel fresher the deeper you descend
/// without changing any gameplay layout code.
enum DungeonTheme {
  /// Levels 1-3 — warm, cozy sandstone temple. The welcome mat.
  templeWarm,

  /// Levels 4-6 — cool mossy crypt stone. Damp and atmospheric.
  cryptCool,

  /// Levels 7-9 — indigo mage chamber with faint magenta runes. Ethereal.
  magicChamber,

  /// Level 10 (and beyond, if the campaign grows) — the Warden's arena, dark
  /// basalt with warm ember cracks.
  wardenArena,
}

/// Assets declared per theme. Drop PNG + JSON into
/// `assets/images/dungeon/` using the filenames below and the loader picks
/// them up automatically.
class DungeonThemeAssets {
  const DungeonThemeAssets({
    required this.theme,
    required this.pngAsset,
    required this.jsonAsset,
    required this.label,
  });

  final DungeonTheme theme;

  /// Asset path passed to `Flame.images.load` (relative to `assets/images/`).
  final String pngAsset;

  /// Full asset path passed to `rootBundle.loadString`.
  final String jsonAsset;

  /// Short, human-readable label. Used for diagnostics.
  final String label;
}

/// Static registry. Keep the order aligned with progression: earliest theme
/// first so it acts as the implicit fallback when a later theme fails to load.
const List<DungeonThemeAssets> kDungeonThemeAssets = <DungeonThemeAssets>[
  DungeonThemeAssets(
    theme: DungeonTheme.templeWarm,
    pngAsset: 'dungeon/theme_temple_warm.png',
    jsonAsset: 'assets/images/dungeon/theme_temple_warm.json',
    label: 'Warm Temple',
  ),
  DungeonThemeAssets(
    theme: DungeonTheme.cryptCool,
    pngAsset: 'dungeon/theme_crypt_cool.png',
    jsonAsset: 'assets/images/dungeon/theme_crypt_cool.json',
    label: 'Cool Crypt',
  ),
  DungeonThemeAssets(
    theme: DungeonTheme.magicChamber,
    pngAsset: 'dungeon/theme_magic_chamber.png',
    jsonAsset: 'assets/images/dungeon/theme_magic_chamber.json',
    label: 'Mage Chamber',
  ),
  DungeonThemeAssets(
    theme: DungeonTheme.wardenArena,
    pngAsset: 'dungeon/theme_warden_arena.png',
    jsonAsset: 'assets/images/dungeon/theme_warden_arena.json',
    label: "Warden's Arena",
  ),
];

/// Legacy tileset used as a universal fallback if no themed tileset loads.
/// Kept so older builds can still render floors while new art is being cooked.
const DungeonThemeAssets kLegacyTempleTheme = DungeonThemeAssets(
  theme: DungeonTheme.templeWarm,
  pngAsset: 'dungeon/temple_tileset_16.png',
  jsonAsset: 'assets/images/dungeon/temple_tileset_16.json',
  label: 'Legacy Temple (fallback)',
);

/// Maps a 1-indexed dungeon level to its theme. Out-of-range levels clamp to
/// the nearest valid theme so hypothetical level 11+ still render.
DungeonTheme themeForLevel(int levelNumber) {
  if (levelNumber >= 10) {
    return DungeonTheme.wardenArena;
  }
  if (levelNumber >= 7) {
    return DungeonTheme.magicChamber;
  }
  if (levelNumber >= 4) {
    return DungeonTheme.cryptCool;
  }
  return DungeonTheme.templeWarm;
}
