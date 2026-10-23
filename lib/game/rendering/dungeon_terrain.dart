import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../dungeon_theme.dart';

// agent.md palette. Theme colours are mixes of these, never eyeballed hexes.
const Color _deepVoid = Color(0xFF1A1412);
const Color _shadowStone = Color(0xFF2F2F2F);
const Color _stoneBase = Color(0xFF919090);
const Color _coolShadow = Color(0xFF27367B);
const Color _wood = Color(0xFF4F3816);
const Color _emberOrange = Color(0xFFFF6A1F);
const Color _chromeRed = Color(0xFFC1231C);
const Color _magic = Color(0xFFEBC7FF);
const Color _bone = Color(0xFFF1E2C4);

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// Colours for one biome's floor and walls.
class TerrainPalette {
  const TerrainPalette({
    required this.floorLight,
    required this.floorDark,
    required this.mortar,
    required this.wallFill,
    required this.wallLip,
    required this.outline,
  });

  /// Flagstones pick a tone between these two.
  final Color floorLight;
  final Color floorDark;

  /// Gaps between flagstones and their drop edge.
  final Color mortar;

  /// Wall tops: a darkened version of the floor stone (agent.md: walls are
  /// never pure black).
  final Color wallFill;

  /// Lighter rim where the wall top meets the floor.
  final Color wallLip;

  /// Thick chunky outline for walls and the floor edge.
  final Color outline;

  factory TerrainPalette.forTheme(DungeonTheme theme) {
    switch (theme) {
      case DungeonTheme.templeWarm:
        final light = _mix(_bone, _emberOrange, 0.22);
        final dark = _mix(light, _wood, 0.28);
        return TerrainPalette(
          floorLight: light,
          floorDark: dark,
          mortar: _mix(dark, _wood, 0.55),
          wallFill: _mix(_wood, _emberOrange, 0.18),
          wallLip: _mix(_wood, _bone, 0.38),
          outline: _mix(_wood, _deepVoid, 0.7),
        );
      case DungeonTheme.cryptCool:
        final light = _mix(_stoneBase, _bone, 0.18);
        final dark = _mix(_stoneBase, _coolShadow, 0.22);
        return TerrainPalette(
          floorLight: light,
          floorDark: dark,
          mortar: _mix(_stoneBase, _coolShadow, 0.55),
          wallFill: _mix(_coolShadow, _shadowStone, 0.45),
          wallLip: _mix(_coolShadow, _stoneBase, 0.5),
          outline: _mix(_coolShadow, _deepVoid, 0.75),
        );
      case DungeonTheme.magicChamber:
        final light = _mix(_stoneBase, _magic, 0.45);
        final dark = _mix(light, _coolShadow, 0.25);
        return TerrainPalette(
          floorLight: light,
          floorDark: dark,
          mortar: _mix(_coolShadow, _magic, 0.35),
          wallFill: _mix(_coolShadow, _magic, 0.12),
          wallLip: _mix(_coolShadow, _magic, 0.5),
          outline: _mix(_coolShadow, _deepVoid, 0.7),
        );
      case DungeonTheme.wardenArena:
        final light = _mix(_stoneBase, _shadowStone, 0.25);
        final dark = _mix(_stoneBase, _shadowStone, 0.5);
        return TerrainPalette(
          floorLight: light,
          floorDark: dark,
          mortar: _mix(_shadowStone, _chromeRed, 0.18),
          wallFill: _mix(_shadowStone, _chromeRed, 0.28),
          wallLip: _mix(_shadowStone, _emberOrange, 0.45),
          outline: _mix(_shadowStone, _deepVoid, 0.75),
        );
    }
  }
}

/// A walkable rectangle of the level in world units. Corridors lay their
/// flagstones across the direction of travel.
class TerrainRegion {
  const TerrainRegion(this.rect, {this.isCorridor = false});

  final Rect rect;
  final bool isCorridor;
}

