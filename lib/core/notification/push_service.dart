import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import '../../config/constants.dart';
import '../api/device_repository.dart';
import '../diagnostics/logger.dart';
import 'callkit_service.dart';

/// Shape of an incoming-call push. The backend sends opaque identifiers only —
/// never SIP credentials (PRD 6.5).
class IncomingCallPush {
  const IncomingCallPush({
    required this.callId,
    required this.fromNumber,
    this.fromName,
  });

  final String callId;
  final String fromNumber;
  final String? fromName;

  static IncomingCallPush? tryParse(Map<String, dynamic> data) {
    if (data['type'] != 'incoming_call') return null;
    final callId = data['call_id'] as String?;
    if (callId == null) return null;
    return IncomingCallPush(
      callId: callId,
      fromNumber: data['from_number'] as String? ?? '',
      fromName: data['from_name'] as String?,
    );
  }
}

/// Handles data messages while the app is terminated or backgrounded.
///
/// This runs in a separate isolate with no access to app state, so it does the
/// one thing the OS requires immediately: put the call on screen. The SIP stack
/// is woken by the native side and reconnects when the user answers.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  final push = IncomingCallPush.tryParse(message.data);
  if (push == null) return;
  await FlutterCallkitIncoming.showCallkitIncoming(
    CallKitParams(
      id: push.callId,
      nameCaller: push.fromName ?? push.fromNumber,
      appName: AppConstants.appName,
      handle: push.fromNumber,
      type: 0,
      extra: {'sip_call_id': push.callId},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowFullLockedScreen: true,
        ringtonePath: 'ringtone_default',
      ),
      ios: const IOSParams(handleType: 'number', supportsHolding: true),
    ),
  );
}

/// Owns push registration and foreground push handling.
class PushService {
  PushService({
    required this._devices,
    required this._callKit,
    // Injectable so tests can drive push flows without Firebase.
    FirebaseMessaging? messaging,
  }) : _messaging = messaging ?? FirebaseMessaging.instance;

  final DeviceRepository _devices;
  final CallKitService _callKit;
  final FirebaseMessaging _messaging;

  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<String>? _tokenSub;

  static Future<void> initializeFirebase() async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  }

  /// Requests permission, uploads the current token, and starts listening.
  /// Failures here are non-fatal: the app still works in the foreground.
  Future<void> start() async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);

      await _syncToken();
      _tokenSub ??= _messaging.onTokenRefresh.listen((_) => _syncToken());
      _messageSub ??= FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    } catch (e) {
      log.error('push', 'push registration failed', e);
    }
  }

  Future<void> _syncToken() async {
    final token = await _messaging.getToken();
    if (token == null) return;
    // ponytail: backend only accepts one push_token; iOS PushKit VoIP token
    // is not sent until the API grows a field for it.
    await _devices.register(pushToken: token);
  }

  void _onForegroundMessage(RemoteMessage message) {
    final push = IncomingCallPush.tryParse(message.data);
    if (push == null) return;
    // In the foreground the SIP INVITE normally arrives first; reportIncoming
    // is keyed by call id, so a duplicate is a no-op rather than a second ring.
    unawaited(
      _callKit.reportIncoming(
        sipCallId: push.callId,
        number: push.fromNumber,
        displayName: push.fromName,
      ),
    );
  }

  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
    } catch (e) {
      log.warn('push', 'could not delete push token: $e');
    }
  }

  Future<void> dispose() async {
    await _messageSub?.cancel();
    await _tokenSub?.cancel();
  }
}
