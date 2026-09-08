import 'package:flame/components.dart';

class CombatSystem {
  const CombatSystem._();

  static double damageFromSpeed({
    required double baseDamage,
    required double speed,
  }) {
    return baseDamage * speed;
  }

  /// Spinner body impact: linear speed term + per-hit chip so weak launches still feel meaty.
  /// [earlyLevelFactor] boosts dungeon levels 1–3 (e.g. 1.24 on level 1).
  static double spinnerImpactDamage({
    required double speed,
    required double damageMultiplier,
    double earlyLevelFactor = 1.0,
  }) {
    const basePerSpeed = 0.052;
    const chipPerMult = 0.78;
    final linear = basePerSpeed * speed * damageMultiplier;
    final chip = chipPerMult * damageMultiplier;
    return (linear + chip) * earlyLevelFactor;
  }

  static Vector2 knockback({
    required Vector2 direction,
    required double force,
  }) {
    if (direction.length2 == 0) {
      return Vector2.zero();
    }

    return direction.normalized() * force;
  }
}
