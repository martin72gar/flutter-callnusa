import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../../shared/models/app_settings.dart';

class SettingsDao {
  SettingsDao(this._box);

  static const String _key = 'app_settings';
  final Box<dynamic> _box;

  AppSettings read() {
    final raw = _box.get(_key);
    return raw == null
        ? const AppSettings()
        : AppSettings.fromJson(raw as Map<dynamic, dynamic>);
  }

  Future<void> write(AppSettings settings) => _box.put(_key, settings.toJson());
}
