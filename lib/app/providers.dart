import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/auth/auth_service.dart';
import '../core/auth/auth_state.dart';
import '../core/database/daos/call_history_dao.dart';
import '../core/database/daos/settings_dao.dart';
import '../core/notification/callkit_service.dart';
import '../core/sip/call_controller.dart';
import '../core/sip/sip_models.dart';
import '../core/sip/sip_service.dart';
import '../features/provisioning/provisioning_service.dart';
import '../features/provisioning/provisioning_state.dart';
import '../features/settings/settings_view_model.dart';
import '../shared/models/app_settings.dart';
import '../shared/models/call_history_entry.dart';
import 'bootstrap.dart';

/// Overridden in `main()` with the result of [AppDependencies.create].
final dependenciesProvider = Provider<AppDependencies>(
  (_) => throw UnimplementedError('dependenciesProvider must be overridden'),
);

// ---- Infrastructure ------------------------------------------------------

final apiClientProvider = Provider<ApiClient>(
  (ref) => ref.watch(dependenciesProvider).api,
);

final authServiceProvider = Provider<AuthService>(
  (ref) => ref.watch(dependenciesProvider).auth,
);

final sipServiceProvider = Provider<SipService>(
  (ref) => ref.watch(dependenciesProvider).sip,
);

final callKitServiceProvider = Provider<CallKitService>(
  (ref) => ref.watch(dependenciesProvider).callKit,
);

final provisioningServiceProvider = Provider<ProvisioningService>(
  (ref) => ref.watch(dependenciesProvider).provisioning,
);

final callHistoryDaoProvider = Provider<CallHistoryDao>(
  (ref) => ref.watch(dependenciesProvider).callHistoryDao,
);

final settingsDaoProvider = Provider<SettingsDao>(
  (ref) => ref.watch(dependenciesProvider).settingsDao,
);

final appVersionProvider = Provider<String>(
  (ref) => ref.watch(dependenciesProvider).appVersion,
);

// ---- Session -------------------------------------------------------------

/// Current auth state. Seeded with the service's value so the first frame does
/// not flash an `initial` state that has already been resolved.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final service = ref.watch(authServiceProvider);
  return service.stream.startWith(service.state);
});

final provisioningStreamProvider = StreamProvider<ProvisioningState>((ref) {
  final service = ref.watch(provisioningServiceProvider);
  return service.stream.startWith(service.state);
});

/// Synchronous view of provisioning, with a safe default before it loads.
final provisioningStateProvider = Provider<ProvisioningState>(
  (ref) =>
      ref.watch(provisioningStreamProvider).value ?? const ProvisioningState(),
);

// ---- SIP -----------------------------------------------------------------

final sipStatusProvider = StreamProvider<SipRegistrationStatus>((ref) {
  final sip = ref.watch(sipServiceProvider);
  return sip.statusStream.startWith(sip.status);
});

/// When the next registration retry is due, so the UI can count down.
final sipRetryAtProvider = StreamProvider<DateTime?>(
  (ref) => ref.watch(sipServiceProvider).retryAtStream,
);

final activeCallProvider = NotifierProvider<CallController, ActiveCallState>(
  CallController.new,
);

// ---- Data ----------------------------------------------------------------

final callHistoryProvider = StreamProvider<List<CallHistoryEntry>>(
  (ref) => ref.watch(callHistoryDaoProvider).watch(),
);

final historyFilterProvider =
    NotifierProvider<HistoryFilterController, HistoryFilter>(
      HistoryFilterController.new,
    );

class HistoryFilterController extends Notifier<HistoryFilter> {
  @override
  HistoryFilter build() => HistoryFilter.all;

  void select(HistoryFilter filter) => state = filter;
}

final settingsProvider = NotifierProvider<SettingsViewModel, AppSettings>(
  SettingsViewModel.new,
);

// ---- Helpers -------------------------------------------------------------

extension _StartWith<T> on Stream<T> {
  /// Prepends the current value so late listeners see state immediately.
  Stream<T> startWith(T value) async* {
    yield value;
    yield* this;
  }
}
