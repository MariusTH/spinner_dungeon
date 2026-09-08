import 'dart:math';
import 'dart:ui';

import 'package:flutter/painting.dart';

/// Soft-vector "thumb-design" creature rendering.
///
/// This module replaces per-creature pixel sprites with procedural Canvas
/// drawings. Each silhouette is built from primitives (circles, rounded
/// paths, ovals with squash) and renders identically at any zoom — no
/// per-angle sprite sheets, no asset pipeline.
///
/// Facing is handled via a true 8-direction snap: the body itself does NOT
/// rotate (which is what gave the old sprites their "sliding on its belly"
/// look); instead, face elements (eyes, antennae, scanner) shift toward the
/// snapped facing direction. This gives creatures distinct poses for each
/// octant without requiring 8 hand-drawn sprites.
enum CreatureSilhouette {
  /// Walker enemy — pill-shaped dungeon bug with stubby legs.
  walkerBug,

  /// Pulser enemy — round mushroom thumb with polka-dot body.
  pulserCap,

  /// Turret enemy — squat dome with a single tracking eye-scanner.
  turretEye,

  /// Boss — big round warden with chunky shoulders and a rune eye.
  bossGolem,

  /// Paddle — long rounded wooden plank hazard with a cranky face on the
  /// leading end. This silhouette intentionally draws the plank as a rotated
  /// RRect so it reads as a swept hazard; callers are expected to already
  /// have the canvas rotated to the paddle's heading angle.
  paddlePlank,

  /// Hedgehog — round thumb body with soft triangular spikes around the
  /// perimeter and a cute face pointing at its leading octant.
  hedgehogSpiky,
}

/// Flat-color palette for a single creature. Keep zones to 4–5 to preserve
/// the "soft vector" look (no gradients, no texture noise).
class CreaturePalette {
  const CreaturePalette({
    required this.body,
    required this.bodyShadow,
    required this.belly,
    required this.accent,
    required this.eye,
    this.outline = const Color(0xFF1B1917),
  });

  /// Main body fill.
  final Color body;

  /// Ground shadow underneath (usually a translucent dark oval).
  final Color bodyShadow;

  /// Lighter underside / belly zone for dimension.
  final Color belly;

  /// Spots, stripes, or secondary body detail color.
  final Color accent;

  /// Eye / sclera fill.
  final Color eye;

  /// Dark outline for silhouette pop — DB32-style thin dark line.
  final Color outline;
}

/// Per-frame render inputs for a creature. Computed by the enemy each tick
/// and fed to [CreatureRenderer.render].
class CreatureRenderState {
  const CreatureRenderState({
    required this.radius,
    required this.facingAngle,
    this.idleBreathPhase = 0,
    this.damageFlashStrength = 0,
    this.telegraphPulse = 0,
    this.alert = false,
    this.spikeAxisAngle,
  });

  /// Collision / visual radius — sets the creature's overall size.
  final double radius;

  /// UN-snapped angle (radians) pointing from the creature TOWARD its
  /// target. The renderer will snap this to the nearest 45° for face
  /// element placement.
  final double facingAngle;

  /// 0..2π smooth phase used for subtle idle "breathing" squash-stretch.
  final double idleBreathPhase;

  /// 0..1 — how recently the creature was hit. Blends a flash highlight
  /// into the body.
  final double damageFlashStrength;

  /// 0..1 — used for telegraph glows (e.g., pulser about to burst, turret
  /// about to fire).
  final double telegraphPulse;

  /// Whether the creature has "spotted" the spinner. Pops eye size up.
  final bool alert;

  /// Optional — the angle (radians) of a creature's defensive axis,
  /// independent of [facingAngle]. Currently used by the hedgehog to
  /// place its spike clusters on a fixed patrol axis (horizontal or
  /// vertical) while [facingAngle] tracks the current direction of
  /// travel for the face.
  final double? spikeAxisAngle;
}

/// Static renderer for all creature silhouettes. The canvas is expected to
/// be pre-translated so that `Offset.zero` is the creature's visual center.
class CreatureRenderer {
  CreatureRenderer._();

  static const double _octantStep = pi / 4;

