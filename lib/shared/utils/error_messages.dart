import '../../l10n/app_localizations.dart';
import '../models/app_exception.dart';
import '../../core/sip/sip_models.dart';

/// Maps errors to localized, user-facing text (PRD 6.8).
///
/// Backend error codes take priority over the transport-level category so the
/// user sees the most specific message the server was able to give.
String messageFor(AppLocalizations l10n, Object? error) {
  if (error is AppException) {
    return switch (error.code) {
      'AUTH_INVALID_CREDENTIALS' => l10n.errorInvalidCredentials,
      'AUTH_SESSION_EXPIRED' => l10n.errorSessionExpired,
      'AUTH_ACCOUNT_DISABLED' => l10n.errorAccountDisabled,
      'PROVISIONING_NO_EXTENSION' => l10n.errorNoExtension,
      'PROVISIONING_INVALID_CONFIG' => l10n.errorInvalidConfig,
      'DEVICE_LIMIT_EXCEEDED' => l10n.errorDeviceLimit,
      'MIC_PERMISSION_DENIED' => l10n.errorMicPermission,
      'NETWORK_UNAVAILABLE' => l10n.errorNetwork,
      _ => switch (error.kind) {
        AppErrorKind.network => l10n.errorNetwork,
        AppErrorKind.timeout => l10n.errorTimeout,
        AppErrorKind.unauthorized => l10n.errorSessionExpired,
        AppErrorKind.server => l10n.errorServer,
        AppErrorKind.sip => l10n.errorSipRegistration,
        AppErrorKind.notFound => l10n.errorNotFound,
        _ => l10n.errorUnknown,
      },
    };
  }
  return l10n.errorUnknown;
}

/// Why the last call ended, in words.
String callEndMessage(AppLocalizations l10n, CallEndReason? reason) =>
    switch (reason) {
      CallEndReason.busy => l10n.errorBusy,
      CallEndReason.notFound => l10n.errorNotFound,
      CallEndReason.error => l10n.errorCallFailed,
      _ => l10n.callEnded,
    };
