import 'dart:math';

import 'package:flutter/painting.dart';

// agent.md palette. Prop colours are mixes of these, never eyeballed hexes.
const Color _deepVoid = Color(0xFF1A1412);
const Color _shadowStone = Color(0xFF2F2F2F);
const Color _stoneBase = Color(0xFF919090);
const Color _wood = Color(0xFF4F3816);
const Color _emberOrange = Color(0xFFFF6A1F);
const Color _emberYellow = Color(0xFFFFC83B);
const Color _actionYellow = Color(0xFFFFE100);
const Color _chrome = Color(0xFFE8EEF5);
const Color _chromeRed = Color(0xFFC1231C);
const Color _danger = Color(0xFFFF3B30);

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

final Color _propOutline = _mix(_wood, _deepVoid, 0.75);

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round
  ..strokeWidth = width;

/// Top-down treasure chest centred on the origin, [width] × [height].
/// Closed: plank lid with gold bands and a lock on the front edge. Opened:
/// an empty box with the lid lying flipped back behind it.
void paintChest(
  Canvas canvas, {
  required double width,
  required double height,
  required bool opened,
}) {
  final woodLight = _mix(_wood, _emberOrange, 0.3);
  final woodDark = _mix(_wood, _deepVoid, 0.35);
  final band = _emberYellow;
  final outline = _stroke(_propOutline, 2.6);
  final box = Rect.fromCenter(
    center: Offset.zero,
    width: width,
    height: height,
  );
  final boxRRect = RRect.fromRectAndRadius(box, const Radius.circular(5));

  void bands(Rect area) {
    for (final sx in const [-0.3, 0.3]) {
      final r = Rect.fromCenter(
        center: Offset(area.center.dx + sx * area.width, area.center.dy),
        width: area.width * 0.13,
        height: area.height,
      );
      canvas.drawRect(r, Paint()..color = band);
      canvas.drawRect(r, _stroke(_propOutline, 1.2));
    }
  }

  if (opened) {
    // Lid lying flipped back behind the box.
    final lid = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        box.left + 1,
        box.top - height * 0.42,
        box.right - 1,
        box.top + 3,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      lid.shift(const Offset(0, 2.5)),
      Paint()..color = _deepVoid.withValues(alpha: 0.45),
    );
    canvas.drawRRect(lid, Paint()..color = woodDark);
    canvas.save();
    canvas.clipRRect(lid);
    bands(lid.outerRect);
    canvas.restore();
    canvas.drawRRect(lid, outline);
  }

  // Box shadow and body.
  canvas.drawRRect(
    boxRRect.shift(const Offset(0, 3)),
    Paint()..color = _deepVoid.withValues(alpha: 0.45),
  );
  canvas.drawRRect(boxRRect, Paint()..color = woodLight);

  if (opened) {
    // Empty interior with one leftover glint.
    final inner = RRect.fromRectAndRadius(
      box.deflate(width * 0.14),
      const Radius.circular(3),
    );
    canvas.drawRRect(inner, Paint()..color = _mix(_wood, _deepVoid, 0.65));
    canvas.drawRRect(inner, _stroke(_deepVoid.withValues(alpha: 0.5), 2));
    final coin = Offset(
      inner.left + inner.width * 0.7,
      inner.top + inner.height * 0.62,
    );
    canvas.drawCircle(coin, width * 0.07, Paint()..color = _actionYellow);
    canvas.drawCircle(coin, width * 0.07, _stroke(_propOutline, 1.2));
  } else {
    // Three planks running across the lid.
    final plankLine = _stroke(woodDark, 1.6);
    final highlight = _stroke(_mix(woodLight, _emberYellow, 0.35), 1.4);
    for (var i = 0; i < 3; i++) {
      final top = box.top + box.height * i / 3;
      if (i > 0) {
        canvas.drawLine(
          Offset(box.left + 2, top),
          Offset(box.right - 2, top),
          plankLine,
        );
      }
      canvas.drawLine(
        Offset(box.left + 4, top + 2.6),
        Offset(box.left + box.width * 0.45, top + 2.6),
        highlight,
      );
    }
    canvas.save();
    canvas.clipRRect(boxRRect);
    bands(box);
    canvas.restore();

    // Lock plate on the front (bottom) edge.
    final lock = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, box.bottom - height * 0.12),
        width: width * 0.22,
        height: height * 0.3,
      ),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(lock, Paint()..color = band);
    canvas.drawRRect(lock, _stroke(_propOutline, 1.4));
    canvas.drawCircle(
      lock.center.translate(0, -1),
      width * 0.035,
      Paint()..color = _deepVoid,
    );
  }

  canvas.drawRRect(boxRRect, outline);
}

