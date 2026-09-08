import 'dart:convert';

import '../room_template.dart';
import '../tile_semantics.dart';

/// Parses a minimal subset of **LDtk** project JSON (`.ldtk`) to build a
/// [RoomTemplate] from the first level’s IntGrid layer.
///
/// Prefer checking in `assets/levels/room_templates/*.json` exports for stable
/// CI; use this when you want to load a project file at runtime or in a tool.
///
/// The [flame_ldtk] package also provides full [LdtkWorld] loading — re-exported
/// from this library for convenience when you need rendering, not just grids.
RoomTemplate? roomTemplateFromLdtkProjectString(
  String source, {
  String semanticsLayerName = 'Semantics',
  String hurtLayerName = 'Hurt',
  String templateId = 'ldtk_import',
}) {
  try {
    final root = jsonDecode(source) as Map<String, dynamic>;
    final levels = root['levels'] as List<dynamic>?;
    if (levels == null || levels.isEmpty) {
      return null;
    }
    final level = levels.first as Map<String, dynamic>;
    final layerInstances = level['layerInstances'] as List<dynamic>? ?? const [];
    Map<String, dynamic>? semanticsLayer;
    Map<String, dynamic>? hurtLayer;
    for (final raw in layerInstances) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final id = raw['__identifier'] as String? ?? raw['identifier'] as String?;
      if (id == semanticsLayerName) {
        semanticsLayer = raw;
      }
      if (id == hurtLayerName) {
        hurtLayer = raw;
      }
    }
    if (semanticsLayer == null) {
      return null;
    }

    final cw = (level['__cWid'] as num?)?.toInt() ??
        (level['pxWid'] as num?)?.toInt() ??
        0;
    final ch = (level['__cHei'] as num?)?.toInt() ??
        (level['pxHei'] as num?)?.toInt() ??
        0;
    var cols = cw;
    var rows = ch;
    if (cols <= 0 || rows <= 0) {
      final grid = level['__gridSize'] as int? ?? 0;
      final w = (level['pxWid'] as num?)?.toInt() ?? 0;
      final h = (level['pxHei'] as num?)?.toInt() ?? 0;
      if (grid > 0 && w > 0 && h > 0) {
        cols = (w / grid).ceil();
        rows = (h / grid).ceil();
      }
    }
    if (cols <= 0 || rows <= 0) {
      return null;
    }

    final csv = semanticsLayer['intGridCsv'] as String?;
    List<int>? ints;
    if (csv != null && csv.isNotEmpty) {
      ints = csv
          .split(',')
          .map((s) => int.tryParse(s.trim()) ?? TileSemantics.floor)
          .toList();
    } else {
      final intGrid = semanticsLayer['intGrid'] as List<dynamic>?;
      if (intGrid != null) {
        ints = intGrid.map((e) {
          if (e is int) {
            return e;
          }
          if (e is Map && e['v'] != null) {
            return (e['v'] as num).toInt();
          }
          return TileSemantics.floor;
        }).toList();
      }
    }
    if (ints == null || ints.length != cols * rows) {
      return null;
    }

    List<int>? hurt;
    if (hurtLayer != null) {
      final hcsv = hurtLayer['intGridCsv'] as String?;
      if (hcsv != null && hcsv.isNotEmpty) {
        hurt = hcsv
            .split(',')
            .map((s) => int.tryParse(s.trim()) ?? 0)
            .toList();
        if (hurt.length != ints.length) {
          hurt = null;
        }
      }
    }

    return RoomTemplate(
      id: templateId,
      version: 1,
      tileSemanticsVersion: kTileSemanticsVersion,
      cols: cols,
      rows: rows,
      semantics: ints,
      hurt: hurt,
      entities: const <RoomTemplateEntity>[],
    );
  } catch (_) {
    return null;
  }
}