/// Records the static dungeon floor and walls as one vector [ui.Picture]:
/// irregular hand-drawn flagstones, chunky outlined wall tops and a soft
/// edge shadow. Drawn as vectors, so it stays crisp at any camera zoom and
/// has no texture to alias or visibly repeat.
///
/// [wallInset] is how far collision walls reach into the floor and
/// [wallOutset] how far the drawn wall top extends past the floor edge.
/// [blocks] are solid interior cells drawn as raised wall chunks.
ui.Picture paintDungeonTerrain({
  required List<TerrainRegion> regions,
  required TerrainPalette palette,
  required int seed,
  required double wallInset,
  required double wallOutset,
  List<Rect> blocks = const <Rect>[],
}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (regions.isEmpty) {
    return recorder.endRecording();
  }

  Path union(Iterable<Path> paths) {
    Path? acc;
    for (final p in paths) {
      acc = acc == null ? p : Path.combine(PathOperation.union, acc, p);
    }
    return acc ?? Path();
  }

  final wallOuter = union(
    regions.map(
      (r) => Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            r.rect.inflate(wallOutset),
            Radius.circular(wallOutset * 0.8),
          ),
        ),
    ),
  );
  final floor = union(
    regions.map(
      (r) => Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            r.rect.deflate(wallInset),
            const Radius.circular(6),
          ),
        ),
    ),
  );

  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  // Wall: drop shadow, fill, brick joints, outline.
  canvas.drawPath(
    wallOuter.shift(const Offset(0, 10)),
    Paint()..color = _deepVoid.withValues(alpha: 0.55),
  );
  canvas.drawPath(wallOuter, Paint()..color = palette.wallFill);
  canvas.save();
  canvas.clipPath(wallOuter);
  _paintWallJoints(canvas, regions, palette, seed, wallInset, wallOutset);
  canvas.restore();
  canvas.drawPath(
    wallOuter,
    stroke
      ..color = palette.outline
      ..strokeWidth = 5,
  );
  // Lip: half of this stroke lands on the wall top; the floor covers the rest.
  canvas.drawPath(
    floor,
    stroke
      ..color = palette.wallLip
      ..strokeWidth = 16,
  );

  // Floor.
  canvas.save();
  canvas.clipPath(floor);
  canvas.drawPath(floor, Paint()..color = palette.mortar);
  // Corridors first so rooms win where they overlap at doorways.
  final ordered = [
    ...regions.where((r) => r.isCorridor),
    ...regions.where((r) => !r.isCorridor),
  ];
  for (var i = 0; i < ordered.length; i++) {
    final region = ordered[i];
    canvas.save();
    final clip = region.rect.deflate(region.isCorridor ? 0 : wallInset);
    canvas.clipRect(clip);
    // Fresh mortar so slabs from an overlapping corridor never show through.
    canvas.drawRect(clip, Paint()..color = palette.mortar);
    _paintFlagstones(canvas, region, palette, Random(seed * 31 + i * 7919));
    canvas.restore();
  }
  // Soft inner edge shadow so the floor sits below the wall tops.
  canvas.drawPath(
    floor,
    stroke
      ..color = _deepVoid.withValues(alpha: 0.18)
      ..strokeWidth = 34,
  );
  canvas.drawPath(
    floor,
    stroke
      ..color = _deepVoid.withValues(alpha: 0.18)
      ..strokeWidth = 16,
  );
  canvas.restore();
  canvas.drawPath(
    floor,
    stroke
      ..color = palette.outline
      ..strokeWidth = 4,
  );

  for (final block in blocks) {
    _paintBlock(canvas, block, palette);
  }

  return recorder.endRecording();
}

