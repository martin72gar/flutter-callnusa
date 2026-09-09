import 'dart:async';

import 'package:flutter/services.dart';

import '../../config/constants.dart';
import '../../config/env.dart';
import '../../shared/models/app_exception.dart';
import '../../shared/models/sip_config.dart';
import '../diagnostics/logger.dart';
import 'sip_models.dart';

/// Contract for the SIP stack. Exists so the call/registration logic above it
/// can be unit-tested against a fake without a device or a SIP server.
abstract class LinphoneBinding {
  Stream<SipRegistrationEvent> get registrationEvents;
  Stream<SipCallEvent> get callEvents;

  Future<void> initialize();
  Future<void> setAccount(SipConfig config);
  Future<void> clearAccount();
  Future<void> refreshRegistration();
  Future<void> setNetworkReachable(bool reachable);

  Future<String> startCall(String destination);
  Future<void> acceptCall(String callId);
  Future<void> declineCall(String callId);
  Future<void> endCall(String callId);
  Future<void> setMuted(String callId, bool muted);
  Future<void> setHeld(String callId, bool held);
  Future<void> setAudioRoute(AudioRoute route);
  Future<void> sendDtmf(String callId, String digit);
  Future<void> dispose();
}

/// The **only** class allowed to talk to Liblinphone.
///
/// Liblinphone runs natively (Android: `org.linphone:linphone-sdk-android`,
/// iOS: the `linphone-sdk` pod) because the Core needs its own `iterate` loop
/// and native audio/PushKit integration. Dart drives it over a method channel
/// and receives Core callbacks over an event channel; see
/// `android/app/src/main/kotlin/.../LinphonePlugin.kt` and
/// `ios/Runner/LinphonePlugin.swift`.
class LinphoneService implements LinphoneBinding {
  LinphoneService({MethodChannel? methodChannel, EventChannel? eventChannel})
    : _channel =
          methodChannel ??
          const MethodChannel(AppConstants.linphoneMethodChannel),
      _events =
          eventChannel ?? const EventChannel(AppConstants.linphoneEventChannel);

  final MethodChannel _channel;
  final EventChannel _events;

  final _registration = StreamController<SipRegistrationEvent>.broadcast();
  final _calls = StreamController<SipCallEvent>.broadcast();
  StreamSubscription<dynamic>? _nativeSubscription;

  @override
  Stream<SipRegistrationEvent> get registrationEvents => _registration.stream;

  @override
  Stream<SipCallEvent> get callEvents => _calls.stream;

  @override
  Future<void> initialize() async {
    _nativeSubscription ??= _events.receiveBroadcastStream().listen(
      _onNativeEvent,
      onError: (Object e) => log.error('sip', 'event channel error', e),
    );
    await _invoke('initialize', {
      'userAgent': '${Env.userAgent}/${AppConstants.appName}',
      'verbose': Env.verboseSipLogging,
    });
    log.info('sip', 'liblinphone core started');
  }

  void _onNativeEvent(dynamic raw) {
    if (raw is! Map) return;
    switch (raw['type']) {
      case 'registration':
        final event = SipRegistrationEvent.fromNative(raw);
        log.info(
          'sip',
          'registration → ${event.status.name}'
              '${event.reason == null ? '' : ' (${event.reason})'}',
        );
        _registration.add(event);
      case 'call':
        final event = SipCallEvent.fromNative(raw);
        log.info('sip', 'call ${event.callId} → ${event.status.name}');
        _calls.add(event);
      case 'log':
        log.debug('sip.native', '${raw['message']}');
    }
  }

  @override
  Future<void> setAccount(SipConfig config) async {
    // The password crosses the channel but is never logged: `toString()` on
    // SipConfig redacts it and the logger scrubs registered secrets.
    log.info('sip', 'applying account $config');
    await _invoke('setAccount', config.toNativeConfig());
  }

  @override
  Future<void> clearAccount() => _invoke('clearAccount');

  @override
  Future<void> refreshRegistration() => _invoke('refreshRegistration');

  @override
  Future<void> setNetworkReachable(bool reachable) =>
      _invoke('setNetworkReachable', {'reachable': reachable});

  @override
  Future<String> startCall(String destination) async {
    final id = await _invoke<String>('startCall', {'destination': destination});
    return id ??
        (throw const AppException(AppErrorKind.sip, code: 'CALL_NOT_STARTED'));
  }

  @override
  Future<void> acceptCall(String callId) =>
      _invoke('acceptCall', {'callId': callId});

  @override
  Future<void> declineCall(String callId) =>
      _invoke('declineCall', {'callId': callId});

  @override
  Future<void> endCall(String callId) => _invoke('endCall', {'callId': callId});

  @override
  Future<void> setMuted(String callId, bool muted) =>
      _invoke('setMuted', {'callId': callId, 'muted': muted});

  @override
  Future<void> setHeld(String callId, bool held) =>
      _invoke('setHeld', {'callId': callId, 'held': held});

  @override
  Future<void> setAudioRoute(AudioRoute route) =>
      _invoke('setAudioRoute', {'route': route.name});

  @override
  Future<void> sendDtmf(String callId, String digit) =>
      _invoke('sendDtmf', {'callId': callId, 'digit': digit});

  @override
  Future<void> dispose() async {
    await _nativeSubscription?.cancel();
    _nativeSubscription = null;
    await _invoke('dispose');
    await _registration.close();
    await _calls.close();
  }

  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      log.error('sip', 'native $method failed: ${e.code}');
      throw AppException(AppErrorKind.sip, code: e.code, message: e.message);
    } on MissingPluginException {
      throw const AppException(
        AppErrorKind.platform,
        code: 'SIP_STACK_UNAVAILABLE',
      );
    }
  }
}
