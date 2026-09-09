/// App-wide constants that are genuinely fixed. Anything deployment-specific
/// belongs in `.env.<flavor>` instead — see [Env].
class AppConstants {
  const AppConstants._();

  static const String appName = 'CallNusa';
  static const String licenseName = 'GPL-3.0-only';

  // Platform channels exposed by the native Liblinphone binding.
  static const String linphoneMethodChannel = 'id.callnusa/linphone';
  static const String linphoneEventChannel = 'id.callnusa/linphone/events';

  // Hive boxes (non-secret data only).
  static const String callHistoryBox = 'call_history';
  static const String settingsBox = 'settings';

  // Secure storage keys.
  static const String kAccessToken = 'auth.access_token';
  static const String kRefreshToken = 'auth.refresh_token';
  static const String kUser = 'auth.user';
  static const String kSipConfig = 'sip.config';
  static const String kDeviceId = 'device.id';

  // SIP registration backoff (PRD 6.3).
  static const Duration registerBackoffInitial = Duration(seconds: 1);
  static const Duration registerBackoffMax = Duration(seconds: 60);

  /// Provisioning is refetched on resume, but no more than once per window.
  static const Duration provisioningMinInterval = Duration(minutes: 5);

  static const int historyPageSize = 50;
  static const int localHistoryLimit = 500;
}
