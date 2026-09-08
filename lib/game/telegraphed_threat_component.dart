import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

enum TelegraphShape { beam, circle, arc }

/// World-space hazard preview: full outline plus interior fill that grows 0→1
/// over [fillDuration] after optional [startDelay].
class TelegraphedThreatComponent extends PositionComponent
    with HasGameReference<FlameGame> {
  TelegraphedThreatComponent.beam({
    required Vector2 origin,
    required Vector2 direction,
    required this.beamLength,
    required this.beamHalfWidth,
    required this.startDelay,
    required this.fillDuration,
    required this.onComplete,
    required this.canAdvanceTime,
    this.trackMuzzleWorld,
    this.outlineColor = const Color(0xCCFF6B4A),
    this.fillColor = const Color(0x55FF8A5C),
    super.priority,
  }) : shape = TelegraphShape.beam,
       _dir = direction.length2 > 0 ? direction.normalized() : Vector2(1, 0),
       arcRadius = 0,
       arcStartAngle = 0,
       arcSweep = 0,
       super(
         position: origin.clone(),
         anchor: Anchor.centerLeft,
         angle: atan2(direction.y, direction.x),
       );

  TelegraphedThreatComponent.circle({
    required Vector2 center,
    required this.arcRadius,
    required this.startDelay,
    required this.fillDuration,
    required this.onComplete,
    required this.canAdvanceTime,
    this.trackMuzzleWorld,
    this.outlineColor = const Color(0xCCFF6B4A),
    this.fillColor = const Color(0x55FF8A5C),
    super.priority,
  }) : shape = TelegraphShape.circle,
       beamLength = 0,
       beamHalfWidth = 0,
       _dir = Vector2(1, 0),
       arcStartAngle = 0,
       arcSweep = 0,
       super(position: center.clone(), anchor: Anchor.center);

  /// Circular sector (wedge); local +Y is [arcStartAngle] 0 reference — use
  /// [angle] on the component to rotate in world space.
  TelegraphedThreatComponent.arc({
    required Vector2 center,
    required this.arcRadius,
    required this.arcStartAngle,
    required this.arcSweep,
    required this.startDelay,
    required this.fillDuration,
    required this.onComplete,
    required this.canAdvanceTime,
    this.outlineColor = const Color(0xCCFF6B4A),
    this.fillColor = const Color(0x55FF8A5C),
    super.priority,
  }) : shape = TelegraphShape.arc,
       beamLength = 0,
       beamHalfWidth = 0,
       _dir = Vector2(1, 0),
       trackMuzzleWorld = null,
       super(position: center.clone(), anchor: Anchor.center);

  final TelegraphShape shape;
  final double beamLength;
  final double beamHalfWidth;
  final Vector2 _dir;
  final double arcRadius;
  final double arcStartAngle;
  final double arcSweep;

  final double startDelay;
  final double fillDuration;
  final void Function() onComplete;

  /// When false (e.g. world frozen), elapsed time does not advance.
  final bool Function() canAdvanceTime;

  final Color outlineColor;
  final Color fillColor;

  /// When set, [position] follows this each frame (beam: muzzle; circle: center).
  final Vector2 Function()? trackMuzzleWorld;

  double _elapsed = 0;
  bool _fired = false;

  Vector2 get direction => _dir.clone();

  double get _progress {
    if (_elapsed <= startDelay) {
      return 0;
    }
    return ((_elapsed - startDelay) / fillDuration).clamp(0.0, 1.0);
  }

  @override
  void update(double dt) {
    final track = trackMuzzleWorld;
    if (track != null) {
      position.setFrom(track());
    }
    super.update(dt);
    if (_fired) {
      return;
    }
    if (!canAdvanceTime()) {
      return;
    }
    _elapsed += dt;
    if (_elapsed >= startDelay + fillDuration) {
      _fired = true;
      onComplete();
      removeFromParent();
    }
  }

  @override
  void render(ui.Canvas canvas) {
    final p = _progress;
    switch (shape) {
      case TelegraphShape.beam:
        _renderBeam(canvas, p);
      case TelegraphShape.circle:
        _renderCircle(canvas, p);
      case TelegraphShape.arc:
        _renderArc(canvas, p);
    }
  }

  void _renderBeam(ui.Canvas canvas, double progress) {
    final r = Radius.circular(min(6.0, beamHalfWidth * 0.85));
    final full = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, -beamHalfWidth, beamLength, beamHalfWidth * 2),
      r,
    );
    final stroke = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final fillPaint = Paint()..color = fillColor;
    canvas.drawRRect(full, stroke);
    if (progress > 0) {
      final w = max(2.0, beamLength * progress);
      final fillR = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, -beamHalfWidth, w, beamHalfWidth * 2),
        r,
      );
      canvas.drawRRect(fillR, fillPaint);
    }
  }

  void _renderCircle(ui.Canvas canvas, double progress) {
    final outer = Paint()
      ..color = outlineColor.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset.zero, arcRadius * 1.06, outer);
    final stroke = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6;
    final fillPaint = Paint()..color = fillColor;
    canvas.drawCircle(Offset.zero, arcRadius, stroke);
    if (progress > 0) {
      final sweep = -2 * pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: arcRadius),
        -pi / 2,
        sweep,
        true,
        fillPaint,
      );
    }
  }

  void _renderArc(ui.Canvas canvas, double progress) {
    final stroke = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final fillPaint = Paint()..color = fillColor;

    final pathOutline = Path()
      ..moveTo(0, 0)
      ..arcTo(
        Rect.fromCircle(center: Offset.zero, radius: arcRadius),
        arcStartAngle,
        arcSweep,
        false,
      )
      ..close();
    canvas.drawPath(pathOutline, stroke);

    if (progress > 0) {
      final sweep = arcSweep * progress;
      final pathFill = Path()
        ..moveTo(0, 0)
        ..arcTo(
          Rect.fromCircle(center: Offset.zero, radius: arcRadius),
          arcStartAngle,
          sweep,
          false,
        )
        ..close();
      canvas.drawPath(pathFill, fillPaint);
    }
  }
}
