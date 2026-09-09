import 'package:meta/meta.dart';

/// Payload for `PUT /api/v1/devices/current`. Field names are what the
/// backend validates (`device_uid`, not `device_id`); unknown keys are dropped.
@immutable
class DeviceRegistration {
  const DeviceRegistration({
    required this.deviceUid,
    required this.platform,
    required this.appVersion,
    this.pushToken,
  });

  final String deviceUid;
  final String platform; // android | ios
  final String appVersion;
  final String? pushToken;

  Map<String, dynamic> toJson() => {
    'device_uid': deviceUid,
    'platform': platform,
    'app_version': appVersion,
    'push_token': pushToken,
  };
}