  /// Snaps an angle to the nearest 45° — the core of the 8-direction feel.
  static double snapTo8(double angle) {
    return (angle / _octantStep).round() * _octantStep;
  }

  static void render(
    Canvas canvas,
    CreatureSilhouette silhouette,
    CreaturePalette palette,
    CreatureRenderState state,
  ) {
    switch (silhouette) {
      case CreatureSilhouette.walkerBug:
        _drawWalkerBug(canvas, palette, state);
      case CreatureSilhouette.pulserCap:
        _drawPulserCap(canvas, palette, state);
      case CreatureSilhouette.turretEye:
        _drawTurretEye(canvas, palette, state);
      case CreatureSilhouette.bossGolem:
        _drawBossGolem(canvas, palette, state);
      case CreatureSilhouette.paddlePlank:
        _drawPaddlePlank(canvas, palette, state);
      case CreatureSilhouette.hedgehogSpiky:
        _drawHedgehogSpiky(canvas, palette, state);
    }
  }

  // ---------------------------------------------------------------------------
  // Shared primitives

  /// Soft blurred drop-shadow oval under the creature. Grounds it on the
  /// floor without needing ambient occlusion.
  static void _drawGroundShadow(
    Canvas canvas,
    CreaturePalette palette,
    double radius, {
    double widthMul = 1.7,
    double heightMul = 0.42,
    double yOffset = 0.85,
  }) {
    final shadow = Paint()
      ..color = palette.bodyShadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, radius * yOffset),
        width: radius * widthMul,
        height: radius * heightMul,
      ),
      shadow,
    );
  }

  /// Two round eyes placed at a 2D offset toward the snapped facing, with
  /// a small separation perpendicular to facing. Used by most creatures.
  static void _drawFacingEyes(
    Canvas canvas,
    CreaturePalette palette, {
    required double radius,
    required double snappedAngle,
    double forwardOffset = 0.32,
    double sideOffset = 0.22,
    double eyeRadius = 0.14,
    double pupilRadius = 0.07,
    bool alert = false,
  }) {
    final fx = cos(snappedAngle);
    final fy = sin(snappedAngle);
    // Perpendicular vector for eye separation.
    final px = -fy;
    final py = fx;

    final forward = Offset(fx * radius * forwardOffset, fy * radius * forwardOffset);
    final sideA = Offset(px * radius * sideOffset, py * radius * sideOffset);
    final eyeR = radius * eyeRadius * (alert ? 1.18 : 1.0);
    final pupilR = radius * pupilRadius * (alert ? 1.1 : 1.0);

    final eyeWhite = Paint()..color = palette.eye;
    final pupil = Paint()..color = palette.outline;
    final shine = Paint()..color = const Color(0xCCFFFFFF);
    final lid = Paint()
      ..color = palette.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final side in <Offset>[sideA, -sideA]) {
      final center = forward + side;
      canvas.drawCircle(center, eyeR, eyeWhite);
      canvas.drawCircle(center, eyeR, lid);
      // Pupil shifted slightly further toward the facing direction so the
      // creature visibly "looks at" the target, not just "faces" it.
      final pupilCenter = center + Offset(fx, fy) * (eyeR * 0.35);
      canvas.drawCircle(pupilCenter, pupilR, pupil);
      // Tiny specular highlight for life.
      canvas.drawCircle(
        pupilCenter - Offset(fx, fy) * (pupilR * 0.5) - const Offset(0.8, 0.8),
        pupilR * 0.45,
        shine,
      );
    }
  }

  /// Applies a translucent flash overlay across the provided path, used on
  /// hit to sell damage without replacing the palette.
  static void _maybeApplyDamageFlash(
    Canvas canvas,
    Path bodyPath,
    double strength,
  ) {
    if (strength <= 0) {
      return;
    }
    final alpha = (210 * strength.clamp(0.0, 1.0)).round();
    final flash = Paint()..color = Color.fromARGB(alpha, 255, 235, 200);
    canvas.drawPath(bodyPath, flash);
  }

  // ---------------------------------------------------------------------------
  // Walker bug

  static void _drawWalkerBug(
    Canvas canvas,
    CreaturePalette palette,
    CreatureRenderState state,
  ) {
    final r = state.radius;
    final snapped = snapTo8(state.facingAngle);
    final fx = cos(snapped);
    final fy = sin(snapped);

    // Idle breath = subtle uniform body scale oscillation.
    final breath = 1.0 + sin(state.idleBreathPhase) * 0.035;

    _drawGroundShadow(canvas, palette, r, widthMul: 1.8, heightMul: 0.5);

    // Body is an oval slightly squashed perpendicular to facing, so the bug
    // visibly "points" in its direction without the entire sprite rotating.
    canvas.save();
    canvas.rotate(snapped);
    final bodyWidth = r * 1.55 * breath;
    final bodyHeight = r * 1.25 * breath;
    final bodyRect = Rect.fromCenter(
      center: Offset.zero,
      width: bodyWidth,
      height: bodyHeight,
    );

    final body = Paint()..color = palette.body;
    final outlinePaint = Paint()
      ..color = palette.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08;

    // Six stubby legs — three per side. Drawn in body-local frame so they
    // step-snap with the body to the facing octant.
    final legPaint = Paint()..color = palette.outline;
    for (var i = -1; i <= 1; i++) {
      final xOff = bodyWidth * 0.28 * i;
      for (final ySign in <double>[-1, 1]) {
        final footY = ySign * (bodyHeight * 0.52);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(xOff, footY),
            width: r * 0.22,
            height: r * 0.36,
          ),
          legPaint,
        );
      }
    }

    final bodyPath = Path()..addOval(bodyRect);
    canvas.drawPath(bodyPath, body);

    // Belly stripe — lighter band along the front half to give dimension.
    final bellyRect = Rect.fromLTWH(
      -bodyWidth * 0.46,
      -bodyHeight * 0.1,
      bodyWidth * 0.92,
      bodyHeight * 0.35,
    );
    canvas.drawOval(bellyRect, Paint()..color = palette.belly);

    // Accent dots (3) along the centerline give the bug its carapace feel.
    final accent = Paint()..color = palette.accent;
    for (var i = -1; i <= 1; i++) {
      canvas.drawCircle(
        Offset(bodyWidth * 0.2 * i, -bodyHeight * 0.05),
        r * 0.095,
        accent,
      );
    }

    canvas.drawPath(bodyPath, outlinePaint);
    _maybeApplyDamageFlash(canvas, bodyPath, state.damageFlashStrength);
    canvas.restore();

    // Antennae + eyes live in world-aligned space (we already rotated/unrotated
    // the body). Eyes shift toward facing direction.
    final antennaPaint = Paint()
      ..color = palette.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.07
      ..strokeCap = StrokeCap.round;
    final tipPaint = Paint()..color = palette.accent;
    for (final sign in <double>[-1, 1]) {
      // Antenna roots are near the leading edge of the body.
      final rootX = fx * r * 0.55 + (-fy) * r * 0.18 * sign;
      final rootY = fy * r * 0.55 + (fx) * r * 0.18 * sign;
      final tipX = rootX + fx * r * 0.45 + (-fy) * r * 0.22 * sign;
      final tipY = rootY + fy * r * 0.45 + (fx) * r * 0.22 * sign;
      canvas.drawLine(Offset(rootX, rootY), Offset(tipX, tipY), antennaPaint);
      canvas.drawCircle(Offset(tipX, tipY), r * 0.08, tipPaint);
    }

    _drawFacingEyes(
      canvas,
      palette,
      radius: r,
      snappedAngle: snapped,
      forwardOffset: 0.24,
      sideOffset: 0.26,
      eyeRadius: 0.15,
      pupilRadius: 0.07,
      alert: state.alert,
    );
  }

  // ---------------------------------------------------------------------------
  // Pulser mushroom

  static void _drawPulserCap(
    Canvas canvas,
    CreaturePalette palette,
    CreatureRenderState state,
  ) {
    final r = state.radius;
    final snapped = snapTo8(state.facingAngle);

    // Pulse phase drives both the telegraph ring and a subtle body pulse.
    final pulse = state.telegraphPulse;
    final bodyPulse = 1.0 + pulse * 0.12 + sin(state.idleBreathPhase) * 0.025;

    // Outward-spreading telegraph ring that fades.
    if (pulse > 0.01) {
      final ringPaint = Paint()
        ..color = palette.accent.withValues(alpha: (1 - pulse).clamp(0.0, 1.0) * 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12 * (1 - pulse * 0.5);
      canvas.drawCircle(
        Offset.zero,
        r * (1.05 + pulse * 0.9),
        ringPaint,
      );
    }

    _drawGroundShadow(canvas, palette, r, widthMul: 1.55, heightMul: 0.45);

    final bodyRadius = r * 1.0 * bodyPulse;
    final bodyRect = Rect.fromCircle(center: Offset.zero, radius: bodyRadius);
    final bodyPath = Path()..addOval(bodyRect);

    canvas.drawPath(bodyPath, Paint()..color = palette.body);

    // Mushroom polka dots — scatter deterministic pattern on top half.
    final dotPaint = Paint()..color = palette.accent;
    const dots = <Offset>[
      Offset(-0.42, -0.38),
      Offset(0.18, -0.55),
      Offset(0.48, -0.22),
      Offset(-0.14, -0.18),
      Offset(-0.56, 0.04),
      Offset(0.34, 0.08),
    ];
    for (final d in dots) {
      final dx = d.dx * bodyRadius;
      final dy = d.dy * bodyRadius;
      canvas.drawCircle(Offset(dx, dy), bodyRadius * 0.14, dotPaint);
    }

    // Belly crescent — lighter area at the bottom half for volume.
    final bellyPath = Path()
      ..moveTo(-bodyRadius * 0.82, bodyRadius * 0.1)
      ..quadraticBezierTo(
        0,
        bodyRadius * 1.15,
        bodyRadius * 0.82,
        bodyRadius * 0.1,
      )
      ..close();
    canvas.drawPath(bellyPath, Paint()..color = palette.belly);

    // Outline + damage flash go on the final composited body silhouette.
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = palette.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09,
    );
    _maybeApplyDamageFlash(canvas, bodyPath, state.damageFlashStrength);

    // Tiny mouth — a small arc centered below the eyes.
    final mouthCenter = Offset(
      cos(snapped) * r * 0.18,
      sin(snapped) * r * 0.18 + r * 0.18,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: mouthCenter,
        width: r * 0.3,
        height: r * 0.22,
      ),
      0,
      pi,
      false,
      Paint()
        ..color = palette.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06
        ..strokeCap = StrokeCap.round,
    );

    _drawFacingEyes(
      canvas,
      palette,
      radius: r,
      snappedAngle: snapped,
      forwardOffset: 0.14,
      sideOffset: 0.28,
      eyeRadius: 0.17,
      pupilRadius: 0.08,
      alert: state.alert,
    );
  }

  // ---------------------------------------------------------------------------
  // Turret eye

  static void _drawTurretEye(
    Canvas canvas,
    CreaturePalette palette,
    CreatureRenderState state,
  ) {
    final r = state.radius;
    final snapped = snapTo8(state.facingAngle);

    _drawGroundShadow(canvas, palette, r, widthMul: 1.9, heightMul: 0.4);

    // Squat dome base — wider at bottom, tapering up. Two rounded rectangles
    // stacked give a cute chunky bunker feel without being "mechanical cold".
    final basePath = Path();
    final baseRect = RRect.fromLTRBR(
      -r * 0.95,
      -r * 0.15,
      r * 0.95,
      r * 0.9,
      Radius.circular(r * 0.45),
    );
    basePath.addRRect(baseRect);
    canvas.drawPath(basePath, Paint()..color = palette.body);

    // Armor band — a darker horizontal stripe for "plating".
    canvas.drawRRect(
      RRect.fromLTRBR(
        -r * 0.85,
        r * 0.22,
        r * 0.85,
        r * 0.44,
        Radius.circular(r * 0.12),
      ),
      Paint()..color = palette.bodyShadow,
    );

    // Three bolts along the band for extra texture.
    for (var i = -1; i <= 1; i++) {
      canvas.drawCircle(
        Offset(i * r * 0.48, r * 0.33),
        r * 0.06,
        Paint()..color = palette.accent,
      );
    }

    // Dome top — a chunky rounded cap that sits above the base.
    final dome = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(0, -r * 0.25),
        width: r * 1.65,
        height: r * 1.1,
      ));
    canvas.drawPath(dome, Paint()..color = palette.body);
    canvas.drawPath(dome, Paint()
      ..color = palette.belly
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.srcOver);
    // Highlight band on the dome's upper-left gives volume.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-r * 0.28, -r * 0.55),
        width: r * 0.7,
        height: r * 0.25,
      ),
      Paint()..color = palette.belly,
    );

    // Outline the whole silhouette in dark for pop.
    final outline = Paint()
      ..color = palette.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.09;
    canvas.drawPath(basePath, outline);
    canvas.drawPath(dome, outline);

    // Single large "eye scanner" that steps to one of 8 positions around the
    // dome's equator. This is what "8-dir" looks like on a turret — the eye
    // moves, the body doesn't rotate.
    final eyeCenter = Offset(
      cos(snapped) * r * 0.62,
      sin(snapped) * r * 0.62 - r * 0.15,
    );
    // Glow base behind the eye.
    final glowStrength = 0.4 + state.telegraphPulse * 0.6;
    canvas.drawCircle(
      eyeCenter,
      r * 0.32,
      Paint()
        ..color = palette.accent.withValues(alpha: 0.35 * glowStrength)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2),
    );
    // Eye socket (dark).
    canvas.drawCircle(eyeCenter, r * 0.22, Paint()..color = palette.outline);
    // Iris — accent color, grows with telegraphPulse.
    final irisR = r * (0.14 + state.telegraphPulse * 0.04);
    canvas.drawCircle(eyeCenter, irisR, Paint()..color = palette.accent);
    // Pupil — pulsing black dot at the iris center.
    canvas.drawCircle(
      eyeCenter,
      irisR * 0.42,
      Paint()..color = palette.outline,
    );
    // Shine spot on the iris.
    canvas.drawCircle(
      eyeCenter + Offset(-irisR * 0.4, -irisR * 0.4),
      irisR * 0.3,
      Paint()..color = const Color(0xCCFFFFFF),
    );

    // Damage flash applied across base+dome silhouette.
    final silhouette = Path.combine(PathOperation.union, basePath, dome);
    _maybeApplyDamageFlash(canvas, silhouette, state.damageFlashStrength);
  }

  // ---------------------------------------------------------------------------
  // Boss golem
  //
  // Reads as the dungeon Warden: chunky round body, heavy shoulder pauldrons,
  // and a single glowing rune eye that tracks the player. Telegraph pulse
  // drives a rising glow around the eye (wind-up for slams).

  static void _drawBossGolem(
    Canvas canvas,
    CreaturePalette palette,
    CreatureRenderState state,
  ) {
    final r = state.radius;
    final snapped = snapTo8(state.facingAngle);
    final fx = cos(snapped);
    final fy = sin(snapped);
    final breath = 1.0 + sin(state.idleBreathPhase * 0.6) * 0.03;

    _drawGroundShadow(canvas, palette, r, widthMul: 2.1, heightMul: 0.52);

    final bodyR = r * 1.05 * breath;

    // Chunky pauldrons — two overlapping circles on either side of the body.
    final shoulderOffset = Offset(-fy, fx) * (r * 0.78);
    final shoulderShadow = Paint()..color = palette.bodyShadow;
    final shoulder = Paint()..color = palette.body;
    canvas.drawCircle(shoulderOffset, r * 0.55, shoulderShadow);
    canvas.drawCircle(-shoulderOffset, r * 0.55, shoulderShadow);
    canvas.drawCircle(shoulderOffset, r * 0.5, shoulder);
    canvas.drawCircle(-shoulderOffset, r * 0.5, shoulder);

    // Main body — a big round core.
    final bodyPath = Path()
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: bodyR));
    canvas.drawPath(bodyPath, Paint()..color = palette.body);

    // Belly plate — a lighter dome across the upper half that reads as armor.
    final bellyPath = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(fx * r * 0.1, fy * r * 0.1),
          width: bodyR * 1.4,
          height: bodyR * 0.95,
        ),
      );
    canvas.drawPath(
      Path.combine(PathOperation.intersect, bodyPath, bellyPath),
      Paint()..color = palette.belly,
    );

    // Cracked accent runes — three small diamonds along the belt line for
    // that "etched ancient warden" read.
    final accent = Paint()..color = palette.accent;
    for (var i = -1; i <= 1; i++) {
      final ox = -fy * i * r * 0.45;
      final oy = fx * i * r * 0.45;
      final diamond = Path()
        ..moveTo(ox, oy - r * 0.09)
        ..lineTo(ox + r * 0.07, oy)
        ..lineTo(ox, oy + r * 0.09)
        ..lineTo(ox - r * 0.07, oy)
        ..close();
      canvas.drawPath(diamond, accent);
    }

    // Outline everything for silhouette pop.
    final outline = Paint()
      ..color = palette.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.1;
    canvas.drawCircle(shoulderOffset, r * 0.5, outline);
    canvas.drawCircle(-shoulderOffset, r * 0.5, outline);
    canvas.drawPath(bodyPath, outline);

    _maybeApplyDamageFlash(canvas, bodyPath, state.damageFlashStrength);

    // Rune eye — single large glowing eye at the forward edge of the body.
    final eyeCenter = Offset(fx * bodyR * 0.55, fy * bodyR * 0.55);
    final glow = 0.35 + state.telegraphPulse * 0.65;
    canvas.drawCircle(
      eyeCenter,
      r * 0.45,
      Paint()
        ..color = palette.accent.withValues(alpha: 0.28 * glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5),
    );
    canvas.drawCircle(eyeCenter, r * 0.26, Paint()..color = palette.outline);
    final irisR = r * (0.18 + state.telegraphPulse * 0.05);
    canvas.drawCircle(eyeCenter, irisR, Paint()..color = palette.accent);
    canvas.drawCircle(
      eyeCenter,
      irisR * 0.45,
      Paint()..color = palette.outline,
    );
    canvas.drawCircle(
      eyeCenter + Offset(-irisR * 0.38, -irisR * 0.38),
      irisR * 0.28,
      Paint()..color = const Color(0xDDFFFFFF),
    );
  }

  // ---------------------------------------------------------------------------
  // Paddle plank
  //
  // Wooden plank with a grumpy face on the leading end. The caller is
  // expected to have already rotated the canvas to the plank's heading
  // angle, so "forward" is +X in the local frame. facingAngle is used only
  // for a micro expression tilt.

  static void _drawPaddlePlank(
    Canvas canvas,
    CreaturePalette palette,
    CreatureRenderState state,
  ) {
    final r = state.radius;
    final breath = 1.0 + sin(state.idleBreathPhase * 1.4) * 0.025;

    _drawGroundShadow(canvas, palette, r, widthMul: 3.4, heightMul: 0.35);

    // Plank body — long rounded rectangle along X (the caller rotated the
    // canvas so "along X" = the plank's heading).
    final plankRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: r * 3.0 * breath,
        height: r * 1.0,
      ),
      Radius.circular(r * 0.4),
    );
    final bodyPath = Path()..addRRect(plankRect);
    canvas.drawPath(bodyPath, Paint()..color = palette.body);

    // Belly stripe — a lighter band along the middle horizontal.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: r * 2.8,
          height: r * 0.32,
        ),
        Radius.circular(r * 0.16),
      ),
      Paint()..color = palette.belly,
    );

    // Wood-grain accent dashes scattered along the plank.
    final grain = Paint()
      ..color = palette.accent.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.07;
    for (var i = -2; i <= 2; i++) {
      if (i == 0) continue;
      canvas.drawLine(
        Offset(i * r * 0.52, -r * 0.12),
        Offset(i * r * 0.52 + r * 0.18, -r * 0.12),
        grain,
      );
    }

    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = palette.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09,
    );

    _maybeApplyDamageFlash(canvas, bodyPath, state.damageFlashStrength);

    // Grumpy face on the +X leading end.
    final faceCenter = Offset(r * 1.15, 0);
    // Two half-lidded eyes with a tiny perpendicular gap.
    final eyeWhite = Paint()..color = palette.eye;
    final eyeOutline = Paint()
      ..color = palette.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.06;
    for (final dy in <double>[-r * 0.2, r * 0.2]) {
      final c = faceCenter + Offset(0, dy);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: r * 0.3, height: r * 0.22),
        eyeWhite,
      );
      canvas.drawOval(
        Rect.fromCenter(center: c, width: r * 0.3, height: r * 0.22),
        eyeOutline,
      );
      canvas.drawCircle(
        c + const Offset(1.2, 0),
        r * 0.06,
        Paint()..color = palette.outline,
      );
    }
    // Angry eyebrow — single thick V across the forehead.
    final brow = Path()
      ..moveTo(faceCenter.dx - r * 0.28, -r * 0.42)
      ..lineTo(faceCenter.dx, -r * 0.3)
      ..lineTo(faceCenter.dx + r * 0.28, -r * 0.42);
    canvas.drawPath(
      brow,
      Paint()
        ..color = palette.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  // ---------------------------------------------------------------------------
  // Hedgehog spiky
  //
  // Hedgehog — asymmetric defensive silhouette. Spikes are clustered at
  // BOTH ends of the patrol axis (front + back) while the two
  // perpendicular sides are exposed soft belly — the "hit me here" zones
  // the player learns to target. Eyes/nose still track the current
  // direction of travel via `facingAngle` so the player can read which
  // way the hedgehog is currently moving.

  static void _drawHedgehogSpiky(
    Canvas canvas,
    CreaturePalette palette,
    CreatureRenderState state,
  ) {
    final r = state.radius;
    // Spike placement uses the patrol axis, not the live facing. That
    // keeps the armor/weak layout static while the hedgehog reverses,
    // preventing the spikes from sweeping across the player's strike
    // window during a turn-around.
    final axisAngle = state.spikeAxisAngle ?? snapTo8(state.facingAngle);
    final faceAngle = snapTo8(state.facingAngle);
    final fx = cos(faceAngle);
    final fy = sin(faceAngle);
    final perpX = -sin(axisAngle);
    final perpY = cos(axisAngle);
    final breath = 1.0 + sin(state.idleBreathPhase) * 0.035;

    _drawGroundShadow(canvas, palette, r, widthMul: 1.9, heightMul: 0.46);

    final bodyR = r * 0.92 * breath;

    // --- Spike clusters on the patrol-axis ends ---------------------------
    // Only draw a spike when the spike's angle falls within ±45° of the
    // patrol axis. Tapered length (longer near the axis, shorter near the
    // transition to the weak zone) gives the "two tufts of quills" look.
    final spikeFill = Paint()..color = palette.bodyShadow;
    final spikeOutline = Paint()
      ..color = palette.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.055;
    const spikeCount = 22;
    const spikeCosThreshold = 0.707; // cos(45°)
    final spikeExtra = r * 0.32 * (0.7 + state.telegraphPulse * 0.3);
    for (var i = 0; i < spikeCount; i++) {
      final theta = (pi * 2 * i) / spikeCount;
      final axisAlignment = cos(theta - axisAngle).abs();
      if (axisAlignment < spikeCosThreshold) {
        continue;
      }
      final tipScale =
          ((axisAlignment - spikeCosThreshold) / (1 - spikeCosThreshold))
              .clamp(0.0, 1.0);
      final tipOffset = spikeExtra * (0.55 + 0.55 * tipScale);
      final baseA = Offset(
        cos(theta + 0.14) * bodyR * 0.96,
        sin(theta + 0.14) * bodyR * 0.96,
      );
      final baseB = Offset(
        cos(theta - 0.14) * bodyR * 0.96,
        sin(theta - 0.14) * bodyR * 0.96,
      );
      final tip = Offset(
        cos(theta) * (bodyR + tipOffset),
        sin(theta) * (bodyR + tipOffset),
      );
      final path = Path()
        ..moveTo(baseA.dx, baseA.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(baseB.dx, baseB.dy)
        ..close();
      canvas.drawPath(path, spikeFill);
      canvas.drawPath(path, spikeOutline);
    }

    // --- Body ------------------------------------------------------------
    final bodyPath = Path()
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: bodyR));
    canvas.drawPath(bodyPath, Paint()..color = palette.body);

    // Perpendicular weak-spot patches — soft belly-colored ovals aligned
    // to the perpendicular (hit-me) axis. Clipped to the body so they
    // read as cut-outs from the overall silhouette, not stickers on top.
    final weakPaint = Paint()..color = palette.belly;
    for (final sign in <double>[1, -1]) {
      final cx = perpX * bodyR * 0.55 * sign;
      final cy = perpY * bodyR * 0.55 * sign;
      final patch = Path()
        ..addOval(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: bodyR * 1.05,
            height: bodyR * 0.78,
          ),
        );
      canvas.drawPath(
        Path.combine(PathOperation.intersect, bodyPath, patch),
        weakPaint,
      );
    }

    // Tiny pink "hit-here" accent dot in the middle of each weak patch.
    final accentPaint = Paint()..color = palette.accent;
    for (final sign in <double>[1, -1]) {
      final cx = perpX * bodyR * 0.5 * sign;
      final cy = perpY * bodyR * 0.5 * sign;
      canvas.drawCircle(Offset(cx, cy), bodyR * 0.09, accentPaint);
    }

    // Outline the body so the whole silhouette pops.
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = palette.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.075,
    );
    _maybeApplyDamageFlash(canvas, bodyPath, state.damageFlashStrength);

    // --- Face ------------------------------------------------------------
    // Small triangular nose pointing in the current travel direction so
    // players can see which end is "forward" this lap.
    final nose = Path()
      ..moveTo(
        fx * bodyR * 0.58 - fy * r * 0.05,
        fy * bodyR * 0.58 + fx * r * 0.05,
      )
      ..lineTo(fx * bodyR * 0.88, fy * bodyR * 0.88)
      ..lineTo(
        fx * bodyR * 0.58 + fy * r * 0.05,
        fy * bodyR * 0.58 - fx * r * 0.05,
      )
      ..close();
    canvas.drawPath(nose, Paint()..color = palette.outline);

    _drawFacingEyes(
      canvas,
      palette,
      radius: r,
      snappedAngle: faceAngle,
      forwardOffset: 0.28,
      sideOffset: 0.18,
      eyeRadius: 0.12,
      pupilRadius: 0.06,
      alert: state.alert,
    );
  }
}

