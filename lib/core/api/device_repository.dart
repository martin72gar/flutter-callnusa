import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import '../../shared/models/device.dart';
import '../diagnostics/logger.dart';
import '../secure_storage/secure_storage_service.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

/// Registers this installation and its push tokens with the backend.
class DeviceRepository {
  DeviceRepository(this._api, this._storage);

  final ApiClient _api;
  final SecureStorageService _storage;

  Future<void> registerPushToken({
    required String pushToken,
    String? voipToken,
  }) async {
    final info = await PackageInfo.fromPlatform();
    final registration = DeviceRegistration(
      deviceId: await _storage.deviceId(),
      platform: Platform.isIOS ? 'ios' : 'android',
      appVersion: '${info.version}+${info.buildNumber}',
      pushToken: pushToken,
      pushProvider: Platform.isIOS ? PushProvider.apns : PushProvider.fcm,
      voipToken: voipToken,
    );
    await _api.put(ApiEndpoints.currentDevice, body: registration.toJson());
    // The token itself is a routing address, not a secret, but it is still
    // user-identifying: never log its value.
    log.info('push', 'device push token registered');
  }
}
