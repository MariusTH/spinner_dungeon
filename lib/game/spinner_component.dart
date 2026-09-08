import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../systems/collision_system.dart';
import '../systems/combat_system.dart';
import '../systems/spinner_parts.dart';
import 'bumper_component.dart';
import 'enemy_component.dart';
import 'physics.dart';
import 'spinner_game.dart';
import 'spinner_top_physics.dart';
import 'wall_component.dart';

class SpinnerComponent extends CircleComponent
    with CollisionCallbacks, HasGameReference<SpinnerGame> {
  SpinnerComponent({required Vector2 position})
    : velocity = Vector2.zero(),
      angularVelocity = 0,
      friction = 0.93,
      damageMultiplier = 1,
      isMoving = false,
      super(
        position: position,
        radius: 20,
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0xFF57D1FF),
      );

  Vector2 velocity;
  double angularVelocity;
  double friction;
  double damageMultiplier;
  bool isMoving;
  Vector2 _targetVelocity = Vector2.zero();
  double _launchBlendTime = 0;
  double _spinDirection = 1;
  double _timeSinceImpact = 0;
  double _chargePreviewStrength = 0;
  double _chargePulseTime = 0;
  double _chargePreviewAngularVelocity = 0;
  double _damageFlashTime = 0;
  double _hitConfirmTime = 0;
  SpinnerTopPhysicsConfig? _topPhysics;
  double _precessionPhase = 0;
  double _nutationPhase = 0;
  final Random _random = Random();
  Color _coreColor = const Color(0xFFE4A956);
  Color _ringColor = const Color(0xFFC69A57);
  Color _bladeColor = const Color(0xFF74C2E8);
  Color _glowColor = const Color(0xFFFFC05B);
  // Blade profile is applied at spawn; defaults are safe for the fallback build
  // in case `configureBuildVisual` is never called (e.g., in tests).
  BladeShape _bladeShape = BladeShape.standard;
  /// Build-defined reach (catalog “blade reach”) before the run-time stance.
  double _bladeReachBase = 3;
  /// `true` = extended blade arc (larger), `false` = tucked (tighter, safer).
  bool _bladesWideStance = true;
  /// `true` — matches loadout [SpinnerBuildStats.bladeReach]. `false` — tucked in.
  static const double _wideStanceFactor = 1.0;
  static const double _compactStanceFactor = 0.68;
  double _bladeReach = 3;
  double _bladeDamageBonus = 1.05;
  // Extra visual "hit zone" bloom on successful blade-tip hits.
  double _bladeHitFlashTime = 0;
  CircleHitbox? _bladeHitbox;

  static const double _maxSpeed = 1120;
  static const double _stopThreshold = 10;
  static const double _launchBlendDuration = 0.12;
  static const double _legacyAngularDamping = 0.92;
  static const double _impactGraceSeconds = 1.0;
  static const double _deadAirFriction = 0.42;
  static const double _wallRestitution = 0.9;
  static const double _wallSpeedRetentionCap = 0.96;
  static const double _maxChargePreviewAngularVelocity = 20;
  static const double _damageFlashDuration = 0.24;
  static const double _hitConfirmDuration = 0.14;
  static const double _bladeHitFlashDuration = 0.18;

  /// Outermost reach of the spinner's blade tips, including `_bladeReach`.
  /// Used by anything that needs to know how far the spinner "swings" out
  /// from its center (enemy hit zone, render extents, hitbox sizing).
  double get outerReachRadius => radius + _bladeReach;

  bool get bladesWideStance => _bladesWideStance;

  void toggleBladeStance() {
    _bladesWideStance = !_bladesWideStance;
    _applyBladeStanceReach();
  }

  void _applyBladeStanceReach() {
    final factor =
        _bladesWideStance ? _wideStanceFactor : _compactStanceFactor;
    final newReach = (_bladeReachBase * factor).clamp(0.5, 14.0);
    final reachChanged = (newReach - _bladeReach).abs() > 0.01;
    _bladeReach = newReach;
    if (reachChanged || _bladeHitbox == null) {
      _rebuildBladeHitbox();
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _rebuildBladeHitbox();
  }

  /// (Re)build the single active collision hitbox. Its radius equals the
  /// body radius plus the current blade reach so enemies can be struck by
  /// the blade tips before the core body touches them.
  ///
  /// Walls and bumpers still resolve against `radius` (body-only) via the
  /// manual overlap path in `_resolveWallOverlaps`, so enlarging the hitbox
  /// never makes the spinner bounce off walls from a blade tip.
  void _rebuildBladeHitbox() {
    _bladeHitbox?.removeFromParent();
    final hitR = outerReachRadius;
    // CircleHitbox positions itself relative to the parent's top-left local
    // origin. Offset by `radius` so the hitbox center sits on the visual
    // center of the spinner (matching the render translation in `render`).
    final box = CircleHitbox(
      radius: hitR,
      position: Vector2(radius, radius),
      anchor: Anchor.center,
      collisionType: CollisionType.active,
    );
    _bladeHitbox = box;
    add(box);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_damageFlashTime > 0) {
      _damageFlashTime = max(0, _damageFlashTime - dt);
    }
    if (_hitConfirmTime > 0) {
      _hitConfirmTime = max(0, _hitConfirmTime - dt);
    }
    if (_bladeHitFlashTime > 0) {
      _bladeHitFlashTime = max(0, _bladeHitFlashTime - dt);
    }

    if (!isMoving) {
      if (_chargePreviewStrength > 0) {
        _chargePulseTime += dt;
        final chargeRatio = (_chargePreviewStrength / 10).clamp(0.0, 1.0);
        final targetPreviewAngularVelocity =
            _spinDirection * (_maxChargePreviewAngularVelocity * chargeRatio);
        final blend = (dt * 12).clamp(0, 1).toDouble();
        _chargePreviewAngularVelocity +=
            (targetPreviewAngularVelocity - _chargePreviewAngularVelocity) *
            blend;
        angle += _chargePreviewAngularVelocity * dt;
      } else if (_chargePreviewAngularVelocity != 0) {
        _chargePreviewAngularVelocity *= pow(0.05, dt).toDouble();
        if (_chargePreviewAngularVelocity.abs() < 0.01) {
          _chargePreviewAngularVelocity = 0;
        }
      }
      return;
    }

    _timeSinceImpact += dt;
    _integrateWithWallResolution(dt);

    if (_launchBlendTime > 0) {
      final blend = (dt / _launchBlendTime).clamp(0, 1).toDouble();
      velocity += (_targetVelocity - velocity) * blend;
      _launchBlendTime -= dt;
      if (_launchBlendTime <= 0) {
        velocity = _targetVelocity.clone();
      }
    }

    velocity = PhysicsModel.applyFriction(velocity, friction, dt);
    if (_timeSinceImpact > _impactGraceSeconds && _launchBlendTime <= 0) {
      velocity = PhysicsModel.applyFriction(velocity, _deadAirFriction, dt);
      _targetVelocity = velocity.clone();
    }

    _applyTopPhysics(dt);

    if (_launchBlendTime <= 0) {
      _targetVelocity = velocity.clone();
    }

    final speed = velocity.length;
    final cfg = _topPhysics;
    if (cfg != null) {
      final ret = cfg.spinRetention.clamp(0.52, 1.58);
      angularVelocity *= pow(cfg.baseAngularDamping, dt / ret);
      final targetSpin = speed * cfg.pathToSpinScale * _spinDirection;
      final blend = (dt * 12 * cfg.spinBlendFromPath).clamp(0.0, 1.0);
      angularVelocity += (targetSpin - angularVelocity) * blend;
    } else {
      final targetSpin = speed * 0.018 * _spinDirection;
      angularVelocity =
          (angularVelocity * pow(_legacyAngularDamping, dt).toDouble()) * 0.9 +
          (targetSpin * 0.1);
    }
    angle += angularVelocity * dt;

    game.clampSpinnerToArena(this);

    if (velocity.length < _stopThreshold) {
      stop();
    }
  }

  void _integrateWithWallResolution(double dt) {
    if (dt <= 0) {
      return;
    }

    final travel = velocity.length * dt;
    final steps = max(1, (travel / max(6, radius * 0.45)).ceil()).clamp(1, 12);
    final stepDt = dt / steps;
    for (var i = 0; i < steps; i++) {
      PhysicsModel.integrate(this, velocity, stepDt);
      _resolveWallOverlaps();
      game.clampSpinnerToArena(this);
    }
  }

  bool _resolveWallOverlaps() {
    var anyCollision = false;
    for (var pass = 0; pass < 6; pass++) {
      var collided = false;
      for (final wall in game.wallComponents) {
        if (_resolveAgainstWall(wall)) {
          collided = true;
        }
      }
      if (collided) {
        anyCollision = true;
      } else {
        break;
      }
    }
    return anyCollision;
  }

  /// Cheap test: is this wall AABB overlapping the body circle (NOT the
  /// blade-reach circle)? Lets `onCollisionStart` ignore events where only
  /// blade tips graze a wall so the impact grace timer doesn't reset and
  /// the spinner can coast smoothly alongside walls.
  bool _bodyOverlapsWall(WallComponent wall) {
    final halfW = wall.size.x * 0.5;
    final halfH = wall.size.y * 0.5;
    final closestX = position.x.clamp(
      wall.position.x - halfW,
      wall.position.x + halfW,
    );
    final closestY = position.y.clamp(
      wall.position.y - halfH,
      wall.position.y + halfH,
    );
    final dx = position.x - closestX;
    final dy = position.y - closestY;
    return dx * dx + dy * dy < radius * radius;
  }

  bool _resolveAgainstWall(WallComponent wall) {
    final halfW = wall.size.x * 0.5;
    final halfH = wall.size.y * 0.5;
    final left = wall.position.x - halfW;
    final right = wall.position.x + halfW;
    final top = wall.position.y - halfH;
    final bottom = wall.position.y + halfH;

    final closestX = position.x.clamp(left, right).toDouble();
    final closestY = position.y.clamp(top, bottom).toDouble();
    final dx = position.x - closestX;
    final dy = position.y - closestY;
    final dist2 = dx * dx + dy * dy;
    final radius2 = radius * radius;
    if (dist2 >= radius2) {
      return false;
    }

    late Vector2 normal;
    late double penetration;

    if (dist2 > 0.0001) {
      final dist = sqrt(dist2);
      normal = Vector2(dx / dist, dy / dist);
      penetration = radius - dist;
    } else {
      final distToLeft = (position.x - left).abs();
      final distToRight = (right - position.x).abs();
      final distToTop = (position.y - top).abs();
      final distToBottom = (bottom - position.y).abs();

      final minDist = min(
        min(distToLeft, distToRight),
        min(distToTop, distToBottom),
      );
      if (minDist == distToLeft) {
        normal = Vector2(-1, 0);
        penetration = radius + distToLeft;
      } else if (minDist == distToRight) {
        normal = Vector2(1, 0);
        penetration = radius + distToRight;
      } else if (minDist == distToTop) {
        normal = Vector2(0, -1);
        penetration = radius + distToTop;
      } else {
        normal = Vector2(0, 1);
        penetration = radius + distToBottom;
      }
    }

    position += normal * (penetration + 0.6);

    final vn = velocity.dot(normal);
    if (vn < 0) {
      _timeSinceImpact = 0;
      final incomingSpeed = velocity.length;
      final bouncedVelocity = CollisionSystem.bounce(
        velocity: velocity,
        normal: normal,
        restitution: _wallRestitution,
      );
      final bouncedSpeed = bouncedVelocity.length;
      if (incomingSpeed <= 0 || bouncedSpeed <= 0) {
        velocity = Vector2.zero();
      } else {
        final cappedSpeed = min(
          bouncedSpeed,
          incomingSpeed * _wallSpeedRetentionCap,
        );
        velocity = bouncedVelocity * (cappedSpeed / bouncedSpeed);
      }
      _targetVelocity = velocity.clone();
    }
    return true;
  }

  @override
  void render(Canvas canvas) {
    // CircleComponent uses a top-left local origin; move to true visual center
    // so component rotation always pivots around the spinner itself.
    canvas.save();
    canvas.translate(radius, radius);

    final bodyPaint = Paint()..color = _ringColor;
    final bodyOutline = Paint()
      ..color = const Color(0xFF1B1917)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(Offset.zero, radius, bodyPaint);
    canvas.drawCircle(Offset.zero, radius, bodyOutline);

    _renderBlades(canvas);

    final corePaint = Paint()..color = _coreColor;
    canvas.drawCircle(Offset.zero, radius * 0.55, corePaint);
    canvas.drawCircle(
      Offset.zero,
      radius * 0.55,
      Paint()
        ..color = const Color(0xFF1B1917)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    canvas.drawCircle(
      Offset(-radius * 0.18, -radius * 0.2),
      radius * 0.12,
      Paint()..color = const Color(0x99FFFFFF),
    );
    canvas.drawCircle(
      Offset.zero,
      radius * 0.2,
      Paint()..color = _glowColor.withAlpha(205),
    );

    if (_damageFlashTime > 0) {
      final intensity = (_damageFlashTime / _damageFlashDuration).clamp(
        0.0,
        1.0,
      );
      final flashPaint = Paint()
        ..color = Color.fromARGB((90 + (150 * intensity)).toInt(), 255, 96, 92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2 + (2.4 * intensity);
      final fillPaint = Paint()
        ..color = Color.fromARGB((28 + (75 * intensity)).toInt(), 255, 90, 86);
      canvas.drawCircle(
        Offset.zero,
        radius * (0.96 + intensity * 0.05),
        fillPaint,
      );
      canvas.drawCircle(
        Offset.zero,
        radius + 2.0 + (1.4 * intensity),
        flashPaint,
      );
    }

    if (_hitConfirmTime > 0) {
      final u = (_hitConfirmTime / _hitConfirmDuration).clamp(0.0, 1.0);
      final pulse = sin(u * pi);
      final ringPaint = Paint()
        ..color = Color.fromARGB((160 * pulse).round(), 120, 220, 255)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 + pulse * 2;
      canvas.drawCircle(
        Offset.zero,
        radius + 4 + (6 * (1 - u)),
        ringPaint,
      );
    }

    if (game.tetherActive) {
      final tetherPaint = Paint()
        ..color = const Color(0xAA90E9FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawCircle(Offset.zero, radius + 6.5, tetherPaint);
    }

    if (game.fireballActive) {
      final t = game.elapsedSeconds * 7.5;
      final orbitRadius = radius + 8.2;
      for (var i = 0; i < 2; i++) {
        final theta = t + (pi * i);
        final p = Offset(cos(theta), sin(theta)) * orbitRadius;
        canvas.drawCircle(
          p,
          radius * 0.2,
          Paint()..color = const Color(0xA6FFB46B),
        );
        canvas.drawCircle(
          p,
          radius * 0.1,
          Paint()..color = const Color(0xFFFFE2BE),
        );
      }
    }

    if (game.needlesActive) {
      final spikePaint = Paint()
        ..color = const Color(0xFF87EBC7)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 8; i++) {
        final theta = (pi * 2 * i) / 8;
        final inner = Offset(cos(theta), sin(theta)) * (radius + 2.6);
        final outer = Offset(cos(theta), sin(theta)) * (radius + 6.0);
        canvas.drawLine(inner, outer, spikePaint);
      }
    }

    if (_chargePreviewStrength > 0) {
      final pulse = (sin(_chargePulseTime * 10) + 1) * 0.5;
      final glowStrength = (_chargePreviewStrength / 6).clamp(0.15, 1.0);
      final chargeRatio = (_chargePreviewStrength / 10).clamp(0.0, 1.0);
      final alpha = (110 + 100 * glowStrength * (0.45 + pulse * 0.55))
          .clamp(0, 255)
          .toInt();
      final ringRadius = radius + 4 + pulse * 2.5;
      final ringPaint = Paint()
        ..color = Color.fromARGB(alpha, 255, 244, 150)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + 2.5 * glowStrength;
      canvas.drawCircle(Offset.zero, ringRadius, ringPaint);

      // Add a directional arc + marker so charge feels like visible spin speed.
      final directionSign = _spinDirection >= 0 ? 1.0 : -1.0;
      final sweep = directionSign * (0.5 + chargeRatio * 1.85);
      final arcPaint = Paint()
        ..color = Color.fromARGB((alpha * 0.95).toInt(), 255, 226, 120)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 + (2.6 * glowStrength)
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: ringRadius),
        -pi * 0.5,
        sweep,
        false,
        arcPaint,
      );

      final markerAngle = (-pi * 0.5) + sweep;
      final markerOffset =
          Offset(cos(markerAngle), sin(markerAngle)) * ringRadius;
      final markerPaint = Paint()
        ..color = Color.fromARGB(
          (165 + chargeRatio * 90).clamp(0, 255).toInt(),
          255,
          248,
          173,
        );
      canvas.drawCircle(markerOffset, 2.2 + chargeRatio * 2.2, markerPaint);
    }

    canvas.restore();
  }

  /// Draws four evenly spaced blades around the body. Each shape has a
  /// distinct silhouette that matches its gameplay feel:
  ///  - `standard`: balanced rounded rectangles
  ///  - `curved`:   scything arc sweeping along the rotation direction
  ///  - `hook`:     slender shaft with a hooked outer tip
  ///  - `spiky`:    triangular spurs with sharp outward point
  ///  - `extruded`: chunky thick bar jutting far past the body
  ///
  /// All shapes render in the spinner's local space (canvas already
  /// translated so `Offset.zero` is the visual center) and respect
  /// `_bladeReach` so the visual matches the enemy collision extent.
  void _renderBlades(Canvas canvas) {
    final bladePaint = Paint()..color = _bladeColor;
    final outlinePaint = Paint()
      ..color = const Color(0xFF1B1917)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final shadowPaint = Paint()..color = const Color(0x661B1917);
    final tipHighlight = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..style = PaintingStyle.fill;

    final reach = _bladeReach;
    for (var i = 0; i < 4; i++) {
      final theta = pi * 0.5 * i;
      canvas.save();
      canvas.rotate(theta);
      // After rotation, the "outward" direction is +X. Each shape is drawn
      // in this local frame so all four blades share one geometry pass.
      switch (_bladeShape) {
        case BladeShape.standard:
          _drawStandardBlade(
            canvas,
            reach: reach,
            body: bladePaint,
            outline: outlinePaint,
            shadow: shadowPaint,
          );
        case BladeShape.curved:
          _drawCurvedBlade(
            canvas,
            reach: reach,
            body: bladePaint,
            outline: outlinePaint,
            shadow: shadowPaint,
          );
        case BladeShape.hook:
          _drawHookBlade(
            canvas,
            reach: reach,
            body: bladePaint,
            outline: outlinePaint,
            shadow: shadowPaint,
            highlight: tipHighlight,
          );
        case BladeShape.spiky:
          _drawSpikyBlade(
            canvas,
            reach: reach,
            body: bladePaint,
            outline: outlinePaint,
            shadow: shadowPaint,
            highlight: tipHighlight,
          );
        case BladeShape.extruded:
          _drawExtrudedBlade(
            canvas,
            reach: reach,
            body: bladePaint,
            outline: outlinePaint,
            shadow: shadowPaint,
          );
      }
      canvas.restore();
    }

    // Blade-tip hit pulse: brief translucent ring at the blade reach so
    // "my blade actually connected" reads separately from the body hit flash.
    if (_bladeHitFlashTime > 0 && reach > 0.5) {
      final u = (_bladeHitFlashTime / _bladeHitFlashDuration).clamp(0.0, 1.0);
      final pulse = sin(u * pi);
      final ringPaint = Paint()
        ..color = Color.fromARGB((200 * pulse).round(), 255, 225, 130)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 + pulse * 1.8;
      canvas.drawCircle(
        Offset.zero,
        outerReachRadius + 1.5 + (3.0 * (1 - u)),
        ringPaint,
      );
    }
  }

  void _drawStandardBlade(
    Canvas canvas, {
    required double reach,
    required Paint body,
    required Paint outline,
    required Paint shadow,
  }) {
    // Rectangular fin with a hint of tilt. Reach directly extends its tip.
    final inner = radius * 0.42;
    final outer = radius + reach;
    final length = outer - inner;
    final width = radius * 0.36;
    final rect = Rect.fromLTWH(inner, -width * 0.5, length, width);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(3));
    // Slight tilt so each blade reads as rotating even when still.
    canvas.save();
    canvas.translate(inner + length * 0.5, 0);
    canvas.rotate(pi / 12);
    canvas.translate(-(inner + length * 0.5), 0);
    canvas.drawRRect(rr.shift(const Offset(0.8, 1.2)), shadow);
    canvas.drawRRect(rr, body);
    canvas.drawRRect(rr, outline);
    canvas.restore();
  }

  void _drawCurvedBlade(
    Canvas canvas, {
    required double reach,
    required Paint body,
    required Paint outline,
    required Paint shadow,
  }) {
    // Sickle / halo arc sweeping along the rotation direction. Built from a
    // filled Path so the curve reads like a real cutting edge, not a stroke.
    final inner = radius * 0.4;
    final outer = radius + reach;
    final thickness = radius * 0.26;
    final sweep = pi * 0.42;

    final path = Path();
    path.moveTo(inner, -thickness * 0.2);
    final outerRect = Rect.fromCircle(
      center: Offset.zero,
      radius: outer,
    );
    final innerRect = Rect.fromCircle(
      center: Offset.zero,
      radius: inner,
    );
    path.arcTo(outerRect, -sweep * 0.5, sweep, false);
    path.arcTo(innerRect, sweep * 0.5, -sweep, false);
    path.close();

    canvas.save();
    canvas.translate(1.0, 1.4);
    canvas.drawPath(path, shadow);
    canvas.restore();
    canvas.drawPath(path, body);
    canvas.drawPath(path, outline);
  }

  void _drawHookBlade(
    Canvas canvas, {
    required double reach,
    required Paint body,
    required Paint outline,
    required Paint shadow,
    required Paint highlight,
  }) {
    // Thin comet shaft ending in a hooked tip that curls along rotation.
    final inner = radius * 0.45;
    final outer = radius + reach;
    final thickness = radius * 0.18;
    final shaft = Rect.fromLTWH(
      inner,
      -thickness * 0.5,
      (outer - inner) * 0.88,
      thickness,
    );
    final shaftRR = RRect.fromRectAndRadius(shaft, const Radius.circular(2.5));

    canvas.drawRRect(shaftRR.shift(const Offset(0.6, 1.2)), shadow);
    canvas.drawRRect(shaftRR, body);
    canvas.drawRRect(shaftRR, outline);

    final hookCenter = Offset(inner + (outer - inner) * 0.86, 0);
    final hookR = thickness * 1.3;
    final hookPath = Path()
      ..addArc(
        Rect.fromCircle(center: hookCenter, radius: hookR),
        -pi * 0.2,
        pi * 1.15,
      );
    final hookPaint = Paint()
      ..color = body.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness * 0.95
      ..strokeCap = StrokeCap.round;
    final hookOutline = Paint()
      ..color = outline.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness * 1.25
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(hookPath, hookOutline);
    canvas.drawPath(hookPath, hookPaint);

    // Bright tip dot so it reads at small sizes.
    canvas.drawCircle(Offset(outer - 2, -hookR * 0.6), 1.6, highlight);
  }

  void _drawSpikyBlade(
    Canvas canvas, {
    required double reach,
    required Paint body,
    required Paint outline,
    required Paint shadow,
    required Paint highlight,
  }) {
    // Triangular spur with a smaller serration underneath for "jagged" feel.
    final inner = radius * 0.48;
    final outer = radius + reach;
    final halfW = radius * 0.32;

    final spear = Path()
      ..moveTo(inner, -halfW)
      ..lineTo(outer, 0)
      ..lineTo(inner, halfW)
      ..close();

    final serration = Path()
      ..moveTo(inner + (outer - inner) * 0.35, -halfW * 0.3)
      ..lineTo(outer - (outer - inner) * 0.25, -halfW * 0.9)
      ..lineTo(inner + (outer - inner) * 0.55, -halfW * 0.25)
      ..close();

    canvas.save();
    canvas.translate(0.8, 1.2);
    canvas.drawPath(spear, shadow);
    canvas.restore();
    canvas.drawPath(spear, body);
    canvas.drawPath(spear, outline);
    canvas.drawPath(serration, body);
    canvas.drawPath(serration, outline);

    // Luminous tip for the "spiky" feel — ties in with Voidedge accent.
    canvas.drawCircle(Offset(outer - 1.5, 0), 1.8, highlight);
  }

  void _drawExtrudedBlade(
    Canvas canvas, {
    required double reach,
    required Paint body,
    required Paint outline,
    required Paint shadow,
  }) {
    // Forge / anchor: thick rectangular bar jutting well past the body with a
    // darker rivet band at the base.
    final inner = radius * 0.36;
    final outer = radius + reach;
    final width = radius * 0.48;
    final rect = Rect.fromLTWH(inner, -width * 0.5, outer - inner, width);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(2));
    canvas.drawRRect(rr.shift(const Offset(1.0, 1.6)), shadow);
    canvas.drawRRect(rr, body);
    canvas.drawRRect(rr, outline);

    final rivetBand = Rect.fromLTWH(
      inner + 1.5,
      -width * 0.35,
      width * 0.55,
      width * 0.7,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rivetBand, const Radius.circular(1.5)),
      Paint()..color = const Color(0xFF1B1917).withValues(alpha: 0.35),
    );

    // Outer cap stripe so the "tip" reads at speed.
    final capStripe = Rect.fromLTWH(
      outer - (width * 0.55),
      -width * 0.35,
      width * 0.45,
      width * 0.7,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(capStripe, const Radius.circular(1.5)),
      Paint()..color = const Color(0x88FFFFFF),
    );
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (!isMoving) {
      return;
    }

    if (other is WallComponent) {
      // Blade tips now extend the hitbox, so ignore events where only the
      // blade zone grazes a wall. Only reset the impact timer + resolve when
      // the body itself is overlapping.
      if (!_bodyOverlapsWall(other)) {
        return;
      }
      _timeSinceImpact = 0;
      _resolveWallOverlaps();
      game.clampSpinnerToArena(this);
      return;
    }

    if (other is BumperComponent) {
      _timeSinceImpact = 0;
      final spinnerAway = CollisionSystem.directionAwayFrom(
        from: other.position,
        to: position,
      );
      final normal = spinnerAway.length2 > 0
          ? spinnerAway.normalized()
          : (velocity.length2 > 0 ? velocity.normalized() : Vector2(1, 0));
      final bounced = CollisionSystem.bounce(
        velocity: velocity,
        normal: normal,
        restitution: other.restitution,
      );
      final bouncedDir = bounced.length2 > 0 ? bounced.normalized() : normal;
      final baseSpeed = max(_stopThreshold, bounced.length);
      final boostedSpeed = (baseSpeed * other.boostMultiplier).clamp(
        _stopThreshold,
        _maxSpeed * 1.28,
      );

      // Add directional uncertainty after bumper hit to simulate loss of control.
      final jitter =
          (_random.nextDouble() * 2 - 1) *
          other.controlLossRadians.clamp(0.05, pi * 0.5);
      final cosJ = cos(jitter);
      final sinJ = sin(jitter);
      final jitteredDir = Vector2(
        bouncedDir.x * cosJ - bouncedDir.y * sinJ,
        bouncedDir.x * sinJ + bouncedDir.y * cosJ,
      );

      velocity = jitteredDir.normalized() * boostedSpeed.toDouble();
      _targetVelocity = velocity.clone();
      _launchBlendTime = max(_launchBlendTime, 0.1);

      final spinSign = angularVelocity == 0
          ? (_random.nextBool() ? 1.0 : -1.0)
          : angularVelocity.sign;
      angularVelocity =
          spinSign * (angularVelocity.abs() + boostedSpeed * 0.012);

      game.clampSpinnerToArena(this);
      return;
    }

    if (other is EnemyComponent && !other.isDead) {
      _timeSinceImpact = 0;
      final speed = velocity.length;
      // Distinguish a "blade-tip strike" from a "body slam":
      //   - Blade zone  = body radius .. outerReachRadius  → damage bonus, minimal knock-back on self
      //   - Body zone   = inside body radius                → normal damage, full bounce
      // This is what makes blade reach + shape matter in combat.
      final centerDist = position.distanceTo(other.position);
      // EnemyComponent already extends CircleComponent, so `radius` is always
      // available here; we still guard with a safe default of 0 for clarity.
      final otherR = other.radius;
      final bladeZoneThreshold = radius + (otherR * 0.55);
      final isBladeZoneHit =
          _bladeReach > 0.5 && centerDist > bladeZoneThreshold;
      final baseDamage = CombatSystem.spinnerImpactDamage(
        speed: speed,
        damageMultiplier: damageMultiplier,
        earlyLevelFactor: game.spinnerContactDamageEarlyFactor,
      );
      final zoneBonus = isBladeZoneHit ? _bladeDamageBonus : 1.0;
      final damage = (baseDamage * zoneBonus).clamp(1.0, 9999.0);
      final canDamageEnemy = other.canTakeDamageFromSpinner(position);
      if (canDamageEnemy) {
        final heavyHit = damage >= other.maxHp * 0.75;
        final defeated = other.hp <= damage;
        other.takeDamage(damage);
        final mid = (position + other.position) / 2;
        game.onSpinnerEnemyImpact(
          impactSpeed: speed,
          damage: damage,
          enemyDefeated: defeated || other.isDead,
          heavyHit: heavyHit,
          impactWorldPos: mid,
        );
        triggerHitConfirm();
        if (isBladeZoneHit) {
          _bladeHitFlashTime = _bladeHitFlashDuration;
        }
      }

      final spinnerToEnemy = CollisionSystem.directionAwayFrom(
        from: position,
        to: other.position,
      );
      if (spinnerToEnemy.length2 > 0) {
        final enemyToSpinner = spinnerToEnemy * -1;
        velocity = CollisionSystem.bounce(
          velocity: velocity,
          normal: enemyToSpinner,
          restitution: other.spinnerCollisionRestitution(
            spinnerCanDamage: canDamageEnemy,
          ),
        );
        final maxCollisionSpeed = _maxSpeed * 1.12;
        if (velocity.length > maxCollisionSpeed) {
          velocity = velocity.normalized() * maxCollisionSpeed;
        }
        _targetVelocity = velocity.clone();
        if (canDamageEnemy) {
          other.addImpulse(
            CombatSystem.knockback(
              direction: spinnerToEnemy,
              force: speed * 0.31,
            ),
          );
        }
      }

      if (other.isAbsorber && !game.isInvasionMode) {
        velocity *= 0.46;
        _targetVelocity *= 0.46;
        angularVelocity *= 0.72;
      }
    }
  }

  void launch(Vector2 launchVelocity, {required double angularVelocity}) {
    clearChargePreview();

    _precessionPhase = _random.nextDouble() * pi * 2;
    _nutationPhase = _random.nextDouble() * pi * 2;

    final speed = launchVelocity.length;
    _targetVelocity = speed > _maxSpeed
        ? launchVelocity.normalized() * _maxSpeed
        : launchVelocity.clone();
    velocity = _targetVelocity * 0.4;
    _launchBlendTime = _launchBlendDuration;
    _timeSinceImpact = 0;

    _spinDirection = angularVelocity == 0 ? 1 : angularVelocity.sign;
    this.angularVelocity = angularVelocity * 1.4;
    isMoving = _targetVelocity.length >= _stopThreshold;
    game.onSpinnerLaunched();
    game.onSpinnerStateChanged();
  }

  void stop() {
    velocity = Vector2.zero();
    _targetVelocity = Vector2.zero();
    angularVelocity = 0;
    _launchBlendTime = 0;
    _timeSinceImpact = 0;
    _precessionPhase = 0;
    _nutationPhase = 0;
    isMoving = false;
    game.onSpinnerStateChanged();
  }

  void setChargePreview({
    required double strength,
    required double signedAngularVelocity,
  }) {
    if (isMoving) {
      return;
    }

    _chargePreviewStrength = strength.clamp(0, 10).toDouble();
    final direction = signedAngularVelocity == 0
        ? _spinDirection
        : signedAngularVelocity.sign;
    _spinDirection = direction == 0 ? _spinDirection : direction;
  }

  void clearChargePreview() {
    _chargePreviewStrength = 0;
    _chargePulseTime = 0;
    _chargePreviewAngularVelocity = 0;
  }

  void triggerDamageFlash() {
    _damageFlashTime = _damageFlashDuration;
  }

  void triggerHitConfirm() {
    _hitConfirmTime = _hitConfirmDuration;
  }

  void applyTrapEffect({
    double speedMultiplier = 0.55,
    double spinMultiplier = 0.65,
  }) {
    if (!isMoving) {
      return;
    }

    velocity *= speedMultiplier;
    _targetVelocity *= speedMultiplier;
    angularVelocity *= spinMultiplier;

    if (velocity.length < _stopThreshold) {
      stop();
    } else {
      game.onSpinnerStateChanged();
    }
  }

  void addExternalImpulse(Vector2 impulse) {
    if (!isMoving || impulse.length2 <= 0) {
      return;
    }

    velocity += impulse;
    _targetVelocity += impulse;

    if (velocity.length > _maxSpeed) {
      velocity = velocity.normalized() * _maxSpeed;
    }
    if (_targetVelocity.length > _maxSpeed) {
      _targetVelocity = _targetVelocity.normalized() * _maxSpeed;
    }
  }

  @override
  bool containsPoint(Vector2 point) {
    // Mobile-friendly gesture start radius around the spinner center.
    return point.distanceTo(position) <= radius * 2.45;
  }

  void configureForRun({
    required double damageMultiplier,
    required double friction,
    required SpinnerTopPhysicsConfig topPhysics,
  }) {
    this.damageMultiplier = damageMultiplier;
    this.friction = friction.clamp(0.7, 0.985).toDouble();
    _topPhysics = topPhysics;
  }

  double get topPrecessionPhase => _precessionPhase;

  double get topNutationPhase => _nutationPhase;

  void restoreTopMotionPhases({
    required double precessionPhase,
    required double nutationPhase,
  }) {
    _precessionPhase = precessionPhase;
    _nutationPhase = nutationPhase;
  }

  void _applyTopPhysics(double dt) {
    final cfg = _topPhysics;
    if (cfg == null || dt <= 0) {
      return;
    }

    final speed = velocity.length;
    if (speed < 0.8) {
      return;
    }

    final spinMag = angularVelocity.abs();
    final sleepRatio = (spinMag / cfg.sleepSpinReference).clamp(0.0, 1.0);
    final g = cfg.gyroStability.clamp(0.12, 0.99);
    final unstable = ((1.0 - sleepRatio) * (1.0 - g)).clamp(0.0, 1.0);

    final spinEff = spinMag + cfg.precessionSpinEpsilon;
    _precessionPhase +=
        dt * cfg.precessionPhaseDrive / spinEff * (0.38 + unstable * 0.62);
    _nutationPhase += dt * cfg.nutationFrequency;

    final velDir = velocity / speed;
    final perp = Vector2(-velDir.y, velDir.x);

    if (unstable > 0.004) {
      final wobble = unstable;
      final pre = sin(_precessionPhase) * cfg.precessionAccelMax * wobble;
      final nut =
          sin(_nutationPhase * cfg.nutationHarmonic) *
          cfg.nutationAccelMax *
          wobble *
          cfg.nutationMix;

      var dv = perp * (pre + nut) * dt;
      final maxDv = cfg.maxTopAccelPerFrame * dt;
      if (dv.length > maxDv) {
        dv = dv.normalized() * maxDv;
      }
      velocity += dv;
    }

    if (sleepRatio > 0.52) {
      final side = velocity.dot(perp);
      velocity -= perp * (side * cfg.riseAlignStrength * sleepRatio * dt);
    }

    final cap = _maxSpeed * 1.08;
    if (velocity.length > cap) {
      velocity.normalize();
      velocity *= cap;
    }
  }

  void configureBuildVisual(SpinnerBuildStats buildStats) {
    _coreColor = buildStats.coreColor;
    _ringColor = buildStats.ringColor;
    _bladeColor = buildStats.bladeColor;
    _glowColor = buildStats.glowColor;

    _bladeReachBase = buildStats.bladeReach.clamp(0.0, 14.0).toDouble();
    _bladeDamageBonus = buildStats.bladeDamageBonus.clamp(1.0, 1.6).toDouble();
    _bladeShape = buildStats.bladeShape;
    _applyBladeStanceReach();
  }
}
