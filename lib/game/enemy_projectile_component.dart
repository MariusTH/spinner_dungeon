import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'spinner_component.dart';
import 'spinner_game.dart';
import 'wall_component.dart';

class EnemyProjectileComponent extends CircleComponent
    with CollisionCallbacks, HasGameReference<SpinnerGame> {
  EnemyProjectileComponent({
    required Vector2 position,
    required Vector2 velocity,
    required this.damage,
    this.lifeTime = 4,
  }) : _velocity = velocity,
       super(
         position: position,
         radius: 6,
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0xFFE96A6A),
       );

  final double damage;
  final double lifeTime;

  final Vector2 _velocity;
  double _age = 0;
  bool _resolved = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox(collisionType: CollisionType.active));
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_resolved || game.isWorldFrozen) {
      return;
    }

    _age += dt;
    if (_age >= lifeTime) {
      _resolved = true;
      game.onEnemyProjectileExpired(this);
      return;
    }

    position += _velocity * dt;
    angle += dt * 8;
  }

  @override
  void render(Canvas canvas) {
    // Translate to visual center so the base fill and the inner core both
    // draw on the projectile's actual world position (matches the hitbox).
    canvas.save();
    canvas.translate(radius, radius);

    canvas.drawCircle(Offset.zero, radius, paint);
    final core = Paint()..color = const Color(0xFFFFB5B5);
    canvas.drawCircle(Offset.zero, radius * 0.45, core);

    canvas.restore();
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (_resolved) {
      return;
    }

    if (other is SpinnerComponent) {
      _resolved = true;
      game.onEnemyProjectileHit(this);
      return;
    }

    if (other is WallComponent) {
      _resolved = true;
      game.onEnemyProjectileExpired(this);
    }
  }
}
