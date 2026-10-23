import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'hit_reaction.dart';
import 'rendering/prop_painters.dart';

import 'spinner_component.dart';
import 'spinner_game.dart';

class TrapComponent extends CircleComponent
    with CollisionCallbacks, HasGameReference<SpinnerGame>, HitReaction {
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

    paintSpikeTrap(canvas, radius: radius);
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
      triggerHitReaction();
      game.onTrapTriggered(this, other);
    }
  }
}
