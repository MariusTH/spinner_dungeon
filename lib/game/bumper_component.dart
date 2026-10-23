import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'hit_reaction.dart';
import 'spinner_game.dart';

// agent.md palette.
const Color _deepVoid = Color(0xFF1A1412);
const Color _shadowStone = Color(0xFF2F2F2F);
const Color _emberOrange = Color(0xFFFF6A1F);
const Color _emberYellow = Color(0xFFFFC83B);
const Color _actionYellow = Color(0xFFFFE100);
const Color _bone = Color(0xFFF1E2C4);

/// Round obstacle the spinner ricochets off with a speed boost. Bumpers in
/// a pinball set ([groupId] != null) light up when hit; lighting a whole set
/// pays out a jackpot (see [SpinnerGame.onBumperLit]).
///
/// Pillars and barrels subclass this for shared bounce physics and override
/// [onSpinnerHit] and [render].
class BumperComponent extends CircleComponent
    with CollisionCallbacks, HasGameReference<SpinnerGame>, HitReaction {
  BumperComponent({
    required Vector2 position,
    double radius = 18,
    this.boostMultiplier = 1.18,
    this.controlLossRadians = 0.38,
    this.restitution = 1.06,
    this.groupId,
    bool lit = false,
  }) : _lit = lit,
       super(
         position: position,
         radius: radius,
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0xFFD5A94A),
       );

  final double boostMultiplier;
  final double controlLossRadians;
  final double restitution;

  /// Pinball set this bumper belongs to, or null for a lone bumper.
  final int? groupId;

  bool _lit;
  bool get lit => _lit;

  double _pulseTime = 0;
  double _litFlash = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulseTime += dt;
    if (_litFlash > 0) {
      _litFlash = max(0, _litFlash - dt);
    }
  }

  /// Called by the spinner on impact, after the bounce is applied.
  void onSpinnerHit(double impactSpeed) {
    if (groupId != null && !_lit) {
      _lit = true;
      _litFlash = 0.35;
      game.onBumperLit(this);
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(radius, radius);

    final pulse = (sin(_pulseTime * 3.6) + 1) * 0.5;
    final inSet = groupId != null;
    final ring = _lit
        ? _actionYellow
        : (inSet
              ? Color.lerp(_shadowStone, _emberOrange, 0.55)!
              : _emberOrange);
    final cap = _lit ? _bone : Color.lerp(_shadowStone, _bone, 0.35)!;

    // Contact shadow.
    canvas.drawCircle(
      Offset(0, radius * 0.16),
      radius * 1.02,
      Paint()..color = _deepVoid.withValues(alpha: 0.5),
    );
    if (_lit) {
      canvas.drawCircle(
        Offset.zero,
        radius * (1.35 + pulse * 0.1 + _litFlash),
        Paint()
          ..color = _emberYellow.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    canvas.drawCircle(Offset.zero, radius, Paint()..color = ring);
    canvas.drawCircle(Offset.zero, radius * 0.66, Paint()..color = cap);
    canvas.drawCircle(
      Offset.zero,
      radius * (0.3 + (_lit ? pulse * 0.06 : 0)),
      Paint()..color = _lit ? _emberYellow : _shadowStone,
    );
    // Upper-left shine.
    canvas.drawCircle(
      Offset(-radius * 0.22, -radius * 0.24),
      radius * 0.14,
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
    final outline = Paint()
      ..color = _deepVoid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6;
    canvas.drawCircle(Offset.zero, radius, outline);
    canvas.drawCircle(Offset.zero, radius * 0.66, outline..strokeWidth = 1.8);

    canvas.restore();
  }
}
