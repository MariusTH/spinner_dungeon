import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class BumperComponent extends CircleComponent with CollisionCallbacks {
  BumperComponent({
    required Vector2 position,
    double radius = 18,
    this.boostMultiplier = 1.18,
    this.controlLossRadians = 0.38,
    this.restitution = 1.06,
  }) : super(
         position: position,
         radius: radius,
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0xFFE6C773),
       );

  final double boostMultiplier;
  final double controlLossRadians;
  final double restitution;

  double _pulseTime = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulseTime += dt;
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(radius, radius);

    final pulse = (sin(_pulseTime * 3.6) + 1) * 0.5;
    final outerPaint = Paint()..color = const Color(0xFFD5A94A);
    final midPaint = Paint()..color = const Color(0xFFE6C773);
    final corePaint = Paint()..color = const Color(0xFFF4E9B7);
    final shadowPaint = Paint()..color = const Color(0x992E1F12);
    final ringPaint = Paint()
      ..color = const Color(0xFF2E1F12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawCircle(Offset(0, radius * 0.07), radius * 0.95, shadowPaint);
    canvas.drawCircle(Offset.zero, radius, outerPaint);
    canvas.drawCircle(Offset.zero, radius * 0.72, midPaint);
    canvas.drawCircle(Offset.zero, radius * (0.32 + pulse * 0.05), corePaint);
    canvas.drawCircle(Offset.zero, radius, ringPaint);
    canvas.drawCircle(Offset.zero, radius * 0.72, ringPaint);

    canvas.restore();
  }
}
