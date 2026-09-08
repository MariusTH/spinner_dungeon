import 'dart:convert';

import 'package:flame/sprite.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'dungeon_theme.dart';
import 'tile_semantics.dart';

/// Maps [TileSemantics] IDs to a **flat sprite index** (0..15) in the theme’s
/// 4×4 Wang sheet — same art atlas as [_ThemeSprites.floorTileSprites], so themes
/// can share layout JSON while still swapping the PNG.
class SemanticThemeMapping {
  const SemanticThemeMapping._(this._spriteIndexBySemantic);

  final Map<int, int> _spriteIndexBySemantic;

  static SemanticThemeMapping? _cached;

  /// Loads a shared mapping; falls back to a reasonable default if the asset
  /// is missing (same keys for every theme in v1).
  static Future<SemanticThemeMapping> load() async {
    if (_cached != null) {
      return _cached!;
    }
    try {
      final raw = await rootBundle.loadString(
        'assets/images/dungeon/semantic_theme_default.json',
      );
      _cached = _parse(raw);
      return _cached!;
    } catch (_) {
      _cached = SemanticThemeMapping._(_fallbackIndices);
      return _cached!;
    }
  }

  /// Per-theme file name under `assets/images/dungeon/`, e.g. semantic_theme_crypt_cool.json
  static Future<SemanticThemeMapping> loadForTheme(DungeonTheme theme) async {
    final assetName = _assetFileForTheme(theme);
    try {
      final raw = await rootBundle.loadString(
        'assets/images/dungeon/$assetName',
      );
      return _parse(raw);
    } catch (_) {
      return load();
    }
  }

  static String _assetFileForTheme(DungeonTheme theme) {
    switch (theme) {
      case DungeonTheme.templeWarm:
        return 'semantic_theme_temple_warm.json';
      case DungeonTheme.cryptCool:
        return 'semantic_theme_crypt_cool.json';
      case DungeonTheme.magicChamber:
        return 'semantic_theme_magic_chamber.json';
      case DungeonTheme.wardenArena:
        return 'semantic_theme_warden_arena.json';
    }
  }

  static SemanticThemeMapping _parse(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final version = decoded['tileSemanticsVersion'] as int? ?? 0;
    if (version != kTileSemanticsVersion) {
      return SemanticThemeMapping._(_fallbackIndices);
    }
    final mapRaw = decoded['spriteIndexBySemantic'] as Map<String, dynamic>?;
    if (mapRaw == null) {
      return SemanticThemeMapping._(_fallbackIndices);
    }
    final out = <int, int>{};
    for (final e in mapRaw.entries) {
      final k = int.tryParse(e.key);
      final v = (e.value as num?)?.toInt();
      if (k != null && v != null) {
        out[k] = v.clamp(0, 15);
      }
    }
    return SemanticThemeMapping._(out);
  }

  /// Default: map semantics to distinct Wang indices (16-tile sheet).
  static final Map<int, int> _fallbackIndices = <int, int>{
    TileSemantics.floor: 8,
    TileSemantics.wallNorthBand: 15,
    TileSemantics.wallSouthBand: 0,
    TileSemantics.wallEastBand: 3,
    TileSemantics.wallWestBand: 1,
    TileSemantics.solidBlock: 7,
    TileSemantics.pit: 4,
    TileSemantics.hurtLow: 6,
    TileSemantics.hurtHigh: 5,
  };

  Sprite? spriteForSemantic(List<Sprite> floorTileSprites, int semanticId) {
    if (floorTileSprites.isEmpty) {
      return null;
    }
    final idx = _spriteIndexBySemantic[semanticId] ??
        _fallbackIndices[semanticId] ??
        _spriteIndexBySemantic[TileSemantics.floor] ??
        8;
    final i = idx.clamp(0, floorTileSprites.length - 1);
    return floorTileSprites[i];
  }
}
