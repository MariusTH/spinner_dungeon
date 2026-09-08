import 'dart:math';

import 'package:image/image.dart' as img;

import 'dungeon_level_generator.dart';

/// Rasterizes a [DungeonLevel] (tile coordinates) to a PNG preview: room rects
/// over the carved corridors, with a marker dot for the start room and small
/// dots for rooms holding monsters/items.
class DungeonPreviewRenderer {
  const DungeonPreviewRenderer({this.cellSize = 14, this.margin = 24});

  /// Pixels per dungeon tile.
  final int cellSize;
  final int margin;

  img.Image render(DungeonLevel dungeon) {
    final rooms = dungeon.rooms;
    if (rooms.isEmpty) {
      final emptyImage = img.Image(width: 256, height: 128);
      img.fill(emptyImage, color: _backgroundColor());
      return emptyImage;
    }

    final width = (margin * 2) + (dungeon.width * cellSize);
    final height = (margin * 2) + (dungeon.height * cellSize);
    final image = img.Image(width: width, height: height);
    img.fill(image, color: _backgroundColor());

    // Corridors first, so rooms paint over the elbows.
    for (final corridor in dungeon.corridors) {
      _drawCorridor(image, corridor);
    }

    for (final room in rooms) {
      final left = margin + room.x * cellSize;
      final top = margin + room.y * cellSize;
      final right = left + room.width * cellSize;
      final bottom = top + room.height * cellSize;

      img.fillRect(
        image,
        x1: left,
        y1: top,
        x2: right,
        y2: bottom,
        color: _roomColor(room.type),
      );
      img.drawRect(
        image,
        x1: left,
        y1: top,
        x2: right,
        y2: bottom,
        color: img.ColorRgb8(220, 229, 242),
      );
      _drawMarkers(image, room: room, left: left, top: top, right: right);
    }

    return image;
  }

  List<int> renderPngBytes(DungeonLevel dungeon) {
    return img.encodePng(render(dungeon));
  }

  int _px(int tile) => margin + tile * cellSize + cellSize ~/ 2;

  void _drawCorridor(img.Image image, DungeonCorridor corridor) {
    final color = img.ColorRgb8(77, 93, 116);
    final half = max(1, (corridor.width * cellSize) ~/ 2);
    final ax = _px(corridor.ax);
    final ay = _px(corridor.ay);
    final bx = _px(corridor.bx);
    final by = _px(corridor.by);
    final ex = _px(corridor.elbowX);
    final ey = _px(corridor.elbowY);

    void segment(int x1, int y1, int x2, int y2) {
      img.fillRect(
        image,
        x1: min(x1, x2) - half,
        y1: min(y1, y2) - half,
        x2: max(x1, x2) + half,
        y2: max(y1, y2) + half,
        color: color,
      );
    }

    segment(ax, ay, ex, ey);
    segment(ex, ey, bx, by);
  }

  void _drawMarkers(
    img.Image image, {
    required DungeonRoom room,
    required int left,
    required int top,
    required int right,
  }) {
    final markerRadius = max(3, cellSize);
    if (room.monsters != null && room.monsters!.isNotEmpty) {
      img.fillCircle(
        image,
        x: right - markerRadius - 4,
        y: top + markerRadius + 4,
        radius: markerRadius,
        color: img.ColorRgb8(244, 98, 98),
      );
    }
    if (room.items != null && room.items!.isNotEmpty) {
      img.fillCircle(
        image,
        x: left + markerRadius + 4,
        y: top + markerRadius + 4,
        radius: markerRadius,
        color: img.ColorRgb8(117, 217, 146),
      );
    }
    if (room.type == DungeonRoomType.start) {
      img.fillCircle(
        image,
        x: (left + right) ~/ 2,
        y: top + markerRadius + 2,
        radius: markerRadius,
        color: img.ColorRgb8(130, 199, 255),
      );
    }
  }

  img.Color _backgroundColor() => img.ColorRgb8(14, 18, 27);

  img.Color _roomColor(DungeonRoomType type) {
    switch (type) {
      case DungeonRoomType.start:
        return img.ColorRgb8(70, 107, 163);
      case DungeonRoomType.combat:
        return img.ColorRgb8(63, 73, 88);
      case DungeonRoomType.trap:
        return img.ColorRgb8(130, 58, 64);
      case DungeonRoomType.treasure:
        return img.ColorRgb8(138, 118, 57);
      case DungeonRoomType.boss:
        return img.ColorRgb8(118, 76, 140);
    }
  }
}
