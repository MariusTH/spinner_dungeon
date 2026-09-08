import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'spinner_game.dart';

class TetherLinkComponent extends PositionComponent
    with HasGameReference<SpinnerGame> {
  TetherLinkComponent()
    : super(position: Vector2.zero(), anchor: Anchor.topLeft, priority: 90);

  @override
  void render(Canvas canvas) {
    final start = game.tetherLineStart;
    final end = game.tetherLineEnd;
    if (!game.tetherActive || start == null || end == null) {
      return;
    }

    final delta = end - start;
    if (delta.length2 <= 16) {
      return;
    }

    final pulse = (sin(game.elapsedSeconds * 16) + 1) * 0.5;
    final glowPaint = Paint()
      ..color = Color.fromARGB((42 + 46 * pulse).toInt(), 98, 220, 255)
      ..strokeWidth = 7.2 + pulse * 2.4
      ..strokeCap = StrokeCap.round;
    final beamPaint = Paint()
      ..color = Color.fromARGB((150 + 92 * pulse).toInt(), 172, 242, 255)
      ..strokeWidth = 2.5 + pulse * 0.9
      ..strokeCap = StrokeCap.round;

    final startOffset = Offset(start.x, start.y);
    final endOffset = Offset(end.x, end.y);
    canvas.drawLine(startOffset, endOffset, glowPaint);
    canvas.drawLine(startOffset, endOffset, beamPaint);

    final direction = delta.normalized();
    final perpendicular = Vector2(-direction.y, direction.x);
    final tip = end - direction * 6;
    final wingA = tip - direction * 9 + perpendicular * 4;
    final wingB = tip - direction * 9 - perpendicular * 4;
    final tipPaint = Paint()
      ..color = Color.fromARGB((180 + 70 * pulse).toInt(), 196, 250, 255)
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(wingA.x, wingA.y), Offset(tip.x, tip.y), tipPaint);
    canvas.drawLine(Offset(wingB.x, wingB.y), Offset(tip.x, tip.y), tipPaint);
  }
}
