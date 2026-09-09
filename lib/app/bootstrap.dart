import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/env.dart';
import '../core/api/api_client.dart';
import '../core/api/device_repository.dart';
import '../core/auth/auth_repository.dart';
import '../core/auth/auth_service.dart';
import '../core/database/app_database.dart';
import '../core/database/daos/call_history_dao.dart';
import '../core/database/daos/settings_dao.dart';
import '../core/diagnostics/logger.dart';
import '../core/notification/callkit_service.dart';
import '../core/notification/push_service.dart';
import '../core/secure_storage/secure_storage_service.dart';
import '../core/sip/linphone_service.dart';
import '../core/sip/sip_service.dart';
import '../features/provisioning/provisioning_service.dart';

/// Everything the app needs, constructed once at startup and injected into the
/// Riverpod container. Building the object graph here (rather than lazily
/// inside providers) keeps the wiring — including the two dependency cycles
/// below — explicit and testable.
class AppDependencies {
  AppDependencies._({
    required this.appVersion,
    required this.storage,
    required this.database,
    required this.api,
    required this.auth,
    required this.provisioning,
    required this.sip,
    required this.push,
    required this.callKit,
    required this.callHistoryDao,
    required this.settingsDao,
  });

  final String appVersion;
  final SecureStorageService storage;
  final AppDatabase database;
  final ApiClient api;
  final AuthService auth;
  final ProvisioningService provisioning;
  final SipService sip;
  final PushService push;
  final CallKitService callKit;
  final CallHistoryDao callHistoryDao;
  final SettingsDao settingsDao;

  static Future<AppDependencies> create({Flavor? flavor}) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Env.load(flavor);
    await log.enableFileLogging();
    log.info('boot', 'starting ${Env.flavor.name} build');

    final info = await PackageInfo.fromPlatform();
    final appVersion = '${info.version}+${info.buildNumber}';

    final storage = SecureStorageService();
    final database = await AppDatabase.open();

    // Cycle 1: the API client needs to sign the user out when refresh fails,
    // but AuthService is built from the API client. The late binding below is
    // resolved before any request can run.
    late final AuthService auth;
    final api = ApiClient(
      storage: storage,
      appVersion: appVersion,
      onSessionExpired: () => auth.onSessionExpired(),
    );

    // Cycle 2: SIP re-provisions on registrar auth failure, and provisioning
    // applies its result to SIP.
    late final ProvisioningService provisioning;
    final sip = SipService(
      LinphoneService(),
      onAuthFailure: () async {
        await provisioning.fetch(force: true);
      },
    );
    provisioning = ProvisioningService(api: api, storage: storage, sip: sip);

    final callKit = CallKitService();
    final push = PushService(
      devices: DeviceRepository(api, storage),
      callKit: callKit,
    );

    auth = AuthService(
      repository: AuthRepository(api, storage),
      storage: storage,
      provisioning: provisioning,
      sip: sip,
      push: push,
      callKit: callKit,
      database: database,
    );

    await sip.start();
    callKit.start();

    return AppDependencies._(
      appVersion: appVersion,
      storage: storage,
      database: database,
      api: api,
      auth: auth,
      provisioning: provisioning,
      sip: sip,
      push: push,
      callKit: callKit,
      callHistoryDao: CallHistoryDao(database.history),
      settingsDao: SettingsDao(database.settings),
    );
  }
}
