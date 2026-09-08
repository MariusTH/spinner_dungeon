import 'dart:convert';

import 'tile_semantics.dart';

/// One authored room footprint: fixed [cols]×[rows] of semantic tile IDs, optional
/// parallel [hurt] tier grid, and optional [entities] exported from LDtk (spawns,
/// markers, and **socket** points — see [RoomTemplateEntity]).
class RoomTemplate {
  const RoomTemplate({
    required this.id,
    required this.version,
    required this.tileSemanticsVersion,
    required this.cols,
    required this.rows,
    required this.semantics,
    this.hurt,
    this.entities = const <RoomTemplateEntity>[],
  });

  final String id;
  final int version;
  final int tileSemanticsVersion;
  final int cols;
  final int rows;

  /// Row-major: `semantics[y * cols + x]`.
  final List<int> semantics;

  /// Optional same-length grid: 0 = none, 1 = low, 2 = high.
  final List<int>? hurt;

  final List<RoomTemplateEntity> entities;

  int semanticAt(int x, int y) {
    if (x < 0 || y < 0 || x >= cols || y >= rows) {
      return TileSemantics.empty;
    }
    return semantics[y * cols + x];
  }

  int hurtAt(int x, int y) {
    final h = hurt;
    if (h == null || x < 0 || y < 0 || x >= cols || y >= rows) {
      return 0;
    }
    return h[y * cols + x];
  }

  static RoomTemplate fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? 'unknown';
    final version = (json['version'] as num?)?.toInt() ?? 1;
    final tsv = (json['tileSemanticsVersion'] as num?)?.toInt() ?? 1;
    final cols = (json['cols'] as num?)?.toInt() ?? 0;
    final rows = (json['rows'] as num?)?.toInt() ?? 0;
    final semRaw = json['semantics'];
    final sem = <int>[];
    if (semRaw is List) {
      for (final v in semRaw) {
        if (v is num) {
          sem.add(v.toInt());
        }
      }
    }
    List<int>? hurt;
    final hurtRaw = json['hurt'];
    if (hurtRaw is List) {
      hurt = <int>[];
      for (final v in hurtRaw) {
        if (v is num) {
          hurt.add(v.toInt());
        }
      }
      if (hurt.length != sem.length) {
        hurt = null;
      }
    }

    final entities = <RoomTemplateEntity>[];
    final entRaw = json['entities'];
    if (entRaw is List) {
      for (final e in entRaw) {
        if (e is Map<String, dynamic>) {
          entities.add(RoomTemplateEntity.fromJson(e));
        } else if (e is Map) {
          entities.add(
            RoomTemplateEntity.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }

    return RoomTemplate(
      id: id,
      version: version,
      tileSemanticsVersion: tsv,
      cols: cols,
      rows: rows,
      semantics: sem,
      hurt: hurt,
      entities: entities,
    );
  }

  static RoomTemplate fromJsonString(String source) =>
      fromJson(jsonDecode(source) as Map<String, dynamic>);
}

class RoomTemplateEntity {
  const RoomTemplateEntity({
    required this.kind,
    required this.cx,
    required this.cy,
    this.fields = const <String, dynamic>{},
  });

  /// e.g. `enemy` / `item` (spawn or pickup hints), or `socket` (**not** a spawn:
  /// attachment origin on an enemy *sprite* for shields, trim, etc.).
  final String kind;

  /// Cell coordinates (0..cols), top-left origin; **center** of entity in cell.
  final double cx;
  final double cy;

  final Map<String, dynamic> fields;

  static RoomTemplateEntity fromJson(Map<String, dynamic> json) {
    return RoomTemplateEntity(
      kind: json['kind'] as String? ?? 'marker',
      cx: (json['cx'] as num?)?.toDouble() ?? 0,
      cy: (json['cy'] as num?)?.toDouble() ?? 0,
      fields: Map<String, dynamic>.from(
        (json['fields'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
    );
  }
}

/// One 90° CW rotation on a row-major [c]×[r] grid; new size is [r]×[c].
List<int> _rotate90Cw({
  required int c,
  required int r,
  required List<int> g,
}) {
  final out = List<int>.filled(c * r, 0);
  for (var y = 0; y < r; y++) {
    for (var x = 0; x < c; x++) {
      final nx = r - 1 - y;
      final ny = x;
      out[ny * r + nx] = g[y * c + x];
    }
  }
  return out;
}

/// Row-major: flipH mirrors within each row, flipV mirrors top/bottom.
List<int> _flipGrid({
  required int c,
  required int r,
  required List<int> g,
  required bool flipH,
  required bool flipV,
}) {
  var out = List<int>.from(g);
  if (flipH) {
    for (var y = 0; y < r; y++) {
      for (var x = 0; x < c ~/ 2; x++) {
        final a = y * c + x;
        final b = y * c + (c - 1 - x);
        final t = out[a];
        out[a] = out[b];
        out[b] = t;
      }
    }
  }
  if (flipV) {
    for (var x = 0; x < c; x++) {
      for (var y = 0; y < r ~/ 2; y++) {
        final a = y * c + x;
        final b = (r - 1 - y) * c + x;
        final t = out[a];
        out[a] = out[b];
        out[b] = t;
      }
    }
  }
  return out;
}

/// Returns transformed semantics + optional hurt (same transform).
({int cols, int rows, List<int> sem, List<int>? hurt}) applyTemplateTransform(
  RoomTemplate t, {
  required int quarterTurns,
  required bool flipH,
  required bool flipV,
}) {
  if (t.tileSemanticsVersion != kTileSemanticsVersion) {
    return (
      cols: t.cols,
      rows: t.rows,
      sem: List<int>.from(t.semantics),
      hurt: t.hurt != null ? List<int>.from(t.hurt!) : null,
    );
  }
  if (quarterTurns & 3 == 0 && !flipH && !flipV) {
    return (
      cols: t.cols,
      rows: t.rows,
      sem: List<int>.from(t.semantics),
      hurt: t.hurt != null ? List<int>.from(t.hurt!) : null,
    );
  }
  var c = t.cols;
  var r = t.rows;
  var sem = List<int>.from(t.semantics);
  var hurt = t.hurt != null ? List<int>.from(t.hurt!) : null;

  for (var i = 0; i < (quarterTurns & 3); i++) {
    sem = _rotate90Cw(c: c, r: r, g: sem);
    if (hurt != null) {
      hurt = _rotate90Cw(c: c, r: r, g: hurt);
    }
    final nc = r;
    final nr = c;
    c = nc;
    r = nr;
  }
  sem = _flipGrid(c: c, r: r, g: sem, flipH: flipH, flipV: flipV);
  if (hurt != null) {
    hurt = _flipGrid(c: c, r: r, g: hurt, flipH: flipH, flipV: flipV);
  }
  return (cols: c, rows: r, sem: sem, hurt: hurt);
}
