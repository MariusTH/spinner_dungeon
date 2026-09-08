import 'dart:math';

import 'package:flame/components.dart';

class SpinLaunchData {
  SpinLaunchData({
    required this.launchDirection,
    required this.spinStrength,
    required this.signedAngularVelocity,
    required this.turns,
  });

  final Vector2 launchDirection;
  final double spinStrength;
  final double signedAngularVelocity;
  final double turns;

  bool get hasLaunch => spinStrength > 0.02 && launchDirection.length2 > 0;

  static SpinLaunchData empty() {
    return SpinLaunchData(
      launchDirection: Vector2.zero(),
      spinStrength: 0,
      signedAngularVelocity: 0,
      turns: 0,
    );
  }
}

class SpinGestureDetector {
  final List<_GestureSample> _samples = <_GestureSample>[];

  Vector2 _center = Vector2.zero();
  double _accumulatedRadians = 0;
  double _signedAngularVelocity = 0;
  bool _active = false;

  bool get isActive => _active;

  double get currentCharge {
    final turns = _accumulatedRadians / (2 * pi);
    return _signedAngularVelocity.abs() * (1 + turns * 0.25);
  }

  double get currentSignedAngularVelocity => _signedAngularVelocity;

  void start({
    required Vector2 pointerPosition,
    required Vector2 center,
    required double timestamp,
  }) {
    _active = true;
    _center = center.clone();
    _accumulatedRadians = 0;
    _signedAngularVelocity = 0;
    _samples
      ..clear()
      ..add(_GestureSample(pointerPosition.clone(), timestamp));
  }

  void update({required Vector2 pointerPosition, required double timestamp}) {
    if (!_active) {
      return;
    }

    final sample = _GestureSample(pointerPosition.clone(), timestamp);

    if (_samples.isNotEmpty) {
      final previous = _samples.last;
      final dt = (sample.time - previous.time).clamp(0.0001, 0.25);
      final previousToCenter = previous.position - _center;
      final currentToCenter = sample.position - _center;

      if (previousToCenter.length2 > 4 && currentToCenter.length2 > 4) {
        final delta = _signedAngle(previousToCenter, currentToCenter);
        _accumulatedRadians += delta.abs();

        final instantaneousAngularVelocity = (delta / dt).clamp(-20, 20);
        _signedAngularVelocity =
            (_signedAngularVelocity * 0.82) +
            (instantaneousAngularVelocity * 0.18);
      }
    }

    _samples.add(sample);
    if (_samples.length > 60) {
      _samples.removeAt(0);
    }
  }

  SpinLaunchData end({required double timestamp}) {
    if (!_active) {
      return SpinLaunchData.empty();
    }

    _active = false;

    if (_samples.isNotEmpty && _samples.last.time < timestamp) {
      _samples.add(_GestureSample(_samples.last.position.clone(), timestamp));
    }

    if (_samples.length < 2) {
      reset();
      return SpinLaunchData.empty();
    }

    final launchDirection = _estimateLaunchDirection();
    final turns = _accumulatedRadians / (2 * pi);
    final spinStrength = _signedAngularVelocity.abs() * (1 + turns * 0.25);

    final data = SpinLaunchData(
      launchDirection: launchDirection,
      spinStrength: spinStrength,
      signedAngularVelocity: _signedAngularVelocity,
      turns: turns,
    );

    reset();
    return data;
  }

  void reset() {
    _active = false;
    _accumulatedRadians = 0;
    _signedAngularVelocity = 0;
    _samples.clear();
  }

  Vector2 _estimateLaunchDirection() {
    if (_samples.length < 2) {
      return Vector2.zero();
    }

    final tailPairs = min(6, _samples.length - 1);
    var direction = Vector2.zero();
    var weight = 1.0;

    for (var i = _samples.length - tailPairs; i < _samples.length; i++) {
      final previous = _samples[i - 1];
      final current = _samples[i];
      direction += (current.position - previous.position) * weight;
      weight += 0.35;
    }

    if (direction.length2 == 0) {
      direction = _samples.last.position - _samples.first.position;
    }

    if (direction.length2 == 0) {
      return Vector2.zero();
    }

    return direction.normalized();
  }

  double _signedAngle(Vector2 from, Vector2 to) {
    final cross = (from.x * to.y) - (from.y * to.x);
    final dot = from.dot(to);
    return atan2(cross, dot);
  }
}

class _GestureSample {
  const _GestureSample(this.position, this.time);

  final Vector2 position;
  final double time;
}
