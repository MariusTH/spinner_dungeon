import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'enemy_component.dart';
import 'spinner_game.dart';
import 'wall_component.dart';

enum SpinnerShotKind { fireball, needle }

class SpinnerShotComponent extends CircleComponent
    with CollisionCallbacks, HasGameReference<SpinnerGame> {
  SpinnerShotComponent.fireball({
    required Vector2 position,
    required Vector2 velocity,
    required this.damage,
  }) : _velocity = velocity,
       kind = SpinnerShotKind.fireball,
       super(
         position: position,
         radius: 6.5,
         anchor: Anchor.center,
         priority: 45,
         paint: Paint()..color = const Color(0xFFFF7A5E),
       );

  SpinnerShotComponent.needle({
    required Vector2 position,
    required Vector2 velocity,
    required this.damage,
  }) : _velocity = velocity,
       kind = SpinnerShotKind.needle,
       super(
         position: position,
         radius: 4.2,
         anchor: Anchor.center,
         priority: 45,
         paint: Paint()..color = const Color(0xFF96FFD1),
       );

  final SpinnerShotKind kind;
  final double damage;
  final Vector2 _velocity;

  double _age = 0;
  bool _resolved = false;

  double get lifeTime => kind == SpinnerShotKind.fireball ? 2.2 : 1.6;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox(collisionType: CollisionType.active));
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_resolved || game.runPhase != RunPhase.playing || game.pausedByMenu) {
      return;
    }

    _age += dt;
    if (_age >= lifeTime) {
      _resolved = true;
      game.onSpinnerShotExpired(this);
      return;
    }

    position += _velocity * dt;
    angle += dt * (kind == SpinnerShotKind.fireball ? 7 : 14);
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(radius, radius);

    if (kind == SpinnerShotKind.fireball) {
      final glow = Paint()..color = const Color(0x66FFA55B);
      final body = Paint()..color = const Color(0xFFFF7A5E);
      final core = Paint()..color = const Color(0xFFFFD2B3);
      canvas.drawCircle(Offset.zero, radius * 1.25, glow);
      canvas.drawCircle(Offset.zero, radius, body);
      canvas.drawCircle(Offset.zero, radius * 0.45, core);
      canvas.drawCircle(
        const Offset(-1.0, -1.4),
        radius * 0.18,
        Paint()..color = const Color(0xAAFFFFFF),
      );
      canvas.restore();
      return;
    }

    final shaft = Paint()
      ..color = const Color(0xFF1D6B53)
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round;
    final tip = Paint()..color = const Color(0xFFE0FFF2);
    canvas.drawLine(Offset(-radius * 1.05, 0), Offset(radius * 1.05, 0), shaft);
    canvas.drawCircle(Offset(radius * 1.12, 0), radius * 0.42, tip);
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

    if (other is EnemyComponent && !other.isDead) {
      _resolved = true;
      game.onSpinnerShotHit(this, other);
      return;
    }

    if (other is WallComponent) {
      _resolved = true;
      game.onSpinnerShotExpired(this);
    }
  }
}
