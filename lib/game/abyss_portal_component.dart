import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'spinner_game.dart';

// agent.md palette.
const Color _deepVoid = Color(0xFF1A1412);
const Color _emberOrange = Color(0xFFFF6A1F);
const Color _emberYellow = Color(0xFFFFC83B);
const Color _coolShadow = Color(0xFF27367B);

/// The way down: opens on a cleared floor. Flinging the spinner into it
/// descends to the next floor. A swirling hole with ember rims and rings
/// that sink toward the centre.
class AbyssPortalComponent extends PositionComponent
    with HasGameReference<SpinnerGame> {
  AbyssPortalComponent({required Vector2 position, this.radius = 46})
    : super(position: position, anchor: Anchor.center, priority: -60);

  final double radius;
  double _age = 0;
  bool _entered = false;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_entered) {
      return;
    }
    final spinner = game.spinner;
    // Only armed once fully open, so it can't swallow the spinner instantly.
    if (spinner == null || _age < 0.6) {
      return;
    }
    if (spinner.position.distanceTo(position) < radius * 0.75) {
      _entered = true;
      game.onSpinnerEnteredAbyss();
    }
  }

  @override
  void render(Canvas canvas) {
    final open = Curves.easeOutBack.transform((_age / 0.6).clamp(0.0, 1.0));
    final r = radius * open;
    if (r <= 0.5) {
      return;
    }

    // Outer glow and ember rim.
    canvas.drawCircle(
      Offset.zero,
      r * 1.35,
      Paint()
        ..color = _emberOrange.withValues(alpha: 0.18 + 0.08 * sin(_age * 3))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(Offset.zero, r * 1.08, Paint()..color = _emberOrange);
    canvas.drawCircle(Offset.zero, r, Paint()..color = _deepVoid);

    // Rings sinking toward the centre.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (var i = 0; i < 4; i++) {
      final phase = ((_age * 0.55 + i / 4) % 1.0);
      final rr = r * (1 - phase) * 0.95;
      ring.color = Color.lerp(
        _emberYellow,
        _coolShadow,
        phase,
      )!.withValues(alpha: (1 - phase) * 0.8);
      canvas.drawCircle(Offset.zero, rr, ring);
    }

    // Swirl arms.
    final arm = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4
      ..color = _emberOrange.withValues(alpha: 0.75);
    for (var i = 0; i < 3; i++) {
      final start = _age * 2.4 + i * 2 * pi / 3;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: r * 0.62),
        start,
        pi * 0.5,
        false,
        arm,
      );
    }

    canvas.drawCircle(
      Offset.zero,
      r * 1.08,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = _deepVoid,
    );
  }
}
