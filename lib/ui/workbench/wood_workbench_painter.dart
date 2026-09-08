import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'workbench_palette.dart';

/// Top-down wooden bench slab with chunky grain lines (procedural, no assets).
class WoodWorkbenchPainter extends CustomPainter {
  WoodWorkbenchPainter({this.cornerRadius = 18});

  final double cornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(cornerRadius),
    );

    final drop = Paint()
      ..color = Colors.black.withValues(alpha: 0.32)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.save();
    canvas.translate(0, 5);
    canvas.drawRRect(rrect, drop);
    canvas.restore();

    final base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          WorkbenchPalette.woodLight.withValues(alpha: 0.98),
          WorkbenchPalette.wood,
          WorkbenchPalette.woodDark,
        ],
      ).createShader(rect);

    canvas.drawRRect(rrect, base);

    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = WorkbenchPalette.woodEdge;
    canvas.drawRRect(rrect, edge);

    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final random = math.Random(42);
    for (var i = 0; i < 28; i++) {
      final y = size.height * (0.08 + random.nextDouble() * 0.84);
      final wobble = random.nextDouble() * 6 - 3;
      grain.color = WorkbenchPalette.woodDark.withValues(
        alpha: 0.12 + random.nextDouble() * 0.14,
      );
      final path = Path()
        ..moveTo(8, y)
        ..quadraticBezierTo(
          size.width * 0.5,
          y + wobble,
          size.width - 8,
          y - wobble * 0.5,
        );
      canvas.drawPath(path, grain);
    }
  }

  @override
  bool shouldRepaint(covariant WoodWorkbenchPainter oldDelegate) =>
      oldDelegate.cornerRadius != cornerRadius;
}
