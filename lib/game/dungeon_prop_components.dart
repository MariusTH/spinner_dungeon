import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../systems/combat_system.dart';
import 'bumper_component.dart';

// agent.md palette.
const Color _deepVoid = Color(0xFF1A1412);
const Color _shadowStone = Color(0xFF2F2F2F);
const Color _stoneBase = Color(0xFF919090);
const Color _wood = Color(0xFF4F3816);
const Color _emberOrange = Color(0xFFFF6A1F);
const Color _emberYellow = Color(0xFFFFC83B);
const Color _danger = Color(0xFFFF3B30);
const Color _bone = Color(0xFFF1E2C4);

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

Paint _outline(double width) => Paint()
  ..color = _deepVoid
  ..style = PaintingStyle.stroke
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round
  ..strokeWidth = width;

/// Breakable stone column. Solid like a bumper but with no boost; cracks as
/// it takes damage from hits and explosions, then shatters.
class PillarComponent extends BumperComponent {
  PillarComponent({required super.position, super.radius = 20})
    : super(boostMultiplier: 0.82, controlLossRadians: 0.05, restitution: 0.9);

  static const double maxHp = 70;
  double _hp = maxHp;
  bool _broken = false;

  bool get isBroken => _broken;

  @override
  void onSpinnerHit(double impactSpeed) {
    takeDamage(
      CombatSystem.spinnerImpactDamage(
        speed: impactSpeed,
        damageMultiplier: game.spinner?.damageMultiplier ?? 1,
      ),
    );
  }

  void takeDamage(double damage) {
    if (_broken) {
      return;
    }
    _hp -= damage;
    triggerHitReaction(strength: 1.3);
    if (_hp <= 0) {
      _broken = true;
      game.onPropDestroyed(this);
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(radius, radius);
    final r = radius;
    final stone = _mix(_stoneBase, _bone, 0.12);

    canvas.drawCircle(
      Offset(0, r * 0.2),
      r * 1.04,
      Paint()..color = _deepVoid.withValues(alpha: 0.5),
    );
    // Octagonal column top seen from above.
    final top = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4 + pi / 8;
      final p = Offset(cos(a) * r, sin(a) * r);
      i == 0 ? top.moveTo(p.dx, p.dy) : top.lineTo(p.dx, p.dy);
    }
    top.close();
    canvas.drawPath(top, Paint()..color = stone);
    canvas.drawCircle(
      Offset.zero,
      r * 0.62,
      Paint()..color = _mix(stone, _shadowStone, 0.25),
    );
    canvas.drawCircle(
      Offset(-r * 0.25, -r * 0.3),
      r * 0.2,
      Paint()..color = _bone.withValues(alpha: 0.55),
    );

    // Cracks spread as HP drops.
    final damage = 1 - (_hp / maxHp).clamp(0.0, 1.0);
    final crack = _outline(1.8);
    if (damage > 0.3) {
      canvas.drawPath(
        Path()
          ..moveTo(-r * 0.7, -r * 0.2)
          ..lineTo(-r * 0.2, 0)
          ..lineTo(-r * 0.3, r * 0.45),
        crack,
      );
    }
    if (damage > 0.6) {
      canvas.drawPath(
        Path()
          ..moveTo(r * 0.75, r * 0.1)
          ..lineTo(r * 0.2, -r * 0.1)
          ..lineTo(r * 0.35, -r * 0.6)
          ..moveTo(r * 0.2, -r * 0.1)
          ..lineTo(-r * 0.2, 0),
        crack,
      );
    }
    canvas.drawPath(top, _outline(2.6));
    canvas.restore();
  }
}

/// Explosive barrel. Any spinner hit (or a nearby explosion) sets it off,
/// damaging enemies and pillars and chaining into other barrels.
class BarrelComponent extends BumperComponent {
  BarrelComponent({required super.position, super.radius = 15})
    : super(boostMultiplier: 1.0, controlLossRadians: 0.05, restitution: 0.95);

  static const double blastRadius = 130;
  static const double blastDamage = 48;

  bool _exploded = false;
  double? _fuse;
  double _age = 0;

  bool get isExploded => _exploded;

  @override
  void onSpinnerHit(double impactSpeed) => explode();

  /// Sets the barrel off after [delay] seconds (chains read better staggered).
  void explode({double delay = 0}) {
    if (_exploded) {
      return;
    }
    if (delay <= 0) {
      _detonate();
      return;
    }
    _fuse = _fuse == null ? delay : min(_fuse!, delay);
  }

  void _detonate() {
    if (_exploded) {
      return;
    }
    _exploded = true;
    game.triggerExplosion(
      center: position.clone(),
      radius: blastRadius,
      damage: blastDamage,
    );
    game.onPropDestroyed(this);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    final fuse = _fuse;
    if (fuse != null && !_exploded) {
      _fuse = fuse - dt;
      if (_fuse! <= 0) {
        _detonate();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(radius, radius);
    final r = radius;
    final lit = _fuse != null;
    final glow = lit ? 1.0 : (sin(_age * 2.4) + 1) * 0.5;

    canvas.drawCircle(
      Offset(0, r * 0.2),
      r * 1.04,
      Paint()..color = _deepVoid.withValues(alpha: 0.5),
    );
    // Wooden rim, metal hoop, red lid.
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()..color = _mix(_wood, _emberOrange, 0.25),
    );
    canvas.drawCircle(
      Offset.zero,
      r * 0.82,
      Paint()
        ..color = _shadowStone
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.14,
    );
    canvas.drawCircle(
      Offset.zero,
      r * 0.62,
      Paint()..color = lit ? _emberYellow : _danger,
    );
    // Warning glyph: a chunky "!".
    final mark = Paint()..color = _bone;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -r * 0.1),
          width: r * 0.2,
          height: r * 0.5,
        ),
        Radius.circular(r * 0.1),
      ),
      mark,
    );
    canvas.drawCircle(Offset(0, r * 0.3), r * 0.11, mark);
    canvas.drawCircle(
      Offset.zero,
      r * 0.62,
      _outline(1.6)..color = _deepVoid.withValues(alpha: 0.6 + glow * 0.4),
    );
    canvas.drawCircle(Offset.zero, r, _outline(2.4));
    canvas.restore();
  }
}

/// Expanding fireball ring for explosions.
class ExplosionFxComponent extends PositionComponent {
  ExplosionFxComponent({required Vector2 position, required this.radius})
    : super(position: position, anchor: Anchor.center, priority: 80);

  final double radius;
  static const double _duration = 0.38;
  double _age = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= _duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / _duration).clamp(0.0, 1.0);
    final grow = Curves.easeOutCubic.transform(t);
    final fade = 1 - t;
    canvas.drawCircle(
      Offset.zero,
      radius * (0.35 + grow * 0.65),
      Paint()..color = _emberOrange.withValues(alpha: 0.45 * fade),
    );
    canvas.drawCircle(
      Offset.zero,
      radius * (0.2 + grow * 0.4),
      Paint()..color = _emberYellow.withValues(alpha: 0.8 * fade),
    );
    canvas.drawCircle(
      Offset.zero,
      radius * (0.35 + grow * 0.65),
      Paint()
        ..color = _deepVoid.withValues(alpha: 0.8 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * fade + 1,
    );
  }
}
