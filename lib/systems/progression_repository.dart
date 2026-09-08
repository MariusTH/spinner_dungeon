import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'upgrade_system.dart';

abstract class ProgressRepository {
  Future<MetaProgress> load();

  Future<void> save(MetaProgress progress);
}

class SharedPreferencesProgressRepository implements ProgressRepository {
  SharedPreferencesProgressRepository({this.storageKey = _defaultStorageKey});

  static const String _defaultStorageKey = 'ssc_meta_progress_v1';

  final String storageKey;

  @override
  Future<MetaProgress> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = prefs.getString(storageKey);
      if (payload == null || payload.isEmpty) {
        return MetaProgress.defaults();
      }

      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return MetaProgress.defaults();
      }

      return MetaProgress.fromJson(decoded);
    } catch (_) {
      return MetaProgress.defaults();
    }
  }

  @override
  Future<void> save(MetaProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(progress.toJson());
    await prefs.setString(storageKey, payload);
  }
}
