import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../config/constants.dart';

/// Local, **non-secret** persistence: call history cache and user settings.
///
/// Secrets never come near Hive — they live in [SecureStorageService].
/// Plain JSON maps are stored instead of generated type adapters: the schema is
/// small and the app already needs `toJson`/`fromJson` for the REST API.
class AppDatabase {
  AppDatabase._(this.history, this.settings);

  final Box<dynamic> history;
  final Box<dynamic> settings;

  static AppDatabase? _instance;
  static AppDatabase get instance {
    final db = _instance;
    if (db == null) {
      throw StateError('AppDatabase.open() must be awaited before use');
    }
    return db;
  }

  static Future<AppDatabase> open() async {
    if (_instance != null) return _instance!;
    await Hive.initFlutter();
    _instance = AppDatabase._(
      await Hive.openBox<dynamic>(AppConstants.callHistoryBox),
      await Hive.openBox<dynamic>(AppConstants.settingsBox),
    );
    return _instance!;
  }

  /// Called on logout: history is user data and must not survive the session.
  Future<void> clearUserData() async {
    await history.clear();
  }

  Future<void> close() async {
    await Hive.close();
    _instance = null;
  }
}