void _paintFlagstones(
  Canvas canvas,
  TerrainRegion region,
  TerrainPalette palette,
  Random random,
) {
  final rect = region.rect;
  // Lay rows across the long axis of corridors, along x for rooms.
  final alongX = !region.isCorridor || rect.height > rect.width;
  final uLen = alongX ? rect.width : rect.height;
  final vLen = alongX ? rect.height : rect.width;
  Offset toWorld(double u, double v) => alongX
      ? Offset(rect.left + u, rect.top + v)
      : Offset(rect.left + v, rect.top + u);

  // Rooms are either loose flagstone rows or a chunky checkered tile grid.
  final grid = !region.isCorridor && random.nextDouble() < 0.4;
  final gridCell = 60.0 + random.nextDouble() * 16;
  final minRow = grid ? gridCell : (region.isCorridor ? 30.0 : 36.0);
  final maxRow = grid ? gridCell : (region.isCorridor ? 44.0 : 58.0);
  final minSlab = grid ? gridCell : (region.isCorridor ? 34.0 : 40.0);
  final maxSlab = grid ? gridCell : (region.isCorridor ? 60.0 : 92.0);
  const gap = 3.5;

  final edge = Paint()..color = palette.mortar;
  final fill = Paint();
  final detail = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = 1.8
    ..color = palette.mortar;
  final shine = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 2.2
    ..color = palette.floorLight.withValues(alpha: 0.55);

  // Grid rooms centre the grid so edge tiles are cut evenly on both sides.
  var v = grid
      ? (vLen % gridCell) / 2 - gridCell
      : -random.nextDouble() * minRow;
  var row = 0;
  while (v < vLen) {
    final rowH = minRow + random.nextDouble() * (maxRow - minRow);
    var u = grid
        ? (uLen % gridCell) / 2 - gridCell
        : -random.nextDouble() * maxSlab;
    var col = 0;
    while (u < uLen) {
      final slabW = minSlab + random.nextDouble() * (maxSlab - minSlab);
      final corners = <Offset>[
        toWorld(u + gap, v + gap),
        toWorld(u + slabW - gap, v + gap),
        toWorld(u + slabW - gap, v + rowH - gap),
        toWorld(u + gap, v + rowH - gap),
      ];
      // Wobble every corner a little so slabs look hand drawn.
      for (var c = 0; c < corners.length; c++) {
        corners[c] = corners[c].translate(
          (random.nextDouble() - 0.5) * 5,
          (random.nextDouble() - 0.5) * 5,
        );
      }
      final path = _roundedQuad(corners, 7);
      final tone = grid
          ? ((row + col).isEven ? 0.72 : 0.22) + random.nextDouble() * 0.2
          : random.nextDouble();
      fill.color = _mix(palette.floorDark, palette.floorLight, tone);
      // Chunky drop edge, then the slab face.
      canvas.drawPath(path.shift(const Offset(0, 3)), edge);
      canvas.drawPath(path, fill);
      // Top-left highlight along the upper edge.
      if (tone > 0.35) {
        final a = Offset.lerp(corners[0], corners[1], 0.18)!;
        final b = Offset.lerp(corners[0], corners[1], 0.62)!;
        canvas.drawLine(a.translate(0, 4), b.translate(0, 4), shine);
      }
      final roll = random.nextDouble();
      if (roll < 0.12) {
        _paintCrack(canvas, corners, random, detail);
      } else if (roll < 0.2) {
        final c = Offset.lerp(
          corners[0],
          corners[2],
          0.3 + random.nextDouble() * 0.4,
        )!;
        canvas.drawCircle(c, 2.2 + random.nextDouble() * 1.6, edge);
      }
      u += slabW;
      col++;
    }
    v += rowH;
    row++;
  }
}

