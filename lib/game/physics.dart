import 'dart:math';

import 'package:flame/components.dart';

class PhysicsModel {
  const PhysicsModel._();

  static void integrate(
    PositionComponent component,
    Vector2 velocity,
    double dt,
  ) {
    component.position += velocity * dt;
  }

  static Vector2 applyFriction(Vector2 velocity, double friction, double dt) {
    final clampedFriction = friction.clamp(0.0001, 0.9999);
    final decay = pow(clampedFriction, dt).toDouble();
    return velocity * decay;
  }

  static Vector2 reflect(Vector2 velocity, Vector2 normal) {
    if (normal.length2 == 0) {
      return velocity.clone();
    }

    final n = normal.normalized();
    return velocity - n * (2 * velocity.dot(n));
  }
}
