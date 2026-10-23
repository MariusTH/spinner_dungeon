import 'package:flutter_test/flutter_test.dart';
import 'package:ssc/systems/trick_shot_system.dart';

void main() {
  test('a plain first kill has no callout or bonus', () {
    final t = TrickShotTracker()..onLaunch();
    final kill = t.onKill();
    expect(kill.callouts, isEmpty);
    expect(kill.bonusCoins, 0);
    expect(kill.scoreMultiplier, 1.0);
  });

  test('a kill after a bounce is a bank shot', () {
    final t = TrickShotTracker()
      ..onLaunch()
      ..onBank();
    final kill = t.onKill();
    expect(kill.callouts, ['BANK SHOT!']);
    expect(kill.bonusCoins, 1);
    expect(kill.scoreMultiplier, 1.5);
  });

  test('three bounces upgrade to ricochet', () {
    final t = TrickShotTracker()
      ..onLaunch()
      ..onBank()
      ..onBank()
      ..onBank();
    expect(t.onKill().callouts, ['RICOCHET!']);
  });

  test('multi-kills escalate and reset on launch', () {
    final t = TrickShotTracker()..onLaunch();
    t.onKill();
    expect(t.onKill().callouts, ['DOUBLE!']);
    expect(t.onKill().callouts, ['TRIPLE!']);
    final fourth = t.onKill();
    expect(fourth.callouts, ['CARNAGE!']);
    expect(fourth.bonusCoins, 3);

    t.onLaunch();
    expect(t.kills, 0);
    expect(t.banks, 0);
    expect(t.onKill().callouts, isEmpty);
  });

  test('combo only drains while the spinner rests', () {
    final c = ComboTracker()
      ..onKill()
      ..onKill();
    expect(c.count, 2);
    expect(c.tick(10, draining: false), isNull);
    expect(c.count, 2);
    expect(c.tick(1, draining: true), isNull);
    c.onKill();
    expect(c.fraction, 1.0);
    expect(c.tick(ComboTracker.window + 0.1, draining: true), 3);
    expect(c.count, 0);
    expect(c.multiplier, 1.0);
  });

  test('combo payout skips tiny combos', () {
    expect(ComboTracker.payoutCoins(2), 0);
    expect(ComboTracker.payoutCoins(3), 1);
    expect(ComboTracker.payoutCoins(10), 5);
  });

  test('floor pace tiers against par', () {
    final par = FloorPace.parSeconds(4);
    expect(
      FloorPace.tierFor(elapsedSeconds: par * 0.5, roomCount: 4),
      FloorPaceTier.blazing,
    );
    expect(
      FloorPace.tierFor(elapsedSeconds: par * 0.9, roomCount: 4),
      FloorPaceTier.speedy,
    );
    expect(
      FloorPace.tierFor(elapsedSeconds: par * 1.2, roomCount: 4),
      FloorPaceTier.none,
    );
  });
}
