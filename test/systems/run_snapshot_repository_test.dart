import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssc/systems/run_snapshot_repository.dart';

void main() {
  const storageKey = 'test_run_snapshot';
  final repository = SharedPreferencesRunSnapshotRepository(
    storageKey: storageKey,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('load returns null when no snapshot exists', () async {
    final snapshot = await repository.load();
    expect(snapshot, isNull);
  });

  test('save and load round-trips snapshot payload', () async {
    final payload = <String, dynamic>{
      'schema': 1,
      'runPhase': 0,
      'spinsRemaining': 12,
      'spinner': <String, dynamic>{'x': 10.0, 'y': 12.0},
    };

    await repository.save(payload);
    final loaded = await repository.load();

    expect(loaded, isNotNull);
    expect(loaded!['schema'], 1);
    expect(loaded['spinsRemaining'], 12);
    expect((loaded['spinner'] as Map<String, dynamic>)['x'], 10.0);
  });

  test('clear removes saved snapshot', () async {
    await repository.save(<String, dynamic>{'schema': 1});
    await repository.clear();
    final loaded = await repository.load();
    expect(loaded, isNull);
  });
}
