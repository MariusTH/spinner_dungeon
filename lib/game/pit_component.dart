import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'rendering/prop_painters.dart';

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

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox(collisionType: CollisionType.passive));
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
    canvas.save();
    canvas.translate(radius, radius);
    paintPit(canvas, radius: radius);
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
      _cooldown = 0.5;
      game.onPitTriggered(this, other);
    }
  }
}
