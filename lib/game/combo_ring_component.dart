import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'spinner_game.dart';

// agent.md palette.
const Color _deepVoid = Color(0xFF1A1412);
const Color _emberOrange = Color(0xFFFF6A1F);
const Color _emberYellow = Color(0xFFFFC83B);

/// Diegetic combo HUD: a draining ring around the spinner plus an "xN"
/// count, shown while a kill combo of 2+ is alive. The ring drains only
/// while the spinner rests, which is the cue to fling again.
class ComboRingComponent extends PositionComponent
    with HasGameReference<SpinnerGame> {
  ComboRingComponent() : super(anchor: Anchor.center, priority: 60);

  int _shownCount = -1;
  TextPainter? _label;
  TextPainter? _fill;
  double _pop = 0;

  @override
  void update(double dt) {
    super.update(dt);
    final spinner = game.spinner;
    if (spinner != null) {
      position.setFrom(spinner.position);
    }
    final count = game.comboCount;
    if (count != _shownCount) {
      if (count > _shownCount && count >= 2) {
        _pop = 1;
      }
      _shownCount = count;
      _label = count < 2 ? null : _buildLabel('x$count', outline: true);
      _fill = count < 2 ? null : _buildLabel('x$count', outline: false);
    }
    if (_pop > 0) {
      _pop = max(0, _pop - dt * 5);
    }
  }

  Color get _heatColor => Color.lerp(
    _emberOrange,
    _emberYellow,
    (game.comboCount / 12).clamp(0.0, 1.0),
  )!;

  TextPainter _buildLabel(String text, {required bool outline}) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: outline
            ? TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 4
                  ..color = _deepVoid,
              )
            : TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: _heatColor,
              ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void render(Canvas canvas) {
    final spinner = game.spinner;
    final label = _label;
    final fill = _fill;
    if (spinner == null || label == null || fill == null) {
      return;
    }
    final fraction = game.comboFraction;
    final r = spinner.radius + 16;
    final rect = Rect.fromCircle(center: Offset.zero, radius: r);
    final color = _heatColor;

    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = _deepVoid.withValues(alpha: 0.35),
    );
    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * fraction,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4
        ..color = color,
    );

    final scale = 1 + _pop * 0.5;
    canvas.save();
    canvas.translate(0, -r - 14);
    canvas.scale(scale);
    final offset = Offset(-label.width / 2, -label.height / 2);
    label.paint(canvas, offset);
    fill.paint(canvas, offset);
    canvas.restore();
  }
}
