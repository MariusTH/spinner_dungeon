import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssc/systems/progression_repository.dart';
import 'package:ssc/systems/upgrade_system.dart';

void main() {
  const storageKey = 'test_progress';
  final repository = SharedPreferencesProgressRepository(
    storageKey: storageKey,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('load returns defaults when storage is empty', () async {
    final progress = await repository.load();

    expect(progress.bankedCoins, 0);
    expect(progress.bestScore, 0);
    expect(progress.totalRuns, 0);
    expect(progress.deepestLevelReached, 0);
  });

  test('save then load round-trips meta progress', () async {
    final seed = MetaProgress.defaults().copyWith(
      bankedCoins: 88,
      bestScore: 999,
      totalRuns: 7,
      deepestLevelReached: 4,
      tiers: <UpgradeType, int>{UpgradeType.launchCoil: 2},
    );

    await repository.save(seed);
    final loaded = await repository.load();

    expect(loaded.bankedCoins, 88);
    expect(loaded.bestScore, 999);
    expect(loaded.totalRuns, 7);
    expect(loaded.deepestLevelReached, 4);
    expect(loaded.tiers[UpgradeType.launchCoil], 2);
  });

  test('corrupt payload falls back to defaults', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      storageKey: 'not-json',
    });

    final loaded = await repository.load();
    expect(loaded.bankedCoins, 0);
    expect(UpgradeSystem.tierFor(loaded.tiers, UpgradeType.maxHp), 0);
  });
}
