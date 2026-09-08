import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

enum WallSide { left, right, top, bottom }

class WallComponent extends RectangleComponent with CollisionCallbacks {
  WallComponent({
    required this.side,
    required super.position,
    required super.size,
  }) : super(
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0x00000000),
       );

  final WallSide side;

  Vector2 get normal {
    switch (side) {
      case WallSide.left:
        return Vector2(1, 0);
      case WallSide.right:
        return Vector2(-1, 0);
      case WallSide.top:
        return Vector2(0, 1);
      case WallSide.bottom:
        return Vector2(0, -1);
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }
}
