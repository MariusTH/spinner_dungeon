import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'spinner_component.dart';
import 'spinner_game.dart';

class ChestComponent extends RectangleComponent
    with CollisionCallbacks, HasGameReference<SpinnerGame> {
  static ui.Image? _closedImage;
  static ui.Image? _openImage;

  ChestComponent({
    required Vector2 position,
    required this.coinReward,
  }) : super(
         position: position,
         size: Vector2(30, 24),
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0xFFC28D2E),
       );

  final int coinReward;
  bool isOpened = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(collisionType: CollisionType.passive));
    if (_closedImage == null) {
      try {
        _closedImage = await game.images.load('props/chest_closed.png');
      } catch (_) {
        _closedImage = null;
      }
    }
    if (_openImage == null) {
      try {
        _openImage = await game.images.load('props/chest_open.png');
      } catch (_) {
        _openImage = null;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x * 0.5, size.y * 0.5);

    final sprite = isOpened ? _openImage : _closedImage;
    if (sprite != null) {
      final dst = Rect.fromCenter(
        center: Offset.zero,
        width: size.x * 1.8,
        height: size.y * 2.2,
      );
      final src = Rect.fromLTWH(
        0,
        0,
        sprite.width.toDouble(),
        sprite.height.toDouble(),
      );
      canvas.drawImageRect(sprite, src, dst, Paint());
    } else {
      final lidPaint = Paint()
        ..color = isOpened ? const Color(0xFF8D8F96) : const Color(0xFFF2C357);
      final lockPaint = Paint()..color = const Color(0xFF3A2A0B);

      final lidHeight = isOpened ? 6.0 : 10.0;
      canvas.drawRect(
        Rect.fromLTWH(-size.x / 2, -size.y / 2, size.x, lidHeight),
        lidPaint,
      );

      if (!isOpened) {
        canvas.drawRect(
          Rect.fromCenter(center: const Offset(0, 2), width: 5, height: 8),
          lockPaint,
        );
      }
    }
    canvas.restore();
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (isOpened) {
      return;
    }

    if (other is SpinnerComponent) {
      open();
      game.onChestOpened(this);
    }
  }

  void open() {
    isOpened = true;
    paint.color = const Color(0xFF737780);
  }
}
