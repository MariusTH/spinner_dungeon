import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// Lenient pickup behaviour shared by coins and powerups.
///
/// Idle pickups give a little attention shake every so often. Once the
/// spinner comes within [attractRadius], the pickup shivers briefly, then
/// accelerates toward the spinner (always faster than it) and counts as
/// collected when it gets within [collectSlack] of the spinner's edge, so a
/// near miss still scoops it up.
class PickupMagnet {
  PickupMagnet({
    this.attractRadius = 150,
    this.collectSlack = 12,
    this.armDelay = 0,
  });

  final double attractRadius;
  final double collectSlack;

  /// Seconds before the magnet engages (lets a coin burst spread first).
  final double armDelay;

  static const double _shiverDuration = 0.12;
  static const double _idleShakeEvery = 1.6;
  static const double _idleShakeDuration = 0.22;
  static final Random _random = Random();

  double _age = 0;
  double _shiver = 0;
  bool _homing = false;
  double _speed = 0;
  late final double _idlePhase = _random.nextDouble() * _idleShakeEvery;

  bool get isHoming => _homing;

  /// Moves [pickup] and returns true once it should be collected.
  /// [rangeBoost] widens the attract radius (e.g. after a floor is cleared).
  bool update(
    double dt, {
    required PositionComponent pickup,
    required double pickupRadius,
    required Vector2? spinnerPosition,
    required double spinnerRadius,
    required double spinnerSpeed,
    double rangeBoost = 1,
  }) {
    _age += dt;
    if (spinnerPosition == null) {
      return false;
    }
    final delta = spinnerPosition - pickup.position;
    final dist = delta.length;
    if (dist <= spinnerRadius + pickupRadius + collectSlack) {
      return true;
    }
    if (_age < armDelay) {
      return false;
    }

    if (!_homing) {
      if (_shiver > 0) {
        _shiver -= dt;
        if (_shiver <= 0) {
          _homing = true;
          _speed = 160;
        }
      } else if (dist < attractRadius * rangeBoost) {
        _shiver = _shiverDuration;
      }
      return false;
    }

    // Accelerate, and never fall behind a fast-moving spinner.
    _speed = max(min(_speed + 2600 * dt, 1500), spinnerSpeed + 220);
    final step = min(_speed * dt, dist);
    pickup.position += delta / dist * step;
    return false;
  }

  /// Visual-only jitter to add when rendering.
  Offset shakeOffset() {
    if (_homing) {
      return Offset.zero;
    }
    double amp;
    if (_shiver > 0) {
      amp = 2.6;
    } else {
      final cycle = (_age + _idlePhase) % _idleShakeEvery;
      if (cycle > _idleShakeDuration) {
        return Offset.zero;
      }
      amp = 1.4 * sin(cycle / _idleShakeDuration * pi);
    }
    return Offset(
      (_random.nextDouble() * 2 - 1) * amp,
      (_random.nextDouble() * 2 - 1) * amp,
    );
  }
}
