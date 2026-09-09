import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../config/constants.dart';
import '../../shared/models/sip_config.dart';
import '../diagnostics/logger.dart';
import 'linphone_service.dart';
import 'sip_models.dart';

/// Owns SIP registration: applies provisioning, tracks state, retries with
/// bounded exponential backoff, and follows network transitions (PRD 6.3).
///
/// Call actions are delegated to the binding but funnelled through here so the
/// UI never imports [LinphoneBinding] directly.
class SipService {
  SipService(
    this._binding, {
    required this._onAuthFailure,
    Connectivity? connectivity,
  }) : _connectivity = connectivity ?? Connectivity();

  final LinphoneBinding _binding;
  final Connectivity _connectivity;

  /// Invoked when the registrar rejects our credentials: the backend may have
  /// rotated the device secret, so the app re-provisions instead of hammering
  /// the registrar with a password that will never work.
  final Future<void> Function() _onAuthFailure;

  final _status = StreamController<SipRegistrationStatus>.broadcast();
  final _retryAt = StreamController<DateTime?>.broadcast();

  StreamSubscription<SipRegistrationEvent>? _registrationSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _retryTimer;
  Duration _backoff = AppConstants.registerBackoffInitial;
  SipConfig? _config;
  bool _started = false;

  SipRegistrationStatus _current = SipRegistrationStatus.initial;

  SipRegistrationStatus get status => _current;
  Stream<SipRegistrationStatus> get statusStream => _status.stream;

  /// When non-null, the moment the next registration attempt is scheduled.
  Stream<DateTime?> get retryAtStream => _retryAt.stream;

  Stream<SipCallEvent> get callEvents => _binding.callEvents;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _binding.initialize();

    _registrationSub = _binding.registrationEvents.listen(_onRegistrationEvent);
    _connectivitySub = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
  }

  /// Applies (or replaces) the SIP account and triggers registration.
  Future<void> apply(SipConfig config) async {
    await start();
    _config = config;
    _resetBackoff();
    _emit(SipRegistrationStatus.connecting);
    await _binding.setAccount(config);
  }

  /// Unregisters and forgets the account (logout, or provisioning revoked).
  Future<void> stop() async {
    _cancelRetry();
    _config = null;
    await _binding.clearAccount();
    _emit(SipRegistrationStatus.unregistered);
  }

  Future<void> retryNow() async {
    final config = _config;
    if (config == null) return;
    _cancelRetry();
    _emit(SipRegistrationStatus.connecting);
    await _binding.refreshRegistration();
  }

  void _onRegistrationEvent(SipRegistrationEvent event) {
    switch (event.status) {
      case SipRegistrationStatus.registered:
        _resetBackoff();
        _cancelRetry();
      case SipRegistrationStatus.failed:
        if (event.isAuthFailure) {
          // Credentials are stale — re-provision instead of retrying.
          log.warn('sip', 'registrar rejected credentials, re-provisioning');
          unawaited(_onAuthFailure());
        } else {
          _scheduleRetry();
        }
      case _:
        break;
    }
    _emit(event.status);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    log.info('sip', 'network ${online ? 'available' : 'lost'}');
    unawaited(_binding.setNetworkReachable(online));

    if (!online) {
      _cancelRetry();
      _emit(SipRegistrationStatus.unregistered);
      return;
    }
    // Network came back: retry immediately rather than waiting out the backoff.
    _resetBackoff();
    if (_config != null) unawaited(retryNow());
  }

  void _scheduleRetry() {
    if (_config == null) return;
    _retryTimer?.cancel();
    final delay = _backoff;
    _retryAt.add(DateTime.now().add(delay));
    log.info('sip', 'registration retry in ${delay.inSeconds}s');

    _retryTimer = Timer(delay, () {
      _retryAt.add(null);
      unawaited(_binding.refreshRegistration());
    });

    // 1s, 2s, 4s … capped at 60s.
    final next = _backoff * 2;
    _backoff = next > AppConstants.registerBackoffMax
        ? AppConstants.registerBackoffMax
        : next;
  }

  void _resetBackoff() => _backoff = AppConstants.registerBackoffInitial;

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAt.add(null);
  }

  void _emit(SipRegistrationStatus status) {
    if (status == _current) return;
    _current = status;
    _status.add(status);
  }

  // ---- Call actions -------------------------------------------------------

  Future<String> startCall(String destination) =>
      _binding.startCall(destination);
  Future<void> acceptCall(String callId) => _binding.acceptCall(callId);
  Future<void> declineCall(String callId) => _binding.declineCall(callId);
  Future<void> endCall(String callId) => _binding.endCall(callId);
  Future<void> setMuted(String id, bool muted) => _binding.setMuted(id, muted);
  Future<void> setHeld(String id, bool held) => _binding.setHeld(id, held);
  Future<void> setAudioRoute(AudioRoute route) => _binding.setAudioRoute(route);
  Future<void> sendDtmf(String id, String digit) =>
      _binding.sendDtmf(id, digit);

  Future<void> dispose() async {
    _cancelRetry();
    await _registrationSub?.cancel();
    await _connectivitySub?.cancel();
    await _binding.dispose();
    await _status.close();
    await _retryAt.close();
  }
}
