import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../shared/models/app_settings.dart';

/// User preferences. Read synchronously from Hive on build so the first frame
/// already reflects the stored values; every mutation writes through.
class SettingsViewModel extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsDaoProvider).read();

  Future<void> _update(AppSettings next) async {
    state = next;
    await ref.read(settingsDaoProvider).write(next);
  }

  Future<void> setDefaultSpeaker(bool value) =>
      _update(state.copyWith(defaultSpeaker: value));

  Future<void> setAutoAnswer(bool value) =>
      _update(state.copyWith(autoAnswer: value));

  Future<void> setVibrate(bool value) =>
      _update(state.copyWith(vibrate: value));

  Future<void> setRingtone(String value) =>
      _update(state.copyWith(ringtone: value));

  /// `null` restores "follow the system locale".
  Future<void> setLanguage(String? code) => _update(
    code == null
        ? state.copyWith(clearLanguage: true)
        : state.copyWith(languageCode: code),
  );
}
