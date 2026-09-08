import 'dart:ui' as ui;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'spinner_component.dart';
import 'spinner_game.dart';

class PitComponent extends CircleComponent
    with CollisionCallbacks, HasGameReference<SpinnerGame> {
  PitComponent({required Vector2 position, double radius = 24})
    : super(
        position: position,
        radius: radius,
        anchor: Anchor.center,
        paint: Paint()..color = Colors.transparent,
      );

  double _cooldown = 0;
  static ui.Image? _pitImage;
  static bool _pitImageLoadAttempted = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox(collisionType: CollisionType.passive));
    if (!_pitImageLoadAttempted) {
      _pitImageLoadAttempted = true;
      try {
        _pitImage = await game.images.load('props/pit_hole.png');
      } catch (_) {
        _pitImage = null;
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isWorldFrozen) {
      return;
    }

    if (_cooldown > 0) {
      _cooldown -= dt;
    }
  }

  @override
  void render(Canvas canvas) {
    final image = _pitImage;
    if (image == null) {
      // Procedural fallback: cozy dark void with warm amber rim so the pit
      // still reads even if the art hasn't been loaded yet.
      final center = Offset(radius, radius);
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = const Color(0xFF1A0F1F),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = const Color(0xFFFFB347).withValues(alpha: 0.8),
      );
      return;
    }
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Rect.fromCircle(center: Offset(radius, radius), radius: radius);
    canvas.drawImageRect(image, src, dst, Paint());
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (_cooldown > 0) {
      return;
    }

    if (other is SpinnerComponent) {
      _cooldown = 0.5;
      game.onPitTriggered(this, other);
    }
  }
}
