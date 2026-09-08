import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'spinner_component.dart';
import 'spinner_game.dart';

enum PowerupType { tether, fireball, needles, spinRefill }

extension on PowerupType {
  Color get color {
    switch (this) {
      case PowerupType.tether:
        return const Color(0xFF66D2FF);
      case PowerupType.fireball:
        return const Color(0xFFFF875C);
      case PowerupType.needles:
        return const Color(0xFFA4FFD0);
      case PowerupType.spinRefill:
        return const Color(0xFFFFD54A);
    }
  }

  Color get _accent {
    switch (this) {
      case PowerupType.tether:
        return const Color(0xFFFFFFFF);
      case PowerupType.fireball:
        return const Color(0xFFFFE4B5);
      case PowerupType.needles:
        return const Color(0xFFE9FFF2);
      case PowerupType.spinRefill:
        return const Color(0xFFFFF4B8);
    }
  }

  Color get _deepTint {
    switch (this) {
      case PowerupType.tether:
        return const Color(0xFF0D6FA0);
      case PowerupType.fireball:
        return const Color(0xFFC23D2B);
      case PowerupType.needles:
        return const Color(0xFF1F8F6A);
      case PowerupType.spinRefill:
        return const Color(0xFFB8860B);
    }
  }
}

class PowerupComponent extends CircleComponent
    with CollisionCallbacks, HasGameReference<SpinnerGame> {
  PowerupComponent({
    required this.type,
    required Vector2 position,
    this.durationSeconds = 14,
  }) : super(
         position: position,
         radius: 12,
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0x00000000),
       );

  final PowerupType type;
  final double durationSeconds;

  bool _consumed = false;
  double _age = 0;

  bool get isConsumed => _consumed;
  double get ageSeconds => _age;

  void restoreState({required double ageSeconds, required bool consumed}) {
    _age = ageSeconds.clamp(0, 60).toDouble();
    _consumed = consumed;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_consumed || game.isWorldFrozen) {
      return;
    }

    _age += dt;
    if (_age > 18) {
      removeFromParent();
      return;
    }

    // Component rotation stays zero — the visual spin happens inside render so
    // the bob + rotation can share the same base orientation without tilting
    // the hitbox.
  }

  @override
  void render(Canvas canvas) {
    // Always render centered on the hitbox. CircleComponent's local origin is
    // top-left; translate so Offset.zero is the powerup's world position.
    canvas.save();
    canvas.translate(radius, radius);

    // Procedural floating bob — visual only, not positional. Keeps the orb
    // feeling alive without the component drifting off its spawn point.
    final bob = sin(_age * 3.4) * 2.2;
    canvas.translate(0, bob);

    // Soft drop shadow a few px below the orb grounds it on the floor.
    canvas.save();
    canvas.translate(0, -bob);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, radius * 0.85),
        width: radius * 1.45,
        height: radius * 0.4,
      ),
      Paint()
        ..color = const Color(0x552B0F18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
    );
    canvas.restore();

    // Outer glow halo — always visible in the orb's tint for pickup read.
    canvas.drawCircle(
      Offset.zero,
      radius * 1.45,
      Paint()
        ..color = type.color.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
    );

    // Base orb fill.
    canvas.drawCircle(Offset.zero, radius, Paint()..color = type.color);

    // Gentle belly highlight top-left for volume.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-radius * 0.3, -radius * 0.38),
        width: radius * 0.7,
        height: radius * 0.4,
      ),
      Paint()..color = type._accent.withValues(alpha: 0.68),
    );

    // Orb outline.
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = const Color(0xFF1B1917)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );

    // Per-type decoration rotates with age so the orb reads as "active".
    canvas.save();
    canvas.rotate(_age * 1.8);
    switch (type) {
      case PowerupType.tether:
        _drawTetherDecoration(canvas);
      case PowerupType.fireball:
        _drawFireballDecoration(canvas);
      case PowerupType.needles:
        _drawNeedlesDecoration(canvas);
      case PowerupType.spinRefill:
        _drawSpinRefillDecoration(canvas);
    }
    canvas.restore();

    canvas.restore();
  }

  void _drawTetherDecoration(Canvas canvas) {
    // Concentric rings radiating inward — classic tether/anchor read.
    final ring = Paint()
      ..color = type._deepTint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(Offset.zero, radius * 0.72, ring);
    canvas.drawCircle(Offset.zero, radius * 0.45, ring);
    canvas.drawCircle(
      Offset.zero,
      radius * 0.22,
      Paint()..color = type._accent,
    );
  }

  void _drawFireballDecoration(Canvas canvas) {
    // Three soft flame tongues licking outward — not jagged, rounded thumb
    // style to match the creature language.
    final flame = Paint()..color = type._accent;
    final flameOutline = Paint()
      ..color = type._deepTint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (var i = 0; i < 3; i++) {
      final theta = (pi * 2 * i) / 3;
      final tipX = cos(theta) * radius * 0.85;
      final tipY = sin(theta) * radius * 0.85;
      final path = Path()
        ..moveTo(cos(theta + 0.55) * radius * 0.48, sin(theta + 0.55) * radius * 0.48)
        ..quadraticBezierTo(
          cos(theta) * radius * 0.9,
          sin(theta) * radius * 0.9,
          tipX,
          tipY,
        )
        ..quadraticBezierTo(
          cos(theta - 0.25) * radius * 0.9,
          sin(theta - 0.25) * radius * 0.9,
          cos(theta - 0.55) * radius * 0.48,
          sin(theta - 0.55) * radius * 0.48,
        )
        ..close();
      canvas.drawPath(path, flame);
      canvas.drawPath(path, flameOutline);
    }
    canvas.drawCircle(
      Offset.zero,
      radius * 0.28,
      Paint()..color = type._accent,
    );
  }

  void _drawNeedlesDecoration(Canvas canvas) {
    // Eight stubby triangular spikes — rounded bases, pointed tips.
    final spike = Paint()..color = type._deepTint;
    final outline = Paint()
      ..color = const Color(0xFF1B1917)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    const count = 8;
    for (var i = 0; i < count; i++) {
      final theta = (pi * 2 * i) / count;
      final baseA = Offset(
        cos(theta + 0.22) * radius * 0.62,
        sin(theta + 0.22) * radius * 0.62,
      );
      final baseB = Offset(
        cos(theta - 0.22) * radius * 0.62,
        sin(theta - 0.22) * radius * 0.62,
      );
      final tip = Offset(cos(theta) * radius * 1.02, sin(theta) * radius * 1.02);
      final path = Path()
        ..moveTo(baseA.dx, baseA.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(baseB.dx, baseB.dy)
        ..close();
      canvas.drawPath(path, spike);
      canvas.drawPath(path, outline);
    }
  }

  void _drawSpinRefillDecoration(Canvas canvas) {
    // Swirling arrow motif — two curved tadpole shapes chasing each other.
    final swirl = Paint()..color = type._deepTint;
    final outline = Paint()
      ..color = const Color(0xFF1B1917)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (var i = 0; i < 2; i++) {
      final base = i * pi;
      final path = Path()
        ..moveTo(cos(base) * radius * 0.2, sin(base) * radius * 0.2)
        ..arcToPoint(
          Offset(
            cos(base + pi * 0.9) * radius * 0.68,
            sin(base + pi * 0.9) * radius * 0.68,
          ),
          radius: Radius.circular(radius * 0.62),
          largeArc: false,
        )
        ..lineTo(
          cos(base + pi * 0.9 + 0.22) * radius * 0.5,
          sin(base + pi * 0.9 + 0.22) * radius * 0.5,
        )
        ..arcToPoint(
          Offset(
            cos(base + 0.2) * radius * 0.22,
            sin(base + 0.2) * radius * 0.22,
          ),
          radius: Radius.circular(radius * 0.4),
          largeArc: false,
          clockwise: false,
        )
        ..close();
      canvas.drawPath(path, swirl);
      canvas.drawPath(path, outline);
    }
    canvas.drawCircle(
      Offset.zero,
      radius * 0.16,
      Paint()..color = type._accent,
    );
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (_consumed) {
      return;
    }

    if (other is SpinnerComponent) {
      _consumed = true;
      game.onPowerupCollected(this);
      removeFromParent();
    }
  }
}
