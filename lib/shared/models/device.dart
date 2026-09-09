import 'package:meta/meta.dart';

enum PushProvider { fcm, apns }

/// Payload for `PUT /api/v1/devices/current`.
@immutable
class DeviceRegistration {
  const DeviceRegistration({
    required this.deviceId,
    required this.platform,
    required this.appVersion,
    required this.pushToken,
    required this.pushProvider,
    this.voipToken,
    this.model,
  });

  final String deviceId;
  final String platform; // android | ios
  final String appVersion;
  final String pushToken;
  final PushProvider pushProvider;

  /// iOS only: PushKit token used for VoIP wake-ups (PRD 6.5).
  final String? voipToken;
  final String? model;

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'platform': platform,
    'app_version': appVersion,
    'push_token': pushToken,
    'push_provider': pushProvider.name,
    if (voipToken != null) 'voip_token': voipToken,
    if (model != null) 'model': model,
  };
}
