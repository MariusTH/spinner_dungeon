import 'package:flame/components.dart';

import '../game/physics.dart';

class CollisionSystem {
  const CollisionSystem._();

  static Vector2 bounce({
    required Vector2 velocity,
    required Vector2 normal,
    double restitution = 0.92,
  }) {
    return PhysicsModel.reflect(velocity, normal) * restitution;
  }

  static Vector2 directionAwayFrom({
    required Vector2 from,
    required Vector2 to,
  }) {
    final delta = to - from;
    if (delta.length2 == 0) {
      return Vector2.zero();
    }

    return delta.normalized();
  }
}