void _paintCrack(
  Canvas canvas,
  List<Offset> corners,
  Random random,
  Paint paint,
) {
  final start = Offset.lerp(
    corners[0],
    corners[1],
    0.2 + random.nextDouble() * 0.6,
  )!;
  final end = Offset.lerp(
    corners[3],
    corners[2],
    0.2 + random.nextDouble() * 0.6,
  )!;
  final mid1 = Offset.lerp(
    start,
    end,
    0.35,
  )!.translate((random.nextDouble() - 0.5) * 10, 0);
  final mid2 = Offset.lerp(
    start,
    end,
    0.65,
  )!.translate((random.nextDouble() - 0.5) * 10, 0);
  // Short cracks only: stop part way across the slab.
  final stop = Offset.lerp(mid2, end, random.nextDouble() * 0.6)!;
  canvas.drawPath(
    Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(mid1.dx, mid1.dy)
      ..lineTo(mid2.dx, mid2.dy)
      ..lineTo(stop.dx, stop.dy),
    paint,
  );
}

/// Short joint strokes across the wall band so wall tops read as masonry.
void _paintWallJoints(
  Canvas canvas,
  List<TerrainRegion> regions,
  TerrainPalette palette,
  int seed,
  double wallInset,
  double wallOutset,
) {
  final random = Random(seed ^ 0x5eed);
  final joint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 3
    ..color = palette.outline.withValues(alpha: 0.55);
  final innerOffset = -wallInset;
  final outerOffset = wallOutset - 4;

  void alongEdge(Offset from, Offset to, Offset outward) {
    final len = (to - from).distance;
    final dir = (to - from) / len;
    var t = random.nextDouble() * 30;
    while (t < len) {
      final p = from + dir * t;
      canvas.drawLine(
        p + outward * (innerOffset + 6),
        p + outward * outerOffset,
        joint,
      );
      t += 34 + random.nextDouble() * 22;
    }
  }

  for (final region in regions) {
    final r = region.rect;
    alongEdge(r.topLeft, r.topRight, const Offset(0, -1));
    alongEdge(r.bottomLeft, r.bottomRight, const Offset(0, 1));
    alongEdge(r.topLeft, r.bottomLeft, const Offset(-1, 0));
    alongEdge(r.topRight, r.bottomRight, const Offset(1, 0));
  }
}

void _paintBlock(Canvas canvas, Rect block, TerrainPalette palette) {
  final rrect = RRect.fromRectAndRadius(
    block.deflate(2),
    const Radius.circular(8),
  );
  canvas.drawRRect(
    rrect.shift(const Offset(0, 8)),
    Paint()..color = _deepVoid.withValues(alpha: 0.5),
  );
  canvas.drawRRect(rrect, Paint()..color = palette.wallFill);
  canvas.drawRRect(
    rrect.deflate(6),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = palette.wallLip,
  );
  canvas.drawRRect(
    rrect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = palette.outline,
  );
}

/// Closed quad through [corners] with each corner rounded by [radius].
Path _roundedQuad(List<Offset> corners, double radius) {
  final path = Path();
  final n = corners.length;
  for (var i = 0; i < n; i++) {
    final prev = corners[(i - 1 + n) % n];
    final cur = corners[i];
    final next = corners[(i + 1) % n];
    final toPrev = prev - cur;
    final toNext = next - cur;
    final rPrev = min(radius, toPrev.distance / 2);
    final rNext = min(radius, toNext.distance / 2);
    final a = cur + toPrev / toPrev.distance * rPrev;
    final b = cur + toNext / toNext.distance * rNext;
    if (i == 0) {
      path.moveTo(a.dx, a.dy);
    } else {
      path.lineTo(a.dx, a.dy);
    }
    path.quadraticBezierTo(cur.dx, cur.dy, b.dx, b.dy);
  }
  return path..close();
}

/// Draws a pre-recorded terrain [picture] in world space, behind everything.
class DungeonTerrainComponent extends PositionComponent {
  DungeonTerrainComponent({required this.picture, super.priority = -100});

  final ui.Picture picture;

  @override
  void render(Canvas canvas) {
    canvas.drawPicture(picture);
  }

  @override
  void onRemove() {
    picture.dispose();
    super.onRemove();
  }
}
