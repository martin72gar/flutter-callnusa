import 'dart:async';

import '../../config/constants.dart';
import '../../config/env.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/diagnostics/logger.dart';
import '../../core/secure_storage/secure_storage_service.dart';
import '../../core/sip/sip_service.dart';
import '../../shared/models/app_exception.dart';
import '../../shared/models/provisioning_config.dart';
import 'provisioning_state.dart';

/// Fetches `/api/v1/provisioning/device` and applies the result to the SIP
/// stack. This is the only path by which SIP credentials enter the app.
class ProvisioningService {
  ProvisioningService({
    required this._api,
    required this._storage,
    required this._sip,
  });

  final ApiClient _api;
  final SecureStorageService _storage;
  final SipService _sip;

  final _controller = StreamController<ProvisioningState>.broadcast();
  ProvisioningState _state = const ProvisioningState();
  DateTime? _lastFetch;
  Future<ProvisioningConfig>? _inFlight;

  ProvisioningState get state => _state;
  Stream<ProvisioningState> get stream => _controller.stream;

  /// Registers SIP from the cached credentials so the app can accept a call
  /// right after launch, without waiting for the network round trip.
  Future<bool> applyCachedConfig() async {
    final cached = await _storage.readSipConfig();
    if (cached == null) return false;
    log.info('provisioning', 'applying cached SIP config');
    await _sip.apply(cached);
    return true;
  }

  /// Fetches provisioning and registers SIP.
  ///
  /// Rate-limited to one call per [AppConstants.provisioningMinInterval] so the
  /// resume hook cannot turn app switching into a request flood; [force]
  /// bypasses it (login, and registrar auth failures).
  Future<ProvisioningConfig?> fetch({bool force = false}) async {
    if (!force && _isThrottled) {
      log.debug('provisioning', 'skipped, fetched recently');
      return _state.config;
    }
    // Coalesce concurrent callers (resume + auth failure racing each other).
    if (_inFlight != null) return _inFlight;

    _emit(
      _state.status == ProvisioningStatus.ready
          ? _state
          : const ProvisioningState(status: ProvisioningStatus.loading),
    );

    final future = _fetch();
    _inFlight = future;
    try {
      return await future;
    } on AppException catch (e) {
      log.error('provisioning', 'fetch failed: $e');
      _emit(
        ProvisioningState(
          status: ProvisioningStatus.failed,
          config: _state.config,
          error: e,
        ),
      );
      return null;
    } finally {
      _inFlight = null;
    }
  }

  bool get _isThrottled =>
      _lastFetch != null &&
      DateTime.now().difference(_lastFetch!) <
          AppConstants.provisioningMinInterval;

  Future<ProvisioningConfig> _fetch() async {
    final json = await _api.get(ApiEndpoints.provisioning);
    final config = ProvisioningConfig.fromJson(
      json,
      defaultExpiry: Env.sipRegisterExpiry,
    );

    // Never log the raw response: it contains the device SIP secret.
    log.info('provisioning', 'received $config');

    await _storage.saveSipConfig(config.sip);
    _lastFetch = DateTime.now();
    _emit(ProvisioningState(status: ProvisioningStatus.ready, config: config));

    await _sip.apply(config.sip);
    return config;
  }

  Future<void> clear() async {
    _lastFetch = null;
    _emit(const ProvisioningState());
  }

  void _emit(ProvisioningState state) {
    _state = state;
    _controller.add(state);
  }

  Future<void> dispose() => _controller.close();
}
