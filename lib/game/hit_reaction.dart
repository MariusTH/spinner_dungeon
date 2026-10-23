import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// White flash + small jitter when something is hit. Mix into any component
/// and call [triggerHitReaction]; the whole render tree (body, HP bar, child
/// effects) is tinted white for a moment and shaken in place. Purely visual:
/// position and hitboxes never move.
///
/// The timer runs on real frame time, so the flash also plays through
/// hit-stop (when the world is frozen), which is where it reads best.
mixin HitReaction on PositionComponent {
  static const double _duration = 0.2;
  static final Random _random = Random();

  double _hitRemaining = 0;
  double _hitStrength = 1;

  /// [strength] scales the jitter (1 = normal hit, 2 = heavy).
  void triggerHitReaction({double strength = 1}) {
    // Overlapping hits keep the strongest jitter.
    _hitStrength = _hitRemaining > 0 ? max(_hitStrength, strength) : strength;
    _hitRemaining = _duration;
  }

  /// 0..1, 1 right after a hit.
  double get hitReactionAmount => (_hitRemaining / _duration).clamp(0.0, 1.0);

  @override
  void update(double dt) {
    super.update(dt);
    if (_hitRemaining > 0) {
      _hitRemaining = max(0, _hitRemaining - dt);
    }
  }

  @override
  void renderTree(Canvas canvas) {
    final t = hitReactionAmount;
    if (t <= 0) {
      super.renderTree(canvas);
      return;
    }
    final amp = 3.2 * _hitStrength * t;
    canvas.save();
    canvas.translate(
      (_random.nextDouble() * 2 - 1) * amp,
      (_random.nextDouble() * 2 - 1) * amp,
    );
    // Generous bounds: blades, spikes and HP bars draw outside the hitbox.
    final bounds = toRect().inflate(max(size.x, size.y) + 24);
    canvas.saveLayer(bounds, Paint());
    super.renderTree(canvas);
    // Hold full white for the first half, then fade back to normal colours.
    final flash = t > 0.5 ? 0.95 : 0.95 * (t / 0.5);
    canvas.drawRect(
      bounds,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: flash)
        ..blendMode = BlendMode.srcATop,
    );
    canvas.restore();
    canvas.restore();
  }
}
