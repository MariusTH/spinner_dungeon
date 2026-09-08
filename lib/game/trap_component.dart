import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'spinner_component.dart';
import 'spinner_game.dart';

class TrapComponent extends CircleComponent
    with CollisionCallbacks, HasGameReference<SpinnerGame> {
  static ui.Image? _trapImage;

  TrapComponent({required Vector2 position})
    : super(
        position: position,
        radius: 14,
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0xFF9A3D3D),
      );

  double _cooldown = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox(collisionType: CollisionType.passive));
    if (_trapImage == null) {
      try {
        _trapImage = await game.images.load('props/trap_spike.png');
      } catch (_) {
        _trapImage = null;
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
    angle += dt * 0.8;
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(radius, radius);

    final sprite = _trapImage;
    if (sprite != null) {
      final dst = Rect.fromCenter(
        center: Offset.zero,
        width: radius * 3.2,
        height: radius * 3.2,
      );
      final src = Rect.fromLTWH(
        0,
        0,
        sprite.width.toDouble(),
        sprite.height.toDouble(),
      );
      canvas.drawImageRect(sprite, src, dst, Paint());
    } else {
      final spikePaint = Paint()..color = const Color(0xFFC95757);
      final count = 8;
      for (var i = 0; i < count; i++) {
        final theta = (2 * pi * i) / count;
        final inner = Offset(
          cos(theta) * (radius - 4),
          sin(theta) * (radius - 4),
        );
        final outer = Offset(
          cos(theta) * (radius + 4),
          sin(theta) * (radius + 4),
        );
        canvas.drawLine(inner, outer, spikePaint..strokeWidth = 2.5);
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

    if (_cooldown > 0) {
      return;
    }

    if (other is SpinnerComponent) {
      _cooldown = 0.8;
      game.onTrapTriggered(this, other);
    }
  }
}