/// Canonical palette presets keyed by silhouette. Keeps creature color
/// language consistent across levels while allowing per-biome tweaks later.
class CreaturePalettes {
  CreaturePalettes._();

  static const CreaturePalette walkerBug = CreaturePalette(
    body: Color(0xFFB96A3E),
    bodyShadow: Color(0x66120603),
    belly: Color(0xFFF0A867),
    accent: Color(0xFFFFD98A),
    eye: Color(0xFFFFF4E0),
  );

  static const CreaturePalette pulserCap = CreaturePalette(
    body: Color(0xFFC85AB0),
    bodyShadow: Color(0x66150316),
    belly: Color(0xFFF1B7E2),
    accent: Color(0xFFFFF0F7),
    eye: Color(0xFFFFF4FC),
  );

  static const CreaturePalette turretEye = CreaturePalette(
    body: Color(0xFF9BA6B6),
    bodyShadow: Color(0xFF4A5260),
    belly: Color(0xFFC3CBDA),
    accent: Color(0xFFFFB648),
    eye: Color(0xFFFFEFC4),
  );

  static const CreaturePalette bossGolem = CreaturePalette(
    body: Color(0xFF6C4CA2),
    bodyShadow: Color(0xFF2B1E49),
    belly: Color(0xFFB08CDE),
    accent: Color(0xFFFFDA57),
    eye: Color(0xFFFFF4C8),
  );

  static const CreaturePalette paddlePlank = CreaturePalette(
    body: Color(0xFF8A5A2E),
    bodyShadow: Color(0x663A1E0A),
    belly: Color(0xFFC28A54),
    accent: Color(0xFFF2D68A),
    eye: Color(0xFFFFF8E3),
  );

  static const CreaturePalette hedgehogSpiky = CreaturePalette(
    body: Color(0xFFB88A4C),
    bodyShadow: Color(0xFF3A2A10),
    belly: Color(0xFFFFD89A),
    accent: Color(0xFFFF5C8F),
    eye: Color(0xFFFFF4E0),
  );
}
