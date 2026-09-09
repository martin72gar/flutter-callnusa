import 'package:meta/meta.dart';

import '../../shared/models/app_exception.dart';
import '../../shared/models/provisioning_config.dart';

enum ProvisioningStatus { idle, loading, ready, failed }

@immutable
class ProvisioningState {
  const ProvisioningState({
    this.status = ProvisioningStatus.idle,
    this.config,
    this.error,
  });

  final ProvisioningStatus status;
  final ProvisioningConfig? config;
  final AppException? error;

  bool get isReady => status == ProvisioningStatus.ready && config != null;

  /// Convenience accessors used across the UI; safe defaults keep screens
  /// renderable before provisioning has completed.
  bool get canDialOut => config?.features.outboundCalling ?? false;
  bool get showsRecordingNotice =>
      config?.features.callRecordingNotice ?? false;
  String? get extension => config?.account.extension;
}
