import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'spinner_component.dart';
import 'spinner_game.dart';

class CoinPickupComponent extends CircleComponent
    with CollisionCallbacks, HasGameReference<SpinnerGame> {
  CoinPickupComponent({
    required Vector2 position,
    required this.value,
    Vector2? initialVelocity,
    this.lifeTime = 12,
  }) : _velocity = initialVelocity ?? Vector2.zero(),
       super(
         position: position,
         radius: 7,
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0xFFF2C75C),
       );

  final int value;
  final double lifeTime;

  Vector2 _velocity;
  double _alive = 0;
  bool _collected = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_collected) {
      return;
    }

    if (game.isWorldFrozen) {
      return;
    }

    _alive += dt;
    if (_alive >= lifeTime) {
      removeFromParent();
      return;
    }

    position += _velocity * dt;
    _velocity *= 0.92;
    angle += dt * 2.3;
  }

  @override
  void render(Canvas canvas) {
    // CircleComponent's local origin is the top-left of its bounding box.
    // Translate to the visual center so the base disc AND the inner details
    // both draw on the coin's actual world position. Previously `super.render`
    // drew the base circle at visual center while the notch + inner circle
    // drew at Offset.zero (top-left), making the coin look like a colored
    // blob with a sprite offset from it.
    canvas.save();
    canvas.translate(radius, radius);

    canvas.drawCircle(Offset.zero, radius, paint);

    final innerPaint = Paint()..color = const Color(0xFFFFEEA7);
    final notchPaint = Paint()..color = const Color(0xFFB9891C);

    canvas.drawCircle(Offset.zero, radius * 0.5, innerPaint);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: 2.5, height: radius * 1.15),
      notchPaint,
    );

    canvas.restore();
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (_collected) {
      return;
    }

    if (other is SpinnerComponent) {
      _collected = true;
      game.onCoinCollected(this);
      removeFromParent();
    }
  }
}
