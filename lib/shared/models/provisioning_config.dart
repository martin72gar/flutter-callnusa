import 'package:meta/meta.dart';

import 'sip_config.dart';

@immutable
class SipAccount {
  const SipAccount({
    required this.id,
    required this.displayName,
    required this.extension,
  });

  final String id;
  final String displayName;
  final String extension;

  factory SipAccount.fromJson(Map<String, dynamic> json) => SipAccount(
    id: '${json['id']}',
    displayName: json['display_name'] as String? ?? '',
    extension: json['extension'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'display_name': displayName,
    'extension': extension,
  };
}

/// Backend-controlled feature switches. Unknown keys are ignored so the app
/// keeps working when the backend adds flags.
@immutable
class FeatureFlags {
  const FeatureFlags({
    this.outboundCalling = true,
    this.callRecordingNotice = false,
    this.video = false,
    this.chat = false,
  });

  final bool outboundCalling;
  final bool callRecordingNotice;
  final bool video;
  final bool chat;

  factory FeatureFlags.fromJson(Map<String, dynamic> json) => FeatureFlags(
    outboundCalling: json['outbound_calling'] as bool? ?? true,
    callRecordingNotice: json['call_recording_notice'] as bool? ?? false,
    video: json['video'] as bool? ?? false,
    chat: json['chat'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'outbound_calling': outboundCalling,
    'call_recording_notice': callRecordingNotice,
    'video': video,
    'chat': chat,
  };
}

@immutable
class DevicePolicy {
  const DevicePolicy({
    this.defaultSpeaker = false,
    this.maxRegisteredDevices = 1,
    this.dialingPrefix,
  });

  final bool defaultSpeaker;
  final int maxRegisteredDevices;

  /// Prefix the backend wants prepended to external numbers, if any.
  /// The app never invents its own dialing rules (PRD 6.4).
  final String? dialingPrefix;

  factory DevicePolicy.fromJson(Map<String, dynamic> json) => DevicePolicy(
    defaultSpeaker: json['default_speaker'] as bool? ?? false,
    maxRegisteredDevices:
        (json['max_registered_devices'] as num?)?.toInt() ?? 1,
    dialingPrefix: json['dialing_prefix'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'default_speaker': defaultSpeaker,
    'max_registered_devices': maxRegisteredDevices,
    'dialing_prefix': dialingPrefix,
  };
}

@immutable
class ProvisioningConfig {
  const ProvisioningConfig({
    required this.account,
    required this.sip,
    required this.features,
    required this.policy,
  });

  final SipAccount account;
  final SipConfig sip;
  final FeatureFlags features;
  final DevicePolicy policy;

  factory ProvisioningConfig.fromJson(
    Map<String, dynamic> json, {
    int defaultExpiry = 600,
  }) {
    final data = (json['data'] as Map?)?.cast<String, dynamic>() ?? json;
    return ProvisioningConfig(
      account: SipAccount.fromJson(
        (data['account'] as Map).cast<String, dynamic>(),
      ),
      sip: SipConfig.fromJson(
        (data['sip'] as Map).cast<String, dynamic>(),
        defaultExpiry: defaultExpiry,
      ),
      features: FeatureFlags.fromJson(
        (data['features'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      policy: DevicePolicy.fromJson(
        (data['policy'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'account': account.toJson(),
    'sip': sip.toJson(),
    'features': features.toJson(),
    'policy': policy.toJson(),
  };

  @override
  String toString() => 'ProvisioningConfig(ext=${account.extension}, $sip)';
}
