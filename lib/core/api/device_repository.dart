import 'dart:io';

import '../../shared/models/device.dart';
import '../diagnostics/logger.dart';
import '../secure_storage/secure_storage_service.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

/// Registers this installation and its push token with the backend.
class DeviceRepository {
  DeviceRepository(this._api, this._storage, {required this.appVersion});

  final ApiClient _api;
  final SecureStorageService _storage;
  final String appVersion;

  /// `PUT /devices/current` — on app start and on push-token rotation.
  /// Remembers the device's public id so it can be revoked on logout.
  Future<void> register({String? pushToken}) async {
    final registration = DeviceRegistration(
      deviceUid: await _storage.deviceId(),
      platform: Platform.isIOS ? 'ios' : 'android',
      appVersion: appVersion,
      pushToken: pushToken,
    );
    final response = await _api.put(
      ApiEndpoints.currentDevice,
      body: registration.toJson(),
    );
    final publicId = (response['data'] as Map?)?['public_id'] as String?;
    if (publicId != null) await _storage.saveDevicePublicId(publicId);
    // The token is user-identifying: never log its value.
    log.info('push', 'device registered (push token: ${pushToken != null})');
  }

  /// `DELETE /devices/{publicId}` on logout. The backend permanently marks
  /// the `device_uid` as revoked (DEVICE_UNAVAILABLE afterwards), so the
  /// local device id is rotated as well; the next login is a fresh device.
  Future<void> revokeCurrent() async {
    final publicId = await _storage.devicePublicId;
    if (publicId != null) {
      try {
        await _api.delete(ApiEndpoints.device(publicId));
      } catch (e) {
        log.warn('push', 'remote device revoke failed: $e');
      }
    }
    await _storage.rotateDeviceId();
  }
}
