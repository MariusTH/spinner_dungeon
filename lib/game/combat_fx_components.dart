import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'spinner_game.dart';

/// Short radial sparks at a hit point (world-space).
class ImpactSparkBurstComponent extends PositionComponent
    with HasGameReference<SpinnerGame> {
  ImpactSparkBurstComponent({
    required Vector2 position,
    required this.intensity,
  }) : super(position: position, anchor: Anchor.center) {
    priority = 80;
  }

  final double intensity;

  static const double _duration = 0.165;

  late double _spawnedAt;
  final List<double> _angles = <double>[];
  final List<double> _speeds = <double>[];
  final Random _rng = Random();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _spawnedAt = game.elapsedSeconds;
    final n = 6 + _rng.nextInt(3);
    for (var i = 0; i < n; i++) {
      _angles.add(_rng.nextDouble() * pi * 2);
      _speeds.add(
        (36 + _rng.nextDouble() * 72) * intensity.clamp(0.6, 1.8),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final age = game.elapsedSeconds - _spawnedAt;
    if (age >= _duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final age = (game.elapsedSeconds - _spawnedAt).clamp(0.0, _duration);
    final t = age / _duration;
    final fade = (1.0 - t).clamp(0.0, 1.0);
    if (fade <= 0.01) {
      return;
    }

    for (var i = 0; i < _angles.length; i++) {
      final dist = _speeds[i] * age;
      final ox = cos(_angles[i]) * dist;
      final oy = sin(_angles[i]) * dist;
      final r = 3.2 + (1.0 - t) * 2.4;
      final paint = Paint()
        ..color = Color.fromARGB(
          (200 * fade).round().clamp(0, 255),
          255,
          (230 - t * 80).round().clamp(0, 255),
          (120 - t * 60).round().clamp(0, 255),
        );
      canvas.drawCircle(Offset(ox, oy), r, paint);
      final core = Paint()
        ..color = Color.fromARGB(
          (255 * fade).round().clamp(0, 255),
          255,
          255,
          240,
        );
      canvas.drawCircle(Offset(ox, oy), r * 0.45, core);
    }
  }
}

/// Comic heavy-hit burst + "KAPOW" label.
class KapowEffectComponent extends PositionComponent
    with HasGameReference<SpinnerGame> {
  KapowEffectComponent({required Vector2 position})
    : super(position: position, anchor: Anchor.center) {
    priority = 90;
  }

  static const double _duration = 0.34;

  late double _spawnedAt;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _spawnedAt = game.elapsedSeconds;
  }

  Path _starPath() {
    const spikes = 10;
    const rOuter = 52.0;
    const rInner = 24.0;
    final path = Path();
    for (var i = 0; i < spikes * 2; i++) {
      final a = (i * pi) / spikes;
      final rad = i.isEven ? rOuter : rInner;
      final x = cos(a) * rad;
      final y = sin(a) * rad;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final age = game.elapsedSeconds - _spawnedAt;
    if (age >= _duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final age = (game.elapsedSeconds - _spawnedAt).clamp(0.0, _duration);
    final t = age / _duration;
    final scale = 0.55 + Curves.easeOutBack.transform(t.clamp(0, 1)) * 0.85;
    final fade = (1.0 - Curves.easeIn.transform(t)).clamp(0.0, 1.0);

    canvas.save();
    canvas.scale(scale);
    canvas.scale(1.0 + sin(t * pi) * 0.06);

    final star = _starPath();
    canvas.drawPath(
      star,
      Paint()
        ..color = const Color(0x66FF6B35)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      star,
      Paint()
        ..color = const Color(0xFFFFD54F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: 'KAPOW!',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..color = const Color(0xFF1A0A4A),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, 8));

    final tpFill = TextPainter(
      text: TextSpan(
        text: 'KAPOW!',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: Color.fromARGB((255 * fade).round(), 255, 240, 120),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpFill.paint(canvas, Offset(-tpFill.width / 2, 8));

    canvas.restore();
  }
}
