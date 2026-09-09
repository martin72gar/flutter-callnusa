import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../config/constants.dart';
import '../../shared/models/sip_config.dart';
import '../../shared/models/user.dart';
import '../diagnostics/logger.dart';

/// The only place credentials touch persistent storage.
///
/// Backed by the Android keystore (EncryptedSharedPreferences) and the iOS
/// keychain, so nothing here is readable from a device backup or by another app.
class SecureStorageService {
  SecureStorageService([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // Android encrypts through the keystore by default in v10+.
            // `first_unlock` lets the keychain be read after a reboot, so a
            // VoIP push can register SIP before the user unlocks the phone.
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;

  Future<String?> get accessToken =>
      _storage.read(key: AppConstants.kAccessToken);

  Future<String?> get refreshToken =>
      _storage.read(key: AppConstants.kRefreshToken);

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    log.registerSecret(accessToken);
    log.registerSecret(refreshToken);
    await _storage.write(key: AppConstants.kAccessToken, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(
        key: AppConstants.kRefreshToken,
        value: refreshToken,
      );
    }
  }

  Future<User?> readUser() async {
    final raw = await _storage.read(key: AppConstants.kUser);
    if (raw == null) return null;
    return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveUser(User user) =>
      _storage.write(key: AppConstants.kUser, value: jsonEncode(user.toJson()));

  Future<SipConfig?> readSipConfig() async {
    final raw = await _storage.read(key: AppConstants.kSipConfig);
    if (raw == null) return null;
    final config = SipConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    log.registerSecret(config.password);
    return config;
  }

  Future<void> saveSipConfig(SipConfig config) async {
    log.registerSecret(config.password);
    await _storage.write(
      key: AppConstants.kSipConfig,
      value: jsonEncode(config.toJson()),
    );
  }

  /// Stable per-installation identifier sent as `X-Device-Id`. Generated on
  /// first use; it is not a hardware id, so it resets on reinstall by design.
  Future<String> deviceId() async {
    final existing = await _storage.read(key: AppConstants.kDeviceId);
    if (existing != null) return existing;
    final generated = const Uuid().v4();
    await _storage.write(key: AppConstants.kDeviceId, value: generated);
    return generated;
  }

  /// Wipes the session. [AppConstants.kDeviceId] survives so the backend can
  /// still recognise the installation on the next login.
  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: AppConstants.kAccessToken),
      _storage.delete(key: AppConstants.kRefreshToken),
      _storage.delete(key: AppConstants.kUser),
      _storage.delete(key: AppConstants.kSipConfig),
    ]);
    log.clearSecrets();
  }
}
