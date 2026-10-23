import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'hit_reaction.dart';
import 'rendering/prop_painters.dart';
import 'spinner_component.dart';
import 'spinner_game.dart';

class ChestComponent extends RectangleComponent
    with CollisionCallbacks, HasGameReference<SpinnerGame>, HitReaction {
  ChestComponent({required Vector2 position, required this.coinReward})
    : super(
        position: position,
        size: Vector2(30, 24),
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0xFFC28D2E),
      );

  final int coinReward;
  bool isOpened = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x * 0.5, size.y * 0.5);

    paintChest(
      canvas,
      width: size.x * 1.3,
      height: size.y * 1.25,
      opened: isOpened,
    );
    canvas.restore();
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (isOpened) {
      return;
    }

    if (other is SpinnerComponent) {
      open();
      game.onChestOpened(this);
    }
  }

  /// [react] is false when restoring a saved run, so no flash plays on load.
  void open({bool react = true}) {
    isOpened = true;
    if (react) {
      triggerHitReaction(strength: 1.5);
    }
    paint.color = const Color(0xFF737780);
  }
}
