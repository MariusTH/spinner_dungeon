import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract class RunSnapshotRepository {
  Future<Map<String, dynamic>?> load();

  Future<void> save(Map<String, dynamic> snapshot);

  Future<void> clear();
}

class SharedPreferencesRunSnapshotRepository implements RunSnapshotRepository {
  SharedPreferencesRunSnapshotRepository({
    this.storageKey = _defaultStorageKey,
  });

  static const String _defaultStorageKey = 'ssc_run_snapshot_v1';

  final String storageKey;

  @override
  Future<Map<String, dynamic>?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = prefs.getString(storageKey);
      if (payload == null || payload.isEmpty) {
        return null;
      }

      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return decoded;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(Map<String, dynamic> snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(snapshot);
    await prefs.setString(storageKey, payload);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }
}
