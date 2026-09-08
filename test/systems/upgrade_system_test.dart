import 'package:flutter_test/flutter_test.dart';
import 'package:ssc/systems/upgrade_system.dart';

void main() {
  test('apply computes stat bundle from tiers', () {
    final upgrades = UpgradeSystem.apply({
      UpgradeType.maxHp: 2,
      UpgradeType.damageBoost: 3,
      UpgradeType.spinReserve: 2,
      UpgradeType.gyroBearing: 1,
      UpgradeType.launchCoil: 2,
      UpgradeType.guardPlating: 2,
      UpgradeType.fortuneSigil: 2,
      UpgradeType.emergencyGrapple: 3,
      UpgradeType.flightStabilizer: 2,
    });

    expect(upgrades.maxHp, 110);
    expect(upgrades.damageMultiplier, closeTo(1.3, 0.0001));
    expect(upgrades.startingSpinsBonus, 2);
    expect(upgrades.frictionRetention, closeTo(0.88, 0.0001));
    expect(upgrades.launchSpeedMultiplier, closeTo(1.1, 0.0001));
    expect(upgrades.incomingDamageMultiplier, closeTo(0.84, 0.0001));
    expect(upgrades.coinMultiplier, closeTo(1.24, 0.0001));
    expect(upgrades.pitSaves, 2);
    expect(upgrades.pitSkimMinSpeed, 600);
    expect(upgrades.pitSkimMaxRadius, 20);
    expect(upgrades.pitHoverSeconds, closeTo(0.18, 0.0001));
  });

  test('purchase spends coins and respects max tier', () {
    var progress = MetaProgress.defaults().copyWith(bankedCoins: 1000);

    for (var i = 0; i < 6; i++) {
      progress = UpgradeSystem.purchase(progress, UpgradeType.maxHp);
    }

    expect(UpgradeSystem.tierFor(progress.tiers, UpgradeType.maxHp), 6);
    expect(UpgradeSystem.costForNextTier(progress, UpgradeType.maxHp), isNull);

    final afterCap = UpgradeSystem.purchase(progress, UpgradeType.maxHp);
    expect(UpgradeSystem.tierFor(afterCap.tiers, UpgradeType.maxHp), 6);
    expect(afterCap.bankedCoins, progress.bankedCoins);
  });
}
