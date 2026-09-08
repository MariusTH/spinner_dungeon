import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssc/input/spin_gesture_detector.dart';

void main() {
  test('low spin launch can still trigger with a direction', () {
    final launch = SpinLaunchData(
      launchDirection: Vector2(1, 0),
      spinStrength: 0.03,
      signedAngularVelocity: 0.03,
      turns: 0,
    );

    expect(launch.hasLaunch, isTrue);
  });

  test('launch requires a minimum spin threshold', () {
    final launch = SpinLaunchData(
      launchDirection: Vector2(1, 0),
      spinStrength: 0.01,
      signedAngularVelocity: 0.01,
      turns: 0,
    );

    expect(launch.hasLaunch, isFalse);
  });

  test('launch requires a non-zero direction', () {
    final launch = SpinLaunchData(
      launchDirection: Vector2.zero(),
      spinStrength: 0.4,
      signedAngularVelocity: 0.4,
      turns: 0.2,
    );

    expect(launch.hasLaunch, isFalse);
  });
}
