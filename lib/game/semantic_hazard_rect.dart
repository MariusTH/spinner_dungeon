import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'spinner_component.dart';

/// Rectangular contact damage used by semantic hurt tiles and optional hurt grids.
class SemanticHazardRectComponent extends RectangleComponent with CollisionCallbacks {
  SemanticHazardRectComponent({
    required super.position,
    required super.size,
    required this.damage,
    required this.onDamage,
    required this.isWorldFrozen,
  }) : super(
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0x22FF3B30),
       );

  final double damage;
  final void Function(double damage) onDamage;
  final bool Function() isWorldFrozen;

  double _cooldown = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_cooldown > 0) {
      _cooldown -= dt;
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (_cooldown > 0 || isWorldFrozen()) {
      return;
    }

    if (other is SpinnerComponent) {
      _cooldown = 0.55;
      onDamage(damage);
    }
  }
}