/// Top-down pit of [radius] centred on the origin: a stone rim around a hole
/// that darkens toward its centre.
void paintPit(Canvas canvas, {required double radius}) {
  final rimColor = _mix(_stoneBase, _deepVoid, 0.35);
  final rimR = radius * 1.1;
  final holeR = radius * 0.86;

  canvas.drawCircle(Offset.zero, rimR, Paint()..color = rimColor);
  // Rim stone joints.
  final joint = _stroke(_mix(rimColor, _deepVoid, 0.55), 1.6);
  const stones = 9;
  for (var i = 0; i < stones; i++) {
    final t = i * 2 * pi / stones + 0.3;
    final dir = Offset(cos(t), sin(t));
    canvas.drawLine(dir * holeR, dir * rimR, joint);
  }
  // Light catches the upper-left of the rim.
  canvas.drawArc(
    Rect.fromCircle(center: Offset.zero, radius: (rimR + holeR) / 2),
    pi * 1.05,
    pi * 0.5,
    false,
    _stroke(_mix(rimColor, _chrome, 0.3), 2),
  );

  canvas.drawCircle(
    Offset.zero,
    holeR,
    Paint()
      ..shader = RadialGradient(
        colors: [
          _mix(_deepVoid, Color(0xFF000000), 0.4),
          _deepVoid,
          _shadowStone,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: holeR)),
  );
  // Inner wall shadow cast by the rim.
  canvas.drawCircle(
    Offset.zero,
    holeR - 2,
    _stroke(_deepVoid.withValues(alpha: 0.6), 4),
  );
  canvas.drawCircle(Offset.zero, holeR, _stroke(_propOutline, 2));
  canvas.drawCircle(Offset.zero, rimR, _stroke(_propOutline, 2.6));
}

/// Top-down spike trap of [radius] centred on the origin: a metal plate with
/// a red danger rim and eight chrome spikes pointing outward.
void paintSpikeTrap(Canvas canvas, {required double radius}) {
  final r = radius;
  final outline = _stroke(_propOutline, 1.8);

  canvas.drawCircle(
    const Offset(0, 2.5),
    r * 1.05,
    Paint()..color = _deepVoid.withValues(alpha: 0.45),
  );

  // Spikes: two-tone so each reads as a cone seen from above.
  const count = 8;
  final lit = Paint()..color = _chrome;
  final shade = Paint()..color = _mix(_chrome, _shadowStone, 0.45);
  for (var i = 0; i < count; i++) {
    final t = i * 2 * pi / count;
    final dir = Offset(cos(t), sin(t));
    final side = Offset(-dir.dy, dir.dx);
    final base = dir * (r * 0.45);
    final tip = dir * (r * 1.55);
    final halfW = r * 0.32;
    final left = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(base.dx + side.dx * halfW, base.dy + side.dy * halfW)
      ..lineTo(base.dx, base.dy)
      ..close();
    final right = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(base.dx, base.dy)
      ..lineTo(base.dx - side.dx * halfW, base.dy - side.dy * halfW)
      ..close();
    canvas.drawPath(left, lit);
    canvas.drawPath(right, shade);
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(base.dx + side.dx * halfW, base.dy + side.dy * halfW)
        ..lineTo(base.dx - side.dx * halfW, base.dy - side.dy * halfW)
        ..close(),
      outline,
    );
  }

  // Plate with a clearly bounded danger rim.
  canvas.drawCircle(
    Offset.zero,
    r * 0.7,
    Paint()..color = _mix(_shadowStone, _stoneBase, 0.35),
  );
  canvas.drawCircle(Offset.zero, r * 0.7, _stroke(_danger, 2.4));
  canvas.drawCircle(Offset.zero, r * 0.7 + 1.6, _stroke(_propOutline, 1.4));
  // Hub.
  canvas.drawCircle(Offset.zero, r * 0.42, Paint()..color = _chromeRed);
  canvas.drawCircle(
    Offset(-r * 0.12, -r * 0.12),
    r * 0.14,
    Paint()..color = _mix(_chromeRed, _chrome, 0.6),
  );
  canvas.drawCircle(Offset.zero, r * 0.42, outline);
}
